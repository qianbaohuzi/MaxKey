#!/bin/bash
############################################################################
#  make-runtime.sh — 生成发布包内置的精简 Java 运行时（jlink）
#
#  为什么需要它:
#      麒麟 V10 自带 JDK 常为 8/11/17，而 MaxKey 4.2.0 字节码为 class file
#      major 65（Java 21），低版本 JDK 直接 UnsupportedClassVersionError。
#      与其要求在每台机器上装 JDK 21，不如把运行时随包分发。
#
#  为什么不用完整 JDK:
#      完整 JDK 约 300MB+；裁剪后约 60MB，只保留运行必需模块。
#
#  模块清单来源:
#      用 jdeps 对 maxkey-boot jar 实际分析得出，并逐项做了启动验证：
#        jdeps --print-module-deps --multi-release 21 \
#              --class-path "BOOT-INF/lib/*" BOOT-INF/classes
#        => java.base,java.compiler,java.desktop,java.instrument,java.net.http,
#           java.prefs,java.rmi,java.scripting,java.security.jgss,java.sql.rowset,
#           java.xml.crypto,jdk.attach,jdk.jdi,jdk.jfr,jdk.management,jdk.unsupported
#
#      在此基础上做了两处“实测必需”的调整（缺了会启动失败）：
#        * 加 java.desktop —— 验证码走 java.awt/BufferedImage；
#          去掉后实测 NoClassDefFoundError: java/beans/PropertyChangeEvent
#        * 去掉 jdk.attach/jdk.jdi/jdk.jfr —— 仅 jdeps 静态推断的间接引用，
#          实测不需要，可省约 20MB
#      另外补充 java.sql / java.naming / java.management / java.security.sasl /
#      java.transaction.xa / jdk.crypto.ec / jdk.zipfs / jdk.charsets /
#      jdk.localedata：MySQL/Kingbase JDBC、TLS、中文时区与编码依赖它们，
#      属于“运行期反射加载”，jdeps 静态分析看不到。
#
#  用法:
#      ./make-runtime.sh --download                # 推荐：固定版 Temurin 21，带缓存
#      ./make-runtime.sh --clean-cache             # 清空 Temurin 缓存（545MB）
#      ./make-runtime.sh /opt/jdk-21               # 用已有 JDK 21（须低 glibc 基线）
#      TEMURIN_CACHE=/data/ci ./make-runtime.sh --download   # 指定共享缓存目录
#      TARGET_GLIBC=2.34 ./make-runtime.sh --download        # 覆盖目标基线
#
#  关键约束（本脚本会自动校验）:
#      产物 jre 的 libjvm.so 依赖的 GLIBC_* 必须 <= 目标机 glibc。
#      实测：Ubuntu 打包的 openjdk-21 需 GLIBC_2.38（麒麟 2.28 跑不了）；
#            Adoptium Temurin 只需 GLIBC_2.15（可用）。
#      故默认走 Temurin，且固定版本 + sha256 校验，保证可复现与防篡改。
#
#  产物:
#      <发布根>/jre/   约 64MB，含 bin/java
#      缓存: <包根>/.cache/temurin/jdk-<ver>/   （压缩包 + 解压副本）
############################################################################

set -eu

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${HERE}/.." && pwd)
OUT="${ROOT}/jre"

# ---------------------------------------------------------------------------
#  glibc 基线检测
#
#  原理（这是本方案能否"一次构建、多环境运行"的关键）：
#    glibc 符号版本是**向后兼容**的 —— 低版本 glibc 上构建的产物可以在
#    高版本上运行；反之不行。
#    实测同一台机器上：
#      Ubuntu 24.04 自带的 openjdk-21  -> libjvm.so 需要 GLIBC_2.38
#      Temurin 官方构建的 JDK 21       -> libjvm.so 需要 GLIBC_2.15
#    麒麟 V10 是 glibc 2.28，所以只有后者能跑。
#
#  因此**不需要在麒麟上构建**，只需要用"低基线"的 JDK 发行版即可。
# ---------------------------------------------------------------------------
glibc_needed_by() {
    local libjvm="$1/lib/server/libjvm.so"
    [ -f "$libjvm" ] || { echo "unknown"; return; }
    command -v objdump >/dev/null 2>&1 || { echo "unknown"; return; }
    local v
    v=$(objdump -T "$libjvm" 2>/dev/null | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -uV | tail -1)
    echo "${v#GLIBC_}"
}

ver_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }

# ---------------------------------------------------------------- 参数 ----
# 用法:
#   ./make-runtime.sh                       自动探测本机 JDK 21
#   ./make-runtime.sh /opt/jdk-21           指定 JDK 路径
#   ./make-runtime.sh --download            取固定版 Temurin 21（有缓存则复用，推荐）
#   ./make-runtime.sh --clean-cache         清空 Temurin 缓存（强制下次重新下载）
#   TARGET_GLIBC=2.28 ./make-runtime.sh     指定目标机 glibc 基线
#   TEMURIN_CACHE=/data/cache ./make-runtime.sh --download   指定缓存目录
DO_DOWNLOAD=0
DO_CLEAN=0
SRC_JDK=""
for a in "$@"; do
    case "$a" in
        --download)    DO_DOWNLOAD=1 ;;
        --clean-cache) DO_CLEAN=1 ;;
        -h|--help)  sed -n '2,47p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          SRC_JDK="$a" ;;
    esac
done

# ---- --clean-cache：清空缓存目录 ----
if [ "$DO_CLEAN" = "1" ]; then
    if [ -n "${TEMURIN_CACHE:-}" ]; then
        CACHE_ROOT="$TEMURIN_CACHE"
    elif [ -d "${ROOT}/.cache/temurin" ]; then
        CACHE_ROOT="${ROOT}/.cache/temurin"
    else
        CACHE_ROOT="${HOME}/.cache/temurin"
    fi
    if [ -d "$CACHE_ROOT" ]; then
        SZ=$(du -sh "$CACHE_ROOT" 2>/dev/null | cut -f1)
        echo "删除缓存 ${CACHE_ROOT} (${SZ})"
        rm -rf "$CACHE_ROOT"
        echo "已清空。下次 --download 将重新联网获取。"
    else
        echo "缓存目录不存在：${CACHE_ROOT}"
    fi
    exit 0
fi
[ -z "$SRC_JDK" ] && SRC_JDK="${JAVA_HOME:-}"

# ---- --download：固定版本 Temurin（基线 glibc 2.15）+ 本地缓存 ----
#
# 设计要点：
#   1. **固定版本**，不用 latest。原因：
#      - latest 会随时间漂移，同一提交在不同时间构建出的包不一致（不可复现）
#      - 配合 sha256 校验，可确保下到的确实是 Temurin 官方产物（防篡改/防中间人）
#   2. **两级缓存**，避免每次构建都走网络：
#      - 压缩包缓存：<cache>/jdk-21.0.13+9/OpenJDK21U-jdk_<arch>_linux_hotspot_*.tar.gz
#      - 解压后目录缓存：<cache>/jdk-21.0.13+9/<arch>/  （命中则完全不再下载）
#      命中任一级即跳过网络；删除缓存目录即可强制重新下载。
#   3. 缓存位置（按优先级）：
#      $TEMURIN_CACHE  >  仓库内 .cache/temurin（团队共享、随项目复用）  >  ~/.cache/temurin
#
if [ "$DO_DOWNLOAD" = "1" ]; then
    # ---- 固定版本参数（升级时改这三项 + 两个 sha256）----
    # JDK_TAG 是 GitHub release tag（%2B 是 + 的 URL 编码，不能直接写 +）
    JDK_TAG="jdk-21.0.13%2B9"
    JDK_VERSION="21.0.13+9"              # 仅用于展示与缓存目录命名
    JDK_VERSION_UNDERSCORE="21.0.13_9"   # 用于安装包文件名

    case "$(uname -m)" in
        x86_64)
            TEM_ARCH=x64
            JDK_SHA256="d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c"
            ;;
        aarch64|arm64)
            TEM_ARCH=aarch64
            JDK_SHA256="e3522e707fc7dbe2a72c30746b1e7068301a0213ecd213d4491f35a14eb55578"
            ;;
        *)
            echo "ERROR: 不支持的架构 $(uname -m)。"
            echo "       请手工下载对应 Temurin，然后用: JAVA_HOME=/path ./make-runtime.sh"
            exit 1
            ;;
    esac

    PKG_NAME="OpenJDK21U-jdk_${TEM_ARCH}_linux_hotspot_${JDK_VERSION_UNDERSCORE}.tar.gz"
    PKG_URL="https://github.com/adoptium/temurin21-binaries/releases/download/${JDK_TAG}/${PKG_NAME}"

    # ---- 缓存根目录 ----
    if [ -n "${TEMURIN_CACHE:-}" ]; then
        CACHE_ROOT="$TEMURIN_CACHE"
    elif [ -w "${ROOT}" ] || mkdir -p "${ROOT}/.cache" 2>/dev/null; then
        CACHE_ROOT="${ROOT}/.cache/temurin"
    else
        CACHE_ROOT="${HOME}/.cache/temurin"
    fi

    CACHE_DIR="${CACHE_ROOT}/jdk-${JDK_VERSION}"
    CACHED_TGZ="${CACHE_DIR}/${PKG_NAME}"
    CACHED_JDK="${CACHE_DIR}/${TEM_ARCH}"

    echo "Temurin    : ${JDK_VERSION} (${TEM_ARCH})  固定版本"
    echo "缓存目录   : ${CACHE_ROOT}"

    # ---- 一级命中：已解压的 JDK 目录 ----
    if [ -x "${CACHED_JDK}/bin/jlink" ]; then
        echo "[cache] 命中已解压 JDK，跳过下载与解压"
        SRC_JDK="$CACHED_JDK"
    else
        mkdir -p "${CACHE_DIR}"

        # ---- 二级命中：已下载的 tar.gz（校验通过才用）----
        if [ -f "${CACHED_TGZ}" ]; then
            echo "[cache] 发现已缓存的压缩包，校验完整性 ..."
            ACTUAL=$(sha256sum "${CACHED_TGZ}" 2>/dev/null | awk '{print $1}')
            if [ "$ACTUAL" != "$JDK_SHA256" ]; then
                echo "[cache] 缓存包校验失败（可能下载中断），将重新下载"
                echo "        期望 ${JDK_SHA256}"
                echo "        实际 ${ACTUAL:-<无法读取>}"
                rm -f "${CACHED_TGZ}"
            fi
        fi

        # ---- 缓存未命中：下载 ----
        if [ ! -f "${CACHED_TGZ}" ]; then
            echo "下载中（约 200MB，仅首次需要）:"
            echo "  ${PKG_URL}"
            # 先下到 .part，校验通过后再改名，避免半截文件被当成有效缓存
            TMP="${CACHED_TGZ}.part"
            rm -f "$TMP"
            if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 \
                       --progress-bar -o "$TMP" "$PKG_URL"; then
                echo
                echo "ERROR: 下载失败。"
                echo "  内网环境请在可联网机器下载同名文件后放入缓存目录："
                echo "    目标路径: ${CACHED_TGZ}"
                echo "    下载地址: ${PKG_URL}"
                echo "    校验方式: sha256sum ${PKG_NAME}   # 应为 ${JDK_SHA256}"
                rm -f "$TMP"
                exit 1
            fi
            echo
            echo "校验 sha256 ..."
            ACTUAL=$(sha256sum "$TMP" | awk '{print $1}')
            if [ "$ACTUAL" != "$JDK_SHA256" ]; then
                echo "ERROR: 校验失败，包可能损坏或被篡改"
                echo "  期望 ${JDK_SHA256}"
                echo "  实际 ${ACTUAL}"
                rm -f "$TMP"; exit 1
            fi
            echo "[ OK ] 校验通过"
            mv "$TMP" "${CACHED_TGZ}"
        else
            echo "[cache] 压缩包校验通过，跳过下载"
        fi

        # ---- 解压到缓存（用临时目录，成功后原子改名）----
        echo "解压到缓存 ..."
        rm -rf "${CACHED_JDK}.tmp"
        mkdir -p "${CACHED_JDK}.tmp"
        if ! tar xzf "${CACHED_TGZ}" -C "${CACHED_JDK}.tmp" --strip-components=1; then
            echo "ERROR: 解压失败"; rm -rf "${CACHED_JDK}.tmp"; exit 1
        fi
        rm -rf "${CACHED_JDK}"
        mv "${CACHED_JDK}.tmp" "${CACHED_JDK}"
        echo "[ OK ] 已缓存解压结果，后续构建将直接复用"
        SRC_JDK="${CACHED_JDK}"
    fi
fi

if [ -z "$SRC_JDK" ] || [ ! -x "${SRC_JDK}/bin/jlink" ]; then
    echo "未指定可用的 JDK（需要含 jlink 的完整 JDK 21+），开始自动探测 ..."
    for c in /usr/lib/jvm/*21* /opt/jdk-21* /usr/java/jdk-21*; do
        if [ -x "${c}/bin/jlink" ]; then SRC_JDK="$c"; break; fi
    done
fi

if [ -z "$SRC_JDK" ] || [ ! -x "${SRC_JDK}/bin/jlink" ]; then
    cat <<'EOF'
ERROR: 找不到含 jlink 的 JDK 21+。

说明：jlink 只在完整 JDK 中提供，JRE 不行。
      构建动作只需在**一台**机器上做一次，产物可整体拷贝到麒麟主机。

离线环境下可先获取任意 JDK 21 发行版（Temurin / 毕昇 / 龙芯 JDK 等）解压后用：
      JAVA_HOME=/opt/jdk-21.0.x ./make-runtime.sh
EOF
    exit 1
fi

# 校验构建用 JDK 主版本
MAJOR=$("${SRC_JDK}/bin/java" -version 2>&1 | head -1 | sed -n 's/.*version "\([0-9]*\).*/\1/p')
if [ "${MAJOR:-0}" -lt 21 ]; then
    echo "ERROR: 构建用 JDK 版本为 ${MAJOR}，必须 >= 21（否则 jlink 无法处理 class file major 65）"
    exit 1
fi

if [ -e "$OUT" ]; then
    echo "已存在 ${OUT}，先移除旧运行时"
    rm -rf "$OUT"
fi

ARCH=$(uname -m)
HOST_GLIBC=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')
NEED_GLIBC=$(glibc_needed_by "$SRC_JDK")

echo "构建主机   : ${ARCH}   (host glibc ${HOST_GLIBC:-unknown})"
echo "构建用 JDK : ${SRC_JDK} (major ${MAJOR})"
echo "产物需要   : glibc ${NEED_GLIBC}"
echo

# ---- 关键校验：产物 glibc 基线必须 <= 目标机 ----
# 麒麟 V10 系为 glibc 2.28，作为默认目标；可用 TARGET_GLIBC 覆盖。
# 规则：NEED <= TARGET 才可运行（glibc 向后兼容）。
: "${TARGET_GLIBC:=2.28}"
echo "目标基线   : glibc ${TARGET_GLIBC}（麒麟 V10 默认）"
echo

if [ "$NEED_GLIBC" = "unknown" ]; then
    echo "[WARN] 无法读取 libjvm.so 的 glibc 依赖（缺 objdump），请自行确认"
elif ver_ge "$TARGET_GLIBC" "$NEED_GLIBC"; then
    echo "[ OK ] 产物需 glibc ${NEED_GLIBC}，目标 ${TARGET_GLIBC} 满足，可在麒麟运行"
else
    echo "[FAIL] 该 JDK 产物需要 glibc ${NEED_GLIBC}，高于目标 ${TARGET_GLIBC}"
    cat <<EOF

原因：这是用**系统自带 JDK**（如 Ubuntu/Debian 打包版）构建的。
      它的 libjvm.so 链接了较新的 glibc 符号，麒麟 V10(2.28) 加载会失败，
      现场报错形如：version \\`GLIBC_${NEED_GLIBC}' not found

解法（都不需要在麒麟机器上构建）：

  ① 推荐 —— 改用 Adoptium Temurin 官方构建（基线仅 glibc 2.15）：
       curl -L -o /tmp/temurin21.tar.gz \
         "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk"
       mkdir -p /opt/temurin21
       tar xzf /tmp/temurin21.tar.gz -C /opt/temurin21 --strip-components=1
       JAVA_HOME=/opt/temurin21 ./bin/make-runtime.sh

  ② 用本脚本的一键模式（自动下载 Temurin 后重建）：
       ./bin/make-runtime.sh --download

  ③ 目标机已装 JDK 21（含毕昇 / 龙芯 JDK）时，跳过本步骤：
       export JAVA_HOME=/usr/lib/jvm/jdk-21

  ④ 目标机 glibc 实际更高时（如某些麒麟 V10 SP3 补丁版本）：
       TARGET_GLIBC=2.34 ./bin/make-runtime.sh
EOF
    exit 1
fi
echo

MODULES="java.base,java.compiler,java.desktop,java.instrument,java.logging,java.management,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.security.jgss,java.security.sasl,java.sql,java.sql.rowset,java.transaction.xa,java.xml,java.xml.crypto,jdk.charsets,jdk.crypto.ec,jdk.localedata,jdk.unsupported,jdk.zipfs"

echo "模块清单:"
echo "$MODULES" | tr ',' '\n' | sed 's/^/  - /'
echo

"${SRC_JDK}/bin/jlink" \
    --add-modules "$MODULES" \
    --include-locales=zh,en \
    --output "$OUT" \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=zip-6

echo
echo "已完成: ${OUT}  ($(du -sh "$OUT" | awk '{print $1}'))"
"${OUT}/bin/java" -version
echo
cat <<EOF
提示：
  1. 该运行时与构建机的 CPU 架构(${ARCH})和 glibc 基线绑定；
     目标麒麟主机若为 aarch64/龙芯/申威，须在对应架构机器上重新执行本脚本。
  2. 目标机 glibc 版本必须 >= 构建机。检查方法:
         ldd --version | head -1
  3. 若目标机已装 JDK 21，可跳过本步骤，改用:
         export JAVA_HOME=/usr/lib/jvm/jdk-21
     maxkeyctl.sh 会优先使用 JAVA_HOME。
EOF
