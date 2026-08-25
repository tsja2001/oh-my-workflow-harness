# B通道收口计划：今晚家庭端配完，明日公司端一键验收

> 日期：2026-08-24
> 工具：codex
> 当前状态：Windows和WSL的B通道客户端已经预配置；今晚只需由家里Codex完成Cloudflare Access保护、`home-lan`的SSH发布入口和家庭端验证。
> 下一步：回家后把本文交给家里Codex按第2～7节执行；明天公司Windows只运行 `ssh home-mac-access`完成最终验收。

> 本文是给家里Codex/Computer Use的自包含执行单，简化并接续 `20i-B通道AccessSSH预配置与测试准备-codex.md`，不覆盖前文证据。Cloudflare页面名称会改版；当前界面的 `Public DNS` 对应官方文档中的 `Add public hostname`。

## 1. 最终要得到什么

这次不再做一套覆盖所有家庭设备的VPN，而是增加一个只服务于SSH开发的B通道：

```text
明天公司 Windows / WSL
  → ssh home-mac-access
  → Windows本机cloudflared弹出Cloudflare Access登录
  → ssh-home.tttthappy1111.org
  → Cloudflare边缘和既有home-lan Tunnel
  → 家里Mac localhost:22
```

目标体验：

1. Windows PowerShell和WSL都能直接运行 `ssh home-mac-access`。
2. VS Code Remote-SSH可以选择 `home-mac-access`打开Mac目录。
3. 不再依赖公司Windows的WARP私网路径来承载SSH；现有A通道仍保留给Home Assistant、路由器等家庭私网资源。
4. Mac不开放路由器公网22端口，访问者必须先通过Cloudflare Access身份验证，再通过原SSH密钥验证。

必须实话说明：今晚可以把家庭端和Cloudflare全部配好，但公司网络是否允许这条新链路、延迟是否足够低，只能明天在公司实测。明天最少仍需运行一次SSH，并由用户本人完成一次浏览器登录；不能在家里替公司网络做出结论。

## 2. 交给家里Codex的开工口令

回家后，在家里Mac的Codex中直接发送：

> 请完整阅读 `docs/需求/17网络/10i-B通道今晚家庭端与明日公司端收口计划-codex.md`，按文档完成今晚家庭端任务。你负责只读核查、Cloudflare页面配置、Mac本地测试、验收记录和必要回退；我只在Cloudflare登录、验证码/MFA、Mac密码等人的身份界面亲自输入。不要读取、保存、复制或输出Token、Cookie、OTP、密码和私钥。不要修改现有A通道、Clash、旧saturate Tunnel和cdn域名。界面与文档不同时先根据官方文档核实语义，不要猜着保存。

家里Codex可以使用Computer Use点击普通配置并保存。以下动作必须由用户本人输入或确认：

- Cloudflare账号登录、邮箱验证码、MFA。
- Mac密码或Touch ID授权。
- 任何页面意外要求展示、复制或重新生成Tunnel Token时，停止，不继续。

## 3. 已经完成的事，不要在家里重做

以下是公司电脑当前已完成的预配置，家里Codex只需把它当作明天验收前提，不需要远程修改公司电脑：

| 项目 | 当前状态 |
|---|---|
| Windows `cloudflared.exe` | 已安装，版本 `2026.8.2`，签名有效 |
| WSL `cloudflared` | 已安装，版本 `2026.8.2` |
| Windows SSH别名 | `home-mac-access` 已配置，`ssh -G`通过 |
| WSL SSH别名 | `home-mac-access` 已配置，`ssh -G`通过 |
| Windows/WSL SSH密钥 | 已沿用原来能够登录Mac的密钥 |
| Mac主机指纹 | 两端已复用已验证的 `192.168.5.35` 指纹 |
| B通道真实连接 | 尚未发生，因为Cloudflare后台对象还没配完 |

家庭端也已经有这些基础设施，不要重建：

| 项目 | 当前状态 |
|---|---|
| Tunnel | 已有独立的 `home-lan` |
| Mac Connector | 已迁成root LaunchDaemon，不依赖用户登录 |
| 家庭CIDR Route | `192.168.5.0/24 → home-lan` 已存在 |
| Mac SSH | 原A通道已实际用公钥登录成功 |
| 旧代理设施 | `saturate`、`cdn.tttthappy1111.org`保持独立 |

家里Codex严禁“顺手优化”以下内容：

- 不新建第二个Tunnel，不重新安装Connector，不重新生成Token。
- 不删除或修改 `192.168.5.0/24` CIDR Route。
- 不改Device Profile、Split Tunnel、Enrollment和WARP。
- 不改Mac或Windows Clash/Mihomo。
- 不迁移、编辑或重启 `saturate`。
- 不修改 `cdn.tttthappy1111.org`、VLESS或路由器端口转发。
- 不启用顶层 `Infrastructure`，不选 `Private destinations`、`Workers`或`Service auth`。

## 4. 今晚第一阶段：先做只读快照

家里Codex先核实，不满足就停，不自动修：

1. Mac本机 `127.0.0.1:22`正在监听并能返回SSH握手；本机用户是否已有自连接密钥不是开工门槛。
2. 系统级cloudflared LaunchDaemon已加载，进程身份为root。
3. Cloudflare Dashboard中的 `home-lan`为Healthy。
4. `home-lan`中原 `192.168.5.0/24` CIDR Route仍存在。
5. Access应用列表中尚无同名 `home-mac-ssh`；Tunnel Routes和DNS中尚无 `ssh-home.tttthappy1111.org`。如果已经存在，先检查它是否为本方案创建的相同对象，不创建重复项。

只记录对象名称、状态和非敏感配置。不得读取或展示LaunchDaemon中的Tunnel Token，不截图带Cookie、Token或完整账户身份信息的页面。

只读快照全部正常，才进入下一阶段。

## 5. 今晚第二阶段：创建Cloudflare Access保护

必须先创建Access应用，再发布Tunnel路由。Cloudflare官方明确提醒：没有Access应用时先发布公共Hostname，会在保护生效前形成公开入口。

当前页面路径：

```text
Cloudflare Dashboard
→ Zero Trust
→ Access controls
→ Applications
→ Add/Create an application
→ Self-hosted and private
→ Public DNS
```

如果页面写的是 `Add public hostname`，它与当前 `Public DNS`是同一个语义，继续即可。

填写目标值：

| 字段语义 | 目标值 |
|---|---|
| Application name | `home-mac-ssh` |
| Public hostname / Domain | `ssh-home.tttthappy1111.org` |
| Path | 留空 |
| Session duration | `24 hours` |
| Browser rendering | 不启用 |
| App Launcher visibility | 可关闭；不是连接必需项 |

创建一条且只创建一条允许策略：

| 字段语义 | 目标值 |
|---|---|
| Policy name | `allow-owner-only` |
| Action / Decision | `Allow` |
| Include selector | `Emails` / 指定邮箱 |
| Email value | 用户本人当前可接收Cloudflare登录验证码的邮箱，由用户在页面亲自选择或输入，不写入本文和聊天 |

安全门槛：

- 不选 `Everyone`、`Emails ending in`或宽泛域名。
- 不创建 `Bypass`、`Service Auth`或Service Token。
- 不开启“仅凭WARP会话自动认证”一类依赖公司WARP的选项；B通道要能独立弹出Access登录。
- 登录方式沿用当前可用的One-time PIN/现有身份方式，不新增身份提供商。
- 如果页面要求的对象类型变成Infrastructure、SSH CA、Gateway policy或目标主机，说明走错入口，返回上一步。

保存后重新打开 `home-mac-ssh`，回查应用名、完整域名、24小时会话和owner-only Allow策略均仍存在。没有明确Allow策略不要继续发布路由。

## 6. 今晚第三阶段：在既有home-lan发布SSH

页面路径可能因改版显示为 `Networking`或 `Networks`：

```text
Zero Trust
→ Networking / Networks
→ Tunnels
→ home-lan
→ Routes
→ Add route
→ Published application
```

填写：

| 字段语义 | 目标值 |
|---|---|
| Subdomain | `ssh-home` |
| Domain | `tttthappy1111.org` |
| Path | 留空 |
| Service type | `SSH` |
| Service / URL | `localhost:22` |

其余规则：

- 使用现有 `home-lan`，不是 `saturate`。
- Service必须是 `SSH`，不是HTTP、HTTPS、TCP、RDP或Bastion。
- `localhost:22`表示由Mac上的Connector转给同一台Mac的SSH。
- 不跳过TLS验证，不加HTTP Header，不改连接超时等高级参数。
- 如果页面提供 `Protect with Access`，应在能够明确关联刚创建的 `home-mac-ssh`时启用；若它要求手工猜AUD、Team Name或其他未知值，先停止并核实，不乱填。

保存后必须回查：

1. `home-lan`仍为Healthy。
2. 原 `192.168.5.0/24` CIDR Route仍存在。
3. Routes出现且只出现一条 `ssh-home.tttthappy1111.org → SSH localhost:22`。
4. 普通DNS页面自动出现 `ssh-home`的Proxied CNAME，目标指向本Tunnel的Cloudflare Tunnel域名。

不要手工猜Tunnel UUID创建DNS。如果保存路由后DNS没有自动生成，停止并记录页面报错；不要再增加第二条记录。

## 7. 今晚第四阶段：家庭端验收

家里Codex按从近到远的顺序验证：

### 7.1 本机源站

- `127.0.0.1:22`可连接。
- Mac当前SSH主机公钥指纹可读取；只记录指纹，不读取私钥。
- `home-lan` Connector进程和LaunchDaemon保持原状。

### 7.2 公共名称和Access门

- 使用公共DNS/DoH确认 `ssh-home.tttthappy1111.org`不再是NXDOMAIN。
- 未认证访问时必须进入Cloudflare Access身份验证，不能直接到达Mac SSH。
- 用错误/未授权身份不能通过；不得为了测试临时放宽到Everyone。

### 7.3 client-side cloudflared回环测试

家里Codex先检查Mac现有 `cloudflared`可执行文件路径，再使用临时SSH参数或临时配置测试，不永久修改 `~/.ssh/config`。目标链路是：

```text
Mac客户端SSH
→ Mac本机cloudflared access ssh
→ Cloudflare Access登录
→ 公共Hostname
→ home-lan Tunnel
→ 同一台Mac localhost:22
```

用户本人完成浏览器验证码/MFA。如果SSH需要Mac密码，只能由用户在终端亲自输入；AI不得索取、回显、保存或自动填写。

验收至少证明：

1. Access认证成功。
2. 已进入真实SSH握手，而不是只看到DNS或HTTP 200。
3. 远端主机指纹与Mac本机SSH公钥指纹一致。
4. 最好能执行只读命令 `hostname`并返回Mac主机名；如果本机没有可用的自连接密钥，允许停在“Access通过、SSH握手和指纹正确、SSH用户认证未完成”，明天用公司现有密钥完成最终认证。
5. 连续建立3次短连接，无循环登录、WebSocket立即重置或Tunnel掉线。

家庭同一网络的回环测试只能证明Cloudflare、Tunnel和Mac源站可用，不能证明公司出口一定放行。

## 8. 今晚完成的定义

以下全部满足，才可以告诉用户“家庭端完成”：

- `home-mac-ssh` Access应用存在。
- 只有用户本人邮箱匹配 `allow-owner-only` Allow策略。
- `home-lan`存在 `ssh-home.tttthappy1111.org → SSH localhost:22` Published Application。
- 自动DNS存在且Proxied，没有重复记录。
- `home-lan`仍Healthy，原CIDR Route未受影响。
- 未认证不能到达SSH；认证后至少完成SSH握手和主机指纹核对。
- 现有A通道、Mac网络、Clash、旧Tunnel和旧CDN均未修改。
- 形成一份新的 `20j-B通道家庭端配置与验收-codex.md`，记录实际页面路径、非敏感字段、测试结果、未知项和明天命令；不得把密码、Token、Cookie、OTP、私钥或完整邮箱写入文档。

若其中任何一项失败，家里Codex要写明失败发生在哪一层，不把“页面保存成功”“DNS有记录”或“看到Access登录页”当成完整成功。

## 9. 明天到公司只做什么

家庭端今晚完成后，公司Windows不需要再安装软件或编辑SSH配置。

### 9.1 最小动作

在Windows PowerShell运行：

```powershell
ssh home-mac-access
```

首次运行时，Windows本机 `cloudflared`会打开浏览器。用户本人完成Cloudflare Access登录，然后SSH应继续使用现有密钥登录Mac。

成功后执行：

```powershell
ssh home-mac-access "hostname"
```

如果返回Mac主机名，再在WSL执行：

```bash
ssh home-mac-access 'hostname'
```

WSL可能会单独弹一次Access登录，因为Windows和WSL使用各自的cloudflared及认证缓存。这是正常的首次动作，不应要求重新配置Cloudflare后台。

### 9.2 VS Code

命令行连接稳定后，在Windows VS Code执行：

```text
Remote-SSH: Connect to Host...
→ home-mac-access
```

先打开Mac上的小目录，验证终端、文件列表、保存和15～30分钟空闲恢复。不要一上来打开大型仓库掩盖网络问题。

### 9.3 明天如何判断是哪层出错

| 现象 | 先判断 |
|---|---|
| 域名不存在/NXDOMAIN | DNS或Tunnel Published Application没有真正保存 |
| 连Access登录页都到不了 | 公司出口或Windows Clash到Cloudflare公共入口的路径问题 |
| Access登录反复循环/无权限 | Access应用、登录方式或owner-only策略问题 |
| Access成功后SSH超时 | Published Application、home-lan Connector或Mac `localhost:22`问题 |
| 出现主机指纹不一致 | 立即停止，不能接受新指纹 |
| SSH能连但仍明显卡顿 | 先记录连接耗时和Mihomo最终路由；大概率需要做Windows单端路径A/B，不先改Mac |
| PowerShell成功、WSL失败 | WSL自己的cloudflared、认证缓存或ProxyCommand问题，不改Cloudflare后台 |
| SSH稳定、VS Code不稳定 | VS Code Remote-SSH长连接层问题，不等同于Tunnel失败 |

明天不要因为一次失败就回家改Mac。今晚家庭回环验收通过后，优先把失败定位到公司出口、Clash、Windows或WSL客户端。

## 10. 成功后的日常使用

如果B通道低延迟且稳定：

```text
SSH / VS Code开发：使用 home-mac-access（B通道）
Home Assistant / 路由器 / 家庭其他IP：继续使用现有WARP（A通道）
旧VLESS/CDN代理：保持原用途，不与本方案合并
```

不需要为了使用B通道删除A。两条通道解决的问题不同：B只发布一个受Access保护的SSH入口；A仍是整个家庭CIDR的私网访问。

Cloudflare官方说明SSH Published Application通过WebSocket承载，长连接不保证一定优于Client-to-Tunnel。因此最终是否长期保留B，只看公司现场的真实连接、输入延迟、30分钟稳定性和VS Code体验，不凭架构名称判断。

## 11. 回退

若今晚配置错误或安全验收失败，只回退本次新增对象，顺序如下：

1. 从 `home-lan → Routes`删除且只删除 `ssh-home.tttthappy1111.org` Published Application。
2. 删除且只删除Access应用 `home-mac-ssh`。
3. 如果自动DNS仍残留，只删除 `ssh-home`这一条CNAME。
4. 回查 `home-lan`仍Healthy、`192.168.5.0/24` CIDR Route仍存在。

不得删除 `home-lan` Tunnel、Connector、CIDR Route、Device Profile、Enrollment或 `saturate`。Windows/WSL的 `home-mac-access`别名即使暂时保留也不会主动联网，只在用户执行SSH时生效。

## 12. 官方依据

- [Cloudflare：使用client-side cloudflared连接SSH](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/)：客户端不需要Cloudflare One Client；通过SSH `ProxyCommand`调用 `cloudflared access ssh`。
- [Cloudflare：发布Self-hosted public application](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)：先创建Access应用和Allow策略，再发布Tunnel公共Hostname；完整DNS托管时会自动创建记录。
- [Cloudflare：Published Application协议](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/protocols/)：SSH服务值为 `ssh://localhost:22`，客户端SSH经WebSocket承载。
- [Cloudflare：Origin参数与Protect with Access](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/)：可让Connector再次校验Access JWT，作为纵深保护。

## 13. 当前收口状态

```text
今晚家里要完成：Access应用 + owner-only策略 + home-lan SSH发布 + DNS + 家庭回环验收
明天公司要完成：PowerShell首次Access登录 + SSH真实连接 + WSL/VS Code验证
Windows软件安装：已完成
Windows/WSL SSH配置：已完成
Mac Connector部署：已完成，不重做
现有A通道：保留，不改
Clash：今晚不改
远程Git：本次未操作
```
