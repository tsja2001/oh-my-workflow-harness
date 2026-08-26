# 洛杉矶 VPS SSH · KiwiVM Advanced 一键生成与交互安装

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：一体化脚本、Advanced 单行载荷和本地验证均已完成；VPS、Cloudflare Route/DNS、SSH 和防火墙尚未执行本轮改动。  
> 下一步：用户只执行本文第 2 节 Advanced 生成步骤，看到 `SCRIPT_CREATE_OK` 后先把输出发给 Codex。

> 本文取代 `20d-KVM分步短脚本执行-codex.md`，取代原因：用户明确要求重新收敛为“一条 Advanced 命令生成一个 Bash，执行 Bash 时直接无回显粘贴 Token”的流程。旧脚本和旧文档继续保留，不覆盖、不删除。

## 1. 这次重新准备成什么样

```text
KiwiVM Advanced：执行一条压缩载荷命令
  → 自动生成 /root/la-vps-admin-setup-v2.sh
  → 自动核对 SHA-256

KiwiVM Interactive：bash /root/la-vps-admin-setup-v2.sh
  → 先只读预检 root/systemd/cloudflared/localhost:22
  → 提示粘贴 eyJ... Token（不回显、不进命令历史）
  → 备份本轮会触碰的同名文件
  → 创建独立程序、账号、限权 Token 文件和 systemd unit
  → 启动并等待真实 Registered tunnel connection
  → 成功输出 CONNECTOR_INSTALL_OK；失败只回退本轮新服务
```

脚本不会修改：

- 旧 `saturate`、默认 `cloudflared.service` 和现有 VLESS/CDN；
- SSH 配置、22 端口监听和防火墙；
- Clash、家庭 `home-lan`、WARP/CIDR；
- Cloudflare DNS、Published application 或 Access 策略。

## 2. 现在只做 Advanced 生成

打开工作区文件：

```text
docs/需求/17网络/lsVPS/KVM脚本2/01-Advanced-生成命令.txt
```

它只有一行。完整复制到 KiwiVM `Root shell - advanced` 并执行。

成功时必须同时看到：

```text
/root/la-vps-admin-setup-v2.sh: OK
SCRIPT_CREATE_OK
```

预期文件 SHA-256：

```text
2dd803ca0ac4be5dd47212c2d54ffbce2c880e1ad4f982441e98042b1e206102
```

如果没有两个成功标志，或出现 `base64`、`gzip`、`sha256sum` 错误：立即停止，不执行半成品，把原样输出发给 Codex。

## 3. Advanced 成功后再执行 Bash

在 KiwiVM Interactive 只执行：

```bash
bash /root/la-vps-admin-setup-v2.sh
```

脚本先打印现状并显示 `PRECHECK_OK`，随后提示：

```text
Paste only the full eyJ... Tunnel Token, then press Enter.
Token will not be displayed:
```

此时回到 Cloudflare：

```text
Zero Trust → Networking → Tunnels → la-vps-admin → Add a replica
```

从页面安装命令中只复制完整 `eyJ...` Token，粘贴到 Interactive 后按回车。不要复制 `sudo cloudflared service install`，也不要把 Token 发到聊天或文档。

这一步只需粘贴 Token 本身，不需要再输入另一条保存 Token 的终端命令。Token 不回显、不进入 Bash 命令历史；脚本只把它写入 VPS 的限权文件 `/etc/cloudflared-la-vps-admin/token`。

## 4. 执行结果怎么判断

成功输出必须包含：

```text
PRECHECK_OK
token_format=accepted token_value=not_displayed
ActiveState=active
SubState=running
Registered tunnel connection
CONNECTOR_INSTALL_OK
```

还必须在 Cloudflare 页面单独看到：

- `la-vps-admin` 有 Connector；
- Tunnel 状态为 `Healthy`；
- 旧 `saturate` 仍为 `Healthy`。

在以上 VPS 输出和 Cloudflare 页面证据都齐全前，不创建 `ssh-vps → ssh://localhost:22` Route，不创建 DNS，也不关闭公网 SSH。

脚本日志会自动把疑似 Token 替换为 `[TOKEN-REDACTED]`。可以把最终输出原样发给 Codex；不要另行执行 `cat /etc/cloudflared-la-vps-admin/token` 或粘贴 Cloudflare 的完整安装命令。

## 5. 失败与回退

Token 格式不对发生在任何修改之前，脚本直接停止。

写入或启动后失败，脚本会停止且尝试恢复同名 unit、Token 和独立程序副本，并输出：

```text
ROLLBACK_OK
AUTO_ROLLBACK_OK
```

旧 `saturate`、SSH、防火墙和 DNS 不在回退范围，因为脚本从未修改它们。失败后保持 KiwiVM 可用，把完整脱敏输出发给 Codex，不反复换 Token 或重复执行。

日后只读复查：

```bash
bash /root/la-vps-admin-setup-v2.sh status
```

只有收到明确回退指示时才执行：

```bash
bash /root/la-vps-admin-setup-v2.sh rollback
```

## 6. 本地验证记录

2026-08-26 已完成：

- `bash -n` 语法检查通过；
- 源脚本 399 行、11.9 KB；压缩 Base64 载荷约 5.1 KB；
- Advanced 命令为单行，载荷解码、解压后与源脚本逐字节一致；
- SHA-256 自动校验值与源脚本一致；
- 非 root 和非法模式均能在修改前以退出码 1 停止；
- 静态扫描未发现真实 Token、Tunnel ID、VPS IP 或占位凭据。
