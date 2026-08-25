# Windows 局域网 SSH 配置执行记录

> 日期：2026-08-22  
> 工具：codex  
> 当前状态：Windows 主机和 Mac 客户端均已配置完成；Mac 公钥实际登录 `work-windows-lan` 及通过 ProxyJump 登录 `work-wsl-lan` 均成功。  
> 下一步：日常开发直接使用 `ssh work-wsl-lan`；路由器建议为 Windows 保留 `192.168.5.88`、为 Mac mini 保留 `192.168.5.35`。

## 1. 边界和结论

这是 Mac 在同一家庭局域网内访问 Windows/WSL 的前置子任务，与计划中的 Cloudflare 异地组网分开。本次没有登录或修改 Cloudflare。

推荐保留两个 SSH 别名：

- `work-wsl-lan`：日常开发首选，经 Windows 跳板直接进 WSL，Linux 路径、命令、systemd 和工程环境都是原生的。
- `work-windows-lan`：处理 Windows 文件、服务、日志、网络配置以及调用 `wsl.exe`。

稳定链路是：

```text
Mac ──SSH──> Windows 192.168.5.88:2222
                      └──ProxyJump/TCP forwarding──> Windows 127.0.0.1:22
                                                           └──wslrelay──> WSL sshd:22
```

这条链路不直接使用会随 WSL 重启变化的 `172.x.x.x` NAT 地址，因此比把 WSL NAT IP 写死稳定。

## 2. 最终配置

| 项目 | 已核实结果 |
|---|---|
| Windows 主机/用户 | `T` / `29455` |
| Windows LAN | `192.168.5.88/24`，网卡 `WLAN` |
| Windows OpenSSH | `sshd` = `Running + Automatic` |
| 入口 | TCP `2222`，监听 `0.0.0.0` 和 `::` |
| 认证 | 仅公钥；`AuthenticationMethods publickey`，密码和键盘交互认证关闭 |
| 管理员公钥 | `C:\ProgramData\ssh\administrators_authorized_keys`，已安装 2 枚预置 Mac 公钥 |
| TCP 转发 | `AllowTcpForwarding yes`，专门供 Mac `ProxyJump` 进 WSL |
| 防火墙 | 入站 Allow TCP/2222，仅 `WLAN + LocalSubnet` |
| Windows TCP/22 | 仍只有 `127.0.0.1` / `::1` 的 `wslrelay.exe` |
| WSL | `networkingMode=nat`，未改 |
| Tailscale | `Stopped + Disabled`，未改 |
| Clash/Mihomo | 进程和启动时间未变，未改 |
| Mac mini | `mac@macdeMac-mini.local`，macOS `15.5`，LAN `192.168.5.35` |

对网络的实际影响只有一项：Windows 在家庭 WLAN 本地子网放行新的 TCP/2222 入站。未改 DNS、默认路由、代理、WSL NAT 或其他端口。

## 3. 故障根因与修复

最初 `sshd` 以 Windows 服务身份启动时报 1067，但前台手工启动能监听。最终用一次性 SYSTEM 身份调试确认：主机私钥的所有者/ACL 过宽，SYSTEM `sshd` 以 `Bad owner` / `UNPROTECTED PRIVATE KEY FILE` 拒绝读取。

修复内容：

1. 仅修复 Windows OpenSSH Server 可选组件；OpenSSH Client 不动。
2. 将 `ssh_host_*_key` 私钥的所有者设为 Administrators，ACL 仅允许 SYSTEM 和 Administrators。
3. 限制管理员公钥文件 ACL，验证 `sshd -t`、服务启动、监听地址、防火墙和 SSH 握手。

组件修复前备份：`C:\ProgramData\codex-openssh-repair-backups\20260822-205958`。

## 4. 验收证据与剩余未知

已通过：

- WSL 到 `192.168.5.88:2222` TCP 连接成功。
- `ssh-keyscan` 已与 Windows `sshd` 完成 SSH 握手，RSA/ECDSA/ED25519 主机钥都能返回。
- 配置指令、服务状态、2222/22 监听地址、防火墙限制、Tailscale 和 WSL NAT 状态已复核。

后续只剩路由器层未知：

- Mac 的 `~/.ssh/id_ed25519` 已成功登录 Windows；`ProxyJump` 进 WSL 的完整公钥登录也已成功。
- 路由器 DHCP 是否为 Windows/Mac 保留当前 LAN IP 尚未核实；未核实前不应猜测它们不会变。

## 5. 日常检查与回退

在 WSL 工程目录运行：

```bash
bash scripts/windows-lan-ssh.sh status    # 只读状态，需点一次 UAC
bash scripts/windows-lan-ssh.sh apply     # 备份后重新应用，失败自动回滚
bash scripts/windows-lan-ssh.sh rollback  # 回到最近一次 apply 之前
```

最新回退指针：

```text
C:\ProgramData\ssh\codex-last-lan-ssh-backup.txt
→ C:\ProgramData\ssh\codex-backups\20260822-220930
```

`rollback` 会读取该指针，恢复之前的 sshd 配置/服务状态、主机钥、管理员公钥文件、ACL 和本脚本的防火墙规则。`windows-openssh-repair.ps1` 只是 OpenSSH 可选组件损坏时的恢复工具，日常不要运行。

## 6. Mac SSH 配置

已在 Mac 上将下面两段以受管标记块合并到 `~/.ssh/config`。原 Tailscale 条目保留，原来完全相同的两份 Tailscale 块去重为一份。

```sshconfig
Host Thinkpad-Windows-LAN work-windows-lan
    HostName 192.168.5.88
    Port 2222
    User 29455
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host Thinkpad-WSL-LAN work-wsl-lan
    HostName 127.0.0.1
    Port 22
    User t
    ProxyJump work-windows-lan
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    HostKeyAlias ThinkPad-WSL-LAN
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Mac 实际验收结果：

```text
ssh work-windows-lan  → t\29455 / t，返回码 0
ssh work-wsl-lan      → t / t / Linux 6.18.33.2-microsoft-standard-WSL2 x86_64，返回码 0
```

首次连接前，已从 Mac 实际扫描并核对 Windows 主机指纹，然后才写入 Mac `known_hosts`。Windows 当前 ED25519 指纹：

```text
SHA256:7pI6hPPgGs+mz2+YiaS5PO7VjJItZy6yGXwPZ+SDpp8
```

Mac 可精确回退到本次修改之前：

```bash
cp ~/.ssh/config.bak-before-windows-lan-20260822-222205 ~/.ssh/config
cp ~/.ssh/known_hosts.bak-before-windows-lan-20260822-222310 ~/.ssh/known_hosts
chmod 600 ~/.ssh/config ~/.ssh/known_hosts
```

## 7. Mac 连上后能做什么

`work-windows-lan` 能做：读写用户有权限的 Windows 文件，执行 `cmd.exe` / `powershell.exe` / `wsl.exe`，查看服务、事件日志和网络状态，以及运行不需桌面交互的 Windows 工具。

`work-wsl-lan` 能做：直接使用 WSL 用户 `t` 的 Linux 环境，包括本工程、Git 本地操作、编译、测试、systemd 用户/系统服务（以 Linux 权限为准），也适合 VS Code Remote-SSH。

做不了或需要人配合的事：

- SSH 不提供 Windows 图形桌面，不能代替远程桌面。
- Windows UAC 安全桌面不能从普通 SSH 会话中直接点击；管理员变更仍可能需要用户在 Windows 上点“是”。
- 依赖已登录桌面、托盘或交互窗口的应用不适合纯 SSH 自动化。
- 从 Windows SSH 里再用复杂内联命令调 `wsl.exe` 容易遇到变量/引号跨边界问题；正式 WSL 开发优先直连 `work-wsl-lan`。

## 8. 与后续组网的关系

本次解决的是“Mac 和 Windows 在同一局域网”的 SSH。后续 Cloudflare 或其他组网方案只需安全地把这个私网地址变得可路由，不应重新暴露 WSL 动态 NAT IP，也不需要破坏现有 Clash 所需的 NAT 模式。
