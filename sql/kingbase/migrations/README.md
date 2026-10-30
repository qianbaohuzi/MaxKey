# Flyway 迁移文件（只增不改）

## 约定

- 文件名：`V<序号>__<英文短描述>.sql`，例如 `V2__add_user_mobile_index.sql`
- 序号从 2 开始：**V1 是现有种子库**（`sql/kingbase/maxkey-seed.sql` 建的 44 张表），
  `install.sh --init-db` 建库后会执行 `baseline` 把当前结构标记为 V1。
- 已发布的文件**不能修改**：Flyway 会校验校验和，改一个字节就会在下次迁移时
  报 `Validate failed: Migration checksum mismatch`，导致升级直接失败。
  需要修正时新建一个 V 文件（可以是反向 SQL）。
- 每个文件必须**幂等或至少可重入**：虽然 Flyway 保证"每个文件只执行一次"，
  但回滚演练会重放（见 `rollback.sh --restore-db`），写 `IF NOT EXISTS`
  能让演练更省心。
- 不要在这里放种子数据（业务初始化数据走 `maxkey-seed.sql`），
  这里只放**表结构变更**与必要的字典数据。

## 执行时机

- `install.sh --init-db`：建表（种子库）→ `baseline` 到 V1
- `upgrade.sh <包>`：停服务 → 备份 → 执行 V2..Vn → 切版本 → 启服务 → 健康检查
- 手工：`bin/migrate.sh --info` 看状态，`bin/migrate.sh` 执行

## 为什么用 Flyway 而不是自研版本表

Flyway 提供了三件自研容易做错的事：校验和（防止已执行脚本被悄悄改）、
失败中断（迁移中途失败不会留下"半张表"的记账）、以及 `info` 的
"已应用/待应用"视图。这些正是多环境重复验证时最容易出问题的部分。

数据库是 KingbaseES（PostgreSQL 系），但 **Flyway 走 pgjdbc 连接**：
KingbaseES 驱动的产品名是 `KingbaseES`，Flyway 12 只认 `PostgreSQL` 开头，
直接喂会被判 `Unsupported Database`。所以 `lib/db.sh` 里会把
`jdbc:kingbase8://` 自动改写成 `jdbc:postgresql://`（已实测可连通，
产品名返回 PostgreSQL / 12.1）。

## 一个可用的模板

```sql
-- V2__example.sql
-- 加一个索引。写成 IF NOT EXISTS，便于在演练库上重复执行。
CREATE INDEX IF NOT EXISTS idx_mxk_accounts_instid ON mxk_accounts (instid);

-- 加一列（KingbaseES 支持 ADD COLUMN IF NOT EXISTS）
ALTER TABLE mxk_institutions ADD COLUMN IF NOT EXISTS theme varchar(50) DEFAULT NULL;
```
