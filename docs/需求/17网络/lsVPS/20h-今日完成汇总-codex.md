# 洛杉矶 VPS Cloudflare Access SSH · 今日完成汇总

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：独立 Access SSH 通道已从 Cloudflare 前置、KiwiVM Connector、发布路由推进到公司 Windows 真实 SSH 登录成功。  
> 下一步：按 `10c-中性域名并行迁移计划-codex.md` 将 VPS 与家庭 Mac 的公开 SSH 域名迁移为中性名称；验收前保留旧入口。

## 今日已完成

1. 建立独立的 Cloudflare 对象：
   - Access 应用 `la-vps-ssh`，精确保护 `ssh-vps.tttthappy1111.org`；
   - 唯一 owner-only Allow 策略，会话时长 8 小时；
   - 独立远程管理 Tunnel `la-vps-admin`。
2. 针对 KiwiVM/AlmaLinux 9.7 完成一体化安装脚本：
   - 修复最小系统缺少 `xargs`；
   - 修复 `pipefail + grep -q` 的 SIGPIPE 误判；
   - 改为 Advanced 创建脚本、Interactive 无回显粘贴 Token；
   - 脚本只管理新 Connector，不修改旧 `cloudflared.service`、SSH、防火墙或 Clash。
3. VPS 真实执行成功：
   - `cloudflared-la-vps-admin.service` 为 `enabled`、`active running`；
   - 新 Connector 注册 QUIC 连接并输出 `CONNECTOR_INSTALL_OK`；
   - 原有 `cloudflared.service` 保持运行。
4. Cloudflare 发布完成：
   - `ssh-vps.tttthappy1111.org → ssh://localhost:22`；
   - Proxied CNAME 已创建；
   - `la-vps-admin` 与原 `saturate` 均回读为 `healthy`；
   - 外部请求正确进入 Cloudflare Access 登录门禁。
5. 公司 Windows 客户端配置完成：
   - 新增 SSH 别名 `la-vps-access`；
   - 复用现有 Windows `cloudflared.exe`、VPS 私钥和原主机指纹；
   - 用户完成 Access 登录后，`ssh la-vps-access` 已真实连接 VPS。

## 当前仍保留

- VPS 公网 22 端口尚未关闭；
- 旧代理业务、`saturate`、VLESS/CDN 均未修改；
- 家庭 `home-lan`、WARP/CIDR 与 Mac Connector 均未修改；
- Cloudflare Token、邮箱、OTP、Cookie 和私钥没有写入文档或聊天。

## 新发现与后续决定

公司网络或终端管理可能通过 DNS、TLS/SNI、代理日志或进程命令行看到公开 hostname。域名改为中性名称只能减少名称直接暴露用途，不能隐藏 `ssh.exe`/`cloudflared access ssh`，也不能替代公司合规要求。

用户决定将两条公开 hostname 并行迁移为：

- VPS：`access-la.tttthappy1111.org`；
- 家庭 Mac：`access-home.tttthappy1111.org`。

旧 `ssh-vps`、`ssh-home` 只有在新入口真实 SSH 验收完成且用户再次确认后才删除。
