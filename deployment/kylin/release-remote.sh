#!/bin/bash
############################################################################
#  release-remote.sh —— 本地打好的包，一条命令送到目标机并执行
#
#  为什么需要它：
#  「本地打包 → scp 到服务器 → ssh 上去执行脚本」这三步手敲时最容易
#  出三类错：传错目录、忘了执行、在错误的机器上执行。脚本化后只剩一条命令，
#  且每次都打印"传了什么、在哪台机器、执行了什么"。
#
#  ⚠️ 这是**开发侧**工具，不随包分发（目标机上不需要它）。
#
#  用法（在仓库根目录执行，不需要 root）：
#      # 首次：先注册目标机（会写到 .remote-targets，已在 .gitignore）
#      ./deployment/kylin/release-remote.sh --add test1 --host 10.0.0.11 \
#             --user root --dir /root/maxkey-release
#
#      # 首次安装（会调 install.sh --profile，需要交互填口令）
#      ./deployment/kylin/release-remote.sh test1 install --profile test1 --init-db
#
#      # 日常更新（推荐用法）
#      ./deployment/kylin/release-remote.sh test1 upgrade
#
#      # 回滚
#      ./deployment/kylin/release-remote.sh test1 rollback --list
#
#      # 只看将要执行什么
#      ./deployment/kylin/release-remote.sh test1 upgrade --dry-run
#
#  传输方式：rsync 优先（增量，重复传 400MB 包第二次只传变化块）；
#  目标机没有 rsync 时自动回退到 `ssh + tar` 管道（只依赖 ssh 与 tar）。
############################################################################

set -eu
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "${HERE}/../.." && pwd)
TARGETS_FILE="${REPO}/.remote-targets"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

usage() { sed -n '2,40p' "$0"; exit "${1:-0}"; }

# ------------------------------------------------------- 目标机注册表 ----
# 格式（每行）：名字<TAB>host<TAB>user<TAB>port<TAB>远程目录
# 为什么单独一个文件而不塞进 env/<profile>.env：
#   env/ 下的档案是**随包分发**的（要上传到目标机），
#   内网地址与 SSH 端口不该跟着包走。
target_get() {
    local name=$1
    [ -f "$TARGETS_FILE" ] || return 1
    awk -F'\t' -v n="$name" '$1==n {print; exit}' "$TARGETS_FILE"
}

target_add() {
    local name=$1 host=$2 user=$3 port=$4 dir=$5
    mkdir -p "$(dirname "$TARGETS_FILE")"
    touch "$TARGETS_FILE"
    chmod 600 "$TARGETS_FILE"
    # 同名的先删掉，保持"最后一次为准"
    if grep -q "^${name}	" "$TARGETS_FILE" 2>/dev/null; then
        local tmp; tmp=$(mktemp)
        awk -F'\t' -v n="$name" '$1!=n' "$TARGETS_FILE" > "$tmp"
        mv "$tmp" "$TARGETS_FILE"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$host" "$user" "$port" "$dir" >> "$TARGETS_FILE"
    chmod 600 "$TARGETS_FILE"
    info "已注册目标机 ${name} -> ${user}@${host}:${port}:${dir}"
}

list_targets() {
    if [ ! -f "$TARGETS_FILE" ] || [ ! -s "$TARGETS_FILE" ]; then
        echo "  （尚未注册目标机）"
        echo
        echo "  注册方式："
        echo "    $0 --add <名字> --host <IP> --user <用户> --dir <远程目录>"
        return 0
    fi
    printf '  %-12s %-24s %-20s %s\n' "名字" "地址" "远程目录" "端口"
    printf '  %-12s %-24s %-20s %s\n' "------------" "------------------------" "--------------------" "------"
    awk -F'\t' '{printf "  %-12s %-24s %-20s %s\n", $1, $3"@"$2, $5, $4}' "$TARGETS_FILE"
}

# ---------------------------------------------------------------- 参数 ----
NAME=""
ACTION=""
DRY_RUN=0
ADD=0
OPT_HOST=""
OPT_USER="root"
OPT_PORT=22
OPT_DIR="/root/maxkey-release"
PKG=""
ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --add)     ADD=1; shift; NAME=${1:?--add 需要名字} ;;
        --host)    shift; OPT_HOST=${1:?} ;;
        --user)    shift; OPT_USER=${1:?} ;;
        --port)    shift; OPT_PORT=${1:?} ;;
        --dir)     shift; OPT_DIR=${1:?} ;;
        --pkg)     shift; PKG=${1:?} ;;
        --dry-run) DRY_RUN=1 ;;
        --list|list) ACTION=list ;;
        -h|--help) usage 0 ;;
        -*)
            # 其余参数原样透传给远程脚本（例如 --profile test1 --init-db）
            ARGS+=("$1")
            ;;
        *)
            if [ -z "$NAME" ]; then NAME=$1
            elif [ -z "$ACTION" ]; then ACTION=$1
            else ARGS+=("$1")
            fi
            ;;
    esac
    shift
done

[ "$ADD" = "1" ] || [ -n "$ACTION" ]

if [ "$ADD" = "1" ]; then
    [ -n "$OPT_HOST" ] || die "--add 需要 --host"
    target_add "$NAME" "$OPT_HOST" "$OPT_USER" "$OPT_PORT" "$OPT_DIR"
    exit 0
fi

if [ "$ACTION" = "list" ]; then
    say "已注册的目标机"
    list_targets
    exit 0
fi

LINE=$(target_get "$NAME") || die "未注册目标机: ${NAME}
      先注册： $0 --add ${NAME} --host <IP> --user <用户> --dir <远程目录>
      或查看： $0 --list"

IFS=$'\t' read -r _ THOST TUSER TPORT TDIR <<< "$LINE"
info "目标机 : ${TUSER}@${THOST}:${TPORT}:${TDIR}"
info "动作   : ${ACTION} ${ARGS[*]:-}"

# ------------------------------------------------------------ 选哪个包 ----
if [ -z "$PKG" ]; then
    PKG=$(ls -1t "${REPO}"/build/maxkey-deploy-*.tar.gz 2>/dev/null | head -1 || true)
fi
[ -n "$PKG" ] || die "找不到部署包。先执行 ./deployment/kylin/build-package.sh"
[ -f "$PKG" ] || die "包不存在: $PKG"
PKG_ABS=$(cd "$(dirname "$PKG")" && pwd)/$(basename "$PKG")
PKG_NAME=$(basename "$PKG_ABS" .tar.gz)
PKG_SIZE=$(du -h "$PKG_ABS" | cut -f1)
info "部署包 : ${PKG_NAME} (${PKG_SIZE})"

# 包内脚本从解压目录取（本地已解压过就直接用，否则解到 build/.stage）
PKG_DIR="${REPO}/build/${PKG_NAME}"
if [ ! -d "$PKG_DIR" ]; then
    say "本地解压包（为了取脚本与版本号）"
    mkdir -p "$PKG_DIR"
    tar xzf "$PKG_ABS" -C "$(dirname "$PKG_DIR")"
    [ -d "$PKG_DIR" ] || die "解压后目录不符合预期: $PKG_DIR"
fi

PKG_VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${PKG_DIR}/manifest.json" 2>/dev/null | head -1)
info "版本   : ${PKG_VER:-未知}"

SSH_OPTS=(-p "$TPORT" -o BatchMode=no -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
SSH="ssh ${SSH_OPTS[*]} ${TUSER}@${THOST}"

if [ "$DRY_RUN" = "1" ]; then
    say "dry-run：以下命令不会真正执行"
    echo "    ${SSH} \"mkdir -p ${TDIR}\""
    echo "    rsync -avz --partial -e 'ssh ${SSH_OPTS[*]}' \\"
    echo "        '${PKG_ABS}' '${TUSER}@${THOST}:${TDIR}/${PKG_NAME}.tar.gz'"
    echo "    ${SSH} \"cd ${TDIR}/${PKG_NAME} && ./${ACTION}.sh ${ARGS[*]:-}\""
    exit 0
fi

# ------------------------------------------------------------ 传输 ----
say "传输到 ${TUSER}@${THOST}:${TDIR}"

# shellcheck disable=SC2086
${SSH} "mkdir -p '${TDIR}'" || die "无法连接目标机（检查 ssh 可达性、用户、端口、密钥）"

# rsync 优先：增量传输，重复更新同一个包时只传变化块。
# 目标机没有 rsync 是常见情况（麒麟最小化安装），所以必须有回退路径。
if command -v rsync >/dev/null 2>&1; then
    if ${SSH} 'command -v rsync >/dev/null 2>&1'; then
        info "使用 rsync（增量）"
        rsync -az --partial --inplace --info=progress2 \
              -e "ssh ${SSH_OPTS[*]}" \
              "$PKG_ABS" "${TUSER}@${THOST}:${TDIR}/${PKG_NAME}.tar.gz" \
            || die "rsync 传输失败"
    else
        info "目标机无 rsync，回退到 ssh + tar 管道"
        # shellcheck disable=SC2086
        tar czf - -C "$(dirname "$PKG_ABS")" "$(basename "$PKG_ABS")" \
            | ${SSH} "cat > '${TDIR}/${PKG_NAME}.tar.gz'" \
            || die "tar 管道传输失败"
    fi
else
    info "本机无 rsync，使用 ssh + tar 管道"
    # shellcheck disable=SC2086
    tar czf - -C "$(dirname "$PKG_ABS")" "$(basename "$PKG_ABS")" \
        | ${SSH} "cat > '${TDIR}/${PKG_NAME}.tar.gz'" \
        || die "tar 管道传输失败"
fi

# 传输完整性：比对大小。400MB 的包传一半断掉，解压时才报错，
# 而那时已经覆盖了一部分文件 —— 提前比对能拦住。
LOCAL_SIZE=$(stat -c %s "$PKG_ABS")
# shellcheck disable=SC2086
REMOTE_SIZE=$(${SSH} "stat -c %s '${TDIR}/${PKG_NAME}.tar.gz'" 2>/dev/null || echo 0)
if [ "$LOCAL_SIZE" != "$REMOTE_SIZE" ]; then
    die "传输不完整：本地 ${LOCAL_SIZE} 字节，远端 ${REMOTE_SIZE} 字节。
      重新执行本命令（rsync 会续传）。"
fi
info "传输完成并校验大小一致（${LOCAL_SIZE} 字节）"

# ------------------------------------------------------------ 远程执行 ----
say "远端解包并执行 ${ACTION}.sh"
cat <<EOF
    将在目标机执行：
      cd ${TDIR}/${PKG_NAME} && ./${ACTION}.sh ${ARGS[*]:-}
EOF

# 解包到独立目录（不覆盖已有解压结果，避免"旧脚本配新包"）
REMOTE_CMD="set -e
  cd '${TDIR}'
  rm -rf '${PKG_NAME}'
  tar xzf '${PKG_NAME}.tar.gz'
  cd '${PKG_NAME}'
  chmod +x *.sh bin/*.sh 2>/dev/null || true
  ./${ACTION}.sh ${ARGS[*]:-}"

# shellcheck disable=SC2086
${SSH} "bash -c $(printf '%q' "$REMOTE_CMD")"
RC=$?

if [ "$RC" -eq 0 ]; then
    say "完成"
    cat <<EOF
  目标机 : ${TUSER}@${THOST}
  版本   : ${PKG_VER}
  目录   : ${TDIR}/${PKG_NAME}

  后续：
    看状态  ${0} ${NAME} status
    回滚    ${0} ${NAME} rollback --list
    验证    ${0} ${NAME} verify --expect installed
EOF
else
    warn "远端执行返回 ${RC}"
    cat <<EOF
  排查：
    ssh ${TUSER}@${THOST} 'tail -50 ${TDIR}/${PKG_NAME}/../*.log 2>/dev/null'
    ssh ${TUSER}@${THOST} 'journalctl -u maxkey-portal -n 100 --no-pager'

  回滚（若已切换过版本）：
    ${0} ${NAME} rollback --list
EOF
    exit "$RC"
fi
