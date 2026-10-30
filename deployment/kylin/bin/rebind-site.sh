#!/bin/bash
############################################################################
#  rebind-site.sh —— 换域名后，把"绑死在库里的旧域名"改掉
#
#  为什么需要这个脚本：
#  换域名不只是改 conf/maxkey.env。库里有一批数据是**按旧域名生成的字符串**，
#  而且其中几处是"严格相等比对"，改不干净的症状极难查：
#
#    mxk_apps_cas_details.service      必须与 conf 的 LOGIN_CAS_SERVICE 完全相等
#                                      → 不等则点「后台」一直卡在登录页
#    mxk_apps.loginurl / logouturl     应用回跳地址 → 不等则回跳到旧域名
#    mxk_apps_oauth_client_details
#        .web_server_redirect_uri      OAuth 回调 → 不等则客户端报 redirect_uri_mismatch
#        .issuer                       token 里的 iss → 不等则客户端校验失败
#    mxk_institutions.domain           租户识别（WebInstRequestFilter 按 Host 头匹配）
#                                      → 不等则退回默认机构，登录页标题/Logo 都不对
#
#  设计原则：
#    1. **幂等**：只把"含旧域名"的行改成新域名，跑一次与跑十次结果相同。
#    2. **可预览**：默认就是 dry-run，打印将改动的行数与旧值/新值。
#    3. **不猜**：旧域名必须显式给出（或用 --from-conf 从当前 conf 反推），
#       绝不"把看起来很旧的值都改掉"。
#    4. **可回退**：实执行前自动 dump 一份到 backups/。
#
#  用法（需 root）：
#      ./bin/rebind-site.sh --old sso.old.com --new sso.new.com          # 预览
#      ./bin/rebind-site.sh --old sso.old.com --new sso.new.com --apply  # 实执行
#      ./bin/rebind-site.sh --from-conf --new sso.new.com --apply
#          # 旧域名从 conf 里取……注意：换域名后 conf 已经是新值了，
#          # 所以这条路只在"conf 还没改、只想先改库"时有用。
#      ./bin/rebind-site.sh --old a.com --new b.com --apply --scheme https
#
#  换域名的完整顺序（务必按这个来）：
#      1. 改 env/<环境名>.env 里的域名/证书/端口
#      2. sudo ./install.sh --profile <环境名> --force-reinstall   （把 nginx/conf 换成新值）
#      3. sudo ./bin/rebind-site.sh --old <旧域名> --new <新域名> --apply
#      4. sudo systemctl restart maxkey-portal maxkey-mgt
#      5. 浏览器验证：门户登录 → 点「后台」→ 应免密进入管理端
############################################################################

set -eu
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${HERE}/.." && pwd)
# shellcheck source=../lib/common.sh
. "${ROOT}/lib/common.sh"

OLD_HOST=""
NEW_HOST=""
SCHEME=""
FROM_CONF=0
APPLY=0
OLD_PORT=""
NEW_PORT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --old)       shift; OLD_HOST=${1:?--old 需要旧域名} ;;
        --new)       shift; NEW_HOST=${1:?--new 需要新域名} ;;
        --scheme)    shift; SCHEME=${1:?--scheme 需要 http 或 https} ;;
        --from-conf) FROM_CONF=1 ;;
        --apply)     APPLY=1 ;;
        -h|--help)   sed -n '2,45p' "$0"; exit 0 ;;
        *) echo "未知参数: $1"; exit 0 ;;
    esac
    shift
done

set_paths
export DRY_RUN=0
need_root

# ------------------------------------------------------------ 参数校验 ----
[ -f "${CONF_DIR}/maxkey.env" ] || die "缺少 ${CONF_DIR}/maxkey.env"
load_env_file "${CONF_DIR}/maxkey.env"

if secret_has DATABASE_PWD; then
    DATABASE_PWD=$(secret_read DATABASE_PWD)
    export DATABASE_PWD
fi
: "${DATABASE_PWD:?缺少 DATABASE_PWD，无法连库}"

# shellcheck source=../lib/db.sh
. "${ROOT}/lib/db.sh"

: "${NEW_HOST:?必须指定 --new <新域名>}"

# 旧域名：可以显式给，也可以从种子库的默认值反推（只对"从未改过域名"的库有效）
if [ "$FROM_CONF" = "1" ] && [ -z "$OLD_HOST" ]; then
    OLD_HOST="${NGINX_SERVER_NAME:-}"
    [ -n "$OLD_HOST" ] || die "conf 里没有 NGINX_SERVER_NAME，请显式 --old"
    warn "从 conf 取旧域名: ${OLD_HOST}（若 conf 已是新值，这个参数等于没意义）"
fi
[ -n "$OLD_HOST" ] || die "必须指定 --old <旧域名>（或用 --from-conf）"

# 从 MAXKEY_PUBLIC_URL 推断协议与新端口，保证改出来的串与 conf 一致
if [ -z "$SCHEME" ]; then
    SCHEME=$(printf '%s' "${MAXKEY_PUBLIC_URL:-https}" | sed -E 's#^([a-z]+)://.*#\1#')
fi
NEW_PORT=$(printf '%s' "${MAXKEY_PUBLIC_URL:-}" | sed -nE 's#^[a-z]+://[^:/]+:([0-9]+).*#\1#p')
OLD_PORT=$(printf '%s' "$OLD_HOST" | sed -nE 's#^[^:]+:([0-9]+)$#\1#p')
OLD_HOST=${OLD_HOST%%:*}
NEW_HOST=${NEW_HOST%%:*}

# 与 conf 的一致性检查：库里的 service 必须能对上 conf 的 LOGIN_CAS_SERVICE，
# 否则改完还是卡在「后台」 —— 提前拦下比事后查便宜得多。
EXPECT_SERVICE="${LOGIN_CAS_SERVICE:-}"
if [ -n "$EXPECT_SERVICE" ]; then
    case "$EXPECT_SERVICE" in
        *"${NEW_HOST}"*) info "conf 的 LOGIN_CAS_SERVICE 已指向新域名（一致）" ;;
        *) warn "conf 的 LOGIN_CAS_SERVICE 仍是 ${EXPECT_SERVICE}" 
           warn "  改完库后两边仍不一致，请先按顺序执行 install.sh 更新 conf" ;;
    esac
fi

say "重绑计划"
info "旧域名 : ${OLD_HOST}${OLD_PORT:+:${OLD_PORT}}"
info "新域名 : ${NEW_HOST}${NEW_PORT:+:${NEW_PORT}}"
info "协议   : ${SCHEME}"
info "模式   : $( [ "$APPLY" = "1" ] && echo '实执行' || echo '预览（dry-run，不改数据）' )"

db_connect_ok || die "数据库连不上（${DATABASE_URL}）"

# ------------------------------------------------------------ 改动清单 ----
# 每一项都是 (表, 主键列, 要改的列, 说明)。列出来是为了让人能核对
# 「到底动了什么」，而不是只看到一句"已更新 12 行"。
#
# 注意：只用 REPLACE(列, 旧串, 新串)，不做模糊匹配 ——
# 模糊匹配会误伤 description 之类含旧域名文本的自由字段。
build_sql() {
    local old_full="$1" new_full="$2"
    cat <<SQL
-- 1) 管理端 CAS 应用：service/callbackurl 必须与 conf 的 LOGIN_CAS_SERVICE 严格相等
UPDATE mxk_apps_cas_details
   SET service     = REPLACE(service,     '${old_full}', '${new_full}'),
       callbackurl = REPLACE(callbackurl, '${old_full}', '${new_full}')
 WHERE service LIKE '%${old_full}%' OR callbackurl LIKE '%${old_full}%';

-- 2) 应用回跳地址（登录后跳回业务系统）
UPDATE mxk_apps
   SET loginurl  = REPLACE(loginurl,  '${old_full}', '${new_full}')
 WHERE loginurl  LIKE '%${old_full}%';

UPDATE mxk_apps
   SET logouturl = REPLACE(logouturl, '${old_full}', '${new_full}')
 WHERE logouturl LIKE '%${old_full}%';

-- 3) OAuth2 客户端：回调地址与 issuer（iss 不一致会被客户端判为无效 token）
UPDATE mxk_apps_oauth_client_details
   SET web_server_redirect_uri = REPLACE(web_server_redirect_uri, '${old_full}', '${new_full}')
 WHERE web_server_redirect_uri LIKE '%${old_full}%';

UPDATE mxk_apps_oauth_client_details
   SET issuer = REPLACE(issuer, '${old_full}', '${new_full}')
 WHERE issuer LIKE '%${old_full}%';

-- 4) 租户识别：WebInstRequestFilter 按 Host 头匹配 domain
UPDATE mxk_institutions
   SET domain = '${new_full}'
 WHERE domain = '${old_full}';
SQL
}

# 统计用：每张表里含旧域名的行数
count_sql() {
    local old_full="$1"
    cat <<SQL
select 'mxk_apps_cas_details' as t, count(*) from mxk_apps_cas_details
 where service like '%${old_full}%' or callbackurl like '%${old_full}%'
union all
select 'mxk_apps.loginurl', count(*) from mxk_apps where loginurl like '%${old_full}%'
union all
select 'mxk_apps.logouturl', count(*) from mxk_apps where logouturl like '%${old_full}%'
union all
select 'mxk_oauth.redirect_uri', count(*) from mxk_apps_oauth_client_details where web_server_redirect_uri like '%${old_full}%'
union all
select 'mxk_oauth.issuer', count(*) from mxk_apps_oauth_client_details where issuer like '%${old_full}%'
union all
select 'mxk_institutions.domain', count(*) from mxk_institutions where domain = '${old_full}';
SQL
}

# 旧串：带端口的形式（如果原来有端口）与不带端口的形式都要试，
# 因为库里可能两种写法都有（历史数据）。
OLD_FULLS="${SCHEME}://${OLD_HOST}"
if [ -n "$OLD_PORT" ] && [ "$OLD_PORT" != "443" ] && [ "$OLD_PORT" != "80" ]; then
    OLD_FULLS="${SCHEME}://${OLD_HOST}:${OLD_PORT} ${SCHEME}://${OLD_PORT}"
fi
NEW_FULL="${SCHEME}://${NEW_HOST}"
if [ -n "$NEW_PORT" ] && { [ "$NEW_PORT" != "443" ] && [ "$NEW_PORT" != "80" ]; }; then
    NEW_FULL="${SCHEME}://${NEW_HOST}:${NEW_PORT}"
fi

say "当前含旧域名的数据"
TOTAL=0
for old_full in $OLD_FULLS; do
    echo "    匹配串: ${old_full}"
    OUT=$(db_exec_sql "$(count_sql "$old_full")" 2>&1) || {
        echo "$OUT" | sed 's/^/      /'
        die "查询失败（表结构可能与预期不同，请人工核对）"
    }
    while IFS=$'\t' read -r tbl cnt; do
        [ -n "${tbl:-}" ] || continue
        [ "${cnt:-0}" -gt 0 ] 2>/dev/null || continue
        printf '      %-28s %s 行\n' "$tbl" "$cnt"
        TOTAL=$((TOTAL + cnt))
    done <<< "$OUT"
done

if [ "$TOTAL" -eq 0 ]; then
    info "没有找到含旧域名的数据 —— 库里可能已经是新域名（幂等：无需改动）"
    exit 0
fi

say "将执行以下 UPDATE（按新域名 ${NEW_FULL}）"
for old_full in $OLD_FULLS; do
    echo "    --- ${old_full} -> ${NEW_FULL} ---"
    build_sql "$old_full" "$NEW_FULL" | sed 's/^/      /'
done

if [ "$APPLY" != "1" ]; then
    say "预览结束（未改任何数据）"
    cat <<EOF
  确认无误后执行：
      sudo ./bin/rebind-site.sh --old ${OLD_HOST} --new ${NEW_HOST} --apply

  之后务必：
      sudo systemctl restart maxkey-portal maxkey-mgt
EOF
    exit 0
fi

# ------------------------------------------------------------ 备份后执行 ----
TS=$(date +%Y%m%d-%H%M%S)
BK="${BK_DIR}/${TS}-rebind"
say "备份到 ${BK}"
mkdir -p "$BK"
if db_backup "${BK}/db-before-rebind.dump" > "${BK}/backup.log" 2>&1; then
    info "已备份 $(du -h "${BK}/db-before-rebind.dump" 2>/dev/null | cut -f1)"
else
    tail -20 "${BK}/backup.log" | sed 's/^/      /'
    die "备份失败，已中止（未改任何数据）"
fi
cp -a "${CONF_DIR}/maxkey.env" "${BK}/maxkey.env"
echo "old=${OLD_HOST} new=${NEW_HOST} scheme=${SCHEME} time=$(date -Iseconds)" > "${BK}/meta.txt"

say "执行 UPDATE"
for old_full in $OLD_FULLS; do
    if db_exec_sql "$(build_sql "$old_full" "$NEW_FULL")" > /tmp/rebind.out 2>&1; then
        info "已处理 ${old_full}"
    else
        sed 's/^/      /' /tmp/rebind.out
        die "UPDATE 失败，库可能只改了一半。
      用备份恢复： sudo ./rollback.sh --from-backup ${BK} --restore-db"
    fi
done

say "复查"
for old_full in $OLD_FULLS; do
    OUT=$(db_exec_sql "$(count_sql "$old_full")" 2>&1 || true)
    LEFT=$(printf '%s\n' "$OUT" | awk -F'\t' '{s+=$2} END {print s+0}')
    if [ "${LEFT:-0}" -eq 0 ]; then
        ok "已无 ${old_full} 残留"
    else
        bad "仍有 ${LEFT} 行含 ${old_full}"
        printf '%s\n' "$OUT" | sed 's/^/      /'
    fi
done

say "完成"
cat <<EOF
  备份 : ${BK}

  下一步（必做，否则应用仍用旧配置）：
      sudo systemctl restart maxkey-portal maxkey-mgt

  然后浏览器验证：
      1. 打开 ${MAXKEY_PUBLIC_URL}/maxkey/ 登录
      2. 点菜单「后台」 —— 应免密进入管理端（这是 CAS service 是否一致的关键验证）
      3. 管理端「机构」里的 domain 应已是 ${NEW_HOST}
EOF
