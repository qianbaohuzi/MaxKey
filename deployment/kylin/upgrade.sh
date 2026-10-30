#!/bin/bash
############################################################################
#  upgrade.sh —— 只更新包（不动配置、自动备份、可回滚）
#
#  与 install.sh 的分工：
#      install.sh  首次落地：建用户、装 unit、接 nginx、建库
#      upgrade.sh  后续更新：换 releases/<版本> + 切软链 + 跑迁移
#                  绝不覆盖 conf/、绝不重装 unit（除非内容真变了）
#
#  为什么单独一个脚本而不是重跑 install：
#      重跑 install 会把 nginx/unit/用户/口令全部再走一遍，任何一步的
#      "看起来没问题"都可能把运行中的环境改成半新半旧状态。
#      更新应当只有一条路径、且每一步都可回退。
#
#  流程（每步都可能失败，失败即停，环境保持可用）：
#      1. 校验新包（manifest / 校验和 / 版本不得低于当前）
#      2. 停两个服务（portal 与 mgt 必须同停同起：共享 JWT 密钥与 Cookie 域，
#         分开重启会出现"新 portal + 旧 mgt"的互不认窗口）
#      3. 备份：整库 dump + conf/ + nginx + unit 快照 → backups/<时间戳>/
#      4. 执行 Flyway 迁移（本版本若带 sql/migrations 且尚未应用）
#      5. 落新 release 目录（不改现有任何 release）
#      6. 切 current 软链
#      7. unit 内容变了才重装 + daemon-reload
#      8. 起服务 + 健康检查（失败则打印回滚命令，不自动回滚 —— 见下）
#      9. 清理超出保留份数的旧版本与旧备份
#
#  为什么不自动回滚：健康检查的判据再全也可能误判（例如数据库抖动）。
#  自动把线上代码换掉比"停下来让人看一眼"风险更大。脚本会把回滚命令
#  打在一屏之内，且 rollback.sh 是一步到位的。
#
#  用法（需 root）：
#      sudo ./upgrade.sh /path/to/maxkey-deploy-<版本>.tar.gz
#      sudo ./upgrade.sh ./maxkey-deploy-<版本>/          # 已解压目录也行
#      sudo ./upgrade.sh <包> --dry-run
#      sudo ./upgrade.sh <包> --skip-backup              # 紧急情况（不推荐）
#      sudo ./upgrade.sh <包> --allow-downgrade          # 显式允许装旧版本
############################################################################

set -eu
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "${HERE}/lib/common.sh"

PKG_ARG=""
DRY_RUN=0
SKIP_BACKUP=0
ALLOW_DOWNGRADE=0
KEEP_RELEASES="${KEEP_RELEASES:-3}"
KEEP_BACKUPS="${KEEP_BACKUPS:-5}"
BACKUP_DIR_OVERRIDE=""
NO_START=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)          DRY_RUN=1 ;;
        --skip-backup)      SKIP_BACKUP=1 ;;
        --allow-downgrade)  ALLOW_DOWNGRADE=1 ;;
        --keep-releases)    shift; KEEP_RELEASES=${1:?需要数字} ;;
        --keep-backups)     shift; KEEP_BACKUPS=${1:?需要数字} ;;
        --backup-dir)       shift; BACKUP_DIR_OVERRIDE=${1:?需要路径} ;;
        --no-start)         NO_START=1 ;;
        # --yes 目前不改变任何行为：upgrade 里没有交互确认（备份与迁移都是
        # 自动的，回滚靠 rollback.sh）。保留它是为了让 verify-cycle.sh 这类
        # 自动调用方不必区分"哪个脚本需要确认"。
        --yes|-y)           : ;;
        -h|--help)          sed -n '2,40p' "$0"; exit 0 ;;
        -*)                 echo "未知参数: $1"; exit 2 ;;
        *)                  PKG_ARG=$1 ;;
    esac
    shift
done

set_paths
export DRY_RUN
need_root

[ -n "$PKG_ARG" ] || die "请指定新包：./upgrade.sh <maxkey-deploy-*.tar.gz | 已解压目录>"

# ------------------------------------------------------------ 解包与校验 ----
say "校验新包"

SRC_ROOT=""
CLEANUP_DIR=""
if [ -d "$PKG_ARG" ]; then
    SRC_ROOT=$(cd "$PKG_ARG" && pwd)
elif [ -f "$PKG_ARG" ]; then
    # 在包所在目录旁解压，避免落到 /tmp（内存盘可能放不下 400MB）
    STAGE=$(mktemp -d "$(dirname "$(cd "$(dirname "$PKG_ARG")" && pwd)")/.maxkey-stage.XXXXXX")
    CLEANUP_DIR="$STAGE"
    info "解压到 ${STAGE}"
    tar xzf "$PKG_ARG" -C "$STAGE" || die "解压失败"
    SRC_ROOT=$(find "$STAGE" -maxdepth 2 -name manifest.json -printf '%h\n' 2>/dev/null | head -1)
    [ -n "$SRC_ROOT" ] || SRC_ROOT=$(find "$STAGE" -maxdepth 1 -mindepth 1 -type d | head -1)
    [ -n "$SRC_ROOT" ] || die "包里没有找到部署目录"
else
    die "路径不存在: ${PKG_ARG}"
fi
trap '[ -n "$CLEANUP_DIR" ] && rm -rf "$CLEANUP_DIR"' EXIT

NEW_VER=$(resolve_pkg_version "$SRC_ROOT")
[ -n "$NEW_VER" ] || die "无法从包里解析版本号（缺 manifest.json / VERSION）"
info "新包版本 : ${NEW_VER}"
info "包目录   : ${SRC_ROOT}"

# 版本号不得倒退：库里已经跑到 V3 而包只到 V2 时，旧代码配新表结构是
# 最难查的一类故障（列为不存在、字段类型不匹配）。要降级请用 rollback.sh
# （它带数据库备份），或显式 --allow-downgrade。
CUR_VER=""
CUR_TARGET=""
if [ -L "$CURRENT_LINK" ]; then
    CUR_TARGET=$(readlink -f "$CURRENT_LINK")
    CUR_VER=$(basename "$CUR_TARGET")
fi
[ -n "$CUR_VER" ] || die "本机尚未安装（${CURRENT_LINK} 不存在）。首次安装请用 ./install.sh --profile <环境名>"
info "当前版本 : ${CUR_VER}"

CMP=$(version_cmp "$NEW_VER" "$CUR_VER")
if [ "$CMP" = "-1" ] && [ "$ALLOW_DOWNGRADE" != "1" ]; then
    die "新包版本(${NEW_VER}) 低于当前版本(${CUR_VER})，已拒绝。
      数据库可能已迁移到更新的结构，回退代码会配不上。
      确实要降级：加 --allow-downgrade（务必先确认库结构与代码匹配）
      或改用回滚： sudo ./rollback.sh --list"
fi
if [ "$NEW_VER" = "$CUR_VER" ]; then
    die "新包与当前版本相同（${NEW_VER}），无需更新。
      如果这是重新打的同版本包，说明 build-package.sh 的版本号没带
      git sha 与时间戳 —— 请勿覆盖式重发，否则会失去回滚目标。"
fi

# 校验和：只覆盖"出问题必然起不来"的那部分（jar / 脚本 / sql / 配置模板）
if [ -f "${SRC_ROOT}/checksums.sha256" ]; then
    if ( cd "$SRC_ROOT" && sha256sum -c --quiet checksums.sha256 >/dev/null 2>&1 ); then
        info "校验和通过（$(wc -l < "${SRC_ROOT}/checksums.sha256") 个文件）"
    else
        ( cd "$SRC_ROOT" && sha256sum -c checksums.sha256 2>&1 | grep -v ': OK$' | head -10 | sed 's/^/      /' ) || true
        die "校验和校验失败，包可能传输损坏。请重新传输后再试"
    fi
else
    warn "包里没有 checksums.sha256，跳过完整性校验（建议重新打包）"
fi

# 迁移文件清单：决定本次是否需要动数据库
NEW_MIGRATIONS=$(ls -1 "${SRC_ROOT}"/sql/migrations/V*.sql 2>/dev/null || true)
HAS_MIGRATIONS=0
[ -n "$NEW_MIGRATIONS" ] && HAS_MIGRATIONS=1

# ------------------------------------------------------------ 前置环境 ----
say "前置环境"

[ -f "${CONF_DIR}/maxkey.env" ] || die "缺少 ${CONF_DIR}/maxkey.env（现场配置）。首次安装请用 install.sh"
load_env_file "${CONF_DIR}/maxkey.env"

if ! secret_has DATABASE_PWD; then
    die "缺少数据库口令（${SECRET_FILE}）。请先预置，否则无法备份与迁移"
fi
DATABASE_PWD=$(secret_read DATABASE_PWD)
export DATABASE_PWD

# shellcheck source=lib/db.sh
. "${HERE}/lib/db.sh"
MAXKEY_SQL_DIR="${SRC_ROOT}/sql"   # 迁移用新包里的工具与 SQL

db_connect_ok || die "数据库连不上（${DATABASE_URL}）。请先修好再升级"

CUR_DB_VER=$(db_flyway_version 2>/dev/null || true)
info "数据库版本: ${CUR_DB_VER:-（无 Flyway 历史表）}"

# ---------------------------------------------------------------- 备份 ----
TS=$(date +%Y%m%d-%H%M%S)
BK="${BACKUP_DIR_OVERRIDE:-${BK_DIR}}/${TS}"

if [ "$SKIP_BACKUP" = "1" ]; then
    warn "已指定 --skip-backup：本次不备份，回滚将无法还原数据库"
else
    say "备份当前状态到 ${BK}"

    # 空间预检：宁可提前报错，也不要在 dump 到一半时把磁盘写满
    DBSIZE=$(db_size_bytes)
    NEED_KB=$(( DBSIZE / 1024 * 2 + 256000 ))   # 2 倍库大小 + 250MB 余量（jar 与配置）
    AVAIL_KB=$(df -Pk "$(dirname "$BK")" 2>/dev/null | awk 'NR==2 {print $4}')
    info "库大小约 $((DBSIZE / 1024 / 1024)) MB，预计需要 $((NEED_KB / 1024)) MB，可用 $(( ${AVAIL_KB:-0} / 1024 )) MB"
    if [ "${AVAIL_KB:-0}" -lt "$NEED_KB" ]; then
        die "磁盘空间不足（可用 $(( ${AVAIL_KB:-0}/1024 )) MB < 需要 $(( NEED_KB/1024 )) MB）。
      用 --backup-dir /挂载盘/备份 指定其它位置，或先清理 ${BK_DIR} 下的旧备份。"
    fi

    run mkdir -p "$BK"
    run mkdir -p "${BK}/config"

    # 1) 整库 dump（含数据）。回滚时要能恢复"升级前那一刻"，必须有数据。
    info "备份数据库 ..."
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] sys_dump -> %s/db.dump\n' "$BK"
    else
        if db_backup "${BK}/db.dump" > "${BK}/db-backup.log" 2>&1; then
            SZ=$(du -h "${BK}/db.dump" 2>/dev/null | cut -f1)
            info "  已备份 ${SZ} -> db.dump"
        else
            tail -20 "${BK}/db-backup.log" | sed 's/^/      /'
            die "数据库备份失败，已中止（未做任何改动）。
      备份是回滚的唯一依据，跳过它升级等于放弃退路。"
        fi
    fi

    # 2) 配置与接入点快照。回滚时一起还原：只回代码不回配置，
    #    旧代码可能因缺新变量或路径变化而起不来。
    for f in "${CONF_DIR}/maxkey.env"; do
        [ -f "$f" ] && run cp -a "$f" "${BK}/config/"
    done
    [ -f "$NGINX_SITE" ] && run cp -a "$NGINX_SITE" "${BK}/config/maxkey.conf"
    for u in $UNITS; do
        [ -f "${SYSTEMD_DIR}/${u}.service" ] && run cp -a "${SYSTEMD_DIR}/${u}.service" "${BK}/config/"
    done
    [ -f "$LOGROTATE_FILE" ] && run cp -a "$LOGROTATE_FILE" "${BK}/config/maxkey.logrotate"

    # 3) 元信息：回滚时要知道"从哪个版本升到哪个版本"
    if [ "$DRY_RUN" = "0" ]; then
        cat > "${BK}/meta.txt" <<EOF
from_version=${CUR_VER}
to_version=${NEW_VER}
db_version_before=${CUR_DB_VER:-none}
created=$(date -Iseconds)
has_migrations=${HAS_MIGRATIONS}
EOF
    fi
    info "配置与元信息已快照"
fi

# ---------------------------------------------------------------- 迁移 ----
if [ "$HAS_MIGRATIONS" = "1" ]; then
    say "执行数据库迁移"
    info "本版本带迁移文件："
    printf '%s\n' "$NEW_MIGRATIONS" | sed "s#^${SRC_ROOT}/##" | sed 's/^/      /'

    # 停服务必须在迁移之前：Flyway 与运行中的应用同时改表会有锁与半成品状态。
    for u in $UNITS; do
        if systemctl is-active "$u" >/dev/null 2>&1; then
            run systemctl stop "$u" || warn "停止 ${u} 失败（继续尝试迁移）"
            info "已停止 $u"
        fi
    done

    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] MaxKeyMigrate --locations filesystem:%s/sql/migrations\n' "$SRC_ROOT"
    else
        # baseline-on-migrate + baseline-version 1：库里已有 44 张表（种子库建的）
        # 但没有 Flyway 历史表 —— 首次升级时自动把当前结构标记为 V1，
        # 之后只跑 V2+。否则 Flyway 会因"非空库且无历史表"直接报错。
        if db_flyway_run 2>&1 | sed 's/^/      /'; then
            NEW_DB_VER=$(db_flyway_version 2>/dev/null || true)
            info "迁移完成，数据库版本：${NEW_DB_VER:-?}"
        else
            warn "迁移失败。正在尝试把服务恢复原状（代码未改动）..."
            for u in $UNITS; do run systemctl start "$u" 2>/dev/null || true; done
            die "数据库迁移失败，升级已中止。
      库可能处于部分迁移状态。用备份恢复：
          sudo ./rollback.sh --from-backup ${BK} --restore-db
      或人工检查 ${BK}/db.dump 后修复。"
        fi
    fi
else
    info "本版本不含迁移文件，跳过数据库迁移"
fi

# ------------------------------------------------------- 停服务（若无迁移） ----
if [ "$HAS_MIGRATIONS" = "0" ]; then
    say "停止服务"
    for u in $UNITS; do
        if systemctl is-active "$u" >/dev/null 2>&1; then
            run systemctl stop "$u" || warn "停止 ${u} 失败"
            info "已停止 $u"
        fi
    done
fi

# ------------------------------------------------------- 安装新 release ----
say "安装新版本 ${NEW_VER}"
RELEASE_DIR="${REL_DIR}/${NEW_VER}"
if [ -d "$RELEASE_DIR" ]; then
    warn "目标版本目录已存在，覆盖其程序文件（不覆盖 conf/logs 软链）"
fi
run mkdir -p "$RELEASE_DIR"

for d in maxkey maxkey_mgt web bin lib sql tools; do
    [ -e "${SRC_ROOT}/${d}" ] || continue
    run rm -rf "${RELEASE_DIR}/${d}.new"
    run cp -a "${SRC_ROOT}/${d}" "${RELEASE_DIR}/${d}.new"
    run rm -rf "${RELEASE_DIR}/${d}"
    run mv "${RELEASE_DIR}/${d}.new" "${RELEASE_DIR}/${d}"
done
run cp -a "${SRC_ROOT}/manifest.json" "$RELEASE_DIR/" 2>/dev/null || true
run cp -a "${SRC_ROOT}/VERSION" "$RELEASE_DIR/" 2>/dev/null || true
run cp -a "${SRC_ROOT}/checksums.sha256" "$RELEASE_DIR/" 2>/dev/null || true

# release 内的 conf/logs 指回共享目录（与 install.sh 完全一致的口径）
if [ "$DRY_RUN" = "0" ]; then
    rm -rf "${RELEASE_DIR}/maxkey/logs" "${RELEASE_DIR}/maxkey_mgt/logs" "${RELEASE_DIR}/conf"
    ln -sfn "${LOG_DIR}/portal" "${RELEASE_DIR}/maxkey/logs"
    ln -sfn "${LOG_DIR}/mgt"    "${RELEASE_DIR}/maxkey_mgt/logs"
    ln -sfn "${CONF_DIR}"       "${RELEASE_DIR}/conf"
fi
rmdir "${RELEASE_DIR}/logs" 2>/dev/null || true

run chown -R root:root "$RELEASE_DIR" 2>/dev/null || true
run chmod +x "${RELEASE_DIR}/bin/"*.sh 2>/dev/null || true
info "文件已就位"

# --------------------------------------------------- 配置：补新增项 ----
# 不覆盖现场值（升级把配置回退成模板值是最常见的升级事故），
# 只把新版模板里新增的键追加进去 —— 缺新变量会静默回落成代码默认值，
# 这类故障极难查。
ADDED=$(conf_sync_missing_keys "${SRC_ROOT}/conf/maxkey.env" "${CONF_DIR}/maxkey.env" 2>/dev/null || true)
if [ -n "$ADDED" ]; then
    warn "新版配置新增了这些键，已用模板默认值补入 ${CONF_DIR}/maxkey.env："
    printf '%s\n' $ADDED | sed 's/^/      /'
    warn "请按现场情况核对它们（尤其是地址类与开关类）"
else
    info "现场配置无需补项"
fi

# ------------------------------------------------------------ systemd ----
say "systemd 单元"
UNIT_CHANGED=0
for u in "${SRC_ROOT}"/systemd/*.service; do
    [ -e "$u" ] || continue
    name=$(basename "$u")
    tmp=$(mktemp)
    sed "s#/opt/maxkey#${PREFIX}#g" "$u" > "$tmp"

    if [ -f "${SYSTEMD_DIR}/${name}" ] && cmp -s "$tmp" "${SYSTEMD_DIR}/${name}"; then
        info "${name} 无变化"
    else
        if [ -f "${SYSTEMD_DIR}/${name}" ]; then
            info "${name} 有变化，将重装（差异预览）："
            diff -u "${SYSTEMD_DIR}/${name}" "$tmp" 2>/dev/null | head -30 | sed 's/^/      /' || true
        else
            info "${name} 不存在，将安装"
        fi
        run install -m 644 -o root -g root "$tmp" "${SYSTEMD_DIR}/${name}"
        UNIT_CHANGED=1
    fi
    rm -f "$tmp"
done
if [ "$UNIT_CHANGED" = "1" ]; then
    run systemctl daemon-reload
    info "已 daemon-reload"
else
    info "所有 unit 无需变更，跳过 daemon-reload"
fi

# ---------------------------------------------------------- nginx 片段 ----
# nginx 配置只在"包里的模板能让渲染结果变化"时才重写。
# 换域名/换证书属于 install 的职责（--profile），升级不该动它。
NGINX_TEMPLATE_CHANGED=0
if [ -f "${SRC_ROOT}/nginx/maxkey-site.conf" ] && [ -f "$NGINX_SITE" ]; then
    RENDERED=$(mktemp)
    sed -e "s#/etc/nginx/cert/sso\.example\.gov\.cn\.crt#${NGINX_CERT:-}#g" \
        -e "s#/etc/nginx/cert/sso\.example\.gov\.cn\.key#${NGINX_KEY:-}#g" \
        -e "s#^    listen       443 ssl;#    listen       ${NGINX_TLS_PORT:-443} ssl;#" \
        -e "s#^    listen       \[::\]:443 ssl;#    listen       [::]:${NGINX_TLS_PORT:-443} ssl;#" \
        -e "s#sso\.example\.gov\.cn#${NGINX_SERVER_NAME:-}#g" \
        "${SRC_ROOT}/nginx/maxkey-site.conf" > "$RENDERED"
    if ! cmp -s "$RENDERED" "$NGINX_SITE"; then
        NGINX_TEMPLATE_CHANGED=1
        info "nginx 站点模板有变化，将更新（先 nginx -t 再 reload）"
        # 备份也必须走 run：写成裸 cp 时 --dry-run 会真的往 /etc/nginx 里写文件
        run cp -a "$NGINX_SITE" "${NGINX_SITE}.bak-${TS}"
        run cp "$RENDERED" "$NGINX_SITE"
        if [ "$DRY_RUN" = "0" ]; then
            if nginx -t 2>/tmp/nginx-t.err; then
                nginx -s reload 2>/dev/null && info "nginx 已 reload"
            else
                warn "nginx -t 失败，回滚站点文件："
                sed 's/^/      /' /tmp/nginx-t.err
                mv "${NGINX_SITE}.bak-${TS}" "$NGINX_SITE"
                nginx -s reload 2>/dev/null || true
                die "nginx 配置校验失败，已回滚（升级中止，代码未切换）"
            fi
        fi
    else
        info "nginx 站点配置无变化"
    fi
    rm -f "$RENDERED"
fi

# ------------------------------------------------------- 切 current ----
say "切换 current"
run ln -sfn "$RELEASE_DIR" "${CURRENT_LINK}"
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
        # reset-failed：上一次失败的 restart 可能留下 failed 状态，
        # 直接 restart 会被 systemd 拒绝或表现怪异。
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

        if health_check "${PORTAL_PORT}" "${MGT_PORT}" \
                "${MAXKEY_PUBLIC_URL}" "${NGINX_SERVER_NAME}" "${NGINX_TLS_PORT:-443}"; then
            info "升级成功"
        else
            RC=1
        fi
    fi
fi

# ------------------------------------------------------------ 收尾 ----
if [ "$RC" -eq 0 ]; then
    say "清理旧版本与旧备份"
    # 保留最近 N 个 release（当前版本永远保留，即使它不在最近 N 里）
    mapfile -t ALL_RELS < <(ls -1d "${REL_DIR}"/*/ 2>/dev/null | sed 's#/$##' | sort -V)
    TOTAL=${#ALL_RELS[@]}
    if [ "$TOTAL" -gt "$KEEP_RELEASES" ]; then
        REMOVE=$((TOTAL - KEEP_RELEASES))
        for ((i=0; i<REMOVE; i++)); do
            old=${ALL_RELS[$i]}
            if [ "$(readlink -f "$CURRENT_LINK")" = "$(readlink -f "$old")" ]; then
                continue
            fi
            run rm -rf "$old"
            info "已删除旧版本 $(basename "$old")"
        done
    fi

    if [ -d "$BK_DIR" ]; then
        mapfile -t ALL_BK < <(ls -1d "${BK_DIR}"/*/ 2>/dev/null | sed 's#/$##' | sort)
        TOTAL=${#ALL_BK[@]}
        if [ "$TOTAL" -gt "$KEEP_BACKUPS" ]; then
            REMOVE=$((TOTAL - KEEP_BACKUPS))
            for ((i=0; i<REMOVE; i++)); do
                run rm -rf "${ALL_BK[$i]}"
                info "已删除旧备份 $(basename "${ALL_BK[$i]}")"
            done
        fi
    fi

    say "升级完成"
    cat <<EOF
    从 ${CUR_VER}
    到 ${NEW_VER}
    备份 ${BK}

  回滚：sudo ./rollback.sh --to ${CUR_VER}
EOF
    exit 0
fi

# ------------------------------------------------------ 失败：给命令 ----
printf '\n\033[1;31m升级未通过健康检查\033[0m。代码已切到 %s，服务处于运行状态但不健康。\n' "${NEW_VER}"
cat <<EOF

请立刻二选一：

  A. 回滚到升级前（推荐，一步到位）
       sudo ./rollback.sh --to ${CUR_VER}

  B. 先看看到底哪一步不对（回滚窗口内随时可回）
       ${PREFIX}/bin/maxkeyctl.sh status
       tail -100 ${LOG_DIR}/portal/maxkey.log
       tail -100 ${LOG_DIR}/portal/nohup-portal.out
       journalctl -u maxkey-portal -n 100 --no-pager

  本次备份：${BK}
       db.dump         升级前的整库快照
       config/         conf、nginx、unit 快照
       meta.txt        版本与库版本记录

  只回代码、不回数据库： sudo ./rollback.sh --to ${CUR_VER} --code-only
  连数据库一起回退：     sudo ./rollback.sh --to ${CUR_VER} --restore-db
                         （会丢掉升级后新产生的数据）
EOF
exit 1
