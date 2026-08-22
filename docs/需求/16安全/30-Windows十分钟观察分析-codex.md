# Windows 十分钟 Trend / WSL / 网络观察分析

> 日期：2026-08-20  
> 工具：codex  
> 当前状态：14:10:06～14:20:14 的10分钟观察已完整结束并分析；Trend 未出现活动证据，Clash、Tailscale、ToDesk、输入法和 Windows 局域网流量已完成分层归因。  
> 下一步：如需定位高频网关 ICMP 的具体进程，另开一轮针对 ICMP/WFP 的短时进程归因；原始 PCAP 与事件文件含敏感本机信息，不进 Git、不上传。

## 1. 一句话结论

本轮没有观察到 Trend 进程、Trend 驱动对象句柄、Trend 日志新增或可归因给 Trend 的网络连接，因此**没有证据表明 Trend 在这10分钟内读取 WSL 或向外上报**；但这不是“驱动永远不会工作”的证明。

公司网络侧在这10分钟内能够稳定看到本机 WLAN 地址向一个 Mihomo 代理节点建立大量 TCP/443 加密连接，也能看到少量绕过代理的 Tailscale TCP/443、ToDesk、腾讯输入法和 Mihomo DNS 上游连接。代理内层的 ChatGPT、Claude、GitHub 等目标域名没有以明文 DNS、HTTP Host 或 TLS SNI 出现在物理 WLAN 数据包中。

## 2. 采集完整性

结果目录：`C:\Users\29455\AppData\Local\Temp\codex-trend-watch-20260820-141006`。

- 请求600秒，实际607.8秒；
- Pktmon 记录519,660条，丢弃0条；
- ETL 289,232,849字节，SHA-256 `FE91F157366A45A3992127D2483B6DCE3FFD8E180197EFD9269E6F84C0889489`；
- PCAPNG 416,101,296字节，SHA-256 `26A655C12E186932F506B223841E9A4AC01AF5F0B5D1817FC88560063BC40AF5`；
- 主体在14:20:08正常停止 Pktmon，14:20:14转换完成；独立看门狗在14:20:21确认已正常收尾，没有接管或误停其他会话；
- `events.jsonl` 中 `ObservationError=0`，无 `FatalError`。

Pktmon 同时记录物理和虚拟网卡，同一个包会在多个组件重复出现。分析按 IP 报文和1毫秒时间窗去重；物理 WLAN 的802.11记录去重后为114,136条，不能直接把519,660当成唯一上网包数。

## 3. Trend 与 Defender

`events.jsonl` 的10分钟结果：

| 观察项 | 结果 |
|---|---:|
| Trend 进程 | 0 |
| `TmComm/TmActMon/TmEvtMgr/VprotectTMFilter` 句柄匹配 | 0 |
| Trend 三份系统日志新增 | 0 |
| Trend 或 PID 4 远程 TCP 连接 | 0 |
| 观察错误 | 0 |

因此，本轮不能回答 Trend “上报了什么正文”，因为没有捕获到可归因给 Trend 的上报连接或日志动作。

Clash 日志在窗口内记录了一次 `MpDefenderCoreService.exe` 到微软事件域名的 TCP/443，走 Mihomo 代理；正文为 TLS 密文。实时只读查询显示 Defender 处于普通防病毒正常运行状态，但 MDE `OnboardingState` 为空，注册表状态和策略均没有 OrgId。故这条证据支持“微软 Defender 遥测”，不支持“公司已将本机接入 Microsoft Defender for Endpoint”。

## 4. 公司 WLAN 实际可见流量

本机 WLAN 地址为 `10.66.10.153`。以下字节数为物理 WLAN 报文去重后的 IP 层近似值：

| 远端/类型 | 上行 | 下行 | 归因证据 | 网络侧含义 |
|---|---:|---:|---|---|
| `64.64.252.58:443` | 16.84 MB | 49.66 MB | 捕获跨度约599.9秒；捕获后相同四元组的进程所有者为 `mihomo.exe`，配置 `proxies` 也包含该地址 | 公司出口能稳定看到单一公网443端点、连接数量、时长和流量；是否判为代理取决于 DPI/IP 情报 |
| `101.42.45.53:443` | 2.76 KB | 27.88 KB | 捕获中的本地端口53380在复查时仍由 `tailscaled.exe` 持有；另有同目的端口64890连接 | 高概率为 Tailscale 控制/保活直连；网络侧能见 IP、443、时序和字节，正文不可见 |
| `223.6.6.6/120.53.53.53/223.5.5.5:443` | 约42 KB | 约85 KB | 配置中的 DNS/绕行地址；复查时前两者连接由 `mihomo.exe` 持有 | Mihomo 的加密 DNS 上游直连，不等于访问目标域名明文外泄 |
| `140.143.217.39:443` | 4.14 KB | 2.40 KB | 捕获本地端口64843在复查时仍由 `ToDesk.exe` 持有 | ToDesk 持续保活，可能被网络侧按远控产品/IP识别 |
| `101.226.95.60:443` | 7.97 KB | 4.49 KB | 捕获本地端口49690在复查时仍由 `wetype_server.exe` 持有 | 腾讯输入法服务直连 |

物理 WLAN 中没有 UDP 数据包，因此本轮没有看到 Tailscale 常见的 UDP 41641 direct、UDP 3478 STUN 或其他 UDP 数据面流量。捕获后 `tailscale status --json` 也显示服务在线，但活动对端0、具有 direct endpoint 的对端0。结论仅适用于这10分钟，不能代替全天观察。

局域网还有多台 `10.66.x.x` 与本机 TCP/7680 的小流量连接；当前端口所有者为 `svchost.exe/DoSvc`，即 Windows Delivery Optimization，不是 Trend。另有约10,169个发往网关 `10.66.10.254` 的 ICMP Echo、10,161个响应，平均约17次/秒；PCAP 不能提供 ICMP 调用进程，暂不能归因，但它是本机主动探测网关，不是 Trend 上报证据。

## 5. Clash 内外层差异

窗口内 Clash core 日志记录382条新连接，全部匹配 `PROXY`；主要来源为 WSL/未归因本地流量、Claude、浏览器、微信、钉钉、VS Code 等。物理 WLAN 上看到的是 Mihomo 到代理节点的外层 TCP/443，没有发现明文 DNS、HTTP Host 或可提取的 TLS SNI。

完整 PCAP 同时抓了 WSL NAT、Meta Tunnel 等本机虚拟网卡，所以在本机侧仍能看到：

- Clash fake-IP DNS 映射，例如 ChatGPT、Anthropic、GitHub、微软和腾讯相关域名；
- WSL 到显式代理的明文 `CONNECT host:443` 请求头；
- 进入代理前的少量明文 HTTP Host。

这些内容存在于本地 PCAP，不代表公司出口能在代理外层直接读取。正文经过 TLS/VLESS/Reality 后仍是密文，本轮未读取 TLS 密钥、未解密应用正文、未导出 Cookie 或 Token。

## 6. Windows 能看到多少 WSL

`events.jsonl` 记录了72个相关 Windows 进程，其中42个 `wsl.exe` 记录、24个 `wslhost.exe`。42不是“新开了42个终端”：首轮扫描会登记已经存在的进程，而且一次 WSL 启动通常同时出现 System32 启动桩、Store 版 WSL 和 `wslhost.exe`。

Windows 进程表能直接看到：

- WSL 发行版名称；
- 显式 `wsl.exe -e/-c` 后面的启动命令；
- VS Code WSL Server 的路径和启动选项；
- 启动 shell 时的工作目录，包括当前项目目录；
- Claude WSL bridge 的程序和本地 socket 路径。

但在已经打开的交互式 bash/zsh 中逐条键入的 Linux 命令不会为每条命令新建 Windows `wsl.exe`，因此本轮 Windows 进程枚举没有直接得到 shell 历史或每条终端命令。若终端内程序联网，本机管理员抓虚拟网卡仍可看到目标域名/地址；TLS 内的提示词、SSH 命令和文件正文仍不可见。

事件文件还包含 VS Code WSL Server 的短期本地连接令牌等命令行字段，因此它和 PCAP 都应视为敏感材料，只留在本机 TEMP，不贴聊天、不提交 Git。

## 7. 能与不能下的结论

可以确认：

1. 这10分钟 Trend 没有出现可观察的使用者、日志动作或网络上报；
2. Clash 外层非常明显，网络侧能把流量精确关联到该 WLAN 会话；
3. Tailscale 没有 peer UDP 数据面，但有一条可见的持续 TCP/443 连接；
4. Windows 管理员能够看到 WSL 启动链和显式启动参数；
5. 普通公司出口只能看到外层流量，不能从本轮包里直接读出代理内层或 TLS 正文。

不能确认：

1. Trend 历史上从未工作，或未来不会工作；
2. 公司出口是否已部署某家 DPI/态势感知、是否已对代理 IP 或 Tailscale IP 告警；
3. Defender 加密遥测正文具体包含什么；
4. 高频 ICMP 是哪个本机进程发起，除非再做带进程归因的短时 ETW/WFP 观察。
