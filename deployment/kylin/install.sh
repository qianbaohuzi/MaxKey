#!/bin/bash
############################################################################
#  install.sh —— 把部署包落到目标机（可重复执行，幂等）
#
#  做什么：
#    1. 创建专用系统用户 maxkey（非 root 运行）
#    2. 安装文件到 /opt/maxkey（保留 conf/ 与 logs/，不覆盖现场配置）
#    3. 安装 systemd 单元并开机自启
#    4. 生成并安装 nginx 站点文件（公共 nginx 场景，只加一个 conf.d 文件）
#    5. nginx -t 校验通过后才 reload（失败自动回滚刚放进去的文件）
#    6. 建库（可选，--init-db）
#
#  刻意**不做**的事：
#    * 不启动服务。落地后应先跑 bin/preflight.sh 与 nginx -t，再手工 start。
#    * 不改目标机已有的 nginx 站点文件。MaxKey 只新增自己的 conf.d 文件。
#    * 不写入数据库口令到任何受版本控制的文件。
#
#  用法（需 root）：
#      ./install.sh                  # 安装文件 + systemd + nginx 配置（不 reload 也行）
#      ./install.sh --dry-run        # 只打印将要做的事，不落盘
#      ./install.sh --no-nginx       # 跳过 nginx 部分（现场自己接）
#      ./install.sh --init-db        # 额外执行建库脚本
#      ./install.sh --prefix /opt/maxkey
#
#  卸载：./uninstall.sh
############################################################################

set -eu

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ------------------------------------------------------------------ 参数 ----
PREFIX=/opt/maxkey
RUN_USER=maxkey
DO_NGINX=1
DO_DB=0
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)  DRY_RUN=1 ;;
        --no-nginx) DO_NGINX=0 ;;
        --init-db)  DO_DB=1 ;;
        --prefix)   shift; PREFIX=${1:?--prefix 需要路径} ;;
        -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "未知参数: $1"; exit 2 ;;
    esac
    shift
done

NGINX_CONF_DIR=/etc/nginx/conf.d
NGINX_SITE="${NGINX_CONF_DIR}/maxkey.conf"
NGINX_PROXY=/etc/nginx/maxkey-proxy.conf
SYSTEMD_DIR=/etc/systemd/system
SECRET_DIR=/etc/maxkey
SECRET_FILE="${SECRET_DIR}/maxkey-secret.env"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# 统一的"执行或只打印"入口，让 --dry-run 能覆盖所有写操作
run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# ------------------------------------------------------------ 前置检查 ----
say "前置检查"

# --dry-run 不落盘，允许非 root 演练（便于在跳板机/CI 上预校验配置）
if [ "$DRY_RUN" = "0" ]; then
    [ "$(id -u)" -eq 0 ] || die "需要 root 权限运行（用于创建用户、写 /etc/nginx 与 systemd）"
else
    [ "$(id -u)" -eq 0 ] || warn "非 root 的 dry-run：仅打印将要执行的操作"
fi

for f in "${HERE}/maxkey" "${HERE}/maxkey_mgt" "${HERE}/web" "${HERE}/conf/maxkey.env"; do
    [ -e "$f" ] || die "部署包不完整，缺少: $f"
done
info "部署包结构完整"

command -v nginx >/dev/null 2>&1 || {
    if [ "$DO_NGINX" = "1" ]; then
        die "未找到 nginx 命令。若现场用别的反向代理，请加 --no-nginx 跳过"
    fi
    warn "未找到 nginx，将跳过 nginx 相关步骤"
    DO_NGINX=0
}

# ------------------------------------------------------------ 配置文件 ----
say "读取 conf/maxkey.env"
# shellcheck disable=SC1091
( set -a; . "${HERE}/conf/maxkey.env" ) || die "conf/maxkey.env 语法错误，执行 bash -n 检查"
set -a
# shellcheck disable=SC1091
. "${HERE}/conf/maxkey.env"
set +a

: "${MAXKEY_PUBLIC_URL:=}"
if [ -z "$MAXKEY_PUBLIC_URL" ] || echo "$MAXKEY_PUBLIC_URL" | grep -q "example\.gov\.cn"; then
    die "请先修改 conf/maxkey.env 里的 MAXKEY_PUBLIC_URL / SERVER_DOMAIN / NGINX_SERVER_NAME 等占位值"
fi
info "对外地址 : ${MAXKEY_PUBLIC_URL}"
info "安装路径 : ${PREFIX}"
info "运行用户 : ${RUN_USER}"

# 校验对外地址与 nginx 配置一致（不一致必然导致 SSO 回跳失败）
if [ "$DO_NGINX" = "1" ]; then
    pub_host=$(echo "$MAXKEY_PUBLIC_URL" | sed -E 's#^[a-zA-Z]+://##; s#[:/].*$##')
    pub_port=$(echo "$MAXKEY_PUBLIC_URL" | sed -nE 's#^[a-zA-Z]+://[^:/]+:([0-9]+).*#\1#p')
    : "${pub_port:=443}"
    [ "$pub_host" = "${NGINX_SERVER_NAME:-}" ] || \
        die "MAXKEY_PUBLIC_URL 主机($pub_host) 与 NGINX_SERVER_NAME(${NGINX_SERVER_NAME:-未配置}) 不一致"
    [ "$pub_port" = "${NGINX_TLS_PORT:-443}" ] || \
        die "MAXKEY_PUBLIC_URL 端口($pub_port) 与 NGINX_TLS_PORT(${NGINX_TLS_PORT:-443}) 不一致"
    info "地址与 nginx 配置一致"

    for f in "${NGINX_CERT:-}" "${NGINX_KEY:-}"; do
        [ -n "$f" ] || die "NGINX_CERT / NGINX_KEY 未配置"
        if [ ! -r "$f" ]; then
            if [ "$DRY_RUN" = "1" ]; then
                warn "证书不可读（dry-run 继续）: $f"
            else
                die "证书文件不可读: $f（需保证 nginx 进程与 root 可读）"
            fi
        fi
    done
    info "证书检查完成"
fi

# ---------------------------------------------------------------- 用户 ----
say "创建运行用户 ${RUN_USER}"
if id "$RUN_USER" >/dev/null 2>&1; then
    info "用户已存在，跳过"
else
    run useradd --system --home-dir "$PREFIX" --shell /sbin/nologin "$RUN_USER"
    info "已创建系统用户 ${RUN_USER}"
fi

# ---------------------------------------------------------------- 文件 ----
say "安装文件到 ${PREFIX}"
run mkdir -p "$PREFIX"

# 关键：conf/ 与 logs/ 不覆盖。现场改过的域名、数据库地址都在这里，
# 覆盖会让升级变成"配置回退到模板值"，是最常见的升级事故。
for d in maxkey maxkey_mgt web bin nginx systemd sql; do
    [ -e "${HERE}/${d}" ] || continue
    run rm -rf "${PREFIX}/${d}.new"
    run cp -a "${HERE}/${d}" "${PREFIX}/${d}.new"
    run rm -rf "${PREFIX}/${d}"
    run mv "${PREFIX}/${d}.new" "${PREFIX}/${d}"
done

# 配置文件：已存在则备份，不覆盖
if [ -f "${PREFIX}/conf/maxkey.env" ]; then
    warn "已存在 ${PREFIX}/conf/maxkey.env，保留现场配置（新模板存为 .new）"
    run cp -a "${HERE}/conf/maxkey.env" "${PREFIX}/conf/maxkey.env.new"
else
    run mkdir -p "${PREFIX}/conf"
    run cp -a "${HERE}/conf/maxkey.env" "${PREFIX}/conf/maxkey.env"
    info "已写入配置模板 ${PREFIX}/conf/maxkey.env"
fi
[ -f "${HERE}/conf/maxkey-secret.env.example" ] && \
    run cp -a "${HERE}/conf/maxkey-secret.env.example" "${PREFIX}/conf/" || true

run mkdir -p "${PREFIX}/logs" "${PREFIX}/run" "${PREFIX}/maxkey/logs" "${PREFIX}/maxkey_mgt/logs"
run chmod +x "${PREFIX}/bin/"*.sh 2>/dev/null || true

# 目录属主：运行时只需要写 logs 与 run，其余只读即可
run chown -R root:root "$PREFIX"
for d in logs run maxkey/logs maxkey_mgt/logs; do
    run chown -R "${RUN_USER}:${RUN_USER}" "${PREFIX}/${d}"
done
run chmod -R go-w "$PREFIX"
info "属主与权限已设置（配置与程序 root 只读，运行目录归 ${RUN_USER}）"

# ------------------------------------------------------------- systemd ----
say "安装 systemd 单元"
for u in "${HERE}"/systemd/*.service; do
    [ -e "$u" ] || continue
    name=$(basename "$u")
    # 单元文件里路径写死 /opt/maxkey，用非默认 prefix 时必须替换
    if [ "$PREFIX" != "/opt/maxkey" ]; then
        run sed "s#/opt/maxkey#${PREFIX}#g" "$u" > "${SYSTEMD_DIR}/${name}"
    else
        run cp -a "$u" "${SYSTEMD_DIR}/${name}"
    fi
    info "已安装 ${name}"
done
run systemctl daemon-reload
run systemctl enable maxkey-portal.service maxkey-mgt.service >/dev/null 2>&1 || true

# ------------------------------------------------------------- 口令注入 ----
say "数据库口令"
run mkdir -p "$SECRET_DIR"
if [ -f "$SECRET_FILE" ]; then
    info "已存在 ${SECRET_FILE}，保留"
else
    run install -m 600 -o root -g root /dev/null "$SECRET_FILE"
    run tee "$SECRET_FILE" >/dev/null <<'SECRET_EOF'
# MaxKey 数据库口令（仅此一行，600 root:root，禁止入库）
DATABASE_PWD='在此填写实际口令'
SECRET_EOF
    warn "已创建 ${SECRET_FILE} 模板，**必须填入真实口令**，否则服务会拒绝启动"
fi

# ---------------------------------------------------------------- 建库 ----
if [ "$DO_DB" = "1" ]; then
    say "初始化数据库"
    # Kingbase 的客户端工具名可能是 ksql 或 ksqlsh
    KSQL_BIN=$(command -v ksql 2>/dev/null || command -v ksqlsh 2>/dev/null || true)
    if [ -z "$KSQL_BIN" ]; then
        warn "未找到 ksql/ksqlsh，跳过建库。请手工执行:"
        warn "  ksql -U ${DATABASE_USER:-maxkey} -d <库名> -f ${PREFIX}/sql/maxkey-seed.sql"
    else
        info "使用 $KSQL_BIN 导入 sql/maxkey-seed.sql（表结构 44 张 + admin 初始账号）"
        info "初始账号 admin / maxkey —— 上线前请立即修改"
        # 实际口令由运维提供，避免在脚本里出现明文
        if [ "$DRY_RUN" = "0" ]; then
            warn "建库需要交互输入口令，本条不在自动流程内执行。请手工执行："
            warn "  $KSQL_BIN -U ${DATABASE_USER:-maxkey} -d <库名> -f ${PREFIX}/sql/maxkey-seed.sql"
        fi
    fi
fi

# ---------------------------------------------------------------- nginx ----
if [ "$DO_NGINX" = "1" ]; then
    say "安装 nginx 站点配置（公共 nginx 场景）"

    # 记录旧文件以便失败回滚
    BACKUP=""
    if [ -f "$NGINX_SITE" ]; then
        BACKUP=$(mktemp)
        cp -a "$NGINX_SITE" "$BACKUP"
    fi

    run mkdir -p "$NGINX_CONF_DIR"
    run cp -a "${HERE}/nginx/maxkey-proxy.conf" "$NGINX_PROXY"

    # 用环境值渲染站点配置。占位符替换只针对我们自己的模板，
    # 绝不改动现场其他站点文件。
    # 渲染顺序有讲究：**先替换证书路径，再替换域名**。
    # 反过来的话，域名先被 sed 改掉，证书行的
    #   /etc/nginx/cert/sso.example.gov.cn.crt
    # 就变成了 /etc/nginx/cert/<新域名>.crt，后面的证书替换规则再也匹配不上，
    # 最终 ngixn 会去加载一个不存在的证书文件。这个顺序不能调换。
    RENDERED=$(mktemp)
    # 注：IPv6 那一行的方括号在 sed 正则里必须写成 \[ \]，
    # 而 shell 双引号里 \[ 会被解释成字面量 \[，所以需要写作 \\\[ 。
    # 为避免多层转义的坑，这里改用两条独立规则：先按 "listen" 行整体重写。
    sed -e "s#/etc/nginx/cert/sso\.example\.gov\.cn\.crt#${NGINX_CERT}#g" \
        -e "s#/etc/nginx/cert/sso\.example\.gov\.cn\.key#${NGINX_KEY}#g" \
        -e "s#^    listen       443 ssl;#    listen       ${NGINX_TLS_PORT:-443} ssl;#" \
        -e "s#^    listen       \[::\]:443 ssl;#    listen       [::]:${NGINX_TLS_PORT:-443} ssl;#" \
        -e "s#sso\.example\.gov\.cn#${NGINX_SERVER_NAME}#g" \
        "${HERE}/nginx/maxkey-site.conf" > "$RENDERED"

    # 渲染后自检：确认端口与证书都换成了现场值，避免"看起来成功、实际仍指向模板"
    if grep -q "sso\.example\.gov\.cn" "$RENDERED"; then
        rm -f "$RENDERED"
        die "站点配置渲染后仍残留占位域名，请检查 nginx/maxkey-site.conf"
    fi
    if grep -qE "^\s+listen\s+443 ssl;" "$RENDERED"; then
        rm -f "$RENDERED"
        warn "站点配置的 IPv4 端口未被替换（可能模板格式已变）"
    fi


    # 若现场已有同 server_name + 同端口的站点，直接接入会产生
    # "conflicting server name" 且实际生效的是先加载的那个 —— 必须先报错。
    if conflict=$(grep -rlE "server_name[^;]*\b${NGINX_SERVER_NAME//./\\.}\b" "$NGINX_CONF_DIR" 2>/dev/null | grep -v "^${NGINX_SITE}$" || true); [ -n "$conflict" ]; then
        warn "以下文件已占用 server_name ${NGINX_SERVER_NAME}："
        echo "$conflict" | sed 's/^/      /'
        warn "同域名双站点会导致 nginx 只采用先加载者。请先停用/移除对方站点配置，"
        warn "或改用不同的 NGINX_SERVER_NAME。"
        rm -f "$RENDERED"
        die "检测到 server_name 冲突，已中止（未改动任何 nginx 文件）"
    fi

    run cp "$RENDERED" "$NGINX_SITE"
    rm -f "$RENDERED"
    info "已写入 $NGINX_SITE 与 $NGINX_PROXY"

    if [ "$DRY_RUN" = "0" ]; then
        if nginx -t 2>/tmp/nginx-t.err; then
            info "nginx -t 通过"
            if nginx -s reload 2>/dev/null || systemctl reload nginx 2>/dev/null; then
                info "nginx 已 reload"
            else
                warn "reload 失败，请手工执行: nginx -s reload"
            fi
        else
            warn "nginx -t 未通过，正在回滚刚安装的站点文件："
            sed 's/^/      /' /tmp/nginx-t.err
            rm -f "$NGINX_SITE"
            if [ -n "$BACKUP" ]; then cp -a "$BACKUP" "$NGINX_SITE"; fi
            die "nginx 配置校验失败，已回滚。请检查证书路径与端口占用"
        fi
    fi
    [ -n "$BACKUP" ] && rm -f "$BACKUP"
fi

# ---------------------------------------------------------------- 收尾 ----
say "完成"
cat <<EOF
    安装路径 : ${PREFIX}
    运行用户 : ${RUN_USER}
    对外地址 : ${MAXKEY_PUBLIC_URL}

  接下来请按顺序执行（本次安装未启动任何服务）：

    1. 填写数据库口令（必做，否则拒绝启动）
         vi ${SECRET_FILE}          # 600 root:root，仅一行 DATABASE_PWD
         chmod 600 ${SECRET_FILE}

    2. 环境自检（一次暴露所有阻塞项：glibc/架构/字体/DB/端口/nginx）
         ${PREFIX}/bin/preflight.sh

    3. 启动
         ${PREFIX}/bin/maxkeyctl.sh start
         或 systemctl start maxkey-portal maxkey-mgt

    4. 验证
         ${PREFIX}/bin/maxkeyctl.sh status
         curl -sk -H 'Host: ${NGINX_SERVER_NAME:-sso.example.gov.cn}' \\
              ${MAXKEY_PUBLIC_URL}/sign/authz/oauth/v20/.well-known/openid-configuration

    5. 浏览器打开 ${MAXKEY_PUBLIC_URL}/maxkey/
         初始账号 admin / maxkey —— **立即改密**
         并把「机构」的 domain 改成 ${NGINX_SERVER_NAME:-你的域名}
EOF
