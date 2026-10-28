#!/bin/bash
############################################################################
#  build-package.sh — 在开发/构建机生成可拷贝到麒麟的可部署包
#
#  产物结构（与 make-runtime.sh、maxkeyctl.sh 的假设一致）:
#
#     maxkey-kylin-<version>/
#     ├── maxkey/                 maxkey-boot-*.jar  + logs/
#     ├── maxkey_mgt/             maxkey-mgt-boot-*.jar + logs/
#     ├── web/
#     │   ├── maxkey/             前端认证中心 dist/browser
#     │   └── maxkey-mgt/         前端管理端 dist/browser
#     ├── jre/                    jlink 裁剪运行时（可选，make-runtime.sh 生成）
#     ├── conf/maxkey.env         部署配置
#     ├── bin/maxkeyctl.sh        启停控制
#     ├── bin/make-runtime.sh     运行时生成工具
#     ├── bin/preflight.sh        部署前环境自检
#     ├── nginx/                  两套 nginx 片段
#     ├── systemd/                systemd 单元
#     └── sql/                    Kingbase 建库脚本
#
#  用法:
#      ./build-package.sh                       # 用已存在的 jar 与 dist
#      ./build-package.sh --build               # 先跑 gradle 与前端构建
#      ./build-package.sh --with-runtime        # 同时 jlink 出内置 jre（自动取 Temurin）
#
#  注意：--with-runtime 默认用 Adoptium Temurin 构建 jre（glibc 基线 2.15），
#        可直接在普通 x86_64 Linux 出包并在麒麟 V10(2.28) 运行。
#        若想复用已有 JDK：MAKE_RUNTIME_ARGS=/opt/temurin21 ./build-package.sh --with-runtime
############################################################################

set -eu

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "${HERE}/../.." && pwd)
# gradle.properties 里是 `version<spaces>=4.2.0`（等号紧贴值），
# 用 awk '{print $3}' 会取到空串，这里按 = 号切更稳
VERSION=$(sed -n 's/^version[[:space:]]*=[[:space:]]*//p' "${REPO}/gradle.properties" | head -1 | tr -d ' \r')
[ -n "$VERSION" ] || { echo "ERROR: 无法从 gradle.properties 解析 version"; exit 1; }
PKG_NAME="maxkey-kylin-${VERSION}"
OUT="${REPO}/build/${PKG_NAME}"

DO_BUILD=0
WITH_RUNTIME=0
for a in "$@"; do
    case "$a" in
        --build)        DO_BUILD=1 ;;
        --with-runtime) WITH_RUNTIME=1 ;;
        *) echo "未知参数: $a"; exit 2 ;;
    esac
done

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ------------------------------------------------------------ 前置检查 ----
say "检查构建产物"

PORTAL_JAR=$(ls -1 "${REPO}"/maxkey-webs/maxkey-web-maxkey/build/libs/maxkey-boot-*ga.jar 2>/dev/null | head -1 || true)
MGT_JAR=$(ls -1 "${REPO}"/maxkey-webs/maxkey-web-mgt/build/libs/maxkey-mgt-boot-*ga.jar 2>/dev/null | head -1 || true)
PORTAL_DIST="${REPO}/maxkey-web-frontend/maxkey-web-ng/dist/browser"
MGT_DIST="${REPO}/maxkey-web-frontend/maxkey-web-mgt-ng/dist/browser"

if [ "$DO_BUILD" = "1" ]; then
    say "构建后端 (gradle bootJar)"
    ( cd "$REPO" && ./gradlew :maxkey-webs:maxkey-web-maxkey:bootJar :maxkey-webs:maxkey-web-mgt:bootJar -x test )

    say "构建前端 (需要 node 22 + pnpm)"
    command -v pnpm >/dev/null || { echo "ERROR: 未安装 pnpm"; exit 1; }
    ( cd "${REPO}/maxkey-web-frontend/maxkey-web-ng"     && pnpm install --frozen-lockfile && pnpm run build:prod )
    ( cd "${REPO}/maxkey-web-frontend/maxkey-web-mgt-ng" && pnpm install --frozen-lockfile && pnpm run build:prod )

    PORTAL_JAR=$(ls -1 "${REPO}"/maxkey-webs/maxkey-web-maxkey/build/libs/maxkey-boot-*ga.jar 2>/dev/null | head -1 || true)
    MGT_JAR=$(ls -1 "${REPO}"/maxkey-webs/maxkey-web-mgt/build/libs/maxkey-mgt-boot-*ga.jar 2>/dev/null | head -1 || true)
fi

[ -n "$PORTAL_JAR" ] || { echo "ERROR: 缺少 maxkey-boot-*.jar，请加 --build 或先执行 gradle bootJar"; exit 1; }
[ -n "$MGT_JAR" ]    || { echo "ERROR: 缺少 maxkey-mgt-boot-*.jar，请加 --build"; exit 1; }
[ -d "$PORTAL_DIST" ] || { echo "ERROR: 缺少前端产物 ${PORTAL_DIST}，请加 --build"; exit 1; }
[ -d "$MGT_DIST" ]    || { echo "ERROR: 缺少前端产物 ${MGT_DIST}，请加 --build"; exit 1; }

echo "  portal jar : $(basename "$PORTAL_JAR")  ($(du -h "$PORTAL_JAR" | cut -f1))"
echo "  mgt jar    : $(basename "$MGT_JAR")  ($(du -h "$MGT_JAR" | cut -f1))"
echo "  web portal : ${PORTAL_DIST}"
echo "  web mgt    : ${MGT_DIST}"

# ------------------------------------------------------------ 组装目录 ----
say "组装 ${PKG_NAME}"
rm -rf "$OUT"
mkdir -p "$OUT"/{maxkey,maxkey_mgt,web/maxkey,web/maxkey-mgt,conf,bin,nginx,systemd,sql}

cp "$PORTAL_JAR" "$OUT/maxkey/"
cp "$MGT_JAR"    "$OUT/maxkey_mgt/"

# 前端产物：拷贝 dist/browser 的**内容**到 maxkey/ 与 maxkey-mgt/ 子目录，
# 与 nginx 片段中的 root/子目录 假设对应
cp -a "${PORTAL_DIST}/." "$OUT/web/maxkey/"
cp -a "${MGT_DIST}/."    "$OUT/web/maxkey-mgt/"

cp "${HERE}/bin/maxkeyctl.sh"    "$OUT/bin/"
cp "${HERE}/bin/make-runtime.sh" "$OUT/bin/"
cp "${HERE}/bin/preflight.sh"    "$OUT/bin/"
cp "${HERE}/conf/maxkey.env"     "$OUT/conf/"
cp "${HERE}/nginx/"*.conf        "$OUT/nginx/"
cp "${HERE}/systemd/"*.service   "$OUT/systemd/"
cp "${REPO}/sql/kingbase/maxkey.sql"        "$OUT/sql/"
cp "${REPO}/sql/kingbase/convert_from_mysql.py" "$OUT/sql/" 2>/dev/null || true

chmod +x "$OUT/bin/"*.sh

# ------------------------------------------------------------- 内置 JDK ----
# 关键：不能用系统自带 JDK（Ubuntu/Debian 打包版基线可达 glibc 2.38，
# 麒麟 V10 只有 2.28 会加载失败）。make-runtime.sh 内部会校验并拦截，
# 这里默认走 --download 拿 Adoptium Temurin（基线 2.15）。
# 若构建机已有 Temurin，可传 TEMURIN_DIR 或直接指定 JDK 路径复用。
if [ "$WITH_RUNTIME" = "1" ]; then
    say "生成内置运行时 (jlink + Temurin)"
    if [ -n "${MAKE_RUNTIME_ARGS:-}" ]; then
        ( cd "$OUT" && ./bin/make-runtime.sh ${MAKE_RUNTIME_ARGS} )
    else
        ( cd "$OUT" && ./bin/make-runtime.sh --download )
    fi
    # 二次确认：产物基线必须 <= 目标
    if [ -x "${OUT}/jre/bin/java" ]; then
        NEED=$(objdump -T "${OUT}/jre/lib/server/libjvm.so" 2>/dev/null \
               | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -uV | tail -1)
        echo "  内置运行时 glibc 基线: ${NEED:-unknown}  ($(du -sh "${OUT}/jre" | cut -f1))"
    fi
else
    say "跳过内置运行时"
    echo "  请在出包前执行以下之一（二者都需要，否则目标机无 JDK 21 时无法启动）："
    echo "    (cd ${OUT} && ./bin/make-runtime.sh --download)"
    echo "    ./build-package.sh --with-runtime"
fi

# ----------------------------------------------------------------- 打包 ----
say "打包 tar.gz"
( cd "$(dirname "$OUT")" && tar czf "${PKG_NAME}.tar.gz" "${PKG_NAME}" )

echo
echo "完成:"
echo "  目录: ${OUT}"
echo "  压缩包: $(dirname "$OUT")/${PKG_NAME}.tar.gz  ($(du -h "$(dirname "$OUT")/${PKG_NAME}.tar.gz" | cut -f1))"
echo
echo "部署到麒麟（统一装到 /opt/maxkey，systemd 单元按此路径写死）:"
echo "  tar xzf ${PKG_NAME}.tar.gz -C /opt"
echo "  mv /opt/${PKG_NAME} /opt/maxkey"
echo "  vi /opt/maxkey/conf/maxkey.env"
echo "  /opt/maxkey/bin/maxkeyctl.sh start"
echo
echo "若必须保留版本号目录，则需同步修改 systemd/*.service 里的"
echo "PIDFile / ExecStart / ReadWritePaths 与 EnvironmentFile 路径。"
