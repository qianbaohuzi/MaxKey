import java.io.*;
import java.sql.*;
import java.util.*;

/**
 * MaxKeyMigrate —— Flyway 迁移入口（供 upgrade.sh 调用）。
 *
 * 为什么自己写入口而不是用官方 flyway-commandline：
 *   官方 linux-x64 发行包实测 476MB（打包了所有数据库的驱动），
 *   而实际只需要 flyway-core + flyway-database-postgresql + pgjdbc + gson ≈ 2.5MB。
 *   每次更新都要把 400MB 的包传到测试机，多 476MB 不可接受。
 *
 * 为什么用反射调用 Flyway：
 *   本文件编译时不依赖 flyway-core（构建机上没有该构件也能编译），
 *   运行期从 sql/lib/ 里加载。这样工具源码可以入库而不引入构建期依赖。
 *
 * 关键事实（已实测）：
 *   * Flyway 12 的 PostgreSQLDatabaseType 判据是
 *     databaseProductName.startsWith("PostgreSQL")；
 *   * kingbase8 驱动的 getDatabaseProductName() 返回 "KingbaseES" → 会被判
 *     "Unsupported Database" 直接拒绝；
 *   * pgjdbc 连接同一台 KingbaseES 返回 "PostgreSQL"（实测：
 *     product = PostgreSQL, version = 12.1, 44 张表）。
 *   所以迁移一律走 jdbc:postgresql:// 前缀，与应用的 kingbase8 URL 并存。
 *
 * 参数：
 *   --url jdbc:postgresql://host:port/db  --user U  --password P
 *   --locations filesystem:/path/migrations
 *   --baseline-version 1        首次对接已有结构的库（种子库建出来的）时使用
 *   --baseline                  执行 baseline
 *   --info                      只打印已应用/待应用，不迁移
 *   --target <version>          迁移到指定版本（回滚场景下用于检查）
 */
public final class MaxKeyMigrate {

    public static void main(String[] args) throws Exception {
        String url = null, user = null, password = "", locations = null;
        String baselineVersion = null, target = null;
        boolean doBaseline = false, infoOnly = false;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--url": url = args[++i]; break;
                case "--user": user = args[++i]; break;
                case "--password": password = args[++i]; break;
                case "--locations": locations = args[++i]; break;
                case "--baseline-version": baselineVersion = args[++i]; break;
                case "--target": target = args[++i]; break;
                case "--baseline": doBaseline = true; break;
                case "--info": infoOnly = true; break;
                case "-h": case "--help":
                    System.out.println("MaxKeyMigrate --url URL --user U [--password P] --locations DIR "
                            + "[--baseline --baseline-version 1] [--info] [--target V]");
                    return;
                default:
                    System.err.println("未知参数: " + args[i]);
                    System.exit(2);
            }
        }
        if (url == null || user == null || locations == null) {
            System.err.println("必须提供 --url / --user / --locations");
            System.exit(2);
        }
        if (password == null || password.isEmpty()) {
            String env = System.getenv("DATABASE_PWD");
            if (env != null && !env.isEmpty()) password = env;
        }

        // 反射构造 Flyway：不引入编译期依赖
        Class<?> flywayClass;
        try {
            flywayClass = Class.forName("org.flywaydb.core.Flyway");
        } catch (ClassNotFoundException e) {
            System.err.println("ERROR: 找不到 org.flywaydb.core.Flyway（检查 sql/lib/ 是否完整）");
            System.exit(3);
            return;
        }

        Object cfg = flywayClass.getMethod("configure").invoke(null);
        Class<?> cfgClass = cfg.getClass();

        // FluentConfiguration 的方法返回自身，可用反射链式调用
        Object fluent = cfg;
        fluent = call(fluent, "dataSource", new Class<?>[]{String.class, String.class, String.class},
                url, user, password);
        fluent = call(fluent, "locations", new Class<?>[]{String[].class}, (Object) new String[]{locations});
        // 已发布迁移文件禁改：校验和变化应当立刻失败而不是"自动修"
        fluent = call(fluent, "validateOnMigrate", new Class<?>[]{boolean.class}, Boolean.TRUE);
        // 库里已有结构（种子库建的）时，允许 baseline 从指定版本起算，
        // 否则 Flyway 会因"非空库且无历史表"直接报错。
        fluent = call(fluent, "baselineOnMigrate", new Class<?>[]{boolean.class}, Boolean.TRUE);
        fluent = call(fluent, "baselineVersion", new Class<?>[]{String.class},
                baselineVersion == null ? "0" : baselineVersion);
        // 迁移用独立的 schema 历史表，与应用表放一起便于 DBA 直接看
        fluent = call(fluent, "table", new Class<?>[]{String.class}, "maxkey_schema_history");
        if (target != null) {
            fluent = call(fluent, "target", new Class<?>[]{String.class}, target);
        }

        Object flyway = cfgClass.getMethod("load").invoke(fluent);

        if (doBaseline) {
            Object result = flyway.getClass().getMethod("baseline").invoke(flyway);
            System.out.println("baseline 完成: " + result);
            return;
        }

        if (infoOnly) {
            Object info = flyway.getClass().getMethod("info").invoke(flyway);
            System.out.println(info);
            // 有待应用的迁移时退出码 1（供脚本判断"是否需要迁移"）
            int pendingCount = 0;
            try {
                Object pending = info.getClass().getMethod("pending").invoke(info);
                if (pending instanceof Object[]) {
                    pendingCount = ((Object[]) pending).length;
                }
            } catch (NoSuchMethodException ignore) {
                // 老版本 Flyway 没有 pending()，按 0 处理
            }
            System.exit(pendingCount > 0 ? 1 : 0);
            return;
        }

        Object result = flyway.getClass().getMethod("migrate").invoke(flyway);
        System.out.println("迁移完成: " + result);

        System.out.println("当前数据库版本: " + currentVersion(flyway));
    }

    private static Object call(Object target, String method, Class<?>[] types, Object... a) throws Exception {
        return target.getClass()
                .getMethod(method, types)
                .invoke(target, a);
    }

    private static String currentVersion(Object flyway) {
        try {
            Object info = flyway.getClass().getMethod("info").invoke(flyway);
            Object cv = info.getClass().getMethod("current").invoke(info);
            if (cv == null) return "(无)";
            Object v = cv.getClass().getMethod("version").invoke(cv);
            return String.valueOf(v);
        } catch (Exception e) {
            return "(取不到)";
        }
    }
}
