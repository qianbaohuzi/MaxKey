#!/bin/bash
############################################################################
#  install.sh —— 把部署包首次落到一台机器（版本目录 + current 软链）
#
#  装完的布局：
#     /opt/maxkey/
#     ├── current -> releases/4.2.0-a1b2c3d-20261029T231500   # 原子切换点
#     ├── releases/
#     │   └── 4.2.0-a1b2c3d-20261029T231500/
#     │       ├── maxkey/        portal jar + logs -> 共享日志软链
#     │       ├── maxkey_mgt/    mgt jar   + logs -> 共享日志软链
#     │       ├── web/           两个前端 dist
#     │       ├── bin/           maxkeyctl.sh / preflight.sh（随版本走）
#     │       ├── conf -> ../../conf
#     │       └── sql/
#     ├── conf/maxkey.env        跨版本共享，升级不覆盖
#     ├── jre/                   跨版本共享的裁剪运行时（64MB，不每版一份）
#     ├── logs/{portal,mgt}/     跨版本共享的日志
#     ├── run/                   pid
#     └── backups/<时间戳>/       升级前的库 dump 与配置快照
#
#  为什么改成版本目录：旧的"就地覆盖"升级是不可逆的 —— 覆盖那一刻旧代码就没了，
#  只能靠事先手工拷贝。软链切换是原子的，回滚就是把链接指回去（见 rollback.sh）。
#
#  刻意不做：
#    * 已装过的机器直接重装 → 拒绝，提示用 upgrade.sh（或 --force-reinstall）
#    * 不覆盖现场 conf/ 与 logs/
#    * 不改目标机已有的其它 nginx 站点文件
#    * 不把口令写进任何受版本控制的文件
#
#  用法（需 root）：
#      ./install.sh --profile dev-local
#      ./install.sh --profile test1 --dry-run
#      ./install.sh --profile test1 --no-nginx --no-start
#      ./install.sh --profile test1 --init-db          # 空库时导入种子库
#      ./install.sh --migrate-layout --profile dev-local  # 旧布局原地转换
#      ./install.sh --force-reinstall --profile dev-local
#
#  卸载：./uninstall.sh        验证：./verify.sh --expect installed
############################################################################

set -eu

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "${HERE}/lib/common.sh"

# ------------------------------------------------------------------ 参数 ----
PROFILE=""
DO_NGINX=1
DO_START=1
DO_DB=0
IMPORT_SEED=0
FORCE_REINSTALL=0
MIGRATE_LAYOUT=0
PROFILE_FILE=""
DRY_RUN=0
PREFIX_ARG=""
RUN_USER=maxkey

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)         shift; PROFILE=${1:?--profile 需要环境名} ;;
        --prefix)          shift; PREFIX_ARG=${1:?--prefix 需要路径} ;;
        --dry-run)         DRY_RUN=1 ;;
        --no-nginx)        DO_NGINX=0 ;;
        --no-start)        DO_START=0 ;;
        --init-db)         DO_DB=1 ;;
        --import-seed)     DO_DB=1; IMPORT_SEED=1 ;;
        --migrate-layout)  MIGRATE_LAYOUT=1 ;;
        --force-reinstall) FORCE_REINSTALL=1 ;;
        -h|--help)         sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "未知参数: $1（--help 查看用法）"; exit 2 ;;
    esac
    shift
done

set_paths
if [ -n "$PREFIX_ARG" ]; then PREFIX=$PREFIX_ARG; set_paths; fi
export DRY_RUN

need_root

# ------------------------------------------------------------ 前置检查 ----
say "前置检查"

[ -f "${HERE}/conf/maxkey.env" ] || die "部署包不完整：缺少 conf/maxkey.env 模板"
[ -d "${HERE}/maxkey" ] || die "部署包不完整：缺少 maxkey/（portal jar）"
[ -d "${HERE}/maxkey_mgt" ] || die "部署包不完整：缺少 maxkey_mgt/（管理端 jar）"
[ -d "${HERE}/web/maxkey" ] || die "部署包不完整：缺少 web/maxkey（前端产物）"

# 变量名必须避开 VERSION：/etc/os-release 里也有 VERSION，且本脚本后面会读它。
PKG_VERSION=$(resolve_pkg_version "$HERE")
[ -n "$PKG_VERSION" ] || die "无法确定包版本（manifest.json / VERSION 都不存在）"
info "部署包版本 : ${PKG_VERSION}"
info "安装路径   : ${PREFIX}"

require_hard useradd "创建运行用户"
require_hard systemctl "管理服务"
if [ "$DO_NGINX" = "1" ] && ! require_soft nginx; then
    die "未找到 nginx。现场用别的反向代理请加 --no-nginx"
fi

# 系统口径：目标机是麒麟 V10，但开发机常用 Ubuntu 做回归。
# 只告警不拦 —— 拦住会让本机无法验证；真正的不兼容（架构/glibc）由 preflight 报。
# 注意：**不能**用 `. /etc/os-release` 走到全局作用域 ——
# 它里面有 VERSION="24.04.5 LTS (Noble Numbat)"，会把本脚本解析出的
# 包版本号 VERSION 覆盖掉，于是 release 目录变成 releases/24.04.5 LTS ...，
# 而且报错点离真正原因很远。这里用子 shell 取值，只取需要的两个字段。
if [ -r /etc/os-release ]; then
    OS_PRETTY=$( . /etc/os-release >/dev/null 2>&1; printf '%s' "${PRETTY_NAME:-}" )
    case "$OS_PRETTY" in
        *Kylin*|*kylin*|*麒麟*) info "系统 : ${OS_PRETTY}（目标系统）" ;;
        *) warn "系统 : ${OS_PRETTY} —— 非麒麟，仅用于验证；生产目标是麒麟 V10" ;;
    esac
fi

# --------------------------------------------------- 环境档案 / 配置文件 ----
say "环境档案"

[ -n "$PROFILE" ] || die "必须指定环境档案：--profile <名>（可用: $(ls "${HERE}/env" 2>/dev/null | sed 's/\.env$//' | tr '\n' ' '))"
PROFILE_FILE="${HERE}/env/${PROFILE}.env"
[ -f "$PROFILE_FILE" ] || die "环境档案不存在: ${PROFILE_FILE}"
info "档案 : ${PROFILE_FILE}"

# 现场配置"一个文件说了算"：模板（含全部默认值与注释）+ 档案（只写差异）渲染而成。
# 已存在则一律保留 —— 升级把配置回退成模板值是最常见的升级事故。
RENDERED=$(mktemp)
render_conf "${HERE}/conf/maxkey.env" "$PROFILE_FILE" "$RENDERED"

if [ -f "${CONF_DIR}/maxkey.env" ]; then
    warn "已存在 ${CONF_DIR}/maxkey.env，保留现场配置"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] cp <渲染结果> %s.new\n' "${CONF_DIR}/maxkey.env"
    else
        cp -a "$RENDERED" "${CONF_DIR}/maxkey.env.new"
    fi
    info "新渲染结果存为 ${CONF_DIR}/maxkey.env.new（diff 后可手工合并）"
else
    run mkdir -p "$CONF_DIR"
    run cp -a "$RENDERED" "${CONF_DIR}/maxkey.env"
    info "已写入 ${CONF_DIR}/maxkey.env（模板 + profile ${PROFILE}）"
fi
rm -f "$RENDERED"

# 校验以"最终生效的那份"为准 —— 现场手改过的值才是真的
if [ -f "${CONF_DIR}/maxkey.env" ]; then
    load_env_file "${CONF_DIR}/maxkey.env"
else
    load_env_file "$PROFILE_FILE"
fi
check_site_consistency

# ------------------------------------------------------ 布局冲突检测 ----
say "布局检测"

if [ -L "$CURRENT_LINK" ] || [ -d "$REL_DIR" ]; then
    if [ "$FORCE_REINSTALL" = "1" ]; then
        warn "已是版本目录布局，但指定了 --force-reinstall，继续（不改动现有 releases）"
    elif [ "$MIGRATE_LAYOUT" = "1" ]; then
        warn "已是版本目录布局，--migrate-layout 无需执行，忽略"
        MIGRATE_LAYOUT=0
    else
        cat <<EOF
    检测到本机已经安装过（${CURRENT_LINK} 存在）。
    「首次安装」与「后续更新」是两条不同的路径，混用会把运行中的环境
    改成半新半旧状态。请按目的选择：

      只换程序包（保留配置、自动备份、可回滚）
          sudo ./upgrade.sh <新包.tar.gz>

      确认要重装（保留 conf/ 与 logs/，不动数据库）
          sudo ./install.sh --profile ${PROFILE} --force-reinstall

      彻底重来（会要求输入库名确认后才 DROP）
          sudo ./uninstall.sh --purge-all && sudo ./install.sh --profile ${PROFILE}
EOF
        die "本机已安装，拒绝重复 install"
    fi
elif [ -d "${PREFIX}/maxkey" ] || [ -d "${PREFIX}/maxkey_mgt" ]; then
    if [ "$MIGRATE_LAYOUT" = "1" ]; then
        info "检测到旧布局（${PREFIX}/maxkey 直接位于根下），将原地转换为版本目录"
    else
        die "检测到旧布局（${PREFIX}/maxkey 直接位于根下）。
      转换为版本目录布局请加 --migrate-layout（保留 conf/ 与 logs/，失败不删旧目录）。
      或先 ./uninstall.sh --purge 再全新安装（不会删库）。"
    fi
fi

# ---------------------------------------------------------------- 用户 ----
say "运行用户 ${RUN_USER}"
if id "$RUN_USER" >/dev/null 2>&1; then
    info "用户已存在，跳过"
else
    run useradd --system --home-dir "$PREFIX" --shell /sbin/nologin "$RUN_USER"
    info "已创建系统用户 ${RUN_USER}（nologin，仅用于跑进程）"
fi

# ------------------------------------------------------- 共享目录与 jre ----
say "共享目录"
run mkdir -p "$PREFIX" "$REL_DIR" "$BK_DIR" "$RUN_DIR"
for d in portal mgt; do
    run mkdir -p "${LOG_DIR}/${d}"
done
run chown -R "${RUN_USER}:${RUN_USER}" "$LOG_DIR" "$RUN_DIR"
run chmod 750 "$LOG_DIR" "$RUN_DIR"
info "logs/{portal,mgt}、run 就绪（属主 ${RUN_USER}）"

# 内置 jre 共享一份：64MB，不随每个版本复制。JDK 升级只改这一处。
if [ -d "${HERE}/jre" ]; then
    if [ -x "${JRE_DIR}/bin/java" ]; then
        info "共享 jre 已存在，复用（${JRE_DIR}）"
    else
        say "安装内置 jre 到 ${JRE_DIR}（64MB，跨版本共享）"
        run cp -a "${HERE}/jre" "${JRE_DIR}"
    fi
elif [ -x "${JRE_DIR}/bin/java" ]; then
    info "包内无 jre，沿用已安装的 ${JRE_DIR}"
else
    warn "包内无 jre 且 ${JRE_DIR} 不存在，将依赖系统 JDK 21+（preflight 会检查）"
fi

# ------------------------------------------------- 旧布局原地转换（可选） ----
# 安全前提：先把旧目录整体复制到目标 release，确认 jar 到位后才删旧目录。
# 中途失败时旧目录仍然完整，不会出现"半个环境"。
if [ "$MIGRATE_LAYOUT" = "1" ]; then
    say "旧布局 → 版本目录（--migrate-layout）"

    LEGACY_JAR=$(ls -1 "${PREFIX}"/maxkey/maxkey-boot-*.jar 2>/dev/null | head -1 || true)
    LEGACY_VER=""
    if [ -n "$LEGACY_JAR" ]; then
        LEGACY_VER=$(basename "$LEGACY_JAR" | sed -E 's/^maxkey-boot-(.*)\.jar$/\1/')
    fi
    [ -n "$LEGACY_VER" ] || LEGACY_VER="legacy-$(date +%Y%m%d%H%M%S)"

    TARGET_REL="${REL_DIR}/${LEGACY_VER}"
    info "旧版本识别为 ${LEGACY_VER}"
    [ -d "$TARGET_REL" ] && die "目标版本目录已存在: ${TARGET_REL}（避免覆盖，请先确认）"

    run mkdir -p "$TARGET_REL"
    for d in maxkey maxkey_mgt web bin sql; do
        [ -d "${PREFIX}/${d}" ] || continue
        run cp -a "${PREFIX}/${d}" "${TARGET_REL}/"
    done
    # 旧包里没有的目录从新包补（否则 maxkeyctl.sh 缺失会导致切软链后起不来）
    [ -d "${TARGET_REL}/bin" ] || run cp -a "${HERE}/bin" "${TARGET_REL}/"
    [ -d "${TARGET_REL}/sql" ] || run cp -a "${HERE}/sql" "${TARGET_REL}/"

    # 存量日志搬到共享日志目录（保留历史，便于回溯升级前的问题）
    for pair in "maxkey:portal" "maxkey_mgt:mgt"; do
        src="${PREFIX}/${pair%%:*}/logs"
        dst="${LOG_DIR}/${pair##*:}"
        if [ -d "$src" ] && [ "$DRY_RUN" = "0" ]; then
            n=$(find "$src" -maxdepth 1 -type f -name '*.log*' 2>/dev/null | wc -l)
            if [ "$n" -gt 0 ]; then
                cp -a "$src"/. "$dst"/ 2>/dev/null || warn "部分旧日志复制失败（不影响启动）"
                info "已搬 ${n} 个存量日志文件 ${src} -> ${dst}"
            fi
        fi
    done

    # 校验：两个 jar 必须在目标目录里，否则中止且不删旧目录
    if [ "$DRY_RUN" = "0" ]; then
        ls -1 "${TARGET_REL}"/maxkey/maxkey-boot-*.jar >/dev/null 2>&1 || die "portal jar 未复制成功，已中止（旧目录未删除）"
        ls -1 "${TARGET_REL}"/maxkey_mgt/maxkey-mgt-boot-*.jar >/dev/null 2>&1 || die "mgt jar 未复制成功，已中止（旧目录未删除）"

        rm -rf "${TARGET_REL}/maxkey/logs" "${TARGET_REL}/maxkey_mgt/logs" "${TARGET_REL}/conf"
        ln -sfn "${LOG_DIR}/portal" "${TARGET_REL}/maxkey/logs"
        ln -sfn "${LOG_DIR}/mgt"    "${TARGET_REL}/maxkey_mgt/logs"
        ln -sfn "${CONF_DIR}"       "${TARGET_REL}/conf"

        for d in maxkey maxkey_mgt web; do
            rm -rf "${PREFIX:?}/${d}"
        done
        ln -sfn "$TARGET_REL" "${CURRENT_LINK}"
        info "current -> ${TARGET_REL}"
    else
        printf '    [dry-run] 建软链 current -> %s 并删除旧布局目录\n' "$TARGET_REL"
    fi
    MIGRATED=1
else
    MIGRATED=0
fi

# ------------------------------------------------------ 安装新版本目录 ----
RELEASE_DIR="${REL_DIR}/${PKG_VERSION}"
CUR_TARGET=""
[ -L "$CURRENT_LINK" ] && CUR_TARGET=$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)

if [ "$MIGRATED" = "1" ] && [ "$RELEASE_DIR" = "$CUR_TARGET" ]; then
    info "本次包版本与迁移出的版本相同，复用 ${RELEASE_DIR}"
fi

say "安装程序文件到 ${RELEASE_DIR}"
run mkdir -p "$RELEASE_DIR"

# 已在用的版本目录不重写程序文件（那是回滚目标，不能被覆盖）
if [ "$RELEASE_DIR" = "$CUR_TARGET" ] && [ -n "$CUR_TARGET" ]; then
    warn "该版本目录正在使用中，跳过程序文件覆盖（避免破坏回滚目标）"
else
    for d in maxkey maxkey_mgt web bin sql; do
        [ -e "${HERE}/${d}" ] || continue
        # 先复制到 .new 再整体替换：避免"删了旧的、复制却失败"的半残状态
        run rm -rf "${RELEASE_DIR}/${d}.new"
        run cp -a "${HERE}/${d}" "${RELEASE_DIR}/${d}.new"
        run rm -rf "${RELEASE_DIR}/${d}"
        run mv "${RELEASE_DIR}/${d}.new" "${RELEASE_DIR}/${d}"
    done

    # release 内的 conf/logs 指向共享目录：
    # maxkeyctl.sh 用相对路径 logs/，这样日志天然落到共享位置，
    # 不必改 jar 内的 log4j2.xml（改它要动源码并重打包）。
    if [ "$DRY_RUN" = "0" ]; then
        rm -rf "${RELEASE_DIR}/maxkey/logs" "${RELEASE_DIR}/maxkey_mgt/logs" "${RELEASE_DIR}/conf"
        ln -sfn "${LOG_DIR}/portal" "${RELEASE_DIR}/maxkey/logs"
        ln -sfn "${LOG_DIR}/mgt"    "${RELEASE_DIR}/maxkey_mgt/logs"
        ln -sfn "${CONF_DIR}"       "${RELEASE_DIR}/conf"
    fi
    rmdir "${RELEASE_DIR}/logs" 2>/dev/null || true
fi

# 属主：程序与配置 root 只读；运行期只写 logs/run/backups
run chown -R root:root "$PREFIX" 2>/dev/null || true
for d in "$LOG_DIR" "$RUN_DIR" "$BK_DIR"; do
    run chown -R "${RUN_USER}:${RUN_USER}" "$d" 2>/dev/null || true
done
run chmod -R go-w "$PREFIX" 2>/dev/null || true
run chmod +x "${RELEASE_DIR}/bin/"*.sh 2>/dev/null || true
info "属主与权限已设置（程序/配置 root 只读，logs/run/backups 归 ${RUN_USER}）"

# ------------------------------------------------------------- 运行时密钥 ----
say "运行时密钥"
run mkdir -p "$ETC_SECRET_DIR"

# DATABASE_PWD：已有则只用不改；没有则交互输入（不回显，不进 shell 历史）
DB_PWD=""
if secret_has DATABASE_PWD; then
    info "DATABASE_PWD 已存在（${SECRET_FILE}），保留"
    DB_PWD=$(secret_read DATABASE_PWD)
    # 必须 export 成 DATABASE_PWD：lib/db.sh 里的 JDBC/ksql 都读这个变量。
    # 踩过的坑：这里只赋给局部变量 DB_PWD，db.sh 拿到的是空口令，
    # ksql 于是进入交互式密码提示（非交互环境直接失败：
    #   fe_sendauth: no password supplied），
    # 而报错位置在"导入种子库"，看起来像种子库或权限问题。
    DATABASE_PWD="$DB_PWD"
    export DATABASE_PWD
elif [ "$DO_DB" = "1" ] || [ "$DO_START" = "1" ]; then
    if [ "$DRY_RUN" = "1" ]; then
        warn "dry-run：跳过口令输入"
    elif [ ! -t 0 ]; then
        die "缺少数据库口令且非交互环境。请先预置：
      install -m 600 -o root -g root /dev/null ${SECRET_FILE}
      printf \"DATABASE_PWD='实际口令'\\n\" >> ${SECRET_FILE}"
    else
        printf '    请输入数据库口令（用户 %s，不回显）: ' "${DATABASE_USER:-maxkey}"
        stty -echo 2>/dev/null || true
        read -r DB_PWD
        stty echo 2>/dev/null || true
        printf '\n'
        [ -n "$DB_PWD" ] || die "口令为空，已中止"
        secret_set DATABASE_PWD "$DB_PWD"
        DATABASE_PWD="$DB_PWD"
        export DATABASE_PWD
        info "已写入 ${SECRET_FILE}（600 root:root）"
    fi
fi

# JWT_SECRET：新版改为环境变量注入（原先明文写死在两个 properties 里，
# 打好的 jar 谁都能 unzip 出来伪造任意用户 token）。
# 首次安装生成 512 字符随机值；升级时由 upgrade.sh 从旧 jar 抽出旧值沿用，
# 不会让存量会话失效。
if secret_has JWT_SECRET; then
    info "JWT_SECRET 已存在，保留（改它会让所有已登录会话失效）"
elif [ "$DRY_RUN" = "1" ]; then
    warn "dry-run：将生成新的 JWT_SECRET（512 字符随机 ASCII）"
else
    secret_set JWT_SECRET "$(gen_jwt_secret)"
    info "已生成 JWT_SECRET（512 字符随机，与历史值同形）"
fi
run chmod 600 "$SECRET_FILE" 2>/dev/null || true
run chown root:root "$SECRET_FILE" 2>/dev/null || true

# ------------------------------------------------------------- systemd ----
say "systemd 单元"
# unit 里路径统一写 <prefix>/current/bin/maxkeyctl.sh —— 指向软链而非具体版本，
# 于是切换版本不需要改 unit，也就不需要 daemon-reload。
for u in "${HERE}"/systemd/*.service; do
    [ -e "$u" ] || continue
    name=$(basename "$u")
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] install %s -> %s/%s\n' "$name" "$SYSTEMD_DIR" "$name"
    else
        tmp=$(mktemp)
        sed "s#/opt/maxkey#${PREFIX}#g" "$u" > "$tmp"
        install -m 644 -o root -g root "$tmp" "${SYSTEMD_DIR}/${name}"
        rm -f "$tmp"
    fi
    info "已安装 ${name}"
done
run systemctl daemon-reload
run_sh "systemctl enable ${UNITS} >/dev/null 2>&1 || true"

# ------------------------------------------------------------- logrotate ----
say "日志轮转"
if require_soft logrotate; then
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] 写 %s\n' "$LOGROTATE_FILE"
    else
        cat > "$LOGROTATE_FILE" <<EOF
# MaxKey 日志轮转（由 install.sh 生成，勿手工改）
# 应用内 log4j2 已按天/128MB 轮转；这里兜底 nohup 的 stdout 与残留大文件。
${LOG_DIR}/portal/*.log ${LOG_DIR}/mgt/*.log ${LOG_DIR}/*.out ${LOG_DIR}/*/*.log {
    daily
    rotate ${LOG_KEEP_DAYS:-30}
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    su ${RUN_USER} ${RUN_USER}
}
EOF
        chmod 644 "$LOGROTATE_FILE"
    fi
    info "已写 ${LOGROTATE_FILE}（保留 ${LOG_KEEP_DAYS:-30} 天）"
else
    warn "未安装 logrotate，跳过（应用内 log4j2 仍按天轮转；nohup 输出不会自动清理）"
fi

# ---------------------------------------------------------------- nginx ----
if [ "$DO_NGINX" = "1" ]; then
    say "nginx 站点配置"

    # 端口预检：写文件之前拦住。等到 reload 才发现端口不可用，
    # 失败的 reload 可能连带影响同实例上其它站点。
    if [ "$DRY_RUN" = "0" ] && port_open "${NGINX_TLS_PORT:-443}"; then
        occ=$(port_listener "${NGINX_TLS_PORT:-443}")
        if echo "$occ" | grep -q nginx; then
            warn "端口 ${NGINX_TLS_PORT:-443} 已被 nginx 监听（上次安装的站点），将覆盖"
        else
            die "端口 ${NGINX_TLS_PORT:-443} 被非 nginx 进程占用：
$(printf '%s\n' "$occ" | sed 's/^/      /')"
        fi
    fi

    BACKUP=""
    if [ "$DRY_RUN" = "0" ] && [ -f "$NGINX_SITE" ]; then
        BACKUP=$(mktemp)
        cp -a "$NGINX_SITE" "$BACKUP"
    fi

    run mkdir -p "$NGINX_CONF_DIR"
    run cp -a "${HERE}/nginx/maxkey-proxy.conf" "$NGINX_PROXY"

    # 渲染顺序有坑：必须先换证书路径再换域名。
    # 反过来的话域名先被替换，证书行变成 <新域名>.crt，后一条规则再也匹配不上，
    # nginx 会去加载一个不存在的证书 —— 每次换域名都会踩这个坑。
    RENDERED_SITE=$(mktemp)
    sed -e "s#/etc/nginx/cert/sso\.example\.gov\.cn\.crt#${NGINX_CERT}#g" \
        -e "s#/etc/nginx/cert/sso\.example\.gov\.cn\.key#${NGINX_KEY}#g" \
        -e "s#^    listen       443 ssl;#    listen       ${NGINX_TLS_PORT:-443} ssl;#" \
        -e "s#^    listen       \[::\]:443 ssl;#    listen       [::]:${NGINX_TLS_PORT:-443} ssl;#" \
        -e "s#sso\.example\.gov\.cn#${NGINX_SERVER_NAME}#g" \
        "${HERE}/nginx/maxkey-site.conf" > "$RENDERED_SITE"

    if grep -q 'sso\.example\.gov\.cn' "$RENDERED_SITE"; then
        rm -f "$RENDERED_SITE"
        die "站点配置渲染后仍残留占位域名，请检查 nginx/maxkey-site.conf"
    fi
    # 目标端口就是 443 时替换前后相同，grep 必然命中 —— 那是正常的，
    # 只有目标端口非 443 才需要校验（否则每次标准端口部署都有假告警）。
    if [ "${NGINX_TLS_PORT:-443}" != "443" ] && grep -qE '^\s+listen\s+443 ssl;' "$RENDERED_SITE"; then
        rm -f "$RENDERED_SITE"
        die "站点配置的 IPv4 端口未被替换（期望 ${NGINX_TLS_PORT}，实际仍是 443）"
    fi

    # 同 server_name 双站点：nginx 只采用先加载者，表现为"改了不生效"，极难查
    # 冲突判定要排除两类"自己人"：
    #   1) 本文件自身
    #   2) 本文件的历史备份 ${NGINX_SITE}.bak-<时间戳>
    # 踩过的坑：只排除自身时，第二次安装会检出一堆 .bak 文件并报冲突，
    # 于是"重装"这条路自己把自己锁死 —— 而 nginx 实际只加载 *.conf，
    # .bak-xxx 根本不参与加载，不该算冲突。
    conflict=$(grep -rlE "server_name[^;]*\b${NGINX_SERVER_NAME//./\\.}\b" "$NGINX_CONF_DIR" 2>/dev/null \
               | grep -v "^${NGINX_SITE}$" \
               | grep -v "^${NGINX_SITE}\.bak-" \
               | grep -v '\.bak-[0-9]' || true)
    if [ -n "$conflict" ]; then
        rm -f "$RENDERED_SITE"
        warn "以下文件已占用 server_name ${NGINX_SERVER_NAME}："
        printf '%s\n' "$conflict" | sed 's/^/      /'
        die "server_name 冲突，已中止（未改动任何 nginx 文件）"
    fi

    run cp "$RENDERED_SITE" "$NGINX_SITE"
    rm -f "$RENDERED_SITE"
    info "已写入 ${NGINX_SITE} 与 ${NGINX_PROXY}"

    if [ "$DRY_RUN" = "0" ]; then
        if ! nginx -t 2>/tmp/nginx-t.err; then
            warn "nginx -t 未通过，回滚站点文件："
            sed 's/^/      /' /tmp/nginx-t.err
            rm -f "$NGINX_SITE"
            [ -n "$BACKUP" ] && cp -a "$BACKUP" "$NGINX_SITE"
            die "nginx 配置校验失败，已回滚（检查证书路径与端口）"
        fi
        info "nginx -t 通过"

        # reload 后必须真的验证端口在监听：nginx -s reload 绑不上端口时
        # 也常返回 0，只把 [emerg] 写进 error.log，脚本会误报成功。
        ERR_LOG=""
        for f in /var/log/nginx/error.log /var/log/nginx/error_log; do
            [ -f "$f" ] && { ERR_LOG="$f"; break; }
        done
        if [ -n "$ERR_LOG" ]; then ERR_MARK=$(wc -l < "$ERR_LOG" 2>/dev/null || echo 0); else ERR_MARK=0; fi

        nginx -s reload 2>/dev/null || systemctl reload nginx 2>/dev/null || true
        RELOAD_OK=0
        nginx -t >/dev/null 2>&1 && RELOAD_OK=1
        sleep 2

        PORT_FAIL=""
        if [ -n "$ERR_LOG" ]; then
            NEW_ERRS=$(tail -n +$((ERR_MARK + 1)) "$ERR_LOG" 2>/dev/null | grep -E '\[emerg\]|could not bind' || true)
            if [ -n "$NEW_ERRS" ]; then
                PORT_FAIL="错误日志出现 emerg"
                printf '%s\n' "$NEW_ERRS" | head -5 | sed 's/^/      /'
            fi
        fi
        if [ -z "$PORT_FAIL" ] && ! port_open "${NGINX_TLS_PORT:-443}"; then
            PORT_FAIL="端口 ${NGINX_TLS_PORT:-443} 未监听"
        fi

        if [ "$RELOAD_OK" != "1" ] || [ -n "$PORT_FAIL" ]; then
            warn "nginx 未能按新配置生效：${PORT_FAIL:-reload 失败}"
            rm -f "$NGINX_SITE"
            [ -n "$BACKUP" ] && cp -a "$BACKUP" "$NGINX_SITE"
            nginx -t >/dev/null 2>&1 && { systemctl restart nginx 2>/dev/null || nginx -s reload 2>/dev/null; } || true
            die "站点配置未生效，已回滚。常见原因：端口被占、证书不可读"
        fi
        info "nginx 已 reload，端口 ${NGINX_TLS_PORT:-443} 确认监听中"
    fi
    [ -n "${BACKUP:-}" ] && rm -f "$BACKUP"
else
    skip "已指定 --no-nginx，跳过 nginx 接入"
fi

# ---------------------------------------------------------------- 建库 ----
if [ "$DO_DB" = "1" ]; then
    say "初始化数据库"
    # shellcheck source=lib/db.sh
    . "${HERE}/lib/db.sh"

    # 工具与驱动取自**当前部署包**（${HERE}/sql/lib），不取 PREFIX/current：
    # 首次安装时 current 还没建出来，取不到就会报找不到 MaxKeySql。
    MAXKEY_SQL_DIR="${HERE}/sql"

    SEED_SRC="${RELEASE_DIR}/sql/maxkey-seed.sql"
    [ -f "$SEED_SRC" ] || die "缺少种子库脚本: ${SEED_SRC}"

    EXISTING=$(db_table_count || echo 0)
    EXPECT=$(grep -cE '^\s*CREATE TABLE' "$SEED_SRC" 2>/dev/null || echo '?')
    info "当前库表数量: ${EXISTING:-0} / 种子库 ${EXPECT}"

    if [ "${EXISTING:-0}" -ge 40 ]; then
        if [ "$IMPORT_SEED" = "1" ]; then
            warn "库中已有 ${EXISTING} 张表，仍按 --import-seed 导入（已存在的表会报错，不会覆盖数据）"
        else
            die "库中已有 ${EXISTING} 张表，不是空库。
      只想补种子数据：加 --import-seed
      要重建：请先备份后手工执行 DROP SCHEMA public CASCADE; CREATE SCHEMA public;
      本脚本永不自动 DROP。"
        fi
    fi

    # 种子库里有三行管理端 CAS 应用按域名生成（loginurl/service），
    # 仓库里是演示域名，直接导入会让门户「后台」菜单指向错误地址。
    SEED_DEFAULT="https://sso.maxkey.top"
    if grep -qF "$SEED_DEFAULT" "$SEED_SRC"; then
        # 渲染结果放**包内 sql/**（不放 RELEASE_DIR/sql/）：
        # 踩过的坑 —— 写在 RELEASE_DIR 下时，若该 release 目录随后被
        # "装程序文件"那一步整体替换，渲染文件就消失了，
        # 后续导入报 "No such file or directory"，而错误被 ksql 的 stderr
        # 与 set -e 的退出码掩盖，只看到一句"导入失败"。
        SEED_RENDERED="${HERE}/sql/maxkey-seed.rendered.sql"
        if [ "$DRY_RUN" = "1" ]; then
            printf '    [dry-run] 按 %s 渲染种子库 -> %s\n' "$MAXKEY_PUBLIC_URL" "$SEED_RENDERED"
        else
            sed "s#${SEED_DEFAULT}#${MAXKEY_PUBLIC_URL}#g" "$SEED_SRC" > "$SEED_RENDERED" \
                || die "渲染种子库失败（写 ${SEED_RENDERED}）"
            [ -s "$SEED_RENDERED" ] || die "渲染后的种子库为空: ${SEED_RENDERED}"
            info "种子库已按 ${MAXKEY_PUBLIC_URL} 渲染管理端应用地址"
            SEED_SRC="$SEED_RENDERED"
        fi
    fi

    SEED_LOG=$(mktemp)
    # 必须 `set -o pipefail`（本脚本开头已设）或显式取 PIPESTATUS，
    # 否则 `cmd | tee` 的退出码是 tee 的（永远 0）——
    # 于是导入失败会被判成成功，脚本继续往下走，
    # 最后表现为"装完了但一张表都没有"，比直接失败难查得多。
    if db_import_seed "$SEED_SRC" 2>&1 | tee "$SEED_LOG" && [ "${PIPESTATUS[0]}" -eq 0 ]; then
        info "种子库导入完成（44 张表 + admin/maxkey 初始账号）"
        warn "初始账号 admin / maxkey —— 上线前请立即改密"
        rm -f "$SEED_LOG"
    else
        cat <<EOF

[1;31m种子库导入失败[0m。ksql 的输出：

EOF
        sed 's/^/      /' "$SEED_LOG"
        cat <<EOF

  常见原因：
    1. 库不是空的（已有部分表）—— 会报 "already exists"，数据不会被覆盖
    2. 编码/Locale 不匹配 —— 种子库按 UTF-8 生成
    3. 权限不足（需要目标 schema 的 CREATE 权限）
  处理：先确认库状态，必要时
      ksql -U <dba> -d maxkey -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
  再重试。导入文件保留在：
      ${SEED_SRC}
EOF
        rm -f "$SEED_LOG"
        exit 1
    fi
fi

# ------------------------------------------------------- 切换 current ----
say "切换 current"
run ln -sfn "$RELEASE_DIR" "${CURRENT_LINK}"
if [ "$DRY_RUN" = "0" ]; then
    info "current -> $(readlink -f "$CURRENT_LINK")"
fi

# --------------------------------------------------------- 启动与自检 ----
if [ "$DO_START" = "1" ]; then
    say "启动服务"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] systemctl restart %s\n' "$UNITS"
    else
        systemctl restart $UNITS
        info "systemctl restart 已执行"
        if ! health_check "${PORTAL_PORT}" "${MGT_PORT}" \
                "${MAXKEY_PUBLIC_URL}" "${NGINX_SERVER_NAME}" "${NGINX_TLS_PORT:-443}"; then
            cat <<EOF

服务已安装，但健康检查未通过。按顺序排查：

  1. 环境与配置自检
       ${PREFIX}/bin/preflight.sh
  2. 数据库口令 / 连通性
       sudo vi ${SECRET_FILE}
       systemctl restart ${UNITS}
  3. 库里没有表（漏了 --init-db）
       sudo ./install.sh --profile ${PROFILE} --init-db --force-reinstall
  4. 端口被占
       ss -lntp | grep -E ':${PORTAL_PORT}|:${MGT_PORT}'
EOF
            exit 1
        fi
    fi
else
    skip "已指定 --no-start，服务未启动"
fi

# ---------------------------------------------------------------- 收尾 ----
say "安装完成"
cat <<EOF
    版本     : ${PKG_VERSION}
    路径     : ${PREFIX}
    current  : ${RELEASE_DIR}
    对外地址 : ${MAXKEY_PUBLIC_URL}
    运行用户 : ${RUN_USER}

  常用操作：
    状态      ${PREFIX}/bin/maxkeyctl.sh status
    自检      ${PREFIX}/bin/preflight.sh
    日志      tail -f ${LOG_DIR}/portal/maxkey.log
    更新      sudo ./upgrade.sh <新包.tar.gz>
    回滚      sudo ./rollback.sh --list
    验证      sudo ./verify.sh --expect installed
    卸载      sudo ./uninstall.sh [--purge] [--purge-all]

  首次上线还差两步：
    1. 浏览器打开 ${MAXKEY_PUBLIC_URL}/maxkey/ ，admin/maxkey 登录后立即改密
    2. 管理端「机构」的 domain 改成 ${NGINX_SERVER_NAME}
EOF
