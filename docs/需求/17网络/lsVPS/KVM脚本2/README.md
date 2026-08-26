# KiwiVM 一体化交互脚本

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：首版预检在 AlmaLinux 暴露 `xargs` 缺失和 `pipefail + grep -q` 偶发误判，兼容修正版已完成本地验证；两次失败均发生在任何 VPS 写入之前。  
> 下一步：在 KiwiVM Advanced 执行 `02-Advanced-预检兼容修正版生成命令.txt` 的唯一一行，看到退出码 0 后回到 Interactive 执行修正版。

## 文件

- `01-Advanced-生成命令.txt`：首版历史载荷，已停用，不再执行。
- `02-Advanced-预检兼容修正版生成命令.txt`：当前载荷，在 KiwiVM Advanced 执行，覆盖生成修正版 `/root/la-vps-admin-setup-v2.sh`。
- `la-vps-admin-setup-v2.sh`：生成后的 Bash 源文件；默认执行安装，也支持只读状态和精确回退。
- `build-advanced-command.sh`：从 Bash 源文件机械生成压缩载荷和哈希，避免人工复制 Base64；不在 VPS 执行。

生成文件预期 SHA-256：

```text
7197c4879852bfaa20f94bec2689835548d2bb8854fa7ef23d132f7b7dfbcee6
```

## 执行顺序

1. Advanced：完整复制并执行 `02-Advanced-预检兼容修正版生成命令.txt` 的唯一一行。
2. KiwiVM Task File 必须显示 `Exit code: 0`；若它保留标准输出，还会看到 `/root/la-vps-admin-setup-v2.sh: OK` 和 `SCRIPT_FIX_CREATE_OK`。
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
