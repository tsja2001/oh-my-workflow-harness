# Cloudflare Access SSH · 中性域名并行迁移计划

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：迁移名称、对象范围、顺序和回退已经确认；尚未创建新域名对象。  
> 下一步：先做 Cloudflare 只读前检，再并行新增新 Access/DNS/Tunnel 路由，最后备份并更新公司 Windows/WSL 客户端。

## 目标与原则

| 通道 | 旧 hostname | 新 hostname | 本地 SSH 别名 |
|---|---|---|---|
| 洛杉矶 VPS | `ssh-vps.tttthappy1111.org` | `access-la.tttthappy1111.org` | `la-vps-access`，别名不变 |
| 家庭 Mac | `ssh-home.tttthappy1111.org` | `access-home.tttthappy1111.org` | `home-mac-access`，别名不变 |

迁移采用“先新增、再切客户端、最后删除旧入口”，不原地硬切：

- 新旧 hostname 并行，避免单点失败导致失联；
- 新域名先有 owner-only Access 门禁，再发布 DNS 和 Tunnel 路由；
- 更新 Tunnel 时读取并合并完整现状，不覆盖 `home-lan` 的其他 ingress/私网配置；
- 新入口验收完成前，不删除任何旧对象；
- 本轮不关闭 VPS 公网 22，不修改 Mac/VPS Connector、sshd、防火墙、Clash、WARP 或 VLESS/CDN。

## Cloudflare 改动

每条通道新增三类对象：

1. 新的 self-hosted Access 应用，复制旧应用的会话时长和 owner-only Allow 规则；
2. 现有 Tunnel 中新增一条 hostname → `ssh://localhost:22` ingress，放在兜底 404 之前；
3. 新 hostname 的 Proxied CNAME，指向对应 Tunnel。

旧 Access 应用、旧 ingress 和旧 DNS 在最终验收前全部保留。内部对象名 `la-vps-admin`、`home-lan`、`la-vps-ssh`、`home-mac-ssh` 不出现在公网 hostname 中，无需为了本次目标修改。

## 客户端改动

Cloudflare 新入口回读健康后：

- 备份 `C:\Users\29455\.ssh\config`；
- 备份 `/home/t/.ssh/config`；
- Windows `la-vps-access` 的 `HostName` 改为 `access-la.tttthappy1111.org`；
- Windows 家庭 Mac Access 别名的 `HostName` 改为 `access-home.tttthappy1111.org`；
- WSL `home-mac-access` 的 `HostName` 同步改为 `access-home.tttthappy1111.org`；
- `ProxyCommand`、User、IdentityFile、HostKeyAlias 和严格主机指纹校验保持不变。

新 Access 应用会产生新的身份会话，首次连接可能弹浏览器登录；邮箱、OTP/MFA 和登录确认由用户本人完成。

## 验收顺序

1. Cloudflare 回读两条新 DNS、Access 应用/策略和 Tunnel ingress；
2. 确认 `la-vps-admin`、`home-lan`、`saturate` 均为 `healthy`；
3. Windows/WSL 执行 `ssh -G`，确认 HostName、ProxyCommand、IdentityFile 和 HostKeyAlias；
4. Windows 真实连接 VPS，返回 VPS hostname 与 `root`；
5. Windows和WSL真实连接家庭 Mac，返回 Mac hostname 与 `mac`；
6. VS Code Remote-SSH 如需使用，由用户确认两个别名均能打开；
7. 验收后仍保留旧入口，等待用户明确同意清理。

## 失败回退

### Cloudflare 新对象失败

- 删除且只删除本轮新 hostname 的 DNS、Tunnel ingress、Access 应用；
- 旧 `ssh-vps`、`ssh-home` 始终可用；
- 回读三个既有 Tunnel 状态，不操作 Connector。

### 客户端切换失败

- 从带时间戳的备份恢复 Windows/WSL SSH 配置，或只把 `HostName` 改回旧域名；
- 不删除新 Cloudflare 对象，先保留用于诊断；
- 主机指纹不一致时停止，不使用 `accept-new`，不删除 `known_hosts`。

## 用户需要参与的节点

1. 浏览器出现 Cloudflare Access 登录时，由用户完成身份验证；
2. 新域名全部验收后，由用户明确决定是否删除旧域名；
3. 关闭 VPS 公网 22 属于另一个高风险步骤，需要 KiwiVM 回退和单独授权，不包含在本迁移中。
