#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make-seed.py —— 从完整的 KingbaseES 建库脚本裁剪出「最小可登录种子」版本

背景
----
sql/kingbase/maxkey.sql 是 convert_from_mysql.py 从 MySQL 官方 dump 全量转换来的：
44 张表 / 3219 条 INSERT / 18.9MB。其中 99% 是与生产无关的演示数据。

**裁剪维度必须按字节，不能按行数。** 实测各表占用：

    mxk_userinfo           16693 KB / 60 条   平均 278 KB/条  ← 每条内嵌一张 PNG 头像
    mxk_apps                1508 KB / 34 条   平均  44 KB/条  ← 每个应用内嵌 PNG 图标
    mxk_history_login_apps   345 KB / 1219 条  平均 0.3 KB/条  ← 行数最多但体积最小
    mxk_permission           123 KB /  453 条  平均 0.3 KB/条

也就是说：按"行数"裁掉 2290 条日志，只能省 0.7MB（压缩比 96%）；
真正的体积全在 60 个演示用户的头像和 34 个演示应用的图标里。
所以本脚本做两件事：
  1. 只保留 admin 一个用户（其余 59 个演示用户丢弃，含其头像）
  2. 演示应用保留配置、把 icon 字段替换为 NULL（结构不变，只去二进制）

保留哪些表的判断依据不是"有数据就留"，而是登录链路会读它：
  mxk_institutions        租户识别（WebInstRequestFilter 按 Host 头查本表）
  mxk_userinfo            admin 账号本体（密码 {plain}maxkey）
  mxk_localization        登录页标题等 UI 文案
  mxk_cnf_password_policy 改密校验策略
  mxk_apps + 各 protocol details  SSO 接入配置示例，方便现场照着配
  mxk_resources / mxk_permission / mxk_permission_role
                          管理端菜单与权限，缺了登录进去是白屏

用法
----
    python3 sql/kingbase/make-seed.py
    python3 sql/kingbase/make-seed.py --verify     # 生成后做结构与体积自检
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "maxkey.sql")
DST = os.path.join(HERE, "maxkey-seed.sql")

# 整表保留 INSERT 的表
KEEP_TABLES = {
    "mxk_institutions",
    "mxk_resources",
    "mxk_permission",
    "mxk_permission_role",
    "mxk_roles",
    "mxk_role_member",
    "mxk_cnf_password_policy",
    "mxk_cnf_email_senders",
    "mxk_cnf_sms_provider",
    "mxk_cnf_ldap_context",
    "mxk_localization",
    "mxk_organizations",
    # --- 用户组：SSO 应用授权判定的必经路径 ---
    # AppsMapper.queryMyApps 的 SQL 是：
    #   select distinct app.* from mxk_apps app, mxk_access p, mxk_groups g
    #   where app.id=p.appid and p.groupid=g.id ...
    #     and g.id in (select id from mxk_groups where groupcode='ROLE_ALL_USER'
    #                  union select gm.groupid from mxk_group_member gm, mxk_userinfo u
    #                  where gm.memberid=u.id and u.username=?)
    # 也就是说：没有 ROLE_ALL_USER 组 + admin 的成员记录 + mxk_access 授权行，
    # 登录后「我的应用」是空列表，访问 /authz/oauth/v20/authorize 会被
    # SingleSignOnInterceptor 判为无权限并 302 到 /sign/authz/refused。
    # 这是实测踩到的：只保留 apps 而不保留 groups/group_member 会导致
    # “能登录、但任何 SSO 都授权不了”。
    "mxk_groups",
    # --- 应用接入配置 ---
    # 演示应用（mxk_apps 及各协议明细、mxk_access 授权行）**全部不导入**，
    # 见下方 EMPTY_TABLES 的说明。
    #
    # 但 mxk_apps_adapters 必须保留：它是"协议适配器"的类名映射
    # （如 org.dromara.maxkey.authz.cas.adapter.CasDefaultAdapter），
    # 不是应用实例。管理端新建应用时要从这里选适配器，
    # 删掉会导致新建应用时下拉框为空、无法保存。
    "mxk_apps_adapters",
    "mxk_socials_provider",
}

# 整表剔除 INSERT（表结构保留，数据不导入）
# 与 KEEP_TABLES 的区别：这里用于"结构要、数据不要"的表。
#
# 为什么演示应用全部不要：
#   官方 dump 里的 34 个应用，其 loginurl / redirect_uri 几乎全部指向
#   不存在的演示域名（hr.maxkey.top / jira.maxkey.top / jenkins.maxkey.top /
#   zentao.maxkey.top / cas.demo.maxkey.top / gitlab.maxkey.top …）。
#   实测点进去必然跳转失败，只会让人误以为"系统坏了"。
#   其中 OAuth/OIDC 的 14 个 client 问题更严重：
#     * redirect_uri 指向演示域名 → 业务系统收不到 code
#     * 13 条 issuer 为空 → id_token 没有 iss 声明（OIDC 规范要求必须有）
#   真实接入时应在管理端按需新建，字段结构可参考部署文档。
EMPTY_TABLES = {
    "mxk_apps",                          # 应用主表
    "mxk_apps_cas_details",              # 各协议明细表
    "mxk_apps_saml_v20_details",
    "mxk_apps_jwt_details",
    "mxk_apps_token_based_details",
    "mxk_apps_form_based_details",
    "mxk_apps_oauth_client_details",
    "mxk_access",                        # 应用授权行（应用没了就是孤儿）
}

# 只保留指定行（表 -> 判定函数）
ONLY_ROWS = {
    # 只要 admin（mxk_userinfo.id = 1）。其余 59 个是演示用户。
    "mxk_userinfo": lambda line: re.search(r"\(\s*E?'1'\s*,", line.split("VALUES", 1)[1][:80]) is not None,
    # 只要 admin 的组成员关系。完整版 60 个用户各有一行 ROLE_ALL_USER_<id>，
    # 裁剪后只剩 admin 的 6 行（含关键的 ROLE_ALL_USER_1）。
    # 行格式：VALUES (E'<id>', E'<groupid>', E'1', E'USER', ...)
    #                                     ^^ memberid 在第 3 个字段
    "mxk_group_member": lambda line: re.match(
        r"^INSERT INTO mxk_group_member .* VALUES \(\s*E?'[^']*'\s*,\s*E?'[^']*'\s*,\s*E?'1'\s*,",
        line) is not None,
}

# 保留表但清空二进制大字段
# 做法：把 INSERT 里形如  E'\\x....'::bytea  的超长字面量替换成 NULL，列数不变。
# MySQL 源是 _binary '...'，转换后成了 E'\\x<hex>'::bytea，头像与图标都走这个形式。
#
# 注意：mxk_apps_saml_v20_details 里的 bytea 是 **SAML 签名证书**，属于有效配置，
# 必须保留（8 条共约 56KB，可忽略）。因此这里只列出真正是「图片」的两处。
BLOB_COLUMNS = {
    "mxk_apps": ["icon"],        # 34 个演示应用的图标，约 1.5MB
    "mxk_userinfo": ["picture"],  # admin 的头像，约 7.4KB（其余用户已被整体丢弃）
}

BLOB_RE = re.compile(r"E'(?:\\\\x|\\x)[0-9a-fA-F]{200,}'::bytea")


def strip_blob(line):
    """把超长的 bytea 字面量替换为 NULL，保持列数不变。"""
    return BLOB_RE.sub("NULL", line)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true", help="生成后做自检")
    args = ap.parse_args()

    if not os.path.exists(SRC):
        sys.exit("ERROR: 源文件不存在: %s" % SRC)

    with open(SRC, encoding="utf-8", errors="surrogateescape") as f:
        raw = f.read()

    out = []
    stats = {}
    dropped = {}
    blob_bytes_saved = 0

    for ln in raw.split("\n"):
        m = re.match(r"^INSERT INTO (\w+)", ln)
        if not m:
            out.append(ln)
            continue
        tbl = m.group(1)
        before = len(ln.encode("utf-8", "surrogateescape"))

        # 整表剔除：结构保留、数据不要
        if tbl in EMPTY_TABLES:
            dropped[tbl] = dropped.get(tbl, 0) + 1
            continue

        keep = False
        if tbl in KEEP_TABLES:
            keep = True
        elif tbl in ONLY_ROWS:
            keep = ONLY_ROWS[tbl](ln)

        if not keep:
            dropped[tbl] = dropped.get(tbl, 0) + 1
            continue

        if tbl in BLOB_COLUMNS:
            ln2 = strip_blob(ln)
            blob_bytes_saved += before - len(ln2.encode("utf-8", "surrogateescape"))
            ln = ln2

        out.append(ln)
        stats[tbl] = stats.get(tbl, 0) + 1

    body = "\n".join(out)

    header = """-- MaxKey 4.2.0 KingbaseES 最小种子库脚本
-- 由 sql/kingbase/make-seed.py 从 maxkey.sql 裁剪生成，请勿手工修改
--
-- 与完整版的差异：
--   表结构 **完全一致**（44 张表、全部索引/约束/注释/序列），不做任何删减。
--   INSERT 只保留登录与管理端菜单的最小闭环：
--     * mxk_userinfo 仅 admin 一行（完整版有 60 个演示用户，共 16MB 头像）
--     * mxk_apps 保留 34 个演示应用的**配置**，icon 字段置 NULL（省 1.5MB）
--     * 演示登录历史 / 系统日志 / 同步记录类全部丢弃
--
-- 建库：
--   ksql -U maxkey -d maxkey -f maxkey-seed.sql
--
-- 初始账号：admin / maxkey   （mxk_userinfo.password 为 {plain}maxkey）
-- 上线前请立即：① 改 admin 密码  ② 把 mxk_institutions.domain 改成真实域名

"""

    with open(DST, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(header)
        f.write(body)
        f.write("\n")

    src_size = os.path.getsize(SRC)
    dst_size = os.path.getsize(DST)

    print("源文件 : %s  (%.1f MB)" % (SRC, src_size / 1048576.0))
    print("输出   : %s  (%.1f MB)" % (DST, dst_size / 1048576.0))
    print("体积   : %.1f%% of 原文件（省 %.1f MB）" %
          (100.0 * dst_size / src_size, (src_size - dst_size) / 1048576.0))
    if blob_bytes_saved:
        print("其中二进制字段置 NULL 省下 %.1f MB" % (blob_bytes_saved / 1048576.0))

    print("\n保留的 INSERT：")
    for k in sorted(stats):
        print("  %-32s %d 条" % (k, stats[k]))

    if dropped:
        print("\n丢弃的 INSERT（按条数）：")
        for k in sorted(dropped, key=lambda x: -dropped[x]):
            print("  %-32s %d 条" % (k, dropped[k]))

    if args.verify:
        print("\n--- 自检 ---")
        src_tables = set(re.findall(r"^CREATE TABLE (\w+)", raw, re.M))
        dst_tables = set(re.findall(r"^CREATE TABLE (\w+)", body, re.M))
        print("表结构: 源 %d / 输出 %d  %s" %
              (len(src_tables), len(dst_tables),
               "OK" if src_tables == dst_tables else "不一致!"))
        if src_tables != dst_tables:
            return 1

        must = [
            ("mxk_userinfo", "'admin'"),
            ("mxk_institutions", "sso.maxkey.top"),
            ("mxk_cnf_password_policy", "minlength"),
            ("mxk_localization", "global.title"),
            # 适配器必须保留，否则管理端新建应用时下拉框为空
            ("mxk_apps_adapters", "Adapter"),
            # 用户组必须保留，否则登录后应用授权判定失效
            ("mxk_groups", "ROLE_ALL_USER"),
        ]
        ok = True
        for tbl, needle in must:
            hit = any(re.match(r"^INSERT INTO %s" % tbl, l) and needle in l
                      for l in body.split("\n"))
            print("种子 %-26s %s" % (tbl, "OK" if hit else "缺失!"))
            ok = ok and hit

        # 演示应用必须一条都不剩
        for t in ("mxk_apps", "mxk_apps_cas_details", "mxk_apps_oauth_client_details", "mxk_access"):
            n = sum(1 for l in body.split("\n") if re.match(r"^INSERT INTO %s\b" % t, l))
            print("演示数据 %-28s %d 条  %s" % (t, n, "OK" if n == 0 else "应为 0"))
            ok = ok and (n == 0)

        # 只允许 1 个用户
        n_user = sum(1 for l in body.split("\n") if re.match(r"^INSERT INTO mxk_userinfo", l))
        print("mxk_userinfo 行数          %d  %s" % (n_user, "OK" if n_user == 1 else "应为 1"))
        ok = ok and (n_user == 1)

        # 图片类 bytea 必须已清空；SAML 证书类允许保留（它是有效配置，不是图片）
        left_img = 0
        left_cert = 0
        for l in body.split("\n"):
            mm = re.match(r"^INSERT INTO (\w+)", l)
            if not mm or not BLOB_RE.search(l):
                continue
            if mm.group(1) in BLOB_COLUMNS:
                left_img += 1
            else:
                left_cert += 1
        print("图片类 bytea 残留         %d  %s" % (left_img, "OK" if left_img == 0 else "应清空"))
        print("证书类 bytea 保留         %d  (mxk_apps_saml_v20_details 的签名证书，正常)"
              % left_cert)
        ok = ok and (left_img == 0)

        print("\n%s" % ("自检通过。" if ok else "自检失败。"))
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
