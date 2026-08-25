# B通道家庭端验收报告

> 日期：2026-08-24
> 工具：codex
> 当前状态：家庭端、Cloudflare Access、Tunnel 和 SSH 服务端链路已验收通过到 SSH 用户认证阶段；公司 Windows/WSL 现有密钥和公司网络体验仍待明日实测。
> 下一步：公司端分别执行 `ssh home-mac-access`，成功后补 hostname、30 分钟长连接和 A/B 延迟结果。

> 本文是 `20j-B通道Cloudflare后台配置-codex.md` 的验收记录；测试边界遵守 `10i-B通道今晚家庭端与明日公司端收口计划-codex.md` 第 5 节，不能用家庭网络代替公司网络下结论。

## 1. 验收结果

| 检查项 | 证据 | 结果 |
|---|---|---|
| Mac cloudflared | `/opt/homebrew/bin/cloudflared`，版本 `2026.8.2` | PASS |
| Mac Tunnel 系统服务 | `launchctl` 回读 `state = running` | PASS |
| Mac SSH 服务端口 | `nc -z 127.0.0.1 22` 成功 | PASS |
| Access 应用 | 页面列表存在 `home-mac-ssh` | PASS |
| owner-only 策略 | 页面详情为 `Include / Emails / 当前登录账号`，Action=`Allow` | PASS |
| Published application | 页面显示 `ssh-home.tttthappy1111.org`、`ssh://localhost:22` | PASS |
| 自动 DNS | DNS 页面显示该主机名为 `Tunnel / home-lan / Proxied / Auto` | PASS |
| A 通道未受损 | `home-lan` 为 Healthy，CIDR `192.168.5.0/24` 仍存在 | PASS |
| Access CLI 身份门禁 | `cloudflared access ssh` 打开 `home-mac-ssh` 登录页；当前账号授权后返回 `Success!` | PASS |
| SSH 穿透到 Mac sshd | 远端回报 `OpenSSH_9.9`，完成 KEX 并进入 `ssh-userauth` | PASS |
| SSH 主机身份 | 远端 ED25519 指纹与 `/etc/ssh/ssh_host_ed25519_key.pub` 计算值一致 | PASS |
| 家庭 Mac 自连接公钥登录 | 当前 Mac 自身 `id_ed25519` 不在服务端授权列表，停在 `Permission denied` | 不作为失败 |
| 公司 Windows/WSL 登录 | 本机无法代表公司出口和公司端现有密钥 | 待公司实测 |

## 2. 端到端测试说明

第一次直接在浏览器打开 SSH 主机名得到连接关闭，这不能作为故障结论：该 Published application 的源站协议是 SSH，不是网页 HTTP。

随后按真实客户端路径验证：

```text
Mac OpenSSH
→ ProxyCommand: cloudflared access ssh
→ Cloudflare Access 登录与 CLI Approve
→ Cloudflare Tunnel home-lan
→ Mac localhost:22
→ SSH 协议握手和主机指纹核对
→ SSH 用户公钥认证
```

实际已到达最后一步。测试使用 `BatchMode=yes`、临时禁用 known_hosts 写入；Mac 自身公钥未获授权，因此没有执行远端命令。这正是计划中允许的家庭端停止点，不应为了自连接测试把额外公钥写入 `authorized_keys`。本机实际回读授权公钥共有 3 条，但本文不输出公钥内容。

## 3. 明日公司端最短验收

Windows PowerShell：

```powershell
ssh home-mac-access
```

WSL：

```bash
ssh home-mac-access
```

首次弹出 Access 页面时，用户使用当前 Cloudflare 账号登录并批准 CLI 请求。预期随后直接使用此前已验证的公司端 SSH 私钥完成 Mac 公钥认证；不得接受与现有 `192.168.5.35` 不一致的主机指纹。

两端成功后再执行：

```bash
ssh home-mac-access 'hostname'
```

然后保持空闲连接 30 分钟，并与 `ssh home-mac` 的 A 通道做相同命令延迟对比。若公司侧 Access 被阻断、反复重置或明显更慢，继续使用 A 通道，不改 Clash、不删现有 CIDR 组网。

## 4. 当前结论

B 通道家庭端已经配置正确，且 Access 身份门禁、边缘、Tunnel、Mac `sshd` 和主机指纹形成了可验证的完整链路。唯一尚未验证的是公司网络和公司 Windows/WSL 的真实客户端登录；因此当前结论是“家庭端可交付，异地最终验收待公司端”，不是“全项目最终完成”。
