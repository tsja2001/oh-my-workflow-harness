# Windows 监控与 Clash / Tailscale 流量可见性调查

> 本文补充 `10-终端网络安全调查-codex.md`，补充原因：用户要求把“用途是否合规”与“技术上是否可检测”分开，并深入扫描 Windows 终端监控、Clash 配置和网络归因能力。  
> 日期：2026-08-20  
> 工具：codex  
> 当前状态：已完成当前用户权限下的 Windows 深度只读扫描；没有发现常见企业 EDR/DLP/MDM/事件转发或 TLS 检查组件，现有证据更支持公司通过 Wi-Fi/出口态势感知发现流量，但管理员专属的文件过滤器枚举仍有一个盲区。  
> 下一步：用户只需决定是否让我继续做“管理员权限补扫”，以及是否修正 Clash 的局域网无认证监听；本轮没有改动任何服务、网络或配置。

## 1. 先给客观结论

### 1.1 Windows 里有没有发现公司监控软件

**没有发现常见企业终端监控软件，置信度中高，但不能写成绝对没有。**

当前证据中：没有域加入、Entra ID 加入、Workplace 加入或有效 MDM 注册；没有 Microsoft Defender for Endpoint、SCCM、Intune、Sysmon、Windows Event Collector 订阅、企业根证书、浏览器企业策略，也没有 CrowdStrike、SentinelOne、Tanium、Carbon Black、奇安信、深信服、FortiClient、Zscaler、Netskope 等常见进程/服务/驱动。Windows 安全中心只登记了普通 Windows Defender。

所以就这台 Windows 的现状看，**公司“只能或主要从网络层发现”的可能性较高**。仍保留三个边界：

1. 当前 PowerShell 不是管理员，`fltmc filters` 被拒绝，无法完整列出内核文件系统过滤器；已能读到的运行驱动中没有第三方安全驱动。
2. 公司可能有自研代理，名称不含常见厂商关键词；本轮已额外检查所有非微软常驻服务和非微软运行进程，未看到明显候选，但无法用名称证明不存在。
3. 即使 Windows 完全没有代理，公司 Wi-Fi 控制器、DHCP、出口防火墙、NAT、DNS、NDR/态势感知平台仍能独立完成流量记录和终端归因。

### 1.2 Clash 会不会被发现

会，但“发现到什么程度”取决于观察位置：

- **只看普通出口流量**：能看到你的办公网内网 IP 在什么时间连接了哪些公网 IP/端口、连接时长和流量；代理内层访问的域名与内容通常看不到。当前代理外层是 VLESS + TCP/TLS + XTLS Vision，配置含 Reality 和 Chrome 客户端指纹。普通防火墙更像看到一条到某公网主机 443 的长连接；具备 DPI/App-ID、IP 信誉和行为模型的态势感知设备可能继续判为代理或异常加密隧道，但具体命中率取决于厂商规则，无法从本机证明。
- **看 DNS/SNI**：当前 Clash 开了 DNS 劫持与 fake-ip，16 个 DNS 上游配置中有 4 个 DoH、1 个 DoT、2 个明文 IP 上游；大量域名解析不会直接出现在公司 DNS 日志中，但启动解析、直连规则、DoH/DoT 端点及故障 fallback 仍可能留下可见信息。Reality 外层出现的 SNI也不等于内层真实访问域名。
- **能看 Windows 终端**：无需分析流量，软件清单、`mihomo.exe`/`Clash Party.exe`、Meta/Wintun 虚拟网卡、监听端口、防火墙规则和配置文件都能直接识别。
- **能从公司局域网探测本机**：当前配置不是仅本机监听，详见第 3 节。这是目前最明确、最容易修正的安全暴露点。

### 1.3 Tailscale 只装在这台电脑，公司还能不能检测

能。检测对象是**这台电脑发出的连接**，不要求公司服务器也安装 Tailscale。

同时，本机事实支持你的描述：当前 Windows 没启用 Tailscale SSH 服务、没有配置 Exit Node、没有向 Tailnet 发布子网路由或服务，主要角色是客户端并接受家庭侧路由，不是公司网络的出口节点、子网路由器或公司服务器代理。因此，检测到本机 Tailscale 流量不等于“公司服务器用了 Tailscale”，也不等于公司数据已经被传出。

不过当前确有一个 active direct 对端，Tailscale 底层对该公网对端选择了 WLAN，且 `tailscaled.exe` 监听 UDP 41641。公司出口至少可能看到：办公网源 IP、家庭对端公网 IP、UDP 端口、开始/结束时间、字节量和连接周期。Tailscale 官方说明 direct 是设备间 UDP 连接并由 WireGuard 端到端加密，所以网络侧通常看不到内层家庭 IP、SSH 命令或文件内容。

## 2. Windows 监控软件扫描证据

调查时间：2026-08-20；全部为本机只读查询。

| 检查面 | 结果 | 判断 |
|---|---|---|
| 域与设备注册 | `DomainJoined=false`、`AzureAdJoined=false`、`WorkplaceJoined=false` | 不是常见域管/Entra 管理终端 |
| MDM | 只有 Windows 自带的 3 个 Authority 占位项，无 UPN、无 Discovery URL | 没有有效企业 MDM 注册证据 |
| 安全产品 | SecurityCenter2 只有 Windows Defender | 没发现第三方 AV/EDR 登记 |
| Defender for Endpoint | `Sense` 服务不存在，MDE Status/OrgId 注册表不存在 | 未加入公司 MDE 租户 |
| SCCM / Intune / Azure Monitor | `CcmExec`、`IntuneManagementExtension`、`HealthService`、Azure Monitor Agent 均不存在 | 没发现这些管理代理 |
| Sysmon | 服务和事件日志均不存在 | 没有 Sysmon 进程/网络事件采集证据 |
| Windows 事件转发 | WEC 服务停止且手动启动；0 个订阅；无策略；ForwardedEvents 未启用 | 本机事件没有通过标准 WEC 持续转发 |
| WLAN 网络绑定 | WLAN 上启用项全部是微软 TCP/IP、LLDP、QoS、共享等组件 | 没发现第三方 NDIS/DLP/VPN 网络过滤器 |
| 企业 TLS 检查 | LocalMachine EnterpriseTrust=0、GroupPolicy=0；未发现常见安全厂商根证书 | 没有本机安装企业 HTTPS 中间人证书的证据 |
| 浏览器策略 | Chrome/Edge 四个机器/用户策略路径均不存在 | 没发现企业浏览器强制策略 |
| WMI 持久化 | 0 个命令消费者、0 个脚本消费者 | 没发现通过 WMI 隐藏执行的监控脚本 |
| 内核驱动 | 当前权限可读的运行驱动中未发现非微软安全驱动；完整 `fltmc` 被拒绝 | 结果偏向没有，但这是本轮唯一明确权限盲区 |
| `SecurityClaw` 日志 | 空日志、0 记录、无 owning provider；消息文件只是系统 `EventCreate.exe` | 是空的自定义事件日志壳，不是正在运行的监控证据 |

### 2.1 扫到的非微软常驻项是什么

| 软件/服务 | 本机事实 | 是否像公司监控 |
|---|---|---|
| ToDesk 4.9.7.1 | 机器级安装、有效厂商签名、自动服务正在运行、当前有公网外联；防火墙允许所有配置文件的任意入站/出站 | 它是远程控制软件，不是 EDR。无法从本机判断是谁安装、账号归谁；若公司安全策略关注远控工具，它比“只装着没运行”更容易被关注 |
| 来也 Agentic Process Automation Community | 2026-08-05 机器级安装、有效北京来也签名；自动服务运行，但当前只监听 127.0.0.1，没有公网连接 | 更像本机 RPA/自动化运行时，不像网络监控代理 |
| O+Connect / OplusRemoteService | 有效 OPPO 签名；跨设备/远程组件，多个 TCP/UDP 端口绑定所有地址或当前 WLAN 地址，防火墙允许任意配置文件入站 | 不是 EDR，但属于可被局域网发现的跨设备/远程功能 |
| 钉钉、OneDrive、微信、输入法、联想/AMD/Logitech 服务 | 普通办公、同步或 OEM 组件 | 没有证据表明它们在采集全机网络流量；是否受公司账号策略管理需看对应后台，不能从进程名推断 |

因此，扫描没有找到“公司偷偷装的安全探针”，但找到了 **Tailscale、Clash、ToDesk、O+Connect 四类网络/远控组件同时处于运行或开放状态**。如果态势感知按“远控/代理工具”归类，告警来源未必只有 Tailscale。

## 3. Clash 当前配置的实际含义

当前运行配置：`%APPDATA%\mihomo-party\work\config.yaml`。

### 3.1 本机透明代理路径

- `:10-15`：TUN 开启，`mixed` 栈，`auto-route=true`、`strict-route=true`、自动识别出口。
- `:16` 起：`route-exclude-address` 共 7,509 条，包含三大私网、Tailscale CGNAT 网段和大量 CN/主机路由；这让公司内网、Tailscale 内层地址及大量国内地址绕过 TUN 路由回环。
- `:7531-7559`：DNS 开启，IPv6 DNS 关闭，使用 fake-ip，`respect-rules=false`。
- `:7666-7670`：域名嗅探开启，纯 IP 解析和 DNS 映射开启；因此 Clash 自己能在日志里记录域名和进程名。
- 规则共 39 条：37 条 DIRECT、2 条指向 PROXY，最后有 MATCH 兜底。规则数量看似 DIRECT 多，但最近日志显示 8 月 19 日约 19,665 条走 PROXY、230 条 DIRECT；8 月 20 日扫描时约 5,075 条走 PROXY、8 条 DIRECT，说明大多数域名流量最终落入代理兜底。

### 3.2 代理外层

当前选择的节点记录在 `:7577-7587`：VLESS、TCP、UDP 开启、TLS 开启、`xtls-rprx-vision`，客户端指纹为 Chrome；同一配置中有一个 Reality 定义。

公司普通出口能确定“该办公终端持续访问某个公网服务器 443”，也能做 IP 地理位置、ASN、云厂商、威胁情报、连接时长和流量统计。它通常不能从这条外层连接直接还原内层访问的 Headscale、OpenAI、GitHub 或 SSH 内容。高级 NDR 是否能把它标成 Reality/VLESS，要看设备版本、规则库和流量质量，不能武断说一定能或一定不能。

### 3.3 明确的局域网开放问题

当前配置和运行状态同时满足：

- `allow-lan: true`（`:2`）；
- `bind-address: "*"`（`:7657`）；
- `lan-allowed-ips` 包含 IPv4/IPv6 全网通配；
- `authentication` 为空；
- 实际监听 `0/:: :7890、7891、7892`；
- Windows 有启用的 `mihomo.exe` 入站允许规则，Profile=Any、RemoteAddress=Any、LocalAddress=Any、TCP 端口=Any。

Mihomo 官方文档对这些字段的定义很直接：`allow-lan` 允许其他设备通过代理端口上网，`bind-address: "*"` 绑定所有地址，空认证即没有用户口令。因此在没有 Wi-Fi 客户端隔离的情况下，同一公司网络的设备可以探测甚至使用这台电脑的 HTTP/SOCKS/Mixed 代理。即使公司 Wi-Fi 隔离普通客户端，网络管理设备通常仍可能从管理侧探测。

这不是“公司能否看穿代理”的问题，而是你的电脑主动在公司网卡上开放了代理入口。若 WSL 需要访问 Windows 7890，正确收口应是只放行 WSL NAT 网段/回环地址，而不是允许整个 WLAN；具体 WSL 网段会变化，修改前需同时处理 Mihomo allowlist 和 Windows 防火墙，不能只改一边。

## 4. Tailscale 当前角色与流量路径

### 4.1 它确实只是客户端吗

从当前偏好看基本是：

- `WantRunning=true`；
- `RunSSH=false`；
- `ExitNodeID/ExitNodeIP` 均未设置；
- `AdvertiseRoutes=null`、`AdvertiseServices=null`；
- 没有发布 Exit Node、子网路由或服务；
- `RouteAll=true` 在这里表示接受 Tailnet 路由，不是“公司全部互联网流量经 Tailscale 出口”；
- `ShieldsUp=false`，表示未开启拒绝 Tailnet 入站的保护开关，但是否真有可访问服务仍取决于 Windows 服务和 Tailnet ACL。

所以本机不是在给公司服务器做代理，也没有证据显示任何公司服务器安装了 Tailscale。它是 Windows 上的 Tailnet 客户端，通过家庭侧节点/路由访问家庭设备。

### 4.2 哪些流量进了 Clash，哪些可能直出

对 8 月现存 Clash 日志按 `tailscaled.exe` 重新分类：

- 2,333 条到 Tailscale 官方域名的 TCP 记录：全部 `PROXY`；
- 16 条到自建控制域名的 TCP/UDP 记录：全部 `PROXY`；
- 另有 4 条代理拨号失败记录；
- 当前 active peer 被 Tailscale 判为 direct，操作系统对该对端的底层路由选择 WLAN；这类 peer UDP 没出现在 Clash 的 `tailscaled.exe` 日志里。

因此当前最合理的链路图是：

```text
控制面 / 官方 DERP、探测域名
tailscaled → Mihomo TUN → VLESS/Reality 节点 → Headscale/Tailscale 服务
公司出口主要看到代理节点

活跃家庭对端数据面
应用访问 Tailnet IP → Tailscale 加密封装 → WLAN direct UDP → 家庭公网对端
公司出口可能看到家庭公网 IP、UDP 会话和流量特征
```

这也解释了为什么“Clash 日志里 Tailscale 全是 PROXY”和“公司仍可能看到 Tailscale direct”可以同时成立：控制面与数据面走的不是同一条路径。

## 5. 公司只靠网络层能定位到哪些信息

| 观察点 | 高概率能定位 | 通常不能仅靠这一层定位 |
|---|---|---|
| Wi-Fi AP/控制器 | 当前设备 MAC、连接的 AP/SSID、上线下线时间、信号与漫游、会话分配的内网 IP | Windows 里具体哪个进程发包、SSH 命令内容 |
| DHCP | 内网 IP ↔ MAC 的租约时间；Windows 当前启用了地址注册，部分环境还会记录主机名 | 真实使用人，除非租约/资产系统另有关联 |
| 802.1X/门户认证 | 如果公司 Wi-Fi 使用员工账号、证书或手机号认证，可直接关联员工身份 | 本轮没有读取 Wi-Fi 凭据，无法确认公司采用哪种认证 |
| 出口防火墙/NAT | NAT 前的内网源 IP、目的公网 IP/端口、协议、时间、字节量；NAT 后公网源地址 | 代理隧道内层的访问内容 |
| DNS | 直接使用公司 DNS 时的域名；本机当前 fake-ip + DoH/DoT 会减少这部分，但不能保证为零 | DoH/DoT 加密请求中的域名 |
| TLS/DPI/NDR | 未加密 SNI（若存在）、TLS/QUIC 指纹、应用特征、IP 信誉、周期性和流量模型 | WireGuard/TLS 内的 SSH 命令、文件内容、Tailnet 内层 IP |
| 同网段/管理侧端口扫描 | 当前 7890～7892 代理端口、O+Connect 等监听服务（是否可达受隔离策略影响） | 配置文件里的节点口令，除非终端本身被读取 |

### 5.1 能不能精确定位到“你本人”

- 定位到**这台 Windows 会话**：高。当前 WLAN 使用 DHCP，设备有稳定的会话 MAC 和内网 IP；AP、DHCP、网关日志可按时间串起来。即使开启随机 MAC，同一次/同一配置文件下的会话仍可关联。
- 定位到**电脑资产**：若这是登记过的办公电脑，MAC、主机名、资产系统、钉钉/门户登录记录可以关联；本轮没有公司资产系统权限，无法核实关联方式。
- 定位到**员工账号**：若 Wi-Fi 用 802.1X、企业证书或认证门户，通常可以；若只是共享 Wi-Fi 密码，则原始网络流量本身只有设备/IP，仍需资产表或现场信息补充。
- 定位到**具体进程是 Clash/Tailscale**：纯 NetFlow/防火墙日志做不到直接读取 Windows PID；需要 DPI 推断或终端遥测。本机当前没有发现后者。
- 定位到**你 SSH 做了什么**：仅靠网络层通常做不到，Tailscale 数据面是 WireGuard 端到端加密；能看到连接双方公网地址、时间和流量，不等于能看到命令或文件。

## 6. “公司是否已经知道 Headscale 服务器”

当前证据更精确的说法是：

- Clash 正常期间，自建控制域名的已记录流量全部进入 Reality/VLESS 代理，普通公司出口看到的是代理节点，不是 Headscale 服务器。
- direct 数据面对端是家庭设备的公网地址；它不必与 Headscale 服务器相同。两者是否同机，本机材料没有证据。
- 如果公司能读终端配置，则 Tailscale 的 ControlURL 直接给出 Headscale 域名；但本轮没发现这类终端代理。
- 如果公司只拿到代理外层 IP，不能仅凭那条流量反推出 Headscale 域名；如果同时拿到 DNS、代理故障直连、终端镜像或公开 DNS/证书透明度信息，则可能继续关联。
- 本轮没有主动解析、访问或扫描你的公网服务器，所以其 IP、国家/地区、证书和公开服务指纹仍未核实。

## 7. 按当前证据给出概率判断

| 问题 | 判断 | 原因 |
|---|---|---|
| Windows 装有常见公司 EDR/DLP | 低 | 多个独立管理面均为阴性；仅管理员 minifilter 尚未补扫 |
| 公司主要从网络态势感知发现 | 中高 | 群消息明确来自态势感知；本机没有终端上报链路证据 |
| 公司出口能把 Clash 外层识别为代理 | 中到高 | 持续公网 443 隧道、VPS/IP 情报和行为模型可用；具体依赖厂商规则 |
| 公司局域网能发现 Clash 监听端口 | 中到高 | 本机配置与防火墙均全网开放；唯一未知是 WLAN 客户端隔离/管理侧扫描能力 |
| 公司能看到 Tailscale 官方域名 | 当前普通出口偏低 | 现存 2,333 条官方域名记录全部经 Clash 代理；故障/旁路时另说 |
| 公司能看到 Tailscale direct UDP | 中高 | 当前确有 active direct，对端底层路由选 WLAN；本机同时监听 Tailscale 默认 UDP 41641 |
| 公司能读到 SSH 内容 | 低 | 仅网络侧是 WireGuard + SSH 双层加密；终端控制是另一回事 |
| 能把流量关联到本机 | 高 | DHCP + AP + NAT 前源 IP 时间线足够 |
| 能把流量关联到员工本人 | 中到高但未核实 | 取决于 Wi-Fi 认证和资产登记，当前缺公司侧信息 |

## 8. 单纯从“安全做得更严谨”角度的建议

这些建议不是隐藏流量，而是减少无意开放面：

1. **优先收口 Clash LAN 监听**：如果只需 Windows 本机，设 `allow-lan: false`；如果 WSL 必须访问 7890，则只允许 WSL NAT 源网段，并把 Windows 防火墙的 Mihomo 入站 RemoteAddress 同步限制到该网段，不能保留 `Any`。
2. **给显式代理入口加认证**：当前 `authentication` 为空。即使只放行 WSL，认证也能降低误用风险；凭据只能放受控本地配置，不能写入项目文档。
3. **复核 ToDesk 与 O+Connect**：如果不是当前工作需要，停止自动服务和宽泛入站规则；它们同样属于远控/跨设备暴露面。
4. **Tailscale 只做出站客户端时可开启 Shields Up**：这不会影响本机主动访问家庭设备，但会阻止 Tailnet 对本机新建入站连接；实施前仍需核实你是否依赖反向访问。
5. **用 Headscale ACL 固化单向最小权限**：只允许这台 Windows 访问指定家庭 SSH 主机/端口，不允许家庭节点反向访问办公电脑，也不接受不需要的家庭子网路由。
6. **若公司已批准这些工具，保留批准依据和用途边界**：安全平台看到的是流量特征，不知道业务背景；审批/备案能把“未知异常”变成“已知授权”。

## 9. 本轮没有做的事与剩余未知

- 没有管理员权限枚举 `fltmc`、WFP callout 和全部内核过滤器；若要把“无终端监控”的置信度从中高再提高，需要一次管理员只读补扫。
- 没有读取 Wi-Fi 密码、员工账号、SSID 明文或认证配置，因而不知道公司是否使用 802.1X/门户认证。
- 没有访问公司态势感知平台，无法知道其具体厂商、App-ID 规则和告警字段。
- 没有探测同网段端口可达性；Clash 是否真能被普通同事电脑连接，取决于公司 WLAN 隔离，但管理侧仍可能可见。
- 没有读取 Clash 节点地址、UUID、密码或 Headscale 真实域名，也没有把这些敏感值写入文档。

## 10. 官方资料

- [Mihomo General Configuration](https://wiki.metacubex.one/en/config/general/)：`allow-lan`、`bind-address`、LAN allowlist 与代理认证的官方定义。
- [Mihomo Proxy Ports](https://wiki.metacubex.one/en/config/inbound/port/)：HTTP、SOCKS、Mixed 端口的用途。
- [Mihomo DNS Configuration](https://wiki.metacubex.one/en/config/dns/)：fake-ip、DoH/DoT、nameserver policy 的含义。
- [Tailscale Connection Types](https://tailscale.com/docs/reference/connection-types)：direct/DERP/peer relay 及 WireGuard 端到端加密说明。
- [Tailscale Firewall Ports](https://tailscale.com/docs/reference/faq/firewall-ports)：direct UDP 41641、STUN 3478、控制/DERP 443 等典型流量特征。
