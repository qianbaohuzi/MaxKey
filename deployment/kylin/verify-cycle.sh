#!/bin/bash
############################################################################
#  verify-cycle.sh —— 开发侧一键回归（不入部署包）
#
#  为什么要这个脚本：
#  「装→卸→装」和「升级→回滚」如果每次靠人拼命令，很容易漏一步、
#  或者跳过 verify 直接看 install 的输出 —— 而 install 说"已安装"只是
#  它自己说自己成功。这个脚本强制每一步都以 verify.sh 的判定为准，
#  任何一步非 0 就停在那一步，并保留现场供排查。
#
#  ⚠️ 会真的停服务、真的删目录、真的 DROP 库。
#     库的 DROP 只发生在 cycle 模式下，且会先 dump 并校验 dump 可读。
#
#  用法（需 root）：
#      ./verify-cycle.sh install          # 装 → verify installed
#      ./verify-cycle.sh uninstall        # 卸载 --purge → verify removed
#      ./verify-cycle.sh cycle            # 装 → 卸(--purge-all) → 装（完整闭环）
#      ./verify-cycle.sh upgrade <包1> <包2>  # 装包1 → 升级到包2 → 回滚到包1
#      ./verify-cycle.sh --dry-run install
#
#  环境档案默认 dev-local，可用 PROFILE=xxx 覆盖。
############################################################################

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "${HERE}/../.." && pwd)
# shellcheck source=lib/common.sh
. "${HERE}/lib/common.sh"

PROFILE="${PROFILE:-dev-local}"
PKG_TGZ="${PKG_TGZ:-}"
DRY_RUN="${DRY_RUN:-0}"
STEPS_LOG="${TMPDIR:-/tmp}/maxkey-cycle-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$(dirname "$STEPS_LOG")"

say()  { printf '\n\033[1;35m==== %s ====\033[0m\n' "$*"; }
step() { printf '\n\033[1;36m--> %s\033[0m\n' "$*"; }
fail() {
    printf '\n\033[1;31m!!!! 失败: %s\033[0m\n' "$*"
    printf '    完整日志: %s\n' "$STEPS_LOG"
    exit 1
}

# 每一条命令都 tee 进日志，失败时能完整复盘
runc() {
    printf '\n\033[1m$ %s\033[0m\n' "$*" | tee -a "$STEPS_LOG"
    if [ "$DRY_RUN" = "1" ]; then
        printf '  [dry-run] 跳过执行\n' | tee -a "$STEPS_LOG"
        return 0
    fi
    # shellcheck disable=SC2068
    "$@" 2>&1 | tee -a "$STEPS_LOG"
    local rc=${PIPESTATUS[0]}
    printf '  (exit %d)\n' "$rc" | tee -a "$STEPS_LOG"
    return $rc
}

# 取最新打出来的包
latest_pkg() {
    ls -1t "${REPO}/build"/maxkey-deploy-*.tar.gz 2>/dev/null | head -1
}

# 解包到固定暂存目录（避免每次重新解 400MB）
stage_pkg() {
    local tgz=$1
    local dir
    dir=$(mktemp -d "${REPO}/build/.stage.XXXXXX")
    tar xzf "$tgz" -C "$dir" || fail "解压失败: $tgz"
    find "$dir" -maxdepth 1 -mindepth 1 -type d | head -1
}

find_pkg_root() {
    if [ -n "$PKG_TGZ" ] && [ -f "$PKG_TGZ" ]; then
        printf '%s' "$PKG_TGZ"
        return
    fi
    local t
    t=$(latest_pkg)
    [ -n "$t" ] || fail "找不到部署包，请先跑 build-package.sh 或用 PKG_TGZ= 指定"
    printf '%s' "$t"
}

do_install() {
    local pkg_root=$1
    step "安装（profile=${PROFILE}）"
    runc "${pkg_root}/install.sh" --profile "$PROFILE" || fail "install.sh 失败"
    step "验证：安装完整"
    runc "${pkg_root}/verify.sh" --expect installed || fail "verify --expect installed 失败"
}

do_upgrade() {
    local pkg_tgz=$1 cur_pkg_root=$2
    step "升级到 $(basename "$pkg_tgz")"
    runc "${cur_pkg_root}/upgrade.sh" "$pkg_tgz" --yes || fail "upgrade.sh 失败"
    step "验证：升级后仍完整"
    runc "${cur_pkg_root}/verify.sh" --expect installed || fail "升级后 verify 失败"
}

do_rollback() {
    local pkg_root=$1 to=$2
    step "回滚到 ${to}"
    runc "${pkg_root}/rollback.sh" --to "$to" || fail "rollback.sh 失败"
    step "验证：回滚后仍完整"
    runc "${pkg_root}/verify.sh" --expect installed || fail "回滚后 verify 失败"
}

do_uninstall() {
    local pkg_root=$1 level=$2
    step "卸载（${level}）"
    if [ "$level" = "purge-all" ]; then
        runc "${pkg_root}/uninstall.sh" --purge-all --yes || fail "uninstall --purge-all 失败"
    else
        runc "${pkg_root}/uninstall.sh" --purge || fail "uninstall --purge 失败"
    fi
    step "验证：零残留"
    runc "${pkg_root}/verify.sh" --expect removed || fail "verify --expect removed 失败（有残留）"
}

# ---------------------------------------------------------------- 主流程 ----
ACTION=${1:-}
[ -n "$ACTION" ] || { sed -n '2,30p' "$0"; exit 2; }
shift || true

case "$ACTION" in
    install)
        TGZ=$(find_pkg_root)
        say "回归：安装"
        ROOT=$(stage_pkg "$TGZ")
        do_install "$ROOT"
        say "PASS：安装 + verify installed"
        ;;

    uninstall)
        TGZ=$(find_pkg_root)
        say "回归：卸载"
        ROOT=$(stage_pkg "$TGZ")
        do_uninstall "$ROOT" purge
        say "PASS：卸载 --purge + verify removed"
        ;;

    cycle)
        TGZ=$(find_pkg_root)
        say "回归：装 → 卸（含删库）→ 再装"
        ROOT=$(stage_pkg "$TGZ")

        do_install "$ROOT"
        do_uninstall "$ROOT" purge-all
        do_install "$ROOT"

        say "PASS：完整闭环（装→卸→装）"
        ;;

    upgrade)
        PKG1=${1:-}
        PKG2=${2:-}
        [ -n "$PKG1" ] || fail "用法: verify-cycle.sh upgrade <旧包> <新包>"
        [ -f "$PKG1" ] || fail "旧包不存在: $PKG1"
        [ -f "$PKG2" ] || fail "新包不存在: $PKG2"

        say "回归：装旧包 → 升级新包 → 回滚"
        ROOT1=$(stage_pkg "$PKG1")
        do_install "$ROOT1"
        V1=$(resolve_pkg_version "$ROOT1")
        info "已装版本 $V1"

        do_upgrade "$PKG2" "$ROOT1"
        do_rollback "$ROOT1" "$V1"

        say "PASS：升级 + 回滚"
        ;;

    *)
        sed -n '2,30p' "$0"
        exit 2
        ;;
esac

printf '\n\033[1;32m全部步骤通过。日志：%s\033[0m\n' "$STEPS_LOG"
