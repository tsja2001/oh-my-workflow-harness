# Cloudflare 家庭私网 · 项目阶段复盘与 AI 交接

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：核心功能已经上线并验收；Windows/WSL到家庭SSH、Home Assistant和路由器均可用，19项自动检查再次全部PASS。当前稳定基线已经恢复，没有保留任何本轮Clash性能优化；剩余问题是公司出口下WARP物理直连不稳定，以及当前双端Clash套娃带来的高延迟。  
> 下一步：默认保持现状，不再改Mac、Cloudflare或Windows路由。先确认公司对“个人家庭私网访问”和“WARP外层经第三方代理”的批准范围；只有明确允许后，才做一次Windows单端 `warp-svc.exe → Daily-Reality-443` 性能A/B，失败立即恢复。

> 本文取代 `50-架构总览与公司端下一步-codex.md` 作为**当前状态入口**。取代原因：旧50写于公司Windows注册和最终验收之前，之后已经完成Mac系统服务迁移、公司端验收、延迟调查、公司网络直连失败试验及手机热点对照。旧文件和所有10/20/30文档继续保留，作为过程证据，不覆盖、不删除。

## 0. 给后续 AI 的第一句话

这是一个**功能已经完成、性能尚未优化、合规边界需要再次确认**的项目，不是一个“继续把网络配通”的项目。

接手后不要重新安装客户端、不要重新注册设备、不要再次运行Mac的 `apply/resume`、不要扩大Cloudflare路由，也不要先改Clash。先运行只读验收；如果19项仍通过，就以本文记录的当前配置为基线做判断。

本文不包含任何Cloudflare Token、密码、OTP、Cookie或私钥内容。后续AI也不得读取、输出或复制这些内容。

## 1. 项目目标与当前结论

### 1.1 原目标

让公司Windows在不暴露家庭公网端口、不接管公司内网和普通公网流量的前提下，访问家庭局域网：

```text
Mac SSH                  192.168.5.35:22
Home Assistant           192.168.5.35:8123
家庭路由器               192.168.5.1:80
以后其他家庭设备         192.168.5.x
```

### 1.2 当前结论

功能目标已经完成：

- 公司Windows和WSL都能通过Cloudflare家庭私网访问上述家庭服务。
- WARP断开后家庭地址不可达，证明没有悄悄走旧Tailscale或其他旁路。
- WARP断开不影响普通公网；重连后家庭链路恢复。
- 公司内网、公网、DNS、默认路由和Clash保持原路径；用户已在公司网络人工确认公司内网正常。
- Mac `cloudflared` 已迁为root LaunchDaemon，开机运行，不依赖用户登录。

证据：`20g-Mac系统服务迁移与公司端最终验收-codex.md:10-24,44-80`，`30d-公司端最终测试报告-codex.md:10-33`。

尚未完成的是性能和公司出口兼容性：

- 公司网络下，WARP直接连接Cloudflare官方入口无法稳定工作。
- 当前WARP外层经Windows Clash的 `Daily-CDN-WS` 才能稳定保持业务可用。
- 家庭Mac的 `cloudflared` 外层也经Mac Clash，但走的是 `Daily-Reality-443`。
- 当前路径功能正确，但层级较多、延迟较高。
- Windows改走Reality只是一份尚未实施的性能候选，不是当前配置。

## 2. 当前真实架构

### 2.1 逻辑架构

```text
公司 Windows / WSL
  │
  │ 只有目标 192.168.5.0/24 被WARP接管
  ▼
Cloudflare One Client（WARP）
  │
  │ 当前外层被Windows Mihomo捕获
  ▼
Daily-CDN-WS
  │
  ▼
Cloudflare WARP / MASQUE入口
  │
  ▼
Cloudflare Zero Trust中的192.168.5.0/24路由
  │
  ▼
home-lan Cloudflare Tunnel
  │
  │ 家庭侧cloudflared外层被Mac Mihomo捕获
  ▼
Daily-Reality-443
  │
  ▼
Mac root cloudflared LaunchDaemon
  ├─ 192.168.5.35:22   Mac SSH
  ├─ 192.168.5.35:8123 Home Assistant
  └─ 192.168.5.1:80    家庭路由器
```

### 2.2 不进入家庭Tunnel的流量

当前Cloudflare Profile是Traffic-only + Include模式，只包含家庭网段及Cloudflare客户端必需的Team端点。普通公网、公司内网和DNS不进入家庭Tunnel。

证据：`20b-家庭端部署执行结果-codex.md:10-25`，`20g-Mac系统服务迁移与公司端最终验收-codex.md:12-24`，`30d-公司端最终测试报告-codex.md:14-18`。

### 2.3 WARP入口与家庭Tunnel不是同一条连接

需要区分两条独立隧道：

1. Windows WARP把公司电脑送进Cloudflare网络，这是客户端上行入口。
2. 家庭Mac `cloudflared`从家庭网络主动连接Cloudflare，这是家庭侧下行出口。

Cloudflare在中间根据 `192.168.5.0/24 → home-lan` 路由把两条连接接起来。Cloudflare CDN、WARP入口和Cloudflare Tunnel可能共享Cloudflare全球网络，但用途和协议不同。

## 3. 三端当前配置快照

### 3.1 家庭路由器与Mac

| 项目 | 当前值/状态 | 证据 |
|---|---|---|
| 家庭LAN | `192.168.5.0/24` | `20d:25-31` |
| 路由器 | `192.168.5.1` | `20d:20-21,27` |
| Mac固定地址 | `192.168.5.35` | `20d:14-23,34-49` |
| SSH | `192.168.5.35:22`，可用 | `20d:42-49` |
| Home Assistant | `192.168.5.35:8123`，HTTP 200 | `20d:42-49` |
| cloudflared身份 | root | `20g:30-42` |
| 服务类型 | 系统LaunchDaemon，loaded | `20g:30-42` |
| Token | 项目外文件、非空、权限0600，内容未读取 | `20g:32-42` |
| Mac迁移备份 | `/Library/Application Support/codex-cloudflared-migration/backups/20260824-094740` | `20g:40` |
| Mac Clash | `cloudflared`当前经 `Daily-Reality-443` | `10f:40-46` |

旧的 `saturate` Tunnel、旧VLESS/CDN配置、DNS、路由器LAN/DHCP池、Home Assistant和SSH均未因本项目被迁移或重建。证据：`20b:76-83`、`20d:25-32`、`20g:42`。

### 3.2 Cloudflare Zero Trust

| 项目 | 当前结果 |
|---|---|
| 新Tunnel | `home-lan`，最后Cloudflare页面回查Healthy，当前真实业务仍通过 |
| 旧Tunnel | `saturate`保持原状，不在本项目回退范围 |
| 私网路由 | `192.168.5.0/24 → home-lan → default` |
| 客户端协议 | MASQUE，允许H2/TCP 443自动备用 |
| Service mode | Traffic only |
| Split Tunnel | Include IPs |
| 目标业务网段 | `192.168.5.0/24` |
| 设备注册 | 已完成，公司Windows已注册到正确Team |

配置落地证据：`20b:10-25`。当前业务证据：本文第4节的19项验收。

### 3.3 公司Windows WARP

当前读数：

```text
Status update: Connected
Network: unstable
```

不要只根据 `unstable` 判断失败：本次写文档前重新执行完整验收，19项全部PASS。这个状态词说明连接质量不理想，与“家庭业务是否实际可用”不是同一个结论。

当前家庭有效路由仍为：

```text
192.168.5.0/24 → CloudflareWARP
```

WARP当前外层仍被Windows Mihomo接管。2026-08-24 10:53～10:57的新日志持续出现：

```text
warp-svc.exe → 162.159.197.3:443 using PROXY[Daily-CDN-WS]
warp-svc.exe → 2606:4700:102::3:443 using PROXY[Daily-CDN-WS]
warp-svc.exe → 162.159.137.105:443 using PROXY[Daily-CDN-WS]
```

来源：`C:\Users\29455\AppData\Roaming\mihomo-party\logs\core-2026-08-24.log` 的10:53～10:57记录。

### 3.4 Windows Clash持久配置链

```text
C:\Users\29455\AppData\Roaming\mihomo-party\mihomo.yaml
  └─ TUN、strict-route、route-exclude-address等最终覆盖

C:\Users\29455\AppData\Roaming\mihomo-party\profiles\19f21b41eb4.yaml
  └─ 当前订阅缓存和节点定义，订阅更新可能覆盖

C:\Users\29455\AppData\Roaming\mihomo-party\override\19fc53966e1.yaml
  └─ 持久追加规则；未来单进程规则只能放这里

C:\Users\29455\AppData\Roaming\mihomo-party\work\config.yaml
  └─ 当前最终运行配置，是验收事实，但不是持久编辑源
```

当前三个关键文件SHA-256：

```text
mihomo.yaml                   21ad57f95b65ce79d74fac4df7cf68c6d311c5bb1e2ed4c26aed0985a3673d94
override\19fc53966e1.yaml     2f670a0aeaa3581bd32ca296cf5cdb7580adb7f9771b57684a698226fbd0851a
work\config.yaml             93196ab159c22e3349c95b7c946c5326cfbb14d0e08aeee9fc47e5f22bab54f4
```

当前回读未发现以下任何持久配置：

```text
PROCESS-NAME,warp-svc.exe,Daily-Reality-443
162.159.197.0/24
2606:4700:102::/48
```

也就是说：**Windows Reality单进程方案没有实施，WARP物理直连路由排除也没有保留。**

## 4. 当前验收状态

写本文前再次执行：

```bash
bash scripts/windows-cloudflare-one.sh verify
```

以下19项全部PASS：

```text
registered-to-team
warp-connected
settings-traffic-only
settings-include-mode
settings-home-cidr
settings-team-endpoint-1
settings-team-endpoint-2
windows-mac-ssh-tcp
windows-mac-ssh-login
windows-home-assistant-http
windows-router-http
windows-public-internet
windows-public-dns
wsl-mac-ssh-tcp
wsl-home-assistant-http
wsl-public-internet
default-routes-unchanged
dns-servers-unchanged
clash-still-running
```

公司内部网页只能在公司网络由用户人工选择。最近一次公司网络实测已由用户确认“公司内网正常”，见 `30d:22-33`。手机热点上的19项PASS不能替代这项公司内网人工测试。

断开与重连也已真实验收：断开后家庭地址不可达、公网仍可用；重连后19项恢复，见 `20g:70-80`。

## 5. 为什么现在延迟高

优化前同口径实测：

| 测试 | 结果 |
|---|---:|
| Mac到家庭路由器ICMP | 平均3.849ms，0丢包 |
| Windows到HA TCP建连 | 0.518～0.528秒 |
| Windows到HA首字节 | 1.035～1.122秒 |
| Windows到HA总耗时 | 1.418～1.480秒 |
| Windows到路由器总耗时 | 1.074～1.135秒 |

证据：`10f-Windows端Clash优化前延迟基线-codex.md:15-30`。

家庭LAN只有约4ms，因此主要延迟不在家庭Wi-Fi、路由器或Home Assistant。当前数据需要经历：

```text
Windows WARP
→ Windows CDN/WebSocket代理
→ Cloudflare
→ Mac Reality代理
→ cloudflared
→ 家庭设备
```

Windows同一Cloudflare测试目标的节点延迟：

```text
Daily-Reality-443  166 / 164 / 176 ms，中位166ms
Daily-CDN-WS       373 / 351 / 359 ms，中位359ms
```

恢复当前CDN路径后的日志还有6条真实连接超时或 `context deadline exceeded`。这些证据支持“当前CDN外层是主要可优化点”，但节点delay本身不能证明真实家庭业务一定同比改善。证据：`10g:85-103`。

## 6. 公司网络直连WARP到底发生了什么

### 6.1 不是简单的“所有UDP都被封”

公司网络物理绕过Mihomo时，WARP日志显示：

1. 客户端同时赛跑MASQUE/UDP主协议和H2/TCP备用协议。
2. UDP 443曾完成QUIC握手，并连接到Cloudflare FRA边缘。
3. 约5秒后该连接发生idle timeout。
4. 后续UDP 443、500、1701、4500、4443、8443、8095多轮失败或超时。
5. WARP实际回退尝试了H2 over TCP 443。
6. IPv6 TCP 443进入TLS握手后被强制关闭，错误10054。
7. IPv4 TCP 443最终超时，错误10060。

原始证据：

```text
C:\ProgramData\Cloudflare\cfwarp_service_log.txt:8861-9012
C:\ProgramData\Cloudflare\cfwarp_service_log.txt:9099-9102
C:\ProgramData\Cloudflare\cfwarp_service_log.txt:9829-9830
C:\ProgramData\Cloudflare\cfwarp_service_log.txt:10107-10127
C:\ProgramData\Cloudflare\cfwarp_service_log.txt:10331
```

所以当前最准确的说法是：

> 公司办公出口路径无法稳定承载WARP的UDP/MASQUE主通道，TCP/H2备用通道也不可用；这不是对全部UDP或全部TCP 443的一刀切封锁。

### 6.2 手机热点对照

同一台Windows、同一套WARP/Cloudflare策略，仅把公司网络换成手机热点，并使用同样的物理TUN绕过方法：

- WARP从10:39:04到10:39:34共10次检查全部 `Connected / Network: healthy`。
- Home Assistant三次HTTP 200，总耗时0.824～1.088秒。
- 路由器HTTP 200，总耗时1.040秒。
- 19项自动验收全部PASS。
- 试验结束后临时配置逐字节恢复。

证据：`20h-手机热点直连WARP对照试验-codex.md:10-19,52-103`。

这证明Cloudflare账号、Windows客户端、家庭Tunnel和WARP入口在该手机运营商路径上都能工作，也反证“当前位置WARP被普遍封死”。

### 6.3 仍未实锤的根因

当前只能把差异缩小到公司办公出口路径，不能仅凭终端日志断言具体是谁阻断：

| 判断 | 当前把握 |
|---|---|
| 公司出口防火墙/上网行为管理限制QUIC、VPN或未知隧道 | 高可能，未实锤 |
| 态势感知/NDR发现后联动防火墙阻断 | 有可能，未实锤 |
| 企业安全设备兼容、状态跟踪或IPv4/IPv6策略问题 | 有可能 |
| 公司专线运营商到Cloudflare Anycast的路由/丢包问题 | 仍有可能 |
| Cloudflare账号、Windows或家庭Tunnel坏了 | 已由热点成功基本排除 |
| 全国或当前位置普遍封锁WARP | 已由热点成功反证 |

态势感知平台通常负责旁路采集、分析、告警和联动；真正执行丢包或RST的通常是出口防火墙、IPS或上网行为管理。没有公司出口设备日志时，不得把“公司主动封禁”写成确定事实。

## 7. 已做过的试验和恢复状态

### 7.1 公司网络WARP物理直连试验

临时把Cloudflare官方MASQUE入口和客户端编排地址放进Mihomo `route-exclude-address`，用于真正绕过strict-TUN。公司网络下WARP无法稳定连接，随后完整回退。

备份目录：

```text
C:\Users\29455\AppData\Roaming\mihomo-party\codex-backups\windows-warp-bypass-20260824-101202
```

恢复状态和19项PASS见 `10g:32-46`。

### 7.2 手机热点物理直连对照

仅临时修改最终运行文件，测试后恢复：

```text
C:\Users\29455\AppData\Roaming\mihomo-party\codex-backups\windows-warp-hotspot-20260824\config.yaml.before
```

恢复后的 `work/config.yaml` SHA-256：

```text
93196ab159c22e3349c95b7c946c5326cfbb14d0e08aeee9fc47e5f22bab54f4
```

当前回读仍与该值一致。证据：`20h:80-103`及本文3.4节当前查询结果。

### 7.3 Mac服务迁移

首次迁移因旧用户服务被停止导致当前SSH短暂断开；脚本防覆盖保护阻止了第二次 `apply`，之后用 `resume`只补齐备份指针并清理旧plist。当前迁移已经完成，不得重复执行。

回退只在系统LaunchDaemon确认故障、且用户能控制Mac时执行，见 `20g:26-42,91-118`。

## 8. 当前能做与不能做的决定

### 8.1 默认决定：保持当前功能基线

因为19项通过、公司内网上次人工验证通过，所以没有功能修复任务。日常只需要：

```bash
# 完整只读验收
bash scripts/windows-cloudflare-one.sh verify

# 家庭通道影响办公时立即止损
bash scripts/windows-cloudflare-one.sh disconnect

# 恢复家庭通道
bash scripts/windows-cloudflare-one.sh connect
```

### 8.2 不能继续做“直连绕过”

- 不要给Cloudflare整个地址空间加DIRECT。
- 不要长期保留WARP ingress的 `route-exclude-address`。
- 不要把普通Mihomo规则级 `DIRECT` 当成物理直连；strict-TUN下可能再次被捕获并回环。
- 不要继续更换端口试图绕过公司出口策略。
- 如果需要公司网络直连，应让公司网络侧核对并批准Cloudflare官方WARP入口和端口。

### 8.3 Windows Reality候选：技术上可试，合规上先暂停

现有技术方案是在持久override的 `+rules` 第一项加入：

```yaml
- PROCESS-NAME,warp-svc.exe,Daily-Reality-443
```

正确落点：

```text
C:\Users\29455\AppData\Roaming\mihomo-party\override\19fc53966e1.yaml
```

技术依据、步骤和成功门槛见 `10g:105-168`。但这会让公司出口看到的是第三方代理外层，而不是WARP官方入口，可能改变公司安全审计可见性。因此后续AI不得把它仅作为“降延迟配置”直接实施；必须先由用户确认公司批准范围。

如果明确批准，试验仍必须满足：

1. 只改Windows，不改Mac。
2. 先为override单独创建新备份；不要恢复整个旧目录覆盖后来配置。
3. 候选完整配置先通过Mihomo语法测试。
4. Clash重启由用户执行。
5. 新日志必须明确显示 `warp-svc.exe`命中Reality。
6. WARP 30秒内Connected，不反复重连。
7. 19项全部PASS，用户再验证公司内网页面。
8. HA/SSH同口径中位数改善建议至少15%。
9. 出现loopback、Reality超时、公司内网异常或收益不足，恢复单个override备份并由用户重启Clash。

### 8.4 Mac继续冻结

Mac已经让 `cloudflared` 走Reality，且它同时是家庭Connector和远程目标。远程修改Mac TUN/Clash一旦失败，可能同时失去家庭Tunnel和SSH。没有新的功能故障或本地/远程桌面兜底时，不得改Mac。证据：`10g:170-183`。

## 9. 合规与安全边界

已知：用户此前口头说明公司批准安装Cloudflare One Client，但批准方式和精确范围未补齐，见 `10-待提供信息-codex.md:19-31`。

仍需用户确认，不能由AI推断：

- 是否批准公司设备访问个人家庭私网。
- 是否批准WARP外层通过个人Clash/第三方代理节点。
- 是否允许在公司出口无法直连WARP时继续使用代理承载。

在边界不清楚时，后续AI只能做只读诊断、整理证据和准备给网络/安全同事的话术，不得帮助规避态势感知、应用识别、审计或出口策略。

给公司网络同事的中性核查话术：

> 2026年8月24日10:13:34至10:14:33，终端10.66.10.153尝试连接Cloudflare One Client官方WARP入口162.159.197.2及2606:4700:102::2。UDP 443曾完成QUIC握手后约5秒超时，其他UDP备用端口超时；客户端随后回退HTTP/2 over TCP 443，IPv6在TLS阶段被重置，IPv4连接超时。手机热点下同一终端和配置可以正常连接。请协助检查出口防火墙、上网行为管理、IPS及态势感知联动日志，确认是否命中应用识别、VPN/QUIC控制、TLS检查或访问控制策略；若出口记录为完整放行且未发送重置，再请运营商检查到Cloudflare该Anycast入口的IPv4/IPv6路由。

## 10. 后续AI接手顺序

### 10.1 第一轮只读体检

1. 阅读本文，不要先通读整个文件夹。
2. 运行 `git status --short`，保留用户和其他AI的未提交改动。
3. 运行 `warp-cli status`或项目脚本的只读状态检查。
4. 运行 `bash scripts/windows-cloudflare-one.sh verify`。
5. 回读上述三个Windows Clash文件的SHA-256和关键规则。
6. 记录Mihomo与WARP日志起始行，只分析新日志。
7. 如果用户此时在公司网络，再让用户人工打开一个常用公司内网页面；热点结果不能代替。

### 10.2 分支判断

```text
19项PASS
  ├─ 用户只问状态/原理 → 解释，不改配置
  ├─ 用户报告延迟高   → 复测同口径，先确认合规，再决定是否Reality A/B
  └─ 公司内网异常     → 先disconnect止损，再只读排查

19项FAIL
  ├─ WARP未连接       → 查WARP状态和新日志，不先改Mac
  ├─ 只有路由器失败   → 区分Mac本机和cloudflared转发，不重复迁移服务
  ├─ 公网/DNS/路由变  → 立即disconnect，恢复公司电脑原网络
  └─ Clash停止        → 先恢复Clash原配置，不扩大Cloudflare修改
```

### 10.3 任何写配置前

- 精确备份将要修改的单个文件并记录哈希。
- 只改一层、一个端、一个变量。
- 不读取或输出Token、私钥、密码、OTP。
- 不把 `HTTP 200`、`using PROXY`、节点delay、端口监听或语法成功当成端到端成功。
- 完成后必须重新跑19项，并保留公司内网人工验证。
- 不执行远程Git push、改远程分支或提MR，除非用户当次明确授权。

## 11. 文件导航

后续AI优先顺序：

| 要解决的问题 | 读哪份 |
|---|---|
| 当前项目完整上下文 | 本文 `50b-项目阶段复盘与AI交接-codex.md` |
| 已上线功能和19项验收 | `20g-Mac系统服务迁移与公司端最终验收-codex.md`、`30d-公司端最终测试报告-codex.md` |
| 家庭Mac固定IP | `20d-路由器固定租约执行-codex.md` |
| 延迟基线和双端Clash路径 | `10f-Windows端Clash优化前延迟基线-codex.md` |
| Windows Reality候选方案 | `10g-Windows端Clash单端优化方案-codex.md` |
| 热点直连对照与恢复 | `20h-手机热点直连WARP对照试验-codex.md` |
| 快速回退 | `20c-回退与恢复-codex.md`、`20g:91-118` |
| Clash专项日志 | `/home/t/projects/personal/05clash/2026-08-24-cloudflare-warp-windows-reality-plan.log.md`、`2026-08-24-warp-direct-hotspot-comparison.log.md` |

执行工具：

```text
scripts/windows-cloudflare-one.sh
scripts/windows-cloudflare-one.ps1
scripts/macos-cloudflared-launchdaemon.sh
```

## 12. 本文写入时的最终现场

```text
Cloudflare家庭私网功能：        已完成
公司内网人工验收：              已通过一次
本次重新运行19项自动验收：      19/19 PASS
WARP：                          Connected / Network: unstable
Windows WARP外层：              Daily-CDN-WS
Mac cloudflared外层：            Daily-Reality-443
Windows WARP物理直连配置：       未保留
Windows Reality单进程规则：      未实施
Mac系统服务迁移：                已完成，禁止重复apply/resume
Cloudflare云端策略：             无待改项
远程Git：                        未操作
当前主要问题：                  高延迟；公司出口直连WARP不稳定
当前推荐：                      保持基线，先确认公司批准范围
```

如果未来配置发生变化，必须新建下一份 `50c` 或后续编号文档，不要修改本文来洗掉这份基线。
