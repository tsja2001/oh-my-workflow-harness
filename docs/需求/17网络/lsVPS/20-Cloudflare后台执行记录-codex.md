# 洛杉矶 VPS SSH · Cloudflare 后台执行记录

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：Cloudflare Access 应用和独立 Tunnel 已创建并回查；Tunnel 尚无 Connector，DNS/SSH Route 尚未发布，VPS 尚未修改。  
> 下一步：用户在搬瓦工 KiwiVM/KVM 执行 `10b-Cloudflare与搬瓦工KVM实施手册-codex.md` 第 5.1 节只读盘点，把脱敏输出交给 Codex 判断。

## 已执行

2026-08-25 通过本机 Codex 的 Cloudflare API MCP 执行，并在写入前后做了精确名称回查：

| 对象 | 实际结果 |
|---|---|
| 本机 MCP | 已注册 `cloudflare → https://mcp.cloudflare.com/mcp`，OAuth 登录成功；凭据未写入工作区或聊天 |
| Access 应用 | 已创建 `la-vps-ssh`，类型 `self_hosted`，主机名 `ssh-vps.tttthappy1111.org`，会话 `8h`，App Launcher 隐藏 |
| Access 策略 | 已创建唯一策略 `allow-la-vps-owner-only`，动作为 `Allow`，仅复用 `home-mac-ssh` 的本人邮箱选择器；邮箱值未回显 |
| Tunnel | 已创建远程管理 Tunnel `la-vps-admin`，ID `d2c5a8a1-583a-4fea-97d3-7f96b71c3d64`，`config_src=cloudflare` |
| Tunnel 当前状态 | `inactive`，Connector 数 `0`；VPS Connector 尚未安装时符合预期 |
| DNS / Published application | `ssh-vps.tttthappy1111.org` 仍不存在；尚未发布 `ssh://localhost:22` |

## 隔离与回查

Cloudflare MCP 写后回读结果：

- `home-lan`：`healthy`，未修改；
- `saturate`：`healthy`，未修改；
- `la-vps-ssh`：应用、8 小时会话和 owner-email Allow 策略均存在；
- `la-vps-admin`：存在，尚无 Connector；
- `ssh-vps.tttthappy1111.org`：无 DNS 记录；
- 未修改 `home-mac-ssh`、`ssh-home`、`cdn`、WARP/CIDR、Clash 或 VPS。

首次 Access 写入曾被旧 OAuth 授权以 API `1010` 拒绝；精确回查确认当时没有产生对象。用户重新授权最小写权限后创建成功。没有 Token、邮箱、验证码或其他凭据进入本文。

## 当前停止点

现在不能发布 Route。必须按以下顺序继续：

1. 保持 `la-vps-admin` 和 `la-vps-ssh` 不变；
2. 打开搬瓦工 KiwiVM/KVM；
3. 执行实施手册第 5.1 节只读盘点；
4. Codex 根据真实 OS、CPU、现有 cloudflared/sshd/systemd 状态给出下一段命令；
5. 备份后安装独立 Connector；
6. Tunnel 变为 Healthy 且旧 `saturate` 仍 Healthy 后，才发布 `ssh-vps → ssh://localhost:22`。

## 当前回退

VPS 和 DNS 尚未改动。如果决定中止，只需在 Cloudflare 删除且只删除本轮新建的 `la-vps-admin` 和 `la-vps-ssh`；不得触碰 `home-lan`、`saturate`、`home-mac-ssh`、`ssh-home` 或 `cdn`。
