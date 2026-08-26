# 洛杉矶 VPS SSH · Connector 与发布路由完成

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：VPS 独立 Connector 已运行，Cloudflare Published application、DNS 和 Access 门禁均已创建并回读通过；尚未完成公司电脑真实 SSH 登录验收。  
> 下一步：在公司电脑配置 `cloudflared access ssh` 客户端入口，完成 Access 登录、SSH 主机指纹和真实命令验收后，再决定是否收口 VPS 公网 22 端口。

## VPS 执行结果

用户在 KiwiVM Interactive 执行修正版脚本后返回：

- `cloudflared-la-vps-admin.service` 为 `enabled`、`active running`；
- 原有 `cloudflared.service` 仍为 `enabled`、`active running`；
- 新 Connector 已注册 QUIC Tunnel connection；
- 脚本输出 `CONNECTOR_INSTALL_OK`。

Cloudflare API 随后回读：`la-vps-admin=healthy`，原有 `saturate=healthy`，两者均无 `conns_inactive_at`。

## Cloudflare 实际写入

写入前已确认目标 DNS 不存在、新 Tunnel 无 ingress，并确认以下 Access 门禁已经存在：

- 应用：`la-vps-ssh`；
- 类型：`self_hosted`；
- 域名：`ssh-vps.tttthappy1111.org`；
- 会话时长：`8h`；
- 唯一策略：`allow-la-vps-owner-only`，动作为 `allow`。

随后仅对 `la-vps-admin` 和目标域名执行：

| 对象 | 写入并回读的结果 |
|---|---|
| Published application | `ssh-vps.tttthappy1111.org → ssh://localhost:22` |
| 兜底规则 | `http_status:404` |
| Tunnel 配置版本 | `0 → 1` |
| DNS | `ssh-vps.tttthappy1111.org` 为 proxied CNAME，指向该 Tunnel 的 `cfargotunnel.com` 地址 |

执行逻辑带半成品保护：先创建目标 DNS，再更新 Tunnel；若 Tunnel 更新失败则自动删除本轮新建 DNS。本次两步均成功，没有触发回退。

## 验证与边界

- 外部解析已生效；本机受 Clash Fake-IP 影响解析为 `198.18.*` 属客户端代理行为，不作为权威 DNS 值；
- HTTPS 探测返回 Cloudflare Access 登录跳转和受保护资源标记，证明入口受 Access 门禁保护；
- 写后再次回读 `la-vps-admin` 与 `saturate`，均保持 `healthy`；
- 未修改 `saturate`、`home-lan`、家庭 Access、Clash、VLESS/CDN、VPS SSH 配置或防火墙；
- 当前验证只证明 Connector、路由、DNS 和 Access 门禁成立，尚不能代替公司电脑上的真实 SSH 登录验收。

## 回退

如客户端验收失败，只回退本轮发布层，不删除 Tunnel、不动旧服务：

1. 从 `la-vps-admin` 删除 `ssh-vps.tttthappy1111.org → ssh://localhost:22` Published application；
2. 删除且只删除 `ssh-vps.tttthappy1111.org` 对应的 Tunnel CNAME；
3. 回读确认 `la-vps-admin` 与 `saturate` 仍为 `healthy`。

VPS Connector 本身可继续保留用于排查。只有明确放弃整条新通道时，才执行 `/root/la-vps-admin-setup-v2.sh rollback`；不得操作原有 `cloudflared.service`。
