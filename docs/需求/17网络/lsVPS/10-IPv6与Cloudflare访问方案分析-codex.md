# 洛杉矶 VPS SSH · IPv6 与 Cloudflare 访问方案分析

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：已完成只读方案分析；未登录 VPS，未改 SSH、Cloudflare、Clash、DNS 或防火墙。  
> 下一步：如准备实施，先只读盘点 VPS 现有 SSH/防火墙/cloudflared 状态，再决定是否建独立 Access SSH Tunnel。

## 先说结论

1. **IPv6 不会让 SSH 天然更安全。** IPv4 和 IPv6 上的 SSH 都是同一套加密和身份验证。真正的差别是服务器是否对公网开放 SSH、是否禁用密码/root 登录、是否只允许密钥。IPv6 地址空间大不等于不会被扫描或阻断。
2. **既有 Cloudflare CDN 路线能用上，但不应当成原生 SSH 通道复用。** 现有节点是 VLESS over WebSocket/TLS，只是外层经过 Cloudflare；普通橙云 DNS 不会把 `ssh:22` 变成 CDN SSH。
3. **推荐复用“回家方案 B”的方法，不复用它的 Tunnel。** 即给 VPS 新建一个独立 Cloudflare Tunnel + owner-only Access 应用，只发布 VPS 本机 `localhost:22`。不需要 WARP/CIDR，不动家里的 `home-lan`，也不动现有 `saturate`/CDN/VLESS。
4. **先留旧 IPv4 SSH 作回退，验收新通道后再关公网 22。** 必须先确认搬瓦工控制台可用；否则一次防火墙失误就可能把自己锁在服务器外。

## 现有 Clash/CDN 配置说明了什么

只读核对 `/home/t/projects/personal/05clash/订阅备份/20-08-25同步服务器配置.yaml`，未读取或记录 UUID 等敏感值：

| 已核实事实 | 证据 | 含义 |
|---|---|---|
| Mihomo 总开关和 DNS 都配为 `ipv6: false` | 第 5、23 行 | 当前 Clash 配置本身没有在利用 IPv6；不代表 VPS 或操作系统一定没有 IPv6。 |
| `Daily-Reality-443` 是直连 VPS IPv4 的 VLESS/TCP/TLS | 第 53～66 行 | 这是一条直达 VPS 的代理节点，不是 SSH 管理面。 |
| `Daily-CDN-WS` 是域名 `:443` 上的 VLESS/WebSocket/TLS | 第 67～81 行 | Cloudflare 之所以能承载，是因为外层是 HTTPS/WebSocket，不是 Cloudflare 直接代理了 TCP/22。 |
| `PROXY` 可在 Reality、CDN-WS、DIRECT 中手动选 | 第 83～89 行 | 现有 CDN 路线可作代理业务的备用，但不应和服务器管理入口强绑。 |
| 整个自有域名和 VPS IPv4 被规划为 `DIRECT` | 第 118～119 行 | 按配置意图，新建 `ssh-vps` 子域名会直连 Cloudflare，可避免“管理 VPS 却必须先经过同一台 VPS 代理”的套娃。运行时是否确实命中仍需新鲜日志验证。 |

## 四种方案对比

| 方案 | 能不能用 | 安全面 | 可用性/故障面 | 建议 |
|---|---|---|---|---|
| 直接 IPv6 SSH | 能，前提是 VPS 真有可路由 IPv6、客户端网络也有 IPv6 | 仍然对 IPv6 公网暴露 SSH；不比 IPv4 自动更安全 | 某些办公/家庭网络没有稳定 IPv6；IPv6 也可被路由或过滤策略阻断 | 可做对照或临时回退，不做主方案 |
| SSH 经现有 Clash CDN 节点再回到同一 VPS | 技术上可用 SOCKS/ProxyCommand 绕一圈 | 如公网 22 仍开，暴露面没有消失 | 依赖 Clash、CDN-WS、VLESS 和 VPS 自身；代理故障时同时丢掉管理入口 | 不建议日常使用 |
| 在旧 `saturate` Tunnel 里追加 SSH | 技术上可发布 `ssh://localhost:22` | 可用 Access 先挡住未授权访问 | 修改/重启旧 Tunnel 可能影响正在用的 CDN/VLESS；两者同一故障点 | 不建议，尤其未盘点服务端前不能动 |
| 新建独立 Tunnel + Access SSH | 能，且回家 B 通道已验证同类客户端路径 | 可验收后关闭 IPv4/IPv6 公网 22；Access 身份 + SSH 密钥两层校验 | 依赖 Cloudflare，但不依赖现有 Clash 节点和 `saturate` | **推荐** |

## 推荐的最终架构

```text
Windows / WSL：ssh la-vps-access
  → 客户端 cloudflared access ssh
  → Cloudflare Access（仅本人，必要时 MFA）
  → 全新 SSH 子域名
  → 全新 la-vps-admin Tunnel
  → VPS 上的独立 cloudflared 服务
  → localhost:22
  → sshd 密钥认证
```

实施时的隔离规则：

- 新 Tunnel、新子域名、新 Access 应用、新 systemd 服务名；不改旧 `saturate` 配置和服务。
- 只发布 VPS 本机 SSH，不发布整个网段，因此不需要回家 A 通道的 WARP/CIDR。
- Tunnel 从 VPS 主动出站连 Cloudflare，客户端通过 `cloudflared access ssh` 连入；官方当前明确支持 `ssh://localhost:22`。
- Access 通过后仍保留 SSH 公钥验证；不因为有 Access 就恢复密码或 root 直登。
- 新通道完成外网冷连接、短命令、重连、VS Code（如需）验收前，不关旧 IPv4 SSH。
- 最终关闭公网 22 时同时核对 IPv4 和 IPv6 防火墙，不能只关一边。

## “会不会被拦截或封”应该怎么理解

这里要把两件事分开：

- **安全**：SSH 本身是加密的，但公网开放 22 会持续承受扫描、弱密码尝试和漏洞探测。IPv6 不改变这个性质。
- **可达性**：某条路径是否被上游网络限制，取决于当时的路由、出口策略、目标 IP/域名和流量特征。不能根据“是 IPv6”就断言更不容易被限制。
- **Cloudflare 也不是绝对保证**：它把公网 SSH 收缩成了经 Access 授权的应用入口，安全面更小；但连接仍然依赖客户端能访问 Cloudflare。
- 当前最有价值的本地证据是：回家 B 通道已在同一台公司 Windows/WSL 上用这种 Access SSH 路径验收；但这只证明当时该网络可用，不是永久可达保证。

## 实施前必须先查清的事

本轮没有登录 VPS，以下仍是未知，不能用默认值猜：

1. 搬瓦工面板是否有已验证可用的 Console/VNC 带外恢复入口。
2. VPS 的 IPv6 是否已分配、可路由，客户端所在网络是否真有 IPv6。
3. `sshd` 当前的实际生效配置：监听地址、root/密码/公钥认证、允许用户、端口转发。
4. nftables/iptables/ufw 及搬瓦工外层防火墙对 IPv4/IPv6 的真实规则。
5. `saturate` Connector 是否确实运行在这台 VPS，它的本地配置和 systemd 单元如何组织。现有文档只证明它是本地管理的旧 Tunnel，不足以证明具体运行位置。
6. 新 `cloudflared` 实例的服务名、配置路径、日志和出站 `7844/TCP+UDP` 可达性，确保不和旧实例冲突。

## 官方依据

- [Cloudflare：客户端 cloudflared 连接 SSH](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/)：服务端可发布 `SSH → localhost:22`，客户端用 `cloudflared access ssh`。
- [Cloudflare Tunnel 路由与协议](https://developers.cloudflare.com/tunnel/routing/)：公开主机名支持 `ssh://localhost:22`，非 HTTP 协议需客户端 `cloudflared`。
- [Cloudflare Tunnel 出站模型](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)：Connector 主动建立出站连接，可在验收后关闭原站入站口。
- [Cloudflare 常规 DNS 代理端口](https://developers.cloudflare.com/fundamentals/reference/network-ports/)：普通橙云不代理 SSH/22；原生 TCP/22 不能只靠 CDN DNS 实现。
- [OpenSSH `sshd_config` 手册](https://man.openbsd.org/sshd_config)：密码、公钥和 root 登录是独立的服务端安全选项，与底层用 IPv4 还是 IPv6 无关。

