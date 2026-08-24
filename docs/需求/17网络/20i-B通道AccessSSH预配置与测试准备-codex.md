# Cloudflare 家庭私网 · B通道 Access SSH 预配置与测试准备

> 日期：2026-08-24
> 工具：codex
> 当前状态：Windows和WSL客户端已完成无损预配置并通过静态检查；Cloudflare后台尚未创建Access应用和SSH Published Application，因此现在不会连接，等待用户按本文一次性完成页面操作。
> 下一步：用户只完成本文第5节的Cloudflare页面清单，然后回复“B后台已配好”；Codex再执行首次登录引导、Windows/WSL真实SSH、30分钟长连接和现有A通道延迟A/B。

> 本文接续 `10h-明确需求后的下一步方案分析-codex.md`，实施范围只限B通道试点。现有A通道（WARP/CIDR Route）继续作为回退，不修改、不停用。根据Cloudflare最新官方说明，Published Application的SSH使用WebSocket，长连接官方更推荐Client-to-Tunnel；因此B是实验通道，不预设一定比A快。

## 1. 本轮目标和边界

目标：并行建立一个原生SSH入口：

```text
Windows / WSL OpenSSH
→ client-side cloudflared
→ Cloudflare Access
→ ssh-home.tttthappy1111.org
→ 现有home-lan Tunnel
→ Mac localhost:22
```

建成后计划使用：

```powershell
# Windows PowerShell
ssh home-mac-access
```

```bash
# WSL
ssh home-mac-access
```

VS Code Remote-SSH后续也选择同一个Windows别名 `home-mac-access`。

本轮不做：

- 不修改或断开现有WARP。
- 不修改 `192.168.5.0/24 → home-lan` CIDR Route。
- 不修改Windows/Mac Clash节点和规则。
- 不修改Mac `cloudflared` LaunchDaemon。
- 不修改旧 `saturate` Tunnel、`cdn.tttthappy1111.org`或VLESS。
- 不发布HA、路由器或其他家庭设备。
- 不配置SOCKS、通用TCP转发或UDP入口。
- 不读取、保存或输出Cloudflare Token、Cookie、OTP、密码和私钥。

## 2. 为什么只做一个SSH试点

Cloudflare官方确认客户端可以不使用WARP，通过OpenSSH `ProxyCommand`调用：

```text
cloudflared access ssh --hostname <hostname>
```

官方文档：

- <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/>
- <https://developers.cloudflare.com/tunnel/routing/>

但SSH会以WebSocket承载，Windows上的外层连接又可能被当前Clash CDN-WS代理捕获，存在WebSocket套WebSocket和长连接重置风险。所以本轮只增加一个SSH入口，先回答三个问题：

1. 公司网络能否稳定建立Cloudflare Access SSH。
2. 最终外层走当前CDN代理还是其他路径。
3. Windows、WSL、VS Code的真实体验是否比A通道好。

只有实际有收益，才继续讨论C通道。

## 3. 已完成的本地预配置

### 3.1 子域名

选定：

```text
ssh-home.tttthappy1111.org
```

2026-08-24通过Cloudflare DoH公共查询返回NXDOMAIN；它没有现有公共DNS记录。WSL普通 `dig` 会被Mihomo Fake-IP改写成 `198.18.*`，不能用于判断真实占用，因此没有采信Fake-IP结果。

这个名称与以下既有对象隔离：

```text
旧代理入口：cdn.tttthappy1111.org
旧Tunnel：   saturate
家庭Tunnel： home-lan
```

### 3.2 WSL客户端

安装位置：

```text
/home/t/.local/bin/cloudflared
```

版本：

```text
cloudflared 2026.8.2
```

SHA-256：

```text
fcfb02b575a52ca1af2e3267af4e1517bcdeb30ac48c834c69abaed3c0576ad2
```

来源：Cloudflare官方GitHub Release `2026.8.2/cloudflared-linux-amd64`。

### 3.3 Windows客户端

安装位置：

```text
C:\Users\29455\AppData\Local\Programs\cloudflared\cloudflared.exe
```

版本：

```text
cloudflared 2026.8.2
```

SHA-256：

```text
c29eee2b121f5436a642eed69fd9767da7e7b8c510fa50aaa130337f931357b5
```

Windows Authenticode回查：

```text
Status: Valid
Signer: Cloudflare, Inc.
```

来源：Cloudflare官方GitHub Release `2026.8.2/cloudflared-windows-amd64.exe`。

安装使用用户目录，不需要管理员权限，也没有注册Windows服务或启动项。

下载暂存目录保留在：

```text
/tmp/codex-cloudflared-20260824-1100
```

### 3.4 WSL SSH别名

文件：

```text
/home/t/.ssh/config
```

新增独立块：

```sshconfig
# BEGIN codex-cloudflare-access-ssh
Host home-mac-access
    HostName ssh-home.tttthappy1111.org
    User mac
    Port 22
    ProxyCommand /home/t/.local/bin/cloudflared access ssh --hostname %h
    IdentityFile ~/.ssh/macmini_ed25519
    IdentitiesOnly yes
    HostKeyAlias 192.168.5.35
    StrictHostKeyChecking yes
    ConnectTimeout 20
    ServerAliveInterval 30
    ServerAliveCountMax 3
# END codex-cloudflare-access-ssh
```

静态检查：

- `ssh -G home-mac-access`正确展开Hostname、ProxyCommand、IdentityFile和超时参数。
- `HostKeyAlias 192.168.5.35`成功复用已经验证过的Mac ED25519主机指纹。
- 不使用 `accept-new`，如果服务端指纹与已知Mac不一致会直接失败。

### 3.5 Windows SSH别名

文件：

```text
C:\Users\29455\.ssh\config
```

新增独立块：

```sshconfig
# BEGIN codex-cloudflare-access-ssh
Host home-mac-access
    HostName ssh-home.tttthappy1111.org
    User mac
    Port 22
    ProxyCommand C:\Users\29455\AppData\Local\Programs\cloudflared\cloudflared.exe access ssh --hostname %h
    IdentityFile C:\Users\29455\.ssh\thinkpad-t14-windows_ed25519
    IdentitiesOnly yes
    HostKeyAlias 192.168.5.35
    StrictHostKeyChecking yes
    ConnectTimeout 20
    ServerAliveInterval 30
    ServerAliveCountMax 3
# END codex-cloudflare-access-ssh
```

Windows `ssh.exe -G home-mac-access`静态检查通过；Windows `known_hosts`中也存在已验证的 `192.168.5.35`主机指纹。

### 3.6 备份与哈希

WSL备份：

```text
/home/t/.ssh/codex-backups/cloudflare-access-20260824-120002/config.before
```

原哈希：

```text
16a44d29dbd6f0b1d7fcc35e45476a10806dd56c962a365cc1c7ae18fce8e310
```

修改后哈希：

```text
fed9027c50446e1102cda97203f71a36d8e49eebf448e2001bed77270088deb9
```

Windows备份：

```text
C:\Users\29455\.ssh\codex-backups\cloudflare-access-20260824-120002\config.before
```

原哈希：

```text
2dd88a78ad82ceb094149cbe006360e041b7ba816e57002173c42fcab1c37218
```

修改后哈希：

```text
337c8c2738620986482de5e1a5eba637b5f5d91d801cc6444fc86ac83d04cd4b
```

## 4. 当前为什么还不能测试

本地别名已经指向 `ssh-home.tttthappy1111.org`，但Cloudflare后台尚未存在：

```text
Access Self-hosted Application
Access owner-only Allow Policy
home-lan上的SSH Published Application
自动生成的ssh-home DNS记录
```

因此现在运行 `ssh home-mac-access`只会失败或找不到域名。Codex没有主动发起连接，也没有触发浏览器登录。

## 5. 用户一次性Cloudflare页面操作清单

只操作以下两个对象。不要打开、迁移或编辑 `saturate`，不要修改 `cdn.tttthappy1111.org`。

### 第一步：先创建Access保护

进入：

```text
Cloudflare Dashboard
→ Zero Trust
→ Access controls
→ Applications
→ Add an application
→ Self-hosted
```

填写：

| 字段 | 填写值 |
|---|---|
| Application name | `home-mac-ssh` |
| Session duration | `24 hours` |
| Application domain / Hostname | `ssh-home.tttthappy1111.org` |
| Path | 留空 |
| Browser rendering | 关闭/不启用 |
| App Launcher visibility | 可关闭；不影响SSH |

进入策略部分，新增一条：

| 字段 | 填写值 |
|---|---|
| Policy name | `allow-owner-only` |
| Action | `Allow` |
| Include selector | `Emails` |
| Value | 选择或填写你当前用于Cloudflare登录的邮箱；不要发给AI |

要求：

- 只保留这一条明确邮箱的Allow策略。
- 不选 `Everyone`。
- 不增加 `Bypass`。
- 不粘贴任何Token、Cookie或密码。

保存应用后，重新打开 `home-mac-ssh`，确认域名、Allow策略和邮箱选择仍存在。

### 第二步：再发布Mac SSH服务

进入：

```text
Zero Trust
→ Networking
→ Tunnels
→ home-lan
→ Routes
→ Add route
→ Published application
```

填写：

| 字段 | 填写值 |
|---|---|
| Subdomain | `ssh-home` |
| Domain | `tttthappy1111.org` |
| Path | 留空 |
| Service type | `SSH` |
| URL / Service | `localhost:22` |

其余高级选项保持默认，不启用TLS跳过验证，不添加HTTP Header。

保存后做三项页面回查：

1. `home-lan`仍显示Healthy。
2. 原 `192.168.5.0/24` CIDR Route仍存在。
3. Routes中同时出现 `ssh-home.tttthappy1111.org → SSH localhost:22`。

### 第三步：DNS只读确认

进入该域名的普通Cloudflare DNS页面，确认自动出现类似：

```text
Type: CNAME
Name: ssh-home
Target: <home-lan tunnel UUID>.cfargotunnel.com
Proxy status: Proxied
```

不要手工改Target，不要复制Tunnel UUID给AI。如果没有自动生成记录，先停止并告诉Codex页面提示，不要自己猜UUID创建。

完成后只回复：

> B后台已配好：Access应用、owner-only策略、home-lan SSH Published Application均已保存，Tunnel仍Healthy，CIDR Route仍存在。

## 6. 后台完成后的测试顺序

以下由Codex执行；需要浏览器登录时再一次性通知用户。

### 6.1 配置回查

1. 公共DoH查询不再返回NXDOMAIN。
2. `https://ssh-home.tttthappy1111.org`进入Cloudflare Access，而不是直接暴露SSH或返回无保护页面。
3. 两端 `cloudflared --version`和 `ssh -G`继续通过。
4. 现有A通道19项验收继续PASS。

### 6.2 首次认证

先在Windows PowerShell执行：

```powershell
ssh home-mac-access
```

由用户在浏览器完成Cloudflare身份登录。AI不输入邮箱验证码、密码或OTP。

如果Windows成功，再在WSL执行：

```bash
ssh home-mac-access
```

如果WSL需要单独登录，再由用户完成一次。

### 6.3 真实功能

```bash
ssh home-mac-access 'hostname'
ssh home-mac-access 'curl -fsS --max-time 5 http://192.168.5.1/ >/dev/null && echo router-ok'
ssh home-mac-access 'curl -fsS --max-time 10 http://127.0.0.1:8123/ >/dev/null && echo ha-ok'
```

命令只返回成功标记，不把家庭网页内容、Cookie或其他敏感响应写入文档。

### 6.4 延迟与稳定性A/B

| 测试 | A：现有WARP | B：Access SSH |
|---|---:|---:|
| 冷SSH连接5次 | 待测 | 待测 |
| 连续短命令10次 | 待测 | 待测 |
| 保持会话30分钟 | 待测 | 待测 |
| 空闲后继续输入 | 待测 | 待测 |
| Mihomo最终路由 | 已知WARP走CDN | 待查 |
| 用户主观敲字体验 | 当前不可用 | 待测 |

不能只看Access登录成功。必须检查Mihomo新日志，判断 `cloudflared`连接是否仍通过 `Daily-CDN-WS`，并记录WebSocket重置、超时和重复登录。

### 6.5 VS Code最后测试

只有Windows和WSL命令行SSH稳定后，用户再在Windows VS Code中：

```text
Remote-SSH: Connect to Host...
→ home-mac-access
```

先打开Mac上的一个小目录，保持30分钟；不直接打开大型仓库。验收目录加载、终端、文件保存、断线恢复和Cloudflare登录是否重复。

## 7. 成功、失败和停止门槛

### 保留B必须同时满足

- Access必须先认证，未登录不能到达Mac SSH。
- Windows和WSL均使用原生 `ssh home-mac-access`成功。
- Mac主机指纹与现有 `192.168.5.35`一致。
- 非交互SSH和Mac本地curl真实成功。
- 30分钟没有WebSocket重置、循环认证或连接僵死。
- VS Code Remote-SSH实际可打开目录并稳定操作。
- 延迟或稳定性相对A有用户能感知的改善。
- 原A通道、公司内网、公网和19项验收不受影响。

### 立即停止并回退

- Access域名未认证就能触达SSH。
- 主机指纹不一致。
- 公司内网、公网或现有WARP异常。
- WebSocket频繁被重置或公司安全侧出现明确告警。
- B与A同样慢或更慢。
- VS Code频繁重连、重复登录或无法稳定保存文件。

## 8. 回退办法

### Cloudflare后台

1. 先从 `home-lan → Routes` 删除且只删除 `ssh-home.tttthappy1111.org` Published Application。
2. 再删除且只删除Access应用 `home-mac-ssh`。
3. 查看DNS；如果 `ssh-home` CNAME仍残留，只删除这一条。
4. 回查 `home-lan`仍Healthy、`192.168.5.0/24` CIDR Route仍存在。

不得删除 `home-lan` Tunnel、CIDR Route、Enrollment、Device Profile或 `saturate`。

### WSL本地

恢复文件：

```bash
cp -p /home/t/.ssh/codex-backups/cloudflare-access-20260824-120002/config.before /home/t/.ssh/config
```

`/home/t/.local/bin/cloudflared`可以保留；没有进程、服务、别名引用时它只是静态文件。

### Windows本地

恢复文件：

```powershell
Copy-Item -Force `
  'C:\Users\29455\.ssh\codex-backups\cloudflare-access-20260824-120002\config.before' `
  'C:\Users\29455\.ssh\config'
```

Windows `cloudflared.exe`没有注册服务或启动项，可以保留为静态文件。

恢复后原 `home-mac`继续走A通道；B回退不触碰A。

## 9. 当前现场

```text
现有A通道：                         保持原状
Cloudflare Access应用：             待用户页面创建
home-lan SSH Published Application：待用户页面创建
公共ssh-home DNS：                  当前NXDOMAIN，待页面自动创建
WSL cloudflared：                   2026.8.2，已安装
Windows cloudflared：               2026.8.2，签名Valid，已安装
WSL home-mac-access：               已配置，ssh -G通过
Windows home-mac-access：           已配置，ssh -G通过
Mac主机指纹：                       两端均复用既有192.168.5.35记录
真实SSH：                           尚未发起
VS Code：                           尚未测试
远程Git：                           未操作
```
