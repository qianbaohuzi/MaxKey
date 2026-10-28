# MaxKey 裸机部署方案（KingbaseES + 内置精简 JDK + 公共 nginx）

> 配套脚本位于 `deployment/kylin/`。本文所有结论均来自实测，验证记录见 §11。
>
> 目标形态：**两个 jar + 一个 jlink 运行时 + 一份 nginx 站点文件**，
> 不依赖目标机 JDK，不要求 Docker，不动目标机已有的 nginx 站点。

---

## 1. 结论速览

| 问题 | 结论 |
|------|------|
| 目标机没有 JDK 21 怎么办 | 包内内置 **jlink 裁剪运行时**（实测 59MB），不依赖目标机 JDK |
| 内置 JDK 会不会被目标机的 Java 顶掉 | 不会。`maxkeyctl.sh` 把**包内 jre 放在探测顺序第一位**（见 §4.4） |
| 运行时缺模块会怎样 | `maxkeyctl.sh start` 会**先跑自检**，直接报"缺 java.desktop"这类结论（见 §4.5） |
| 前端怎么部署 | 纯静态文件，不需要 Node；nginx 指到 `/opt/maxkey/web` 即可 |
| 公共 nginx 怎么接入 | 新增一个**独立 server 块**的 conf.d 文件，不改别人的站点（见 §6） |
| 怎么避免影响其他应用 | 独立 `server_name`；只新增 2 个文件；安装脚本检测域名冲突并中止 |
| SSO 最小化跑哪些进程 | 只跑 `maxkey`(9527) + `maxkey_mgt`(9526)，不启 openapi / gateway / Redis |
| 数据库 | KingbaseES（实测 V009R003C018）。建库用 0.4MB 的最小种子脚本（见 §9） |
| 容器化 | 已整条移除，仓库不再保留任何 Dockerfile / compose / k8s 资产 |

**最小化拓扑**

```
浏览器 ──443──> 公共 nginx ──/maxkey/─────────> 静态文件  /opt/maxkey/web/maxkey
                   │         ──/maxkey-mgt/────> 静态文件  /opt/maxkey/web/maxkey-mgt
                   ├──/sign/──────────────> maxkey      127.0.0.1:9527  (认证中心)
                   └──/maxkey-mgt-api/────> maxkey_mgt  127.0.0.1:9526  (管理端 API)
                                                    │
                                                    └──> KingbaseES 54321
```

---

## 2. 部署包结构

`deployment/kylin/build-package.sh` 产出 `maxkey-deploy-<version>.tar.gz`。

```
maxkey-deploy-4.2.0/
├── install.sh                一键落地（幂等，支持 --dry-run）
├── uninstall.sh              撤销（默认保留配置与数据）
├── maxkey/                   maxkey-boot-*.jar      ← 认证中心
├── maxkey_mgt/               maxkey-mgt-boot-*.jar  ← 管理端
├── web/
│   ├── maxkey/               maxkey-web-ng 的 dist/browser
│   └── maxkey-mgt/           maxkey-web-mgt-ng 的 dist/browser
├── jre/                      jlink 裁剪运行时（约 59MB，可选但强烈建议）
├── conf/
│   ├── maxkey.env            唯一需要改的配置文件
│   └── maxkey-secret.env.example  数据库口令模板
├── bin/
│   ├── maxkeyctl.sh          启停/状态/诊断/运行时自检
│   ├── make-runtime.sh       生成内置运行时（Temurin 固定版 + sha256）
│   └── preflight.sh          部署前环境自检
├── nginx/
│   ├── maxkey-site.conf      站点配置（独立 server 块）
│   └── maxkey-proxy.conf     反代公共头
├── systemd/                  maxkey-portal.service / maxkey-mgt.service
└── sql/
    ├── maxkey-seed.sql       KingbaseES 最小种子建库脚本（0.4MB / 44 表）
    └── make-seed.py          种子脚本生成器（可重新生成与自检）
```

---

## 3. 快速开始

```bash
tar xzf maxkey-deploy-4.2.0.tar.gz
cd maxkey-deploy-4.2.0

# 1. 改配置：必须改的只有这几处
vi conf/maxkey.env
#    SERVER_DOMAIN=example.gov.cn                  ← 主域名
#    MAXKEY_PUBLIC_URL=https://sso.example.gov.cn   ← 对外访问地址（见 §7）
#    NGINX_SERVER_NAME / NGINX_TLS_PORT / NGINX_CERT / NGINX_KEY
#    DATABASE_URL / DATABASE_USER

# 2. 先演练，确认将要做的事（不需要 root 也能跑）
./install.sh --dry-run

# 3. 真正落地：建用户、装文件、装 systemd、放 nginx 配置
sudo ./install.sh

# 4. 填数据库口令（不在 conf/maxkey.env 里，避免入 git）
sudo vi /etc/maxkey/maxkey-secret.env     # 仅一行 DATABASE_PWD='实际口令'
sudo chmod 600 /etc/maxkey/maxkey-secret.env

# 5. 建库
ksql -U maxkey -d maxkey -f sql/maxkey-seed.sql

# 6. 环境自检（一次性暴露所有阻塞项）
sudo ./bin/preflight.sh

# 7. 启动
sudo ./bin/maxkeyctl.sh start
sudo ./bin/maxkeyctl.sh status

# 8. 验证
curl -sk -H 'Host: sso.example.gov.cn' \
     https://sso.example.gov.cn/sign/authz/oauth/v20/.well-known/openid-configuration
```

浏览器打开 `https://sso.example.gov.cn/maxkey/`，
初始账号 **admin / maxkey** —— 上线前必须立即改密，
并把「机构」的 domain 改成真实域名。

---

## 4. 内置 JDK：为什么必须裁，怎么裁，怎么防被顶掉

### 4.1 硬约束

MaxKey 4.2.0 编译目标是 Java 21（`build.gradle` 里
`sourceCompatibility/targetCompatibility = VERSION_21`，且低于 21 直接抛
`GradleException`）。jar 内 class 文件 major 版本 65。

多数信创环境的系统 JDK 是 8/11/17，直接用会抛
`UnsupportedClassVersionError`。而"让现场先装个 JDK 21"在内网往往做不到。

### 4.2 方案对比

| 方案 | 体积 | 问题 |
|------|------|------|
| A. 要求现场装 JDK 21 | 0 | 信创内网常无源；且要改动目标机 |
| B. 包内放完整 JDK | ~300MB | 2/3 的模块用不到 |
| **C. 包内放 jlink 裁剪运行时** | **59MB** | 与 CPU 架构绑定；glibc 基线取决于构建所用 JDK（见 §4.3） |

采用 C。

### 4.3 glibc 基线：不必在麒麟上构建

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

### 4.4 内置运行时如何不被目标机 JDK 顶掉

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

### 4.5 模块清单与运行时自检

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

## 5. 前端：纯静态，不需要 Node

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

## 6. nginx：接进公共实例，不影响其他应用

### 6.1 设计取舍

目标机 nginx 是公共的，本机实测 80 端口已被另一个站点占用
（`listen 80; server_name localhost;`）。三种做法里选第三种：

| 做法 | 问题 |
|------|------|
| 另起一个 nginx 实例 | 多一个进程、多一套配置要维护 |
| 往别人的 `server{}` 里塞 location | Cookie 作用域与对方重叠；对方改配置会牵连 MaxKey |
| **新增独立 server 块（conf.d 一个文件）** | **选用**。隔离干净，升级只替换自己的文件 |

具体形态：`conf.d/maxkey.conf` + `/etc/nginx/maxkey-proxy.conf`，
共 2 个文件，**不触碰任何已有站点文件**。

### 6.2 安装位置

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

### 6.3 四个必须避开的坑（都是实测出来的）

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

### 6.4 反代必须带的头

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

### 6.5 HTTPS 与证书

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

## 7. 对外地址：`MAXKEY_PUBLIC_URL` 是唯一入口

这是整套配置里最容易搞错、也最容易出"能登录但立刻掉线"的地方。

后端有**两处**需要"对外地址"，但取法完全不同：

| 用途 | 取值方式 | 可否请求推导 |
|------|---------|-------------|
| JWT 的 `iss`（`maxkey.auth.jwt.issuer` ← `maxkey.server.uri`） | **固定配置值** | **不能** |
| OIDC 元数据 `issuer` / 各 `*_endpoint` | 由当前请求推导 | 必须（见 §7.2） |

### 7.1 JWT 的 iss 必须是固定值

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

### 7.2 OIDC 元数据必须按请求推导

OIDC 元数据由 `WebContext.getContextPath(true)` 生成，内部走
`UrlUtils.buildFullRequestUrl(request)`，取的是**当前请求**的
scheme/port/host。

因此后端开了 `server.forward-headers-strategy=NATIVE`
（Tomcat `RemoteIpValve`），配合 nginx 传 `X-Forwarded-*`。

选 `NATIVE` 而非 `FRAMEWORK`：前者在连接器层生效，
`getScheme()`/`getServerPort()`/`getRemoteAddr()` 三者都正确；
后者是 Servlet Filter，覆盖范围取决于 filter 顺序，更容易漏。

顺带修好第三个问题：登录日志里的客户端 IP 不再全是 `127.0.0.1`。

### 7.3 两处必须一致

| 配置 | 决定什么 | 必须等于 |
|------|---------|---------|
| `MAXKEY_PUBLIC_URL` | JWT iss、登录页/门户跳转、登出回跳 | 浏览器实际访问的根地址 |
| nginx `server_name` + `listen` | OIDC 元数据推导 | 同上 |

实测两者一致时：JWT 的 iss 是
`https://sso.lottery-dev.com:9443/sign`，
OIDC issuer 是 `https://sso.lottery-dev.com:9443/sign/maxkey`，同源同端口。

### 7.4 迁移到不同端口/协议

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

## 8. 域名在本项目里的三个作用

域名不只是"访问地址"，改错会引发三类互不相关的故障：

### 8.1 租户（机构）识别

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

### 8.2 SSO 回跳地址拼接

`SingleSignOnInterceptor` 未登录时跳：

```
<maxkey.server.frontend.uri>/#/passport/login?redirect_uri=<base64(当前URL)>
```

`frontend.uri` 是相对路径（`/maxkey`），跟着当前 Host 走；
但 OIDC/OAuth 的 issuer、`authorization_endpoint` 走的是
`WebContext.getContextPath()`，依赖 §7.2 的请求推导。
两者任一错位都会让回跳地址不可达。

### 8.3 Cookie 域

会话 Cookie 绑定当前域名。跨域名回跳会丢登录态。

---

## 9. 数据库：KingbaseES

### 9.1 实测环境

| 项目 | 值 |
|------|-----|
| 版本 | **KingbaseES V009R003C018**（`server_version` 报 12.1，PG 兼容） |
| 端口 | 54321 |
| 库/账号 | `maxkey` / `maxkey` |
| 表数 | 44 张 `mxk_*` |

### 9.2 建库脚本：为什么是 0.4MB 而不是 19MB

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

结果：**18.9MB → 0.4MB（2.1%）**。`--verify` 可自检结构与关键种子行。

### 9.3 保留哪些表：依据是"登录链路会读它"

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

### 9.4 关键配置项

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

## 10. SSO 最小化：只保留什么

### 10.1 必须启动

| 组件 | 端口 | 作用 | 能否省 |
|------|------|------|--------|
| `maxkey` | 9527 | 认证中心：登录、发 token、OAuth/CAS/SAML/OIDC 端点 | **不能** |
| `maxkey_mgt` | 9526 | 管理端：应用/用户/机构配置 | **不能**（否则无法配置应用接入） |
| nginx | 443 | 静态前端 + 反代 | **不能**（前端是纯静态） |
| KingbaseES | 54321 | 数据库 | **不能** |

### 10.2 不启动

| 组件 | 端口 | 说明 |
|------|------|------|
| `maxkey-web-openapi` | 9525 | 只有 1 个 OTP 校验 controller，SSO 核心链路不依赖。已从构建中移除（源码保留） |
| `maxkey-gataway` | 9000 | **已删除**。没有 Spring Boot 插件、依赖全注释，构建不出可运行构件 |
| Redis | 6379 | 默认 `SERVER_PERSISTENCE=0` 即内存会话，单实例够用 |
| Nacos / RocketMQ | - | 非 SSO 必需 |

> Redis 的取舍：`maxkey.server.persistence` 默认 `0`（内存 Caffeine）。
> 会话在 JVM 内存里，**重启会丢登录态**，且不支持多实例。
> 要横向扩展再切 `2`（Redis），当前最小化不需要。

### 10.3 建议关闭的功能

```bash
LOGIN_CAPTCHA=false        # 内网首次联调可关；生产建议 true
LOGIN_MFA_ENABLED=false    # 无短信/邮箱通道时关掉 TOTP
```

### 10.4 单点登录闭环的最短路径

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

## 11. 实测验证记录

> 环境：Ubuntu 24.04.5 x86_64，glibc 2.39，nginx 1.24.0，
> KingbaseES V009R003C018，JDK 21（jlink 产物 59MB）。
> 所有验证均在本机完成。因 `sudo` 受限（`no new privileges`），
> systemd 与 `/opt` 部分用隔离前缀 + 非 root nginx 实例等效验证，
> 相关项在表中标注。

### 11.1 构建链路

| 项目 | 结果 |
|------|------|
| `gradle projects` | 工程列表不再含 `gataway`；openapi 已排除 |
| `bootJar` ×2 | 成功（离线 11 秒），portal 205MB / mgt 196MB |
| `pnpm install --frozen-lockfile` | 成功（1 分 0 秒），此前因缺 lockfile **必然失败** |
| 前端构建 ×2 | portal 5.9s（初始包 2.51MB / gzip 489KB），mgt 9.9s |
| 从干净树全量重建 | `build-package.sh --build` 1 分 24 秒，自动改用仓库内 `COREPACK_HOME` |
| lockfile 完整性 | 裸 pnpm 执行会改写 lockfile（实测 +25 行）；脚本校验能拦下；corepack 路径无 drift |
| 打包 | `maxkey-deploy-4.2.0.tar.gz` 361MB，结构完整 |

### 11.2 运行时

| 项目 | 结果 |
|------|------|
| jlink 23 模块 | **59MB**，4 秒生成 |
| 缺 `java.desktop` 时 | 自检正确拦截，输出 `NoClassDefFoundError: java/awt/image/BufferedImage` 并判定"缺 java.desktop" |
| 补齐后 | 自检通过 |
| portal 启动 | **8 秒**成功（用包内 jre） |
| mgt 启动 | **8 秒**成功（用包内 jre） |
| 验证码渲染 | HTTP 200，图片正常（证明 `java.desktop` 真实生效） |

### 11.3 nginx 路由

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

### 11.4 对外地址与 SSO

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

### 11.5 数据库

| 项目 | 结果 |
|------|------|
| `maxkey-seed.sql` 导入 | **3.2 秒，0 错误** |
| 表结构 | 44 张 `mxk_*`，与源文件完全一致 |
| 数据 | 1 个用户（admin）、1 个机构、14 个组、admin 6 条成员关系、24 条授权、34 个应用、14 个 OAuth client |
| 协议覆盖 | CAS 9 / SAML 7 / OAuth2 7 / OAuth2.1 1 / OIDC 1 / JWT 2 / Token 3 / ExtendAPI 3 / Basic 1 |
| 登录 | `admin/{plain}maxkey` 成功，`Authorized Apps` 返回 15 个应用 |
| 登录历史写入 | 正常落库（`mxk_history_login`） |

### 11.6 安装脚本

| 项目 | 结果 |
|------|------|
| `install.sh --dry-run`（非 root） | 通过，仅打印操作 |
| 域名冲突检测 | **正确命中**本机已有的 `sso-sso.lottery-dev.com.conf` 并中止，未改动任何 nginx 文件 |
| 渲染校验 | 端口（IPv4+IPv6）、证书路径、server_name 均正确替换，无占位符残留 |
| `uninstall.sh` | 语法通过；默认保留配置与数据，`--purge` 才删目录 |

### 11.7 仍需在目标环境确认的项

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

## 12. 已知问题（本期不修，但必须知道）

以下是排查过程中发现的既有缺陷。都不在本次四个目标范围内，
故**只记录不修**，避免扩大改动面。

### 12.1 JWT HMAC 密钥明文硬编码（安全）

`maxkey.auth.jwt.secret` 与 `refresh.secret` 是 512 字符的字面量，
明文写在 `application-maxkey.properties`、`application-maxkey-mgt.properties`
（两处**完全相同**）。打包后任何人 `unzip` jar 即可取得。

影响：拿到 jar 就能伪造任意用户的 JWT。

缓解：至少做到 jar 不外发；如需彻底解决，改为
`${JWT_SECRET}` 环境变量注入 + 部署时生成随机值。
注意一改就必须同步改 mgt，否则两边校验互不通。

### 12.2 Redis 配置用旧命名空间（潜在启动失败）

`RedisAutoConfiguration` 读的是 `${spring.redis.host}` /
`${spring.redis.password}`，且**没有默认值**。Spring Boot 4 已迁移到
`spring.data.redis.*`。

当前 `maxkey.server.persistence=0` 走内存分支，不会触发；
但 `RedisAutoConfiguration` 是无条件 `@AutoConfiguration`，
一旦启用 Redis（`SERVER_PERSISTENCE=2`）就会因属性解析失败而启动失败。

另：`RedisDefaultConfig` 默认口令是 `admin`，而 properties 默认
`REDIS_PWD:password`，两者本身也不一致。

### 12.3 SAML keystore 口令硬编码

`config/*.jks` 与 `*.jwks` 打包进 jar，口令 `maxkey` 写在 properties 里。
多实例部署时所有实例共用同一套签名密钥。

### 12.4 确认页面注入第三方统计脚本（隐私/合规）

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

### 12.5 `mxk_apps_oauth_client_details.issuer` 默认是演示域名

每个 OAuth client 有独立的 `issuer` / `audience` 字段，
默认值形如 `https://sso.maxkey.top/maxkey`、`http://sso.maxkey.top:9527/...`。

实测 `id_token` 里的 `iss` 就是取这个字段，因此**不会**跟随
`MAXKEY_PUBLIC_URL` 变化。上线时必须逐个改成真实域名，
否则客户端按真实 issuer 校验会失败。

### 12.6 OAuth2 password grant 抛 NPE（上游缺陷）

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

### 12.7 会话不支持多实例

`SERVER_PERSISTENCE=0`（默认）时会话在 JVM 内存（Caffeine），
重启丢登录态，且无法水平扩展。需要多实例时切 Redis
（但要先修 12.2）。

### 12.8 包体积偏大

两个 fat jar 各约 200MB（合计 361MB 压缩包），主要来自依赖较多。
可用 layered jar 或裁剪不需要的协议模块来减小，
但会影响灵活性，本期未做。

---

## 13. 排障速查

| 现象 | 根因 | 处理 |
|------|------|------|
| `UnsupportedClassVersionError` | 目标机 JDK < 21 被优先选中 | `./bin/maxkeyctl.sh java` 查看实际使用的 java；确认 `jre/` 存在 |
| `GLIBC_2.3x not found` | 用系统自带 JDK 构建，基线过高 | 改用 Temurin：`./bin/make-runtime.sh --download` |
| `NoClassDefFoundError: java/beans/...` | 裁剪运行时缺 `java.desktop` | `./bin/maxkeyctl.sh start` 会直接指出；补齐模块重新生成 |
| **登录成功但立刻被踢回登录页** | JWT 的 iss 与实际 origin 不一致 | 检查 `MAXKEY_PUBLIC_URL` 是否等于浏览器实际地址（含端口） |
| OIDC 元数据里出现 `127.0.0.1:9527` | 未开 `forward-headers-strategy` 或 nginx 没传 `X-Forwarded-*` | 两者都要有 |
| SSO 回跳到错误的域名/端口 | `MAXKEY_PUBLIC_URL` 与 nginx `server_name`/端口不一致 | `install.sh` 会拦；手工核对 §7.3 |
| **能登录但门户应用列表为空** | 缺 `ROLE_ALL_USER` 组或其成员记录 | 见 §9.3，检查 `mxk_groups` / `mxk_group_member` / `mxk_access` |
| 访问 authorize 被 302 到 `/authz/refused` | 该应用未对当前用户组授权，或 `visible=0` | 管理端给对应组授权，或调整 `mxk_apps.visible` |
| 配了 Kingbase 却连 3306 | JDBC URL 中 `&` 未加引号被 shell 截断 | URL 加单引号（脚本已做校验） |
| `online` 列名报错 | 未开启标识符转义 | `DATABASE_COLUMN_ESCAPE=true` + 转义符 `"` |
| 分页 SQL 报错 | 方言未生效 | `DATABASE_DIALECT=kingbase` |
| 页面能开但 API 全 404 | `proxy_pass` 漏尾部路径 | `proxy_pass .../sign/;` |
| 改了 nginx 配置不生效 | 存在同 `server_name` 的另一个站点 | `nginx -t` 会报 `conflicting server name`；`install.sh` 会提前拦 |
| **nginx 报 `bind() to 0.0.0.0:443 failed` 但 `ss` 看不到占用者** | WSL 下 Windows 侧端口转发占用了该端口 | 换端口（如 9443），`NGINX_TLS_PORT` 与 `MAXKEY_PUBLIC_URL` 同步改；Windows 侧用 `netstat -ano \| findstr :443` 或 `netsh interface portproxy show all` 核对 |
| `nginx -s reload` 返回 0 但端口没起来 | reload 失败只写 error.log，命令本身仍退出 0 | `install.sh` 已改为 reload 后校验端口监听并自动回滚；手工操作时务必看 `/var/log/nginx/error.log` |
| **只重启 portal 后 mgt 变 failed 且不自愈** | mgt 单元声明了 `Requires=maxkey-portal.service` | 已改为只用 `After=` 表达启动顺序（见 §14）；旧单元需手工 `reset-failed` 后 start |
| **curl 访问 MaxKey 返回 000 但浏览器正常** | 环境变量 `http_proxy/https_proxy` 指向本地代理，`no_proxy` 的 `*.domain` 通配不被 curl 支持 | 用 `curl --noproxy '*'`；或把具体域名写进 `no_proxy` |
| `.js` 报 `Unexpected token '<'` | 静态资源缺失回退到了 index.html | 静态资源 location 用 `try_files $uri =404` |
| 改 DB 配置后不生效 | client 信息有 Caffeine 缓存 | 重启进程 |
| 启动被拒绝，提示 DATABASE_PWD 为空 | 口令未注入 | 填 `/etc/maxkey/maxkey-secret.env` |
| `Invalid redirect: ... does not match` | 回调地址与 client 注册值不一致 | 管理端改该应用的回调地址（精确匹配，含路径） |
| 构建后 `pnpm-lock.yaml` 变脏 | 用了 PATH 上的 pnpm 而非 corepack | 改用 `corepack pnpm`；脚本会比对校验和并报错 |
| 构建报 `EACCES ... corepack/v1` | `$HOME` 不可写 | 脚本已自动处理；手工构建时设 `COREPACK_HOME` |

---

## 14. 日常运维

```bash
# 启停
./bin/maxkeyctl.sh start|stop|restart|status [portal|mgt|all]
./bin/maxkeyctl.sh java              # 查看实际使用的 JDK 与版本

# systemd
systemctl start|stop|restart maxkey-portal maxkey-mgt
journalctl -u maxkey-portal -f

# 日志（log4j2 用相对路径，日志在各应用目录下）
tail -f /opt/maxkey/maxkey/logs/maxkey.log
tail -f /opt/maxkey/maxkey_mgt/logs/maxkey.log
tail -f /opt/maxkey/logs/nohup-portal.out

# 升级（保留配置与日志）
tar xzf maxkey-deploy-<新版本>.tar.gz && cd maxkey-deploy-<新版本>
sudo ./install.sh          # conf/ 与 logs/ 不会被覆盖
sudo ./bin/maxkeyctl.sh restart

# 卸载
sudo ./uninstall.sh          # 保留 /opt/maxkey、/etc/maxkey、数据库
sudo ./uninstall.sh --purge  # 连程序目录一起删；数据库仍不删
```
