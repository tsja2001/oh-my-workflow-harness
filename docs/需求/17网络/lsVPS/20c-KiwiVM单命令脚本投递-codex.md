# 洛杉矶 VPS SSH · KiwiVM 单命令脚本投递

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：已把当前阶段的一次性安装脚本压缩为 Base64 单命令，编码解码逐字节回环验证通过。  
> 下一步：用户在 KiwiVM Advanced 执行单命令生成 `/root/la-vps-cloudflared.sh`，核对 SHA-256 后从 Interactive 执行。

源文件为 `scripts/la-vps-cloudflared-apply.sh`，不包含 Token。生成文件的预期 SHA-256：

```text
698b8e559675e95cc79d43d462bbcbfdc7495d2da5010e1c4500ac10bddab9d8
```

脚本复用 VPS 已有的限权 Token 文件、独立 cloudflared、服务账号和备份指针；只创建并启动 `cloudflared-la-vps-admin.service`，不改 SSH、防火墙或 Cloudflare DNS/Route。
