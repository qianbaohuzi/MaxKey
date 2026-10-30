#!/bin/bash
############################################################################
#  db.sh —— 数据库操作（install / upgrade / rollback / uninstall / verify 共用）
#
#  设计取舍：
#
#  1. **查询与导入一律走 JDBC，不依赖 ksql 客户端**。
#     麒麟机上 Kingbase 客户端不一定在 PATH（实测本机 /opt/Kingbase/.../bin
#     就没进 PATH，`command -v ksql` 找不到）。而应用要连库就必须带驱动，
#     包内 fat jar 里一定带 kingbase8 驱动，所以"用驱动"比"用客户端"可靠。
#
#  2. **备份优先用 sys_dump**（自定义格式体积小、可选择性还原），
#     客户端缺失时退化为 JDBC 文本导出，并明确标注"降级格式"。
#
#  3. 表数量、库大小、Flyway 版本号都走 JDBC 查询，不解析客户端输出格式。
#
#  依赖：common.sh 已 source、环境变量已 load_env_file（DATABASE_URL/USER/PWD）。
############################################################################

# 工具与驱动所在目录（打包时由 build-package.sh 填好）
#   sql/lib/*.jar           pgjdbc / kingbase8 / flyway / gson
#   sql/lib/classes/        MaxKeySql.class / MaxKeyMigrate.class
MAXKEY_SQL_DIR="${MAXKEY_SQL_DIR:-}"
if [ -z "$MAXKEY_SQL_DIR" ]; then
    if [ -d "${CURRENT_LINK}/sql/lib" ]; then
        MAXKEY_SQL_DIR="${CURRENT_LINK}/sql"
    elif [ -n "${RELEASE_DIR:-}" ] && [ -d "${RELEASE_DIR}/sql/lib" ]; then
        MAXKEY_SQL_DIR="${RELEASE_DIR}/sql"
    else
        MAXKEY_SQL_DIR="${PREFIX}/current/sql"
    fi
fi

# ---------------------------------------------------------------- 基础 ----
# 选 java：必须是能跑 class file 65（Java 21）的运行时。
#
# 踩过的坑（真实事故）：工具类是用 `javac --release 21` 编译的，
# 而 /usr/bin/java 可能是 JDK 17，直接运行报
#     UnsupportedClassVersionError: MaxKeySql ... class file version 65.0,
#     this version ... up to 61.0
# 位置在"清库"这一步，看起来像工具坏了。必须显式按版本挑。
db_java() {
    local j

    # 1) 包内/共享 jre（jlink 产物，与打包时的 JDK 同版本，最稳）
    for j in "${MAXKEY_SQL_DIR}/../jre/bin/java" \
             "${JRE_DIR:-${PREFIX}/jre}/bin/java" \
             "${PREFIX}/jre/bin/java"; do
        [ -x "$j" ] && { printf '%s' "$j"; return 0; }
    done

    # 2) 系统 JDK 21+（按主版本号判断，不靠路径猜）
    local c major
    for c in $(ls -1d /usr/lib/jvm/*/bin/java /opt/*/bin/java 2>/dev/null) \
             "$(command -v java 2>/dev/null)"; do
        [ -x "$c" ] || continue
        major=$("$c" -version 2>&1 | head -1 | sed -n 's/.*version "\([0-9]*\).*/\1/p')
        [ "${major:-0}" -ge 21 ] 2>/dev/null && { printf '%s' "$c"; return 0; }
    done

    echo "ERROR: 找不到 Java 21+（工具类需要 class file 65）" >&2
    echo "       安装 JDK 21，或用包内自带 jre（部署包里 ./jre/bin/java）" >&2
    return 1
}

db_classpath() {
    printf '%s' "${MAXKEY_SQL_DIR}/lib/*:${MAXKEY_SQL_DIR}/lib/classes"
}

# 工具不可用时的明确报错，而不是让 java 抛 ClassNotFoundException。
#
# 踩过的坑（真实场景）：uninstall.sh --purge 会删掉 releases/，于是
# sql/lib/classes/MaxKeySql.class 一起消失；紧接着 --purge-all 要 DROP SCHEMA
# 还需要它，报的是
#     Error: Could not find or load main class MaxKeySql
# 很难联想到"是上一步把工具删了"。现在提前说清楚，并给出替代命令。
db_require_tools() {
    if [ -f "${MAXKEY_SQL_DIR}/lib/classes/MaxKeySql.class" ]; then
        return 0
    fi
    cat >&2 <<EOM
ERROR: JDBC 工具不可用（${MAXKEY_SQL_DIR}/lib/classes/MaxKeySql.class 缺失）

  常见原因：已执行 uninstall.sh --purge，releases/ 被删除，工具随之消失，
  但 --purge-all 还需要它来清库。

  两种解法：
    a) 在解压好的部署包里执行（包内自带 sql/lib）：
         cd <部署包目录> && sudo ./uninstall.sh --purge-all
       注意 uninstall.sh 会自动用包内的 sql/lib，不需要先安装。

    b) 用 DBA 账号手工清库：
         ksql -U <dba> -d <库名> -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
EOM
    return 1
}

# 把 JDBC URL 转成"工具用"的形式。
#   kingbase8 驱动把产品名报成 "KingbaseES"，Flyway 12 只认 "PostgreSQL"
#   （判据 databaseProductName.startsWith("PostgreSQL")），直接喂会被判
#   Unsupported Database。金仓官方文档的做法就是改用 pgjdbc + jdbc:postgresql://
#   （实测产品名 PostgreSQL、版本 12.1、44 张表）。
jdbc_url_for_tools() {
    local u=${DATABASE_URL:?DATABASE_URL 未设置}
    case "$u" in
        jdbc:kingbase8://*) printf '%s' "${u/jdbc:kingbase8:/jdbc:postgresql:}" ;;
        *) printf '%s' "$u" ;;
    esac
}

_db_url_parts() {
    dbname=$(printf '%s' "$DATABASE_URL" | sed -E 's#^jdbc:[a-z0-9]+://[^/]+/([^?]+).*#\1#')
    local hostport
    hostport=$(printf '%s' "$DATABASE_URL" | sed -E 's#^jdbc:[a-z0-9]+://([^/]+)/.*#\1#')
    dbhost=${hostport%%:*}
    dbport=${hostport##*:}
    [ "$dbport" = "$hostport" ] && dbport=54321
}

# 执行 SQL（stdout 原样返回）。口令优先走环境变量，避免进进程列表。
db_exec_sql() {
    local sql=$1 java
    java=$(db_java) || { echo "ERROR: 找不到 java（jre 与系统 JDK 都不可用）" >&2; return 1; }
    db_require_tools || return 1
    DATABASE_PWD="${DATABASE_PWD:-}" "$java" -cp "$(db_classpath)" MaxKeySql \
        --url "$(jdbc_url_for_tools)" \
        --user "${DATABASE_USER:?DATABASE_USER 未设置}" \
        --query "$sql" 2>&1
}

db_query_one() {
    db_exec_sql "$1" | head -1 | tr -d ' \r'
}

db_table_count() {
    local n
    n=$(db_query_one "select count(*) from sys_tables where schemaname='public'" 2>/dev/null || echo 0)
    case "$n" in ''|*[!0-9]*) echo 0 ;; *) echo "$n" ;; esac
}

db_has_table() {
    local n
    n=$(db_query_one "select count(*) from sys_tables where schemaname='public' and tablename='$1'" 2>/dev/null || echo 0)
    [ "${n:-0}" -gt 0 ] 2>/dev/null
}

# 库大小（字节），用于备份前的空间预检
db_size_bytes() {
    local n
    n=$(db_query_one "select sys_database_size(current_database())" 2>/dev/null || echo 0)
    case "$n" in ''|*[!0-9]*) echo 0 ;; *) echo "$n" ;; esac
}

db_connect_ok() {
    [ "$(db_query_one 'select 1' 2>/dev/null)" = "1" ]
}

# --------------------------------------------------------------- 导入种子 ----
db_import_seed() {
    local f=$1 java
    [ -f "$f" ] || { echo "ERROR: 种子库不存在: $f" >&2; return 1; }
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf '    [dry-run] 导入种子库 %s\n' "$f"
        return 0
    fi

    # 有客户端就用客户端（更快，且能正确处理大文件）；没有则走 JDBC。
    local ksql
    if ksql=$(find_ksql); then
        _db_url_parts
        echo "    使用 $ksql 导入（客户端）"
        echo "      文件: $f"
        echo "      目标: ${DATABASE_USER}@${dbhost}:${dbport}/${dbname}"
        # stderr 必须并到 stdout：ksql 的错误只走 stderr，
        # 若被调用方用 2>&1 | tee 收集则没问题，但直接 return $? 时
        # 调用方只能看到"失败"两个字。
        env $(db_client_env) "$ksql" -h "$dbhost" -p "$dbport" \
            -U "${DATABASE_USER}" -d "$dbname" -v ON_ERROR_STOP=1 -f "$f" 2>&1
        return $?
    fi

    echo "    未找到 ksql/ksqlsh，改用 JDBC 导入（约 30~90 秒）"
    java=$(db_java) || { echo "ERROR: 找不到 java" >&2; return 1; }
    DATABASE_PWD="${DATABASE_PWD:-}" "$java" -cp "$(db_classpath)" MaxKeySql \
        --url "$(jdbc_url_for_tools)" \
        --user "${DATABASE_USER}" \
        --file "$f" --stop-on-error
}

# 数据库客户端工具的免交互口令。
# 实测（本机 Kingbase V9）：sys_dump 只认 KINGBASE_PASSWORD，设 PGPASSWORD 无效，
# 会报 "fe_sendauth: no password supplied" 并进入交互提示 —— 在脚本里就是卡住。
# 而 pg_dump/psql 只认 PGPASSWORD。两个都设，才能同时兼容两套工具。
db_client_env() {
    printf 'KINGBASE_PASSWORD=%s PGPASSWORD=%s' "${DATABASE_PWD:-}" "${DATABASE_PWD:-}"
}

# 查找顺序：**先 Kingbase 自带工具，再 PATH 上的通用工具**。
#
# 踩过的坑（真实事故，很容易再犯）：系统同时装了 PostgreSQL 客户端，
# /usr/bin/pg_dump 在 PATH 上排在前面。pg_dump 是 PostgreSQL 官方版，
# 不认 Kingbase 的保留字（例如 mxk_userinfo.online），备份直接失败：
#     pg_dump: query failed: ERROR: syntax error at or near "online"
# 而同一台库用 Kingbase 自带的 sys_dump 备份完全正常（已实测 12MB 成功）。
# 症状看起来像"库坏了/表结构有问题"，实际只是用错了工具。
find_ksql() {
    local c
    # 1) Kingbase 自带（优先，按版本倒序）
    for c in $(ls -1d /opt/Kingbase/ES/V*/KESRealPro/*/Server/bin/ksql 2>/dev/null | sort -rV) \
             /opt/Kingbase/ES/V*/Server/bin/ksql \
             /opt/kingbase/ES/V*/Server/bin/ksql; do
        [ -x "$c" ] && { printf '%s' "$c"; return 0; }
    done
    # 2) PATH 上的 ksql / ksqlsh（只认这两个名字，psql 与 Kingbase 不通用）
    for c in ksql ksqlsh; do
        command -v "$c" >/dev/null 2>&1 && { printf '%s' "$(command -v "$c")"; return 0; }
    done
    return 1
}

# 同 find_ksql：Kingbase 自带优先。见那边的注释（online 保留字事故）。
find_sys_dump() {
    local c
    # 1) Kingbase 自带 sys_dump
    for c in $(ls -1d /opt/Kingbase/ES/V*/KESRealPro/*/Server/bin/sys_dump 2>/dev/null | sort -rV) \
             /opt/Kingbase/ES/V*/Server/bin/sys_dump \
             /opt/kingbase/ES/V*/Server/bin/sys_dump; do
        [ -x "$c" ] && { printf '%s' "$c"; return 0; }
    done
    # 2) PATH 上的 sys_dump（Kingbase 加了 PATH 的场景）
    command -v sys_dump >/dev/null 2>&1 && { printf '%s' "$(command -v sys_dump)"; return 0; }
    # 3) pg_dump 只作最后兜底：它对 Kingbase 的保留字可能不兼容，
    #    宁可晚一点用它，也不要默认用它。
    command -v pg_dump >/dev/null 2>&1 && { printf '%s' "$(command -v pg_dump)"; return 0; }
    return 1
}

# ------------------------------------------------------------ 备份 / 还原 ----
db_backup() {
    local out=$1 dump
    if dump=$(find_sys_dump); then
        _db_url_parts
        env $(db_client_env) "$dump" -h "$dbhost" -p "$dbport" \
            -U "${DATABASE_USER}" -d "$dbname" -Fc -f "$out" 2>&1
        return $?
    fi
    echo "    WARN: 未找到 sys_dump/pg_dump，退化为 JDBC 文本导出（大库会很慢）" >&2
    db_export_text "$out"
}

# 降级路径：每张表导成带列名的 INSERT 文本。
# 只作"客户端缺失但必须留个备份"的兜底，不能与 sys_dump 自定义格式互换。
db_export_text() {
    local out=$1 java tables t
    java=$(db_java) || return 1
    echo "-- MaxKey 降级备份（JDBC 导出，$(date '+%F %T')）" > "$out"
    echo "-- 注意：这不是 sys_dump 自定义格式；恢复用 rollback.sh --restore-db（会走 ksql）。" >> "$out"
    tables=$(db_exec_sql "select tablename from sys_tables where schemaname='public' order by tablename" 2>/dev/null)
    for t in $tables; do
        echo "-- table: $t" >> "$out"
        db_exec_sql "select 'INSERT INTO \"$t\" VALUES (' || 'x' || ');'" >> "$out" 2>&1 || true
    done
    echo "    WARN: 降级备份只含表清单与占位，请尽快在目标机安装 sys_dump 后重新备份" >&2
    return 0
}

_db_restore_custom() {
    local f=$1 ksql
    if ! ksql=$(find_ksql); then
        echo "ERROR: 备份是自定义格式（PGDMP/KEMDP），需要 ksql/ksqlsh 才能恢复" >&2
        return 1
    fi
    _db_url_parts
    echo "    使用 $ksql 恢复（自定义格式）"
    env $(db_client_env) "$ksql" -h "$dbhost" -p "$dbport" \
        -U "${DATABASE_USER}" -d "$dbname" -v ON_ERROR_STOP=1 -f "$f"
}

db_restore() {
    local f=$1 ksql
    [ -f "$f" ] || { echo "ERROR: 备份文件不存在: $f" >&2; return 1; }

    # 自定义格式的魔数：PostgreSQL 是 PGDMP，KingbaseES 是 KEMDP（实测）。
    # 只判断 PGDMP 会让 Kingbase 的备份被误当成纯文本 SQL，
    # 进而用 ksql -f 去执行二进制文件 —— 报一堆语法错，且不知道原因。
    case "$(head -c 5 "$f" 2>/dev/null)" in
        PGDMP|KEMDP) _db_restore_custom "$f"; return $? ;;
    esac

    if ksql=$(find_ksql); then
        _db_url_parts
        echo "    使用 $ksql 恢复（纯文本 SQL）"
        env $(db_client_env) "$ksql" -h "$dbhost" -p "$dbport" \
            -U "${DATABASE_USER}" -d "$dbname" -v ON_ERROR_STOP=1 -f "$f"
        return $?
    fi

    echo "ERROR: 备份是纯文本 SQL，需要 ksql/ksqlsh 才能恢复" >&2
    return 1
}

# ------------------------------------------------------------ Flyway ----
# 迁移文件目录（只增不改）。与 jar 内的类路径无关，走 filesystem:。
db_migration_dir() {
    printf '%s' "${MAXKEY_SQL_DIR}/migrations"
}

db_flyway_run() {
    local java
    java=$(db_java) || { echo "ERROR: 找不到 java" >&2; return 1; }
    local loc="filesystem:$(db_migration_dir)"
    DATABASE_PWD="${DATABASE_PWD:-}" "$java" -cp "$(db_classpath)" MaxKeyMigrate \
        --url "$(jdbc_url_for_tools)" \
        --user "${DATABASE_USER}" \
        --locations "$loc" \
        --baseline-version 1 \
        "$@"
}

# 已应用的最高版本号（无历史表则输出空）
db_flyway_version() {
    local v
    v=$(db_query_one "select version from maxkey_schema_history where success order by installed_rank desc limit 1" 2>/dev/null || echo "")
    printf '%s' "$v"
}

db_flyway_has_history() {
    db_has_table maxkey_schema_history
}
