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

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONF_FILE="${BASE_DIR}/conf/maxkey.env"
RUN_DIR="${BASE_DIR}/run"
LOG_DIR="${BASE_DIR}/logs"

mkdir -p "$RUN_DIR" "$LOG_DIR"

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

# maxkey.server.scheme 在 properties 中是写死的 http，无法用环境变量覆盖，
# 故启动时用 -D 显式下发（-D 优先级高于 application.properties）
SPRING_EXTRA_OPTS="-Dmaxkey.server.scheme=${MAXKEY_SCHEME}"

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
    # 1) 显式指定（systemd / 环境变量）
    if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
        cand="${JAVA_HOME}/bin/java"
        major=$(java_major "$cand")
        if [ "$major" -ge 21 ] 2>/dev/null; then echo "$cand"; return 0; fi
        echo "WARN: JAVA_HOME=${JAVA_HOME} 为 JDK ${major}，低于 21，继续探测" >&2
    fi
    # 2) 发布包内置运行时（jlink 裁剪结果）
    if [ -x "${BASE_DIR}/jre/bin/java" ]; then echo "${BASE_DIR}/jre/bin/java"; return 0; fi
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
