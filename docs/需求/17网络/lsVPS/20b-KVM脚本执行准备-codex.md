# 洛杉矶 VPS SSH · KVM 脚本执行准备

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：已生成独立可复用脚本；VPS 前一轮已完成备份、独立程序、服务账号和 Token 文件，但 systemd unit 因 Interactive 粘贴丢失 heredoc 结束标记而未启动。  
> 下一步：通过 KiwiVM `Root shell - advanced` 把脚本保存为 `/root/la-vps-cloudflared.sh`，再从 Interactive 执行 `apply`。

## 脚本来源

工作区文件：`scripts/la-vps-cloudflared.sh`。

脚本不包含 Token，不读取或输出 Token 内容。它只使用 VPS 已存在的：

- `/usr/local/lib/cloudflared-la-vps/cloudflared`；
- `/etc/cloudflared-la-vps-admin/token`；
- `/root/la-vps-admin-last-backup.txt`；
- 用户/组 `cloudflared-la-vps`。

## KiwiVM 操作

1. 在 `Root shell - advanced` 新建 `/root/la-vps-cloudflared.sh`，内容完整复制自工作区同名脚本。
2. 回到 `Root shell - interactive` 执行：

   ```bash
   chmod 700 /root/la-vps-cloudflared.sh
   bash /root/la-vps-cloudflared.sh apply
   ```

3. 成功标准：出现 `ActiveState=active`、`SubState=running` 和 `CONNECTOR_INSTALL_OK`。
4. 只读复查：`bash /root/la-vps-cloudflared.sh status`。
5. 如需只回退新服务：`bash /root/la-vps-cloudflared.sh rollback`。回退保留 Token 文件、独立程序、服务账号和备份，便于诊断与恢复。

脚本不修改 SSH、防火墙、Cloudflare DNS/Route、`home-lan`、`saturate`、Clash 或其他服务。
