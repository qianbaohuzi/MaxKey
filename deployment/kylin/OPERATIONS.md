# MaxKey qilin-01 部署操作手册

> 本文是**照着敲**的操作手册：每条命令单独一行，每步标注预期结果与失败排查。
> 背后的设计原因不在本文，见同目录 [README.md](README.md)。
>
> 适用目标机：**qilin-01**（麒麟 V10，KingbaseES V9 本机 54321，域名
> `sso.maxkey.lottery-dev.com:9443`）。
> 打包机：开发机（本仓库所在机器）。

---

## 0. 执行前必须替换/确认的值

全文用 `«»` 标注需要按现场替换的值。开始前先把这张表填掉：

| 占位符 | 本次部署的值 | 在哪里确认 |
|--------|-------------|-----------|
| `«QILIN01_IP»` | `___________` | `ping qilin-01` 或问运维 |
| `«SSH_USER»` | `maxkey` | SSH 账号（wheel 组，sudo 需密码） |
| `«QILIN01_DB_PWD»` | `___________` | 问 DBA（Kingbase 角色 `maxkey` 的口令） |
| `«DNS_A_RECORD»` | `sso.maxkey.lottery-dev.com → «QILIN01_IP»` | 内网 DNS 管理员 |
| 构建机路径 | `/home/liwenbiao/workspace/shanxi/maxkey` | 本仓库位置 |
| 远程目录 | `/home/maxkey/release` | 目标机上放包的目录 |

> **域名必须先有 DNS**：`sso.maxkey.lottery-dev.com` 若不解析，
> 第 5 步的浏览器点测全部无法进行（租户识别、Cookie、SSO 回跳都绑域名）。
> 让内网 DNS 管理员加一条 A 记录：`sso.maxkey.lottery-dev.com → «QILIN01_IP»`。
> 这是**前置项**，不是部署时才做的。

---

## 1. 构建打包（开发机执行，约 3~6 分钟）

### 1.1 前置确认

```bash
cd /home/liwenbiao/workspace/shanxi/maxkey

# JDK 21 可用（编译迁移工具与跑 gradle）
ls /usr/lib/jvm/java-21-openjdk-amd64/bin/javac

# 工作区干净（有未提交改动时打出的包不含那些改动，容易造成"改了没生效"）
git status --short
```

> 预期：`javac` 路径存在；`git status` 无未预期的改动
> （`sql/kingbase/` 下有历史遗留改动属正常，见 README）。

### 1.2 打包

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
  ./deployment/kylin/build-package.sh
```

预期输出末尾：

```
  manifest: 4.2.0-<sha>-<时间戳>  (git <sha>, jre=true)
  校验和: 39 个文件
  压缩包: .../maxkey-deploy-4.2.0-<sha>-<时间戳>.tar.gz  (405M)
EXIT=0
```

**失败排查**（都是实测出现过的）：

| 报错 | 原因与处理 |
|------|-----------|
| `corepack: command not found` → 前端构建失败 | PATH 上没有 corepack。`export PATH="$HOME/.nvm/versions/node/v22.23.2/bin:$PATH"` 后重跑 |
| `requires a minimum Node.js version` | node 版本不对（24.14.0 不满足 Angular 要求）。同上，用 22.23.2 |
| `pnpm-lock.yaml` 被改写 | 用了 PATH 上的 pnpm 而非 corepack。删掉改动（`git checkout -- <文件>`）后重跑 |
| `下载失败`（fetch flyway/jackson jar） | 构建机无外网。把 jar 手工放进 `.cache/flyway/`（文件名列表见 README §5.3） |

### 1.3 记录包信息（后面传输与校验要用）

```bash
PKG=$(ls -1t build/maxkey-deploy-*.tar.gz | head -1)
echo "PKG=$PKG"
sha256sum "$PKG"
```

**记下这两行输出**：文件名与 sha256。目标机上要比对。

### 1.4 验证包内结构（可选但建议，10 秒）

```bash
NEW=$(ls -1dt build/maxkey-deploy-*/ | grep -v tar | head -1)
ls "${NEW%/}"
```

预期包含：`install.sh upgrade.sh rollback.sh uninstall.sh verify.sh`
`maxkey/ maxkey_mgt/ web/ jre/ conf/ env/ lib/ bin/ sql/ nginx/ systemd/ tools/`
`manifest.json checksums.sha256 VERSION`。

缺 `sql/lib/` 里的 jar 或 `sql/migrations/` 说明打包脚本没跑全，重跑 1.2。

---

## 2. 传输（手工 scp）

### 2.1 从开发机传出

```bash
# 在开发机（仓库根目录）
PKG=$(ls -1t build/maxkey-deploy-*.tar.gz | head -1)
scp "$PKG" «SSH_USER»@«QILIN01_IP»:/home/maxkey/release/
```

> 目标目录 `/home/maxkey/release/` 若不存在先建：
> `ssh «SSH_USER»@«QILIN01_IP» 'mkdir -p /home/maxkey/release'`
>
> 400MB 全量传输，内网约 1~5 分钟。断了就重跑同一条 scp（scp 会覆盖重传）。

### 2.2 在目标机上校验完整性

```bash
ssh «SSH_USER»@«QILIN01_IP»

# 以下在目标机执行
cd /home/maxkey/release
sha256sum maxkey-deploy-*.tar.gz
```

**必须与 1.3 记录的 sha256 完全一致**。不一致说明传输损坏，重传（不要解压）。

### 2.3 解压

```bash
cd /home/maxkey/release
tar xzf maxkey-deploy-4.2.0-*.tar.gz
cd maxkey-deploy-4.2.0-*
ls
```

预期看到与 1.4 相同的目录结构。

---

## 3. 安装（目标机执行，全程 root）

### 3.0 切到 root 并做一次自检

```bash
sudo -i          # 输入 maxkey 的密码；之后所有命令都在 root 下
cd /home/maxkey/release/maxkey-deploy-4.2.0-*

# 环境自检：一次性暴露所有阻塞项（只读，不改任何东西）
./bin/preflight.sh
```

预期：`自检结果: N 通过 / M 警告 / 0 阻塞`。

**阻塞项处理**（警告可忽略，阻塞必须先解决）：

| 阻塞项 | 处理 |
|--------|------|
| glibc 不足 | 不应出现（包内自带 Temurin jre，基线 2.15）。出现说明用了系统 JDK |
| 缺 JDK 21 | 不影响（包内 jre 会优先使用），可忽略该项 |
| 端口 9527/9526 被占 | `ss -lntp \| grep -E '9526\|9527'` 找占用者；确属遗留进程则 kill |
| Kingbase 端口不可达 | 确认 Kingbase 服务在跑：`ss -lnt \| grep 54321` |
| `/etc/maxkey/maxkey-secret.env` 缺失 | 正常，第 3.4 步会创建 |
| nginx 未安装 | `yum install -y nginx`（目标机应已装，缺失时找运维） |
| `AWT/字体不可用 ... Module jdk.compiler not in boot Layer` | **是旧版预检脚本的误报，不是缺东西**（java.desktop 一直都在，是探测方式错了）。换用 2026-10-30 之后的包，或手工验证：`«包内jre»/bin/java --list-modules \| grep java.desktop` |
| `端口 9527/9526 已被占用` 且占用者是 java | 这台机器之前装过/还在跑 MaxKey。见 Q：全新机器不会出现；出现了按 §6 卸载后重装 |

### 3.1 创建证书（自签，仅测试环境）

```bash
mkdir -p /etc/nginx/cert

openssl req -x509 -nodes -days 1095 -newkey rsa:2048 \
  -keyout /etc/nginx/cert/sso.maxkey.lottery-dev.com.key \
  -out    /etc/nginx/cert/sso.maxkey.lottery-dev.com.crt \
  -subj "/CN=sso.maxkey.lottery-dev.com" \
  -addext "subjectAltName=DNS:sso.maxkey.lottery-dev.com"

chmod 640 /etc/nginx/cert/sso.maxkey.lottery-dev.com.key
chmod 644 /etc/nginx/cert/sso.maxkey.lottery-dev.com.crt
ls -l /etc/nginx/cert/
```

预期：两个文件生成，key 是 640，crt 是 644。

> ⚠️ 自签证书仅限测试。浏览器第一次访问会提示"不安全"，点"继续访问"即可。
> 生产环境换正式证书时只改 `env/qilin01.env` 里的 `NGINX_CERT/NGINX_KEY`
> 两个路径，重新 install 即可。

### 3.2 演练（不落盘，确认将要做的事）

```bash
./install.sh --profile qilin01 --dry-run
```

**逐项核对输出**（这一步是防呆的关键）：

| 检查 | 预期 |
|------|------|
| `部署包版本` | 与 1.3 记录的包名一致 |
| `系统 :` | 应显示麒麟 V10（显示 Ubuntu 说明连错机器了） |
| `档案 :` | `env/qilin01.env` |
| `环境档案自洽性校验通过` | 必须有这一行；若有 `ERROR`，按提示改 `env/qilin01.env` |
| `当前库表数量: 0` | 空库才对；若 ≥40 说明这个库已被用过，**停下**（见下方红框） |
| `nginx 站点配置` | 端口 9443；无 `server_name 冲突` |

> **⚠️ 如果 `当前库表数量 ≥ 40`**：这个库已经有数据了。**不要**继续，
> 否则 `--init-db` 会被拒（这是保护，不是 bug）。需要确认：
> 这是别人环境遗留，还是本机此前部署残留？找 DBA 确认后，
> 由人显式执行 `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`（脚本永不自动删库）。

### 3.3 正式安装（含建库）

```bash
./install.sh --profile qilin01 --init-db
```

过程中的交互：

```
请输入数据库口令（用户 maxkey，不回显）: «QILIN01_DB_PWD»
```

输入 DBA 提供的口令（不回显，输错不会显示，回车确认）。

**成功判据**（输出末尾）：

```
==> 健康检查
  [ OK ] portal 端口 9527 监听中
  [ OK ] mgt 端口 9526 监听中
  [ OK ] 直连后端 OIDC 元数据 200
  [ OK ] 经 nginx 访问前端 200（Host: sso.maxkey.lottery-dev.com:9443）
  [ OK ] 经 nginx 访问管理端 200
  [ OK ] 无 ERROR 日志（portal）
  健康检查全部通过
==> 安装完成
```

**失败排查**：

| 报错/现象 | 原因与处理 |
|-----------|-----------|
| `fe_sendauth: no password supplied` | 口令错或为空。重跑（口令已存入 `/etc/maxkey/maxkey-secret.env`，可用 `vi` 改） |
| `password authentication failed` | 口令不对。找 DBA 确认角色 `maxkey` 的口令 |
| `种子库导入失败 ... already exists` | 库非空。见 3.2 的红框 |
| `server_name 冲突` | 目标机 nginx 已有同域名的站点。`grep -rl 'sso.maxkey.lottery-dev.com' /etc/nginx/conf.d/` 找出并处理 |
| 端口 9443 被非 nginx 进程占用 | `ss -lntp \| grep 9443`；换端口需同步改 `env/qilin01.env` 的 `NGINX_TLS_PORT` 与 `MAXKEY_PUBLIC_URL` |
| 健康检查"直连后端"不过 | 看 `tail -100 /opt/maxkey/logs/portal/nohup-portal.out`；最常见是数据库口令错 |
| 健康检查"经 nginx"不过但直连过 | 证书路径或端口渲染问题。`nginx -t && tail -20 /var/log/nginx/maxkey.error.log` |

### 3.4 确认密钥文件（自动生成，核对即可）

```bash
ls -l /etc/maxkey/maxkey-secret.env
stat -c '%a %U' /etc/maxkey/maxkey-secret.env
grep -cE '^(DATABASE_PWD|JWT_SECRET)=' /etc/maxkey/maxkey-secret.env
```

预期：`600 root`，计数为 `2`。

> 这是全机唯一存明文口令的地方。**不要**把它拷走、贴进工单或提交进 git。

### 3.5 验证安装完整性

```bash
./verify.sh --expect installed
```

预期最后一行：`== 验证通过：安装完整 ==`。

任何 `[FAIL]` 项按提示处理后再验一次，**这一步不过不要进入点测**。

---

## 4. 部署后检查（SSH 侧，1 分钟）

```bash
# 服务
systemctl status maxkey-portal maxkey-mgt --no-pager | grep Active
#      预期两行 active (exited)（forking 类型）

# 进程与端口
ss -lntp | grep -E ':9526|:9527|:9443'
#      预期 9527(java) 9526(java) 9443(nginx) 都在监听

# 日志集中在共享目录（跨版本共享，回滚后旧日志仍在）
ls /opt/maxkey/logs/portal/ /opt/maxkey/logs/mgt/

# 布局
readlink /opt/maxkey/current
#      预期 /opt/maxkey/releases/4.2.0-<sha>-<时间戳>

# 从服务器本机验证 HTTPS（-k 跳过自签证书校验）
curl -sk -o /dev/null -w '%{http_code}\n' \
  -H 'Host: sso.maxkey.lottery-dev.com' \
  https://127.0.0.1:9443/maxkey/
#      预期 200
```

**DNS 验证**（点测的前提）：

```bash
# 在目标机确认解析（若无 dig 用 getent）
getent hosts sso.maxkey.lottery-dev.com
#      预期输出 «QILIN01_IP»
```

> 没解析就回头找 DNS 管理员。**这一步不过，第 5 步整章作废**。

---

## 5. 点击测试（浏览器，约 30 分钟）

浏览器机器需能解析 `sso.maxkey.lottery-dev.com` 且网络可达 9443。
自签证书第一次访问会出现"您的连接不是私密连接"，点
**高级 → 继续前往**（Chrome）或 **高级 → 接受风险并继续**（Firefox）。

### 5.1 登录门户 ✅

| | |
|---|---|
| 打开 | `https://sso.maxkey.lottery-dev.com:9443/maxkey/` |
| 输入 | `admin` / `maxkey` |
| 验证码 | 按图片输入（qilin01.env 里 `LOGIN_CAPTCHA=true`） |
| **预期** | 进入门户首页，右上角显示用户名 |

失败排查：

| 现象 | 处理 |
|------|------|
| 验证码图片不显示/乱码 | 目标机缺字体：`yum install -y fontconfig dejavu-sans-fonts` 后重启服务 |
| "用户名或密码错误" | 确认库是刚初始化的（admin/maxkey）；若改过密码用新密码 |
| 页面白屏、控制台大量 404 | nginx 静态资源路径问题，`tail -20 /var/log/nginx/maxkey.error.log` |
| 登录后立刻被踢回登录页 | JWT 的 iss 与访问地址不一致。检查 `MAXKEY_PUBLIC_URL` 是否**含端口** `:9443` |

### 5.2 立即改密 ✅

| | |
|---|---|
| 操作 | 右上角头像 → 个人设置 → 修改密码 |
| 新密码 | `«NEW_ADMIN_PWD»`（记下来，后面每一步都用它） |
| **预期** | 提示修改成功；用旧密码再登录应失败，新密码成功 |

### 5.3 管理端免密进入（CAS 单点，最关键的一项）✅

| | |
|---|---|
| 操作 | 门户首页点菜单 **「后台」** |
| **预期** | **不输密码**直接进入管理端（`/maxkey-mgt/`） |

这一项同时验证了三件事：CAS ticket 校验、库里的
`mxk_apps_cas_details.service` 与配置一致、token 的 iss 一致。
它是换域名/换环境后最容易坏的一环，**必须测**。

失败排查：

| 现象 | 处理 |
|------|------|
| 卡在登录页/跳回登录 | CAS service 不一致。`sudo ./bin/rebind-site.sh --dry-run` 看库里的值；种子库已按本域名渲染，一般不会发生 |
| 管理端页面 404 | nginx 的 `/maxkey-mgt/` 静态路径问题 |

### 5.4 管理端核心页面 ✅

在管理端依次打开，均应正常加载（无 500、无空白）：

```
组织机构 → 应能看到默认机构（domain 应为 sso.maxkey.lottery-dev.com）
用户管理 → 应能看到 admin
应用管理 → 应能看到「MaxKey管理系统」一条
日志审计 → 打开即可（应无报错）
```

> 若「组织机构」里的 domain 不是本域名，说明种子库渲染没生效
> （一般只在手工导入了未渲染的种子 SQL 时发生）。处理：
> 管理端直接改，或用 `bin/rebind-site.sh --old sso.maxkey.top --new sso.maxkey.lottery-dev.com --apply`。

### 5.5 OAuth2 授权闭环 ✅

用浏览器地址栏模拟一次授权码请求（ Biggest 验证点：iss 与回调）：

```
https://sso.maxkey.lottery-dev.com:9443/sign/authz/oauth/v20/authorize
  ?client_id=<在管理端建一个 OAuth 应用的 client_id>
  &response_type=code
  &redirect_uri=<该应用注册的回调地址>
```

> 没有现成测试应用时，可在管理端「应用管理」新建一个 OAuth2 应用，
> 回调地址填 `https://sso.maxkey.lottery-dev.com:9443/maxkey/`（仅测试用）。

**预期**：跳到授权确认页 → 点"同意" → 302 到回调地址且带 `?code=...`。

失败排查：

| 现象 | 处理 |
|------|------|
| `redirect_uri_mismatch` | 回调地址与注册值不一致（精确匹配，含路径与协议） |
| `invalid client_id` | 应用未启用或 client_id 抄错 |
| 授权页 500 | `tail -50 /opt/maxkey/logs/portal/maxkey.log` 找堆栈 |

### 5.6 登出 ✅

| | |
|---|---|
| 操作 | 门户右上角 → 退出登录 |
| **预期** | 回到登录页；再点「后台」要求重新登录 |

### 5.7 失败重试与锁定 ✅

| | |
|---|---|
| 操作 | 登录页故意输错密码 3 次 |
| **预期** | 出现账号锁定提示（或按配置的次数锁定）；等锁定时间过后可重试 |

### 5.8 会话与并发 ✅

| | |
|---|---|
| 操作 | 登录后复制 URL 到**另一个浏览器**（或无痕窗口）打开 |
| **预期** | 要求重新登录（会话不跨浏览器共享，内存态会话的预期行为） |

### 5.9 点测结论记录

```
[ ] 5.1 登录门户
[ ] 5.2 修改密码（新密码：__________）
[ ] 5.3 后台免密进入（CAS）
[ ] 5.4 管理端四个页面
[ ] 5.5 OAuth2 授权闭环
[ ] 5.6 登出
[ ] 5.7 失败重试/锁定
[ ] 5.8 会话隔离
```

**八项全过才算部署成功**。任何一项不过，先查
`/opt/maxkey/logs/portal/maxkey.log` 与 README §18 排障速查表。

---

## 6. 卸载（验证可重复性）

> 目的：证明「装→卸→装」是可重复的，环境不留幽灵状态。
> **会真的删数据**（含刚改的 admin 密码），删完需要重装并重做 5.1/5.2。

### 6.1 分级卸载演练

```bash
cd /home/maxkey/release/maxkey-deploy-4.2.0-*

# 级别 1：只摘服务接入（程序/配置/库全保留）——演练后无需重装
sudo ./uninstall.sh
sudo ./verify.sh --expect removed
#      预期：通过（conf/logs/backups 属刻意保留项）
#      此时浏览器已无法访问（nginx 摘了），重装只需再跑 install.sh --force-reinstall

# 级别 2：再删程序与密钥（保留 conf/logs/backups/数据库）
sudo ./uninstall.sh --purge
sudo ./verify.sh --expect removed
#      预期：通过

# 级别 3：连库一起清（真正回到零状态）
sudo ./uninstall.sh --purge-all
```

级别 3 的交互：

```
请重复输入库名以确认删除（输入 maxkey）: maxkey
```

> 输错库名会直接中止，不会删任何东西。
> 删之前脚本会自动 dump 一份到 `/opt/maxkey/backups/<时间戳>/`
> （含删除前的全部数据），万一删错还能捞回来。

预期末尾：`== 卸载完成 == 当前级别：--purge-all`。

### 6.2 零残留确认

```bash
sudo ./verify.sh --expect removed
```

预期：`== 验证通过：已清理干净 ==`，即：

- systemd 两个 unit 已删、`maxkey` 用户已删
- `/opt/maxkey/releases`、`current`、`jre` 已删
- `/etc/maxkey/maxkey-secret.env` 已删
- nginx 两个文件已删、logrotate 已删
- 端口 9527/9526 已释放
- 数据库 0 张表

**保留项**（刻意不清，`--purge` 也不删）：
`conf/`（现场配置）、`logs/`（排障证据）、`backups/`（升级备份）。
这是设计决定，不是残留。

### 6.3 再装一遍（证明可重复）

```bash
# 密钥文件已被删，需重建（口令用同一个）
install -m 600 -o root -g root /dev/null /etc/maxkey/maxkey-secret.env
printf "DATABASE_PWD='«QILIN01_DB_PWD»'\n" >> /etc/maxkey/maxkey-secret.env

sudo ./install.sh --profile qilin01 --init-db
sudo ./verify.sh --expect installed
```

预期：与健康检查五项全过、验证通过。

> ⚠️ **注意**：重装后 admin 密码回到初始的 `maxkey`，
> 第 5.2 步改的密码已随库删除。点测记录表需要重做 5.1/5.2。

---

## 7. 升级与回滚（验收时至少演练一次）

> 这一章不在你最初的清单里，但它是这套方案的另一半价值：
> 「只换包、配置不动、出问题一条命令退回」。
> 验收时建议用两个不同版本的包演练一次完整闭环。

### 7.1 出一个"新版本"

在开发机上随便改点东西（比如加一个迁移文件）再打包：

```bash
cd /home/liwenbiao/workspace/shanxi/maxkey
# 示例：加一个空迁移，让包里带上新的 migration
cat > sql/kingbase/migrations/V3__acceptance_test.sql <<'EOF'
-- 验收用：验证升级时迁移会被执行
CREATE INDEX IF NOT EXISTS idx_mxk_apps_status ON mxk_apps (status);
EOF

JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 ./deployment/kylin/build-package.sh
# 记下新的 PKG 文件名与 sha256
```

### 7.2 传输并升级

```bash
# 开发机
scp build/maxkey-deploy-<新版本>.tar.gz \
    «SSH_USER»@«QILIN01_IP»:/home/maxkey/release/

# 目标机（root）
cd /home/maxkey/release
sha256sum maxkey-deploy-<新版本>.tar.gz        # 与开发机比对
tar xzf maxkey-deploy-<新版本>.tar.gz
cd maxkey-deploy-<新版本>
./upgrade.sh ../maxkey-deploy-<新版本>.tar.gz
```

**预期**（输出末尾）：

```
==> 健康检查
  ... 五项全过 ...
==> 升级完成
    从 4.2.0-<旧sha>-<旧时间戳>
    到 4.2.0-<新sha>-<新时间戳>
    备份 /opt/maxkey/backups/<时间戳>
  回滚：sudo ./rollback.sh --to 4.2.0-<旧sha>-<旧时间戳>
```

升级过程中会自动：停服 → 整库 dump + conf/nginx/unit 快照 →
执行 V3 迁移 → 落新版本目录 → 切 current → 起服 → 健康检查。

**升级后验证**：

```bash
readlink /opt/maxkey/current                     # 应指向新版本
./bin/migrate.sh --info                          # 应显示 V3 已应用
ls /opt/maxkey/releases/                         # 应有新旧两版（旧的是回滚目标）
```

### 7.3 回滚

```bash
sudo ./rollback.sh --list          # 看可回滚的版本与备份
sudo ./rollback.sh --to 4.2.0-<旧sha>-<旧时间戳>
sudo ./verify.sh --expect installed
readlink /opt/maxkey/current       # 应回到旧版本
```

**预期**：切换软链 → 健康检查五项全过。
数据库**默认不回退**（V3 加的索引留着无害）。
只有当"新版本改了表结构、旧代码跑不起来"时才需要：

```bash
sudo ./rollback.sh --to <版本> --restore-db    # 会丢升级后新产生的数据
```

### 7.4 清理验收用的迁移

验收完成后把 V3 删掉（**只在它还没发布到任何环境时可以删**；
一旦在别的环境应用过就只能新增反向 SQL）：

```bash
# 开发机
git rm sql/kingbase/migrations/V3__acceptance_test.sql
git commit -m "移除验收用的临时迁移"
```

> 若 V3 已被目标机应用过（`maxkey_schema_history` 里有记录）而文件又删了，
> 下次升级 Flyway 会报 "applied migration not resolved locally"。
> 处理：要么恢复该文件，要么在库中删除对应记录（需 DBA）。

---

## 8. 常用命令速查（部署完成后）

```bash
# 状态与日志
/opt/maxkey/current/bin/maxkeyctl.sh status
tail -f /opt/maxkey/logs/portal/maxkey.log
journalctl -u maxkey-portal -f

# 环境自检（怀疑配置/环境问题时先跑这个）
/opt/maxkey/current/bin/preflight.sh

# 更新（下次有新包时）
sudo ./upgrade.sh <新包.tar.gz>

# 回滚
sudo ./rollback.sh --list
sudo ./rollback.sh --to <版本>

# 换域名后重绑库里的数据（仅换域名时需要）
sudo ./bin/rebind-site.sh --old <旧域名> --new <新域名>     # 先预览
sudo ./bin/rebind-site.sh --old <旧域名> --new <新域名> --apply
```

**出问题时的第一反应**：

1. `./bin/preflight.sh` —— 环境与配置有没有问题
2. `tail -100 /opt/maxkey/logs/portal/maxkey.log` —— 应用层报错
3. `journalctl -u maxkey-portal -n 100 --no-pager` —— 进程为什么没起来
4. README §18 排障速查表 —— 症状对号入座
5. 都不行就 `rollback.sh --to <上一个版本>`，先恢复服务再慢慢查
