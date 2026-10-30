#!/bin/bash
############################################################################
#  MaxKey 麒麟(Kylin) 部署控制脚本
#
#  用法:
#      ./maxkeyctl.sh start   [portal|mgt|all]
#      ./maxkeyctl.sh stop    [portal|mgt|all]
#      ./maxkeyctl.sh restart [portal|mgt|all]
#      ./maxkeyctl.sh status  [portal|mgt|all]
#      ./maxkeyctl.sh java                    # 打印自动探测到的 JDK 及版本
#
#  设计要点:
#      1. 不依赖外部 JAVA_HOME：按 “显式 JAVA_HOME -> 包内 jre -> 系统 JDK21” 顺序探测
#      2. 校验 JDK 主版本 >= 21（MaxKey 4.2.0 字节码为 class file major 65）
#      3. 所有路径基于脚本自身位置解析，可从任意目录调用 / 可挂 systemd
#      4. 启动后轮询端口，避免“脚本返回成功但进程已退出”的假成功
############################################################################

set -u
set -o pipefail

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# ---------------------------------------------------------------- 布局适配 --
# 新布局：程序在 <root>/releases/<版本>/，current 软链指向它，而
#   conf/ logs/ run/ 是**跨版本共享**的（在 <root> 下）。
# 本脚本放在 release 内（随代码走，保证启动参数与 jar 版本匹配），
# 所以运行时目录必须解析到共享位置，否则：
#   * pid 写进版本目录，systemd 的 PIDFile 找不到 → 服务"启动成功但立即退"
#   * 日志留在版本目录里，回滚后旧日志"消失"
# 旧布局（程序直接在 <root> 下）保持原行为。
# 判定必须基于**物理路径**：systemd 调的是 /opt/maxkey/current/bin/maxkeyctl.sh，
# 此时 BASE_DIR=/opt/maxkey/current（软链），dirname 是 /opt/maxkey 而不是 releases，
# 用逻辑路径判断会漏判 —— 后果是 pid 与日志写进 current/run、current/logs，
# 在 systemd 的 ProtectSystem=full 下 /opt 只读，直接报
#   /opt/maxkey/current/run/maxkey-portal.pid: No such file or directory
# 而"没权限创建目录"被 mkdir -p 的 2>/dev/null 吞掉了，只剩一句没有 pid 文件，
# 极难归因。
REAL_BASE=$(readlink -f "$BASE_DIR")
if [ "$(basename "$(dirname "$REAL_BASE")")" = "releases" ]; then
    SHARED_DIR=$(cd "$(dirname "$REAL_BASE")/.." && pwd)
    SHARED_LAYOUT=1
else
    SHARED_DIR="$REAL_BASE"
    SHARED_LAYOUT=0
fi

CONF_FILE="${BASE_DIR}/conf/maxkey.env"
RUN_DIR="${SHARED_DIR}/run"
LOG_DIR="${SHARED_DIR}/logs"

# 内置 jre 也是跨版本共享的（64MB，不在每个 release 里复制一份）。
# 先看包内（旧布局/单目录部署），再看共享位置（新布局）。
if [ -x "${SHARED_DIR}/jre/bin/java" ]; then
    JRE_HOME="${SHARED_DIR}/jre"
else
    JRE_HOME="${BASE_DIR}/jre"
fi

# 不能静默吞掉创建失败：那会让后面"pid 文件不存在"成为唯一线索。
for d in "$RUN_DIR" "$LOG_DIR"; do
    if ! mkdir -p "$d" 2>/dev/null; then
        echo "ERROR: 无法创建 ${d}"
        echo "       检查属主（应为 maxkey:maxkey）与 systemd 的 ReadWritePaths"
        echo "       当前用户: $(id -un 2>/dev/null || echo '?')"
        exit 1
    fi
    [ -w "$d" ] || { echo "ERROR: ${d} 不可写（当前用户 $(id -un 2>/dev/null || echo '?')）"; exit 1; }
done


# set -a 让 conf 中的变量自动 export，否则 DATABASE_URL/SERVER_DOMAIN 等
# 只是 shell 局部变量，不会传给 java 子进程，Spring 会静默回落到代码内置默认值
# （典型症状：配置了 Kingbase 却仍连 MySQL，日志里全是 3306 连接失败）
#
# 注意：source 失败时 bash 的报错不一定让脚本中止（取决于调用方式），
# 会出现“配置文件坏了但脚本继续用默认值启动”的假成功，故显式校验。
if [ -f "$CONF_FILE" ]; then
    if ! ( set -a; . "$CONF_FILE" ) 2>/dev/null; then
        echo "ERROR: 配置文件语法错误: ${CONF_FILE}"
        echo "       请执行以下命令查看具体行号："
        echo "       bash -n ${CONF_FILE}"
        exit 1
    fi
    set -a
    # shellcheck disable=SC1090
    . "$CONF_FILE"
    set +a
fi

# ------------------------------------------------------------ 变量派生 ----
# 端口与协议在 conf 中是可选的“友好名”，这里翻译成 Spring 认识的键，
# 保证“改一处配置”即可，不必同时写 SERVER_PORT 和 PORTAL_PORT
: "${MAXKEY_SCHEME:=http}"
export MAXKEY_SCHEME
export SERVER_DOMAIN="${SERVER_DOMAIN:-}"
export MAXKEY_PUBLIC_URL="${MAXKEY_PUBLIC_URL:-}"

# 公开访问地址（MAXKEY_PUBLIC_URL）的处理，这是整套配置里最容易搞错的一环。
#
# 后端有两处需要"对外地址"，但取法完全不同：
#   (a) JWT 的 iss（maxkey.auth.jwt.issuer ← maxkey.server.uri）
#       签发与校验用同一个固定值，JwtLoginService 对 iss 做【严格相等】比对。
#       所以它绝不能用请求头推导 —— 否则同一实例经不同入口访问会签出不同 iss，
#       token 互不认，表现为"登录成功但立刻失效"。
#   (b) OIDC 元数据的 issuer / authorization_endpoint 等
#       由 WebContext.getContextPath(true) 从【当前请求】推导，
#       依赖 server.forward-headers-strategy=NATIVE 读 X-Forwarded-*。
#
# 脚本只负责把 (a) 下发给 JVM；(b) 由 nginx 传头 + 后端开关解决。
#
# 未配置时回退到 scheme://sso.$SERVER_DOMAIN（与历史行为一致，保证能起来）；
# 但走 nginx 反代且对外端口非默认端口时，必须显式配置。
if [ -z "$MAXKEY_PUBLIC_URL" ]; then
    if [ -n "${SERVER_DOMAIN:-}" ]; then
        MAXKEY_PUBLIC_URL="${MAXKEY_SCHEME}://sso.${SERVER_DOMAIN}"
        echo "WARN: 未配置 MAXKEY_PUBLIC_URL，按 SERVER_DOMAIN 推导为 ${MAXKEY_PUBLIC_URL}"
        echo "      若对外端口不是 ${MAXKEY_SCHEME} 的默认端口，请显式配置，例如"
        echo "      MAXKEY_PUBLIC_URL='${MAXKEY_SCHEME}://sso.${SERVER_DOMAIN}:9443'"
    fi
fi
export MAXKEY_PUBLIC_URL

# 管理端 CAS 免密登录的两个地址在 conf 里是
#   LOGIN_CAS_SERVER="http://127.0.0.1:${PORTAL_PORT:-9527}/sign/authz/cas"
#   LOGIN_CAS_SERVICE="${MAXKEY_PUBLIC_URL}/maxkey-mgt/#/passport/trust/auth"
# 后者**在 source 时**就展开。若 conf 里 MAXKEY_PUBLIC_URL 留空、靠上面这段
# 按 SERVER_DOMAIN 推导，它就会变成残缺的 "/maxkey-mgt/#/..."（没有协议和主机），
# serviceValidate 比对必然失败。故这里在派生完成后做一次兜底。
if [ -n "$MAXKEY_PUBLIC_URL" ]; then
    case "${LOGIN_CAS_SERVER:-}" in
        http://*|https://*) ;;
        *)
            LOGIN_CAS_SERVER="http://127.0.0.1:${PORTAL_PORT:-9527}/sign/authz/cas"
            echo "WARN: LOGIN_CAS_SERVER 未配置或不完整，已回退为 ${LOGIN_CAS_SERVER}"
            ;;
    esac
    case "${LOGIN_CAS_SERVICE:-}" in
        http://*|https://*) ;;
        *)
            LOGIN_CAS_SERVICE="${MAXKEY_PUBLIC_URL}/maxkey-mgt/#/passport/trust/auth"
            echo "WARN: LOGIN_CAS_SERVICE 未配置或不完整，已按对外地址重建为 ${LOGIN_CAS_SERVICE}"
            ;;
    esac
    export LOGIN_CAS_SERVER LOGIN_CAS_SERVICE
fi

# maxkey.server.scheme 在 properties 中是写死的 http，无法用环境变量覆盖，
# 故启动时用 -D 显式下发（-D 优先级高于 application.properties）
SPRING_EXTRA_OPTS="-Dmaxkey.server.scheme=${MAXKEY_SCHEME}"
# 公开地址同样用 -D 兜底下发：环境变量已能生效，-D 只是双保险，
# 避免 systemd 的 EnvironmentFile 与手工 source 两条路径行为不一致。
[ -n "$MAXKEY_PUBLIC_URL" ] && SPRING_EXTRA_OPTS="${SPRING_EXTRA_OPTS} -DMAXKEY_PUBLIC_URL=${MAXKEY_PUBLIC_URL}"

# ------------------------------------------------ 配置一致性检查 ----
# MAXKEY_PUBLIC_URL 与 SERVER_DOMAIN 必须指向同一个主机。
# 不一致时典型症状：能登录，但 SSO 回跳到另一个域名/端口，浏览器侧 404。
if [ -n "${MAXKEY_PUBLIC_URL:-}" ] && [ -n "${SERVER_DOMAIN:-}" ]; then
    pub_host=$(echo "$MAXKEY_PUBLIC_URL" | sed -E 's#^[a-zA-Z]+://##; s#[:/].*$##')
    if [ "$pub_host" != "sso.${SERVER_DOMAIN}" ]; then
        echo "WARN: MAXKEY_PUBLIC_URL 的主机 (${pub_host}) 与 SERVER_DOMAIN 推导的"
        echo "      (sso.${SERVER_DOMAIN}) 不一致。"
        echo "      域名同时用于①租户识别 ②SSO 回跳地址 ③Cookie 域，不一致会导致回跳失败。"
    fi
fi

# ------------------------------------------------------- 配置自检（关键） ----
# bash 对 `A=x&y` 不报语法错误，而是把 & 当后台分隔符，A 变成空串、
# y 被当命令执行。这类错误只能靠“值是否为空”来发现，故显式校验，
# 否则应用会带着空配置静默回落到代码内置默认值（默认连 MySQL）。
if [ -n "${DATABASE_DRIVER:-}" ] && [ -z "${DATABASE_URL:-}" ]; then
    echo "ERROR: DATABASE_DRIVER 已配置但 DATABASE_URL 为空"
    echo "       常见原因：JDBC URL 中的 & 没加引号，被 shell 当后台分隔符截断。"
    echo "       修正：DATABASE_URL='jdbc:kingbase8://host:54321/maxkey?a=1&b=2'"
    exit 1
fi

# 数据库口令已改为环境变量注入，conf/maxkey.env 中不再保存明文。
# 未注入时 Spring 会回落到内置默认值并连库失败，故此处显式拦截。
if [ -n "${DATABASE_DRIVER:-}" ] && [ -z "${DATABASE_PWD:-}" ]; then
    echo "ERROR: DATABASE_DRIVER 已配置但 DATABASE_PWD 为空（数据库口令未注入）"
    echo "       口令不再写入 conf/maxkey.env，需由运行环境提供，任选其一："
    echo "         systemd: [Service] 段加 EnvironmentFile=-/etc/maxkey/maxkey-secret.env"
    echo "                  （该文件 600，内容仅一行 DATABASE_PWD='实际口令'）"
    echo "         手工启动: export DATABASE_PWD='实际口令' && ./bin/maxkeyctl.sh start"
    exit 1
fi

# JWT 密钥同理：4.2.0 起从 jar 内的明文常量改为环境变量注入
# （原先是 512 字符字面量写在两个 properties 里，任何人 unzip jar 就能
#  拿到并伪造任意用户 token）。缺它时 @Value("${maxkey.auth.jwt.secret}")
# 没有默认值，应用会在启动阶段就抛 IllegalArgumentException。
#
# 同源要求：portal 与 mgt 必须用**同一个**密钥，否则两边签发的 token
# 互不认可（表现为登录成功但立刻被踢回登录页）。
if [ -z "${JWT_SECRET:-}" ]; then
    echo "ERROR: JWT_SECRET 未注入（portal 与 mgt 必须使用同一个值）"
    echo "       由安装脚本生成，位于 /etc/maxkey/maxkey-secret.env："
    echo "         JWT_SECRET='<512 字符随机串>'"
    echo "       手工启动时："
    echo "         export JWT_SECRET=\"\$(sed -n 's/^JWT_SECRET=//p' /etc/maxkey/maxkey-secret.env)\""
    exit 1
fi

# ---------------------------------------------------------------- 默认值 ----
# 未在 conf/maxkey.env 中指定时使用
: "${JAVA_OPTS_PORTAL:=-Xms512m -Xmx2048m}"
: "${JAVA_OPTS_MGT:=-Xms256m -Xmx1024m}"
: "${PORTAL_PORT:=9527}"
: "${MGT_PORT:=9526}"
: "${START_TIMEOUT:=180}"
: "${LOG_KEEP_DAYS:=30}"

# ------------------------------------------------------------ Java 探测 ----
java_major() {
    # $1 = java 可执行文件；输出主版本号，失败输出 0
    local v
    v=$("$1" -version 2>&1 | head -1)
    # openjdk version "21.0.12.1" / java version "1.8.0_301"
    v=$(echo "$v" | sed -n 's/.*version "\([0-9._]*\)".*/\1/p')
    [ -z "$v" ] && { echo 0; return; }
    case "$v" in
        1.*) echo "$v" | cut -d. -f2 ;;
        *)   echo "$v" | cut -d. -f1 ;;
    esac
}

find_java() {
    local cand major
    # 探测顺序是刻意的，不要随意调换：
    #   0) MAXKEY_JAVA 显式强制
    #   1) 发布包内置运行时（jlink 裁剪结果）
    #   2) 显式指定的 JAVA_HOME
    #   3) 系统已装的 JDK 21
    #   4) PATH 中的 java
    #
    # 为什么内置运行时排第一：本方案要解决的问题正是"目标机器的 Java 版本不可控"。
    # 若让 JAVA_HOME / PATH 优先，目标机上一个残缺的 JDK 会把内置运行时顶掉，
    # 打包内置 JDK 的努力全部作废，且失败现象变成难以归因的
    # UnsupportedClassVersionError 或各类 NoClassDefFoundError。
    # 需要强制用外部 JDK 时，显式传 MAXKEY_JAVA 或删掉 jre/ 目录。
    if [ -n "${MAXKEY_JAVA:-}" ]; then
        if [ -x "$MAXKEY_JAVA" ]; then
            echo "$MAXKEY_JAVA"; return 0
        fi
        echo "WARN: MAXKEY_JAVA=${MAXKEY_JAVA} 不存在或不可执行，忽略" >&2
    fi
    # 1) 发布包内置运行时
    if [ -x "${JRE_HOME}/bin/java" ]; then echo "${JRE_HOME}/bin/java"; return 0; fi
    # 2) 显式指定的 JAVA_HOME
    if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
        cand="${JAVA_HOME}/bin/java"
        major=$(java_major "$cand")
        if [ "$major" -ge 21 ] 2>/dev/null; then echo "$cand"; return 0; fi
        echo "WARN: JAVA_HOME=${JAVA_HOME} 为 JDK ${major}，低于 21，继续探测" >&2
    fi
    # 3) 系统已装 JDK
    for dir in /usr/lib/jvm/*21* /usr/lib/jvm/*-21-* /opt/jdk-21* /usr/java/jdk-21*; do
        [ -x "${dir}/bin/java" ] || continue
        cand="${dir}/bin/java"
        major=$(java_major "$cand")
        if [ "$major" -ge 21 ] 2>/dev/null; then echo "$cand"; return 0; fi
    done
    # 4) PATH 中的 java
    if command -v java >/dev/null 2>&1; then
        cand=$(command -v java)
        major=$(java_major "$cand")
        if [ "$major" -ge 21 ] 2>/dev/null; then echo "$cand"; return 0; fi
    fi
    return 1
}

# --------------------------------------------------------- 运行时自检 ----
# jlink 裁剪运行时的兜底检查。
#
# 为什么需要它：裁剪后的运行时如果缺模块，报错形式是 ClassNotFoundException /
# NoClassDefFoundError，堆栈很深且指向的往往不是真正的缺失点。现场看到
# "NoClassDefFoundError: java/beans/PropertyChangeEvent" 时，几乎没人能立刻
# 想到"缺 java.desktop"。实测这个异常只在渲染验证码时才触发 —— 也就是说
# 服务已经启动成功、运维以为没事了，等用户第一次打开登录页才炸。
#
# 所以这里在启动前主动探测，缺模块时立刻停下并指名道姓说缺什么。
#
# 实现注意：**不能用 `java Probe.java` 单文件源码模式**。
# 那种模式依赖 jdk.compiler，而按设计裁剪掉的运行时正好没有它，
# 会先报 "Module jdk.compiler not in boot Layer"，把真正缺的模块信息盖掉。
# 所以用 javac 预编译成 .class，再用 -cp 运行。
runtime_selfcheck() {
    local jvm=$1
    local probe_dir javac_bin out rc=0

    # 系统 JDK（非 jlink 产物）模块齐全，不必探测。
    case "$jvm" in
        "${JRE_HOME}/bin/java") ;;
        *) return 0 ;;
    esac

    probe_dir=$(mktemp -d 2>/dev/null) || return 0

    # 编译用的 javac：裁剪运行时通常没有，需借外部 JDK。
    javac_bin=""
    for c in "${JRE_HOME}/bin/javac" "$(dirname "$jvm")/javac" "$(command -v javac 2>/dev/null)"; do
        [ -n "$c" ] && [ -x "$c" ] && { javac_bin="$c"; break; }
    done

    cat > "${probe_dir}/Probe.java" <<'PROBE_EOF'
import java.awt.image.BufferedImage;
import java.util.prefs.Preferences;

public class Probe {
    public static void main(String[] a) throws Exception {
        new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB).getGraphics(); // java.desktop
        Class.forName("java.sql.Driver");                                   // java.sql
        Class.forName("javax.naming.Context");                              // java.naming
        Class.forName("java.lang.management.ManagementFactory");            // java.management
        Class.forName("org.ietf.jgss.GSSManager");                          // jgss
        Preferences.userRoot();                                             // java.prefs
        System.out.println("RUNTIME_OK");
    }
}
PROBE_EOF

    if [ -z "$javac_bin" ]; then
        echo "WARN: 找不到 javac，跳过内置运行时自检"
        echo "      如需启用自检，请安装任意 JDK 或保证 jre/bin/javac 存在"
        rm -rf "$probe_dir"
        return 0
    fi

    if ! "$javac_bin" -d "$probe_dir" "${probe_dir}/Probe.java" >"${probe_dir}/javac.log" 2>&1; then
        echo "WARN: 自检代码编译失败，跳过运行时自检:"
        head -3 "${probe_dir}/javac.log" 2>/dev/null | sed 's/^/      /'
        rm -rf "$probe_dir"
        return 0
    fi

    "$jvm" -cp "$probe_dir" Probe >"${probe_dir}/out" 2>&1 || rc=1
    out=$(cat "${probe_dir}/out" 2>/dev/null)
    rm -rf "$probe_dir"

    if [ "$rc" -eq 0 ] && echo "$out" | grep -q RUNTIME_OK; then
        return 0
    fi

    echo "ERROR: 内置运行时自检未通过 —— jlink 裁剪的 jre 缺少必需模块。"
    echo "       运行时: ${jvm}"
    echo
    echo "       缺失线索:"
    echo "$out" | grep -iE "ClassNotFound|NoClassDefFound|Error|Exception" | head -5 | sed 's/^/         /'
    echo
    if echo "$out" | grep -qiE "awt|beans|imageio|desktop"; then
        echo "       判定: 缺 java.desktop（验证码/二维码渲染必须，去掉会导致登录页崩溃）。"
    elif echo "$out" | grep -qiE "sql"; then
        echo "       判定: 缺 java.sql（JDBC 驱动）。"
    elif echo "$out" | grep -qiE "naming|ldap"; then
        echo "       判定: 缺 java.naming（LDAP/JNDI）。"
    elif echo "$out" | grep -qiE "management"; then
        echo "       判定: 缺 java.management（JMX/Druid 监控）。"
    elif echo "$out" | grep -qiE "jgss|gss"; then
        echo "       判定: 缺 java.security.jgss（Kerberos）。"
    else
        echo "       判定: 见上方异常；对照 bin/make-runtime.sh 的 --add-modules 清单补齐。"
    fi
    echo
    echo "       修复: 重新生成运行时"
    echo "             ./bin/make-runtime.sh --download"
    echo "       或临时改用完整 JDK:"
    echo "             export JAVA_HOME=/path/to/jdk-21 && ./bin/maxkeyctl.sh start"
    return 1
}

# --------------------------------------------------------------- 应用表 ----
app_jar() {
    case "$1" in
        portal) ls -1 "${BASE_DIR}/maxkey"/maxkey-boot-*.jar 2>/dev/null | head -1 ;;
        mgt)    ls -1 "${BASE_DIR}/maxkey_mgt"/maxkey-mgt-boot-*.jar 2>/dev/null | head -1 ;;
    esac
}

app_port()  { [ "$1" = "portal" ] && echo "$PORTAL_PORT" || echo "$MGT_PORT"; }
app_opts()  { [ "$1" = "portal" ] && echo "$JAVA_OPTS_PORTAL" || echo "$JAVA_OPTS_MGT"; }
app_name()  { [ "$1" = "portal" ] && echo "MaxKey(认证中心)" || echo "MaxKeyMgt(管理端)"; }

pid_file()  { echo "${RUN_DIR}/maxkey-$1.pid"; }
out_file()  { echo "${LOG_DIR}/nohup-$1.out"; }

app_dir() {
    case "$1" in
        portal) echo "${BASE_DIR}/maxkey" ;;
        mgt)    echo "${BASE_DIR}/maxkey_mgt" ;;
    esac
}

is_running() {
    local pf
    pf=$(pid_file "$1")
    [ -f "$pf" ] || return 1
    local pid
    pid=$(cat "$pf" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

port_open() {
    local port=$1
    (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null && exec 3<&- && return 0
    return 1
}

# --------------------------------------------------------------- 动作 ----
do_start() {
    local app=$1
    local name jar port opts jvm pid

    name=$(app_name "$app")
    jar=$(app_jar "$app")
    port=$(app_port "$app")
    opts=$(app_opts "$app")

    if [ -z "$jar" ]; then
        echo "ERROR: 未找到 ${app} 的 jar，请检查 ${BASE_DIR}/maxkey 或 ${BASE_DIR}/maxkey_mgt"
        return 1
    fi
    if is_running "$app"; then
        echo "${name} 已在运行 (PID $(cat "$(pid_file "$app")"))，跳过"
        return 0
    fi
    if port_open "$port"; then
        echo "ERROR: 端口 ${port} 已被其它进程占用，${name} 无法启动"
        echo "       排查: ss -lntp | grep :${port}"
        return 1
    fi

    jvm=$(find_java) || {
        echo "ERROR: 未找到 JDK 21+"
        echo "       补救: ① 执行 bin/make-runtime.sh 生成包内 jre；或 ② export JAVA_HOME=/path/to/jdk-21"
        return 1
    }

    # 启动前做一次运行时自检（仅对包内 jlink jre 生效，见函数注释）。
    # 缺模块时在这里就明确报错，而不是等用户打开登录页渲染验证码时才崩。
    runtime_selfcheck "$jvm" || return 1

    echo "-------------------------------------------------------------"
    echo "  启动 ${name}"
    echo "  java    : ${jvm}"
    echo "  jar     : ${jar}"
    echo "  port    : ${port}"
    echo "  opts    : ${opts}"
    echo "-------------------------------------------------------------"

    # java.awt.headless=true: 无图形环境必须，验证码(图片)在 headless 下正常渲染
    # -XX:+ExitOnOutOfMemoryError: OOM 时让进程退出由 systemd/脚本重启，而不是假死
    # SERVER_PORT: 每个应用端口不同，必须按应用逐个下发
    #
    # cd 到 $(app_dir) 的原因：log4j2.xml 里写的是相对路径 logs/maxkey.log，
    # 不切换工作目录的话日志会落在“调用者当前目录”，从 / 或 /root 启动时
    # 要么散落别处，要么因无写权限直接起不来。
    #
    # 截断 history 日志的原因：> 是追加模式，长期运行会膨胀到 GB 级
    # （实测一次排障事故中 nohup 文件涨到 14GB 并耗尽磁盘）。
    local out
    out=$(out_file "$app")
    if [ -f "$out" ] && [ "$(stat -c %s "$out" 2>/dev/null || echo 0)" -gt 52428800 ]; then
        mv "$out" "${out}.$(date +%Y%m%d%H%M%S)"
    fi

    ( cd "$(app_dir "$app")" && \
      SERVER_PORT="$port" exec "$jvm" \
        ${opts} \
        ${SPRING_EXTRA_OPTS} \
        -Dfile.encoding=UTF-8 \
        -Duser.timezone=Asia/Shanghai \
        -Djava.awt.headless=true \
        -Djava.security.egd=file:/dev/./urandom \
        -XX:+ExitOnOutOfMemoryError \
        -jar "$jar" \
        >>"$out" 2>&1 ) &

    pid=$!
    echo "$pid" > "$(pid_file "$app")"

    # 等待端口就绪
    local waited=0
    while [ "$waited" -lt "$START_TIMEOUT" ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "ERROR: ${name} 进程已退出，最近日志:"
            tail -30 "$out"
            rm -f "$(pid_file "$app")"
            return 1
        fi
        if port_open "$port"; then
            echo "${name} 启动成功 (PID ${pid}, 端口 ${port}, 耗时 ${waited}s)"
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
        [ $((waited % 20)) -eq 0 ] && echo "  ... 已等待 ${waited}s (端口 ${port} 未就绪)"
    done

    echo "WARN: ${name} 进程存活但 ${START_TIMEOUT}s 内端口 ${port} 未就绪，请检查 $(out_file "$app")"
    return 1
}

do_stop() {
    local app=$1 name pf pid waited
    name=$(app_name "$app")
    pf=$(pid_file "$app")

    if ! is_running "$app"; then
        echo "${name} 未运行"
        rm -f "$pf"
        return 0
    fi
    pid=$(cat "$pf")
    echo "停止 ${name} (PID ${pid}) ..."
    kill "$pid" 2>/dev/null
    waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 40 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "  优雅停止超时，强制结束"
        kill -9 "$pid" 2>/dev/null
        sleep 1
    fi
    rm -f "$pf"
    echo "${name} 已停止"
}

do_status() {
    local app=$1 name port
    name=$(app_name "$app")
    port=$(app_port "$app")
    if is_running "$app"; then
        printf "%-22s RUNNING  pid=%-8s port=%s(%s)\n" \
            "$name" "$(cat "$(pid_file "$app")")" "$port" \
            "$(port_open "$port" && echo listening || echo not-listening)"
        return 0
    fi
    printf "%-22s STOPPED  port=%s\n" "$name" "$port"
    return 3
}

# --------------------------------------------------------------- 主流程 ----
ACTION=${1:-}
TARGET=${2:-all}

case "$ACTION" in
    start|stop|restart|status|java) ;;
    *)
        sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac

if [ "$ACTION" = "java" ]; then
    jvm=$(find_java) || { echo "未找到 JDK 21+"; exit 1; }
    echo "java      = $jvm"
    echo "major     = $(java_major "$jvm")"
    echo "JAVA_HOME = ${JAVA_HOME:-<未设置>}"
    "$jvm" -version
    exit 0
fi

case "$TARGET" in
    portal|mgt) APPS="$TARGET" ;;
    all)        APPS="portal mgt" ;;
    *) echo "未知目标: $TARGET (可选 portal|mgt|all)"; exit 2 ;;
esac

rc=0
for app in $APPS; do
    case "$ACTION" in
        start)   do_start   "$app" || rc=1 ;;
        stop)    do_stop    "$app" || rc=1 ;;
        restart) do_stop    "$app"; do_start "$app" || rc=1 ;;
        status)  do_status  "$app" || rc=1 ;;
    esac
done

# 清理过期日志（仅 start/stop 时执行，避免 status 产生副作用）
if [ "$ACTION" != "status" ] && [ "$LOG_KEEP_DAYS" -gt 0 ] 2>/dev/null; then
    find "$LOG_DIR" -maxdepth 1 -name 'nohup-*.out.*' -mtime "+${LOG_KEEP_DAYS}" -delete 2>/dev/null
fi

exit $rc
