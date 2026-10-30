#!/bin/bash
############################################################################
#  common.sh —— install / upgrade / rollback / uninstall / verify 共用函数
#
#  只放"所有脚本都需要、且必须行为一致"的东西：
#    输出格式、--dry-run 包装、root 校验、配置读取与渲染、一致性校验、
#    健康检查、systemd / nginx / logrotate 的装卸。
#
#  为什么集中：这套脚本最怕的是「install 装的东西 uninstall 不知道」。
#  把路径与动作收敛到一处，install/uninstall/verify 三者的口径就不会漂。
#
#  本文件不单独执行，只被 source。要求调用方已 `set -eu`。
############################################################################

# ------------------------------------------------------------ 路径常量 ----
MAXKEY_HOME_DEFAULT=/opt/maxkey

# 这些常量在所有脚本里必须完全一致，故只在这里定义一次。
set_paths() {
    : "${PREFIX:=${MAXKEY_HOME_DEFAULT}}"
    : "${RUN_USER:=maxkey}"
    CONF_DIR="${PREFIX}/conf"
    LOG_DIR="${PREFIX}/logs"
    RUN_DIR="${PREFIX}/run"
    REL_DIR="${PREFIX}/releases"
    BK_DIR="${PREFIX}/backups"
    JRE_DIR="${PREFIX}/jre"
    CURRENT_LINK="${PREFIX}/current"

    ETC_SECRET_DIR=/etc/maxkey
    SECRET_FILE="${ETC_SECRET_DIR}/maxkey-secret.env"

    NGINX_CONF_DIR=/etc/nginx/conf.d
    NGINX_SITE="${NGINX_CONF_DIR}/maxkey.conf"
    NGINX_PROXY=/etc/nginx/maxkey-proxy.conf
    SYSTEMD_DIR=/etc/systemd/system
    LOGROTATE_FILE=/etc/logrotate.d/maxkey
    UNITS="maxkey-portal maxkey-mgt"
}

# ---------------------------------------------------------------- 输出 ----
say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '  \033[32m[ OK ]\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; }
skip() { printf '  \033[33m[SKIP]\033[0m %s\n' "$*"; }

# ------------------------------------------------------------ dry-run ----
# 所有写操作必须经由 run/run_sh，否则 --dry-run 会漏掉某个分支。
# 踩过的坑：`run sed ... > /etc/...` 里 > 由当前 shell 执行，
# 不受 run 保护，dry-run 也会真写文件。写文件一律先渲染到临时文件再 run 搬运。
run() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf '    [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

run_sh() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf '    [dry-run] sh -c %s\n' "$1"
    else
        sh -c "$1"
    fi
}

need_root() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        [ "$(id -u)" -eq 0 ] || warn "非 root 的 dry-run：只打印将要执行的操作"
        return 0
    fi
    [ "$(id -u)" -eq 0 ] || die "需要 root 权限运行（创建用户、写 /etc/nginx 与 systemd、启停服务）"
}

# ---------------------------------------------------------- 包根与版本 ----
# 包根 = 本脚本所在目录的上一级（部署包解压后的根目录）
pkg_root_of() {
    ( cd "$(dirname "$1")/.." && pwd )
}

# 版本号来源优先级：
#   1) manifest.json 里的 version（build-package 生成，含 git sha 与构建时间）
#   2) VERSION 文件
#   3) 目录名 maxkey-deploy-<版本>
resolve_pkg_version() {
    local root=$1 v=""
    if [ -f "${root}/manifest.json" ]; then
        v=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${root}/manifest.json" | head -1)
    fi
    [ -n "$v" ] || { [ -f "${root}/VERSION" ] && v=$(head -1 "${root}/VERSION" | tr -d ' \r'); }
    [ -n "$v" ] || v=$(basename "$root" | sed 's/^maxkey-deploy-//')
    printf '%s' "$v"
}

# ------------------------------------------------------ 配置读取与渲染 ----
# 以 set -a 方式 source 一个 env 文件（变量自动 export）。
# 注意：source 失败必须显式拦截 —— bash 对 `A=x&y` 不报语法错，
# 而是把 & 当后台分隔符，结果 A 为空、y 被当命令执行。
load_env_file() {
    local f=$1
    [ -f "$f" ] || die "配置文件不存在: $f"
    if ! bash -n "$f" 2>/dev/null; then
        die "配置文件语法错误: $f（用 bash -n $f 查看行号）"
    fi
    set -a
    # shellcheck disable=SC1090
    . "$f"
    set +a
}

# 用 profile 覆盖模板里的同名键，生成目标 conf。
#   $1 = 模板（含全部键与注释）  $2 = profile（只写要改的键）  $3 = 输出
#
# 为什么不是"直接用 profile 当配置"：模板里还有大量带解释的默认值
# （DATABASE_COLUMN_ESCAPE_CHAR 这种必须写成单引号包双引号的项），
# 现场需要能看到并修改它们。profile 只负责"这台机器跟别人不一样的部分"。
render_conf() {
    local tpl=$1 profile=$2 out=$3
    [ -f "$tpl" ] || die "配置模板缺失: $tpl"
    [ -f "$profile" ] || die "环境档案缺失: $profile"

    # 用 awk 一次生成，不写中间文件。
    #
    # 为什么不写"先 cp 到 ${out}.tmp 再原地改"：
    # 踩过的真实坑 —— `cp -a` 会把源文件的**属主**一起带过来（部署包里是
    # 构建用户，例如 liwenbiao），而 /tmp 是 sticky 目录且 fs.protected_regular=2，
    # 于是 root 后续用 `> ${out}.tmp` 截断写入时被内核拒绝：
    #     cannot create /tmp/tmp.XXXX.tmp: Permission denied
    # 报错位置在 awk/printf 那行，看起来像"写文件没权限"，极难归因。
    # 现在改成"从模板流式读出 → awk 替换 → 直接写到 out"，全程不产生
    # 属主异常的文件，也不依赖 /tmp 的语义。
    awk -v profile="$profile" '
        BEGIN {
            # 先把 profile 读进内存：只认 KEY=VALUE，跳过注释与空行
            while ((getline line < profile) > 0) {
                sub(/\r$/, "", line)
                if (line ~ /^[[:space:]]*(#|$)/) continue
                eq = index(line, "=")
                if (eq == 0) continue
                k = substr(line, 1, eq - 1)
                v = substr(line, eq + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
                if (k != "") { val[k] = v; seen[k] = 0 }
            }
            close(profile)
        }
        {
            line = $0
            # 匹配 KEY= 行（允许行首空白）
            if (match(line, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/)) {
                k = substr(line, RSTART, RLENGTH)
                gsub(/^[[:space:]]+|=/, "", k)
                if (k in val) {
                    print k "=" val[k]
                    seen[k] = 1
                    next
                }
            }
            print line
        }
        END {
            # profile 里模板没有的键，追加到末尾（模板可能落后于档案）
            for (k in val) {
                if (seen[k] == 0) {
                    print ""
                    print "# 由环境档案补充（模板中无此项）"
                    print k "=" val[k]
                }
            }
        }
    ' "$tpl" > "$out"

    [ -s "$out" ] || die "渲染配置失败（输出为空）: $out"
    chmod 644 "$out" 2>/dev/null || true
}

# 升级时比对新版模板与现场 conf 的键差异，缺的补上（值取模板默认），已有值不动。
# 打印补了哪些键，让人知道"这台机器多了几行"。
conf_sync_missing_keys() {
    local tpl=$1 conf=$2 added=""
    local k
    for k in $(grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$tpl" | tr -d ' =' | sort -u); do
        grep -qE "^[[:space:]]*${k}=" "$conf" && continue
        local def
        def=$(grep -E "^[[:space:]]*${k}=" "$tpl" | head -1 | sed "s/^[[:space:]]*${k}=//")
        # dry-run 下不能真写：这函数由 upgrade.sh 在 dry-run 里也会调用，
        # 裸 >> 会在"只演练"时把现场配置改掉 —— 演练反而造成变更，
        # 是最不该发生的副作用。
        if [ "${DRY_RUN:-0}" = "1" ]; then
            printf '    [dry-run] 将补入配置项 %s=%s\n' "$k" "$def"
        else
            printf '\n# 新版本新增项（升级时补入，值取模板默认，请按现场核对）\n%s=%s\n' "$k" "$def" >> "$conf"
        fi
        added="${added} ${k}"
    done
    [ -n "$added" ] && printf '%s' "$added"
}

# ------------------------------------------------------------ 口令文件 ----
# 只读取，不打印值。输出形如：DATABASE_PWD=xxx
secret_read() {
    local key=$1
    [ -f "$SECRET_FILE" ] || return 1
    # 文件由 root 持有 600；非 root 的 dry-run 读不到是正常的
    local v
    v=$(sed -n "s/^[[:space:]]*${key}=//p" "$SECRET_FILE" 2>/dev/null | head -1 | sed "s/^['\"]//; s/['\"]$//")
    [ -n "$v" ] || return 1
    printf '%s' "$v"
}

secret_has() { secret_read "$1" >/dev/null 2>&1; }

# 写入或更新单个键（保留文件内其它键与注释）
secret_set() {
    local key=$1 val=$2
    run mkdir -p "$ETC_SECRET_DIR"
    if [ ! -f "$SECRET_FILE" ]; then
        run install -m 600 -o root -g root /dev/null "$SECRET_FILE"
        if [ "${DRY_RUN:-0}" != "1" ]; then
            cat > "$SECRET_FILE" <<'EOF'
# MaxKey 运行时密钥（600 root:root，禁止入库、禁止随包分发）
# 由 install.sh 生成或由运维预置；maxkeyctl.sh 与 systemd 单元都读本文件。
EOF
        fi
    fi
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf '    [dry-run] secret_set %s=<隐藏>\n' "$key"
        return 0
    fi
    if grep -qE "^[[:space:]]*${key}=" "$SECRET_FILE"; then
        local tmp
        tmp=$(mktemp)
        awk -v k="$key" -v v="$val" '
            BEGIN { done = 0 }
            $0 ~ "^[[:space:]]*"k"=" { if (!done) { print k"="v; done = 1 } next }
            { print }
        ' "$SECRET_FILE" > "$tmp"
        cat "$tmp" > "$SECRET_FILE"
        rm -f "$tmp"
    else
        printf "%s=%s\n" "$key" "$val" >> "$SECRET_FILE"
    fi
    chmod 600 "$SECRET_FILE"
    chown root:root "$SECRET_FILE" 2>/dev/null || true
}

# 生成 512 字符随机 ASCII 的 JWT 密钥（与历史值同形，避免任何长度假设）
gen_jwt_secret() {
    LC_ALL=C tr -dc 'A-Za-z0-9_-' < /dev/urandom 2>/dev/null | head -c 512
}

# ------------------------------------------------------- 一致性校验 ----
# 换环境最容易出的错不是"漏改"，而是"改得不自洽"：
#   域名与 nginx server_name 不一致 → SSO 回跳失败
#   端口与对外地址不一致         → iss 缺端口，登录成功即被踢回
#   证书路径与域名不对应         → nginx -t 过不了
#   机构 domain 与域名不一致     → 租户识别退回默认机构
# 这些在安装前全部拦下，比装完再查便宜得多。
check_site_consistency() {
    local errs=0

    : "${SERVER_DOMAIN:?环境档案缺少 SERVER_DOMAIN}"
    : "${MAXKEY_PUBLIC_URL:?环境档案缺少 MAXKEY_PUBLIC_URL}"
    : "${NGINX_SERVER_NAME:?环境档案缺少 NGINX_SERVER_NAME}"
    : "${NGINX_CERT:?环境档案缺少 NGINX_CERT}"
    : "${NGINX_KEY:?环境档案缺少 NGINX_KEY}"

    case "$MAXKEY_PUBLIC_URL" in
        http://*|https://*) ;;
        *) bad "MAXKEY_PUBLIC_URL 必须以 http:// 或 https:// 开头（当前: ${MAXKEY_PUBLIC_URL}）"; errs=$((errs+1)) ;;
    esac
    case "$MAXKEY_PUBLIC_URL" in
        */) bad "MAXKEY_PUBLIC_URL 末尾不能带斜杠（否则 iss 与回调地址都会多一个 /）"; errs=$((errs+1)) ;;
    esac
    if echo "$MAXKEY_PUBLIC_URL" | grep -q 'example\.gov\.cn'; then
        bad "MAXKEY_PUBLIC_URL 仍是占位值 ${MAXKEY_PUBLIC_URL}，请在环境档案里改成现场地址"
        errs=$((errs+1))
    fi

    local pub_host pub_port pub_scheme
    pub_host=$(printf '%s' "$MAXKEY_PUBLIC_URL" | sed -E 's#^[a-zA-Z]+://##; s#[:/].*$##')
    pub_scheme=$(printf '%s' "$MAXKEY_PUBLIC_URL" | sed -E 's#^([a-zA-Z]+)://.*#\1#')
    pub_port=$(printf '%s' "$MAXKEY_PUBLIC_URL" | sed -nE 's#^[a-zA-Z]+://[^:/]+:([0-9]+).*#\1#p')
    if [ -z "$pub_port" ]; then
        [ "$pub_scheme" = "https" ] && pub_port=443 || pub_port=80
    fi

    [ "$pub_host" = "$NGINX_SERVER_NAME" ] || {
        bad "对外地址主机(${pub_host}) 与 NGINX_SERVER_NAME(${NGINX_SERVER_NAME}) 不一致"
        errs=$((errs+1))
    }
    [ "$pub_port" = "${NGINX_TLS_PORT:-443}" ] || {
        bad "对外地址端口(${pub_port}) 与 NGINX_TLS_PORT(${NGINX_TLS_PORT:-443}) 不一致"
        errs=$((errs+1))
    }
    [ "$pub_host" = "sso.${SERVER_DOMAIN}" ] || {
        # 不是硬错误：有的现场用单域名（sso 前缀可省），但必须明确知道后果
        warn "对外地址主机(${pub_host}) 与 SERVER_DOMAIN 推导值(sso.${SERVER_DOMAIN}) 不同"
        warn "  机构(租户)识别按 Host 头匹配 mxk_insts.domain，请确认库里的 domain 也是 ${pub_host}"
    }

    # CAS 服务地址必须由对外地址派生（库里的 service 必须与它严格相等）
    case "${LOGIN_CAS_SERVICE:-}" in
        "${MAXKEY_PUBLIC_URL}"*) ;;
        *) bad "LOGIN_CAS_SERVICE 必须由 MAXKEY_PUBLIC_URL 派生（当前: ${LOGIN_CAS_SERVICE:-未设置}）"; errs=$((errs+1)) ;;
    esac

    local f
    for f in "$NGINX_CERT" "$NGINX_KEY"; do
        if [ ! -e "$f" ]; then
            bad "证书文件不存在: $f"
            errs=$((errs+1))
        elif [ ! -s "$f" ]; then
            bad "证书文件为空: $f"
            errs=$((errs+1))
        fi
    done

    case "${DATABASE_URL:-}" in
        jdbc:kingbase8://*|jdbc:postgresql://*|jdbc:mysql://*) ;;
        *) bad "DATABASE_URL 格式不认识（当前: ${DATABASE_URL:-未设置}）"; errs=$((errs+1)) ;;
    esac
    case "${DATABASE_URL:-}" in
        *'&'*) case "$(grep -E '^[[:space:]]*DATABASE_URL=' "$CONF_DIR/maxkey.env" 2>/dev/null || true)" in
                   *"'"*) ;;
                   *) [ -f "$CONF_DIR/maxkey.env" ] && { bad "DATABASE_URL 含 & 但没用单引号包裹，会被 shell 截断"; errs=$((errs+1)); } ;;
               esac ;;
    esac

    [ "$errs" -eq 0 ] || die "环境档案自洽性校验未通过（${errs} 项），已中止，未改动任何文件"
    info "环境档案自洽性校验通过"
}

# ------------------------------------------------------------ 端口探测 ----
port_open() {
    local p=$1
    (exec 3<>"/dev/tcp/127.0.0.1/${p}") 2>/dev/null && exec 3<&- 2>/dev/null && return 0
    return 1
}

port_listener() {
    (ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null) | grep -E "[:.]${1}[[:space:]]" || true
}

# ------------------------------------------------------------ 健康检查 ----
# 判据（每一项都对应一次真实故障）：
#   1. 两个后端端口在监听      —— 进程活着但没 bind 也算失败
#   2. 直连后端 OIDC 元数据 200 —— 应用真的起来了
#   3. 经 nginx 访问首页 200    —— 反代与证书链路通（-k 因现场多为自签）
#   4. 启动后日志无 ERROR 堆栈  —— 起来但半残（连库失败等）能发现
# 直连与经 nginx 分开报，失败时能一眼看出是哪一层的问题。
health_check() {
    local app_port=$1 mgt_port=$2 pub_url=$3 srv_name=$4 tls_port=$5
    local fails=0 timeout=0

    say "健康检查"

    # 应用启动需要时间：最多等 90 秒
    while [ "$timeout" -lt 90 ]; do
        port_open "$app_port" && port_open "$mgt_port" && break
        sleep 3
        timeout=$((timeout + 3))
    done

    port_open "$app_port" && ok "portal 端口 ${app_port} 监听中" || { bad "portal 端口 ${app_port} 未监听"; fails=$((fails+1)); }
    port_open "$mgt_port"  && ok "mgt 端口 ${mgt_port} 监听中"  || { bad "mgt 端口 ${mgt_port} 未监听";  fails=$((fails+1)); }

    if command -v curl >/dev/null 2>&1; then
        local code
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
               "http://127.0.0.1:${app_port}/sign/authz/oauth/v20/.well-known/openid-configuration" 2>/dev/null || echo 000)
        [ "$code" = "200" ] && ok "直连后端 OIDC 元数据 200" || { bad "直连后端 OIDC 元数据返回 ${code}"; fails=$((fails+1)); }

        code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 \
               -H "Host: ${srv_name}" "https://127.0.0.1:${tls_port}/maxkey/" 2>/dev/null || echo 000)
        [ "$code" = "200" ] && ok "经 nginx 访问前端 200（Host: ${srv_name}:${tls_port}）" \
                            || { bad "经 nginx 访问前端返回 ${code}"; fails=$((fails+1)); }

        code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 \
               -H "Host: ${srv_name}" "https://127.0.0.1:${tls_port}/maxkey-mgt/" 2>/dev/null || echo 000)
        [ "$code" = "200" ] && ok "经 nginx 访问管理端 200" || { bad "经 nginx 访问管理端返回 ${code}"; fails=$((fails+1)); }
    else
        skip "未安装 curl，跳过 HTTP 探测"
    fi

    # 日志判据：只看本次启动之后写入的部分，避免历史 ERROR 造成误报
    local lf line
    for lf in "${LOG_DIR}/portal/maxkey.log" "${LOG_DIR}/mgt/maxkey.log"; do
        [ -f "$lf" ] || continue
        # 已知的"非故障 ERROR"必须排除，否则每次健康检查都会带一条噪音。
        # 反复出现的假告警会训练人忽略告警 —— 那比没有告警更危险。
        #
        # 目前只有一条：Druid 在 testWhileIdle=true 且未配 validationQuery 时
        # 打出的配置提醒。它是 Druid 的既有行为（连接可用性检测退化为
        # "连接没断就算健康"），不影响启动与功能，属于已知问题。
        line=$(tail -n 400 "$lf" 2>/dev/null \
                 | grep -E ' ERROR ' \
                 | grep -v 'testWhileIdle is true, validationQuery not set' \
                 | tail -3 || true)
        if [ -n "$line" ]; then
            warn "最近日志里有 ERROR（${lf}）:"
            printf '%s\n' "$line" | sed 's/^/      /'
        else
            ok "无 ERROR 日志（$(basename "$(dirname "$lf")")）"
        fi
    done

    if [ "$fails" -gt 0 ]; then
        printf '\n\033[1;31m健康检查未通过（%s 项）\033[0m\n' "$fails"
        cat <<EOF
  排障顺序：
    1. 进程与端口   ${PREFIX}/bin/maxkeyctl.sh status
    2. 启动日志     tail -100 ${LOG_DIR}/portal/nohup-portal.out
    3. 应用日志     tail -100 ${LOG_DIR}/portal/maxkey.log
    4. systemd      journalctl -u maxkey-portal -n 100 --no-pager
    5. nginx        nginx -t && tail -50 /var/log/nginx/maxkey.error.log
EOF
        return 1
    fi
    info "健康检查全部通过"
    return 0
}

# ------------------------------------------------------------ 系统依赖 ----
# 分级：硬依赖缺失直接失败；可选项缺失只告警并跳过。
# 理由：麒麟最小化安装常常没有 logrotate / rsync，但这不该挡住部署；
# 而缺 useradd/systemctl/nginx（当需要时）是真装不上。
require_hard() {
    command -v "$1" >/dev/null 2>&1 && return 0
    # dry-run 的价值就在于"不需要 root 也能在任意机器上预演"：
    # 此时 useradd/systemctl 这类命令可能因权限或最小化安装而不可见，
    # 但它们是否可用，只有真装时才有意义。这里降级为告警，
    # 否则 `--dry-run` 会在检查阶段就退出，演练失去意义。
    if [ "${DRY_RUN:-0}" = "1" ]; then
        warn "dry-run：未找到 $1（$2）—— 真装时若缺失会中止"
        return 0
    fi
    die "缺少必需命令: $1（$2）"
}

require_soft() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------ 防火墙检查 ----
# 目标机开了 firewalld 时，端口没放行 → 本机 curl 200、外部浏览器打不开。
# 这个坑极难自查：应用正常、nginx 正常、端口在监听，`curl 127.0.0.1` 也是 200，
# 因为回环接口被 iptables 的 `-A INPUT -i lo -j ACCEPT` 放行了 ——
# 也就是说"本机自测全绿"完全无法证明外部可访问。
#
# 实测过的现场（qilin-01）：
#   services: cockpit dhcpv6-client http https mdns ssh
#   ports:    9999/tcp 54321/tcp 9092/tcp 8093/tcp
#   → 443 因为 services 里有 https 而放行，但 MaxKey 用 9443，
#     没在白名单里，命中最后的 `REJECT --reject-with icmp-host-prohibited`。
#
# 这里只做**检查与提示**，不自动改防火墙：放行端口是运维决策，
# 擅自修改防火墙在等保/信创环境里可能直接违反合规要求。
# 返回 0 = 已放行或无需检查；1 = 未放行
check_firewall_port() {
    local port=$1
    local zone

    # firewalld 未运行 → 没有这个问题（也可能是 iptables 手写规则，不深究）
    if ! systemctl is-active firewalld >/dev/null 2>&1; then
        return 0
    fi

    zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo public)

    # 已显式放行端口
    if firewall-cmd --zone="$zone" --query-port="${port}/tcp" >/dev/null 2>&1; then
        return 0
    fi

    # 端口所属服务已放行（如 443 对应 https、80 对应 http）
    case "$port" in
        443) firewall-cmd --zone="$zone" --query-service=https >/dev/null 2>&1 && return 0 ;;
        80)  firewall-cmd --zone="$zone" --query-service=http  >/dev/null 2>&1 && return 0 ;;
    esac

    return 1
}

# 打印"怎么放行"，措辞里带上后果，避免被当成可选建议忽略
firewall_hint() {
    local port=$1
    cat <<EOF

    firewalld 正在运行，但端口 ${port}/tcp 未放行。
    表现：服务器本机 curl 返回 200，但**别的机器上的浏览器打不开**
          （回环接口被 iptables 放行，所以本机自测看不出问题）。

    放行命令（root）：
        firewall-cmd --permanent --add-port=${port}/tcp
        firewall-cmd --reload
        firewall-cmd --list-ports          # 确认出现 ${port}/tcp

    只想临时验证（重启后失效）：
        firewall-cmd --add-port=${port}/tcp
EOF
}

# ------------------------------------------------------------ 版本比较 ----
# 版本形如 4.2.0-<sha>-<时间戳>，比较时只看第一段的数字部分；
# 其余部分用于目录命名与溯源。相同数字版本视为"同级升级"（允许）。
version_number() { printf '%s' "$1" | sed -E 's/^([0-9]+(\.[0-9]+)*).*/\1/'; }

version_cmp() {
    # 输出 -1 / 0 / 1（$1 相对 $2）
    local a b i max
    a=$(version_number "$1"); b=$(version_number "$2")
    IFS=. read -r -a av <<< "$a"
    IFS=. read -r -a bv <<< "$b"
    max=${#av[@]}; [ "${#bv[@]}" -gt "$max" ] && max=${#bv[@]}
    for ((i=0; i<max; i++)); do
        local x=${av[$i]:-0} y=${bv[$i]:-0}
        if [ "$x" -gt "$y" ] 2>/dev/null; then echo 1; return; fi
        if [ "$x" -lt "$y" ] 2>/dev/null; then echo -1; return; fi
    done
    echo 0
}
