# 办公终端 Tailscale / Clash 网络安全调查

> 日期：2026-08-20  
> 工具：codex  
> 当前状态：已完成本机离线、只读调查；确认本机在公司 Wi-Fi 上运行 Tailscale 与 Clash，存在可被公司网络侧或终端侧识别的真实证据，但仅凭群通知无法证明被通报的终端一定就是本机。  
> 下一步：先断开公司 Wi-Fi，再停止并禁用 Tailscale、退出 Clash；如公司要求“及时清理”，完成卸载后用本文末尾话术向安全同事确认替代方案。

## 1. 一句话结论

**这台电脑确实具备被通报命中的全部技术条件，属于高风险候选；但没有安全平台告警中的时间、源 IP、终端编号或目的地址，不能把“可能是我”写成“已经证实是我”。**

Clash 分流只能改变公司出口看到的外层目的地，不能让 Tailscale 在终端上消失，也不能保证所有 Tailscale 数据面流量都被代理。当前证据中，Tailscale 控制面和探测流量进入了 Clash 代理，但一个活跃对端的底层路由明确选中了 WLAN。因此，“配置了分流”不等于“公司看不到”；继续调整端口、域名或规则也不是合规解决办法。

## 2. 调查边界

- 只读检查 Windows、WSL、Tailscale 状态、Windows 路由/服务/事件日志、Clash 配置与历史日志、AI 工具本地日志目录。
- 没有运行 `tailscale netcheck`、`ping`、`curl`、DNS 查询、端口扫描、抓包或公网服务器探测。
- 没有访问 Headscale 服务器，没有修改 Tailscale、Clash、Windows 网络、服务或防火墙。
- 公网域名、服务器 IP、家庭公网 IP、Tailnet 节点名均未写入本文；控制地址只在内存中做了匹配。

## 3. 已核实的本机事实

调查时间为 2026-08-20 11:31～11:50，以下结果来自对应的本机只读查询。

| 证据 | 查询结果 | 能说明什么 |
|---|---|---|
| E1 Windows 服务/进程 | `Tailscale` 服务为 `Running + Automatic`；存在两个 `tailscaled.exe`；`Clash Party.exe` 和 `mihomo.exe` 同时运行 | 不是残留安装包，而是正在运行的网络软件；开机后会自动恢复 Tailscale |
| E2 Tailscale 本地状态 | `BackendState=Running`、`TUN=true`、本机在线；8 个对端中 4 个在线、1 个活跃；活跃对端为 direct；累计对端计数约接收 62.9 MB、发送 16.5 MB | 已发生真实通信，不是“装了但没用” |
| E3 端口与网卡 | Windows 存在 `Tailscale Tunnel`、`Meta Tunnel`、`wintun`；`tailscaled.exe` 在 UDP 41641 上监听 | 终端资产盘点、进程盘点、驱动/虚拟网卡盘点都能直接识别 |
| E4 当前对端出口 | 对活跃对端地址执行本地 `Find-NetRoute`，选中的接口为 `WLAN`；Tailscale 状态同时判定该对端为 direct | 至少存在直接对等 UDP 从公司 Wi-Fi 出口出现的现实路径；这类流量不会因为控制面进了 Clash 就自动消失 |
| E5 当前路由/Clash 配置 | Tailscale 对端和家庭子网使用更具体路由；Mihomo TUN 开启 `auto-route`、`strict-route`，并排除 Tailscale CGNAT 网段；当前配置见 `C:\Users\29455\AppData\Roaming\mihomo-party\work\config.yaml:10-20`、规则见同文件 `:7649` | 现有配置的目标是保证 Tailscale 不被 Clash TUN 绕死；不是隐藏 Tailscale |
| E6 Clash 历史 | 8 月 14/16/17/18/19/20 分别记录 10/718/470/280/671/179 条由 `tailscaled.exe` 发起的连接；正常记录全部显示 `using PROXY`，另有 4 条代理连接超时 | 控制面、HTTP 探测、STUN 等大量流量确实进入代理；同时说明 Clash 自己完整记录了 Tailscale 进程和目的地 |
| E7 Headscale 控制域名 | 从 Tailscale 本地偏好读取控制地址后，在 Clash 历史中匹配到 20 条，均走 `PROXY`；Windows 当前 DNS 缓存中无该域名 | Clash 正常工作时，公司出口通常先看到代理节点而不是 Headscale 域名；这不是对历史所有时段的保证 |
| E8 Windows 防火墙事件 | 最近 30 天有 31 次 `Tailscale-In` 规则添加事件和 31 次 `Tailscale-Process` 规则删除事件（事件 ID 2097/2052） | 即使删软件，Windows 本地仍已有明确历史痕迹；不应删日志或试图抹痕 |
| E9 Windows 流量日志能力 | 防火墙 `LogAllowed=false`、`LogBlocked=false`；DNS Operational 日志未启用；Security 中未读到 5156 连接审计；Tailscale 服务日志目录因 Windows ACL 无权读取 | 不能靠 Windows 自带日志完整还原过去每一条流；“本机没日志”不代表公司出口没日志 |
| E10 终端管理迹象 | Windows 未加入传统域、Entra ID 或 Workplace；标准安全产品只发现 Windows Defender，未发现命名明显的 Sysmon/EDR 服务 | 本机更像非域管终端，降低“通过常见企业代理取证”的概率；不能排除隐藏代理、Wi-Fi 控制器、出口防火墙/NDR |

当前配置与以前排障记录互相印证：`/home/t/projects/personal/05clash/2026-08-11-clash-tun-fix.log.md:127-140` 明确把 Tailscale 网段加入 TUN 路由排除，并曾验证 Tailscale direct；同文件 `:159-178` 说明 WSL 已改为 NAT，WSL 到家庭设备仍经 Windows NAT + Tailscale。

## 4. 公司侧分别可能看到什么

### 4.1 只看公司 Wi-Fi / 出口防火墙

高概率可见：终端在什么时间向哪个公网 IP、端口、协议发送了多少流量，并能通过 DHCP、无线控制器或认证会话把流量关联到终端。Tailscale 官方说明，直接 WireGuard 通信通常使用源 UDP 41641，STUN 使用 UDP 3478，控制/DERP 通常使用 TCP 443，另外会有 TCP 80 探测；本机 Clash 日志正好出现了 41641、3478、443、80 这些组合。

当前 Clash 正常时，已进入代理的连接在公司出口表现为“到代理服务器的加密连接”，公司通常看不到其中的 Headscale 域名和内层 SSH 内容。但这会新增另一项更直接的风险：群通知同时点名“代理工具”，而本机正在运行 Clash/Mihomo。公司即使没把它判成 Tailscale，也可能判成代理/异常加密外联。

### 4.2 能看终端进程、软件、驱动或事件日志

可见性很高：软件清单直接包含 Tailscale 1.98.8 和 Clash Party 1.9.6，服务、进程、虚拟网卡、Wintun 驱动、UDP 41641 监听、防火墙事件都带明确名称。此时改域名、改端口或把流量塞进代理没有意义。

### 4.3 能否认出 SSH 内容

网络侧通常能判断有持续加密会话、流量方向和字节量，但不能直接读取 Tailscale 内层 SSH 命令和文件内容。若公司能管理终端，仍可能从进程、命令历史、SSH 配置、AI 会话记录或文件审计侧看到用途；“链路加密”不等于“终端行为不可见”。

## 5. 群里说的“部分终端”是不是本机

### 已能确认

- 本机在群通知当天仍连接公司 Wi-Fi，并运行 Tailscale、Clash。
- Tailscale 当前在线、有活跃 direct 对端、有实际字节计数。
- Clash 从 8 月 14 日起持续记录 `tailscaled.exe` 外联，今天 08:52～11:34 仍有记录。
- 所以本机**完全可能**在安全平台的候选列表里，不能按“用了 Headscale/Clash，所以不会被看见”处理。

### 仍不能确认

群通知没有给出告警时间、办公网源 IP、MAC、终端编号、目的 IP/域名、命中规则或流量截图。缺少这些字段，无法把群里的泛化通知与本机一一对应。若要实锤，只需向安全同事要一行脱敏告警：`时间 + 终端编号/源IP末段 + 目的IP/域名 + 规则名`，再与本文时间线比对；不需要自己继续发测试流量。

**综合判断：本机是高概率候选，但“就是本机”尚未证实。**

## 6. 公司能否查到自建 Headscale 公网服务器

分场景看：

1. **从当前正常的 Clash 出口流量看**：控制域名的 20 条已知记录都进了代理，公司出口首先看到代理节点，不一定看到 Headscale 域名或服务器 IP。
2. **从 direct 数据面看**：公司能看到家庭对端的公网 IP/UDP 会话；它未必等于 Headscale 服务器 IP。若两者部署在同一公网主机，则可被关联，当前本机材料无法核实是否同机。
3. **从终端侧看**：Tailscale 本地偏好中保存了自定义 ControlURL。具备终端读取权限的安全软件可以直接得到域名，不需要从网络猜。
4. **从公开互联网信息看**：域名的公开 DNS、IP 归属、WHOIS/ASN、反向解析以及公开 CA 证书的 Certificate Transparency 记录都可能被查询。若服务器暴露可识别的 Headscale 接口，获知域名/IP 后还能进一步确认。本文没有主动访问服务器，也没有成功核实该域名当前的 DNS/CT 明细，所以服务器所在国家/地区、证书类型和是否暴露特征仍为未知，不能猜成“境外”或“境内”。
5. **Clash 故障或退出时**：不能假设控制连接仍会被代理。本地历史已经出现 4 条代理拨号超时；虽然没有证据证明随后直连成功，但任何 fallback、规则失效或 TUN 未启动时段都可能让控制域名/IP直接暴露给公司出口。

结论：**公司有能力查到，但能否从当前这批出口日志直接查到，取决于它拿到的是代理外层、direct 对端流量，还是终端遥测。不要把“暂时套在代理里”当成不可发现。**

## 7. WSL、work-wsl 与 AI Harness 的额外风险

- WSL 内没有安装 Tailscale，只有 NAT 虚拟网卡；Tailscale 在 Windows 宿主运行。WSL 当前没有 `HTTP_PROXY/HTTPS_PROXY/ALL_PROXY` 环境变量，现存 Codex/其他 AI 进程直接建立 TCP 443，随后是否被代理由 Windows TUN 决定。
- `work-wsl` 内没发现传统运行日志；`.claude` 主要是设置/工作树，`deepseek-harness` 当前只有需求文件。真正的大量历史位于用户目录：`.codex` 约 3.12 GB、`.claude` 约 0.94 GB、OpenCode 数据约 0.32 GB。
- 多数会话文件为 600，但目录为 755，OpenCode 日志和部分 Claude 文件为 644。其他本地普通用户可能读取 644 文件；管理员/终端安全软件不受这些权限保护。
- 这些日志不是公司出口告警证据，却可能包含提示词、命令、文件路径和工具输出。若公司未明确批准向外部 AI 发送源代码或业务数据，这是独立于 Tailscale 的数据合规问题，应单独向负责人确认。不要用删日志来应对本次通知；先保留证据，并按公司留存要求处理。

## 8. 建议处置顺序

### 立即做（按顺序，避免关闭 Clash 后 Tailscale 突然直连）

1. 先保存本文，然后断开公司 Wi-Fi。
2. 用管理员 PowerShell 本地停止并禁用 Tailscale：

   ```powershell
   Stop-Service -Name Tailscale -Force
   Set-Service -Name Tailscale -StartupType Disabled
   Get-Service -Name Tailscale
   ```

3. 从 Clash Party 托盘完整退出，并关闭开机启动；确认 `Clash Party.exe`、`mihomo.exe` 均不在任务管理器中。
4. 群通知要求“及时清理”时，在 Windows“已安装的应用”卸载 Tailscale 和 Clash Party。卸载完成前不要重新连接公司 Wi-Fi。
5. 重连后只做本地确认：服务/进程/虚拟网卡不再存在。不要为了验证而 ping 家庭设备、跑 `netcheck` 或访问 Headscale。
6. 不删除 Windows 事件日志、Clash 日志、Tailscale 状态文件，不伪装进程、改域名、换端口或做流量混淆。这些动作既不解决合规问题，也可能让正常自查变成“规避监控”。

### 后续替代

- 首选公司批准的 VPN、堡垒机、远程开发机或远程支持工具。
- 没有批准方案前，不要从办公终端访问个人设备。
- 若确需处理个人设备，使用个人电脑和个人网络，并确保不带出公司代码、数据、密钥或文档；个人热点只改变网络出口，不能让公司终端上的未授权软件变合规。

## 9. 给安全同事的逐字话术

完成停止/卸载后再发，建议私聊安全联系人，不在大群贴域名、IP或日志：

> 我按群通知自查到这台办公终端安装过 Tailscale 和 Clash。Tailscale 原用途是从开发环境访问个人设备，看到通知后我已经停止并按要求清理，Clash 也已停止。请帮忙确认是否需要我提供终端编号和大概使用时间配合核查；后续公司允许使用的远程开发、外网访问或堡垒机方案是什么？我按批准方案调整。

若对方要核对是否命中，可继续说：

> 麻烦给我一行脱敏告警信息就可以：发生时间、终端编号或源 IP 末段、目的 IP/域名、命中规则名。我本机保留了日志，可以配合对时间，不需要再发测试流量。

## 10. 官方资料校准

- [Tailscale：防火墙端口](https://tailscale.com/docs/reference/faq/firewall-ports)：说明 direct UDP、STUN、控制/DERP 和 HTTP 探测所用的典型端口。
- [Tailscale：连接类型](https://tailscale.com/docs/reference/connection-types)：说明连接会先经 DERP，并尝试升级为 direct。
- [Tailscale：配置自定义控制服务器](https://tailscale.com/docs/how-to/set-up-custom-control-server)：确认 Headscale 是客户端自定义控制服务器 URL 的正式用法。
- [Tailscale：控制面与数据面](https://tailscale.com/docs/concepts/control-data-planes)：用于区分 Headscale 控制连接与设备间数据连接。

## 11. 证据不足项

- 群通知的准确发送时间与原始告警字段：未知。
- Headscale 服务器 IP、国家/地区、ASN、公开证书/CT、与家庭对端是否同机：未核实。
- 公司 Wi-Fi 使用哪种防火墙/NDR/无线控制器、是否装有未命名终端代理：未知。
- Tailscale 系统服务完整日志：`C:\ProgramData\Tailscale` 被 Windows ACL 拒绝读取。
- 公司是否批准外部 AI、Clash、个人远程设备：没有制度原文，必须问人，不能按“为了工作方便”推定为允许。
