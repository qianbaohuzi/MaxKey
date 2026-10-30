import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.sql.*;
import java.util.*;

/**
 * MaxKeySql —— 极小的 JDBC 执行器，供部署脚本调用。
 *
 * 为什么不用 ksql/psql：麒麟机器上 Kingbase 的客户端工具不一定在 PATH
 * （实测本机 /opt/Kingbase/.../bin 就没进 PATH），而应用要连库就必须带驱动，
 * 包内 fat jar 里的驱动一定存在。所以"用驱动"比"用客户端"可靠。
 *
 * 为什么不用 jshell：jlink 裁剪出的 jre 不含 jdk.jshell 模块。
 *
 * 用法：
 *   java -cp 'sql/lib/*' MaxKeySql --url URL --user U --password P --query "select 1"
 *   java -cp 'sql/lib/*' MaxKeySql --url URL --user U --password P --file seed.sql [--stop-on-error]
 */
public final class MaxKeySql {

    public static void main(String[] args) throws Exception {
        String url = null, user = null, password = "", query = null, file = null;
        boolean stopOnError = false;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--url":      url = args[++i]; break;
                case "--user":     user = args[++i]; break;
                case "--password": password = args[++i]; break;
                case "--query":    query = args[++i]; break;
                case "--file":     file = args[++i]; break;
                case "--stop-on-error": stopOnError = true; break;
                case "-h": case "--help":
                    System.out.println("MaxKeySql --url URL --user U [--password P] (--query SQL | --file F) [--stop-on-error]");
                    return;
                default:
                    System.err.println("未知参数: " + args[i]);
                    System.exit(2);
            }
        }
        if (url == null || user == null) {
            System.err.println("必须提供 --url 与 --user");
            System.exit(2);
        }
        if (password == null || password.isEmpty()) {
            // 也支持从环境变量取，避免口令进进程列表
            String env = System.getenv("DATABASE_PWD");
            if (env != null && !env.isEmpty()) {
                password = env;
            }
        }

        Class.forName(driverFor(url));

        try (Connection c = DriverManager.getConnection(url, user, password)) {
            c.setAutoCommit(true);
            if (query != null) {
                runQuery(c, query);
            } else if (file != null) {
                runFile(c, Paths.get(file), stopOnError);
            } else {
                System.err.println("必须提供 --query 或 --file");
                System.exit(2);
            }
        }
    }

    private static String driverFor(String url) {
        if (url.startsWith("jdbc:postgresql:")) return "org.postgresql.Driver";
        if (url.startsWith("jdbc:kingbase8:"))   return "com.kingbase8.Driver";
        if (url.startsWith("jdbc:mysql:"))       return "com.mysql.cj.jdbc.Driver";
        throw new IllegalArgumentException("不认识的 JDBC URL: " + url);
    }

    /**
     * 执行一条 SQL 并打印结果集（如果有）。
     *
     * 必须用 execute() 而不是 executeQuery()：
     *   executeQuery 只适用于**返回结果集**的语句，对 DDL（DDL 用
     *   executeQuery 会抛 "No results were returned by the query"）与
     *   UPDATE/INSERT 都会失败。而本工具既要跑 select（查表数、Flyway 版本），
     *   也要跑 DROP SCHEMA / CREATE SCHEMA 这类 DDL ——
     *   踩过一次：清库时 DROP SCHEMA 报
     *     PSQLException: No results were returned by the query
     *   看起来像"SQL 写错了"，实际是 JDBC 调用方式不对。
     */
    private static void runQuery(Connection c, String sql) throws SQLException {
        try (Statement s = c.createStatement()) {
            boolean hasRs = s.execute(sql);
            if (!hasRs) {
                int n = s.getUpdateCount();
                if (n >= 0) System.out.println("OK " + n + " rows affected");
                else        System.out.println("OK");
                return;
            }
            try (ResultSet r = s.getResultSet()) {
                int cols = r.getMetaData().getColumnCount();
                while (r.next()) {
                    StringBuilder sb = new StringBuilder();
                    for (int i = 1; i <= cols; i++) {
                        if (i > 1) sb.append('\t');
                        String v = r.getString(i);
                        sb.append(v == null ? "" : v);
                    }
                    System.out.println(sb);
                }
            }
        }
    }

    private static void runFile(Connection c, Path p, boolean stopOnError) throws IOException {
        String text = new String(Files.readAllBytes(p), StandardCharsets.UTF_8);
        List<String> stmts = split(text);
        int ok = 0, fail = 0;
        try (Statement s = c.createStatement()) {
            for (String sql : stmts) {
                String t = sql.trim();
                if (t.isEmpty()) continue;
                try {
                    s.execute(t);
                    ok++;
                } catch (SQLException e) {
                    fail++;
                    System.err.println("  [FAIL] " + firstLine(t) + " -> " + e.getMessage());
                    if (stopOnError) {
                        throw new SQLException("导入中止（--stop-on-error）", e);
                    }
                }
            }
        } catch (SQLException e) {
            System.err.println("ERROR: " + e.getMessage());
            System.exit(1);
        }
        System.out.println("  执行语句 " + ok + " 条成功" + (fail > 0 ? "，" + fail + " 条失败" : ""));
        if (fail > 0) System.exit(1);
    }

    /** 只在引号/注释之外按 ; 切分。种子库由 make-seed.py 生成，不含存储过程，可安全切分。 */
    private static List<String> split(String sql) {
        List<String> out = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        boolean inS = false, inD = false, inLine = false, inBlock = false;
        for (int i = 0; i < sql.length(); i++) {
            char ch = sql.charAt(i);
            char nx = i + 1 < sql.length() ? sql.charAt(i + 1) : '\0';

            if (inLine) {
                cur.append(ch);
                if (ch == '\n') inLine = false;
                continue;
            }
            if (inBlock) {
                cur.append(ch);
                if (ch == '*' && nx == '/') { cur.append(nx); i++; inBlock = false; }
                continue;
            }
            if (!inS && !inD) {
                if (ch == '-' && nx == '-') { cur.append(ch).append(nx); i++; inLine = true; continue; }
                if (ch == '/' && nx == '*') { cur.append(ch).append(nx); i++; inBlock = true; continue; }
            }
            if (ch == '\'' && !inD) {
                inS = !inS;
                cur.append(ch);
                continue;
            }
            if (ch == '"' && !inS) {
                inD = !inD;
                cur.append(ch);
                continue;
            }
            if (ch == ';' && !inS && !inD) {
                out.add(cur.toString());
                cur.setLength(0);
                continue;
            }
            cur.append(ch);
        }
        if (cur.toString().trim().length() > 0) out.add(cur.toString());
        return out;
    }

    private static String firstLine(String s) {
        int nl = s.indexOf('\n');
        String one = (nl < 0 ? s : s.substring(0, nl)).trim();
        return one.length() > 90 ? one.substring(0, 90) + "..." : one;
    }
}
