# MaxKey 麒麟系统部署方案（KingbaseES + 内置 JDK）

> 本文配套脚本位于 `deployment/kylin/`，所有配置均已在本仓库实测通过：
> 应用在 `jlink` 裁剪运行时（64MB）上 6–8 秒内启动，`admin` 登录、租户域名解析、
> OIDC 元数据、验证码渲染、SSO 回跳均已验证。文末列出验证记录与踩坑清单。

## 1. 现状与结论速览

| 问题 | 结论 |
|------|------|
| 麒麟没有 JDK 21 怎么办 | 用**启动包内置 jlink 运行时**（64MB），不依赖目标机 JDK；`maxkeyctl.sh` 自动探测 |
| 前端怎么启动 | **纯静态文件，不需要 Node**；构建机出 `dist/browser` 后拷到目标机即可 |
| 是否单独起 nginx | 两种都行。**推荐复用已有 nginx**（不占新端口、少一个进程），见 §5 方案 B |
| 已有 nginx 能否合并 | 能，且实测可行；但**必须避开 `alias` + `try_files` 组合**，见 §5.3 |
| 域名起什么作用 | 三处独立作用：①租户识别 ②协议/端口拼接的 SSO 回跳地址 ③Cookie 域。见 §7 |
| SSO 最小化 | 只跑 `maxkey`(9527) + `maxkey_mgt`(9526) 两个 jar，不启 openapi / gateway / Redis |

**最小化 SSO 拓扑**（不启动 openapi 9525、不启动 gateway 9000、不发 Redis）：

```
浏览器 ──80──> nginx ──/sign/──────────> maxkey        9527  (SSO 认证中心)
                  ├──/maxkey/     静态    (登录页, 门户)
                  └──/maxkey-mgt/ 静态    (管理控制台)
                          └──/maxkey-mgt-api/──> maxkey_mgt   9526  (管理端 API)
                                        │
                                        └──> KingbaseES 54321
```

---

## 2. 部署包结构

执行 `deployment/kylin/build-package.sh --with-runtime` 生成。
解包后**统一放到 `/opt/maxkey`**（systemd 单元按此路径写死）：

```
maxkey-kylin-4.2.0/        ← 解包后 mv 成 /opt/maxkey
├── maxkey/                maxkey-boot-*.jar          ← 认证中心
├── maxkey_mgt/            maxkey-mgt-boot-*.jar      ← 管理端
├── web/
│   ├── maxkey/            maxkey-web-ng 的 dist/browser
│   └── maxkey-mgt/        maxkey-web-mgt-ng 的 dist/browser
├── jre/                   jlink 裁剪运行时（64MB，可选）
├── conf/maxkey.env        唯一需要改的配置文件
├── bin/maxkeyctl.sh       启停/状态/诊断
├── bin/make-runtime.sh    生成内置运行时
├── bin/preflight.sh       部署前环境自检（glibc/架构/字体/DB/端口）
├── nginx/                 两套 nginx 片段
├── systemd/               maxkey-portal.service / maxkey-mgt.service
└── sql/maxkey.sql         KingbaseES 建库脚本（44 表）
```

`build-package.sh` 从仓库现有产物组装；加 `--build` 会先跑 gradle 与前端构建。

---

## 3. JDK 21：为什么必须内置

### 3.1 硬约束

MaxKey 4.2.0 编译目标为 Java 21。实测 jar 内 class 文件魔数为
`cafe babe 0000 0041`（major 65 = Java 21）。麒麟 V10 自带 JDK 多为 8/11/17，
直接用会抛 `UnsupportedClassVersionError`。

仓库里已有对应修复（[set_maxkey_env.sh:9](../../deployment/shellscript/linux/set_maxkey_env.sh#L9)），
但该脚本假设 `./jdk-21` 目录已存在，**没有解决“怎么得到 JDK 21”**。本方案补齐这一环。

### 3.2 方案对比

| 方案 | 体积 | 适用 | 问题 |
|------|------|------|------|
| A. 要求现场装 JDK 21 | 0 | 有外网/有内网源 | 信创内网常无源；改动目标机 |
| B. 包内放完整 JDK 21 | ~300MB | 通用 | 包里塞了 2/3 用不到的模块 |
| **C. 包内放 jlink 裁剪运行时** | **64MB** | **推荐** | 与 CPU 架构绑定；glibc 基线取决于构建所用 JDK（见 §3.4） |

采用方案 C。

> 关于方案 C 的 glibc 顾虑：用 **Adoptium Temurin** 构建时基线仅 `GLIBC_2.15`，
> 低于麒麟 V10 的 2.28，因此**可直接在普通 x86_64 Linux 上构建**，无需麒麟机器。
> 详见 §3.4。

### 3.3 模块清单是怎么定的（不要凭经验猜）

直接对 fat jar 做静态分析：

```bash
unzip -q maxkey-boot-4.2.0-ga.jar 'BOOT-INF/lib/*.jar' 'BOOT-INF/classes/*'
jdeps --print-module-deps --multi-release 21 \
      --class-path "BOOT-INF/lib/*" BOOT-INF/classes
```

结果：`java.base,java.compiler,java.desktop,...,jdk.unsupported`

在此基础上做了两处**实测修正**（这一步不能省）：

1. **必须保留 `java.desktop`**
   验证码走 `java.awt.image.BufferedImage`。去掉后启动即失败：
   ```
   NoClassDefFoundError: java/beans/PropertyChangeEvent
   ```
   这正是 `java.desktop` 里的 `java.beans`。换来的代价是它依赖系统字体，
   已验证 headless 下字体渲染正常（`-Djava.awt.headless=true` 时
   `GraphicsEnvironment` 仍能列出 35 个字体族，验证码 PNG 正常输出 120x40）。

2. **可以去掉 `jdk.attach` / `jdk.jdi` / `jdk.jfr`**
   jdeps 因间接引用报出，但实测启动与登录均不需要，省约 20MB。

另外补齐了几个 jdeps **看不到**的模块——它们通过反射/SPI 在运行期加载：

| 模块 | 为什么需要 |
|------|-----------|
| `java.sql` `java.transaction.xa` | JDBC 驱动、连接池 |
| `java.naming` | LDAP / JNDI（同步器） |
| `java.management` | JMX、Druid 监控 |
| `java.security.sasl` `java.security.jgss` | SCRAM 认证、Kerberos 登录 |
| `jdk.crypto.ec` | TLS 椭圆曲线套件 |
| `jdk.charsets` `jdk.localedata` | GB18030/GBK 与中文时区（`--include-locales=zh,en`） |
| `jdk.zipfs` | 嵌套 jar 读取 |

### 3.4 生成运行时：不需要在麒麟上构建

**先给结论**：不需要在麒麟上构建，也不需要"测试麒麟出包、生产麒麟运行"。
只要用**低 glibc 基线**的 JDK 发行版构建一次，产物就能在麒麟 V10 上直接跑。

#### 为什么（glibc 是向后兼容的）

glibc 的符号版本机制保证了：

```
低 glibc 上构建的产物  →  可在高 glibc 运行   ✅
高 glibc 上构建的产物  →  不能 在低 glibc 运行 ❌
```

实测对比（同一台 Ubuntu 24.04 机器上）：

| JDK 来源 | `libjvm.so` 需要 | 能否在麒麟 V10 (2.28) 运行 |
|---------|-----------------|--------------------------|
| Ubuntu 自带的 `openjdk-21-jdk` | `GLIBC_2.38` | ❌ 不能 |
| **Adoptium Temurin 官方 JDK 21** | **`GLIBC_2.15`** | ✅ **能** |

两者是同一台机器、同一个 jlink 命令，差异**完全来自 JDK 发行版本身**——
系统打包版会针对当前发行版重新链接，官方通用构建则保持低基线。

所以真正要控制的是"用哪个 JDK 构建"，不是"在哪台机器构建"。

#### 推荐做法：用固定版 Temurin 构建（带本地缓存）

```bash
# 一条命令：自动取固定版 Temurin，带缓存，然后 jlink
./bin/make-runtime.sh --download

# 已有 Temurin 时跳过下载，直接指定
JAVA_HOME=/opt/temurin21 ./bin/make-runtime.sh
```

**版本是写死的，不用 `latest`**：

| 项目 | 值 |
|------|-----|
| 版本 | `21.0.13+9`（Temurin LTS） |
| x64 sha256 | `d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c` |
| aarch64 sha256 | `e3522e707fc7dbe2a72c30746b1e7068301a0213ecd213d4491f35a14eb55578` |

为什么固定而不用 `latest`：

- `latest` 会随时间漂移 —— 同一个提交在不同月份构建出的包不一致，**不可复现**
- 有固定 sha256 才能校验"下到的确实是 Temurin 官方产物"，防中间人与镜像投毒
- 升级时机可控（改 `JDK_TAG` + 两个 sha256，四项一起改）

#### 两级缓存：第二次构建从 91 秒降到 4 秒

脚本在**运行脚本的这台机器**上缓存，不再每次走网络：

```
<缓存根>/jdk-21.0.13+9/
├── OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz   ← 压缩包（199MB）
└── x64/                                                 ← 解压后的 JDK（346MB）
```

命中顺序：

1. **`x64/` 存在且含 `bin/jlink`** → 直接复用，**完全不联网**（实测 4 秒）
2. **只有 `.tar.gz`** → 先校验 sha256，通过则解压复用，不联网（实测 6 秒）
3. **都没有** → 下载 → 校验 → 缓存 → 解压（实测 91 秒）

实测耗时对比：

| 场景 | 耗时 | 是否联网 |
|------|------|---------|
| 首次（缓存未命中） | **1 分 31 秒** | 是（199MB） |
| 二次（命中已解压） | **4.2 秒** | 否 |
| 二次（仅命中压缩包） | **6.0 秒** | 否 |

缓存根目录按优先级：

```bash
$TEMURIN_CACHE                     # 显式指定，适合 CI 挂载共享盘
<包根>/.cache/temurin              # 默认（已加入 .gitignore，不入库）
~/.cache/temurin                   # 包目录不可写时兜底
```

管理命令：

```bash
./bin/make-runtime.sh --clean-cache     # 清空缓存（545MB），强制重新下载
TEMURIN_CACHE=/data/ci-cache ./bin/make-runtime.sh --download   # 团队/CI 共享缓存
```

**缓存损坏会自动恢复**：脚本读到压缩包先验 sha256，不符则丢弃重下，
并打印期望值与实际值。下载过程写 `.part` 临时文件，校验通过才改名，
避免半截文件被当成有效缓存。

#### 出包前自动拦截高基线 JDK

`make-runtime.sh` 会**自动校验**产物基线并在不合格时拒绝出包：

```
产物需要   : glibc 2.38
目标基线   : glibc 2.28（麒麟 V10 默认）
[FAIL] 该 JDK 产物需要 glibc 2.38，高于目标 2.28
```

合格时：

```
产物需要   : glibc 2.15
目标基线   : glibc 2.28（麒麟 V10 默认）
[ OK ] 产物需 glibc 2.15，目标 2.28 满足，可在麒麟运行
```

目标机 glibc 实际更高时（某些麒麟 V10 SP3 补丁版本）可覆盖：

```bash
TARGET_GLIBC=$(ldd --version | head -1 | grep -oE '[0-9]+\.[0-9]+$') ./bin/make-runtime.sh --download
```

#### 如果内网无外网

**最省事的方式**：利用缓存机制，只把压缩包搬进去。

在可联网机器上（与目标同架构）：

```bash
# 固定版本，与脚本内一致
curl -fL -o OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz \
  "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz"

# 校验（必须与脚本内 sha256 一致）
sha256sum OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz
# d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c
```

拷贝到内网后放进缓存目录，脚本会**自动识别并跳过下载**：

```bash
mkdir -p <包根>/.cache/temurin/jdk-21.0.13+9
cp OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz \
   <包根>/.cache/temurin/jdk-21.0.13+9/
./bin/make-runtime.sh --download      # 校验→解压→jlink，全程不联网
```

也可以直接解压一份 Temurin 指过去（不走缓存）：

```bash
mkdir -p /opt/temurin21
tar xzf OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz -C /opt/temurin21 --strip-components=1
JAVA_HOME=/opt/temurin21 ./bin/make-runtime.sh
```

> 注意：`--download` 在离线环境**不会卡住等待网络**——只要压缩包已在缓存目录且
> sha256 通过，它就直接走解压分支。若校验失败才会尝试下载。

#### 三条替代路径（都不需要构建）

| 场景 | 做法 |
|------|------|
| 目标机已装任意 JDK 21（含毕昇/龙芯 JDK） | `export JAVA_HOME=/usr/lib/jvm/xxx`，脚本优先用它，**根本不需要 jre** |
| 目标机可联网且有内网 yum 源 | `yum install java-21-openjdk`，同上 |
| 完全离线且无任何 JDK | 用上面的离线拷贝方式 |

#### 仍需注意的唯一绑定：CPU 架构

`jre` 与 CPU 架构绑定，与 glibc 无关：

- `x86_64` 的产物不能用在 `aarch64` / 龙芯 / 申威
- 必须**按目标架构**各出一份（`make-runtime.sh --download` 会自动识别 `uname -m`）

麒麟常见架构：`x86_64`（大多数）、`aarch64`（飞腾/鲲鹏）。

> 参考：[Adoptium 关于 glibc 需求的讨论](https://github.com/adoptium/adoptium-support/issues/918)

### 3.5 探测顺序

`maxkeyctl.sh` 的优先级（`find_java()`）：

1. `$JAVA_HOME`（**会校验主版本 ≥ 21**，低于 21 时打印告警并继续找）
2. `<包根>/jre/bin/java`（内置运行时）
3. `/usr/lib/jvm/*21*`、`/opt/jdk-21*`、`/usr/java/jdk-21*`
4. `PATH` 中的 `java`

诊断命令：

```bash
./bin/maxkeyctl.sh java
# java      = /opt/maxkey/jre/bin/java
# major     = 21
# JAVA_HOME = <未设置>
```

---

## 4. 前端在麒麟上怎么跑

### 4.1 关键结论：麒麟上不需要 Node

前端是 Angular 编译产物（HTML/JS/CSS 静态文件）。**构建在开发机完成，目标机只放文件**。
麒麟上不需要装 Node、pnpm、Angular CLI，也不需要 `ng serve`。

构建命令（仅构建机执行）：

```bash
cd maxkey-web-frontend/maxkey-web-ng
pnpm install --frozen-lockfile
pnpm run build:prod        # ng b --configuration production --base-href /maxkey/

cd ../maxkey-web-mgt-ng
pnpm install --frozen-lockfile
pnpm run build:prod        # ng b --configuration production --base-href /maxkey-mgt/
```

产物在各自的 `dist/browser/`。`build-package.sh` 会自动拷到 `web/maxkey/` 与 `web/maxkey-mgt/`。

> 构建机需要 Node 22（见 `maxkey-web-ng/.nvmrc`）与 pnpm 12。

### 4.2 为什么路径前缀是 `/maxkey/` 和 `/maxkey-mgt/`

这不是随便定的，而是编译期烧进 `index.html` 的 `<base href>`，并与后端对齐：

| 前端 | base-href | 后端 API 前缀 | 后端 context-path |
|------|-----------|--------------|-------------------|
| 认证中心 | `/maxkey/` | `/sign/` | `/sign` |
| 管理端 | `/maxkey-mgt/` | `/maxkey-mgt-api/` | `/maxkey-mgt-api` |

`baseUrl` 写在 `environment.prod.ts`（[认证中心](../../maxkey-web-frontend/maxkey-web-ng/src/environments/environment.prod.ts)、[管理端](../../maxkey-web-frontend/maxkey-web-mgt-ng/src/environments/environment.prod.ts)）。
**改前缀要连 nginx 一起改**，三者必须一致。

### 4.3 路由是 hash 模式，这简化了 nginx

两个前端都是 `useHash: true`，即 `http://host/maxkey/#/passport/login`。
`#` 之后的内容浏览器不会发给服务器，所以**不存在“刷新 404”问题**。

仍保留 `try_files` 回退的原因：`index.html` 用 `<base href="./">`，
且用户可能直接粘贴无 hash 的深链接（如 `/maxkey/passport/login`）。

---

## 5. nginx：单独启动，还是合并进已有的？

### 5.1 先决判断

```bash
# 目标机上是否已有 nginx 在跑？
systemctl is-active nginx 2>/dev/null || ps -ef | grep -c "[n]ginx: master"
ss -lntp | grep -E ':(80|443)\b'
```

- **没有 nginx** → 用方案 A（独立站点），装 nginx 包即可
- **已有 nginx 且 80 端口被占用** → 用方案 B（合并），**不必为此再起一个实例**
- **已有 nginx 但端口/目录完全隔离（如容器化）** → 也可用方案 A

### 5.2 方案 A：独立 nginx 站点

```bash
cp nginx/maxkey-standalone.conf  /etc/nginx/conf.d/maxkey.conf
cp nginx/maxkey-proxy.conf       /etc/nginx/maxkey-proxy.conf
mkdir -p /opt/maxkey/web
cp -a web/maxkey web/maxkey-mgt /opt/maxkey/web/
nginx -t && nginx -s reload
```

`maxkey-standalone.conf` 里 `root /opt/maxkey/web;`，靠 URI 前缀 `/maxkey/`
天然对上子目录，**不需要 alias**。

### 5.3 方案 B：合并进已有 nginx（推荐）

**不新建 server 块**，把 `nginx/maxkey-into-existing.conf` 的内容追加到
现有站点的 `server { }` 内部，或存成独立文件后 `include`：

```nginx
server {
    listen 80;
    server_name your-existing-site.gov.cn;
    root /var/www/your-site;          # 别人的根目录，不能动

    # ... 原有配置 ...

    include /etc/nginx/maxkey-locations.conf;   # ← 只加这一行
}
```

推荐 `include` 而非直接粘贴：升级 MaxKey 时只替换被 include 的文件，不碰别人的配置。

#### 三个必须避开的坑（都是实测出来的）

**坑 1：不能用 `alias` + `try_files`**

原先以为这样更“干净”：

```nginx
location /maxkey/ {
    alias /opt/maxkey/web/maxkey/;
    try_files $uri $uri/ /maxkey/index.html;   # ← 错
}
```

实测结果：`/maxkey/` 返回 200，但**深链接和 assets 全部 404**。
nginx 的 `alias` 与 `try_files` 组合有已知缺陷。

正确写法——用 `root`，让 URI 前缀自然映射到子目录：

```nginx
location /maxkey/ {
    root /opt/maxkey/web;                       # 注意：指向父目录
    try_files $uri $uri/ /maxkey/index.html;
}
```

因为 `root` + URI `/maxkey/x.js` = `/opt/maxkey/web/maxkey/x.js`，
子目录名恰好等于 URI 前缀，所以不需要 `alias`。

**坑 2：静态资源缺失必须真 404，不能回退到 index.html**

```nginx
location ^~ /maxkey/assets/ {
    root /opt/maxkey/web;
    try_files $uri =404;      # ← =404 而不是 /maxkey/index.html
    expires 7d;
}
```

若回退到 `index.html`，浏览器会以 `text/html` 解析 `.js`，报
`Unsupported MIME type` / `Unexpected token '<'`，排查成本极高。
`^~` 前缀保证它优先于后面的 SPA 回退。

**坑 3：`proxy_pass` 尾部斜杠不能漏**

```nginx
location /sign/ {
    proxy_pass http://127.0.0.1:9527/sign/;    # ← 必须有尾部斜杠和 /sign
}
```

后端 context-path 是 `/sign`，前端 `baseUrl` 是 `/sign/`。
写成 `proxy_pass http://127.0.0.1:9527;` 会丢路径前缀，所有 API 404。

#### 实测结果（隔离实例，端口 18090）

| 请求 | 结果 |
|------|------|
| `/maxkey/` | 200 index.html |
| `/maxkey/passport/login` | 200 index.html（回退生效） |
| `/maxkey/assets/a.js` | 200 静态文件 |
| `/maxkey/assets/nope.js` | **404**（未误回退） |
| `/maxkey-mgt/dashboard` | 200 |
| `/sign/inst/get` | 200 透传到后端 |

### 5.4 反代必须带的头

见 `nginx/maxkey-proxy.conf`。其中两个不是“锦上添花”而是功能必需：

- **`Host`**：后端 [WebInstRequestFilter.java:58-67](../../maxkey-starter/maxkey-starter-web/src/main/java/org/dromara/maxkey/web/WebInstRequestFilter.java#L58-L67)
  用 `Host` 头查租户（机构）。丢了域名，多租户全部退回默认租户。
- **`X-Forwarded-Proto` / `X-Forwarded-Port`**：OIDC 元数据端点用
  `WebContext.getContextPath()` 从**当前请求**推导 URL。不传这些头，
  会发现文档里出现 `http://127.0.0.1/sign/...` 这类内网地址。

实测对比（同一后端，只改请求头）：

```
无 Host（默认）      → issuer = http://127.0.0.1/sign/maxkey
Host: sso.xxx.local  → issuer = http://sso.xxx.local/sign/maxkey
```

### 5.5 HTTPS

若前端用 https 反代，还需在 `conf/maxkey.env` 改：

```bash
MAXKEY_SCHEME=https
```

因为 `maxkey.server.scheme` 在 properties 里写死为 `http`
（[application-maxkey.properties:33](../../maxkey-webs/maxkey-web-maxkey/src/main/resources/application-maxkey.properties#L33)），
脚本用 `-Dmaxkey.server.scheme=...` 覆盖。

注意：Passkey/WebAuthn 的 allowed-origins 也需同步改
（`maxkey.login.passkey.relying-party.*`），否则生物识别登录会失败。

---

## 6. 后端启动

### 6.1 配置

只需改 `conf/maxkey.env`。三个**容易踩的结构性坑**已在该文件内注明：

1. **JDBC URL 必须加引号**——`&` 是 shell 的后台分隔符。
   裸写会让 `DATABASE_URL` 变成空串，应用静默回落到内置 MySQL 默认值，
   表现为“配了 Kingbase 却连 3306”。
2. **`DATABASE_COLUMN_ESCAPE_CHAR` 用单引号包裹一个双引号**——
   Kingbase 在 MySQL 兼容模式下 `online` 是保留字，必须用双引号转义标识符。
3. **端口用 `PORTAL_PORT`/`MGT_PORT`**，脚本会翻译成 `SERVER_PORT` 分别下发
   （两个应用端口不同，不能共用同一个环境变量）。

`maxkeyctl.sh` 会对第 1 类错误做**显式校验**并在启动前报错退出，
而不是让它静默生效。

#### 数据库口令：不落在配置文件里

`conf/maxkey.env` 是**被 git 跟踪的模板**。若在其中填明文口令，
`git add` 会把口令永久写入提交历史，事后删除也无法真正抹除。
因此口令改为运行期注入，配置文件里只有一行继承：

```bash
DATABASE_PWD="${DATABASE_PWD:-}"
```

三种注入方式（按推荐度）：

| 方式 | 做法 | 适用 |
|------|------|------|
| **独立密钥文件**（推荐） | `/etc/maxkey/maxkey-secret.env`，600 root:root，systemd 单元已引用 | 生产 |
| systemd 内联 | 单元里 `Environment="DATABASE_PWD=..."`（单元需 600） | 临时 |
| 环境变量 | `export DATABASE_PWD=... && ./bin/maxkeyctl.sh start` | 调试 |

密钥文件模板见 `conf/maxkey-secret.env.example`，格式要求：

- 每行 `KEY=VALUE`，**不要写 `export`**
- 口令含 `$` `` ` `` `\` `"` 时**必须用单引号**包裹，否则会被变量展开
- systemd 对单引号的处理与 POSIX shell 一致（剥掉引号），
  所以 `DATABASE_PWD='p@ss'` 传给进程的是 `p@ss`

> 未注入时 `maxkeyctl.sh` 会在启动前显式报错并给出注入指引，
> 不会让你带着空口令去撞一个 `password authentication failed`。

### 6.2 启动

```bash
./bin/maxkeyctl.sh start          # 两个都起
./bin/maxkeyctl.sh start portal   # 只起认证中心
./bin/maxkeyctl.sh status
./bin/maxkeyctl.sh stop
```

脚本在启动后会**轮询端口**直到就绪才返回成功，避免
“脚本说成功了但进程已退出”的假成功。

实测启动耗时：**6–8 秒**（jlink 运行时 64MB，已导入 44 表）。
已从 `/`（根目录）以无 `JAVA_HOME` 的方式验证过，日志正确落在应用目录。
`start` 返回成功即代表端口已监听，可直接用于自动化脚本。

### 6.3 systemd 托管

```bash
useradd -r -s /sbin/nologin maxkey
chown -R maxkey:maxkey /opt/maxkey
cp systemd/*.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now maxkey-portal maxkey-mgt
journalctl -u maxkey-portal -f
```

`maxkey-mgt.service` 声明了 `Requires=maxkey-portal.service`——
管理端登录走 CAS，依赖认证中心。

### 6.4 日志

应用日志由 log4j2 输出到 `logs/maxkey.log`（相对路径，所以脚本会
`cd` 到应用目录再启动，否则日志会散落到调用者当前目录）。

`logs/nohup-*.out` 存放 stdout/stderr。脚本会在超过 50MB 时自动轮转——
这一点是踩坑加的：一次排障中该文件涨到 **14GB** 并耗尽磁盘。

---

## 7. 域名在本项目里如何起作用

这是三个**互相独立**的作用，很容易混为一谈。

### 7.1 作用一：租户（机构）识别 —— 按 `Host` 头查库

请求进来后，`WebInstRequestFilter` 取 `Host` 头，去掉端口，去
`mxk_institutions` 表按 `id` / `domain` / `consoledomain` 三列查：

```sql
-- InstitutionsMapper.java:26
select * from mxk_institutions
where (id = ? or domain = ? or consoledomain = ?) and status = 1
```

查到的机构放进 Session 的 `current_inst`，之后登录页标题、Logo、
验证码策略、社交登录配置都按这个机构取。

实测（`mxk_institutions` 中 `domain='sso.kylin-test.local'`）：

```
Host: sso.kylin-test.local   → 命中，inst id=1, domain=sso.kylin-test.local
Host: mgt.kylin-test.local   → 命中（consoledomain），inst id=1
Host: random.example         → 未命中，回退默认 inst id=1
Host: (无)                   → 使用 maxkey.server.domain 配置值
```

**两个要点**：

- **未命中不报错，静默回退默认机构（id=1）**。所以单租户场景下
  域名配错不会报错，只会“看起来正常但用的是默认配置”——很隐蔽。
- **机构有 60 分钟 Caffeine 缓存**（[InstitutionsServiceImpl.java:42](../../maxkey-persistence/src/main/java/org/dromara/maxkey/persistence/service/impl/InstitutionsServiceImpl.java#L42)）。
  改了 `mxk_institutions.domain` 后**必须重启或等缓存过期**才生效。
  实测：改完 DB 立即查仍是旧值，重启后立即正确。

### 7.2 作用二：拼接 SSO 回跳地址 —— 来自配置文件

这些是**配置值**（不来自请求头），在 [application-maxkey.properties:34-44](../../maxkey-webs/maxkey-web-maxkey/src/main/resources/application-maxkey.properties#L34-L44)：

```properties
maxkey.server.basedomain   = ${SERVER_DOMAIN:maxkey.top}
maxkey.server.domain       = sso.${maxkey.server.basedomain}     # ← 硬拼 sso. 前缀
maxkey.server.name         = ${maxkey.server.scheme}://${maxkey.server.domain}
maxkey.server.uri          = ${maxkey.server.name}:${server.port}${context-path}
maxkey.server.frontend.uri = /maxkey
```

**注意 `sso.` 是写死的前缀**。若真实域名是 `sso.gov.cn`，要把
`SERVER_DOMAIN` 设为 `gov.cn`（得到 `sso.gov.cn`）；
若域名不含 `sso` 前缀（如 `cas.abc.com`），只设 `SERVER_DOMAIN` 得不到想要的结果，
需要直接覆盖 `maxkey.server.domain`。

未登录访问受保护端点时的跳转（实现在
[SingleSignOnInterceptor.java:72](../../maxkey-webs/maxkey-web-maxkey/src/main/java/org/dromara/maxkey/web/interceptor/SingleSignOnInterceptor.java#L72)）：

```
302 → {frontend.uri}/#/passport/login?redirect_uri={base64(原始URL)}
```

实测：

```
302 Location: http://sso.kylin-test.local/maxkey/#/passport/login?redirect_uri=aHR0cDovL3Nzby5reWxpbi10ZXN0LmxvY2Fs...
解码后:        http://sso.kylin-test.local/sign/authz/oauth/v20/authorize?client_id=x&response_type=code
```

`maxkey.server.frontend.uri` 在这里是**相对路径 `/maxkey`**，
浏览器按当前站点拼接，所以换域名时这部分自动跟随。
这是 Minimal-SSO 友好的设计——不需要为每个环境改这一段。

### 7.3 作用三：JWT 的 `iss` 声明

`maxkey.auth.jwt.issuer = ${maxkey.server.uri}`，
即 `http://sso.<domain>:<port>/sign`。

实测解出的 JWT payload：

```json
{ "iss": "http://sso.kylin-test.local:29527/sign", "sub": "admin", ... }
```

而校验只验签 + 校验过期（`validateJwtToken` 不校验 `iss`），
所以**改域名不会导致已有 token 失效**，这点对升级平滑有利。

但要注意：`iss` 里带**内部端口 29527**（因为 `server.uri` 拼了 `server.port`）。
如果要把 token 交给外部系统校验，这个 `iss` 是他们看到的“issuer 名字”，
按需用 `LOGIN_JWT_ISSUER` 覆盖。

### 7.4 三处作用汇总

| 作用 | 取值来源 | 配错的表现 | 改后是否需重启 |
|------|---------|-----------|--------------|
| 租户识别 | 请求头 `Host` → 查 `mxk_institutions` | 静默回退默认机构，页面 Logo/标题不对 | **需要**（60 分钟缓存） |
| SSO 回跳地址 | `maxkey.server.frontend.uri`（相对路径） | 跳转到错误站点 | 需要 |
| JWT `iss` | `maxkey.server.uri` | 外部系统校验 issuer 失败 | 需要 |

---

## 8. SSO 最小化：只保留什么

### 8.1 必须启动

| 组件 | 端口 | 作用 | 能否省 |
|------|------|------|--------|
| `maxkey` | 9527 | 认证中心：登录、发 token、OAuth/CAS/SAML/OIDC 端点 | **不能** |
| `maxkey_mgt` | 9526 | 管理端：应用/用户/机构配置 | **不能**（否则无法配置应用接入） |
| nginx | 80/443 | 静态前端 + 反代 | **不能**（前端是纯静态） |
| KingbaseES | 54321 | 数据库 | **不能** |

### 8.2 可以不启动

| 组件 | 端口 | 说明 |
|------|------|------|
| `maxkey-web-openapi` | 9525 | SCIM/开放 API，SSO 核心流程不依赖 |
| `maxkey-gataway` | 9000 | Spring Cloud Gateway，单机不需要 |
| Redis | 6379 | 默认 `SERVER_PERSISTENCE=0` 即内存会话，单实例够用 |
| RocketMQ / Nacos | - | 非 SSO 必需 |

> 注意 Redis 的取舍：`maxkey.server.persistence` 默认 `0`（内存）。
> 会话存在 JVM 内存里，**重启会丢登录态**，且不支持多实例。
> 若将来要横向扩展再切 `2`（Redis），当前最小化不需要。

### 8.3 建议关闭的功能（减少依赖面）

在 `conf/maxkey.env`：

```bash
LOGIN_MFA_ENABLED=false    # 无短信/邮箱通道时关掉 TOTP
LOGIN_CAPTCHA=true         # 生产建议开；内网联调可关
```

Passkey 相关的 `maxkey.login.passkey.*` 默认 `localhost`，
公网域名下如需 Passkey 要改 riding-party id 与 allowed-origins，否则浏览器会拒绝。

### 8.4 单点登录闭环的最短路径

1. 启动 `maxkey` + `maxkey_mgt` + nginx
2. 登录管理端 → 配置「机构」域名（与 nginx `server_name` 一致）
3. 配置「应用」→ 选协议（OAuth2/CAS/OIDC/SAML）→ 填回调地址
4. 业务系统按所选协议接入
5. 用户访问业务系统 → 未登录 → 302 到 `/maxkey/#/passport/login` → 登录 → 回跳

第 3 步的回调地址必须与后端 `applicationConfig` 生成的 issuer 对得上，
否则 OAuth 会报 `redirect_uri mismatch`。这是最常见的接入故障。

---

## 9. 麒麟部署 checklist

```bash
# 1. 解包并统一到 /opt/maxkey
tar xzf maxkey-kylin-4.2.0.tar.gz -C /opt
mv /opt/maxkey-kylin-4.2.0 /opt/maxkey
cd /opt/maxkey

# 2. 环境自检（强烈建议先跑，一次暴露所有阻塞项）
./bin/preflight.sh
#   检查项：系统/架构、glibc 基线、JDK 版本、AWT 字体、
#           配置语法与关键字段、端口占用、Kingbase 连通与建表、
#           nginx/SELinux/firewalld、目录权限
#   输出 24 项通过 / 1 警告 / 1 阻塞 这类汇总，有阻塞则退出码 1

# 3. 确认 JDK（二选一）
./bin/maxkeyctl.sh java         # 若显示 major=21 即可用
./bin/make-runtime.sh           # 或现场生成内置运行时

# 4. 建库
ksql -U system -d maxkey -f sql/maxkey.sql

# 5. 改配置（域名、数据库地址等；**口令不写在这里**）
vi conf/maxkey.env

# 5.1 注入数据库口令（必需，否则启动会被显式拦下）
#     口令不写入 conf/maxkey.env —— 那是被 git 跟踪的模板，
#     填明文会直接进提交历史。改用仓库外的独立密钥文件。
sudo mkdir -p /etc/maxkey
sudo cp conf/maxkey-secret.env.example /etc/maxkey/maxkey-secret.env
sudo vi /etc/maxkey/maxkey-secret.env        # 填入真实口令
sudo chown root:root /etc/maxkey/maxkey-secret.env
sudo chmod 600 /etc/maxkey/maxkey-secret.env

#     手工启动（不走 systemd）则直接导出环境变量即可：
#     export DATABASE_PWD='实际口令' && ./bin/maxkeyctl.sh start

# 6. 部署前端与 nginx（选方案 A 或 B）
mkdir -p /opt/maxkey/web
cp -a web/maxkey web/maxkey-mgt /opt/maxkey/web/
# 方案A:
cp nginx/maxkey-standalone.conf /etc/nginx/conf.d/maxkey.conf
cp nginx/maxkey-proxy.conf      /etc/nginx/maxkey-proxy.conf
# 方案B: 把 nginx/maxkey-into-existing.conf include 进现有 server{}
nginx -t && nginx -s reload

# 7. 启动
./bin/maxkeyctl.sh start
./bin/maxkeyctl.sh status

# 8. 验证
curl -s -H "Host: <你的域名>" http://127.0.0.1/sign/inst/get
# 期望：返回机构的 domain 与你配置的域名一致（不一致说明缓存或配置问题）
```

---

## 10. 排障速查

| 现象 | 根因 | 处理 |
|------|------|------|
| `UnsupportedClassVersionError` | JDK < 21 | `./bin/maxkeyctl.sh java` 查看；改用内置 jre |
| `GLIBC_2.3x not found` | 用系统自带 JDK 构建，基线过高 | 改用 Temurin：`./bin/make-runtime.sh --download`（基线 2.15）；详见 §3.4 |
| 配了 Kingbase 却连 3306 | JDBC URL 中 `&` 被 shell 截断 | URL 加单引号（脚本已做校验） |
| `online` 列名报错 | 未开启标识符转义 | `DATABASE_COLUMN_ESCAPE=true` + 转义符 `"` |
| **能登录但返回 code=2，日志 `bad SQL grammar ... online = 1`** | 手写 SQL 绕过标识符转义（见 §11.2） | 需代码修复；仅配 `DATABASE_COLUMN_ESCAPE` 无效 |
| 分页 SQL 报错 | 方言未生效 | `DATABASE_DIALECT=kingbase` |
| 页面能开但 API 全 404 | `proxy_pass` 漏尾部路径 | `proxy_pass .../sign/;` |
| JS 报 `Unexpected token '<'` | 静态资源被回退成 index.html | 加 `try_files $uri =404` |
| 改了机构域名不生效 | 60 分钟 Caffeine 缓存 | 重启 `maxkey` |
| 登录后跳到 `127.0.0.1` | 缺 `Host` / `X-Forwarded-*` 头 | 引 `maxkey-proxy.conf` |
| 日志文件涨到 GB | 未轮转 | 脚本已加 50MB 轮转；生产可用 logrotate |

---

## 11. 实测验证记录

### 11.1 真实 KingbaseES 环境验证（2026-10-28）

**环境**：KingbaseES `V009R003C018`（= V9R3C18），`database_mode=mysql`，`UTF8`，
`maxkey` 库 44 表 / 60 用户 / 34 应用，账号 `maxkey`。
应用运行在 `jlink` 裁剪运行时（64MB，Temurin 构建）上，`DATABASE_DIALECT=kingbase` +
`DATABASE_COLUMN_ESCAPE=true` + 转义符 `"`。

| 验证项 | 方法 | 结果 |
|--------|------|------|
| 真实 Kingbase 连接 | `kingbase8` 驱动 → 54321 | ✅ `connected: KingbaseES 12.1` |
| 应用连接真实 Kingbase | 启动日志中的 JDBC URL | ✅ `jdbc:kingbase8://127.0.0.1:54321/maxkey` |
| 应用启动 | `maxkeyctl.sh start portal` | ✅ 6–8s，无 SQL 错误 |
| 读取数据 | `GET /sign/inst/get` | ✅ 返回真实机构数据 |
| **admin 登录** | `POST /sign/login/signin` | ✅ `code=0`，8 个权限 |
| **登录状态回写** | 查 `mxk_userinfo` | ✅ `logincount` 1841→1842，`online=1` |
| JWT 签发 | 解析 token | ✅ `iss=http://sso.kylin-test.local:29527/sign` |
| SSO 回跳 | 未登录访问 authz 端点 | ✅ 302 → `/maxkey/#/passport/login?redirect_uri=...` |
| 租户按 Host 解析 | 变更 `Host` 头 | ✅ 命中 `domain` / `consoledomain` |
| 机构 60 分钟缓存 | 改库后立即查 vs 重启后查 | ✅ 立即查仍旧值，重启后生效 |
| `online` 保留字 | `select id,online from ...` | ✅ 裸写报 `syntax error at or near "online"`；`"online"` 正常 |
| 分页方言 | 对比 `getPreparedStatementLimitString` | ✅ MySQL `limit ? , ?`；kingbase `limit ? offset ?` |
| 分页 SQL 可执行 | JDBC 参数化执行两种写法 | ✅ `LIMIT ? OFFSET ?` rows=10 |
| 关键字方言表 | 反射查 `DialectMapper` | ✅ 内置无 kingbase，注册后映射到 `KingbaseDialect`（父类 `PostgreSQLDialect`） |

**本节最重要的发现**：这一轮真实 Kingbase 验证暴露了一个此前 MySQL 环境下
**不可能发现**的生产级缺陷，见 §11.2。

### 11.2 真实 Kingbase 暴露并已修复的缺陷：硬编码 SQL 绕过标识符转义

**现象**：登录接口返回 `code=2`，但日志显示认证本身已成功
（`'admin' authenticated successfully`），JWT 也已签发。

**根因**：

```
PreparedStatementCallback; bad SQL grammar
[update mxk_userinfo set badpasswordcount = 0 , logincount = logincount + 1 ,
 lastlogintime = ?  , lastloginip = ? , online = 1  where id = ?]
```

`LoginServiceImpl` 里这条 SQL 是**手写字符串常量**，走 `jdbcTemplate`，
不经过 MyBatis 的 mapper XML。而 `mybatis.table-column-escape` 只对
XML 生成的 SQL 生效，**对手写 SQL 完全无效**。

KingbaseES 在 MySQL 兼容模式下 `online` 是保留字（`catcode=R`，已实测确认），
裸写必然报错。后果不只是"登录失败"：

- 用户已通过密码校验，但接口最终返回失败
- `logincount`、`online`、`lastlogintime`、`lastloginip` 全部没写进去
- 表现为"能登录但登录统计/在线状态永远不更新"

**修复**（[LoginServiceImpl.java:416](../../maxkey-persistence/src/main/java/org/dromara/maxkey/persistence/service/impl/LoginServiceImpl.java#L416)）：
新增 `buildLoginUserinfoUpdateStatement()`，按与 mybatis **同一套**
`table-column-escape` / `-escape-char` 配置动态拼接列名。

**兼容性证明**：未开启转义时（MySQL 默认部署）生成的 SQL 与历史硬编码版本
**逐字节一致**，零回归：

```
默认(MySQL) 生成的SQL: ... , online = 1  where id = ?
历史硬编码SQL        : ... , online = 1  where id = ?
是否逐字节一致? true
```

**修复后实测**：`logincount` 1841 → 1842，`"online"=1`，登录时间正确写入 Kingbase。

> 这条缺陷说明"用 PostgreSQL 代替验证"是不够的：PostgreSQL 建表时
> `online` 不是保留字，所以同名 SQL 在 PG 上能通过，问题被掩盖。
> **必须用真实 KingbaseES 验证**。

### 11.3 通用验证（MySQL / nginx / 运行时）

| 验证项 | 方法 | 结果 |
|--------|------|------|
| 裁剪运行时能启动 | `jre/bin/java -jar maxkey-boot.jar` | ✅ 6–8s 启动 |
| 缺 `java.desktop` 会失败 | 去掉该模块重建运行时 | ❌ `NoClassDefFoundError: java/beans/PropertyChangeEvent`（证明必须保留） |
| headless 渲染验证码 | 请求 `/sign/captcha` | ✅ 输出 120×40 PNG，3508 字节 |
| nginx 独立站点 | 方案 A 配置实测 | ✅ index/深链接/assets 200，缺失资源 404 |
| nginx 合并进已有站点 | 现有站点 + MaxKey 片段共存 | ✅ 双方均正常，互不影响 |
| `alias` + `try_files` | 按该写法部署 | ❌ 深链接/assets 404（故改用 `root`） |
| 配置错误的静默失败 | 裸 `&` 的 JDBC URL | ❌ `DATABASE_URL` 变空串并回落 MySQL（已加启动前校验） |
| 从任意目录启动 | `cd /` 后执行脚本 | ✅ 日志正确落在应用目录 |
| 无 `JAVA_HOME` 启动 | `env -u JAVA_HOME` | ✅ 自动使用包内 `jre/` |

### 11.4 glibc 问题已解决（原为"唯一硬阻塞"，现已消除）

**原判断**：jre 在 Ubuntu 24.04 构建，需 `GLIBC_2.38`，麒麟 V10 是 2.28，
因此"必须在麒麟上构建"。

**修正后的结论**：该判断**过窄**。glibc 向后兼容，真正决定基线的是
**用哪个 JDK 发行版构建**，而非构建机器的操作系统。

实测证据（同一台 Ubuntu 24.04、同一条 jlink 命令）：

| 构建用 JDK | `libjvm.so` 需要 glibc | 麒麟 V10 (2.28) 可用 |
|-----------|----------------------|---------------------|
| Ubuntu 自带 `openjdk-21-jdk` | `GLIBC_2.38` | ❌ |
| **Adoptium Temurin 21** | **`GLIBC_2.15`** | ✅ |
| 系统 `openjdk-17`（同为 Ubuntu 包） | `GLIBC_2.38` | ❌ |

**已固化为工具约束**：`make-runtime.sh` 现在会读取 `libjvm.so` 的
`GLIBC_*` 符号版本，与 `TARGET_GLIBC`（默认 2.28）比较，不合格直接拒绝出包，
并给出 Temurin 下载命令。同时新增 `--download` 一键获取 Temurin。

**已端到端验证**：用 `--download` 生成的 64MB 运行时启动应用，
在真实 KingbaseES 上 `admin` 登录 `code=0`、零 SQL 错误、SSO 回跳正常。

**缓存机制实测（同一台机器）**：

| 场景 | 耗时 | 联网 |
|------|------|------|
| 首次（无缓存） | 1 分 31 秒 | 是 |
| 二次（命中解压目录） | **4.2 秒** | 否 |
| 二次（仅命中压缩包） | 6.0 秒 | 否 |
| 全新包目录 + `TEMURIN_CACHE` 共享 | **4.2 秒** | 否 |
| 缓存包被篡改（写入垃圾字节） | 自动丢弃并重下，日志打印期望/实际 sha256 | 是 |
| `--clean-cache` | 删除 545MB，幂等 | — |

固定版本 `21.0.13+9`，x64 sha256 已实测与 Adoptium API 返回值一致
（`d7f5d5cf...d66d1c`），脚本内置该校验值。

**因此交付路径简化为**：

```
任意一台可联网 Linux（x86_64）
   └─ ./make-runtime.sh --download     ← 自动取 Temurin（基线 2.15）
        └─ 产物 jre/ + 整个部署包      ← 可直接拷到生产麒麟
```

不再需要"测试麒麟出包、生产麒麟运行"，也不需要两台麒麟。

### 11.5 仍需在目标环境确认的项

- **CPU 架构**：本次为 `x86_64`。若生产是飞腾/鲲鹏（`aarch64`）或龙芯，
  须在对应架构机器上重跑 `make-runtime.sh --download`（脚本会自动识别 `uname -m`）。
  **这是唯一仍与运行环境绑定的因素。**
- **管理端（9526）**：`maxkey-mgt-boot` 因构建环境 Gradle native 库
  （`libnative-platform.so`）无法加载而未能重新打包，其启动与 `/users/query`
  分页未在本轮实测；逻辑与认证中心同源（同一套 dialect 与转义配置），
  风险低但建议正式构建后复验。
- **glibc 实际版本**：麒麟 V10 各 SP 版本基线略有差异，部署前用
  `./bin/preflight.sh` 确认，必要时用 `TARGET_GLIBC=` 调整。
