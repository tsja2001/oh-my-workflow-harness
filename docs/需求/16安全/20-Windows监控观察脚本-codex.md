# Windows Trend / WSL 受控观察脚本

> 本文承接 `10d-WSL与Trend监控上报调查-codex.md`，产出原因：用户授权后续按指定时长观察 Trend 驱动句柄、WSL 主机活动和网络上报，并明确允许按需抓取完整数据包。  
> 日期：2026-08-20  
> 工具：codex  
> 当前状态：脚本已完成，PowerShell 语法、Bash 参数、60秒完整抓包和提前停止链路均验证通过。  
> 下一步：需要观察时执行一条命令并确认 Windows UAC；任务结束后让 AI 分析 `%TEMP%\codex-trend-watch-latest.txt` 指向的最新目录。

## 1. 脚本

- `scripts/windows-trend-watch.sh`：WSL 入口、参数校验、复制脚本到 Windows TEMP、触发 UAC、输出结果路径。
- `scripts/windows-trend-watch-launcher.ps1`：只负责用一次性管理员 PowerShell 启动观察进程并等待收尾。
- `scripts/windows-trend-watch.ps1`：句柄、进程、连接、Trend 日志和可选 Pktmon 完整抓包的主体。

没有把 Sysinternals 二进制放进仓库。运行时优先复用 Windows TEMP 中已验证的 Handle；不存在时从微软官方地址下载，并要求 Authenticode 状态为 `Valid`、签名者包含 Microsoft Corporation，否则停止。

## 2. 用法

### 2.1 只观察元数据

```bash
bash scripts/windows-trend-watch.sh --minutes 30
```

记录：

- `TmComm/TmActMon/TmEvtMgr/VprotectTMFilter` 具名对象句柄；
- Trend Micro 进程、公司签名和启动信息；
- `wsl.exe/wslhost.exe/wslservice.exe/vmmem/vmwp/WindowsTerminal/OpenConsole` 的新增 Windows 进程；
- 上述相关 PID 和 PID 4/System 的 TCP 连接、UDP 本地端点；
- `C:\Windows\TmComm.log`、`TmEvtMgr.log`、`TmActMon.log` 新增行。

不记录无关进程命令行，不启用 Windows 长期审计，不修改防火墙或驱动。

### 2.2 观察30分钟并抓完整数据包

```bash
bash scripts/windows-trend-watch.sh --minutes 30 --full-packets --max-mb 1024
```

`--full-packets` 才会启动 Windows 自带 Pktmon：

- `--comp nics`：只抓物理/虚拟网卡组件，减少同一数据包在网络栈多层重复；
- `--pkt-size 0`：记录完整数据包，而非默认的前128字节；
- `--log-mode circular`：达到上限后覆盖最早数据，不无限占盘；
- 默认上限512 MB，可配64～4096 MB；启动前要求可用空间至少为上限的3倍再加512 MB，因为 ETL 转 PCAPNG 会额外占空间；
- 结束后自动 `pktmon stop`，并将 ETL 转为 PCAPNG。

它抓的是本机网卡可见流量，不会把无线网卡切换到监听模式去截获其他设备的单播流量。PCAPNG 可能包含本机明文 HTTP、DNS、Cookie、Token 或其他敏感载荷，只能留在本机 TEMP，禁止提交 Git、写入需求文档或贴进聊天。TLS、WireGuard、SSH 等正文虽然被完整抓取，载荷仍是密文。

### 2.3 提前停止

在另一个 WSL 终端执行：

```bash
bash scripts/windows-trend-watch.sh --stop
```

主体在下一次轮询时结束，并通过 `finally` 停止本次启动的 Pktmon、转换 PCAPNG、写摘要。它不会粗暴杀进程。

### 2.4 其他参数

- `--minutes N`：1～240分钟，默认10分钟；
- `--seconds N`：60～14400秒，便于测试；
- `--interval N`：元数据轮询1～30秒，默认2秒；
- `--max-mb N`：ETL 循环文件上限64～4096 MB，默认512 MB。

## 3. 输出

每次运行创建：

```text
C:\Users\<当前用户>\AppData\Local\Temp\codex-trend-watch-YYYYMMDD-HHMMSS\
```

| 文件 | 内容 |
|---|---|
| `events.jsonl` | 带 ISO 时间戳的进程、句柄、连接、日志变化和生命周期事件 |
| `run-metadata.json` | 时长、轮询间隔、是否完整抓包和文件上限 |
| `summary.md` | 事件计数、实际持续时间、产物大小和 SHA-256 |
| `packets.etl` | 仅完整抓包模式生成的 Pktmon 原始日志 |
| `packets.pcapng` | 仅完整抓包模式生成，供 Wireshark/tshark 分析 |

`%TEMP%\codex-trend-watch-latest.txt` 始终指向最近一次目录。用户之后只需说“分析刚才30分钟观察结果”，AI 可从该指针定位，无需用户复制 PCAP 内容。

## 4. 安全边界

脚本明确不做：

- 不停止或卸载 Trend、Defender、网络驱动；
- 不关闭任何句柄；
- 不修改 AuditPol、WFP、Windows 防火墙、代理或路由；
- 不移除已有 Pktmon filter；启动完整抓包前会把当前 filter 状态写入时间线；
- 不向外上传报告或 PCAP；
- 不自动解密、提取或回显凭据。

若 Pktmon 启动失败，脚本不会假装抓包成功；若由本脚本成功启动，则只在该条件下执行 `pktmon stop`，避免停止别人的诊断会话。即使中途发生异常，`finally` 仍负责收尾。

## 5. 验证记录

### 5.1 60秒完整抓包

命令：

```bash
bash scripts/windows-trend-watch.sh --seconds 60 --full-packets --max-mb 64
```

结果目录：`%TEMP%\codex-trend-watch-20260820-135136`。

- 实际运行61.3秒；
- Pktmon 捕获2,337个数据包，丢弃0；
- ETL 486,016字节，PCAPNG 739,704字节；
- PCAPNG magic 为 `0A0D0D0A`，`file` 识别为 pcapng 1.0；
- Trend 进程0、Trend 句柄0、Trend 日志新增0、观察错误0；
- 结束后没有遗留 Pktmon/Handle/观察进程。

### 5.2 提前停止

先启动120秒纯元数据观察，约19秒后执行 `--stop`：

- 时间线生成 `MonitorStopRequested`；
- 实际18.9秒正常退出；
- stop flag 已自动删除；
- 观察错误0。

## 6. 后续分析原则

分析时先读 `summary.md` 和 `events.jsonl`，找到句柄所有者 PID、进程路径、签名与连接时间，再按该时间窗口过滤 PCAPNG。不能仅凭某个公网 IP 就归因给 Trend；必须同时满足进程/句柄/时间或 DNS/TLS 证据。若流量加密，只报告可验证的域名/IP、协议、证书、握手、时序与字节量，不猜测密文正文。

