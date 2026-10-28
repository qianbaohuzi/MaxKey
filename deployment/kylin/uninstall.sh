#!/bin/bash
############################################################################
#  uninstall.sh —— 撤销 install.sh 做的改动（默认保留数据）
#
#  默认行为（安全侧）：
#    * 停止并禁用 systemd 单元，删除单元文件
#    * 删除 nginx 站点文件与代理片段，reload nginx
#    * **保留** /opt/maxkey（含 conf/ 与 logs/）与 /etc/maxkey（口令）
#    * **保留** 数据库与 maxkey 用户
#
#  要连文件一起删，加 --purge。数据与数据库永远不自动删。
#
#  用法（需 root）：
#      ./uninstall.sh --dry-run
#      ./uninstall.sh
#      ./uninstall.sh --purge
############################################################################

set -eu

PREFIX=/opt/maxkey
RUN_USER=maxkey
PURGE=0
DRY_RUN=0
KEEP_NGINX=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)    DRY_RUN=1 ;;
        --purge)      PURGE=1 ;;
        --keep-nginx) KEEP_NGINX=1 ;;
        --prefix)     shift; PREFIX=${1:?--prefix 需要路径} ;;
        -h|--help)    sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "未知参数: $1"; exit 2 ;;
    esac
    shift
done

NGINX_SITE=/etc/nginx/conf.d/maxkey.conf
NGINX_PROXY=/etc/nginx/maxkey-proxy.conf

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

[ "$(id -u)" -eq 0 ] || die "需要 root 权限运行"

# --------------------------------------------------------------- 服务 ----
say "停止服务"
for u in maxkey-portal maxkey-mgt; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${u}.service"; then
        run systemctl stop "${u}.service" 2>/dev/null || true
        run systemctl disable "${u}.service" 2>/dev/null || true
    fi
done

# 兜底：脚本直启的进程（systemd 之外）
for p in "${PREFIX}/run/"*.pid; do
    [ -e "$p" ] || continue
    pid=$(cat "$p" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        run kill "$pid" 2>/dev/null || true
    fi
done
info "服务已停止"

# ------------------------------------------------------------- systemd ----
say "移除 systemd 单元"
for u in maxkey-portal maxkey-mgt; do
    run rm -f "/etc/systemd/system/${u}.service"
done
run systemctl daemon-reload 2>/dev/null || true
info "已移除"

# --------------------------------------------------------------- nginx ----
if [ "$KEEP_NGINX" = "0" ]; then
    say "移除 nginx 接入"
    # 只删 MaxKey 自己的两个文件，绝不触碰现场其他站点
    if [ -f "$NGINX_SITE" ]; then
        run rm -f "$NGINX_SITE"
        info "已删除 $NGINX_SITE"
    else
        info "无 $NGINX_SITE，跳过"
    fi
    if [ -f "$NGINX_PROXY" ]; then
        run rm -f "$NGINX_PROXY"
        info "已删除 $NGINX_PROXY"
    fi

    if command -v nginx >/dev/null 2>&1 && [ "$DRY_RUN" = "0" ]; then
        if nginx -t 2>/dev/null; then
            nginx -s reload 2>/dev/null && info "nginx 已 reload" || warn "reload 失败，请手工 nginx -s reload"
        else
            warn "nginx -t 未通过（可能是其他站点的问题），请检查后手工 reload"
        fi
    fi
else
    say "保留 nginx 配置（--keep-nginx）"
fi

# ---------------------------------------------------------------- 文件 ----
if [ "$PURGE" = "1" ]; then
    say "删除程序文件（--purge）"
    # 双重确认：必须是预期的那两个绝对路径，且不是根目录
    [ -n "$PREFIX" ] || die "PREFIX 为空，拒绝删除"
    case "$PREFIX" in
        /|/opt|/usr|/etc|/var|"") die "PREFIX=${PREFIX} 不安全，拒绝删除" ;;
    esac
    [ -d "$PREFIX" ] || die "${PREFIX} 不存在"
    info "将删除: $PREFIX"
    run rm -rf "$PREFIX"
    info "已删除程序目录"

    warn "保留 ${SECRET_DIR:-/etc/maxkey}/maxkey-secret.env（含口令）"
    warn "如需彻底清理请手工: rm -rf /etc/maxkey"

    if id "$RUN_USER" >/dev/null 2>&1; then
        run userdel "$RUN_USER" 2>/dev/null || warn "userdel 失败（可能有进程仍在用该用户）"
        info "已删除用户 ${RUN_USER}"
    fi
else
    say "保留程序与配置"
    info "${PREFIX} 未删除（含 conf/ 与 logs/）"
    info "/etc/maxkey/maxkey-secret.env 未删除"
    info "/opt/maxkey 下的内容如需清理请手工删除，或改用 --purge"
fi

say "完成"
cat <<EOF
  数据库与数据**未**被删除（uninstall 永远不动数据库）。
  如需清理数据库，请自行执行（谨慎）：
      ksql -U <dba> -d maxkey -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
EOF
