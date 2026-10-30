#!/bin/bash
############################################################################
#  uninstall.sh —— 撤销 install.sh 做的改动（分级，默认保留数据）
#
#  三个级别（默认最保守，逐级显式）：
#      ./uninstall.sh              只停服务 + 删 systemd + 摘 nginx
#                                  → 程序文件、配置、口令、日志、数据库全部保留
#      ./uninstall.sh --purge      再加：删 releases/current/jre/bin 等程序文件、
#                                  删 /etc/maxkey（口令与 JWT 密钥）、删 maxkey 用户、
#                                  删 logrotate
#                                  → 保留 conf/、logs/、backups/、数据库
#      ./uninstall.sh --purge-all  再加：DROP 数据库 schema（需输入库名确认）
#                                  → 真正的零残留，用于「装→卸→装」反复验证
#
#  ⚠️ 只有 --purge-all 会碰数据，且必须手工输入库名确认。任何级别都不会
#     自动删数据库 —— 删库只能由人明确要求。
#
#  验证：./verify.sh --expect removed
############################################################################

set -eu
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "${HERE}/lib/common.sh"

PURGE=0
PURGE_ALL=0
KEEP_NGINX=0
DRY_RUN=0
PREFIX_ARG=""
ASSUME_YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --purge)      PURGE=1 ;;
        --purge-all)  PURGE=1; PURGE_ALL=1 ;;
        --keep-nginx) KEEP_NGINX=1 ;;
        --dry-run)    DRY_RUN=1 ;;
        --yes|-y)     ASSUME_YES=1 ;;
        --prefix)     shift; PREFIX_ARG=${1:?--prefix 需要路径} ;;
        -h|--help)    sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "未知参数: $1（--help 查看用法）"; exit 2 ;;
    esac
    shift
done

set_paths
if [ -n "$PREFIX_ARG" ]; then PREFIX=$PREFIX_ARG; set_paths; fi
export DRY_RUN

need_root

LEVEL="默认（只摘服务接入）"
[ "$PURGE" = "1" ] && LEVEL="--purge（含程序与密钥）"
[ "$PURGE_ALL" = "1" ] && LEVEL="--purge-all（含删库）"
say "卸载：${LEVEL}"

# --------------------------------------------------------------- 服务 ----
say "停止服务"
for u in $UNITS; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${u}\.service"; then
        run systemctl stop "${u}.service" 2>/dev/null || true
        run systemctl disable "${u}.service" 2>/dev/null || true
        info "已停止并禁用 ${u}"
    else
        info "${u} 未安装，跳过"
    fi
done

# 兜底：清理残留 pid（正常路径 systemctl stop 走 ExecStop=maxkeyctl.sh stop 已处理好）
for p in "${RUN_DIR}"/maxkey-*.pid; do
    [ -e "$p" ] || continue
    pid=$(cat "$p" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        run kill "$pid" 2>/dev/null || true
        info "已结束残留进程 ${pid}"
    fi
    run rm -f "$p"
done

# ------------------------------------------------------------- systemd ----
say "移除 systemd 单元"
for u in $UNITS; do
    if [ -f "${SYSTEMD_DIR}/${u}.service" ]; then
        run rm -f "${SYSTEMD_DIR}/${u}.service"
        info "已删除 ${u}.service"
    else
        info "${u}.service 不存在，跳过"
    fi
done
run systemctl daemon-reload 2>/dev/null || true

# --------------------------------------------------------------- nginx ----
if [ "$KEEP_NGINX" = "0" ]; then
    say "移除 nginx 接入"
    # 只删 MaxKey 自己的两个文件，绝不触碰现场其它站点
    for f in "$NGINX_SITE" "$NGINX_PROXY"; do
        if [ -f "$f" ]; then
            run rm -f "$f"
            info "已删除 $f"
        else
            info "$f 不存在，跳过"
        fi
    done
    if command -v nginx >/dev/null 2>&1 && [ "$DRY_RUN" = "0" ]; then
        if nginx -t 2>/dev/null; then
            nginx -s reload 2>/dev/null && info "nginx 已 reload" || warn "reload 失败，请手工 nginx -s reload"
        else
            warn "nginx -t 未通过（可能是别的站点问题），请检查后手工 reload"
        fi
    fi
else
    skip "已指定 --keep-nginx，保留 nginx 配置"
fi

# ------------------------------------------------------------ logrotate ----
if [ "$PURGE" = "1" ] && [ -f "$LOGROTATE_FILE" ]; then
    say "移除日志轮转"
    run rm -f "$LOGROTATE_FILE"
    info "已删除 $LOGROTATE_FILE"
fi

# ---------------------------------------------------------------- 文件 ----
if [ "$PURGE" = "1" ]; then
    say "删除程序文件（--purge）"

    # 安全护栏：必须是预期的绝对路径，且不是系统目录
    [ -n "$PREFIX" ] || die "PREFIX 为空，拒绝删除"
    case "$PREFIX" in
        /|/opt|/usr|/etc|/var|/home|"") die "PREFIX=${PREFIX} 不安全，拒绝删除" ;;
        /*) ;;
        *) die "PREFIX 必须是绝对路径（当前: ${PREFIX}）" ;;
    esac

    for d in releases current jre bin sql nginx systemd web maxkey maxkey_mgt run; do
        if [ -e "${PREFIX}/${d}" ] || [ -L "${PREFIX}/${d}" ]; then
            run rm -rf "${PREFIX:?}/${d}"
            info "已删除 ${PREFIX}/${d}"
        fi
    done

    # conf/ 与 logs/ 与 backups/ 即使 --purge 也保留：
    # 里面是现场域名、数据库地址、排障证据与升级备份，重装时还要用。
    run mkdir -p "$PREFIX"
    info "保留：conf/（现场配置）、logs/（排障证据）、backups/（升级备份）"

    # 注意：**密钥文件与运行用户不在这里删**。
    #
    # 踩过的坑（真实顺序 bug）：--purge-all 的语义是"连库一起清"，
    # 而连库需要 DATABASE_PWD。若在文件清理阶段就把
    # /etc/maxkey/maxkey-secret.env 删掉，后面 DROP SCHEMA 必然失败：
    #     DATABASE_PWD: 缺少 DATABASE_PWD，无法连库执行 DROP
    # 结果是"程序删了、库还在"，且验证脚本会报残留 —— 最难处理的状态。
    # 因此这两件事延后到数据库清理之后再执行（见文件末尾）。
else
    say "保留程序与配置（未指定 --purge）"
    info "${PREFIX} 未删除（含 releases/、conf/、logs/、backups/）"
    info "${SECRET_FILE} 未删除"
    info "需要清理请执行：sudo ./uninstall.sh --purge"
fi

# ---------------------------------------------------------------- 数据库 ----
if [ "$PURGE_ALL" = "1" ]; then
    say "删除数据库 schema（--purge-all）"
    # shellcheck source=lib/db.sh
    . "${HERE}/lib/db.sh"

    # 关键：JDBC 工具必须取自**当前这个部署包**，不能取 PREFIX/current/sql。
    # 因为 --purge 刚刚删掉了 releases/（也就是 current 的指向），
    # 若还去那里找 MaxKeySql.class，会报
    #     Could not find or load main class MaxKeySql
    # 而这一步正是"清库"，缺了工具就无法完成，最后留下"程序删了、库还在"的状态。
    MAXKEY_SQL_DIR="${HERE}/sql"

    if [ -f "${CONF_DIR}/maxkey.env" ]; then
        load_env_file "${CONF_DIR}/maxkey.env"
    else
        die "找不到 ${CONF_DIR}/maxkey.env，无法确定数据库连接。请用 DBA 账号手工 DROP SCHEMA。"
    fi
    if secret_has DATABASE_PWD; then
        DATABASE_PWD=$(secret_read DATABASE_PWD)
    fi
    : "${DATABASE_PWD:?缺少 DATABASE_PWD，无法连库执行 DROP}"

    DBNAME=$(printf '%s' "$DATABASE_URL" | sed -E 's#^jdbc:[a-z0-9]+://[^/]+/([^?]+).*#\1#')
    info "目标库 : ${DBNAME}"
    info "将执行 : DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    warn "这会把 ${DBNAME} 里的全部表与数据删除，且不可恢复"

    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] 跳过确认与 DROP\n'
    else
        if [ "$ASSUME_YES" != "1" ]; then
            if [ ! -t 0 ]; then
                die "非交互环境必须显式加 --yes 才会执行 DROP"
            fi
            printf '    请重复输入库名以确认删除（输入 %s）: ' "$DBNAME"
            read -r answer
            [ "$answer" = "$DBNAME" ] || die "库名不匹配，已中止（未执行任何 SQL）"
        fi

        # 删之前留一份 dump（backups/ 在 --purge 时被保留，放得进去）
        if [ -d "$BK_DIR" ]; then
            ts=$(date +%Y%m%d-%H%M%S)
            mkdir -p "${BK_DIR}/${ts}"
            info "先在 ${BK_DIR}/${ts}/ 留一份删除前备份"
            if db_backup "${BK_DIR}/${ts}/pre-purge-${DBNAME}.dump"; then
                info "备份完成"
            else
                warn "备份失败，但按你的确认继续（--purge-all 语义即彻底清除）"
            fi
        fi

        # IF EXISTS 必须加：本脚本要能重复执行（验证循环里会连跑多次）。
        # 没有它时第二次执行报
        #     ERROR: schema or package "public" does not exist
        # 而库其实已经是干净的 —— 这会把"成功"误判成"失败"，
        # 进而让 verify 与 uninstall 的结论互相矛盾。
        if db_exec_sql "DROP SCHEMA IF EXISTS public CASCADE"; then
            db_exec_sql "CREATE SCHEMA IF NOT EXISTS public" >/dev/null 2>&1 || true
            info "已删除 schema public 并重建为空 schema"
        else
            die "DROP SCHEMA 失败，请用 DBA 账号手工执行：
      ksql -U <dba> -d ${DBNAME} -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'"
        fi
    fi

    warn "数据库 ${DBNAME} 与角色 ${DATABASE_USER} 本身未删除 —— 由 DBA 管理"
else
    cat <<'EOF'

  数据库与数据未被删除（uninstall 不会自动删库）。
  如需清理（谨慎，不可恢复）：
      sudo ./uninstall.sh --purge-all
  或手工：
      ksql -U <dba> -d maxkey -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
EOF
fi

# ------------------------------------------- 密钥与用户（必须最后删） ----
# 顺序理由见上面"文件"段的注释：DROP SCHEMA 需要口令文件还在。
if [ "$PURGE" = "1" ]; then
    say "清理密钥与运行用户"
    if [ -f "$SECRET_FILE" ]; then
        run rm -f "$SECRET_FILE"
        info "已删除 $SECRET_FILE（含数据库口令与 JWT 密钥）"
    fi
    run rmdir "$ETC_SECRET_DIR" 2>/dev/null || true

    if id "$RUN_USER" >/dev/null 2>&1; then
        run userdel "$RUN_USER" 2>/dev/null || warn "userdel 失败（可能仍有进程在用该用户）"
        info "已删除用户 ${RUN_USER}"
    fi
fi

say "卸载完成"
CUR_LEVEL="默认"
[ "$PURGE" = "1" ] && CUR_LEVEL="--purge"
[ "$PURGE_ALL" = "1" ] && CUR_LEVEL="--purge-all"
echo "  当前级别：${CUR_LEVEL}"
echo "  残留检查：sudo ./verify.sh --expect removed"
