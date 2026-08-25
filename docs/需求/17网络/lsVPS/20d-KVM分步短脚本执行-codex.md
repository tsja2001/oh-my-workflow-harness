# 洛杉矶 VPS SSH · KVM 分步短脚本执行

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：本文取代 20b/20c 的长脚本和 Base64 投递方式；已按用户要求拆为 Advanced 建文件、Interactive 短命令执行的 01～05 脚本。  
> 下一步：从 `KVM脚本/README.md` 开始，严格按 01、02、03 执行。

脚本目录：`docs/需求/17网络/lsVPS/KVM脚本/`。

- 01 只读预检；
- 02 备份并准备独立 systemd unit，不启动；
- 03 使用用户只在 KiwiVM Advanced 填写的 Token，写入限权文件、删除自身并启动；
- 04 只读状态和脱敏日志；
- 05 只回退本轮新 unit/Token 文件。

所有工作区脚本只含占位符，不含真实 Token。旧 `home-lan`、`saturate`、SSH、防火墙、DNS/Route 和 Clash 均不在脚本修改范围。

