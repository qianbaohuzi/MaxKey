#!/bin/bash
############################################################################
#  rollback.sh —— 回滚到指定版本（代码 / 配置 / 数据库，三级可选）
#
#  为什么回滚能一步到位：升级把新版本装进 releases/<版本>/，只改了一个软链。
#  回滚就是把软链指回去 —— 不做 400MB 拷贝，不重新构建。
#
#  默认回滚范围（最常用）：
#      代码（current 软链） + conf/ + nginx + systemd
#      **不碰数据库**，因为 Flyway 是单向的，还原会丢掉升级后新产生的数据
#
#  数据库要一起回退（只有当新版本改过表结构、旧代码跑不起来时才需要）：
#      ./rollback.sh --to <版本> --restore-db
#      ./rollback.sh --from-backup /opt/maxkey/backups/<时间戳> --restore-db
#
#  用法（需 root）：
#      ./rollback.sh --list                        # 看有哪些版本可回滚
#      ./rollback.sh --to <版本>                   # 回代码+配置（推荐）
#      ./rollback.sh --to <版本> --code-only       # 只回代码
#      ./rollback.sh --to <版本> --restore-db      # 连数据库一起回退（危险）
#      ./rollback.sh --from-backup <目录> --restore-db
#      ./rollback.sh --last                        # 回到上一个版本
#
#  没有备份时：允许回滚代码与配置，但会在最后一行醒目告警"数据库未恢复"，
#  不制造"看起来成功了"的假象。
############################################################################

set -eu
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "${HERE}/lib/common.sh"

TO_VER=""
LAST=0
LIST=0
CODE_ONLY=0
RESTORE_DB=0
FROM_BACKUP=""
DRY_RUN=0
NO_START=0
YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --to)           shift; TO_VER=${1:?--to 需要版本号} ;;
        --last)         LAST=1 ;;
        --list)         LIST=1 ;;
        --code-only)    CODE_ONLY=1 ;;
        --restore-db)   RESTORE_DB=1 ;;
        --from-backup)  shift; FROM_BACKUP=${1:?--from-backup 需要目录} ;;
        --dry-run)      DRY_RUN=1 ;;
        --no-start)     NO_START=1 ;;
        --yes|-y)       YES=1 ;;
        -h|--help)      sed -n '2,32p' "$0"; exit 0 ;;
        *) echo "未知参数: $1"; exit 2 ;;
    esac
    shift
done

set_paths
export DRY_RUN
need_root

# --------------------------------------------------------------- 列表 ----
list_versions() {
    local cur target
    cur=""
    [ -L "$CURRENT_LINK" ] && cur=$(readlink -f "$CURRENT_LINK")

    printf '\n\033[1;36m== 可回滚的版本（%s）==\033[0m\n' "$REL_DIR"
    printf '  %-42s %-12s %s\n' "版本目录" "大小" "说明"
    printf '  %-42s %-12s %s\n' "------------------------------------------" "----------" "----"
    local d
    for d in $(ls -1d "${REL_DIR}"/*/ 2>/dev/null | sed 's#/$##' | sort -V); do
        local mark=""
        [ "$(readlink -f "$d")" = "$cur" ] && mark="← 当前运行"
        printf '  %-42s %-12s %s\n' "$(basename "$d")" "$(du -sh "$d" 2>/dev/null | cut -f1)" "$mark"
    done

    printf '\n\033[1;36m== 可用的备份（%s）==\033[0m\n' "$BK_DIR"
    if [ -d "$BK_DIR" ]; then
        printf '  %-24s %-10s %-10s %s\n' "时间戳" "库 dump" "大小" "版本（from → to）"
        printf '  %-24s %-10s %-10s %s\n' "------------------------" "----------" "----------" "----"
        for d in $(ls -1d "${BK_DIR}"/*/ 2>/dev/null | sed 's#/$##' | sort -r); do
            local dump="无" sz="-"
            if [ -f "${d}/db.dump" ]; then
                dump="有"
                sz=$(du -h "${d}/db.dump" 2>/dev/null | cut -f1)
            fi
            local meta="-"
            [ -f "${d}/meta.txt" ] && meta=$(sed -n 's/^from_version=//p' "${d}/meta.txt" | head -1)
            [ -f "${d}/meta.txt" ] && meta="${meta} → $(sed -n 's/^to_version=//p' "${d}/meta.txt" | head -1)"
            printf '  %-24s %-10s %-10s %s\n' "$(basename "$d")" "$dump" "$sz" "$meta"
        done
    else
        echo "  （无）"
    fi
    echo
    echo "  用法：sudo ./rollback.sh --to <版本>            只回代码与配置（数据库不动）"
    echo "        sudo ./rollback.sh --to <版本> --restore-db 连数据库一起回退"
    echo "        sudo ./rollback.sh --last                   回到上一个版本"
    echo
}

if [ "$LIST" = "1" ]; then
    list_versions
    exit 0
fi

[ -L "$CURRENT_LINK" ] || die "本机未安装（${CURRENT_LINK} 不存在）"

CUR_TARGET=$(readlink -f "$CURRENT_LINK")
CUR_VER=$(basename "$CUR_TARGET")

# ------------------------------------------------------- 确定目标版本 ----
if [ "$LAST" = "1" ]; then
    mapfile -t ALL < <(ls -1d "${REL_DIR}"/*/ 2>/dev/null | sed 's#/$##' | sort -V)
    PREV=""
    for d in "${ALL[@]}"; do
        [ "$(readlink -f "$d")" = "$CUR_TARGET" ] && break
        PREV=$d
    done
    [ -n "$PREV" ] || die "没有上一个版本可回（当前已是${REL_DIR} 下最旧的版本）"
    TO_VER=$(basename "$PREV")
fi

if [ -n "$FROM_BACKUP" ]; then
    [ -d "$FROM_BACKUP" ] || die "备份目录不存在: ${FROM_BACKUP}"
    [ -f "${FROM_BACKUP}/meta.txt" ] || die "备份目录里缺 meta.txt，无法确定要回到哪个版本"
    TO_VER=$(sed -n 's/^from_version=//p' "${FROM_BACKUP}/meta.txt" | head -1)
    [ -n "$TO_VER" ] || die "meta.txt 里没有 from_version"
    info "从备份推断目标版本: ${TO_VER}"
fi

[ -n "$TO_VER" ] || die "请指定 --to <版本> 或 --last（用 --list 查看可选项）"

TARGET="${REL_DIR}/${TO_VER}"
[ -d "$TARGET" ] || die "版本目录不存在: ${TARGET}
      用 ./rollback.sh --list 查看现有版本。
      版本被自动清理（默认保留 3 个）时就只能重装旧包：
          sudo ./upgrade.sh <旧包.tar.gz> --allow-downgrade"

if [ "$TO_VER" = "$CUR_VER" ]; then
    die "目标版本与当前版本相同（${CUR_VER}），无需回滚"
fi

# 目标版本的 manifest（决定它是哪次构建、是否带迁移）
TARGET_MANIFEST="${TARGET}/manifest.json"
TARGET_TIME=""
[ -f "$TARGET_MANIFEST" ] && TARGET_TIME=$(sed -n 's/.*"buildTime"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TARGET_MANIFEST" | head -1)

say "回滚计划"
info "当前版本 : ${CUR_VER}"
info "目标版本 : ${TO_VER}${TARGET_TIME:+（构建于 ${TARGET_TIME}）}"
info "回滚范围 : $( [ "$CODE_ONLY" = "1" ] && echo '只回代码（软链）' || echo '代码 + conf + nginx + systemd' )"
if [ "$RESTORE_DB" = "1" ]; then
    info "数据库   : 将一起还原（会丢掉升级后新产生的数据）"
else
    info "数据库   : 不动（Flyway 是单向的，默认只回代码）"
fi

# ------------------------------------------------------- 找对应备份 ----
# 目标的匹配备份 = meta.txt 里 to_version 等于"当前版本"的那份
# （即"升级到当前版本之前"拍的那次）
MATCH_BK=""
if [ -d "$BK_DIR" ]; then
    for d in $(ls -1d "${BK_DIR}"/*/ 2>/dev/null | sed 's#/$##' | sort -r); do
        [ -f "${d}/meta.txt" ] || continue
        tv=$(sed -n 's/^to_version=//p' "${d}/meta.txt" | head -1)
        fv=$(sed -n 's/^from_version=//p' "${d}/meta.txt" | head -1)
        if [ "$tv" = "$CUR_VER" ] && [ "$fv" = "$TO_VER" ]; then
            MATCH_BK="$d"
            break
        fi
    done
fi
[ -n "$FROM_BACKUP" ] && MATCH_BK="$FROM_BACKUP"

if [ -n "$MATCH_BK" ]; then
    info "对应备份 : ${MATCH_BK}"
else
    warn "没有找到与「${CUR_VER} ← ${TO_VER}」对应的备份"
fi

# ------------------------------------------------- 数据库还原（需显式） ----
if [ "$RESTORE_DB" = "1" ]; then
    if [ -z "$MATCH_BK" ] || [ ! -f "${MATCH_BK}/db.dump" ]; then
        die "无法还原数据库：没有可用的 db.dump。
      可用的备份：$(ls -1d "${BK_DIR}"/*/ 2>/dev/null | wc -l) 份，都不匹配本次回滚。
      只想回代码与配置请去掉 --restore-db。"
    fi

    say "还原数据库"
    warn "即将用 ${MATCH_BK}/db.dump 覆盖当前库"
    warn "升级后新产生的数据会丢失（包括用户、应用配置、登录日志）"

    if [ "$DRY_RUN" = "0" ] && [ "$YES" != "1" ]; then
        if [ ! -t 0 ]; then
            die "非交互环境还原数据库必须显式加 --yes"
        fi
        printf '    输入 yes 确认覆盖数据库: '
        read -r ans
        [ "$ans" = "yes" ] || die "已取消（未做任何改动）"
    fi

    load_env_file "${CONF_DIR}/maxkey.env"
    if secret_has DATABASE_PWD; then
        DATABASE_PWD=$(secret_read DATABASE_PWD)
        export DATABASE_PWD
    fi
    : "${DATABASE_PWD:?缺少 DATABASE_PWD，无法连库}"

    # shellcheck source=lib/db.sh
    . "${HERE}/lib/db.sh"
    MAXKEY_SQL_DIR="${TARGET}/sql"

    say "停止服务（还原数据库必须先停）"
    for u in $UNITS; do
        run systemctl stop "$u" 2>/dev/null || true
        info "已停止 $u"
    done

    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] 还原 %s -> %s\n' "${MATCH_BK}/db.dump" "$DATABASE_URL"
    else
        # 还原前先清空 schema：db.dump 里的 CREATE TABLE 不带 IF NOT EXISTS，
        # 直接往非空库里灌会一路报"表已存在"。
        db_name=$(printf '%s' "$DATABASE_URL" | sed -E 's#^jdbc:[a-z0-9]+://[^/]+/([^?]+).*#\1#')
        if [ "$YES" != "1" ] && [ -t 0 ]; then
            printf '    再次确认：将清空库 %s 的 public schema 并从备份重建。输入库名: ' "$db_name"
            read -r ans2
            [ "$ans2" = "$db_name" ] || die "库名不匹配，已取消"
        fi

        info "清空 schema public ..."
        if ! db_exec_sql "DROP SCHEMA public CASCADE"; then
            die "清空 schema 失败，已中止（代码未回滚，环境仍在当前版本）"
        fi
        db_exec_sql "CREATE SCHEMA public" >/dev/null 2>&1 || true

        info "从备份恢复 ..."
        if ! db_restore "${MATCH_BK}/db.dump"; then
            printf '\n\033[1;31m数据库恢复失败\033[0m。库当前是空的。\n'
            cat <<EOF
  请立刻人工处理：
      1. 检查备份是否完整： ${MATCH_BK}/db.dump
      2. 用 DBA 账号手工恢复：
           ksql -U <dba> -d ${db_name} -f ${MATCH_BK}/db.dump
      3. 代码尚未回滚，环境仍指向 ${CUR_VER}
EOF
            exit 1
        fi
        info "数据库已恢复"
    fi
else
    if [ -n "$MATCH_BK" ] && [ -f "${MATCH_BK}/db.dump" ]; then
        cat <<EOF

    提示：本次只回代码，数据库**保持现状**。
    如果新版本改过表结构（新增列/表），回退的旧代码可能无法正常工作，
    典型症状是"列不存在"或页面报 500。

    确实需要连数据一起回退：
        sudo ./rollback.sh --to ${TO_VER} --restore-db --from-backup ${MATCH_BK}
    （会丢掉升级后新产生的数据）
EOF
    fi
fi

# ---------------------------------------------------------- 停服务 ----
if [ "$RESTORE_DB" = "0" ]; then
    say "停止服务"
    for u in $UNITS; do
        if systemctl is-active "$u" >/dev/null 2>&1; then
            run systemctl stop "$u" 2>/dev/null || warn "停止 $u 失败"
            info "已停止 $u"
        fi
    done
fi

# ------------------------------------------------- 还原配置（可跳过） ----
if [ "$CODE_ONLY" = "0" ] && [ -n "$MATCH_BK" ] && [ -d "${MATCH_BK}/config" ]; then
    say "还原配置"
    # 只还原"升级时确实被改动过"的东西。conf/maxkey.env 一般不变，
    # 但 unit 与 nginx 可能随新版本变过（例如日志目录、端口）。
    if [ -f "${MATCH_BK}/config/maxkey.env" ]; then
        if cmp -s "${MATCH_BK}/config/maxkey.env" "${CONF_DIR}/maxkey.env"; then
            info "conf/maxkey.env 无变化"
        else
            run cp -a "${CONF_DIR}/maxkey.env" "${CONF_DIR}/maxkey.env.bak-$(date +%Y%m%d%H%M%S)"
            run cp -a "${MATCH_BK}/config/maxkey.env" "${CONF_DIR}/maxkey.env"
            info "conf/maxkey.env 已还原（原文件存为 .bak）"
        fi
    fi

    unit_changed=0
    for u in $UNITS; do
        src="${MATCH_BK}/config/${u}.service"
        dst="${SYSTEMD_DIR}/${u}.service"
        [ -f "$src" ] || continue
        if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
            info "${u}.service 无变化"
        else
            # 备份里的 unit 路径是按当时 prefix 渲染的，可能含旧路径
            tmp=$(mktemp)
            sed "s#/opt/maxkey#${PREFIX}#g" "$src" > "$tmp"
            run install -m 644 -o root -g root "$tmp" "$dst"
            info "${u}.service 已还原"
            unit_changed=1
            rm -f "$tmp"
        fi
    done
    [ "$unit_changed" = "1" ] && { run systemctl daemon-reload; info "已 daemon-reload"; }

    if [ -f "${MATCH_BK}/config/maxkey.conf" ]; then
        if cmp -s "${MATCH_BK}/config/maxkey.conf" "$NGINX_SITE"; then
            info "nginx 站点配置无变化"
        else
            run cp -a "$NGINX_SITE" "${NGINX_SITE}.bak-$(date +%Y%m%d%H%M%S)"
            run cp -a "${MATCH_BK}/config/maxkey.conf" "$NGINX_SITE"
            if [ "$DRY_RUN" = "0" ] && nginx -t 2>/tmp/nginx-t.err; then
                nginx -s reload 2>/dev/null && info "nginx 配置已还原并 reload"
            else
                warn "nginx -t 未通过，配置已还原但未 reload："
                sed 's/^/      /' /tmp/nginx-t.err 2>/dev/null || true
            fi
        fi
    fi
elif [ "$CODE_ONLY" = "1" ]; then
    skip "已指定 --code-only，配置与 unit 保持现状"
else
    warn "无可用备份快照，配置与 unit 保持现状（只回代码）"
fi

# ------------------------------------------------------- 切换 current ----
say "切换 current 回 ${TO_VER}"
run ln -sfn "$TARGET" "${CURRENT_LINK}"
if [ "$DRY_RUN" = "0" ]; then
    info "current -> $(readlink -f "$CURRENT_LINK")"
fi

# --------------------------------------------------------- 启动与自检 ----
RC=0
if [ "$NO_START" = "1" ]; then
    skip "已指定 --no-start，服务未启动"
else
    say "启动服务"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] systemctl restart %s\n' "$UNITS"
    else
        systemctl reset-failed $UNITS 2>/dev/null || true
        # 同 install.sh：set -e 下裸调 systemctl，失败会静默退出，
        # 看不到任何失败原因。必须接住退出码并把 systemd 状态打出来。
        if ! systemctl restart $UNITS; then
            printf '\n\033[1;31msystemctl restart 失败\033[0m\n\n'
            for u in $UNITS; do
                printf '  ---- %s ----\n' "$u"
                systemctl status "$u" --no-pager -l 2>&1 | sed -n '1,12p' | sed 's/^/    /'
            done
            printf '\n  启动输出（java 的 stdout）:\n'
            printf '    tail -50 %s/portal/nohup-portal.out\n' "$LOG_DIR"
            printf '    tail -50 %s/mgt/nohup-mgt.out\n' "$LOG_DIR"
            RC=1
        fi

        # 回滚后的健康检查必须用"目标版本当时的配置"来判，
        # 所以重新 load 一次 conf（可能刚被还原成旧值）。
        load_env_file "${CONF_DIR}/maxkey.env"
        if health_check "${PORTAL_PORT:-9527}" "${MGT_PORT:-9526}" \
                "${MAXKEY_PUBLIC_URL}" "${NGINX_SERVER_NAME}" "${NGINX_TLS_PORT:-443}"; then
            info "回滚后健康检查通过"
        else
            RC=1
        fi
    fi
fi

# ---------------------------------------------------------------- 收尾 ----
if [ "$RC" -eq 0 ]; then
    say "回滚完成"
    cat <<EOF
    现在版本 : ${TO_VER}（原 ${CUR_VER}）

  想回到刚才那个版本：sudo ./rollback.sh --to ${CUR_VER}
EOF
    exit 0
fi

printf '\n\033[1;31m回滚后健康检查仍未通过\033[0m —— 问题可能不在代码版本。\n'
cat <<EOF

  建议按顺序查：
    1. 数据库状态（可能是还原后缺表/缺数据）
         ${PREFIX}/bin/preflight.sh
    2. 口令与密钥
         sudo vi ${SECRET_FILE}
    3. 日志
         tail -100 ${LOG_DIR}/portal/maxkey.log
         journalctl -u maxkey-portal -n 100 --no-pager

  当前版本已指回 ${TO_VER}。如需再切到别的版本：
         sudo ./rollback.sh --list
EOF
exit 1
