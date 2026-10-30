#!/bin/bash
############################################################################
#  build-package.sh — 在开发/构建机生成可拷贝到麒麟的可部署包
#
#  产物结构（安装包与更新包是同一个 tar.gz —— 避免"包内容与脚本版本"错配）:
#
#     maxkey-deploy-<版本>-<sha>-<时间戳>/
#     ├── manifest.json           版本/提交/构建时间/文件校验和
#     ├── VERSION                 同上，纯文本
#     ├── maxkey/                 maxkey-boot-*.jar
#     ├── maxkey_mgt/             maxkey-mgt-boot-*.jar
#     ├── web/
#     │   ├── maxkey/             前端认证中心 dist/browser
#     │   └── maxkey-mgt/         前端管理端 dist/browser
#     ├── jre/                    jlink 裁剪运行时（装到共享目录，不随版本复制）
#     ├── conf/maxkey.env         配置模板（含全部默认值与注释）
#     ├── env/                    环境档案 dev-local.env / test1.env ...
#     ├── lib/common.sh           install/upgrade/rollback/uninstall/verify 共用
#     ├── lib/db.sh               数据库操作（JDBC / sys_dump / Flyway）
#     ├── bin/maxkeyctl.sh        启停控制（随版本走）
#     ├── bin/make-runtime.sh     运行时生成工具
#     ├── bin/preflight.sh        部署前环境自检
#     ├── bin/rebind-site.sh      换域名后重绑库里与域名绑死的数据
#     ├── bin/migrate.sh          单独跑 Flyway 迁移
#     ├── install.sh              首次安装
#     ├── upgrade.sh              只更新包（自动备份 + 迁移 + 健康检查）
#     ├── rollback.sh             回滚到指定版本
#     ├── uninstall.sh            分级卸载
#     ├── verify.sh               双向验证（装完整 / 卸干净）
#     ├── nginx/                  nginx 片段
#     ├── systemd/                systemd 单元
#     └── sql/
#         ├── maxkey-seed.sql     种子库（44 张表 + admin + 管理端应用）
#         ├── migrations/         Flyway 增量迁移 V<n>__*.sql（只增不改）
#         └── lib/                pgjdbc + flyway + 工具类（约 2.5MB，离线可用）
#
#  用法:
#      ./build-package.sh                # 【默认】构建后端+前端+内置 jre，完整出包
#      ./build-package.sh --fast         # 跳过 gradle/前端，用已有产物（只改了
#                                        #   deployment/ 下的脚本或 sql/ 种子规则时用）
#      ./build-package.sh --keep-jre     # 强制重新 jlink（默认已有则复用）
#      ./build-package.sh --help
#
#  版本号 = gradle.properties 的 4.2.0 + git 短 sha + 构建时间戳
#      例：4.2.0-a1b2c3d-20261029T231500
#      为什么加后两段：同一版本号会打很多次包（改代码不改版本号），
#      只用 4.2.0 会让新包覆盖旧版本目录，恰好把回滚目标抛掉。
#
#  为什么默认就做全套（--build --with-runtime 已内化）:
#      这两步恰恰是"忘了加就出事"的两步，且失败代价极高：
#        * 没有内置 jre → 麒麟机通常只有 JDK 8，装上去必然
#          UnsupportedClassVersionError，而构建日志一切正常，
#          问题要到目标机启动时才暴露。
#        * 没有重新构建 → 用的是旧 jar / 旧 dist。改了代码却发出旧包，
#          比构建失败更难发现（这次就踩过：管理端 dist 比源码旧）。
#      把危险路径设为默认、把快速路径设为显式选项，符合"默认安全"。
#
#      代价是默认多花 3~6 分钟。只改了脚本/配置/种子规则时，用 --fast 即可
#      （实测约 30 秒：跳过 gradle/前端，且复用上一次的 jre，不重新 jlink）。
#
#  注意：内置 jre 默认用 Adoptium Temurin 构建（glibc 基线 2.15），
#        可在普通 x86_64 Linux 出包并在麒麟 V10(2.28) 运行。
#        复用已有 JDK：MAKE_RUNTIME_ARGS=/opt/temurin21 ./build-package.sh
############################################################################

set -eu
# pipefail 必须开：前端构建用 `... | tee log` 保留输出，
# 没有 pipefail 时管道的退出码是 tee 的（永远 0），
# pnpm 构建失败会被静默吞掉，最后打出旧 dist —— 比构建失败更难发现。
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "${HERE}/../.." && pwd)
# gradle.properties 里是 `version<spaces>=4.2.0`（等号紧贴值），
# 用 awk '{print $3}' 会取到空串，这里按 = 号切更稳
BASE_VERSION=$(sed -n 's/^version[[:space:]]*=[[:space:]]*//p' "${REPO}/gradle.properties" | head -1 | tr -d ' \r')
[ -n "$BASE_VERSION" ] || { echo "ERROR: 无法从 gradle.properties 解析 version"; exit 1; }

# 版本号 = 4.2.0 + git 短 sha + 构建时间戳
#
# 为什么不只用 4.2.0：改代码通常不改 gradle.properties，于是同一个 4.2.0
# 会被反复打包。若 releases/ 下按 4.2.0 命名，新包会直接覆盖上一份 ——
# 恰好把"可回滚的上一版"抛掉，而这正是本方案的核心价值。
# 加 sha 与时间戳后每次构建都是独立目录，回滚窗口不再被覆盖。
GIT_SHA=$(git -C "$REPO" rev-parse --short=7 HEAD 2>/dev/null || echo "nogit")
BUILD_TS=$(date +%Y%m%dT%H%M%S)
VERSION="${BASE_VERSION}-${GIT_SHA}-${BUILD_TS}"
PKG_NAME="maxkey-deploy-${VERSION}"
OUT="${REPO}/build/${PKG_NAME}"

# 默认做全套（等价于旧的 --build --with-runtime）。
# --fast 跳过 gradle/前端，仅复用已有产物重新组装与打包。
DO_BUILD=1
WITH_RUNTIME=1
FORCE_JRE=0
# 复用"上一次构建的 jre"：jre 与源码无关，重建纯属浪费。
# 但它现在落在**稳定的** build/jre-shared/（不再随包目录 rm -rf 消失），
# 所以 --fast 与连续两次全量构建都能直接复用。
JRE_CACHE="${REPO}/build/jre-shared"
for a in "$@"; do
    case "$a" in
        --fast)         DO_BUILD=0 ;;   # 跳过 gradle/前端
        --no-runtime)   WITH_RUNTIME=0 ;; # 显式不要内置 jre（需目标机自带 JDK21）
        --build)        DO_BUILD=1 ;;   # 兼容旧用法（已是默认）
        --with-runtime) WITH_RUNTIME=1 ;; # 兼容旧用法（已是默认）
        --keep-jre)     FORCE_JRE=1 ;;    # 忽略已有 jre，重新 jlink
        -h|--help)
            sed -n '2,52p' "${BASH_SOURCE[0]}" | sed 's/^#//'
            exit 0 ;;
        *) echo "未知参数: $a"; echo "用 --help 查看用法"; exit 2 ;;
    esac
done

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }

# ------------------------------------------------------- corepack 位置 ----
# corepack 随 node 一起装，但常不在 PATH 上（本机就是：/usr/bin/node 是
# Ubuntu 自带的 18.x，corepack 在 nvm 的 node 22 目录里）。
# 原实现只在 PATH 上找 corepack，找不到就静默跳过整个前端构建，
# 最后用旧 dist 打包 —— 这正是"改了前端却发旧包"的真实成因。
# 现在改为主动探测：PATH -> nvm 目录 -> COREPACK_CMD 覆盖，找不到就报错。
resolve_corepack() {
    if [ -n "${COREPACK_CMD:-}" ]; then
        printf '%s' "$COREPACK_CMD"
        return 0
    fi
    local c
    if c=$(command -v corepack 2>/dev/null) && [ -n "$c" ]; then
        printf '%s' "corepack"
        return 0
    fi
    # node 版本管理器装的位置。
    #
    # 优先 22.x，而不是"最新"：本机 nvm 里有 20/22/24 三个版本，按版本号倒序
    # 会挑到 24.14.0，而 Angular CLI 要求 >= 22.22.3 或 >= 24.15.0 —— 24.14.0
    # 恰好落在"太新但不满足"的缝里，报 "requires a minimum Node.js version"。
    # 团队约定与文档记录的构建版本是 node 22.23.2，故优先 22.x。
    # 需要换版本时用 NODE_BIN_DIR 显式指定。
    if [ -n "${NODE_BIN_DIR:-}" ]; then
        if [ -x "${NODE_BIN_DIR}/corepack" ]; then
            printf '%s' "env PATH=${NODE_BIN_DIR}:\$PATH corepack"
            return 0
        fi
    fi
    local cands=""
    for c in $(ls -1d "${HOME}"/.nvm/versions/node/*/bin/corepack 2>/dev/null); do
        case "$c" in
            */node/v22.*) cands="${cands} ${c}" ;;
        esac
    done
    for c in $(ls -1d "${HOME}"/.nvm/versions/node/*/bin/corepack 2>/dev/null | sort -rV); do
        case "$c" in
            */node/v22.*) ;;                 # 已在上面排过
            *) cands="${cands} ${c}" ;;
        esac
    done
    for c in ${cands} /usr/local/bin/corepack /usr/lib/node_modules/corepack/dist/corepack.js; do
        if [ -x "$c" ]; then
            # 必须在同一 node 下跑：corepack 是 node 脚本，靠 shebang 找 node
            local nbindir
            nbindir=$(dirname "$c")
            if [ -x "${nbindir}/node" ]; then
                printf '%s' "env PATH=${nbindir}:\$PATH corepack"
            else
                printf '%s' "$c"
            fi
            return 0
        fi
    done
    return 1
}

# 开头就把本次模式打出来，避免"以为在快速打包、实际在跑全量"这类误判
if [ "$DO_BUILD" = "1" ]; then
    echo "模式: 完整构建（后端 gradle + 前端 pnpm）"
else
    echo "模式: --fast（跳过 gradle/前端，复用已有 jar 与 dist）"
    echo "      提示: 若改过 Java 或前端代码，请去掉 --fast 重新构建"
fi
if [ "$WITH_RUNTIME" = "1" ]; then
    echo "      jre : 需要（已存在则复用，否则用 Temurin 生成）"
else
    echo "      jre : 【不含】已指定 --no-runtime，目标机必须自带 JDK 21"
fi

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
    #
    # gradle 默认把 wrapper 与依赖缓存放 $HOME/.gradle。在受限环境
    # （只读家目录、CI 容器、部分沙箱）会直接失败：
    #   FileNotFoundException: ~/.gradle/wrapper/dists/.../gradle-9.1.0-bin.zip.lck
    #     (Permission denied)
    #
    # 兜底**不能简单地改指一个空目录**：那会让 gradle 重新下载发行版
    # （实测 ~/.gradle 里其实已解压好 gradle-9.1.0，改指空目录后变成
    # Downloading ... / timeout，反而把原本能过的构建搞挂）。
    # 因此改指前先把 ~/.gradle 的 wrapper 与 caches **复制**过去
    # （不用软链：gradle 要在 dists 目录里创建 .lck 锁文件，
    #  软链到只读位置仍然写不进去）。
    if [ -z "${GRADLE_USER_HOME:-}" ]; then
        # 探测方式必须是"真的写一个文件"。
        # 踩过的坑：用 `mkdir -p ~/.gradle/wrapper` 探测会假阳性 ——
        # 目录本来就存在时 mkdir 什么都不做、直接返回 0，
        # 于是判定"可写"，但后续 gradle 真正创建 .lck 文件时才被拒。
        GRADLE_PROBE="${HOME}/.gradle/.write-probe.$$"
        if ! ( : > "$GRADLE_PROBE" ) 2>/dev/null; then
            ALT_HOME="${REPO}/.gradle-home"
            mkdir -p "$ALT_HOME"
            for sub in wrapper caches; do
                if [ -e "${HOME}/.gradle/${sub}" ] && [ ! -e "${ALT_HOME}/${sub}" ]; then
                    echo "  复制 ${HOME}/.gradle/${sub} -> ${ALT_HOME}/${sub}（复用已有缓存，避免重新下载）"
                    cp -a "${HOME}/.gradle/${sub}" "${ALT_HOME}/${sub}" 2>/dev/null || \
                        echo "  WARN: 复制 ${sub} 失败，gradle 可能需要联网重新下载"
                fi
            done
            export GRADLE_USER_HOME="$ALT_HOME"
            echo "  \$HOME/.gradle 不可写，GRADLE_USER_HOME 改用 ${GRADLE_USER_HOME}"
        else
            rm -f "$GRADLE_PROBE"
        fi
    fi
    # shellcheck disable=SC2086
    ( cd "$REPO" && ./gradlew :maxkey-webs:maxkey-web-maxkey:bootJar \
        :maxkey-webs:maxkey-web-mgt:bootJar -x test ${GRADLE_EXTRA_ARGS:-} )

    say "构建前端 (node 22.23.2 + pnpm，锁文件固定)"

    COREPACK_BIN=$(resolve_corepack) || {
        cat <<'EOM'
  ERROR: 找不到 corepack —— 无法构建前端。

  前端产物是交付包的一部分，静默跳过会用**上一次的旧 dist** 打包，
  这正是"改了代码却发出旧包"的成因，因此这里直接失败而不是跳过。

  任选其一：
    a) 把 corepack 加入 PATH（node >= 16.10 自带）：
         export PATH="$HOME/.nvm/versions/node/v22.23.2/bin:$PATH"
    b) 显式指定调用方式：
         COREPACK_CMD="/path/to/node /path/to/corepack pnpm" ./deployment/kylin/build-package.sh
    c) 只要后端与脚本、确认前端无改动：
         ./deployment/kylin/build-package.sh --fast
EOM
        exit 1
    }
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
    #
    # 判断依据必须是「缓存里有没有可用的 pnpm」，而不是「家目录能不能建目录」。
    # 踩过的坑（真实事故）：
    #   原先只探测 `mkdir -p ~/.cache/node/corepack` 是否成功。家目录可写时
    #   就走默认路径，但那份缓存可能是**残缺**的 —— 例如只有 JS 入口、
    #   缺 pnpm-native 这个原生二进制（56MB）。此时 corepack 会去
    #   https://registry.npmjs.org/@pnpm/exe.linux-x64/<ver> 现场下载，
    #   在内网/代理受限环境下直接失败：
    #       Could not download the pnpm 12.6.0 binary: fetch failed
    #   而仓库内 .cache/corepack 是团队共享、已完整下载并验证过的，
    #   本该优先使用，却因为"家目录可写"被绕过了。
    #
    # 因此改为：只要仓库缓存里有该版本的原生二进制，就优先用它；
    # 家目录不可写时同样回退到仓库缓存。两种情况都可被 COREPACK_HOME 覆盖。
    if [ -z "${COREPACK_HOME:-}" ]; then
        REPO_COREPACK="${REPO}/.cache/corepack"
        # 仓库缓存是否完整：存在任一 pnpm 版本目录且含 pnpm-native 可执行文件
        REPO_COREPACK_OK=0
        for cand in "${REPO_COREPACK}"/v1/pnpm/*/pnpm-native; do
            [ -x "$cand" ] && { REPO_COREPACK_OK=1; break; }
        done

        if [ "$REPO_COREPACK_OK" = "1" ]; then
            export COREPACK_HOME="$REPO_COREPACK"
            echo "  COREPACK_HOME: ${COREPACK_HOME}（仓库内完整缓存，优先使用）"
        elif ! ( mkdir -p "${HOME}/.cache/node/corepack" 2>/dev/null ); then
            export COREPACK_HOME="$REPO_COREPACK"
            mkdir -p "$COREPACK_HOME"
            echo "  \$HOME 不可写，COREPACK_HOME 改用 ${COREPACK_HOME}（需联网下载 pnpm）"
        else
            echo "  COREPACK_HOME: 默认 (~/.cache/node/corepack)"
        fi
    else
        echo "  COREPACK_HOME: ${COREPACK_HOME}（由环境变量指定）"
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
        # 把前端构建的输出留在变量里：失败时要能判断是不是 corepack/pnpm 的问题，
        # 而不是只给用户一行 "fetch failed"。
        FE_LOG=$(mktemp)
        if ! ( cd "$fdir" && eval "${COREPACK_BIN} pnpm install --frozen-lockfile" && \
               NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=8000}" \
               eval "${COREPACK_BIN} pnpm run build:prod" ) 2>&1 | tee "$FE_LOG"; then
            echo
            echo "ERROR: 前端构建失败（${d}）"
            if grep -qE "Could not download the pnpm .* binary|fetch failed" "$FE_LOG"; then
                cat <<EOF
  原因: corepack 拿不到 pnpm 二进制。
        通常是你本机 ~/.cache/node/corepack 里的缓存**不完整**
        （只有 JS 入口、缺 pnpm-native 原生二进制），
        而当前网络又下载不了 registry.npmjs.org 上的对应包。

  最省事的解法 —— 改用仓库内那份已验证完整的缓存：
        COREPACK_HOME=${REPO}/.cache/corepack ./deployment/kylin/build-package.sh

  或者把仓库里的原生二进制补到你自己的缓存（版本需与 package.json 一致）：
        cp -a ${REPO}/.cache/corepack/v1/pnpm/12.6.0/pnpm-native \\
              ~/.cache/node/corepack/v1/pnpm/12.6.0/

  排查用：
        ls ~/.cache/node/corepack/v1/pnpm/*/pnpm-native
        # 无输出 = 缓存残缺
EOF
            else
                echo "  详见上面的输出。日志: ${FE_LOG}"
            fi
            rm -f "$FE_LOG"
            exit 1
        fi
        rm -f "$FE_LOG"
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
mkdir -p "$OUT"/{maxkey,maxkey_mgt,web/maxkey,web/maxkey-mgt,conf,bin,nginx,systemd,sql/lib,sql/migrations,lib,env,tools}

# jre 是 jlink 产物，与源码无关，重建纯属浪费（缓存缺失时要重下 207MB）。
# 缓存在 build/jre-shared/（仓库内固定位置，不随包目录删除而消失）。
JRE_REUSED=0
if [ "$FORCE_JRE" = "0" ] && [ -x "${JRE_CACHE}/bin/java" ]; then
    cp -a "${JRE_CACHE}" "$OUT/jre"
    JRE_REUSED=1
    echo "  复用 ${JRE_CACHE} 的 jre（$(du -sh "$OUT/jre" | cut -f1)），跳过 jlink 生成"
elif [ -x "${REPO}/build/maxkey-deploy-4.2.0/jre/bin/java" ] && [ "$FORCE_JRE" = "0" ]; then
    # 兼容：从旧包目录里捞一份已有 jre，避免首次迁移时重新下载
    cp -a "${REPO}/build/maxkey-deploy-4.2.0/jre" "$OUT/jre"
    JRE_REUSED=1
    echo "  复用旧包目录里的 jre（$(du -sh "$OUT/jre" | cut -f1)）"
fi

cp "$PORTAL_JAR" "$OUT/maxkey/"
cp "$MGT_JAR"    "$OUT/maxkey_mgt/"

# 前端产物：拷贝 dist/browser 的**内容**到 maxkey/ 与 maxkey-mgt/ 子目录，
# 与 nginx 片段中的 root/子目录 假设对应
cp -a "${PORTAL_DIST}/." "$OUT/web/maxkey/"
cp -a "${MGT_DIST}/."    "$OUT/web/maxkey-mgt/"

# ---- 运行时脚本与库：包根放"面向运维的五件事"，bin/ 放运行期工具 ----
# 这个划分是有意的：运维只需要记住包根的五个动词
# （install / upgrade / rollback / uninstall / verify），
# 其余（启停、自检、迁移、换域名）都是运行期辅助。
cp -a "${HERE}/lib"              "$OUT/"
cp "${HERE}/bin/maxkeyctl.sh"    "$OUT/bin/"
cp "${HERE}/bin/make-runtime.sh" "$OUT/bin/"
cp "${HERE}/bin/preflight.sh"    "$OUT/bin/"
cp "${HERE}/bin/rebind-site.sh"  "$OUT/bin/" 2>/dev/null || true
cp "${HERE}/bin/migrate.sh"      "$OUT/bin/" 2>/dev/null || true
for f in install.sh upgrade.sh rollback.sh uninstall.sh verify.sh; do
    [ -f "${HERE}/${f}" ] && cp "${HERE}/${f}" "$OUT/"
done
chmod +x "$OUT"/*.sh 2>/dev/null || true

# ---- 环境档案：随包分发（不含口令），切环境只需换 --profile ----
cp "${HERE}/env/"*.env "$OUT/env/" 2>/dev/null || true
cp "${HERE}/conf/maxkey.env"     "$OUT/conf/"
# 口令密钥模板：运维据此创建 /etc/maxkey/maxkey-secret.env
cp "${HERE}/conf/maxkey-secret.env.example" "$OUT/conf/" 2>/dev/null || true
cp "${HERE}/nginx/"*.conf        "$OUT/nginx/"
cp "${HERE}/systemd/"*.service   "$OUT/systemd/"
# 建库脚本用「最小种子」版：表结构 44 张全保留，只裁掉演示历史/头像/图标，
# 并固定生成「管理端自身」那三行（apps / cas_details / access）。
# 实测从 18.9MB 降到 0.4MB。
#
# **每次都重新生成**，而不是"文件存在就跳过"。
# 踩过的坑：只判断存在性时，改了 make-seed.py（例如调整裁剪规则、修管理端
# 应用地址）却因为旧文件还在，打包静默用了**陈旧产物** —— 包里是旧数据，
# 而构建日志一切正常，极难发现。make-seed.py 本身很快（秒级），
# 无条件重跑的成本远低于这个风险。
SEED_SQL="${REPO}/sql/kingbase/maxkey-seed.sql"
say "生成最小种子建库脚本"
python3 "${REPO}/sql/kingbase/make-seed.py" --verify >/dev/null || {
    echo "ERROR: 生成 ${SEED_SQL} 失败，请检查 sql/kingbase/make-seed.py"
    echo "       单独执行以查看自检输出: python3 sql/kingbase/make-seed.py --verify"
    exit 1; }
cp "$SEED_SQL" "$OUT/sql/"
cp "${REPO}/sql/kingbase/make-seed.py"          "$OUT/sql/" 2>/dev/null || true
cp "${REPO}/sql/kingbase/convert_from_mysql.py" "$OUT/sql/" 2>/dev/null || true

chmod +x "$OUT/bin/"*.sh

# ------------------------------------------------ 迁移工具与驱动（约 2.5MB） ----
# 为什么不打包官方 flyway-commandline：实测 linux-x64 发行包 476MB
# （打包了所有数据库的驱动），而实际只需要：
#     flyway-core (768KB) + flyway-database-postgresql (48KB)
#     + pgjdbc (1.1MB) + gson (300KB)  ≈ 2.5MB
# 每次更新都要把 400MB 的包传到测试机，多 476MB 不可接受。
#
# 为什么驱动要 pgjdbc（而不是包内已有的 kingbase8）：
#     Flyway 12 的 PostgreSQLDatabaseType 判据是
#     databaseProductName.startsWith("PostgreSQL")，
#     而 kingbase8 驱动返回 "KingbaseES" → 直接 Unsupported Database。
#     pgjdbc 连同一台库返回 "PostgreSQL"（已实测：12.1 / 44 张表）。
#     金仓官方文档也是这么要求的。
say "准备迁移工具与驱动"

MVN_CACHE="${REPO}/.cache/flyway"
mkdir -p "$MVN_CACHE" "$OUT/sql/lib/classes"

# 版本与 Spring Boot 4.1.0 的 BOM 对齐（flyway-core 12.4.0），
# 避免"应用内 12.x、迁移工具 10.x"这种跨大版本混用。
FLYWAY_VER="${FLYWAY_VER:-12.4.0}"
PGJDBC_VER="${PGJDBC_VER:-42.7.4}"
GSON_VER="${GSON_VER:-2.11.0}"
FLYWAY_BASE="https://repo1.maven.org/maven2"

fetch_jar() {
    # $1 = 相对路径（groupPath/artifact/ver/artifact-ver.jar）
    local rel=$1 name
    name=$(basename "$rel")
    if [ -f "${MVN_CACHE}/${name}" ]; then
        cp "${MVN_CACHE}/${name}" "${OUT}/sql/lib/"
        echo "    缓存 ${name}"
        return 0
    fi
    echo "    下载 ${name}"
    if ! curl -fsSL --max-time 300 -o "${MVN_CACHE}/${name}.part" "${FLYWAY_BASE}/${rel}"; then
        rm -f "${MVN_CACHE}/${name}.part"
        echo "ERROR: 下载失败: ${FLYWAY_BASE}/${rel}"
        echo "       目标机通常无外网，故驱动必须随包分发。"
        echo "       可在有网机器上执行同样的 fetch 后，把文件放进 ${MVN_CACHE}/ 再打包。"
        return 1
    fi
    mv "${MVN_CACHE}/${name}.part" "${MVN_CACHE}/${name}"
    cp "${MVN_CACHE}/${name}" "${OUT}/sql/lib/"
}

fetch_jar "org/flywaydb/flyway-core/${FLYWAY_VER}/flyway-core-${FLYWAY_VER}.jar"
fetch_jar "org/flywaydb/flyway-database-postgresql/${FLYWAY_VER}/flyway-database-postgresql-${FLYWAY_VER}.jar"
fetch_jar "org/postgresql/postgresql/${PGJDBC_VER}/postgresql-${PGJDBC_VER}.jar"
fetch_jar "com/google/code/gson/gson/${GSON_VER}/gson-${GSON_VER}.jar"

# Flyway 12 用 Jackson **3**（包名 tools.jackson）解析配置，缺了会抛
#   ClassNotFoundException: tools.jackson.databind.ObjectMapper
# 报错位置在 Flyway 构造阶段，看起来像"Flyway 装坏了"。
# 版本跟随项目 gradle.properties 的 jackson3Version，避免与仓库其它地方不一致。
JACKSON3_VER=$(sed -n 's/^jackson3Version[[:space:]]*=[[:space:]]*//p' "${REPO}/gradle.properties" | head -1 | tr -d ' \r')
: "${JACKSON3_VER:=3.0.4}"

# 优先从本机 Gradle 缓存取（构建机通常已有，离线也能出包）；
# 缓存里没有再联网下载。
fetch_jar_local_first() {
    # $1 = gradle 缓存 group 路径, $2 = 完整 maven 相对路径
    local grp=$1 rel=$2 name
    name=$(basename "$rel")
    if [ -f "${MVN_CACHE}/${name}" ]; then
        cp "${MVN_CACHE}/${name}" "${OUT}/sql/lib/"; echo "    缓存 ${name}"; return 0
    fi
    local hit
    hit=$(find "${HOME}/.gradle/caches/modules-2/files-2.1/${grp}" -name "$name" 2>/dev/null | head -1)
    if [ -n "$hit" ]; then
        cp "$hit" "${OUT}/sql/lib/"
        cp "$hit" "${MVN_CACHE}/" 2>/dev/null || true
        echo "    Gradle 缓存 ${name}"
        return 0
    fi
    fetch_jar "$rel"
}

fetch_jar_local_first "tools.jackson.core/jackson-databind" \
    "tools/jackson/core/jackson-databind/${JACKSON3_VER}/jackson-databind-${JACKSON3_VER}.jar"
fetch_jar_local_first "tools.jackson.core/jackson-core" \
    "tools/jackson/core/jackson-core/${JACKSON3_VER}/jackson-core-${JACKSON3_VER}.jar"
# annotations 在 Jackson 3 里仍沿用 com.fasterxml 坐标（2.x 版本号），
# 但 3.x 的 databind 兼容它。取项目已用的 2.22。
fetch_jar_local_first "com.fasterxml.jackson.core/jackson-annotations" \
    "com/fasterxml/jackson/core/jackson-annotations/${JACKSON_ANN_VER:-2.22}/jackson-annotations-${JACKSON_ANN_VER:-2.22}.jar"

# kingbase8 驱动复用仓库里的（与应用连库时用的是同一个 jar，行为一致）
if [ -f "${REPO}/maxkey-lib/kingbase8-9.0.0.jar" ]; then
    cp "${REPO}/maxkey-lib/kingbase8-9.0.0.jar" "$OUT/sql/lib/"
    echo "    kingbase8-9.0.0.jar（仓库内）"
fi

# 编译两个几十行的入口类。用**系统 JDK 21** 编译（构建机必有），
# 目标机只需运行，因此 --release 21 生成的字节码能在裁剪 jre 上跑。
# 不能用 jre 里的 javac：jlink 裁剪后通常不含 jdk.compiler。
JC=$(command -v javac || true)
if [ -z "$JC" ] && [ -x "/usr/lib/jvm/java-21-openjdk-amd64/bin/javac" ]; then
    JC="/usr/lib/jvm/java-21-openjdk-amd64/bin/javac"
fi
[ -n "$JC" ] || { echo "ERROR: 找不到 javac（需要 JDK 21+ 编译迁移工具）"; exit 1; }

for f in MaxKeySql MaxKeyMigrate; do
    "$JC" --release 21 -encoding UTF-8 -d "$OUT/sql/lib/classes" "${HERE}/tools/${f}.java" || {
        echo "ERROR: 编译 ${f}.java 失败"; exit 1; }
done
echo "    已编译 MaxKeySql / MaxKeyMigrate"

# 迁移文件：只增不改（Flyway 校验和会拒绝已发布文件被修改）
if [ -d "${REPO}/sql/kingbase/migrations" ]; then
    cp -a "${REPO}/sql/kingbase/migrations/." "$OUT/sql/migrations/" 2>/dev/null || true
fi
if [ -z "$(ls -A "$OUT/sql/migrations" 2>/dev/null)" ]; then
    warn_empty_migrations() {
        cat <<'EOM'
    注意：sql/migrations/ 为空。
    首次安装用种子库建表（44 张），Flyway baseline 到 V1；
    之后的表结构变更请新增 sql/kingbase/migrations/V<n>__<描述>.sql（只增不改）。
    update.sh 会在每次升级时自动执行其中尚未应用的迁移。
EOM
    }
    warn_empty_migrations
fi

# ------------------------------------------------------------- 内置 JDK ----
# 关键：不能用系统自带 JDK（Ubuntu/Debian 打包版基线可达 glibc 2.38，
# 麒麟 V10 只有 2.28 会加载失败）。make-runtime.sh 内部会校验并拦截，
# 这里默认走 --download 拿 Adoptium Temurin（基线 2.15）。
# 若构建机已有 Temurin，可传 MAKE_RUNTIME_ARGS 指向它复用。
if [ "${JRE_REUSED:-0}" = "1" ]; then
    :   # 已复用上次的 jre，无需生成
elif [ "$WITH_RUNTIME" = "1" ]; then
    say "生成内置运行时 (jlink + Temurin)"

    # ---- 把 Temurin 缓存固定在**包目录之外** ----
    # make-runtime.sh 按 `ROOT=$(cd "${HERE}/.." && pwd)` 推缓存目录，
    # 而这里是在 $OUT 里执行它，于是 ROOT=$OUT，
    # 缓存就落进 build/maxkey-deploy-<ver>/.cache/temurin —— 而 $OUT
    # 每次打包都会被 rm -rf 重建。结果：**缓存永远活不过一次构建**，
    # 每次 --with-runtime 都要重新下载 207MB（实测慢时 20 分钟）。
    # 因此显式指定一个稳定位置：仓库根 .cache/temurin（已被 .gitignore 忽略）。
    # 仍允许调用方用 TEMURIN_CACHE 覆盖（如团队共享目录）。
    if [ -z "${TEMURIN_CACHE:-}" ]; then
        TEMURIN_CACHE="${REPO}/.cache/temurin"
        export TEMURIN_CACHE
    fi
    mkdir -p "$TEMURIN_CACHE" 2>/dev/null || true
    echo "  Temurin 缓存: ${TEMURIN_CACHE}"

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
    say "跳过内置运行时（--no-runtime）"
    # 这里**不能只打印提示就继续打包**。
    # 踩过的坑：包目录每次都会被 rm -rf 重建，上一次构建好的 jre 被一并删掉，
    # 最后打出一个**没有 jre 的包**；而麒麟目标机通常只有 JDK 8，
    # 装上去必然 UnsupportedClassVersionError，问题却要到目标机启动时才暴露。
    cat <<'EOF'
  ERROR: 指定了 --no-runtime，包内将不含内置 jre。

  目标麒麟机常只有 JDK 8/11/17，而 MaxKey 4.2.0 是 Java 21 字节码，
  没有内置运行时将无法启动。

  通常你不需要 --no-runtime —— 直接执行（默认就会生成 jre）：
         ./deployment/kylin/build-package.sh

  想复用本机已有的 Temurin JDK（不联网下载）：
         MAKE_RUNTIME_ARGS=/path/to/temurin21 ./deployment/kylin/build-package.sh

  仅当**确认目标机已装 JDK 21** 时，才可加 ALLOW_NO_RUNTIME=1 跳过本检查：
         ALLOW_NO_RUNTIME=1 ./deployment/kylin/build-package.sh --no-runtime
EOF
    if [ "${ALLOW_NO_RUNTIME:-0}" != "1" ]; then
        exit 1
    fi
    echo "  WARN: ALLOW_NO_RUNTIME=1，按你的要求继续（目标机须自带 JDK 21）"
fi

# ------------------------------------------------------------ manifest ----
say "生成 manifest.json 与 VERSION"
# manifest 是"这台机器装的是哪次构建"的唯一凭据：
#   upgrade.sh 用它判断"包比当前版本旧/新"，rollback.sh 用它列出可回滚的版本，
#   verify.sh 用它比对磁盘上的文件是否与包一致。
cat > "$OUT/VERSION" <<EOF
${VERSION}
EOF

# jre 是否随包（决定 install 时能否跳过 JDK 探测）
HAS_JRE="false"
[ -x "$OUT/jre/bin/java" ] && HAS_JRE="true"

# 迁移文件清单（升级前用它判断"本版本是否带了 schema 变更"）
MIGRATIONS=$(cd "$OUT/sql/migrations" 2>/dev/null && ls -1 V*.sql 2>/dev/null | tr '\n' ' ' || true)

cat > "$OUT/manifest.json" <<EOF
{
  "product": "maxkey",
  "version": "${VERSION}",
  "baseVersion": "${BASE_VERSION}",
  "gitSha": "${GIT_SHA}",
  "buildTime": "$(date -Iseconds)",
  "builtBy": "$(id -un 2>/dev/null || echo unknown)@$(hostname 2>/dev/null || echo unknown)",
  "hasJre": ${HAS_JRE},
  "portalJar": "$(basename "$PORTAL_JAR")",
  "mgtJar": "$(basename "$MGT_JAR")",
  "migrations": "${MIGRATIONS}",
  "seedSql": "sql/maxkey-seed.sql",
  "profiles": "$(cd "$OUT/env" && ls -1 *.env 2>/dev/null | sed 's/\.env$//' | tr '\n' ' ')",
  "checksums": "checksums.sha256"
}
EOF

# 校验和清单（不含 jre 与 web，它们体积大且已有各自的内容指纹；
# 这里覆盖的是"出问题必然导致启动失败"的那部分：jar / 脚本 / sql / 配置）
(
    cd "$OUT"
    find maxkey maxkey_mgt bin lib conf env nginx systemd sql tools \
         install.sh upgrade.sh rollback.sh uninstall.sh verify.sh manifest.json VERSION \
         -type f 2>/dev/null | sort | xargs sha256sum 2>/dev/null
) > "$OUT/checksums.sha256"
echo "  manifest: ${VERSION}  (git ${GIT_SHA}, jre=${HAS_JRE})"
echo "  校验和: $(wc -l < "$OUT/checksums.sha256") 个文件"

# ----------------------------------------------------------------- 打包 ----
say "打包 tar.gz"
# make-runtime.sh 会把 Temurin 的下载缓存放在 <包根>/.cache/temurin
# （545MB：207MB 的 tar.gz + 解压后的 JDK）。那是**构建期**中间产物，
# 绝不能进交付包 —— 漏排会让包体从 ~250MB 涨到 ~800MB，目标机又用不到。
# 这里显式排除，并在打包前清掉。
if [ -d "${OUT}/.cache" ]; then
    echo "  排除构建缓存 ${OUT}/.cache ($(du -sh "${OUT}/.cache" 2>/dev/null | cut -f1))"
    rm -rf "${OUT}/.cache"
fi
( cd "$(dirname "$OUT")" && tar czf "${PKG_NAME}.tar.gz" \
    --exclude="${PKG_NAME}/.cache" \
    "${PKG_NAME}" )

echo
echo "完成:"
echo "  目录: ${OUT}"
echo "  压缩包: $(dirname "$OUT")/${PKG_NAME}.tar.gz  ($(du -h "$(dirname "$OUT")/${PKG_NAME}.tar.gz" | cut -f1))"
echo
echo "部署到目标机（统一装到 /opt/maxkey）:"
echo
echo "  # 首次安装一台新机器（先改 env/<环境名>.env 里的域名/证书/数据库）"
echo "  tar xzf ${PKG_NAME}.tar.gz && cd ${PKG_NAME}"
echo "  sudo ./install.sh --profile <环境名> --dry-run"
echo "  sudo ./install.sh --profile <环境名> --init-db"
echo "  sudo ./verify.sh --expect installed"
echo
echo "  # 日常更新（同一个包，传到目标机后执行）"
echo "  sudo ./upgrade.sh ${PKG_NAME}.tar.gz"
echo
echo "  # 出问题回滚"
echo "  sudo ./rollback.sh --list"
echo "  sudo ./rollback.sh --to <版本>"
echo
echo "  # 卸载（默认只摘服务；--purge 删程序；--purge-all 删库）"
echo "  sudo ./uninstall.sh --purge"
echo "  sudo ./verify.sh --expect removed"
