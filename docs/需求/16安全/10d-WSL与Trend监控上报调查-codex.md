# WSL 与 Trend Micro 监控、上报能力调查

> 本文补充 `10c-管理员内核监控补扫-codex.md`，补充原因：用户继续追问 Trend Micro 驱动能否看到 WSL 终端，以及能否还原其监听和上报行为。  
> 日期：2026-08-20  
> 工具：codex  
> 当前状态：已完成 WSL 内代理、Windows WSL 插件、Trend 日志/事件源、历史网络审计、当前连接和内核对象句柄的只读调查；现有证据支持三枚 Trend 驱动处于“已加载但无用户态采集器连接”的空载状态，没有发现正在监听 WSL 内部事件或向外上报的链路。  
> 下一步：如需验证未来行为，可另行批准一个限定时长、只记录元数据的观察窗口；本轮没有启用抓包、审计或日志策略。

## 1. 直接回答

### 1.1 它是不是 Windows 自带的

不是。`tmactmon.sys`、`tmcomm.sys`、`tmevtmgr.sys` 的公司名、产品名和 INF Provider 都是 Trend Micro Inc.，INF Class 为 `AntiVirus`。它们有微软 WHQL/兼容性签名，但“由微软签名验证”不等于“微软自带”。

WSL、`wsl.exe`、`wslhost.exe`、Windows Terminal 和 Hyper-V 则是微软组件，需要把这两类东西分开。

### 1.2 能不能检测到 WSL 终端

能力边界分四层：

| 层面 | Windows/完整 EDR 理论上可见什么 | 本机当前 Trend 证据 |
|---|---|---|
| WSL 是否运行 | `wsl.exe`、`wslhost.exe`、`wslservice.exe`、Windows Terminal、WSL 虚拟机 | Windows 当前可直接枚举，Trend 行为驱动理论上也能收到 Windows 进程活动 |
| Windows 发起 WSL 的命令 | `wsl.exe -d <发行版> -e <程序及参数>` 的完整 Windows 进程命令行 | 当前实查可见；例如编辑器/工具启动 WSL 服务时，其 `-e` 参数和 Linux 程序路径会出现在 Windows 进程命令行中 |
| 进入 zsh/bash 后逐条输入的命令 | WSL2 内部产生 Linux 进程，不会为每条命令生成新的 Win32 进程；需 WSL 内代理或专门的 WSL 传感器才能稳定获得文件、进程、网络时间线 | WSL 内无 Trend/MDE Linux 代理；Windows 无 MDE WSL 插件，因此未发现这层采集能力 |
| WSL 文件 | `/mnt/c` 是 Windows NTFS，Windows 文件过滤器可见；`/home/...` 是 WSL2 ext4 虚拟磁盘，Windows通过 `\\wsl.localhost` 访问时走 9P/UNC，Linux 原生访问主要发生在虚拟机内部 | `tmevtmgr` 已挂载 C: 与 `\Device\Mup`，所以具备观察 Windows NTFS 和 Windows 侧 UNC 访问的条件；没有证据表明它能把 Linux 原生 ext4 操作还原为完整路径/命令 |

本项目位于 `/home/t/projects/work-wsl`，属于 WSL 原生 Linux 文件系统，不是 `/mnt/c`。因此 Windows minifilter 最直接看到的是 WSL 虚拟磁盘的宿主 I/O；当 Windows 应用通过 `\\wsl.localhost\...` 打开项目文件时，相关 UNC 文件访问则可能进入 `Mup` 过滤路径。

微软官方说明，想让 Defender for Endpoint 获得 WSL2 内部的文件、进程、网络事件时间线，需要单独安装 MDE WSL 插件，并且 Windows 主机先加入 Defender for Endpoint。当前两项都不存在。

## 2. 当前是否有人连接这三枚驱动

### 2.1 用户态进程、服务和事件提供者

查询结果：

- WSL 内没有 `mdatp`、Defender、Trend Micro、AEGIS 相关进程、systemd 服务或 Debian 包。
- `%ProgramFiles%\Microsoft Defender for Endpoint plug-in for WSL` 不存在，卸载注册表也没有该插件。
- Windows 没有 Trend Micro 用户态进程和普通服务。
- Windows Event Log 没有 Trend/AEGIS 事件 provider 或专属 channel。
- `logman query providers` 没有 Trend/AEGIS ETW provider。

### 2.2 内核对象句柄

从微软官方下载 Sysinternals Handle 5.0，运行前核验：

- Authenticode：`Valid`
- 签名者：Microsoft Corporation
- SHA-256：`24BAFCC570CC9BBB6B6E6652A57A519E0464E3996891AABA6F55299CCE20B04F`

管理员只读查询全部返回：

```text
TmComm: No matching handles found.
TmActMon: No matching handles found.
TmEvtMgr: No matching handles found.
VprotectTMFilter: No matching handles found.
```

因此当前没有进程打开这些具名内核对象。句柄快照不能证明过去从未连接，也可能遗漏名字不同的 Filter Manager 通信端口，但结合没有任何配套进程/服务，当前不存在活动采集器的置信度较高。

## 3. 本地日志实际记录了什么

驱动二进制的静态字符串包含：

- `\Device\TmActMon`、`\Device\TmComm`、`\Device\TmEvtMgr`
- `Connect to User Manager Port`
- `C:\Windows\TmComm.log`、`TmEvtMgr.log`、`TmActMon.log`

没有找到 Trend Micro 遥测域名或产品服务器地址；二进制中的 HTTP URL 都属于代码签名证书的 Microsoft/DigiCert CRL、OCSP 地址。静态字符串不是完整逆向结论，但它与“内核驱动把事件交给本机用户态管理器，由用户态产品决定记录/上传”的架构一致。

本机只有 `C:\Windows\TmComm.log`，没有另外两份日志。该文件从 2026-07-02 到 2026-08-20 共 39 行，每行只在开机加载时写入：

```text
System(004)-8 DriverEntry: tmcomm device object reference count 0
```

最新一条为 2026-08-20 08:42:34。日志没有 WSL、进程、文件、网络、服务器、上传成功/失败或客户端连接记录。“引用计数 0”是驱动初始化时刻的值，不能单独证明整次开机期间始终无人连接；但本次实时句柄快照同样为 0 个匹配。

## 4. 能否还原历史上报

当前无法从 Windows 还原历史流量，原因是相关日志当时没有启用：

| 记录源 | 当前配置/结果 | 能否回看 |
|---|---|---|
| WFP 5154～5159 连接审计 | “筛选平台连接”=无审核 | 不能；14 天内 0 条不代表没有连接 |
| WFP 5440～5450 provider/filter 变更 | “筛选平台策略更改”=无审核 | 不能；30 天内 0 条不代表从未变更 |
| Windows 防火墙文本日志 | Domain/Private/Public 的 LogAllowed、LogBlocked 均为 False | 不能 |
| Packet Monitor | 当前未运行 | 没有历史抓包 |
| 进程创建审计 | 无审核 | 不能靠 Security 日志回看 WSL 命令行 |
| 文件系统/注册表审计 | 无审核 | 不能靠 Security 日志回看文件、注册表访问 |
| Trend 自身日志 | 只有 39 条 DriverEntry，均为引用计数 0 | 没有监听或上传细节 |

管理员历史查询只找到 2026-07-02 12:22:58 的三条 System 7045 事件，内容是系统重置阶段安装 `tmactmon/tmcomm/tmevtmgr` 内核服务；没有保留最初安装来源。

当前网络快照同样没有发现 Trend 上报：

- 没有 Trend Micro 进程连接。
- PID 4/System 没有已建立的 TCP 连接。
- PID 4 的 UDP 只有本机各接口的 NetBIOS 137/138 监听，不是远程上报会话。
- WFP provider 没有 Trend Micro。

所以可以写成：**当前没有发现上报；历史记录因为当时未开启系统网络审计而无法从系统日志证明“过去绝对没有上报”。**

## 5. 如果要观察未来行为

可做两种受控观察，但需要用户另行确认后才实施：

1. **元数据观察，优先推荐**：限定 10 分钟，轮询 Trend 设备句柄、相关进程、PID 与目标 IP/端口，不记录数据包正文；期间只执行一个无敏感内容的测试命令。它能回答“是否有采集器连接、哪个进程对外连接”，不能解密上报内容。
2. **数据包捕获**：使用 Windows 自带 Pktmon 对限定接口/目标做短时捕获。它可能包含其他应用流量，隐私和数据量更大；即使捕获到 TLS，也通常只能看到目标、时间、流量，不能直接看到加密载荷中的字段。

不建议为了验证而开启长期全量 WFP 成功连接审计、全盘文件审计或 Driver Verifier；前两者日志量大，后者可能导致性能问题或蓝屏。

## 6. 本轮变更边界

- 没有启用抓包、Windows 审计、防火墙日志或 Sysmon。
- 没有停止、删除、重配任何 Trend 驱动或服务。
- Windows 临时目录下载了签名有效的 Microsoft Sysinternals Handle 5.0，并记录了首次许可接受；只执行查询，没有使用关闭句柄参数。
- 原始查询保存在 `%TEMP%\codex-wsl-trend-history-audit.txt` 和 `%TEMP%\codex-trend-open-handles.txt`。

## 7. 官方资料

- [Microsoft：Defender for Endpoint WSL 插件](https://learn.microsoft.com/en-us/defender-endpoint/mde-plugin-wsl)：说明 WSL2 的虚拟化隔离，以及插件可采集 WSL 内文件、进程和网络事件。
- [Microsoft：WSL 文件系统互操作](https://learn.microsoft.com/en-us/windows/dev-environment/wsl-interop)：说明 `\\wsl.localhost`/`\\wsl$`、9P 与 WSL2 虚拟化边界。
- [Microsoft：Windows Filtering Platform 审计](https://learn.microsoft.com/en-us/windows/win32/fwp/auditing-and-logging)：列出 5154～5159 和 provider/filter 变更审计事件。
- [Microsoft Sysinternals：Handle](https://learn.microsoft.com/zh-cn/sysinternals/downloads/handle)：说明 Handle 可枚举进程打开的内核对象句柄。
- [Microsoft：Packet Monitor](https://learn.microsoft.com/en-us/windows-server/networking/technologies/pktmon/pktmon)：Windows 自带、可用于网络栈数据包与事件观察的诊断工具。

