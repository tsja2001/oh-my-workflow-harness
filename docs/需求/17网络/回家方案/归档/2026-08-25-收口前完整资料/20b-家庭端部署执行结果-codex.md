# Cloudflare 家庭私网接入 · 家庭端部署执行结果

> 日期：2026-08-22  
> 工具：codex  
> 当前状态：家庭 Mac、Cloudflare Tunnel、CIDR Route、注册权限和最小流量策略已配置并回查；路由器静态 DHCP 绑定因管理会话过期未写入，公司 Windows 异地端到端尚未验收。  
> 下一步：路由器重新登录后补 `192.168.5.35` 固定租约；再从非家庭 Wi-Fi 的公司 Windows 注册 Cloudflare One Client，逐项验证 SSH、Home Assistant 和路由器页面。

> 本文接续 `20-部署执行-codex.md`，记录用户完成动作前确认后的实际结果；不覆盖前一份部署中记录。

## 1. 已落地的 Cloudflare 配置

| 项目 | 实际结果 | 回查证据 |
|---|---|---|
| 新 Tunnel | `home-lan` / cloudflared / Healthy | Tunnels & Mesh 表格显示 Healthy |
| 旧 Tunnel | `saturate` 仍为 Healthy，运行时长仍为 46 天 | 同一表格回查；未迁移、未编辑、未重启 |
| 私网 Route | `192.168.5.0/24` → `home-lan` → `default` | Routes 显示 1 条 CIDR Route，描述 `Home LAN via Mac mini` |
| Enrollment | `home-lan-owner` / Allow / 1 条邮箱规则 | Device enrollment policies 重新载入后仍存在 |
| Tunnel 协议 | MASQUE | Default Profile 重新载入后为选中状态 |
| Service mode | Traffic only | Default Profile 重新载入后为选中状态 |
| Split Tunnel | Include IPs | Default Profile 重新载入后为选中状态 |
| Include 1 | `192.168.5.0/24` | Split Tunnels 表格回查 |
| Include 2 | `104.19.194.29/32` | Split Tunnels 表格回查 |
| Include 3 | `104.19.195.29/32` | Split Tunnels 表格回查 |

说明：定稿文档写的是 UI 术语 `Include IPs and domains`。保存 Traffic only 后，Cloudflare 会禁用域名型规则，并把实际可选项显示为 `Include IPs`；三项定稿值本来就是 CIDR，因此实际结果与“仅家庭 IP 流量进入 WARP”的目标一致。

## 2. 家庭 Mac Connector

- Homebrew 安装版本：`cloudflared 2026.8.2`，Apple Silicon 原生程序。
- 服务形式：当前登录用户的 LaunchAgent，标签 `com.cloudflare.cloudflared`。
- LaunchAgent 文件：`~/Library/LaunchAgents/com.cloudflare.cloudflared.plist`。
- Connector Token 由 cloudflared 服务安装流程保存到项目外的应用支持目录，权限回查为 `0600`；Token 未写入项目、文档、聊天或 LaunchAgent 参数。
- 服务回查：`launchctl print gui/$(id -u)/com.cloudflare.cloudflared` 显示 `state = running`、进程存在、正常退出码为 0。
- Cloudflare 下发的运行配置包含 `warp-routing.enabled=true`。

当前服务是用户级 LaunchAgent：Mac 重启并登录当前账号后会自动运行；在登录窗口之前不会启动。家庭 Mac 当前已禁用交流电睡眠，因此日常使用场景满足持续在线要求。

## 3. 恢复能力实测

执行了只针对新 Connector 的一次 `launchctl kickstart -k`：

1. 原进程正常停止，退出码为 0。
2. LaunchAgent 自动生成新进程。
3. DNS、UDP/QUIC、TCP/HTTP2、Cloudflare API 五类预检查全部 PASS，`hard_fail=false`。
4. 新进程重新注册 2 条 QUIC 连接。
5. Dashboard 再次显示 `home-lan` Healthy；旧 `saturate` 同时保持 Healthy。

## 4. 家庭 LAN 服务回查

| 检查 | 结果 |
|---|---|
| Mac 当前 Wi-Fi 地址 | `192.168.5.35/24` |
| Mac SSH `192.168.5.35:22` | TCP 连接成功 |
| Home Assistant `http://192.168.5.35:8123/` | HTTP 200 |
| 路由器 `http://192.168.5.1/` | HTTP 200 |
| cloudflared 本机进程 | running |

## 5. 未完成项与原因

### 5.1 路由器静态 DHCP 绑定

此前只读侦察时路由器管理页已登录，并核实静态绑定表为空。实际准备写入时管理会话已超时，页面退回密码登录；Chrome 没有向网页自动填入已保存凭据，项目凭据文件也没有路由器密码。

因此没有猜密码、没有尝试默认密码，也没有把 Mac 强制改成可能与 DHCP 池冲突的手工静态地址。路由器配置仍保持原状。待重新登录后，应使用当前 Wi-Fi 的实际私有地址标识，把 `192.168.5.35` 固定给这台 Mac；不改 DHCP 池、LAN、DNS或网关。

### 5.2 公司 Windows 异地端到端

当前工作环境只有家庭 Mac 与 Chrome，未连接到公司 Windows，也不能在同一家庭 LAN 内证明 Cloudflare 私网路径。因此尚未宣称完整上线。最终必须在公司 Windows 离开家庭 Wi-Fi 后完成：

1. 安装并注册 Cloudflare One Client，Team Name 为 `mute-cake-c395`。
2. 用当前被允许的邮箱接收 One-time PIN。
3. 确认客户端只包含家庭 `/24`，普通公网、公司内网和 DNS 仍走原路径。
4. 验证 `192.168.5.35:22`、`192.168.5.35:8123`、`192.168.5.1:80`。
5. 用 `traceroute`/路由表或 WARP 诊断确认这三类目标经 Cloudflare，其他目标不经 Cloudflare。

## 6. 明确未改内容

- 未迁移、编辑或重启旧 `saturate` Tunnel。
- 未改 `tttthappy1111.org` DNS、VLESS、两个 VPS。
- 未关闭或改动 Clash、Tailscale、ToDesk、OrbStack、Home Assistant。
- 未改路由器 LAN、DHCP 池、DNS、网关或 Wi-Fi。
- 未安装家庭 Mac 的 WARP 客户端，避免与现有 Clash/Tailscale 叠加。

