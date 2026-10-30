#!/bin/bash
############################################################################
#  migrate.sh —— 单独执行数据库迁移（不切版本、不重启）
#
#  什么时候用：
#    * upgrade.sh 因为别的原因没跑成，但迁移已经准备好，想先单独迁移
#    * 想在切换代码之前先看 Flyway 的 info（有哪些待应用）
#    * DBA 希望先审 SQL、再决定何时应用
#
#  与 upgrade.sh 的关系：upgrade.sh 内部就是调这个脚本的同一套函数。
#  两条路径共用 lib/db.sh，行为一致。
#
#  用法（需 root）：
#      ./bin/migrate.sh --info          # 只列出已应用/待应用，不改库
#      ./bin/migrate.sh                 # 应用全部待执行迁移
#      ./bin/migrate.sh --baseline      # 把当前结构标记为 V1（种子库建的库）
#      ./bin/migrate.sh --target 2      # 只迁到 V2
############################################################################

set -eu
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${HERE}/.." && pwd)
# shellcheck source=../lib/common.sh
. "${ROOT}/lib/common.sh"

set_paths

MODE="migrate"
TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
        --info)     MODE="info" ;;
        --baseline) MODE="baseline" ;;
        --target)   shift; TARGET=${1:?--target 需要版本号} ;;
        -h|--help)  sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "未知参数: $1"; exit 0 ;;
    esac
    shift
done

need_root

[ -f "${CONF_DIR}/maxkey.env" ] || die "缺少 ${CONF_DIR}/maxkey.env"
load_env_file "${CONF_DIR}/maxkey.env"

if secret_has DATABASE_PWD; then
    DATABASE_PWD=$(secret_read DATABASE_PWD)
    export DATABASE_PWD
fi
: "${DATABASE_PWD:?缺少 DATABASE_PWD，无法连库}"

# shellcheck source=../lib/db.sh
. "${ROOT}/lib/db.sh"
# 迁移用"当前版本目录"里的工具与 SQL（与正在运行的代码一致）
MAXKEY_SQL_DIR="${CURRENT_LINK}/sql"
[ -d "${MAXKEY_SQL_DIR}/lib" ] || die "找不到迁移工具目录 ${MAXKEY_SQL_DIR}/lib（先执行 install.sh）"

MIG_DIR=$(db_migration_dir)
say "迁移目录: ${MIG_DIR}"
if [ -d "$MIG_DIR" ]; then
    ls -1 "${MIG_DIR}"/V*.sql 2>/dev/null | sed 's/^/    /' || echo "    （无迁移文件）"
fi

db_connect_ok || die "数据库连不上（${DATABASE_URL}）"
info "当前数据库版本: $(db_flyway_version 2>/dev/null || echo '（无历史表）')"

case "$MODE" in
    info)
        say "Flyway info"
        db_flyway_run --info || true
        ;;
    baseline)
        say "baseline 到 V1"
        warn "把当前库结构标记为已到 V1，不会执行任何 SQL"
        warn "只应在「用种子库建出来的库」上执行一次"
        db_flyway_run --baseline
        info "完成，当前版本: $(db_flyway_version)"
        ;;
    migrate)
        # 迁移前必须备份：这一步是唯一会改表结构的动作
        if [ -d "$BK_DIR" ]; then
            TS=$(date +%Y%m%d-%H%M%S)
            mkdir -p "${BK_DIR}/${TS}-migrate"
            say "迁移前备份到 ${BK_DIR}/${TS}-migrate"
            if db_backup "${BK_DIR}/${TS}-migrate/db.dump" > "${BK_DIR}/${TS}-migrate/backup.log" 2>&1; then
                info "已备份 $(du -h "${BK_DIR}/${TS}-migrate/db.dump" 2>/dev/null | cut -f1)"
            else
                die "备份失败，已中止（未执行迁移）"
            fi
        fi

        say "执行迁移"
        if [ -n "$TARGET" ]; then
            db_flyway_run --target "$TARGET"
        else
            db_flyway_run
        fi
        info "完成，当前版本: $(db_flyway_version)"
        warn "如果应用正在运行，请重启以加载与库结构匹配的代码："
        warn "  systemctl restart maxkey-portal maxkey-mgt"
        ;;
esac
