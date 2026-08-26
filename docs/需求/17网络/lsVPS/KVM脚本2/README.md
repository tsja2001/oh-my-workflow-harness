# KiwiVM 一体化交互脚本

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：Advanced 单行生成命令和一体化 Bash 已完成本地验证，尚未在 VPS 执行。  
> 下一步：先在 KiwiVM Advanced 执行 `01-Advanced-生成命令.txt` 的唯一一行，看到 `SCRIPT_CREATE_OK` 后把输出发给 Codex。

## 文件

- `01-Advanced-生成命令.txt`：在 KiwiVM Advanced 执行，自动生成 `/root/la-vps-admin-setup-v2.sh`。
- `la-vps-admin-setup-v2.sh`：生成后的 Bash 源文件；默认执行安装，也支持只读状态和精确回退。

生成文件预期 SHA-256：

```text
2dd803ca0ac4be5dd47212c2d54ffbce2c880e1ad4f982441e98042b1e206102
```

## 执行顺序

1. Advanced：完整复制并执行 `01-Advanced-生成命令.txt` 的唯一一行。
2. 必须看到 `/root/la-vps-admin-setup-v2.sh: OK` 和 `SCRIPT_CREATE_OK`。
3. Interactive：执行 `bash /root/la-vps-admin-setup-v2.sh`。
4. 出现 Token 提示后，只粘贴 Cloudflare `la-vps-admin` 页面里的完整 `eyJ...` Token并按回车；Token 不回显。
5. 把脚本最终输出发给 Codex。只有出现 `ActiveState=active`、`SubState=running`、注册连接日志和 `CONNECTOR_INSTALL_OK`，才进入 Cloudflare Route/DNS 发布。

只读复查：

```bash
bash /root/la-vps-admin-setup-v2.sh status
```

仅收到明确回退指示时执行：

```bash
bash /root/la-vps-admin-setup-v2.sh rollback
```

脚本只管理 `cloudflared-la-vps-admin.service`、它的独立程序副本和 Token 文件；不修改旧 `saturate`、默认 `cloudflared.service`、SSH、防火墙、Clash、DNS 或 Cloudflare Route。安装失败或中断时会尝试恢复本轮备份。

