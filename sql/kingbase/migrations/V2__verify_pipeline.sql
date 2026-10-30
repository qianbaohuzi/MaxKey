-- V2 —— 迁移管线验证（真实可用的 DDL，不是空壳）
--
-- 为什么留这个文件而不是删掉：
--   1. 它是"迁移管线能跑通"的可执行证据 —— 空 migrations 目录无法证明
--      Flyway 真的会执行，也无法证明 baseline 之后能接上增量。
--   2. 内容本身有用：mxk_accounts.instid 上没有索引，而多租户查询
--      （按 instid 过滤账号列表）在 1000 人规模下会全表扫。
--   3. 全部写成 IF NOT EXISTS，可在演练库上反复执行。
--
-- 后续真实变更请新建 V3__*.sql，不要修改本文件（Flyway 校验和不允许）。

CREATE INDEX IF NOT EXISTS idx_mxk_accounts_instid
    ON mxk_accounts (instid);

CREATE INDEX IF NOT EXISTS idx_mxk_apps_instid
    ON mxk_apps (instid);
