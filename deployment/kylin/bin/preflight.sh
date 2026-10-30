#!/bin/bash
############################################################################
#  preflight.sh — 部署前环境自检
#
#  在**目标麒麟主机**上执行，一次性检查所有会导致启动失败的环境前提。
#  这是把踩过的坑固化成检查项：glibc 不匹配、架构不符、端口占用、
#  配置字段缺失、数据库不可达。
#
#  用法: ./bin/preflight.sh
#  退出码: 0 = 全部通过，1 = 存在阻塞项
############################################################################

set -u
set -o pipefail

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# ---------------------------------------------------------------- 布局适配 --
# 新布局：本脚本随版本走（在 releases/<版本>/bin/），而 conf/ logs/ jre/ 是
# 跨版本共享的（在 <root> 下）。检查项必须指向**真正生效**的那份，
# 否则会出现"自检绿了但服务起不来"或"自检红了一片其实一切正常"。
# 与 maxkeyctl.sh 同一套判定：必须用物理路径，否则从 current 软链调用时
# 会误判为"旧布局"，检查项全部指错地方。
REAL_BASE=$(readlink -f "$BASE_DIR")
if [ "$(basename "$(dirname "$REAL_BASE")")" = "releases" ]; then
    SHARED_DIR=$(cd "$(dirname "$REAL_BASE")/.." && pwd)
    SHARED_LAYOUT=1
else
    SHARED_DIR="$REAL_BASE"
    SHARED_LAYOUT=0
fi

CONF_FILE="${BASE_DIR}/conf/maxkey.env"
if [ -x "${SHARED_DIR}/jre/bin/java" ]; then
    JRE_HOME="${SHARED_DIR}/jre"
else
    JRE_HOME="${BASE_DIR}/jre"
fi
SECRET_FILE=/etc/maxkey/maxkey-secret.env

PASS=0; WARN=0; FAIL=0
ok()   { printf '  \033[32m[ OK ]\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
warn() { printf '  \033[33m[WARN]\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
err()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
sec()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

# ------------------------------------------------------------ 1. 系统 ----
sec "1. 操作系统与架构"

if [ -r /etc/os-release ]; then
    . /etc/os-release
    ok "系统: ${PRETTY_NAME:-$NAME $VERSION}"
    echo "$PRETTY_NAME" | grep -qi kylin && ok "检测到麒麟系统"
else
    warn "无法读取 /etc/os-release"
fi

ARCH=$(uname -m)
ok "架构: ${ARCH}"

# 内置 jre 与构建机架构绑定，这是最容易忽略的交付事故
if [ -x "${JRE_HOME}/bin/java" ]; then
    JREFILE="${JRE_HOME}/bin/java"
    JREARCH=$(file -b "$JREFILE" 2>/dev/null | grep -oE 'x86-64|aarch64|ARM|MIPS|loongarch' | head -1)
    case "$ARCH:$JREARCH" in
        x86_64:x86-64|aarch64:aarch64|loongarch64:loongarch) ok "jre 架构与主机匹配 (${JREARCH})" ;;
        "") warn "无法识别 jre 架构，请手工确认" ;;
        *)  err "jre 架构(${JREARCH}) 与主机(${ARCH}) 不匹配，需在本机重新 make-runtime.sh" ;;
    esac
else
    warn "未发现内置 jre/，将依赖系统 JDK（需 >= 21）"
fi

# ------------------------------------------------------------- 2. glibc ----
sec "2. glibc 基线（运行时能否加载的决定因素）"

HOST_GLIBC=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')
if [ -z "$HOST_GLIBC" ]; then
    warn "无法获取 glibc 版本"
else
    ok "主机 glibc: ${HOST_GLIBC}"
fi

if [ -x "${JRE_HOME}/bin/java" ]; then
    LIBJVM="${JRE_HOME}/lib/server/libjvm.so"
    if [ -f "$LIBJVM" ] && command -v objdump >/dev/null 2>&1; then
        NEED_GLIBC=$(objdump -T "$LIBJVM" 2>/dev/null | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -uV | tail -1 | sed 's/GLIBC_//')
        if [ -n "$NEED_GLIBC" ]; then
            if [ "$(printf '%s\n%s\n' "$HOST_GLIBC" "$NEED_GLIBC" | sort -V | tail -1)" = "$HOST_GLIBC" ]; then
                ok "jre 需要 glibc >= ${NEED_GLIBC}，主机 ${HOST_GLIBC} 满足"
            else
                err "jre 需要 glibc ${NEED_GLIBC}，但主机只有 ${HOST_GLIBC}"
                echo "         → 该 jre 是用系统自带 JDK 构建的（基线过高）。"
                echo "           在构建机改用 Adoptium Temurin 重建即可（基线 2.15）："
                echo "             ./bin/make-runtime.sh --download"
                echo "           或改用目标机已装的 JDK 21：export JAVA_HOME=/usr/lib/jvm/jdk-21"
            fi
        fi
    else
        warn "缺少 objdump，跳过 glibc 符号检查（可 yum/dnf install binutils）"
    fi

    # 最直接的判据：能不能跑起来
    if "${JRE_HOME}/bin/java" -version >/dev/null 2>&1; then
        ok "内置 jre 可正常执行 java -version"
    else
        err "内置 jre 无法执行（多为 glibc/架构不匹配）"
    fi
fi

# -------------------------------------------------------------- 3. JDK ----
sec "3. Java 运行时可用性"

JAVA_BIN=""
for c in "${JAVA_HOME:-}/bin/java" "${JRE_HOME}/bin/java" /usr/lib/jvm/*21*/bin/java /opt/jdk-21*/bin/java; do
    [ -x "$c" ] || continue
    MAJ=$("$c" -version 2>&1 | head -1 | sed -n 's/.*version "\([0-9]*\).*/\1/p')
    if [ "${MAJ:-0}" -ge 21 ] 2>/dev/null; then JAVA_BIN="$c"; break; fi
done

if [ -n "$JAVA_BIN" ]; then
    ok "可用 JDK: $JAVA_BIN (major $("$JAVA_BIN" -version 2>&1 | head -1 | sed -n 's/.*version "\([0-9]*\).*/\1/p'))"
else
    err "未找到 JDK 21+（MaxKey 4.2.0 字节码为 major 65）"
fi

# --------------------------------------------------------- 4. 关键模块 ----
sec "4. Java 字体/图形（验证码依赖 java.desktop）"

if [ -n "$JAVA_BIN" ]; then
    if "$JAVA_BIN" -Djava.awt.headless=true -e 2>/dev/null; then :; fi
    # 用最小代码验证 AWT 与字体是否可用
    TMPJ=$(mktemp /tmp/AwtCheckXXXX.java)
    cat > "$TMPJ" <<'EOF'
public class AwtCheck {
    public static void main(String[] a) {
        int n = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment()
                    .getAvailableFontFamilyNames().length;
        System.out.println("FONTS=" + n);
    }
}
EOF
    OUT=$("$JAVA_BIN" -Djava.awt.headless=true "$TMPJ" 2>&1)
    FONTS=$(echo "$OUT" | grep -oE 'FONTS=[0-9]+' | cut -d= -f2)
    if [ -n "$FONTS" ] && [ "$FONTS" -gt 0 ] 2>/dev/null; then
        ok "AWT 可用，字体族 ${FONTS} 个（验证码可正常渲染）"
    else
        err "AWT/字体不可用，验证码会失败。请安装字体: yum install fontconfig dejavu-sans-fonts"
        echo "         $OUT" | head -3
    fi
    rm -f "$TMPJ" /tmp/AwtCheck.class 2>/dev/null
fi

# ----------------------------------------------------------- 5. 配置 ----
sec "5. 部署配置 conf/maxkey.env"

if [ ! -f "$CONF_FILE" ]; then
    err "缺少 ${CONF_FILE}"
else
    if ( set -a; . "$CONF_FILE" ) 2>/dev/null; then
        ok "配置文件语法正确"
        set -a; . "$CONF_FILE"; set +a
    else
        err "配置文件语法错误，执行 bash -n ${CONF_FILE} 查看"
    fi

    [ -n "${SERVER_DOMAIN:-}" ] && [ "$SERVER_DOMAIN" != "example.gov.cn" ] \
        && ok "SERVER_DOMAIN=${SERVER_DOMAIN}" \
        || warn "SERVER_DOMAIN 仍为示例值，多租户识别会退回默认机构"

    if [ -z "${DATABASE_URL:-}" ]; then
        err "DATABASE_URL 为空（常见原因：JDBC URL 中 & 未加引号）"
    else
        ok "DATABASE_URL 已设置"

        # 口令注入检查。放在这里而非留到启动，避免"自检全绿但一启动就失败"。
        if [ -z "${DATABASE_PWD:-}" ]; then
            if [ -f /etc/maxkey/maxkey-secret.env ]; then
                warn "DATABASE_PWD 未在本 shell 生效，但检测到 /etc/maxkey/maxkey-secret.env"
                echo "         若用 systemd 启动则正常；手工启动需先 source 该文件或 export"
            else
                err "DATABASE_PWD 为空且未找到 /etc/maxkey/maxkey-secret.env"
                echo "         注入方法：sudo cp conf/maxkey-secret.env.example /etc/maxkey/maxkey-secret.env"
                echo "                   然后填入口令并 chmod 600"
                echo "         手工启动：export DATABASE_PWD='实际口令'"
            fi
        else
            ok "DATABASE_PWD 已注入（长度 ${#DATABASE_PWD}，不显示内容）"
        fi

        case "${DATABASE_URL}" in
            *kingbase8*)
                [ "${DATABASE_DIALECT:-}" = "kingbase" ] \
                    && ok "方言 kingbase 与驱动匹配" \
                    || err "驱动是 kingbase8 但 DATABASE_DIALECT=${DATABASE_DIALECT:-未设置}"
                [ "${DATABASE_COLUMN_ESCAPE:-false}" = "true" ] \
                    && ok "已开启标识符转义（Kingbase 必需）" \
                    || err "Kingbase 需 DATABASE_COLUMN_ESCAPE=true（online 是保留字）"
                [ "${DATABASE_COLUMN_ESCAPE_CHAR:-}" = '"' ] \
                    && ok "转义符为双引号（Kingbase 正确）" \
                    || warn "DATABASE_COLUMN_ESCAPE_CHAR 应为单个双引号，当前='${DATABASE_COLUMN_ESCAPE_CHAR:-}'"
                ;;
            *mysql*)
                ok "MySQL 部署（保持 DATABASE_COLUMN_ESCAPE=false 与反引号）"
                ;;
        esac
    fi
fi

# -------------------------------------------------------- 6. 端口占用 ----
sec "6. 端口占用"

PORTAL_PORT="${PORTAL_PORT:-9527}"
MGT_PORT="${MGT_PORT:-9526}"
for p in "$PORTAL_PORT" "$MGT_PORT"; do
    if command -v ss >/dev/null 2>&1 && ss -lnt 2>/dev/null | grep -q ":${p} "; then
        err "端口 ${p} 已被占用: $(ss -lntp 2>/dev/null | grep ":${p} " | head -1)"
    else
        ok "端口 ${p} 空闲"
    fi
done

# ---------------------------------------------------------- 7. 数据库 ----
sec "7. 数据库连通性"

if [ -n "${DATABASE_URL:-}" ]; then
    case "$DATABASE_URL" in
        *kingbase8://*)
            HOSTPORT=$(echo "$DATABASE_URL" | sed -n 's|jdbc:kingbase8://\([^/]*\)/.*|\1|p')
            DBHOST=${HOSTPORT%%:*}; DBPORT=${HOSTPORT##*:}
            [ "$DBPORT" = "$HOSTPORT" ] && DBPORT=54321
            if (exec 3<>"/dev/tcp/${DBHOST}/${DBPORT}") 2>/dev/null; then
                exec 3<&- 2>/dev/null
                ok "Kingbase 端口可达 ${DBHOST}:${DBPORT}"
                if command -v ksql >/dev/null 2>&1; then
                    if echo "${DATABASE_PWD:-}" | ksql -h "$DBHOST" -p "$DBPORT" \
                         -U "${DATABASE_USER:-}" -d maxkey -c "select 1" >/dev/null 2>&1; then
                        ok "Kingbase 账号密码验证通过"
                        N=$(echo "${DATABASE_PWD:-}" | ksql -h "$DBHOST" -p "$DBPORT" -U "${DATABASE_USER:-}" \
                              -d maxkey -t -c "select count(*) from sys_tables where schemaname='public'" 2>/dev/null | tr -d ' ')
                        [ "${N:-0}" -ge 40 ] 2>/dev/null && ok "已建表 ${N} 张" \
                            || err "表数量异常(${N:-0})，请先导入 sql/maxkey.sql"
                    else
                        warn "ksql 连接失败，请检查账号密码（密码含特殊字符需注意引号）"
                    fi
                else
                    warn "未找到 ksql 客户端，跳过认证检查"
                fi
            else
                err "Kingbase 端口不可达 ${DBHOST}:${DBPORT}（服务未启动或防火墙）"
            fi
            ;;
    esac
fi

# -------------------------------------------------------------- 8. nginx ----
sec "8. nginx"

if command -v nginx >/dev/null 2>&1; then
    ok "已安装: $(nginx -v 2>&1)"
    if systemctl is-active nginx >/dev/null 2>&1; then
        ok "nginx 正在运行"
        echo "         接入方式: 新增 conf.d/maxkey.conf（独立 server 块）"
        echo "         检查冲突: grep -rl 'server_name.*<你的域名>' /etc/nginx/conf.d/"
        echo "         同域名同端口双站点会导致 nginx 只采用先加载者，install.sh 会提前拦截"
    else
        ok "nginx 已安装但未运行，启动后再校验配置"
    fi
    if command -v semanage >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
        warn "SELinux 为 Enforcing，nginx 反代可能被拒绝，需: setsebool -P httpd_can_network_connect 1"
    fi
    if systemctl is-active firewalld >/dev/null 2>&1; then
        warn "firewalld 运行中，需放行 80/443: firewall-cmd --add-service=http --permanent"
    fi
else
    err "未安装 nginx，前端无法访问（yum install nginx 或 dnf install nginx）"
fi

# ------------------------------------------------------------- 9. 目录 ----
sec "9. 目录与权限"

if [ "${SHARED_LAYOUT:-0}" = "1" ]; then
    # 新布局：日志与 pid 在共享目录，程序在版本目录
    ok "布局: 版本目录（$(basename "$BASE_DIR")）"
    for d in "${SHARED_DIR}/logs" "${SHARED_DIR}/run"; do
        if [ -d "$d" ]; then
            RUN_OWNER=$(stat -c '%U' "$d" 2>/dev/null)
            if [ "$RUN_OWNER" = "maxkey" ]; then
                ok "${d} 属主 maxkey"
            else
                err "${d} 属主应为 maxkey，实际 ${RUN_OWNER:-?}（chown maxkey:maxkey）"
            fi
        else
            err "$d 不存在（用 install.sh 安装，不要手工建）"
        fi
    done
    # 版本目录内的 logs 与 conf 必须是软链，否则日志会留在版本目录里
    for l in "${BASE_DIR}/maxkey/logs" "${BASE_DIR}/maxkey_mgt/logs" "${BASE_DIR}/conf"; do
        if [ -L "$l" ]; then
            ok "$(basename "$(dirname "$l")")/$(basename "$l") 是软链 -> $(readlink "$l")"
        else
            err "${l} 不是软链（日志/配置会不共享，回滚后丢失）"
        fi
    done
    [ -f "${BASE_DIR}/conf/maxkey.env" ] && ok "conf/maxkey.env 可读" \
        || err "conf/maxkey.env 不可读（软链断了？）"
else
    for d in logs run maxkey maxkey_mgt; do
        if [ -d "${BASE_DIR}/${d}" ]; then
            if [ -w "${BASE_DIR}/${d}" ]; then ok "${d}/ 可写"; else err "${d}/ 不可写（检查 chown maxkey:maxkey）"; fi
        else
            warn "${d}/ 不存在"
        fi
    done
fi

[ -d "${BASE_DIR}/web/maxkey" ] && ok "前端产物 web/maxkey 存在" || err "缺少前端产物 web/maxkey"
[ -d "${BASE_DIR}/web/maxkey-mgt" ] && ok "前端产物 web/maxkey-mgt 存在" || err "缺少前端产物 web/maxkey-mgt"

# ------------------------------------------------------- 10. 运行时密钥 ----
sec "10. 运行时密钥"

if [ -f "$SECRET_FILE" ]; then
    PERM=$(stat -c '%a %U' "$SECRET_FILE" 2>/dev/null)
    case "$PERM" in
        "600 root") ok "${SECRET_FILE} 权限正确（${PERM}）" ;;
        *) err "${SECRET_FILE} 权限应为 600 root，实际 ${PERM}" ;;
    esac
    for k in DATABASE_PWD JWT_SECRET; do
        if grep -qE "^[[:space:]]*${k}=" "$SECRET_FILE" 2>/dev/null; then
            ok "已含 ${k}"
        else
            err "缺少 ${k}（maxkeyctl.sh 会拒绝启动）"
        fi
    done
    # JWT_SECRET 长度：用 HMAC-SHA512 时过短会抛 WeakKeyException
    JLEN=$(sed -n 's/^[[:space:]]*JWT_SECRET=//p' "$SECRET_FILE" 2>/dev/null | head -1 | tr -d "'\"" | wc -c)
    if [ "${JLEN:-0}" -ge 65 ]; then
        ok "JWT_SECRET 长度 ${JLEN} 字节（HS512 要求 >= 64）"
    elif [ "${JLEN:-0}" -gt 0 ]; then
        err "JWT_SECRET 只有 ${JLEN} 字节，HS512 会抛 WeakKeyException"
    fi
else
    err "缺少 ${SECRET_FILE}（由 install.sh 生成，或按 conf/maxkey-secret.env.example 手工创建）"
fi

# ------------------------------------------------------------ 汇总 ----
printf '\n\033[1m========== 自检结果: %d 通过 / %d 警告 / %d 阻塞 ==========\033[0m\n' "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo -e "\033[31m存在阻塞项，请先修复再启动。\033[0m"
    exit 1
fi
echo -e "\033[32m自检通过，可执行 ./bin/maxkeyctl.sh start\033[0m"
exit 0
