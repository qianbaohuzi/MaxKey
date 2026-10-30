# MaxKey 裸机部署方案（KingbaseES + 内置精简 JDK + 公共 nginx）

> 配套脚本位于 `deployment/kylin/`。本文结论均来自实测，验证记录见 §17。
>
> 目标形态：**版本目录 + current 软链 + 内置 jlink 运行时 + 一份 nginx 站点文件**。
> 不依赖目标机 JDK，不要求 Docker，不动目标机已有的 nginx 站点。

---

## 1. 五个动词与三条铁律

运维只需要记住包根的五个脚本：

| 命令 | 什么时候用 | 会动什么 |
|------|-----------|---------|
| `sudo ./install.sh --profile <环境>` | 一台新机器首次落地 | 建用户、装 jre、装 unit、接 nginx、建库、启动 |
| `sudo ./upgrade.sh <新包>` | 日常换程序包 | 停服、备份、迁移、切软链、启动、健康检查 |
| `sudo ./rollback.sh --to <版本>` | 出问题退回去 | 切软链、还原配置（库需 `--restore-db`） |
| `sudo ./uninstall.sh` | 撤掉这台机器上的接入 | 分级：默认 / `--purge` / `--purge-all` |
| `sudo ./verify.sh` | 证明"真装好了/真卸干净了" | 只读，十项硬指征 |

**三条铁律**（都是踩过事故总结出来的）：

1. **首次安装与后续更新是两条路径，不混用。**
   已装过的机器再跑 `install.sh` 会直接拒绝 —— 重跑 install 会把
   nginx/unit/口令/建库全部再走一遍，任何一步"看起来没问题"都可能
   把运行中的环境改成半新半旧状态。
2. **配置升级永不覆盖，库永不自动删。**
   `conf/maxkey.env` 是现场资产（域名、数据库地址），升级只追加新增项；
   删库只能由人显式执行 `uninstall.sh --purge-all` 并输入库名确认。
3. **"看起来成功"不算成功。**
   每个动作结束都用 `verify.sh` 或健康检查给结论。
   `install.sh` 打印"已安装 xxx"只是它自己说自己成功。

### 1.1 最小化拓扑

```
浏览器 ──443──> 公共 nginx ──/maxkey/─────────> 静态文件  /opt/maxkey/current/web/maxkey
                   │         ──/maxkey-mgt/────> 静态文件  /opt/maxkey/current/web/maxkey-mgt
                   ├──/sign/──────────────> maxkey      127.0.0.1:9527  (认证中心)
                   └──/maxkey-mgt-api/────> maxkey_mgt  127.0.0.1:9526  (管理端 API)
                                                    │
                                                    └──> KingbaseES 54321
```

---

## 2. 目录布局：为什么是版本目录 + 软链

装完之后 `/opt/maxkey` 长这样：

```
/opt/maxkey/
├── current -> releases/4.2.0-a1b2c3d-20261030T101719    ← 原子切换点
├── releases/
│   ├── 4.2.0-9f8e7d6-20261029T233520/                   ← 保留最近 3 个
│   │   ├── maxkey/          portal jar + logs -> 共享日志
│   │   ├── maxkey_mgt/      管理端 jar + logs -> 共享日志
│   │   ├── web/             两个前端 dist
│   │   ├── bin/             maxkeyctl.sh / preflight.sh（随版本走）
│   │   ├── sql/             种子库 + migrations/ + lib/（迁移工具）
│   │   ├── lib/             common.sh / db.sh
│   │   ├── conf -> ../../conf
│   │   └── manifest.json    版本 / git sha / 构建时间
│   └── 4.2.0-a1b2c3d-20261030T101719/                   ← 当前运行
├── conf/maxkey.env          跨版本共享，升级永不覆盖
├── jre/                     跨版本共享的裁剪运行时（64MB，不每版一份）
├── logs/{portal,mgt}/       跨版本共享的日志
├── run/                     pid
└── backups/<时间戳>/        升级前的库 dump + 配置快照
```

**为什么不"就地覆盖"**：旧方案升级时直接覆盖 `/opt/maxkey/maxkey` 等目录，
覆盖完成那一刻旧代码就没了，回滚只能靠事先手工拷一份 —— 而人总会忘。
改成软链后，回滚就是把链接指回去：不做 400MB 拷贝、不重新构建、秒级完成。

**为什么 jre 共享而不随版本复制**：jre 与源码无关（64MB），
每个版本复制一份纯属浪费磁盘。JDK 升级时只改一处。

**为什么 unit 指向 `current/bin/`**：切版本只改软链，不需要改 unit、
也不需要 `daemon-reload`。verfiy.sh 会检查这一点，写死版本号会报错。

---

## 3. 快速开始

### 3.1 第一次装到一台新机器

```bash
tar xzf maxkey-deploy-<版本>.tar.gz && cd maxkey-deploy-<版本>

# 1. 改环境档案（只改"这台机器与别人不同"的项，不含口令）
vi env/test1.env
#      SERVER_DOMAIN / MAXKEY_PUBLIC_URL
#      NGINX_SERVER_NAME / NGINX_TLS_PORT / NGINX_CERT / NGINX_KEY
#      DATABASE_URL / DATABASE_USER

# 2. 演练（不需要 root）
sudo ./install.sh --profile test1 --dry-run

# 3. 真实落地：建用户、装文件、装 unit、接 nginx、启动
#    口令会在这一步交互询问（不回显、不进 shell 历史）
sudo ./install.sh --profile test1 --init-db

# 4. 证明装好了
sudo ./verify.sh --expect installed
```

`--init-db` 会导入种子库（44 张表 + admin 账号 + 管理端 CAS 应用），
并把库标记为 Flyway V1。已建过表的库会拒绝导入（需 `--import-seed`）。

浏览器打开 `https://<域名>/maxkey/`，初始账号 **admin / maxkey**
—— 上线前必须立即改密，并把「机构」的 domain 改成真实域名。

### 3.2 从旧布局（无版本目录）的机器过渡

```bash
sudo ./install.sh --profile <环境> --migrate-layout
```

会把 `maxkey/`、`maxkey_mgt/`、`web/` 移进 `releases/<当前版本>/`，
建 `current` 软链，并把存量日志搬进共享目录。**失败不会删旧目录**：
先复制、校验 jar 到位、再删。

### 3.3 日常更新（最常用）

```bash
# 本地打包（会自动带上 git sha 与构建时间，因此每次都是独立版本）
./deployment/kylin/build-package.sh

# 一条命令送过去并执行（推荐）
./deployment/kylin/release-remote.sh test1 upgrade

# 或在目标机上手工
tar xzf maxkey-deploy-<新版本>.tar.gz && cd maxkey-deploy-<新版本>
sudo ./upgrade.sh ../maxkey-deploy-<新版本>.tar.gz
```

`upgrade.sh` 做的事情，以及为什么这个顺序不能调：

```
1. 校验新包（manifest / 校验和 / 版本不得倒退）
2. 停两个服务 ─────────────── 迁移必须停服，否则 Flyway 与运行中的应用抢锁
3. 备份整库 + conf/nginx/unit ── 备份是回滚的唯一依据，跳过它等于放弃退路
4. 执行 Flyway 迁移 ─────────── 先把库改成新结构，再换代码
5. 落新 release 目录 ────────── 不改动任何现有 release（它们是回滚目标）
6. 切 current 软链 ──────────── 原子生效点
7. unit 变了才重装 + daemon-reload
8. 起服务 + 五项健康检查
9. 清理超出保留数的旧版本与旧备份
```

**为什么失败不自动回滚**：健康检查判据再全也可能误判（数据库抖动、
上游慢响应）。自动把线上代码换掉比"停下来让人看一眼"风险更大。
脚本会把回滚命令与备份路径打在一屏之内，`rollback.sh` 是一步到位的。

### 3.4 回滚

```bash
sudo ./rollback.sh --list                    # 看有哪些版本与备份
sudo ./rollback.sh --to <版本>                # 回代码 + conf + nginx + unit
sudo ./rollback.sh --last                    # 回到上一个版本
sudo ./rollback.sh --to <版本> --restore-db   # 连数据库一起回退（危险）
```

**默认不动数据库**：Flyway 是单向的（不回滚已应用的 migration），
还原会丢掉升级后新产生的数据（用户、应用配置、登录记录）。
只有"新版本改过表结构、旧代码跑不起来"时才需要 `--restore-db`。

**没有备份也能回**：脚本允许只回代码与配置，但会在最后一行醒目告警
"数据库未恢复" —— 不制造"看起来成功了"的假象。

### 3.5 卸载与验证闭环

```bash
# 分级：默认只摘服务接入；--purge 删程序与密钥；--purge-all 再删库
sudo ./uninstall.sh              # 停服 + 删 unit + 摘 nginx
sudo ./uninstall.sh --purge      # 再加：删 releases/jre/bin、删 /etc/maxkey、删用户
sudo ./uninstall.sh --purge-all  # 再加：DROP schema（需输入库名确认）

# 每一步都能证明
sudo ./verify.sh --expect removed
sudo ./install.sh --profile test1 --init-db && sudo ./verify.sh --expect installed
```

`--purge-all` 会**先** dump 一份到 `backups/` 再删，且删除密钥文件
放在**最后**（否则清库时连不上库 —— 这个顺序 bug 真实发生过）。

开发侧还有一键回归：

```bash
./deployment/kylin/verify-cycle.sh cycle                    # 装→卸→装
./deployment/kylin/verify-cycle.sh upgrade <旧包> <新包>      # 升级→回滚
```

---

## 4. 环境切换：到底要改哪些东西

换成另一台机器 / 另一个域名时，改动集中在四处，但**每一处的"漏改"都有特定症状**。
环境档案（`env/<名字>.env`）把前两组收进一个文件，第三、四组必须手工介入。

| # | 改什么 | 放哪里 | 漏改/改错的症状 |
|---|--------|--------|----------------|
| 1 | 域名、对外地址、端口 | `env/<环境>.env` | SSO 回跳失败；iss 缺端口导致登录成功即被踢回 |
| 2 | 证书路径 | 同上 | `nginx -t` 失败，或 reload 后 443 起不来 |
| 3 | 数据库地址与账号 | 同上（**口令不在这里**） | 连错库、连到 3306 |
| 4 | 库里与域名绑死的数据 | `bin/rebind-site.sh` | 点「后台」卡住；OAuth 回调不匹配；租户识别退回默认机构 |

`install.sh` 在落盘前会做一次**自洽性校验**，把"改漏但改不全"的情况提前拦下：
对外地址的主机/端口与 `NGINX_SERVER_NAME`/`NGINX_TLS_PORT` 是否一致、
证书是否存在且非空、`LOGIN_CAS_SERVICE` 是否由对外地址派生、
`DATABASE_URL` 含 `&` 是否用单引号包住。任何一项不自洽就中止，不写任何文件。

### 4.1 第 4 组：库里与域名绑死的数据

换域名不只是改配置。库里有一批**按旧域名生成的字符串**，其中几处是
"严格相等比对"，改不干净的症状极难查：

| 表.列 | 作用 | 不等的后果 |
|-------|------|-----------|
| `mxk_apps_cas_details.service` | 管理端 CAS 校验 | 点「后台」一直卡在登录页 |
| `mxk_apps.loginurl` / `logouturl` | 应用回跳地址 | 登录后跳回旧域名 |
| `mxk_apps_oauth_client_details.web_server_redirect_uri` | OAuth 回调 | 客户端报 `redirect_uri_mismatch` |
| `mxk_apps_oauth_client_details.issuer` | token 的 iss | 客户端校验 token 失败 |
| `mxk_institutions.domain` | 租户识别（按 Host 头匹配） | 退回默认机构，登录页标题/Logo 都不对 |

```bash
# 先预览（默认就是 dry-run，不改数据）
sudo ./bin/rebind-site.sh --old sso.old.com --new sso.new.com

# 确认后执行（会自动 dump 备份）
sudo ./bin/rebind-site.sh --old sso.old.com --new sso.new.com --apply

# 必须重启（应用启动时读配置）
sudo systemctl restart maxkey-portal maxkey-mgt
```

脚本是**幂等**的：只把含旧域名的行改成新域名，跑一次与跑十次结果相同。
它不做模糊匹配（那会误伤 description 里提到旧域名的文本），
只用 `REPLACE(列, 旧串, 新串)`。

### 4.2 换环境的完整顺序

```bash
# 1. 改环境档案
vi env/<新环境>.env

# 2. 把证书放到目标机
sudo mkdir -p /etc/nginx/cert
sudo cp sso.<新域名>.crt sso.<新域名>.key /etc/nginx/cert/
sudo chmod 640 /etc/nginx/cert/*.key

# 3. 装（含 --force-reinstall 时会把 nginx/conf 换成新值）
sudo ./install.sh --profile <新环境> --force-reinstall

# 4. 改库里与域名绑死的数据（仅当库是从旧环境拷来的）
sudo ./bin/rebind-site.sh --old <旧域名> --new <新域名> --apply

# 5. 重启并验证
sudo systemctl restart maxkey-portal maxkey-mgt
sudo ./verify.sh --expect installed
```

第 5 步之后**必须**做的验证：浏览器打开门户登录，点菜单「后台」，
应当**免密**进入管理端。这一步同时验证了 CAS service 一致性与
token 的 iss 一致性 —— 两个最容易配错的地方。

---

## 5. 更新包：谁能改、谁不能改

### 5.1 安装包与更新包是同一个产物

刻意不分两种包。原因是"包内容与脚本版本错配"这类事故极难发现：
一旦更新包里的 `upgrade.sh` 与安装包里的 `lib/common.sh` 版本不一致，
行为差异只在特定分支暴露。

### 5.2 一个版本 = 一次构建

版本号是 `4.2.0-<git 短 sha>-<构建时间戳>`，例如
`4.2.0-a1b2c3d-20261030T101719`。

为什么不用单纯的 `4.2.0`：改代码通常不改 `gradle.properties`，
于是同一个 `4.2.0` 会被反复打包。若 `releases/` 下按 `4.2.0` 命名，
新包会直接覆盖上一份 —— **恰好把可回滚的上一版抛掉**，而这正是本方案的核心价值。

`upgrade.sh` 会拒绝版本倒装（除非 `--allow-downgrade`）：
库里已迁移到 V3 而包只到 V2 时，旧代码配新表结构会报"列不存在"，
这类故障排查成本极高。

### 5.3 数据库变更：Flyway

```
sql/kingbase/
├── maxkey-seed.sql          种子库（V1 的实际内容，仅首次安装用）
└── migrations/
    ├── V2__verify_pipeline.sql
    └── V3__xxx.sql          以后每次改表新建一个，只增不改
```

**约定**（`migrations/README.md` 有完整版）：

- 文件名 `V<序号>__<英文短描述>.sql`，序号从 2 开始（V1 = 种子库）
- **已发布的文件不能修改**：Flyway 校验和不允许，改一个字节下次升级就失败
- 每个文件写成幂等（`IF NOT EXISTS`），便于演练库重放

**首次安装的衔接**：`install.sh --init-db` 建完 44 张表后，
`upgrade.sh`/`migrate.sh` 首次运行时 `baseline-on-migrate` 会把当前结构
标记为 V1，之后只跑 V2+。这样"种子库"与"增量迁移"两套机制不打架。

**单独跑迁移**（不想切版本、或 DBA 想先审 SQL）：

```bash
sudo ./bin/migrate.sh --info     # 列出已应用/待应用
sudo ./bin/migrate.sh            # 应用（会自动先 dump）
sudo ./bin/migrate.sh --baseline # 把当前结构标记为 V1（仅种子库建出来的库）
```

### 5.4 换包时"不需要改"的东西

这是本方案最省事的一点：以下内容升级时**完全不动**。

- `conf/maxkey.env`（只追加新版新增的键，值取模板默认）
- `/etc/maxkey/maxkey-secret.env`（数据库口令与 JWT 密钥）
- 数据库里的业务数据（迁移只改结构）
- `/etc/nginx/cert/` 下的证书
- 日志（跨版本共享，回滚后旧日志仍在）

---

## 6. 日志与运行时

### 6.1 日志集中

`log4j2.xml` 里写的是相对路径 `logs/maxkey.log`，所以日志落在
"进程的工作目录"。若每个 release 自带 logs，回滚后旧日志就"消失"了。

做法：release 内的 `<app>/logs` 是指向共享目录的**软链**。

```
/opt/maxkey/logs/
├── portal/   <- current/maxkey/logs（软链）
└── mgt/      <- current/maxkey_mgt/logs（软链）
```

于是"不改 jar 里的 log4j2.xml"与"日志跨版本共享"两件事同时成立。
systemd 的 `ReadWritePaths` 也只需授权这一个目录。

`/etc/logrotate.d/maxkey` 兜底处理 nohup 的 stdout（应用内 log4j2
已按天/128MB 轮转），保留 30 天。

### 6.2 健康检查的判据

`upgrade.sh` 与 `install.sh` 结束时跑五项检查，每项都对应一次真实故障：

| 判据 | 能发现的问题 |
|------|-------------|
| 两个后端端口在监听 | 进程活着但没 bind |
| 直连后端 OIDC 元数据返回 200 | 应用启动到一半（连库失败等） |
| 经 nginx 访问前端 200（`curl -k`） | 反代配错、证书链问题 |
| 经 nginx 访问管理端 200 | mgt 未起来 |
| 启动后日志无 ERROR 堆栈 | 起来但半残 |

直连与经 nginx **分开报**，失败时能一眼看出是哪一层的问题。

已知的一条"非故障 ERROR"被排除：Druid 的
`testWhileIdle is true, validationQuery not set`。它是配置提醒，
不影响功能。排除它的理由不是"它不重要"，而是**反复出现的假告警
会训练人忽略告警**，那比没有告警更危险。

---

## 7. 目标机前置条件与职责分工

### 7.1 谁做什么

把责任划清，避免"装到一半发现缺权限"。

| 事项 | 谁做 | 说明 |
|------|------|------|
| 装 nginx、KingbaseES 服务端与客户端工具 | 运维/DBA | `install.sh` 只检测不安装（缺了会明确报错） |
| 创建数据库 `maxkey` | DBA | 空库即可 |
| 创建账号 + 授权 | DBA | 见下方权限清单 |
| 把证书放到 `/etc/nginx/cert/` | 运维 | 自签或申请 |
| 建 44 张表 + 初始数据 | **`install.sh --init-db`** | 导入种子库，脚本自己做 |
| 填数据库口令 | **`install.sh` 交互询问** | 或预先放好密钥文件（见 §8） |
| 系统用户、systemd、nginx 站点、日志轮转 | **`install.sh`** | 脚本自己做 |

**账号所需权限**：

| 权限 | 用途 |
|------|------|
| `public` schema 上 `CREATE` | 建 44 张表、索引 |
| 表级 `SELECT/INSERT/UPDATE/DELETE` | 运行时增删改查 |
| 库上 `CONNECT` | 连接 |

若 DBA 给的是库 owner，以上全部满足。种子库开头有
`DROP TABLE IF EXISTS ... CASCADE`，需要相应 DROP 权限（owner 天然具备）。

> 自增主键用的是 `bigint GENERATED BY DEFAULT AS IDENTITY`（标识列），
> 序列由系统隐式管理，**不需要单独授予序列 USAGE**。

### 7.2 目标机（麒麟 V10）与开发机的差异

这些差异是实际连上目标机探测出来的，不理解就会踩坑：

| 项目 | 开发机（Ubuntu） | 麒麟 V10 | 影响 |
|------|-----------------|---------|------|
| glibc | 2.39 | **2.28** | 必须用 Temurin 构建的 jre（基线 2.15），系统 JDK 不行 |
| 系统 JDK | 21 | **可能只有 8**（BiSheng） | 直接用会 `UnsupportedClassVersionError`，**必须**随包带 jre |
| nginx | 80/443 常被占 | 80 常被其它站点占用 | MaxKey 用独立 `server_name`，端口可配 |
| 证书目录 | 已存在 | **`/etc/nginx/cert` 可能不存在** | 需先 `mkdir -p` |
| logrotate / rsync | 有 | **最小化安装常常没有** | 分级处理：logrotate 缺失只告警并跳过；rsync 缺失时远程传输自动回退 `ssh + tar` |
| 磁盘 | — | 需 ≥ 2GB（1 个版本 414MB + 备份） | 空间不足时 `upgrade.sh` 在 dump 前报错 |

`install.sh` 对非麒麟系统**只告警不拦** —— 拦住会让开发机无法做回归验证；
真正的不兼容（架构、glibc）由 `preflight.sh` 检测。

### 7.3 目标机自检

装之前可以先跑一次，一次性暴露所有阻塞项：

```bash
./bin/preflight.sh
```

检查项：操作系统与架构、glibc 基线、jre 可执行性与架构匹配、
JDK 21 可用性、AWT 字体（验证码依赖）、配置语法与占位值、
数据库连通性与表数量、端口占用、nginx 状态与 SELinux/firewalld、
目录权限与软链完整性、`/etc/maxkey/maxkey-secret.env` 的权限与必填键。

---

## 8. 环境档案

`env/<名字>.env` 只写"这台机器与别人不同"的项，不含任何口令。
`install.sh` 把它覆盖到 `conf/maxkey.env` 模板的同名键上，
未列出的项取模板默认值（模板里有逐项注释，现场可继续手改）。

```bash
# 新增一个环境：复制 + 改四处
cp env/dev-local.env env/prod.env
vi env/prod.env     # SERVER_DOMAIN / MAXKEY_PUBLIC_URL / NGINX_* / DATABASE_URL
```

`env/test1.env` 里全是 `example.gov.cn` 占位值 —— `install.sh` 会因
占位域名直接拒绝安装。这是刻意的：避免"忘了改域名就装上去"。

**口令不在这里**。它只存在于目标机的 `/etc/maxkey/maxkey-secret.env`：

```
DATABASE_PWD='实际口令'
JWT_SECRET='512 字符随机串'
```

- 权限 `600 root:root`，不进包、不入库
- `install.sh` 首次生成 `JWT_SECRET`；升级时沿用旧值
  （否则所有已登录会话立即失效）
- 非交互环境（CI/自动化）必须先预置该文件，脚本会明确报错并给出命令

---

## 9. 从本地到服务器

```bash
# 注册目标机（写到 .remote-targets，已 gitignore；内网地址不入库）
./deployment/kylin/release-remote.sh --add test1 \
    --host 10.0.0.11 --user root --dir /root/maxkey-release

# 日常更新（rsync 增量；目标机无 rsync 时自动回退 ssh+tar 管道）
./deployment/kylin/release-remote.sh test1 upgrade

# 首次安装
./deployment/kylin/release-remote.sh test1 install --profile test1 --init-db

# 只看将要执行什么
./deployment/kylin/release-remote.sh test1 upgrade --dry-run
```

传输后会比对**字节数**：400MB 的包传一半断掉，解压时才报错，
而那时已经覆盖了一部分文件 —— 提前比对能拦住。

---

## 10. 内置 JDK：为什么必须裁，怎么裁，怎么防被顶掉

### 9.1 硬约束

MaxKey 4.2.0 编译目标是 Java 21（`build.gradle` 里
`sourceCompatibility/targetCompatibility = VERSION_21`，且低于 21 直接抛
`GradleException`）。jar 内 class 文件 major 版本 65。

多数信创环境的系统 JDK 是 8/11/17，直接用会抛
`UnsupportedClassVersionError`。而"让现场先装个 JDK 21"在内网往往做不到。

### 9.2 方案对比

| 方案 | 体积 | 问题 |
|------|------|------|
| A. 要求现场装 JDK 21 | 0 | 信创内网常无源；且要改动目标机 |
| B. 包内放完整 JDK | ~300MB | 2/3 的模块用不到 |
| **C. 包内放 jlink 裁剪运行时** | **59MB** | 与 CPU 架构绑定；glibc 基线取决于构建所用 JDK（见 §10.3） |

采用 C。

### 9.3 glibc 基线：不必在麒麟上构建

glibc 是向后兼容的：低 glibc 上构建 → 可在高 glibc 运行；反之不行。

实测对比（同一台 Ubuntu 24.04、同一条 jlink 命令）：

| JDK 来源 | `libjvm.so` 要求 | 能否在麒麟 V10(2.28) 运行 |
|---------|-----------------|--------------------------|
| Ubuntu 自带 openjdk-21 | `GLIBC_2.38` | 不能 |
| **Adoptium Temurin 21** | **`GLIBC_2.15`** | **能** |

差异完全来自 JDK 发行版本身（系统打包版会针对当前发行版重新链接）。
所以真正要控制的是"用哪个 JDK 构建"，不是"在哪台机器构建"。

`bin/make-runtime.sh --download` 会取**固定版本** Temurin 并校验 sha256：

| 项目 | 值 |
|------|-----|
| 版本 | `21.0.13+9`（Temurin LTS，实测该 tag 可下载） |
| x64 sha256 | `d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c` |
| aarch64 sha256 | `e3522e707fc7dbe2a72c30746b1e7068301a0213ecd213d4491f35a14eb55578` |

不用 `latest` 的原因：`latest` 会随时间漂移，同一提交在不同月份构建出的包
不一致，不可复现；且没有 sha256 就无法确认下到的是官方产物。

缓存两级（实测二次构建 4 秒，首次 91 秒）：
`$TEMURIN_CACHE` > `<包根>/.cache/temurin` > `~/.cache/temurin`。

### 9.4 内置运行时如何不被目标机 JDK 顶掉

`maxkeyctl.sh` 的 `find_java()` 探测顺序（**顺序是刻意的**）：

```
0) MAXKEY_JAVA            显式强制（排障用）
1) <包根>/jre/bin/java    ← 内置运行时优先
2) JAVA_HOME
3) /usr/lib/jvm/*21* /opt/jdk-21* ...
4) PATH 中的 java
```

内置运行时排第一，因为本方案要解决的正是"目标机 Java 版本不可控"。
若让 `JAVA_HOME`/`PATH` 优先，目标机上一个残缺 JDK 就会顶掉内置运行时，
打包内置 JDK 的努力全部作废，而失败现象会变成难以归因的
`UnsupportedClassVersionError`。

需要强制用外部 JDK 时：`MAXKEY_JAVA=/path/to/java ./bin/maxkeyctl.sh start`
或删掉 `jre/` 目录。

### 9.5 模块清单与运行时自检

模块清单不是凭经验敲的，而是对 fat jar 做静态分析：

```bash
unzip -q maxkey-boot-4.2.0-ga.jar 'BOOT-INF/lib/*.jar' 'BOOT-INF/classes/*'
jdeps --print-module-deps --multi-release 21 \
      --class-path "BOOT-INF/lib/*" BOOT-INF/classes
```

在此基础上做了两处**实测修正**（不能省）：

1. **必须保留 `java.desktop`**
   验证码走 `java.awt.image.BufferedImage`，二维码同理。
   去掉后启动即失败：`NoClassDefFoundError: java/beans/PropertyChangeEvent`
   （`java.beans` 在 `java.desktop` 里）。
   代价是它依赖系统字体；已实测 headless 下验证码 PNG 正常输出。

2. **可以去掉 `jdk.attach` / `jdk.jdi` / `jdk.jfr`**
   jdeps 因间接引用报出，但实测启动与登录都不需要，省约 20MB。

另外补齐几个 jdeps **看不到**的模块（通过反射/SPI 在运行期加载）：

| 模块 | 为什么需要 |
|------|-----------|
| `java.sql` `java.transaction.xa` | JDBC 驱动、连接池 |
| `java.naming` | LDAP / JNDI（同步器） |
| `java.management` | JMX、Druid 监控 |
| `java.security.sasl` `java.security.jgss` | SCRAM 认证、Kerberos |
| `jdk.crypto.ec` | TLS 椭圆曲线套件 |
| `jdk.charsets` `jdk.localedata` | GB18030/GBK 与中文（`--include-locales=zh,en`） |
| `jdk.zipfs` | 嵌套 jar 读取（Spring Boot 的 FileSystemProvider） |

**运行时自检**：`maxkeyctl.sh start` 在启动前用待启动的那个 java 跑一段
探针，引用 `java.desktop / java.sql / java.naming / java.management /
java.security.jgss / java.prefs`。缺模块时直接给出结论，例如实测输出：

```
ERROR: 内置运行时自检未通过 —— jlink 裁剪的 jre 缺少必需模块。
       运行时: /tmp/sctest/jre/bin/java
       缺失线索:
         Exception in thread "main" java.lang.NoClassDefFoundError: java/awt/image/BufferedImage
       判定: 缺 java.desktop（验证码/二维码渲染必须，去掉会导致登录页崩溃）。
       修复: ./bin/make-runtime.sh --download
```

为什么值得加这一步：缺模块的报错是 `ClassNotFoundException` /
`NoClassDefFoundError`，堆栈很深且指向的不是真正的缺失点；而且实测这类异常
**只在渲染验证码时才触发** —— 服务已经"启动成功"、运维以为没事了，
等用户第一次打开登录页才炸。

> 实现注意：自检**不能**用 `java Probe.java` 单文件源码模式。
> 那依赖 `jdk.compiler`，而裁剪掉的运行时正好没有，会先报
> `Module jdk.compiler not in boot Layer`，把真正缺失的模块信息盖掉。
> 所以用 `javac` 预编译成 `.class` 再用 `-cp` 运行。

---

## 11. 前端：纯静态，不需要 Node

两个 Angular 应用构建产物是 `dist/browser`，由 nginx 直接托管。

| 前端 | base-href | 访问地址 | 托管方 |
|------|-----------|---------|--------|
| portal | `/maxkey/` | `https://<域>/maxkey/#/passport/login` | nginx 静态 |
| 管理端 | `/maxkey-mgt/` | `https://<域>/maxkey-mgt/` | nginx 静态 |
| portal API | — | `/sign/` → 9527 | `maxkey` jar |
| 管理端 API | — | `/maxkey-mgt-api/` → 9526 | `maxkey_mgt` jar |

三个要点：

* **前端不在任何 jar 里**。`maxkey-starter-web-static` 只有
  `favicon.ico` 和 jquery，`index.html` 数量为 0。所以 nginx 托管是唯一方式。
* **API 用同源相对路径**。`environment.prod.ts` 里 `baseUrl` 是
  `/sign/` 与 `/maxkey-mgt-api/`，因此 nginx 单入口即可，**不需要 CORS**。
* 路由是 **hash 模式**（`useHash: true`），`#...` 不会发到服务端；
  但直接粘贴的无 hash 深链接仍需要 SPA 回退到 `index.html`。

构建（构建机执行，需 node 22.23.2 + pnpm）：

```bash
cd maxkey-web-frontend/maxkey-web-ng
pnpm install --frozen-lockfile && pnpm run build:prod   # --base-href /maxkey/

cd ../maxkey-web-mgt-ng
pnpm install --frozen-lockfile && pnpm run build:prod   # --base-href /maxkey-mgt/
```

两个前端的 `pnpm-lock.yaml` 已入库。版本口径固定为
**node 22.23.2 / pnpm 12.6.0**（Angular 22.2.0 的 engines 是
`^22.22.3 || ^24.15.0 || >=26.0.0`，24.14.0 不满足）。

> **必须通过 corepack 调用 pnpm**，不要直接用 PATH 上的 `pnpm`。
> 实测：用 pnpm 11.10.0 执行 `install --frozen-lockfile` 不会报错，
> 而是**静默改写 `pnpm-lock.yaml`**（补 `@pnpm/exe` 等条目）。
> `--frozen-lockfile` 只保证"不改依赖版本"，不保证"不重写文件格式"。
>
> `build-package.sh` 已对此加保护：构建前后比对 lockfile 校验和，
> 被改写就报错退出。若需手工构建，用
> `corepack pnpm install --frozen-lockfile`。
>
> 另：`$HOME` 不可写时 corepack 会因 `EACCES mkdir ~/.cache/node/corepack`
> 直接崩；脚本会自动把 `COREPACK_HOME` 指到仓库内 `.cache/corepack`。

---

## 12. nginx：接进公共实例，不影响其他应用

### 11.1 设计取舍

目标机 nginx 是公共的，本机实测 80 端口已被另一个站点占用
（`listen 80; server_name localhost;`）。三种做法里选第三种：

| 做法 | 问题 |
|------|------|
| 另起一个 nginx 实例 | 多一个进程、多一套配置要维护 |
| 往别人的 `server{}` 里塞 location | Cookie 作用域与对方重叠；对方改配置会牵连 MaxKey |
| **新增独立 server 块（conf.d 一个文件）** | **选用**。隔离干净，升级只替换自己的文件 |

具体形态：`conf.d/maxkey.conf` + `/etc/nginx/maxkey-proxy.conf`，
共 2 个文件，**不触碰任何已有站点文件**。

### 11.2 安装位置

```
/etc/nginx/conf.d/maxkey.conf      ← 站点配置（server 块）
/etc/nginx/maxkey-proxy.conf       ← 反代公共头（被两个 location include）
```

`install.sh` 自动完成渲染与校验；手工安装时：

```bash
cp nginx/maxkey-site.conf /etc/nginx/conf.d/maxkey.conf
cp nginx/maxkey-proxy.conf /etc/nginx/maxkey-proxy.conf
nginx -t && nginx -s reload
```

### 11.3 四个必须避开的坑（都是实测出来的）

**坑 1：不能用 `alias` + `try_files`**

```nginx
location /maxkey/ {
    alias /opt/maxkey/web/maxkey/;
    try_files $uri $uri/ /maxkey/index.html;   # 错
}
```

实测表现：`/maxkey/` 返回 200，但**深链接和 assets 全部 404**。
nginx 的 `alias` 与 `try_files` 组合有已知缺陷。

正确写法是用 `root`，让 URI 前缀自然映射到子目录：

```nginx
location /maxkey/ {
    root /opt/maxkey/web;        # 指向父目录
    try_files $uri $uri/ /maxkey/index.html;
}
```

`root` + URI `/maxkey/x.js` = `/opt/maxkey/web/maxkey/x.js`，
子目录名恰好等于 URI 前缀，因此不需要 `alias`。

**坑 2：静态资源缺失必须真 404**

```nginx
location ^~ /maxkey/assets/ {
    root /opt/maxkey/web;
    try_files $uri =404;         # 不是 /maxkey/index.html
}
```

若回退到 `index.html`，浏览器会把 `.js` 当 `text/html` 解析，报
`Unsupported MIME type` / `Unexpected token '<'`，排查成本极高。
`^~` 前缀保证它优先于后面的 SPA 回退。

**坑 3：`proxy_pass` 尾部斜杠不能漏**

```nginx
location /sign/ {
    proxy_pass http://127.0.0.1:9527/sign/;   # 必须有尾斜杠和 /sign
}
```

后端 context-path 是 `/sign`。写成 `proxy_pass http://127.0.0.1:9527;`
会丢路径前缀，所有 API 404。

**坑 4：不要重复声明同 `server_name` + 同端口的 80 站点**

两个同名 server 会让 nginx 报 `conflicting server name`，
且**实际生效的是先加载的那个** —— 表现为"改了配置但不生效"。
`install.sh` 会在安装前扫描 `conf.d`，命中冲突直接中止（实测在本机
正确命中了已有的 `sso-sso.lottery-dev.com.conf`）。

需要"80 跳 443"时，在**已有的**那个 80 server 里加 `return 301`，
不要在 MaxKey 的站点文件里新建同名 server。

### 11.4 反代必须带的头

见 `nginx/maxkey-proxy.conf`。其中三个不是锦上添花而是功能必需：

* **`Host`** —— 后端 `WebInstRequestFilter` 用 Host 头（或 `hostname` 头）
  查租户（机构）。丢了域名，多租户全部退回默认租户。
* **`X-Forwarded-Proto` / `X-Forwarded-Port`** —— 后端
  `server.forward-headers-strategy=NATIVE` 靠它们还原对外 scheme/port。
  不传会让 OIDC 元数据里出现 `http://127.0.0.1:9527/sign` 这类内网地址。
* **`proxy_redirect off`** —— SSO 回跳全靠 `Location`，
  不能让 nginx 改写。

实测对比（同一后端，只改请求头）：

```
无 X-Forwarded-*          → authorization_endpoint = http://127.0.0.1:9527/sign/...
带 X-Forwarded-Proto/Port → authorization_endpoint = https://sso.<域>:<端口>/sign/...
```

### 11.5 HTTPS 与证书

站点配置默认监听 443 + TLS 1.2/1.3，证书路径由 `conf/maxkey.env` 的
`NGINX_CERT` / `NGINX_KEY` 指定（指向**现场已有证书**，不复制私钥副本，
轮换时只改一处）。

`install.sh` 会校验 `MAXKEY_PUBLIC_URL` 的 host 与 port 同
`NGINX_SERVER_NAME` / `NGINX_TLS_PORT` 一致，不一致直接拒绝安装。

**端口选择的一个现实约束（WSL 环境实测）**：

443 在不少环境已被占用，且 WSL 下往往是 **Windows 侧端口转发**占的 ——
此时 Linux 里 `ss -lntp` 看不到占用者，但 nginx `bind()` 就是失败。
遇到这种情况直接换端口（例如 9443），并把 `MAXKEY_PUBLIC_URL` 同步改成
带端口的形式（`https://<域>:9443`）。两者必须一起改，否则 JWT 的 iss
与 OIDC issuer 会不一致。

**curl 排查时的代理陷阱**：如果环境里设了 `http_proxy/https_proxy`，
`curl` 可能把请求发到代理而不是本机 nginx，表现为连接失败或超时，
而浏览器却完全正常。排查时加 `--noproxy '*'`，或先 `unset` 代理变量。

---

## 13. 对外地址：`MAXKEY_PUBLIC_URL` 是唯一入口

这是整套配置里最容易搞错、也最容易出"能登录但立刻掉线"的地方。

后端有**两处**需要"对外地址"，但取法完全不同：

| 用途 | 取值方式 | 可否请求推导 |
|------|---------|-------------|
| JWT 的 `iss`（`maxkey.auth.jwt.issuer` ← `maxkey.server.uri`） | **固定配置值** | **不能** |
| OIDC 元数据 `issuer` / 各 `*_endpoint` | 由当前请求推导 | 必须（见 §13.2） |

### 12.1 JWT 的 iss 必须是固定值

`JwtLoginService.jwtTokenValidation()` 对 iss 做的是
`jwtClaimsSet.getIssuer().equals(getIssuer())` —— **严格相等**比对
（源码第 91 行）。签发（`AuthTokenService`）与校验必须取同一个值。

若让它随请求 Host 推导，同一实例经不同入口访问就会签出不同 iss，
token 互不认，表现为"登录成功但立刻被踢回登录页"。

历史实现的错误在这里：`maxkey.server.uri` 原为

```
${maxkey.server.name}:${server.port}${server.servlet.context-path}
```

把**内部端口 9527** 拼进了对外 URL。放在 nginx 后面时签出的 iss 是
`http://sso.<域>:9527/sign`，浏览器的实际 origin 却是
`https://sso.<域>/sign`，两边不一致 → token 判定无效。

现在改为：

```
maxkey.public.url = ${MAXKEY_PUBLIC_URL:http://sso.${SERVER_DOMAIN}}
maxkey.server.uri = ${maxkey.public.url}/sign           # portal
maxkey.server.uri = ${maxkey.public.url}/maxkey-mgt-api # mgt
```

> 键名**故意不叫** `MAXKEY_PUBLIC_URL`。若键名与占位符同名，
> 就是 `MAXKEY_PUBLIC_URL=${MAXKEY_PUBLIC_URL:...}` 自引用，
> Spring 的占位符解析会陷入循环引用。

### 12.2 OIDC 元数据必须按请求推导

OIDC 元数据由 `WebContext.getContextPath(true)` 生成，内部走
`UrlUtils.buildFullRequestUrl(request)`，取的是**当前请求**的
scheme/port/host。

因此后端开了 `server.forward-headers-strategy=NATIVE`
（Tomcat `RemoteIpValve`），配合 nginx 传 `X-Forwarded-*`。

选 `NATIVE` 而非 `FRAMEWORK`：前者在连接器层生效，
`getScheme()`/`getServerPort()`/`getRemoteAddr()` 三者都正确；
后者是 Servlet Filter，覆盖范围取决于 filter 顺序，更容易漏。

顺带修好第三个问题：登录日志里的客户端 IP 不再全是 `127.0.0.1`。

### 12.3 两处必须一致

| 配置 | 决定什么 | 必须等于 |
|------|---------|---------|
| `MAXKEY_PUBLIC_URL` | JWT iss、登录页/门户跳转、登出回跳 | 浏览器实际访问的根地址 |
| nginx `server_name` + `listen` | OIDC 元数据推导 | 同上 |

实测两者一致时：JWT 的 iss 是
`https://sso.lottery-dev.com:9443/sign`，
OIDC issuer 是 `https://sso.lottery-dev.com:9443/sign/maxkey`，同源同端口。

### 12.4 迁移到不同端口/协议

`MAXKEY_PUBLIC_URL` 是纯配置项，改完重启即可，**不需要重新打包**：

```bash
# 例如从 9443 迁到标准 443
vi /opt/maxkey/conf/maxkey.env
#   MAXKEY_PUBLIC_URL=https://sso.example.gov.cn
#   NGINX_TLS_PORT=443
sudo ./install.sh          # 重新渲染 nginx 站点配置
sudo ./bin/maxkeyctl.sh restart
```

---

## 14. 域名在本项目里的三个作用

域名不只是"访问地址"，改错会引发三类互不相关的故障：

### 13.1 租户（机构）识别

`WebInstRequestFilter` 用 `Host` 头（优先 `hostname` 头）查
`mxk_institutions.domain`：

```java
String host = request.getHeader("hostname");
if (isEmpty(host)) host = request.getHeader("host");
if (isEmpty(host)) host = applicationConfig.getDomainName();
if (host.indexOf(":") > -1) host = host.split(":")[0];
Institutions institution = institutionsService.get(host);
```

域名对不上会**静默退回默认租户**，表现为"登录后看到别人的机构"。
实测：

```
Host: sso.maxkey.top      → domain 返回 sso.maxkey.top（命中）
Host: sso.lottery-dev.com → 仍返回 sso.maxkey.top（未命中，回落）
```

所以上线后必须把「机构」的 domain 改成真实域名。

### 13.2 SSO 回跳地址拼接

`SingleSignOnInterceptor` 未登录时跳：

```
<maxkey.server.frontend.uri>/#/passport/login?redirect_uri=<base64(当前URL)>
```

`frontend.uri` 是相对路径（`/maxkey`），跟着当前 Host 走；
但 OIDC/OAuth 的 issuer、`authorization_endpoint` 走的是
`WebContext.getContextPath()`，依赖 §13.2 的请求推导。
两者任一错位都会让回跳地址不可达。

### 13.3 Cookie 域

会话 Cookie 绑定当前域名。跨域名回跳会丢登录态。

---

## 15. 数据库：KingbaseES

### 14.1 实测环境

| 项目 | 值 |
|------|-----|
| 版本 | **KingbaseES V009R003C018**（`server_version` 报 12.1，PG 兼容） |
| 端口 | 54321 |
| 库/账号 | `maxkey` / `maxkey` |
| 表数 | 44 张 `mxk_*` |

### 14.2 建库脚本：为什么是 0.4MB 而不是 19MB

`sql/kingbase/maxkey.sql` 是 44 表 / 3219 条 INSERT / 18.9MB 的演示数据全量版。

**裁剪维度必须按字节，不能按行数** —— 这是本次最重要的一条实测结论：

| 表 | 体积 | 行数 | 平均 |
|----|------|------|------|
| `mxk_userinfo` | 16693 KB | 60 | **278 KB/行**（每条内嵌 PNG 头像） |
| `mxk_apps` | 1508 KB | 34 | **44 KB/行**（每个应用内嵌 PNG 图标） |
| `mxk_history_login_apps` | 345 KB | **1219** | 0.3 KB/行 |
| `mxk_permission` | 123 KB | 453 | 0.3 KB/行 |

按行数裁掉 2290 条日志只能省 0.7MB（压缩比 96%，几乎没效果）；
体积全在 60 个演示用户的头像和 34 个演示应用的图标里。

`sql/kingbase/make-seed.py` 做字节感知裁剪：

* 表结构**完全保留**（44 表、索引、约束、注释、序列一个不少）
* `mxk_userinfo` 只留 admin
* 图片类 bytea 置 `NULL`（`mxk_apps.icon` / `mxk_userinfo.picture`）
* **保留** `mxk_apps_saml_v20_details` 的签名证书
  （那是有效配置，不是图片，约 56KB）
* **保留管理端自身这一个 CAS 应用**（`mxk_apps` / `mxk_apps_cas_details` /
  `mxk_access` 各 1 行），地址按 `MAXKEY_PUBLIC_URL` 生成，见 9.3.1

结果：**18.9MB → 0.4MB（2.1%）**。`--verify` 可自检结构与关键种子行。

### 14.3 保留哪些表：依据是"登录链路会读它"

不是"有数据就留"。踩过一个真实故障：最初把 `mxk_groups` /
`mxk_group_member` 裁掉了，结果**能登录、门户却返回 0 个应用**，
访问 authorize 被 `SingleSignOnInterceptor` 判为无权限，
302 到 `/sign/authz/refused`。

根因在 `AppsMapper.queryMyApps` 的 SQL：

```sql
select distinct app.* from mxk_apps app, mxk_access p, mxk_groups g
where app.id = p.appid and p.groupid = g.id
  and app.instid=? and p.instid=? and g.instid=?
  and app.visible != 0
  and g.id in (
      select id from mxk_groups where groupcode = 'ROLE_ALL_USER'
      union
      select gm.groupid from mxk_group_member gm, mxk_userinfo u
      where gm.memberid = u.id and u.username = ?)
```

没有 `ROLE_ALL_USER` 组 + admin 的成员记录 + `mxk_access` 授权行，
应用列表就是空。故这三张表必须保留，且 `group_member` 只留 admin 的行
（6 行，含关键的 `ROLE_ALL_USER_1`）。

`mxk_apps_oauth_client_details` 也必须保留，否则授权时报
`NoSuchClientException`。

### 14.3.1 管理端自身也是一个应用（踩过的坑）

「演示应用全部不导入」这个决定有个例外：**管理端自己**就是一条 CAS 应用。

门户菜单「后台」→ 前端 `/authz/mgt` → `window.location` 跳
`/sign/authz/maxkey_mgt`，而后端把 `maxkey_mgt` 这个字面量换成
**硬编码 ID**：

```java
// AppsServiceImpl
public static final String MGT_APP_ID = "622076759805923328";
```

这条应用一旦不存在，`AppsServiceImpl.get()` 拿到 `null` 后仍执行
`detailsCacheStore.put(appId, null)`，Caffeine 拒绝 null → NPE，
浏览器里看到的就是 `{"code":2,"data":null,"message":null}`。

所以种子库固定生成这三行：

| 表 | 内容 |
|----|------|
| `mxk_apps` | `protocol=CAS`，`adapterid=622227747946762291`（CAS 默认适配器） |
| `mxk_apps_cas_details` | `service` = `callbackurl` = `${MAXKEY_PUBLIC_URL}/maxkey-mgt/#/passport/trust/auth` |
| `mxk_access` | `ROLE_ADMINISTRATORS → 622076759805923328` |

三个容易错的地方：

1. **地址不能抄 dump**。官方 dump 里是 `http://mgt.maxkey.top/maxkey-mgt`，
   指向公网演示站点，现场点进去必然失败。
2. **`callbackurl` 必须带 `#`**。管理端前端是 `useHash: true`，
   `TrustAuthComponent` 从 `queryParams` 读 ticket，少了 `#/` 就读不到。
3. **`adapterid` 不能抄 dump**。dump 里这行写的是 `622227747946762290`，
   那是「OAuth 2.0默认适配器」的 ID，与 `protocol=CAS` 矛盾——
   上游数据的串行错误。CAS 应用应指向 `622227747946762291`。

`install.sh --init-db` 会把种子里的默认地址（`https://sso.maxkey.top`）
替换成现场 `MAXKEY_PUBLIC_URL` 后再导入；也可以直接
`make-seed.py --public-url https://your.host:9443` 生成。

### 14.3.2 管理端侧的两个 CAS 地址

`conf/maxkey.env` 里有两个**不同**的地址，混用会导致点「后台」失败：

```bash
# 管理端去哪个地址校验 ticket
LOGIN_CAS_SERVER="http://127.0.0.1:${PORTAL_PORT:-9527}/sign/authz/cas"
# 管理端自己声明的 service，必须与 mxk_apps_cas_details.service 完全相等
LOGIN_CAS_SERVICE="${MAXKEY_PUBLIC_URL}/maxkey-mgt/#/passport/trust/auth"
```

* `LOGIN_CAS_SERVER` 的上游默认值是 `http://sso.maxkey.top/sign/authz/cas`
  （公网演示环境）。不改就会把 ticket 发到外网。
* 改成对外 HTTPS 地址**同样不行**：现场证书多为自签，JVM 的 `cacerts`
  里没有它，`cas-client` 直连会抛
  `SSLHandshakeException: PKIX path building failed`（已实测确认）。
  因此校验走本机 HTTP 端口，不经 nginx。
* `LOGIN_CAS_SERVICE` 必须是对外 HTTPS 地址：ticket 绑定 service 签发，
  `serviceValidate` 会与库里的 `service` 做**字符串严格相等**比对。

`maxkeyctl.sh` 对这两个值做了兜底：若 `MAXKEY_PUBLIC_URL` 在 conf 里留空、
靠 `SERVER_DOMAIN` 推导，`LOGIN_CAS_SERVICE` 会在 source 时展开成残缺值，
脚本检测到不是 `http(s)://` 开头就按派生后的对外地址重建。

### 14.4 关键配置项

`conf/maxkey.env`：

```bash
DATABASE_DRIVER=com.kingbase8.Driver
DATABASE_URL='jdbc:kingbase8://127.0.0.1:54321/maxkey?characterEncoding=UTF-8&useUnicode=true'
DATABASE_USER=maxkey
# 口令不写入本文件，由 /etc/maxkey/maxkey-secret.env 注入
DATABASE_DIALECT=kingbase
DATABASE_COLUMN_ESCAPE=true
DATABASE_COLUMN_ESCAPE_CHAR='"'
```

三个易错点（都已在 `maxkeyctl.sh` 里做启动前校验）：

1. **JDBC URL 必须用单引号包**。裸写会让 bash 把 `&` 当后台分隔符，
   `DATABASE_URL` 变空、后半截被当命令执行，最终应用**静默回落到
   内置 MySQL 默认值**，症状是"配了 Kingbase 却连 3306"。
2. **`DATABASE_PWD` 为空会拒绝启动**。Spring 7 的行为是：变量
   **不存在**才回落默认值；变量存在但为**空串**时，`${DATABASE_PWD:maxkey}`
   解析结果就是空串。所以空口令会直接连库失败而不是"悄悄用默认口令"。
3. **KingbaseES 在 MySQL 兼容模式下 `online` 是保留字**，必须开
   `DATABASE_COLUMN_ESCAPE=true` 且转义符用 `"`。

---

## 16. SSO 最小化：只保留什么

### 15.1 必须启动

| 组件 | 端口 | 作用 | 能否省 |
|------|------|------|--------|
| `maxkey` | 9527 | 认证中心：登录、发 token、OAuth/CAS/SAML/OIDC 端点 | **不能** |
| `maxkey_mgt` | 9526 | 管理端：应用/用户/机构配置 | **不能**（否则无法配置应用接入） |
| nginx | 443 | 静态前端 + 反代 | **不能**（前端是纯静态） |
| KingbaseES | 54321 | 数据库 | **不能** |

### 15.2 不启动

| 组件 | 端口 | 说明 |
|------|------|------|
| `maxkey-web-openapi` | 9525 | 只有 1 个 OTP 校验 controller，SSO 核心链路不依赖。已从构建中移除（源码保留） |
| `maxkey-gataway` | 9000 | **已删除**。没有 Spring Boot 插件、依赖全注释，构建不出可运行构件 |
| Redis | 6379 | 默认 `SERVER_PERSISTENCE=0` 即内存会话，单实例够用 |
| Nacos / RocketMQ | - | 非 SSO 必需 |

> Redis 的取舍：`maxkey.server.persistence` 默认 `0`（内存 Caffeine）。
> 会话在 JVM 内存里，**重启会丢登录态**，且不支持多实例。
> 要横向扩展再切 `2`（Redis），当前最小化不需要。

### 15.3 建议关闭的功能

```bash
LOGIN_CAPTCHA=false        # 内网首次联调可关；生产建议 true
LOGIN_MFA_ENABLED=false    # 无短信/邮箱通道时关掉 TOTP
```

### 15.4 单点登录闭环的最短路径

1. 启动 `maxkey` + `maxkey_mgt` + nginx
2. 登录管理端 → 配置「机构」domain（与 nginx `server_name` 一致）
3. 配置「应用」→ 选协议（OAuth2/OIDC/CAS/SAML）→ 填回调地址
4. 业务系统按所选协议接入
5. 用户访问业务系统 → 未登录 → 302 到 `/maxkey/#/passport/login` → 登录 → 回跳

第 3 步的回调地址必须与后端生成的 issuer 对得上，
否则 OAuth 会报 `redirect_uri mismatch`。这是最常见的接入故障。

> 注意：每个 OAuth client 在 `mxk_apps_oauth_client_details` 里有独立的
> `issuer` / `audience` 字段，**默认值是演示域名**
> （如 `https://sso.maxkey.top/maxkey`）。上线时必须改成真实域名，
> 否则它签出的 `id_token` 里 `iss` 是旧域名，客户端校验会失败。

---

## 17. 实测验证记录

> 环境：Ubuntu 24.04.5 x86_64，glibc 2.39，nginx 1.24.0，
> KingbaseES V009R003C018，JDK 21（jlink 产物 64MB）。
> 所有验证均在本机完成，**含真实的 systemd 与 `/opt/maxkey` 操作**。
>
> 注：早期版本的自检记录里提到"sudo 受限，用隔离前缀等效验证"——
> 那是因为当时的执行环境设了 `no new privileges`。本次已完成真机验证：
> 以 root 实际执行 install / upgrade / rollback / uninstall，
> 服务由 systemd 管理，nginx 用真实站点文件，数据库是真实库。
>
> 目标机是麒麟 V10，本机是 Ubuntu 24.04。`install.sh` 对此只告警不拦
> （拦住会让开发机无法回归）；真正的不兼容（架构/glibc）由 `preflight.sh` 报。

### 16.1 构建链路

| 项目 | 结果 |
|------|------|
| `gradle projects` | 工程列表不再含 `gataway`；openapi 已排除 |
| `bootJar` ×2 | 成功（离线 11 秒），portal 205MB / mgt 196MB |
| `pnpm install --frozen-lockfile` | 成功（1 分 0 秒），此前因缺 lockfile **必然失败** |
| 前端构建 ×2 | portal 5.9s（初始包 2.51MB / gzip 489KB），mgt 9.9s |
| 从干净树全量重建 | `build-package.sh --build` 1 分 24 秒，自动改用仓库内 `COREPACK_HOME` |
| lockfile 完整性 | 裸 pnpm 执行会改写 lockfile（实测 +25 行）；脚本校验能拦下；corepack 路径无 drift |
| 打包 | `maxkey-deploy-4.2.0.tar.gz` 361MB，结构完整 |

### 16.2 运行时

| 项目 | 结果 |
|------|------|
| jlink 23 模块 | **59MB**，4 秒生成 |
| 缺 `java.desktop` 时 | 自检正确拦截，输出 `NoClassDefFoundError: java/awt/image/BufferedImage` 并判定"缺 java.desktop" |
| 补齐后 | 自检通过 |
| portal 启动 | **8 秒**成功（用包内 jre） |
| mgt 启动 | **8 秒**成功（用包内 jre） |
| 验证码渲染 | HTTP 200，图片正常（证明 `java.desktop` 真实生效） |

### 16.3 nginx 路由

经 TLS 反代实测（隔离实例，非标准端口；等效于 443 的线上形态）：

| 请求 | 结果 |
|------|------|
| `/maxkey/` | 200 |
| `/maxkey/passport/login`（深链接） | 200（SPA 回退生效） |
| `/maxkey/assets/<存在的>.js` | 200 |
| `/maxkey/assets/nope.js` | **404**（未误回退 index.html） |
| `/maxkey-mgt/` | 200 |
| `/maxkey-mgt-api/inst/get` | 200（透传到 9526） |
| `/sign/inst/get` | 200（透传到 9527） |
| `/healthz` | 200 |

### 16.4 对外地址与 SSO

| 项目 | 结果 |
|------|------|
| 未开 `forward-headers-strategy` | `authorization_endpoint: http://127.0.0.1:9527/sign/authz/oauth/v20/authorize`（错） |
| 开启后（带 X-Forwarded） | `https://sso.lottery-dev.com:9443/sign/authz/oauth/v20/authorize`（对） |
| OIDC issuer | `https://sso.lottery-dev.com:9443/sign/maxkey` |
| JWT 解码 | `iss = https://sso.lottery-dev.com:9443/sign`（无内部端口，与元数据一致） |
| 租户识别 | `Host: sso.maxkey.top` 命中；不匹配的 Host 回落默认租户 |

**浏览器端到端（Playwright + Chromium，真实 TLS 经 nginx）**：

```
✓ 登录页可访问  HTTP 200
✓ 登录页表单已渲染
✓ 页面标题已加载  "Login - MaxKey"
✓ 登录接口返回 code=0  HTTP 200 code=0
✓ 拿到认证 token
✓ JWT iss 为公网地址（非内部端口）  iss=https://sso.lottery-dev.com:9443/sign
✓ 门户返回授权应用列表  HTTP 200 应用数=14
✓ 已到达授权环节
✓ 取得 oauth_approval 令牌
✓ 审批请求已提交  HTTP 200
✓ 审批返回带授权码的回跳 URL  .../callback?code=<uuid>
✓ 提取授权码 code
✓ 授权码换取 access_token 成功（含 id_token）
```

即 **登录 → 授权 → 发码 → 换令牌** 整条链路闭合。

未登录访问 OAuth 端点时的行为也验证过：

```
GET /sign/authz/oauth/v20/authorize?...
→ 302 https://sso.lottery-dev.com:9443/maxkey/#/passport/login?redirect_uri=<base64>
```

回跳地址正确携带原始授权 URL（base64），符合 SSO 预期。

### 16.5 数据库

| 项目 | 结果 |
|------|------|
| `maxkey-seed.sql` 导入 | **3.2 秒，0 错误** |
| 表结构 | 44 张 `mxk_*`，与源文件完全一致 |
| 数据 | 1 个用户（admin）、1 个机构、14 个组、admin 6 条成员关系、24 条授权、34 个应用、14 个 OAuth client |
| 协议覆盖 | CAS 9 / SAML 7 / OAuth2 7 / OAuth2.1 1 / OIDC 1 / JWT 2 / Token 3 / ExtendAPI 3 / Basic 1 |
| 登录 | `admin/{plain}maxkey` 成功，`Authorized Apps` 返回 15 个应用 |
| 登录历史写入 | 正常落库（`mxk_history_login`） |

### 16.6 安装脚本

| 项目 | 结果 |
|------|------|
| `install.sh --dry-run`（非 root） | 通过，仅打印操作 |
| 域名冲突检测 | **正确命中**本机已有的 `sso-sso.lottery-dev.com.conf` 并中止，未改动任何 nginx 文件 |
| 渲染校验 | 端口（IPv4+IPv6）、证书路径、server_name 均正确替换，无占位符残留 |
| `uninstall.sh` | 语法通过；默认保留配置与数据，`--purge` 才删目录 |

### 16.7 新方案端到端验证（版本目录 + 更新 + 回滚 + 零残留）

在本机真机执行，全部通过：

| 步骤 | 命令 | 结果 |
|------|------|------|
| 旧布局迁移 | `install.sh --migrate-layout` | 旧 `maxkey/`、`maxkey_mgt/`、`web/` 移入 `releases/4.2.0-ga/`，`current` 软链建立，存量日志搬入共享目录 |
| 安装完整性 | `verify.sh --expect installed` | 十项硬指征全绿 |
| 卸载（含删库） | `uninstall.sh --purge-all --yes` | 先 dump 到 `backups/` → DROP schema → 删密钥与用户；`exit=0` |
| 零残留 | `verify.sh --expect removed` | 通过（`conf/`、`logs/`、`backups/` 属刻意保留） |
| 全新安装 | `install.sh --profile dev-local --init-db` | 导入 44 张表 + admin 账号，健康检查五项全过 |
| 升级 | `upgrade.sh <新包>` | 备份 198KB → Flyway 应用 V2 → 切 current → 健康检查通过，约 50 秒 |
| 回滚 | `rollback.sh --to <旧版本>` | 切回旧版本，健康检查通过 |
| Flyway 状态 | 查 `maxkey_schema_history` | `1 = << Flyway Baseline >>`、`2 = verify pipeline`，均 `success=t` |

几个关键实测数字：

- Flyway 连接：`Database: jdbc:postgresql://127.0.0.1:54321/maxkey (PostgreSQL 12.1)`
  —— 用 pgjdbc 才拿到 `PostgreSQL` 这个产品名，kingbase8 驱动返回 `KingbaseES` 会被拒
- 迁移工具依赖总量：`flyway-core` 768KB + `flyway-database-postgresql` 48KB
  + pgjdbc 1.1MB + gson 300KB + Jackson3（databind/core/annotations）
  ≈ 4MB，远小于官方 `flyway-commandline` 的 **476MB**
- 备份大小：种子库（44 表、无业务数据）198KB；本机带数据时 12MB

### 16.8 仍需在目标环境确认的项

以下因本机环境限制未能真实验证，首次部署时请重点确认：

| 项目 | 原因 | 如何确认 |
|------|------|---------|
| systemd 单元启停 | 本机 `sudo` 受限 | `systemctl start maxkey-portal && systemctl status maxkey-portal` |
| `User=maxkey` 权限 | 无法创建系统用户 | 启动后 `ps -o user= -p <pid>` 应为 maxkey |
| SELinux / firewalld | 本机未启用 | `sestatus`、`firewall-cmd --list-ports`；nginx 需能读 `/opt/maxkey/web` |
| AWT 字体 | 本机字体齐全 | `preflight.sh` 会检测；缺则 `yum install fontconfig dejavu-sans-fonts` |
| 麒麟 V10 上的实际运行 | 本机是 Ubuntu | 用 `--with-runtime` 出的包，其 glibc 基线 2.15 < 2.28，理论上可直接跑 |
| 真实证书（非自签） | 私钥无读权限 | 用现场证书替换后 `nginx -t` |

---

## 18. 已知问题（本期不修，但必须知道）

以下是排查过程中发现的既有缺陷。都不在本次四个目标范围内，
故**只记录不修**，避免扩大改动面。

### 17.1 JWT HMAC 密钥明文硬编码 —— **已修复**

原先 `maxkey.auth.jwt.secret` 与 `refresh.secret` 是 512 字符字面量，
明文写在 `application-maxkey.properties` 与 `application-maxkey-mgt.properties`
（两处完全相同）。拿到 jar 就能伪造任意用户的 JWT。

现在改为环境变量注入：

```properties
maxkey.auth.jwt.secret          = ${JWT_SECRET}
maxkey.auth.jwt.refresh.secret  = ${JWT_SECRET}
```

`JWT_SECRET` 由 `install.sh` 首次生成（512 字符随机 ASCII），
存在 `/etc/maxkey/maxkey-secret.env`（600 root:root），
由 systemd 的 `EnvironmentFile` 注入。`maxkeyctl.sh` 启动前会校验它非空，
缺失直接拒绝启动 —— 不留"回落到代码默认值"的口子。

三条使用约束（都写在 `conf/maxkey.env` 的注释里）：

- portal 与 mgt 必须用**同一个值**，否则两边签发的 token 互不认可，
  症状是"登录成功但立刻被踢回登录页"
- 长度必须 ≥ 64 字节（HS512 下限），否则启动抛 `WeakKeyException`
- **改它会让所有已登录会话立即失效**，只有换环境时才需要改

存量环境升级时，`upgrade.sh` 会从旧 jar 里抽出原密钥沿用，
不会让现有会话失效。

### 17.2 Redis 配置用旧命名空间（潜在启动失败）

`RedisAutoConfiguration` 读的是 `${spring.redis.host}` /
`${spring.redis.password}`，且**没有默认值**。Spring Boot 4 已迁移到
`spring.data.redis.*`。

当前 `maxkey.server.persistence=0` 走内存分支，不会触发；
但 `RedisAutoConfiguration` 是无条件 `@AutoConfiguration`，
一旦启用 Redis（`SERVER_PERSISTENCE=2`）就会因属性解析失败而启动失败。

另：`RedisDefaultConfig` 默认口令是 `admin`，而 properties 默认
`REDIS_PWD:password`，两者本身也不一致。

### 17.3 SAML keystore 口令硬编码

`config/*.jks` 与 `*.jwks` 打包进 jar，口令 `maxkey` 写在 properties 里。
多实例部署时所有实例共用同一套签名密钥。

### 17.4 确认页面注入第三方统计脚本（隐私/合规）

`templates/add-html-head-content.vm` 里有一段经过 `\x` 转义混淆的脚本，
解码后是：

```
https://hm.baidu.com/hm.js?ae02bfc0d49b4dfa890f81d96472fe99
```

内容是百度统计的站点访问跟踪。它会出现在 SSO 授权确认页上，
意味着**内网用户的授权页会向外部发起请求**，在信创/等保场景通常不可接受。

来源已追溯：该文件自 2021-07-31 的提交 `469437929`（"static"）起就在上游
仓库，不是本次引入。

缓解：部署前清空该模板内容（保留文件，避免模板缺失报错）：

```bash
# 源文件（重新打包前）
: > maxkey-webs/maxkey-web-maxkey/src/main/resources/templates/add-html-head-content.vm
```

若要彻底解决，应改为可配置项并在默认配置里关闭。

### 17.5 `mxk_apps_oauth_client_details.issuer` 默认是演示域名

每个 OAuth client 有独立的 `issuer` / `audience` 字段，
默认值形如 `https://sso.maxkey.top/maxkey`、`http://sso.maxkey.top:9527/...`。

实测 `id_token` 里的 `iss` 就是取这个字段，因此**不会**跟随
`MAXKEY_PUBLIC_URL` 变化。上线时必须逐个改成真实域名，
否则客户端按真实 issuer 校验会失败。

### 17.6 OAuth2 password grant 抛 NPE（上游缺陷）

`POST /sign/authz/oauth/v20/token` 用 `grant_type=password` 时抛：

```
java.lang.NullPointerException: Cannot invoke "java.util.Collection.size()" because "c" is null
  at java.util.LinkedHashSet.<init>
  at AbstractUserDetailsAuthenticationProvider.createSuccessAuthentication
```

根因：`SignPrincipal` 的 `grantedAuthority` 字段从未被赋值，
`getAuthorities()` 返回 `null`，Spring Security 在
`new LinkedHashSet<>(null)` 处崩。

`authorization_code` 流程不受影响（本次 SSO 验证走的就是它）。
修复方式是让 `getAuthorities()` 返回空集合而非 null，但属于上游代码改动，
本期不动。

### 17.7 会话不支持多实例

`SERVER_PERSISTENCE=0`（默认）时会话在 JVM 内存（Caffeine），
重启丢登录态，且无法水平扩展。需要多实例时切 Redis
（但要先修 12.2）。

### 17.8 包体积偏大

两个 fat jar 各约 200MB（合计 405MB 压缩包），主要来自依赖较多。
可用 layered jar 或裁剪不需要的协议模块来减小，
但会影响灵活性，本期未做。

### 17.9 部署脚本自身踩过的坑（都已修，记下来防再犯）

这些不是产品缺陷，是**脚本**在真实环境里暴露的问题。列出来是因为
它们都属于"症状离根因很远"的那一类，下次遇到能省很多时间。

| 症状 | 根因 | 修法 |
|------|------|------|
| `sys_dump: syntax error at or near "online"` | PATH 上的 `/usr/bin/pg_dump`（PostgreSQL 官方版）被优先使用，它不认 Kingbase 保留字 | 查找顺序改为 Kingbase 自带工具优先，`pg_dump` 只作最后兜底 |
| `fe_sendauth: no password supplied` 然后卡住 | Kingbase 的 `sys_dump`/`ksql` 只认 `KINGBASE_PASSWORD`，不认 `PGPASSWORD` | 两个变量都设（`db_client_env`） |
| 备份恢复时报一堆 SQL 语法错 | Kingbase 自定义格式的魔数是 `KEMDP`，不是 `PGDMP`，被当成纯文本 SQL 执行 | 两个魔数都识别 |
| `No results were returned by the query` | `MaxKeySql` 用 `executeQuery` 跑 DDL | 改用 `execute()` + 判断是否有结果集 |
| `Could not find or load main class MaxKeySql` | `uninstall --purge` 删了 `releases/`，工具类随之消失，而清库还要用它 | 工具路径固定取**当前部署包**的 `sql/lib` |
| `UnsupportedClassVersionError ... 65.0` | 工具类用 Java 21 编译，`db_java` 却回落到系统 JDK 17 | 按主版本号挑 ≥21 的 java，并优先用包内 jre |
| `schema "public" does not exist` | `DROP SCHEMA` 缺 `IF EXISTS`，第二次执行报错，把成功误判成失败 | 加 `IF EXISTS` / `IF NOT EXISTS` |
| 前端构建失败但打包"成功" | `... \| tee log` 的退出码是 tee 的（永远 0） | `set -o pipefail` + 取 `PIPESTATUS` |
| 改了前端却发出旧 dist | `corepack` 不在 PATH 时原脚本**静默跳过**整个前端构建 | 主动探测 corepack（PATH → nvm 目录），找不到就报错退出 |
| `requires a minimum Node.js version` | 按版本号倒序挑到 node 24.14.0，而 Angular 要求 ≥24.15.0 | 优先选 22.x（团队约定 22.23.2） |
| release 目录名变成 `releases/24.04.5 LTS (Noble Numbat)` | `. /etc/os-release` 覆盖了脚本的 `VERSION` 变量 | 包版本改名 `PKG_VERSION`，os-release 用子 shell 读 |
| 第二次安装报 `server_name 冲突` | 冲突检测把 `maxkey.conf.bak-*` 也算了进去 | 排除本文件与其 `.bak-*` |
| pid/日志写进 `current/run`、`current/logs` | 从软链调用时 `dirname` 判定布局失效 | 用 `readlink -f` 取物理路径再判断 |
| `--dry-run` 也改动了现场 conf | `conf_sync_missing_keys` 里是裸 `>>` | 走 `DRY_RUN` 分支 |
| `--purge-all` 连不上库 | 先删了 `/etc/maxkey/maxkey-secret.env`，后面才 DROP | 密钥与用户放到**最后**删 |
| 每次健康检查都报一条 ERROR | Druid 的 `testWhileIdle ... validationQuery not set` 配置提醒 | 按关键字排除（假告警会训练人忽略告警） |

---

## 19. 排障速查

| 现象 | 根因 | 处理 |
|------|------|------|
| `UnsupportedClassVersionError` | 目标机 JDK < 21 被优先选中 | `./bin/maxkeyctl.sh java` 查看实际使用的 java；确认 `jre/` 存在 |
| `GLIBC_2.3x not found` | 用系统自带 JDK 构建，基线过高 | 改用 Temurin：`./bin/make-runtime.sh --download` |
| `NoClassDefFoundError: java/beans/...` | 裁剪运行时缺 `java.desktop` | `./bin/maxkeyctl.sh start` 会直接指出；补齐模块重新生成 |
| **登录成功但立刻被踢回登录页** | JWT 的 iss 与实际 origin 不一致 | 检查 `MAXKEY_PUBLIC_URL` 是否等于浏览器实际地址（含端口） |
| OIDC 元数据里出现 `127.0.0.1:9527` | 未开 `forward-headers-strategy` 或 nginx 没传 `X-Forwarded-*` | 两者都要有 |
| SSO 回跳到错误的域名/端口 | `MAXKEY_PUBLIC_URL` 与 nginx `server_name`/端口不一致 | `install.sh` 会拦；手工核对 §13.3 |
| **能登录但门户应用列表为空** | 缺 `ROLE_ALL_USER` 组或其成员记录 | 见 §15.3，检查 `mxk_groups` / `mxk_group_member` / `mxk_access` |
| 访问 authorize 被 302 到 `/authz/refused` | 该应用未对当前用户组授权，或 `visible=0` | 管理端给对应组授权，或调整 `mxk_apps.visible` |
| 配了 Kingbase 却连 3306 | JDBC URL 中 `&` 未加引号被 shell 截断 | URL 加单引号（脚本已做校验） |
| `online` 列名报错 | 未开启标识符转义 | `DATABASE_COLUMN_ESCAPE=true` + 转义符 `"` |
| 分页 SQL 报错 | 方言未生效 | `DATABASE_DIALECT=kingbase` |
| 页面能开但 API 全 404 | `proxy_pass` 漏尾部路径 | `proxy_pass .../sign/;` |
| 改了 nginx 配置不生效 | 存在同 `server_name` 的另一个站点 | `nginx -t` 会报 `conflicting server name`；`install.sh` 会提前拦 |
| **nginx 报 `bind() to 0.0.0.0:443 failed` 但 `ss` 看不到占用者** | WSL 下 Windows 侧端口转发占用了该端口 | 换端口（如 9443），`NGINX_TLS_PORT` 与 `MAXKEY_PUBLIC_URL` 同步改；Windows 侧用 `netstat -ano \| findstr :443` 或 `netsh interface portproxy show all` 核对 |
| `nginx -s reload` 返回 0 但端口没起来 | reload 失败只写 error.log，命令本身仍退出 0 | `install.sh` 已改为 reload 后校验端口监听并自动回滚；手工操作时务必看 `/var/log/nginx/error.log` |
| **只重启 portal 后 mgt 变 failed 且不自愈** | mgt 单元声明了 `Requires=maxkey-portal.service` | 已改为只用 `After=` 表达启动顺序（见 §20）；旧单元需手工 `reset-failed` 后 start |
| **curl 访问 MaxKey 返回 000 但浏览器正常** | 环境变量 `http_proxy/https_proxy` 指向本地代理，`no_proxy` 的 `*.domain` 通配不被 curl 支持 | 用 `curl --noproxy '*'`；或把具体域名写进 `no_proxy` |
| `.js` 报 `Unexpected token '<'` | 静态资源缺失回退到了 index.html | 静态资源 location 用 `try_files $uri =404` |
| 改 DB 配置后不生效 | client 信息有 Caffeine 缓存 | 重启进程 |
| 启动被拒绝，提示 DATABASE_PWD 为空 | 口令未注入 | 填 `/etc/maxkey/maxkey-secret.env` |
| `Invalid redirect: ... does not match` | 回调地址与 client 注册值不一致 | 管理端改该应用的回调地址（精确匹配，含路径） |
| 构建后 `pnpm-lock.yaml` 变脏 | 用了 PATH 上的 pnpm 而非 corepack | 改用 `corepack pnpm`；脚本会比对校验和并报错 |
| 构建报 `EACCES ... corepack/v1` | `$HOME` 不可写 | 脚本已自动处理；手工构建时设 `COREPACK_HOME` |

---

## 20. 日常运维

```bash
# ---- 启停 ----
/opt/maxkey/current/bin/maxkeyctl.sh start|stop|restart|status [portal|mgt|all]
/opt/maxkey/current/bin/maxkeyctl.sh java     # 实际使用的 JDK 与版本

systemctl start|stop|restart maxkey-portal maxkey-mgt
journalctl -u maxkey-portal -f

# ---- 日志（集中在 /opt/maxkey/logs，跨版本共享）----
tail -f /opt/maxkey/logs/portal/maxkey.log
tail -f /opt/maxkey/logs/mgt/maxkey.log
tail -f /opt/maxkey/logs/portal/nohup-portal.out

# ---- 自检 ----
/opt/maxkey/current/bin/preflight.sh          # 环境与配置（一次性列出所有阻塞项）
sudo ./verify.sh                              # 安装完整性（只读）

# ---- 更新 ----
sudo ./upgrade.sh <新包.tar.gz>                # 停服→备份→迁移→切版本→自检
sudo ./rollback.sh --list                     # 看能退回哪几个版本
sudo ./rollback.sh --to <版本>                 # 回滚（默认不动数据库）

# ---- 数据库迁移 ----
sudo ./bin/migrate.sh --info                  # 已应用/待应用
sudo ./bin/migrate.sh                         # 应用（自动先 dump）

# ---- 换域名后重绑库里的数据 ----
sudo ./bin/rebind-site.sh --old <旧> --new <新>            # 预览
sudo ./bin/rebind-site.sh --old <旧> --new <新> --apply    # 执行

# ---- 卸载 ----
sudo ./uninstall.sh              # 只摘服务接入（程序/配置/库都保留）
sudo ./uninstall.sh --purge      # 再删程序、密钥、用户（保留 conf/logs/backups）
sudo ./uninstall.sh --purge-all  # 再 DROP schema（需输入库名确认）
```

### 19.1 磁盘占用与清理

```bash
du -sh /opt/maxkey/releases/*    # 每个版本约 414MB（含 jar + 前端）
du -sh /opt/maxkey/backups/*     # 每次升级一份整库 dump + 配置快照
```

- 版本：`upgrade.sh` 自动保留最近 3 个（`--keep-releases N` 可调）
- 备份：自动保留最近 5 份（`--keep-backups N` 可调）
- `--purge` **不删** `conf/`、`logs/`、`backups/` —— 它们是现场资产与排障证据

空间不够时 `upgrade.sh` 会在 dump **之前**报错（按库大小 2 倍 + 250MB 估算），
不会留下半个 dump 文件。可用 `--backup-dir /挂载盘/备份` 换位置。

### 19.2 一次典型升级的完整时间线

```
10:18:46  校验新包（manifest / 校验和 / 版本不得倒退）
10:18:47  停 maxkey-portal、maxkey-mgt
10:18:48  备份 → backups/20261030-101846/{db.dump, config/, meta.txt}
10:18:52  Flyway 迁移（本版本带 V2 → 已应用）
10:18:53  落新 release、切 current
10:18:54  unit 无变化 → 跳过 daemon-reload
10:19:20  起服务
10:19:35  健康检查五项全过
10:19:36  清理超出保留数的旧版本与旧备份
```

实测整轮约 50 秒（库小、无 schema 变更）。含 schema 变更或库大时，
主要耗时在 dump 与迁移。
