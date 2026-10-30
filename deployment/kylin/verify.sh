#!/bin/bash
############################################################################
#  verify.sh —— 双向验证：既验"装完整"，也验"卸干净"
#
#  为什么需要这个脚本：install.sh 打印一堆"已安装 xxx"，但那是**它自己说**
#  自己成功。真正能证明状态的，是事后以第三方视角逐项检查磁盘与系统。
#  卸载同理 —— "已删除"与"真的没了"是两件事。
#
#  用法：
#      ./verify.sh --expect installed      # 装完之后跑，任一缺失即 exit 1
#      ./verify.sh --expect removed        # 卸完之后跑，任一残留即 exit 1
#      ./verify.sh                         # 只报告，不判定（人看）
#
#  检查项（装完应有 / 卸后应无）：
#      systemd 单元 ×2、运行用户、current 软链、release 目录与 jar、
#      conf/maxkey.env、/etc/maxkey/maxkey-secret.env 与 600 权限、
#      日志目录与软链、nginx 两个文件、logrotate、端口监听、
#      数据库表数量与 Flyway 历史表
############################################################################

set -u
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "${HERE}/lib/common.sh"

EXPECT=""
QUIET=0
PREFIX_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --expect) shift; EXPECT=${1:?--expect 需要 installed 或 removed} ;;
        --quiet)  QUIET=1 ;;
        --prefix) shift; PREFIX_ARG=${1:?--prefix 需要路径} ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "未知参数: $1"; exit 2 ;;
    esac
    shift
done

case "$EXPECT" in
    ""|installed|removed) ;;
    *) echo "--expect 只接受 installed 或 removed"; exit 2 ;;
esac

set_paths
if [ -n "$PREFIX_ARG" ]; then PREFIX=$PREFIX_ARG; set_paths; fi

MISSING=0    # 装完却缺的
LEFTOVER=0   # 卸完却残留的

# 判定 helper：$1=期望的状态 installed/removed；$2=描述；$3=条件命令已由调用方算好
# 这里用两个计数器表达"与期望不符"，最后按 EXPECT 决定退出码。
expect_present() {
    local desc=$1; shift
    if "$@" >/dev/null 2>&1; then
        ok "$desc"
    else
        if [ "$EXPECT" = "removed" ]; then
            ok "$desc（已不存在，符合预期）"
        else
            bad "$desc 缺失"
            MISSING=$((MISSING + 1))
        fi
    fi
}

expect_absent() {
    local desc=$1; shift
    if "$@" >/dev/null 2>&1; then
        if [ "$EXPECT" = "installed" ]; then
            # 装完状态下存在是正常的（例如旧备份），不算失败
            ok "$desc 存在"
        else
            bad "$desc 仍然存在（应为空）"
            LEFTOVER=$((LEFTOVER + 1))
        fi
    else
        if [ "$EXPECT" = "installed" ]; then
            ok "$desc 不存在"
        else
            ok "$desc 已清理"
        fi
    fi
}

_have_file()  { [ -f "$1" ]; }
_have_link()  { [ -L "$1" ]; }
_have_dir()   { [ -d "$1" ]; }
_have_user()  { id "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- 系统层 ----
if [ "$QUIET" = "0" ]; then printf '\n\033[1;36m== 1. systemd 与用户 ==\033[0m\n'; fi

for u in $UNITS; do
    if [ -f "${SYSTEMD_DIR}/${u}.service" ]; then
        if [ "$EXPECT" = "removed" ]; then
            bad "systemd 单元 ${u}.service 仍存在"
            LEFTOVER=$((LEFTOVER + 1))
        else
            ok "systemd 单元 ${u}.service"
            # 单元里引用的路径必须与当前布局一致（漏改会导致切版本后起不来）
            if grep -q "ExecStart=${PREFIX}/current/bin/maxkeyctl.sh" "${SYSTEMD_DIR}/${u}.service"; then
                ok "  ${u} 的 ExecStart 指向 current 软链"
            else
                bad "  ${u} 的 ExecStart 未指向 ${PREFIX}/current/bin/maxkeyctl.sh"
                MISSING=$((MISSING + 1))
            fi
        fi
    else
        if [ "$EXPECT" = "installed" ]; then
            bad "systemd 单元 ${u}.service 缺失"
            MISSING=$((MISSING + 1))
        else
            ok "systemd 单元 ${u}.service 已移除"
        fi
    fi
done

if id "$RUN_USER" >/dev/null 2>&1; then
    if [ "$EXPECT" = "removed" ]; then
        bad "运行用户 ${RUN_USER} 仍存在"
        LEFTOVER=$((LEFTOVER + 1))
    else
        ok "运行用户 ${RUN_USER}"
    fi
else
    if [ "$EXPECT" = "installed" ]; then
        bad "运行用户 ${RUN_USER} 缺失"
        MISSING=$((MISSING + 1))
    else
        ok "运行用户 ${RUN_USER} 已删除"
    fi
fi

# ---------------------------------------------------------------- 目录层 ----
if [ "$QUIET" = "0" ]; then printf '\n\033[1;36m== 2. 版本目录与软链 ==\033[0m\n'; fi

if [ -L "$CURRENT_LINK" ]; then
    TARGET=$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)
    if [ "$EXPECT" = "removed" ]; then
        bad "current 软链仍存在 -> ${TARGET}"
        LEFTOVER=$((LEFTOVER + 1))
    else
        ok "current -> $(basename "$TARGET")"
        case "$TARGET" in
            "${REL_DIR}/"*) ok "  软链指向 releases/ 内的版本目录" ;;
            *) bad "  current 指向 ${TARGET}，不在 ${REL_DIR} 内"; MISSING=$((MISSING + 1)) ;;
        esac
        if [ -f "${CURRENT_LINK}/bin/maxkeyctl.sh" ]; then
            ok "  current/bin/maxkeyctl.sh 可访问"
        else
            bad "  current/bin/maxkeyctl.sh 缺失（切版本后会起不来）"
            MISSING=$((MISSING + 1))
        fi
        for d in maxkey maxkey_mgt web; do
            if [ -d "${CURRENT_LINK}/${d}" ]; then
                ok "  current/${d}/ 存在"
            else
                bad "  current/${d}/ 缺失"
                MISSING=$((MISSING + 1))
            fi
        done
        # 版本目录内的 conf/logs 必须是软链，否则日志会留在版本目录里跟着回滚消失
        for l in "${CURRENT_LINK}/maxkey/logs" "${CURRENT_LINK}/maxkey_mgt/logs" "${CURRENT_LINK}/conf"; do
            if [ -L "$l" ]; then
                ok "  $(basename "$(dirname "$l")")/$(basename "$l") 是软链 -> $(readlink "$l")"
            else
                bad "  ${l} 不是软链（会导致日志/配置不共享）"
                MISSING=$((MISSING + 1))
            fi
        done
    fi
else
    if [ "$EXPECT" = "installed" ]; then
        bad "current 软链缺失"
        MISSING=$((MISSING + 1))
    else
        ok "current 软链已移除"
    fi
fi

if [ "$EXPECT" = "removed" ]; then
    for d in releases jre bin sql nginx systemd web maxkey maxkey_mgt run; do
        if [ -e "${PREFIX}/${d}" ] || [ -L "${PREFIX}/${d}" ]; then
            case "$d" in
                # conf/logs/backups 是 --purge 刻意保留的，不算残留
                *) bad "${PREFIX}/${d} 仍然存在（--purge 应已删除）"; LEFTOVER=$((LEFTOVER + 1)) ;;
            esac
        fi
    done
    ok "程序目录检查完成（conf/logs/backups 属刻意保留项）"
fi

# ---------------------------------------------------------------- 配置层 ----
if [ "$QUIET" = "0" ]; then printf '\n\033[1;36m== 3. 配置与密钥 ==\033[0m\n'; fi

if [ -f "${CONF_DIR}/maxkey.env" ]; then
    ok "conf/maxkey.env 存在"
    # 现场配置必须是"渲染过"的，不能还是模板占位值。
    #
    # 判据只能看**赋值行**（KEY=VALUE），不能全文 grep：
    # 模板里有一批注释用 example.gov.cn 当取值示例，例如
    #     #   nginx 上 443 + https   →  https://sso.example.gov.cn
    # 全文 grep 会把它们当成"残留占位值"，于是每次安装完都报 FAIL ——
    # 而实际配置完全正确。假告警比漏报更坏：它训练人忽略告警。
    PLACEHOLDER=$(grep -vE '^[[:space:]]*#' "${CONF_DIR}/maxkey.env" \
                  | grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' \
                  | grep -c 'example\.gov\.cn' || true)
    if [ "${PLACEHOLDER:-0}" -gt 0 ]; then
        bad "  conf/maxkey.env 有 ${PLACEHOLDER} 个赋值项仍含占位域名 example.gov.cn："
        grep -vE '^[[:space:]]*#' "${CONF_DIR}/maxkey.env" \
            | grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' \
            | grep 'example\.gov\.cn' | sed 's/^/        /'
        MISSING=$((MISSING + 1))
    else
        ok "  无占位域名残留（仅检查赋值行）"
    fi
else
    if [ "$EXPECT" = "installed" ]; then
        bad "conf/maxkey.env 缺失"
        MISSING=$((MISSING + 1))
    else
        # --purge 保留 conf，所以卸载后它通常还在
        ok "conf/maxkey.env 不存在"
    fi
fi

if [ -f "$SECRET_FILE" ]; then
    if [ "$EXPECT" = "removed" ]; then
        bad "${SECRET_FILE} 仍存在（含明文密钥，--purge 应删除）"
        LEFTOVER=$((LEFTOVER + 1))
    else
        ok "/etc/maxkey/maxkey-secret.env 存在"
        perm=$(stat -c '%a %U' "$SECRET_FILE" 2>/dev/null || echo "? ?")
        case "$perm" in
            "600 root") ok "  权限 ${perm}（正确）" ;;
            *) bad "  权限应为 600 root，实际 ${perm}"; MISSING=$((MISSING + 1)) ;;
        esac
        for k in DATABASE_PWD JWT_SECRET; do
            if grep -qE "^[[:space:]]*${k}=" "$SECRET_FILE" 2>/dev/null; then
                ok "  含 ${k}"
            else
                bad "  缺少 ${k}（服务会拒绝启动）"
                MISSING=$((MISSING + 1))
            fi
        done
    fi
else
    if [ "$EXPECT" = "installed" ]; then
        bad "${SECRET_FILE} 缺失"
        MISSING=$((MISSING + 1))
    else
        ok "${SECRET_FILE} 已删除"
    fi
fi

# ---------------------------------------------------------------- 日志层 ----
if [ "$QUIET" = "0" ]; then printf '\n\033[1;36m== 4. 日志与轮转 ==\033[0m\n'; fi

for d in portal mgt; do
    if [ -d "${LOG_DIR}/${d}" ]; then
        if [ "$EXPECT" = "removed" ]; then
            ok "logs/${d}/ 保留（排障证据，刻意不清）"
        else
            ok "logs/${d}/ 存在"
        fi
    else
        if [ "$EXPECT" = "installed" ]; then
            bad "logs/${d}/ 缺失"
            MISSING=$((MISSING + 1))
        else
            ok "logs/${d}/ 不存在"
        fi
    fi
done

if [ -f "$LOGROTATE_FILE" ]; then
    if [ "$EXPECT" = "removed" ]; then
        bad "${LOGROTATE_FILE} 仍存在"
        LEFTOVER=$((LEFTOVER + 1))
    else
        ok "logrotate 配置存在"
    fi
else
    if [ "$EXPECT" = "installed" ]; then
        skip "logrotate 配置缺失（可选项；未装 logrotate 时属正常）"
    else
        ok "logrotate 配置已删除"
    fi
fi

# ---------------------------------------------------------------- 接入层 ----
if [ "$QUIET" = "0" ]; then printf '\n\033[1;36m== 5. nginx ==\033[0m\n'; fi

for f in "$NGINX_SITE" "$NGINX_PROXY"; do
    if [ -f "$f" ]; then
        if [ "$EXPECT" = "removed" ]; then
            bad "$f 仍存在"
            LEFTOVER=$((LEFTOVER + 1))
        else
            ok "$f 存在"
        fi
    else
        if [ "$EXPECT" = "installed" ]; then
            skip "$f 缺失（用 --no-nginx 安装时属正常）"
        else
            ok "$f 已删除"
        fi
    fi
done

# ---------------------------------------------------------------- 运行层 ----
if [ "$QUIET" = "0" ]; then printf '\n\033[1;36m== 6. 端口与服务状态 ==\033[0m\n'; fi

if [ -f "${CONF_DIR}/maxkey.env" ]; then
    # shellcheck disable=SC1091
    ( set -a; . "${CONF_DIR}/maxkey.env" ) 2>/dev/null || true
fi
PORTAL_PORT=${PORTAL_PORT:-9527}
MGT_PORT=${MGT_PORT:-9526}
NGINX_TLS_PORT=${NGINX_TLS_PORT:-443}

for p in "$PORTAL_PORT" "$MGT_PORT"; do
    if port_open "$p"; then
        if [ "$EXPECT" = "removed" ]; then
            bad "端口 ${p} 仍在监听（服务未停）"
            LEFTOVER=$((LEFTOVER + 1))
        else
            ok "端口 ${p} 监听中"
        fi
    else
        if [ "$EXPECT" = "installed" ]; then
            bad "端口 ${p} 未监听（服务没起来）"
            MISSING=$((MISSING + 1))
        else
            ok "端口 ${p} 已释放"
        fi
    fi
done

# ---------------------------------------------------------------- 数据库 ----
if [ "$QUIET" = "0" ]; then printf '\n\033[1;36m== 7. 数据库 ==\033[0m\n'; fi

if [ -f "${CONF_DIR}/maxkey.env" ]; then
    # shellcheck source=lib/db.sh
    . "${HERE}/lib/db.sh"
    load_env_file "${CONF_DIR}/maxkey.env" 2>/dev/null || true
    if secret_has DATABASE_PWD 2>/dev/null; then
        DATABASE_PWD=$(secret_read DATABASE_PWD 2>/dev/null || true)
        export DATABASE_PWD
    fi
    if [ -n "${DATABASE_PWD:-}" ] && db_connect_ok; then
        N=$(db_table_count)
        if [ "$EXPECT" = "removed" ]; then
            if [ "${N:-0}" -eq 0 ]; then
                ok "数据库 schema 已清空（0 张表）"
            else
                bad "数据库仍有 ${N} 张表（--purge-all 应已 DROP）"
                LEFTOVER=$((LEFTOVER + 1))
            fi
        else
            [ "${N:-0}" -ge 40 ] && ok "数据库 ${N} 张表" \
                || { bad "数据库只有 ${N} 张表（应 ≥40）"; MISSING=$((MISSING + 1)); }
            if db_flyway_has_history; then
                ok "Flyway 历史表存在，当前版本 $(db_flyway_version)"
            else
                skip "Flyway 历史表不存在（未启用迁移时属正常）"
            fi
        fi
    else
        skip "数据库不可达或缺少口令，跳过数据库检查"
    fi
else
    skip "无 conf/maxkey.env，跳过数据库检查"
fi

# ---------------------------------------------------------------- 汇总 ----
echo
TOTAL_FAIL=$((MISSING + LEFTOVER))
case "$EXPECT" in
    installed)
        if [ "$MISSING" -eq 0 ]; then
            printf '\033[1;32m== 验证通过：安装完整 ==\033[0m\n'
            exit 0
        fi
        printf '\033[1;31m== 验证失败：%d 项缺失 ==\033[0m\n' "$MISSING"
        exit 1
        ;;
    removed)
        if [ "$LEFTOVER" -eq 0 ]; then
            printf '\033[1;32m== 验证通过：已清理干净 ==\033[0m\n'
            exit 0
        fi
        printf '\033[1;31m== 验证失败：%d 项残留 ==\033[0m\n' "$LEFTOVER"
        exit 1
        ;;
    *)
        printf '\033[1m== 报告：%d 项缺失 / %d 项残留 ==\033[0m\n' "$MISSING" "$LEFTOVER"
        [ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
        ;;
esac
