# 家庭网络接入 · A/B 两条通道架构

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：A、B 均已投入可用状态，且都没有在家庭路由器开放公网入站端口。  
> 下一步：保持架构不变；只有真实使用仍卡时，才测试家庭 Mac 的 Connector 是否适合直连。

## 一句话原理

家里的 Mac 主动连到 Cloudflare，公司电脑只连 Cloudflare；Cloudflare 在中间把流量交给家里的 Mac，再由 Mac 访问自己或家庭局域网设备。

## A 通道：透明家庭网段

```text
公司 Windows / WSL 访问 192.168.5.x
  → Cloudflare One Client（WARP，只接管 192.168.5.0/24）
  → Windows Mihomo / Daily-CDN-WS（当前公司出口的稳定承载）
  → Cloudflare Zero Trust 的 CIDR Route
  → home-lan Tunnel
  → 家庭 Mac root cloudflared
  → Mac Mihomo / Daily-Reality-443
  → Mac、Home Assistant、路由器或其他家庭设备
```

A 的特点：

- 整个 `192.168.5.0/24` 可按 IP 访问，最接近原来的虚拟组网体验。
- 公司内网、公网、DNS 和默认路由不进入家庭 Tunnel。
- 公司网络无法稳定直连 WARP 官方入口，所以当前 WARP 外层仍经 Windows CDN 节点；手机热点直连曾通过，但不能代替公司网络。

## B 通道：单独的 Access SSH

```text
Windows / WSL OpenSSH：ssh home-mac-access
  → Windows cloudflared.exe（公司侧已验证 DIRECT）
  → Cloudflare Access（仅本人策略）
  → ssh-home.tttthappy1111.org
  → home-lan Tunnel
  → 家庭 Mac root cloudflared
  → Mac Mihomo / Daily-Reality-443
  → Mac sshd localhost:22
```

B 的特点：

- 不依赖公司端 WARP/CIDR，Access 身份验证后再走 SSH 公钥认证。
- 目前只发布 Mac SSH，不是整个家庭网段；登录 Mac 后仍可由 Mac 访问路由器、HA 等设备。
- Windows 与 WSL 共用 Windows `cloudflared.exe`；WSL 另有 10 分钟 SSH 连接复用。

## 本质区别

| 对比 | A | B |
|---|---|---|
| 公司侧入口 | WARP | `cloudflared access ssh` |
| 暴露范围 | 家庭 `/24` 网段 | 仅 Mac SSH |
| 公司侧外层 | 当前经 `Daily-CDN-WS` | 已验证直连 Cloudflare |
| 身份控制 | WARP 设备注册与策略 | Access 本人策略 + SSH 密钥 |
| 适合 | 访问家庭 IP、网页、其他设备 | SSH、VS Code、CLI AI |
| 冷连接实测均值 | 8.19 秒 | 8.98 秒 |
| 是否独立回家 | 否，共用 `home-lan` | 否，共用 `home-lan` |

因此 B 的“更直接”只发生在公司侧，不等于端到端一定更快。家庭侧 Reality 绕行和共同 Connector 仍在，VS Code 体感卡并不矛盾。

## 不变的安全边界

- 家庭路由器无公网端口转发；不建设 VPS 中转，也不恢复 Tailscale。
- 不修改旧 `saturate` Tunnel、旧 VLESS/CDN 服务或无关 DNS。
- 不能用 `HTTP 200`、节点 delay、`using DIRECT/PROXY` 单独冒充全链路验收；必须以真实 SSH/业务请求为准。

证据：归档 `50b-项目阶段复盘与AI交接-codex.md:53-99`、`30f-B通道公司端短版验收报告-codex.md:17-48`、`10j-B通道Mac侧代理链路调查-codex.md:10-63`。
