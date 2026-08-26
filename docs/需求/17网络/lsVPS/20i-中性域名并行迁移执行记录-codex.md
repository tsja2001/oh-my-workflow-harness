# Cloudflare Access SSH · 中性域名并行迁移执行记录

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：两个新域名已并行发布，公司 Windows/WSL 客户端已切换且真实 SSH 验收通过；两个旧域名仍完整保留。  
> 下一步：用户确认是否需要 VS Code 验收，并明确决定是否删除旧 `ssh-vps`、`ssh-home` 的 Access 应用、Tunnel ingress 和 DNS。

## 执行前检查

- `access-la.tttthappy1111.org`、`access-home.tttthappy1111.org` 在 DNS、Access 应用和 Tunnel ingress 中均为 0 命中；
- 旧 VPS、家庭 Access 应用各有且仅有一条 owner-only Allow 策略；
- `la-vps-admin`、`home-lan`、`saturate` 均为 `healthy`；
- VPS Tunnel 配置版本为 1，家庭 Tunnel 版本为 2，家庭 `warp-routing.enabled=true`。

## Cloudflare 写入结果

先创建新 Access 门禁，再发布 Tunnel ingress 和 DNS；任一步失败均设计了新对象自动回退。本次未触发回退。

| 通道 | 新 Access 应用 | 会话 | 新 Published application | DNS |
|---|---|---|---|---|
| VPS | `la-vps-access`，复制原 owner-only Allow | 8h | `access-la.tttthappy1111.org → ssh://localhost:22` | Proxied Tunnel CNAME |
| 家庭 Mac | `home-mac-access`，复制原 owner-only Allow | 24h | `access-home.tttthappy1111.org → ssh://localhost:22` | Proxied Tunnel CNAME |

Tunnel 更新采用读取完整现状后插入新规则：

- `la-vps-admin` 配置版本 `1 → 2`，旧 `ssh-vps`、新 `access-la` 和兜底 404 同时存在；
- `home-lan` 配置版本 `2 → 3`，旧 `ssh-home`、新 `access-home` 和兜底 404 同时存在；旧 hostname 的 origin settings 被复制到新规则；
- 家庭 `warp-routing.enabled=true` 写后回读保持不变；
- `saturate` 未修改。

两个新域名外部 HTTPS 探测均为 `302` 跳转 Cloudflare Access 登录域，证明发布后仍受门禁保护。

## 公司电脑切换

切换前备份：

- Windows：`C:\Users\29455\.ssh\config.bak-access-hostnames-20260826`；
- WSL：`/home/t/.ssh/config.bak-access-hostnames-20260826`。

实际只修改三行 `HostName`：

- Windows `la-vps-access` → `access-la.tttthappy1111.org`；
- Windows `home-mac-access-cloudflare-access-ssh` → `access-home.tttthappy1111.org`；
- WSL `home-mac-access` → `access-home.tttthappy1111.org`。

逐字 diff 确认除此之外无改动；User、Port、ProxyCommand、IdentityFile、HostKeyAlias、StrictHostKeyChecking 均保持原值。Windows和WSL的 `ssh -G` 全部通过。

## 真实 SSH 验收

| 客户端与目标 | 实际结果 |
|---|---|
| Windows → VPS `la-vps-access` | 返回 `special-wall-1.localdomain`、`root`、`access-la-ok` |
| Windows → 家庭 Mac Access | 返回 `macdeMac-mini.local`、`mac`、`access-home-windows-ok` |
| WSL → 家庭 Mac `home-mac-access` | 返回 `macdeMac-mini.local`、`mac`、`access-home-wsl-ok` |
| Windows 两目标重复短连接 | 返回 `vps-repeat-ok`、`home-repeat-ok` |

VPS 首次连接在等待浏览器 Access 认证时超过 30 秒客户端超时，没有进入服务器；放宽等待并由用户完成登录后成功。一次性登录 URL、Token、Cookie、OTP 和邮箱均未写入本文。

最终 Cloudflare 回读：

- `la-vps-admin=healthy`，`conns_inactive_at=null`；
- `home-lan=healthy`，`conns_inactive_at=null`；
- `saturate=healthy`，`conns_inactive_at=null`；
- 两个新 Access 应用各 1 个，两个旧 Access 应用也各 1 个。

## 当前安全停止点

旧入口尚未删除：

- `ssh-vps.tttthappy1111.org`；
- `ssh-home.tttthappy1111.org`。

因此当前是可随时回退的双 hostname 状态。用户明确确认清理后，才按“删除旧 DNS → 删除旧 ingress → 删除旧 Access 应用 → 回读 Tunnel/新 SSH”的受控顺序执行；本轮不关闭 VPS 公网 22。
