# Cloudflare 家庭私网接入 · 公司端注册与首次验收

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：公司 Windows 已成功注册 Cloudflare One Client，WARP、最小 Include 策略、Mac SSH/HA 和非目标流量均通过；家庭路由器直连失败后已按规则断开 WARP，完整家庭 `/24` 验收尚未通过。  
> 下一步：经用户确认后，将家里 Mac 的 `cloudflared` 从用户 LaunchAgent 迁移为系统 LaunchDaemon，绕开 macOS 15 本地网络隐私对后台 Agent 的限制，再重跑完整验收。

> 本文接续 `20e-Windows端预配置与明日执行-codex.md`，记录公司网络中的真实注册、首次数据面测试和失败止损；不覆盖前序记录。

## 1. 公司 Windows 已完成配置

在 `/home/t/projects/work-wsl` 依次执行：

```bash
bash scripts/windows-cloudflare-one.sh doctor
bash scripts/windows-cloudflare-one.sh setup
```

只读体检结果：

- Windows WLAN 为公司网 `10.66.10.153/23`，不在家庭 `192.168.5.0/24`。
- 启用前到 `192.168.5.35` 的有效路由为公司 WLAN 默认路由，没有其他 VPN/私网路由抢占家庭地址。
- WSL、Clash Party、Mihomo 和 CloudflareWARP 服务均存在且正常。
- Cloudflare One Client 为 `26.7.1343.0`，执行前处于未注册、未连接状态。

用户在浏览器中自行完成一次性邮箱验证码后：

- Windows 成功注册到 Team `mute-cake-c395`。
- Cloudflare One Client 成功连接。
- 云端下发配置为 `TunnelOnly/Traffic only + Include`。
- Include 中存在家庭 `192.168.5.0/24` 和 Cloudflare 注册所需地址。
- 到 Mac `192.168.5.35` 的有效路由变为 `CloudflareWARP` 上的 `192.168.5.0/24`。

验证码、认证 URL、Token、Cookie、密码和私钥均未写入项目或本文；设备与账号标识也不在本文复述。

## 2. 首轮自动验收

| 验收项 | 结果 | 证据 |
|---|---|---|
| 注册到正确 Team | 通过 | `registered-to-team` PASS |
| WARP 已连接 | 通过 | `warp-connected` PASS |
| Traffic only / Include / 家庭 CIDR | 通过 | 五项 settings 检查全部 PASS |
| Windows → Mac SSH TCP | 通过 | `windows-mac-ssh-tcp` PASS |
| Windows → Mac SSH 远程命令 | 首轮脚本失败 | `windows-mac-ssh-login` FAIL，后续有界复测证明实际认证与命令均成功，见第 3 节 |
| Windows → Home Assistant | 通过 | `windows-home-assistant-http` PASS |
| Windows → 家庭路由器 | 失败 | `windows-router-http` FAIL，后续由 Connector 日志确认，见第 4 节 |
| WSL → Mac SSH TCP / HA / 公网 | 通过 | 三项均 PASS |
| Windows 公网与 DNS | 通过 | 两项均 PASS |
| 默认路由、DNS服务器保持基线 | 通过 | 两项 before/after 比对均 PASS |
| Clash 保持运行 | 通过 | `clash-still-running` PASS |

公司内部页面仍需用户在最终复验时亲自打开；本轮因自动验收已有失败，未把完整链路标记为通过。

## 3. SSH 失败是首轮超时，不是密钥错误

重连后使用 15 秒硬超时和 OpenSSH 调试信息复测，得到以下证据：

1. 与 `192.168.5.35:22` 建立 TCP 和 SSH 2.0 会话。
2. 服务端主机指纹与 Windows `known_hosts` 已有记录匹配。
3. Windows 提供专用 ED25519 公钥，Mac 明确返回 `Server accepts key`。
4. OpenSSH 明确返回 `Authenticated ... using publickey`。
5. 远程 `hostname` 命令被接受并返回 `macdeMac-mini.local`。
6. SFTP 子系统能进入 `/Users/mac` 并正常退出。

因此 SSH 配置和密钥有效。首轮脚本失败发生在 WARP 刚连接且状态显示 `Network: unstable` 的窗口，应在家庭 Connector 修复后重跑脚本确认稳定性，不修改或替换密钥。

## 4. 家庭路由器失败的证据链

公司 Windows 通过 WARP 访问 `192.168.5.1:80` 时超时。Mac 上 `cloudflared` 错误日志与该测试时间一致，精确记录：

```text
unable to dial tcp to origin 192.168.5.1:80: connect: no route to host
originService=warp-routing
```

同一时刻从 Mac 普通 SSH 会话执行只读检查：

- 系统路由明确为 `192.168.5.1` → Wi-Fi `en1`。
- Mac 到路由器 TCP 80 成功。
- Mac 直接访问路由器返回 HTTP 200。
- 通过已认证 SSH 的 `-W 192.168.5.1:80` 转发收到路由器 HTTP 响应。

这证明路由器在线、Mac 普通进程可达、Cloudflare Route 也把流量送到了 `home-lan`；失败只发生在用户级 `cloudflared` LaunchAgent向其他家庭 LAN 设备发起连接时。

## 5. 根因判断

**高置信推断，尚待变更后复验：macOS 15 Local Network Privacy 阻止了用户 LaunchAgent访问家庭局域网。**

依据：

1. 本机实证：相同用户经 SSH运行 `curl/nc` 能访问路由器，LaunchAgent中的同一 `cloudflared` 却得到系统级 `no route to host`。
2. 当前 Connector 已核实为 `~/Library/LaunchAgents/com.cloudflare.cloudflared.plist`，不是系统 LaunchDaemon。
3. Apple TN3179 明确区分：`launchd` daemon 自动允许本地网络，而 `launchd` agent 不享受该豁免；Apple开发者案例记录的典型表现同样是 LaunchAgent访问 `192.168.x.x` 返回 `No route to host`。

官方依据：

- <https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy>
- <https://support.apple.com/guide/mac-help/control-access-to-your-local-network-on-mac-mchla4f49138/mac>
- Cloudflare官方实现支持使用 `sudo cloudflared service install` 安装为开机 LaunchDaemon：<https://developers.cloudflare.com/tunnel/advanced/local-management/as-a-service/macos/>

## 6. 当前安全状态

发现两项失败后已执行：

```bash
bash scripts/windows-cloudflare-one.sh disconnect
```

当前状态：

- Windows 设备注册保留，无需再次 OTP。
- WARP 已断开，公司默认路由恢复为 WLAN。
- 正确的 Traffic only + Include 云端策略保留。
- 家庭 `home-lan`、Route、Mac Connector 和旧 `saturate` 均未删除或修改。
- 未改路由器、Clash、DNS、VLESS、SSH 密钥或防火墙。

## 7. 建议修复与边界

推荐把 `cloudflared` 从当前用户 LaunchAgent迁移为系统 LaunchDaemon：

- 由 macOS `launchd` 在开机时以系统服务启动，不再依赖用户登录。
- Apple文档说明系统 daemon自动允许本地网络访问，可解决当前限制。
- 迁移时复用已有项目外 `0600` Token文件，只引用路径，不读取、不输出、不复制 Token到聊天或仓库。
- 动作前备份用户 plist和服务状态；验证失败立即恢复原 LaunchAgent。
- 该变化使 `cloudflared` 以 root运行，属于权限提升，必须在用户明确确认后执行，并需要用户在 Mac SSH终端亲自输入一次管理员密码。

如果不接受系统服务，备选方案是保留当前状态，只直接访问 Mac 本机服务；其他家庭 LAN设备需临时通过 `ssh -L/-W` 转发，不能实现“整个家庭 `/24` 像 Tailscale 一样直连”的原目标。
