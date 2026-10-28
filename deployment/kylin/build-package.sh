#!/bin/bash
############################################################################
#  build-package.sh — 在开发/构建机生成可拷贝到麒麟的可部署包
#
#  产物结构（与 make-runtime.sh、maxkeyctl.sh 的假设一致）:
#
#     maxkey-deploy-<version>/
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
PKG_NAME="maxkey-deploy-${VERSION}"
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
    # GRADLE_EXTRA_ARGS 用于受限环境，例如：
    #   GRADLE_EXTRA_ARGS="--offline"        # 依赖已在本地缓存，不联网
    # 以及 GRADLE_USER_HOME 指向可写的缓存目录（$HOME 不可写时必需）
    # shellcheck disable=SC2086
    ( cd "$REPO" && ./gradlew :maxkey-webs:maxkey-web-maxkey:bootJar \
        :maxkey-webs:maxkey-web-mgt:bootJar -x test ${GRADLE_EXTRA_ARGS:-} )

    say "构建前端 (node 22.23.2 + pnpm，锁文件固定)"
    # 版本口径必须一致，否则依赖解析会漂。这里对 lockfile 做硬校验：
    # 缺少 pnpm-lock.yaml 就无法 --frozen-lockfile，构建不可复现，直接报错。
    #
    # corepack 在 $HOME 不可写时会失败（EACCES mkdir ~/.cache/node/corepack），
    # 故允许用 COREPACK_HOME 指向可写目录、COREPACK_CMD 指定调用方式。
    # 必须用 corepack 拉起 package.json 里声明的那个 pnpm 版本。
    #
    # 实测过踩坑：直接用 PATH 上的 pnpm（本机是 11.10.0）执行
    # `install --frozen-lockfile`，**不会报错，而是静默把 lockfile 改写**，
    # 而且是往 packageManagerDependencies 里补 @pnpm/exe 之类的条目。
    # 结果就是"构建成功但工作区变脏"，同一个提交在不同机器上产出不同包。
    # --frozen-lockfile 只保证"不改依赖版本"，不保证"不重写文件格式"。
    #
    # 因此这里做三件事：
    #   1. 通过 corepack 固定 pnpm 版本（读 package.json 的 packageManager）
    #   2. 构建前记录 lockfile 校验和
    #   3. 构建后比对，一旦被改写立即报错
    # corepack 默认把下载的 pnpm 放到 ~/.cache/node/corepack。
    # 在 $HOME 不可写（CI 容器、只读家目录、跳板机）时会直接崩：
    #   Error: EACCES: permission denied, mkdir '~/.cache/node/corepack/v1'
    # 所以这里探测家目录可写性，不可写就把它指到仓库内的缓存目录。
    if [ -z "${COREPACK_HOME:-}" ]; then
        if ! ( mkdir -p "${HOME}/.cache/node/corepack" 2>/dev/null ); then
            export COREPACK_HOME="${REPO}/.cache/corepack"
            mkdir -p "$COREPACK_HOME"
            echo "  \$HOME 不可写，COREPACK_HOME 改用 ${COREPACK_HOME}"
        fi
    fi

    for d in maxkey-web-ng maxkey-web-mgt-ng; do
        fdir="${REPO}/maxkey-web-frontend/${d}"
        lock="${fdir}/pnpm-lock.yaml"
        [ -f "$lock" ] || {
            echo "ERROR: 缺少 ${lock}"
            echo "       该文件必须入库，否则构建不可复现。"
            echo "       修复: cd ${fdir} && corepack pnpm install --lockfile-only"
            exit 1
        }
        before=$(cksum "$lock" | awk '{print $1"-"$2}')
        ( cd "$fdir" && ${COREPACK_CMD:-corepack pnpm} install --frozen-lockfile && \
          NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=8000}" \
          ${COREPACK_CMD:-corepack pnpm} run build:prod )
        after=$(cksum "$lock" | awk '{print $1"-"$2}')
        if [ "$before" != "$after" ]; then
            echo "ERROR: 构建过程改写了 ${lock}"
            echo "       说明用的 pnpm 版本与 lockfile 不匹配。"
            echo "       请用 corepack 执行，或先人工更新并提交 lockfile："
            echo "         cd ${fdir} && corepack pnpm install --lockfile-only"
            exit 1
        fi
    done

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
# 安装/卸载脚本放在包根目录，随包分发
cp "${HERE}/install.sh"          "$OUT/"
cp "${HERE}/uninstall.sh"        "$OUT/"
cp "${HERE}/conf/maxkey.env"     "$OUT/conf/"
# 口令密钥模板：运维据此创建 /etc/maxkey/maxkey-secret.env
cp "${HERE}/conf/maxkey-secret.env.example" "$OUT/conf/" 2>/dev/null || true
cp "${HERE}/nginx/"*.conf        "$OUT/nginx/"
cp "${HERE}/systemd/"*.service   "$OUT/systemd/"
# 建库脚本用「最小种子」版：表结构 44 张全保留，只裁掉演示历史/头像/图标。
# 实测从 18.9MB 降到 0.4MB，登录与 SSO 所需数据（admin 账号、机构、用户组、
# 菜单权限、OAuth client 注册信息、SAML 证书）全部在内。
# 生成方式见 sql/kingbase/make-seed.py（--verify 可自检）。
SEED_SQL="${REPO}/sql/kingbase/maxkey-seed.sql"
if [ ! -f "$SEED_SQL" ]; then
    say "生成最小种子建库脚本"
    python3 "${REPO}/sql/kingbase/make-seed.py" --verify >/dev/null || {
        echo "ERROR: 生成 ${SEED_SQL} 失败，请检查 sql/kingbase/make-seed.py"; exit 1; }
fi
cp "$SEED_SQL" "$OUT/sql/"
cp "${REPO}/sql/kingbase/make-seed.py"          "$OUT/sql/" 2>/dev/null || true
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
echo "部署到目标机（统一装到 /opt/maxkey，systemd 单元按此路径写死）:"
echo
echo "  tar xzf ${PKG_NAME}.tar.gz"
echo "  cd ${PKG_NAME}"
echo "  vi conf/maxkey.env           # 改 MAXKEY_PUBLIC_URL / SERVER_DOMAIN / NGINX_* 与数据库"
echo "  sudo ./install.sh --dry-run  # 先演练，确认将要做的事"
echo "  sudo ./install.sh            # 真正落盘（文件/systemd/nginx 配置）"
echo "  sudo vi /etc/maxkey/maxkey-secret.env   # 填数据库口令，600 root:root"
echo "  sudo ./bin/preflight.sh      # 环境自检"
echo "  sudo ./bin/maxkeyctl.sh start"
echo
echo "卸载: sudo ./uninstall.sh          （保留配置与数据）"
echo "      sudo ./uninstall.sh --purge  （连程序目录一起删，数据库不动）"
