# Windows 管理员内核监控补扫

> 本文补充并纠正 `10b-Windows监控与流量可见性调查-codex.md`，纠正原因：管理员权限成功补齐 `fltmc`、运行驱动签名与 WFP 全量状态，发现普通权限扫描遗漏的 Trend Micro 内核组件。  
> 日期：2026-08-20  
> 工具：codex  
> 当前状态：管理员只读补扫完成；确认存在三枚正在运行的 Trend Micro 行为监控驱动，但未发现配套进程、普通服务、已安装产品、产品目录或 Trend Micro 网络过滤提供者，当前证据不足以认定它是公司正在使用并上报的终端监控客户端。  
> 下一步：不要自行停用或删除驱动；若需要判定归属，应让公司 IT/安全部门按驱动名和版本核对资产策略，或经授权后做一次“重启前后及管理端登记”核验。

## 1. 结论变化

`10b` 中“当前权限可读的运行驱动中未发现非微软安全驱动”在当时权限下成立，但管理员补扫后已不再完整。最新结论如下：

1. **Windows 内核里确实有第三方安全监控组件。** `tmactmon`、`tmcomm`、`tmevtmgr` 三枚 Trend Micro 驱动均处于 `Running`，启动方式分别为自动、系统、自动。
2. **它们具备行为/事件观测能力，不是普通硬件驱动。** 驱动 INF 的 Class 为 `AntiVirus`；Trend Micro 官方资料将其描述为系统活动/事件接收接口、隐藏文件/注册表/进程/驱动检测模块和 AEGIS 事件管理器。
3. **目前没有发现一套完整、正在上报的 Trend Micro 客户端。** 本机没有 Trend Micro 用户态进程、普通服务、卸载注册项、`Program Files`/`ProgramData` 产品目录；Windows 安全中心仅登记 Windows Defender。
4. **本机网络过滤层没有发现 Trend Micro。** WLAN 的已启用 NDIS 绑定全部为微软组件；WFP 仅有微软提供者与本次 Codex Windows 沙箱提供者，没有 Trend Micro、企业 VPN/DLP/EDR 提供者。
5. 因此最稳妥的判断是：**存在仍在加载的 Trend Micro 行为监控内核组件，像历史安全软件卸载/系统重置后留下的残留，但仅凭本机不能证明残留，也不能证明公司后台正在接收它的数据。** “公司当前终端监控已实锤”与“机器完全没有监控组件”都不成立。

## 2. 管理员扫描证据

扫描脚本以 Windows 管理员身份运行，报告首部返回 `Elevated: True`；执行内容均为查询或导出，未修改驱动、服务、注册表、防火墙、Defender 或网络配置。原始结果保存在：

- `%TEMP%\codex-admin-kernel-audit.txt`
- `%TEMP%\codex-admin-wfp-state.xml`

### 2.1 文件系统过滤器

管理员查询 `fltmc filters` 得到：

| 过滤器 | 实例数 | 高度 | 厂商判断 |
|---|---:|---:|---|
| `tmevtmgr` | 8 | 328510 | Trend Micro |
| `WdFilter` | 8 | 328010 | Microsoft Defender |
| 其余 `bindflt/UCPD/ahflt/storqosflt/wcifs/CldFlt/bfs/FileCrypt/luafv/UnionFS/npsvctrig/Wof/FileInfo` | 不等 | 不等 | Windows 系统组件 |

`fltmc instances` 显示 `tmevtmgr` 已挂载到 C:、E:、卷影副本和 `\Device\Mup` 网络文件系统路径，不是只存在于磁盘但未加载的文件。其高度 328510 高于 Defender `WdFilter` 的 328010；这说明它处于文件 I/O 过滤栈中，但高度本身不能证明采集内容已被上传。

### 2.2 三枚 Trend Micro 驱动

查询 `Win32_SystemDriver`、文件版本、签名和 `HKLM\SYSTEM\CurrentControlSet\Services`：

| 服务/文件 | 当前状态 | 启动方式 | 产品/说明 | 版本 | 签名 |
|---|---|---|---|---|---|
| `tmactmon.sys` | Running | Auto | Trend Micro AEGIS / Activity Monitor Module | 2.98.0.1853 | Valid |
| `tmcomm.sys` | Running | System | Trend Micro Eyes / Common Module | 8.20.0.1063 | Valid |
| `tmevtmgr.sys` | Running | Auto | Trend Micro AEGIS / Event Management Module | 2.98.0.1853 | Valid |

对应 `oem162.inf`、`oem166.inf`、`oem57.inf` 均明确写有：

- `Class = "AntiVirus"`
- `Provider = "Trend Micro Inc."`
- 描述分别为 Activity Monitor Driver、Common Engine Driver、Event Manager Driver。

三枚驱动的文件时间均为 2023-04-11。`C:\Windows\INF\setupapi.setup.log` 显示 Windows 在 2026-07-02 的 `Install Type: Reset` 阶段重新安装了这三份 primitive driver package；这能证明它们被系统重置流程保留并重新加载，不能证明最初由公司、OEM 还是用户安装。

本次共核验 209 枚运行驱动，签名状态均为 `Valid`。有效签名只证明文件通过当前 Windows 签名验证，不等于它一定属于公司，也不代表没有监控能力。

### 2.3 是否有配套管理端或上传通道

只读查询得到：

| 检查项 | 结果 |
|---|---|
| Trend Micro 运行进程 | 0 |
| Trend Micro 普通 Windows 服务 | 0 |
| Trend Micro 已安装产品注册项 | 0 |
| `Program Files/ProgramData` Trend Micro 产品目录 | 0 |
| System32 下 Trend Micro 驱动 | 仅上述 3 枚 |
| Windows 安全中心登记 | 只有 Windows Defender |
| Defender for Endpoint `Sense` | 未发现 |
| 域/Entra/Workplace 加入 | 全部 NO |
| 有效企业 MDM | 未发现；无企业 UPN 和 Discovery URL |
| Windows Event Forwarding | `wecutil` 返回 RPC 服务不可用，未运行标准 WEC 收集链路 |

Trend Micro 官方资料说明，这三枚驱动可属于 Worry-Free Business Security、OfficeScan 或旧版 Deep Security 的行为/活动监控模块；官方卸载故障文档也列出相同三枚驱动可能成为卸载残留。因此，仅靠驱动名无法反推具体产品，更无法反推它是否归公司所有。

### 2.4 网络内核层

管理员导出的 WFP 状态共列出 15 个 provider：14 个为 Windows 内置提供者，另 1 个名为 `Codex Windows Sandbox WFP`，属于当前 Codex 执行环境的本机沙箱规则。没有 Trend Micro、常见企业 EDR/DLP/VPN 的 WFP provider。

WLAN 已启用的适配器绑定均为微软组件，包括 TCP/IPv4、TCP/IPv6、QoS、LLDP、NativeWiFi、`ms_ndiscap` 和 Windows WFP MAC 层过滤器；没有第三方 NDIS 过滤器。`ms_ndiscap` 是 Windows 自带组件，存在不等于正在抓包。

这说明当前没有证据表明 Trend Micro 直接在本机网络过滤层抓取 Clash/Tailscale 流量。公司出口防火墙、Wi-Fi 控制器和态势感知平台仍可独立观察流量，不依赖本机驱动。

## 3. 对 Clash 和 Tailscale 判断的影响

### 3.1 Clash

- 若一套完整的 Trend Micro/其他 EDR 客户端在运行，终端侧不需要破解 TLS，就可能通过进程、文件、注册表、虚拟网卡和监听端口识别 Clash。
- 当前三枚 Trend Micro 驱动有观测系统活动的能力，但没有找到配套用户态采集器、管理服务或网络上报通道，**不能据此断言公司已经收到 `mihomo.exe` 或 Clash 配置记录**。
- 网络侧判断不变：公司出口仍可能按目的 IP、长连接、TLS 指纹、流量周期和 IP 情报识别代理流量；当前 Clash 面向局域网开放 7890～7892 的风险也不变。

### 3.2 Tailscale

- 当前终端没有证据表明 Trend Micro 在 WFP/NDIS 层直接解析 Tailscale 流量。
- 若存在完整终端采集器，它可以从进程/服务/虚拟网卡层发现 Tailscale，而无需公司服务器安装 Tailscale。
- 当前缺少该采集器和公司管理关系证据，因此公司最确定的发现面仍是办公网络出口：源内网 IP、对端公网 IP、UDP/TCP 端口、时间和流量规模；通常看不到 WireGuard 内层内容。

## 4. 修正后的概率判断

| 问题 | 管理员补扫后的判断 |
|---|---|
| Windows 完全没有第三方安全内核组件 | 否；已确认 Trend Micro 三枚运行驱动 |
| 本机有一套完整、活跃的 Trend Micro 终端客户端 | 偏低；未见进程、普通服务、产品登记、目录和网络 provider |
| 三枚驱动是历史残留 | 中高，但仍是推断；系统重置迁移与缺少用户态组件支持该推断 |
| 公司正在通过这三枚驱动收集并上报 | 低到中，证据不足；没有找到收集器、管理端绑定或上传通道 |
| 公司主要通过网络层发现 Clash/Tailscale | 仍为中高；不依赖本机安装任何代理 |
| 能仅靠网络层看到 SSH/代理隧道内层内容 | 低；加密内容通常不可见，元数据与流量特征可见 |

## 5. 建议边界

不要自行删除 INF、改驱动启动类型或重命名 `.sys` 文件。这些操作需要重启，可能造成蓝屏、文件系统过滤链异常或破坏仍在使用的安全产品；本次只读调查不授权此类改动。

若要向 IT/安全部门确认，可直接发送下面这段话：

> 我在本机做合规自查时发现 `tmactmon.sys 2.98.0.1853`、`tmcomm.sys 8.20.0.1063`、`tmevtmgr.sys 2.98.0.1853` 三个 Trend Micro AntiVirus 类驱动正在运行，但系统里没有对应的 Trend Micro 应用、普通服务和安装项。请帮忙确认它们是否属于公司标准终端安全基线、是否应当连接公司管理平台，以及是否为历史卸载残留。暂未对驱动做任何停止、删除或配置修改。

## 6. 官方资料

- [Trend Micro：Worry-Free Business Security 驱动说明](https://success.trendmicro.com/en-US/solution/KA-0003153)：列出 `tmactmon`、`tmcomm`、`tmevtmgr` 的具体作用。
- [Trend Micro：Deep Security Agent 内核驱动列表](https://success.trendmicro.com/en-US/solution/KA-0013040)：将三枚驱动列为 Windows Active Monitoring 组件。
- [Trend Micro：异常卸载后行为监控驱动残留](https://success.trendmicro.com/en-US/solution/KA-0002552)：说明相同三枚驱动可能因卸载未完成而留在系统中。

