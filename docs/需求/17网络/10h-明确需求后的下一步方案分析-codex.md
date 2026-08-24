# Cloudflare 家庭私网 · 明确需求后的下一步方案分析

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：已根据用户在 `50c回应-明确需求.md` 中补充的真实需求重新收敛方案；本轮只分析，没有修改 Windows、WSL、Mac、Cloudflare 或 Clash。  
> 下一步：保持现有 WARP 私网基线不动，先补齐 3～5 台家庭设备的目标清单；随后优先建设一条并行的 Cloudflare Access SSH 快速通道并做延迟 A/B，验证有实际收益后再决定是否给少数高频 TCP 服务增加 Access 入口。

> 本文回应 `50c回应-明确需求.md`。本文取代 `10g-Windows端Clash单端优化方案-codex.md` 作为**当前下一步建议**。取代原因：10g 推荐 Windows WARP 外层改走 Reality；用户已在 50c 明确排除公司端 Reality 直连。10g继续保留为历史技术分析，不再作为默认执行方案。

## 0. 一句话结论

用户真正要的不是“远程打开 Home Assistant”，而是：

```text
公司 Windows / WSL
  ├─ 像在家里一样访问少量固定家庭 IP
  ├─ 可以访问 Mac mini 上正在监听的各种端口
  ├─ 原生命令行直接 SSH
  └─ WSL 中的 CLI AI 能通过 SSH 去家庭侧执行 curl/fetch
```

这属于**网络层私网接入**，而不是几个网页的反向代理。

在用户明确排除 Tailscale、公司放行、Windows Reality 直连之后：

- 现有 `Cloudflare WARP + CIDR Route` 是当前唯一已经落地、并真正满足“像虚拟组网一样访问 IP/端口”的主通道。
- 当前 `WARP 外层再套 CDN/WebSocket Clash` 是它在公司网络能连接的条件，也是高延迟的主要来源。
- Cloudflare Access 的按应用入口不能完整代替虚拟组网，但可以把最高频的 SSH/CLI 操作从 WARP 套娃中拆出来，作为并行快速通道。
- 因此下一步不是推翻现有 WARP，而是采用“**WARP 全网能力兜底 + Access SSH 高频入口**”的双通道架构。

该方案不承诺一定更快；它的价值是可以在不破坏现有链路的情况下，用真实 A/B 判断是否值得保留。

## 1. 用户需求的准确翻译

输入依据：`50c回应-明确需求.md:1-5`。

### 1.1 必须满足

| 需求 | 技术含义 |
|---|---|
| 不依赖公司开放 WARP | 不能把“找网络同事放行”作为可执行下一步 |
| 不使用 Tailscale | 不再恢复、替换或伪装 Tailscale |
| 公司端不让 WARP 改走 Reality | `warp-svc.exe → Daily-Reality-443` 从当前候选中删除 |
| 访问约 3～5 个固定家庭 IP | 不能只发布一个 HA 网页；需要覆盖多个目标 |
| 访问 Mac mini 上的各种服务 | 需要网络层可达，或者提供足够通用的受控入口 |
| Windows/WSL 原生 SSH | 不能只给浏览器里的 SSH 终端 |
| CLI AI 可远程执行 | SSH 必须支持非交互命令，能够在 Mac 上运行 `curl`、`fetch` 等 |
| 使用体验接近虚拟组网 | 常用操作不应每次手工开网页、复制临时端口或反复改配置 |

### 1.2 用户明确不要

```text
向公司申请开放网络作为主方案
恢复 Tailscale
Windows WARP 外层直连 Reality 节点
只解决 Home Assistant、不解决其他家庭设备
只有浏览器能用、Windows/WSL终端不能用
```

### 1.3 仍需澄清但不阻塞第一步

用户写的“Mac mini上的所有端口”，字面可能包含 TCP、UDP、ICMP及未来未知端口。目前只能确认既有验收目标是 SSH/TCP、HTTP/TCP；不能擅自推断所有目标都是 TCP。

后续目标清单需要逐项注明协议。原因是：

- WARP私网可以承载IP层的TCP/UDP/ICMP。
- Cloudflare Access按应用入口适合SSH、HTTP和指定TCP。
- Access任意TCP并不等于透明承载UDP/ICMP，也不等于自动开放65535个端口。

“访问Mac所有端口”也不等于把Mac所有端口发布到公网。无论走哪条通道，只有Mac实际监听、macOS防火墙允许、访问策略允许的服务才应该响应。

## 2. 用户约束之间存在的硬冲突

### 2.1 要完整虚拟组网，就需要网络层隧道

如果希望在WSL中直接执行：

```bash
ssh mac@192.168.5.35
curl http://192.168.5.20:xxxx
```

而不用先为每个端口创建域名或本地转发，就必须有一条能路由家庭IP的网络层通道。当前承担这个职责的是：

```text
Cloudflare One Client / WARP
  + 192.168.5.0/24 Split Tunnel Include
  + 192.168.5.0/24 → home-lan Tunnel Route
```

Cloudflare官方也把“整段私网CIDR接入”和“发布单个应用”区分为两种能力：

- 私网CIDR结合Cloudflare One Client，提供类似VPN的IP访问。
- Published Application / Access按主机名发布指定HTTP、SSH或TCP应用。

官方依据：

- <https://developers.cloudflare.com/tunnel/integrations/>
- <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/>

### 2.2 要公司端只经过Cloudflare，又不允许官方WARP直连，只能增加一层承载

公司网络下物理直连WARP已经实测：MASQUE/UDP短暂握手后超时，H2/TCP 443备用也失败；同一电脑换手机热点后则持续Healthy。证据见：

- `50b-项目阶段复盘与AI交接-codex.md:264-326`
- `20h-手机热点直连WARP对照试验-codex.md:10-19,52-78`

所以在公司网络中，当前WARP要么：

1. 经过某个额外承载再到Cloudflare；或者
2. 不能建立稳定连接。

用户又明确排除更短的Reality承载，当前留下的就是较慢的CDN/WebSocket承载。这不是再添加一条Clash规则能够消除的物理矛盾。

### 2.3 “经过Cloudflare”不等于“对公司安全系统不可见”

需要纠正一个关键理解：

- 公司出口看到的目的地址可以是Cloudflare，而不是个人Reality服务器。
- 但这不代表WARP、`cloudflared`或长期隧道在终端和网络侧变得不可识别。
- 网络设备仍可能看到Cloudflare IP、域名/SNI、长连接的时间、流量和行为特征。
- 终端侧如果存在安全软件，也可能看到进程、服务、虚拟网卡和连接归属。

因此本文只能把“公司端不直接连接个人Reality IP”当作技术约束，不能承诺“通过Cloudflare就不会触发风控”，也不会设计协议伪装、规避态势感知或清理审计痕迹。

旧 `10-待提供信息-codex.md` 曾记录用户口头表示“这些都是允许的”，但最新50c又明确说明用户无权推动网络开放，且Tailscale曾被公司点名。两份输入并不等价于正式确认了“家庭整网段访问”和“第三方代理承载WARP”的批准范围。后续不能把旧表述扩大解释成任何网络手段都已获批。

## 3. 当前架构为什么功能符合、性能却不符合

### 3.1 功能上完全命中需求

当前已经做到：

- Windows和WSL能直接访问家庭 `192.168.5.0/24`。
- Mac SSH、HA、路由器均验收通过。
- WSL中的命令可以访问家庭IP。
- 普通公网、公司内网、DNS和默认路由没有被家庭Tunnel接管。
- WARP断开后家庭网段不可达，证明没有旧Tailscale旁路。

本项目最近一次自动验收为19/19 PASS，见 `50b:196-230`。

### 3.2 性能成本来自两端套娃

当前实测路径：

```text
公司 Windows / WSL
→ WARP
→ Windows Clash Daily-CDN-WS
→ 代理机房
→ Cloudflare WARP / Zero Trust
→ home-lan Tunnel
→ 代理机房
→ Mac Clash Daily-Reality-443
→ cloudflared
→ 家庭设备
```

证据见 `10f-Windows端Clash优化前延迟基线-codex.md:32-53`。

其中Windows侧的CDN-WS把WARP流量再次封装进VLESS/XUDP和WebSocket/TCP。遇到丢包、重传或连接波动时，TCP层可能放大等待。实测：

| 项目 | 结果 |
|---|---:|
| 家庭Mac到路由器 | 平均3.849ms |
| Windows到HA TCP建连 | 0.518～0.528秒 |
| Windows到HA首字节 | 1.035～1.122秒 |
| Windows到HA总耗时 | 1.418～1.480秒 |
| Reality节点同目标中位数 | 166ms |
| CDN-WS节点同目标中位数 | 359ms |

家庭LAN约4ms，问题不在家庭Wi-Fi。完整证据见 `10f:15-30`、`10g:85-103`。

### 3.3 即使理想WARP直连，也不是几十毫秒

手机热点物理直连WARP时，HA总耗时仍为0.824～1.088秒，见 `20h:68-78`。这说明去掉Windows CDN外层会有改善，但家庭Mac到Cloudflare的远距离链路、Cloudflare中间路由和应用响应仍然存在。

因此本项目的合理目标应该是：

- 让SSH/CLI交互从“明显难用”改善到“稳定可用”；
- 减少重复握手和超时；
- 不承诺获得家庭局域网级延迟。

## 4. 候选方案逐项判定

| 方案 | 满足IP透明访问 | Windows/WSL原生SSH | 符合用户排除项 | 延迟潜力 | 当前判定 |
|---|---:|---:|---:|---:|---|
| 保持当前WARP over CDN | 是 | 是 | 是 | 低 | 保留为兜底 |
| WARP改走Reality | 是 | 是 | 否 | 中 | 用户已排除 |
| 公司网络正式放行WARP | 是 | 是 | 否，用户认为不可执行 | 中～高 | 不作为下一步 |
| 恢复Tailscale | 是 | 是 | 否 | 不确定 | 明确排除 |
| 只发布HA等网页 | 否 | 否 | 是 | 中 | 不完整，只能补充 |
| Cloudflare Access原生SSH | 否，只到SSH目标 | 是 | 是 | 中，需实测 | 推荐并行A/B |
| Access指定TCP端口 | 否，需逐端口映射 | 部分 | 是 | 中，需实测 | 高频服务补充 |
| SSH动态SOCKS代理整个家庭网 | 不是真正透明IP，UDP不足 | 是 | 表面满足但范围过宽 | 不确定 | 不推荐 |
| 公开家庭公网端口 | 可部分做到 | 是 | 偏离Cloudflare边界 | 高 | 安全风险高，排除 |

### 4.1 为什么不再执行Reality方案

Reality在现有测试中确实比CDN-WS快，但用户已经把“公司端不直连个人Reality节点”列为明确约束。技术上能快不代表符合需求，因此不再建议修改：

```text
PROCESS-NAME,warp-svc.exe,Daily-Reality-443
```

### 4.2 为什么不能只发布3～5个网页

Published Applications适合HA等HTTP服务，但无法让WSL继续用原IP访问未来未知端口，也无法自动覆盖UDP/ICMP。只做这个会把“虚拟组网”降级成“几个远程网页”，不符合50c。

### 4.3 为什么Access SSH仍值得测试

Cloudflare官方支持客户端在没有Cloudflare One Client/WARP的情况下，通过 `cloudflared access ssh` 作为OpenSSH `ProxyCommand`，在Windows或WSL原生终端中连接SSH：

<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/>

它满足的关键需求是：

```text
Windows/WSL ssh命令
→ Cloudflare Access身份认证
→ 现有home-lan Tunnel
→ Mac SSH
```

连接到Mac后，CLI AI可以把家庭侧操作交给Mac执行：

```text
公司WSL中的AI
→ ssh home-mac-access
→ 在Mac本地 curl/fetch 192.168.5.x
→ 结果经SSH返回WSL
```

这样CLI AI并不一定需要从公司WSL直接路由到每一个家庭IP。大量操作可以在家庭LAN内部完成，家庭侧只有约4ms。

Access还支持为指定非HTTP TCP服务建立客户端本地端口，但每个服务仍需明确映射，不是透明全网VPN：

<https://developers.cloudflare.com/cloudflare-one/access-controls/applications/non-http/cloudflared-authentication/arbitrary-tcp/>

### 4.4 Access SSH的边界

- 它不会让 `curl http://192.168.5.x` 在WSL里自动直通；AI需改为在Mac远程执行，或为少量固定TCP服务创建明确的本地转发。
- 它不解决任意UDP/ICMP。
- 它仍会经过公司网络和Windows Clash；只是有机会去掉WARP私网这一层，不能提前断言一定更快。
- 首次或会话过期时需要用户在浏览器完成Cloudflare Access登录；AI不处理OTP、Cookie或身份凭据。
- 不能把它扩展成无限制的通用SOCKS/CONNECT代理；固定端口只给已列出的家庭目标。

## 5. 推荐的双通道目标架构

### 5.1 通道A：现有WARP全网能力，保持不动

用途：

- 必须直接使用家庭IP的程序。
- UDP、ICMP或尚未枚举的端口。
- 临时访问新的家庭服务。
- Access SSH不可用时的回退。

```text
Windows / WSL
→ 当前WARP over Daily-CDN-WS
→ Cloudflare Zero Trust CIDR Route
→ home-lan
→ 家庭192.168.5.0/24
```

这条通道慢，但已经19项验收通过，不应该在建立替代入口前拆除。

### 5.2 通道B：Cloudflare Access SSH，作为高频入口

用途：

- Windows PowerShell原生SSH。
- WSL原生SSH。
- CLI AI登录Mac执行诊断、curl、fetch和家庭设备管理命令。
- 通过Mac再连接家庭中明确允许SSH的设备。

```text
Windows / WSL OpenSSH
→ client-side cloudflared / Cloudflare Access
→ Cloudflare上的SSH应用主机名
→ 复用现有home-lan Connector
→ 192.168.5.35:22
```

安全边界：

- Access应用先配置Allow策略，再添加路由，避免无保护发布。
- 只允许用户自己的身份，建议要求MFA。
- Mac仍使用原有SSH账号和密钥；不把密码或私钥交给Cloudflare、文档或AI。
- 不开启通用动态转发。
- 若以后需要从Mac跳到其他家庭SSH设备，应逐个列目标，不默认允许任意横向转发。

### 5.3 通道C：少量高频应用入口，确认收益后再加

只有Access SSH A/B确实比WARP好用，才继续考虑：

```text
ha.<domain>       → 192.168.5.35:8123
device1.<domain>  → 192.168.5.x:port
device2.<domain>  → 192.168.5.x:port
```

所有入口必须先有Cloudflare Access策略。路由器后台、管理界面和敏感设备不默认发布；能通过Mac本地命令完成的操作，优先只保留SSH入口。

## 6. 下一步执行方案

本节只是下一轮执行设计，本轮尚未实施。

### 阶段一：冻结当前基线

1. 运行现有19项只读验收。
2. 冻结当前Windows/WSL到Mac SSH的冷连接和连续命令耗时。
3. 记录WARP和Mihomo日志起始行。
4. 不修改Windows Clash、WARP路由、Mac Clash和现有CIDR Route。

### 阶段二：补家庭目标清单

用户只需要提供业务信息，不需要抄网络配置：

| 设备用途 | 固定IP | 协议/端口 | 使用频率 | 是否必须由WSL直接访问IP | 能否改为在Mac上执行 |
|---|---|---|---|---|---|
| Mac mini | `192.168.5.35` | 已知SSH 22，其他待列 | 高频 | SSH必须 | 不适用 |
| Home Assistant | `192.168.5.35` | TCP 8123 | 待填 | 待填 | 可以curl |
| 家庭设备1 | 待填 | 待填 | 待填 | 待填 | 待填 |
| 家庭设备2 | 待填 | 待填 | 待填 | 待填 | 待填 |
| 家庭设备3～5 | 待填 | 待填 | 待填 | 待填 | 待填 |

这张表决定哪些必须留在WARP，哪些可由Access SSH代替。未知值保持未知，不按常见设备猜。

### 阶段三：并行建设Access SSH

执行原则：

1. 复用现有 `home-lan` Tunnel，不新建第二个家庭Connector。
2. 为Mac SSH创建独立应用主机名。
3. **先建立Access Allow策略和默认拒绝，再接SSH服务。**
4. Windows或WSL安装官方 `cloudflared` 客户端；不处理或保存用户登录凭据。
5. 新增独立SSH别名，例如 `home-mac-access`，不覆盖当前 `home-mac`。
6. 首次认证由用户在浏览器完成。
7. Windows和WSL分别验证交互SSH、非交互命令和真实远程curl。

Cloudflare官方说明此模式可以直接与OpenSSH `ProxyCommand`结合，不要求客户端运行WARP。它还可以与现有WARP/CIDR方式同时存在，所以适合无损A/B。

### 阶段四：真实A/B

至少比较：

| 测试项 | 当前WARP路径 | Access SSH路径 |
|---|---:|---:|
| 新建SSH连接5次 | 待冻结 | 待测 |
| 已认证后连续执行10条短命令 | 待冻结 | 待测 |
| 在Mac执行家庭路由器curl | 待冻结 | 待测 |
| 在Mac执行HA curl | 待冻结 | 待测 |
| 10分钟内断连/超时 | 待冻结 | 待测 |
| 用户主观交互体验 | 当前不可用 | 待测 |
| WSL CLI AI非交互SSH | 当前可用但慢 | 待测 |

保留条件：

- Access登录与SSH稳定，没有反复浏览器认证。
- Windows和WSL的原生SSH均成功。
- CLI AI能够通过非交互SSH在Mac执行家庭侧curl并拿回真实响应。
- 与当前路径相比有可重复、用户能感知的改善。
- 现有19项仍全PASS，公司内网和普通公网不受影响。

如果只是配置成功、但延迟没有明显改善，不继续发布更多服务；删除新Access应用和SSH别名，保留当前WARP基线。

### 阶段五：只给确有收益的高频TCP服务增加入口

Access SSH验证有收益后，再从目标清单中选择1～2个高频服务进行试点。一次只加一个服务；每个服务都要验证认证、真实响应、日志和回退。

不一次性发布3～5台设备的全部端口，也不启用通用SOCKS代理。

## 7. 如果Access SSH仍然很慢，结论是什么

如果Access SSH仍然经Windows CDN代理、真实交互仍不可用，那么在当前约束下将没有另一条同时满足以下全部条件的技术路线：

```text
公司网络不放行官方WARP
不使用Tailscale
公司端不连接Reality
不使用独立网络/热点
仍要透明访问家庭IP和任意端口
还要低延迟
```

届时不能再靠改规则解决，只能在以下需求中至少放松一项：

1. 接受当前WARP over CDN延迟。
2. 只保留Access SSH和少量按应用入口，不再要求WSL透明访问全部家庭IP。
3. 在公司明确允许的前提下重新评估官方WARP直连或其他受管通道。
4. 改用与公司网络隔离的个人设备和个人网络访问家庭环境。

继续更换Cloudflare CDN IP、端口、域名、SNI或传输特征，不会消除远距离链路和套娃成本，而且会进入规避组织检测的边界，本文不建议也不提供这种路线。

## 8. 对Mac侧Reality的单独说明

用户在50c中的风险关注点是公司网络看到个人Reality服务器IP。当前Mac侧 `cloudflared → Daily-Reality-443` 发生在家庭宽带，不经过公司出口，公司侧看不到这条家庭上行连接。

同时已有实测：

```text
Mac DIRECT → Cloudflare测试点    约198ms
Mac Reality → Cloudflare测试点   约185ms
```

因此仅为降低公司侧风险，不需要修改Mac Reality；它不在公司流量观察路径中。为了避免远程改Mac导致Connector和SSH同时失联，下一轮继续冻结Mac Clash。

如果用户的真实要求是“家里和公司两端都绝对不使用Reality”，需要作为另一个独立变更：必须在能远程桌面或物理操作Mac时，对Mac `cloudflared` 直连做带定时回退的A/B。现有数据不支持它能提高性能。

## 9. 最终推荐

按优先级：

1. **保留现有WARP/CIDR通道**：它是唯一满足透明IP、任意监听端口和多协议访问的已验证能力。
2. **停止Windows Reality计划**：它与用户最新明确需求冲突。
3. **新增Cloudflare Access SSH并行通道做A/B**：目标是Windows/WSL原生SSH和CLI AI远程执行，不先发布其他服务。
4. **让家庭侧操作尽量在Mac本地执行**：公司侧只传命令和结果，避免让每一次家庭curl都经历完整的多层握手。
5. **Access SSH确实更快后，才给1～2个高频TCP服务建独立Access入口**。
6. **Access仍慢则停止技术堆叠**：明确接受约束冲突，保留WARP兜底或放弃透明全网体验，不继续做“更像正常流量”的伪装优化。

下一轮最小施工范围应当只有：

```text
Cloudflare：新增一个受Access保护的SSH Published Application
Windows/WSL：安装客户端cloudflared并新增独立SSH别名
Mac：不改Clash、不改系统服务，只复用现有Connector和SSH
现有WARP：不删、不改，继续作为回退
```

在用户提供3～5台目标设备清单之前，不修改现有 `/24` Route，也不猜端口。

## 10. 本文完成时的现场

```text
网络配置：              未修改
Cloudflare配置：         未修改
Windows/WSL配置：        未修改
Mac配置：                未修改
Clash配置：              未修改
Reality Windows方案：    因用户明确约束，退出当前推荐
当前功能基线：           仍按50b记录，最近19/19 PASS
下一步推荐：             Access SSH并行A/B + 现有WARP兜底
实施前还需要：           3～5台家庭设备的IP/协议/端口/频率清单
远程Git：                未操作
```
