# B通道公司端短版验收报告

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：公司 Windows、WSL、Cloudflare Access、家庭 Mac SSH、路由器和 Home Assistant 的短版端到端验收通过；B 通道冷连接未体现稳定提速，30 分钟长连接按用户要求暂不测试。  
> 下一步：用户决定是否把 WSL 的 `home-mac-access` 永久改为复用 Windows `cloudflared.exe`；未决定前保持现有配置不动。

> 本文接续 `30e-B通道家庭端验收报告-codex.md`，只新增公司端真实网络结果，不覆盖家庭端报告。用户已明确确认公司允许后开始验收。

## 1. 验收边界

- 本轮不修改 Cloudflare、Clash、WARP、SSH 永久配置、家庭 Mac 或 A 通道。
- 用户在浏览器中亲自完成 Cloudflare Access 批准；AI 未读取、保存或记录登录 URL、Token、验证码、密码和私钥。
- 按用户要求跳过 30 分钟空闲连接和 VS Code 长连接测试。
- 临时浏览器适配脚本仅创建在 `/tmp`，验收后已删除。

## 2. 真实功能结果

| 检查项 | 实际结果 | 结论 |
|---|---|---|
| Windows `ssh home-mac-access hostname` | 返回 `macdeMac-mini.local`，退出码 0 | PASS |
| Windows Access 身份验证 | 浏览器批准后 SSH 自动继续 | PASS |
| Windows 现有 SSH 私钥 | 完成 Mac 公钥认证，无新指纹提示 | PASS |
| WSL OpenSSH + WSL 私钥 | 临时复用 Windows `cloudflared.exe` 后返回同一 Mac 主机名 | PASS |
| 家庭路由器 | Mac 端请求 `192.168.5.1` 返回 `router-ok` | PASS |
| Home Assistant | Mac 端请求 `127.0.0.1:8123` 返回 `ha-ok` | PASS |

这证明以下实际链路可用：

```text
公司 Windows / WSL OpenSSH
→ Cloudflare Access
→ home-lan Tunnel
→ 家庭 Mac sshd
→ Mac 公钥认证
→ 家庭路由器 / Home Assistant
```

## 3. A/B 短连接计时

同一公司 Windows、同一时段，各执行 3 次冷 SSH 连接并立即退出：

| 通道 | 第1次 | 第2次 | 第3次 | 平均 |
|---|---:|---:|---:|---:|
| A：WARP/CIDR `home-mac` | 8.00秒 | 7.89秒 | 8.69秒 | 8.19秒 |
| B：Access SSH `home-mac-access` | 9.19秒 | 7.38秒 | 10.36秒 | 8.98秒 |

这 3 次小样本只能说明 B 当前没有表现出稳定提速；B 平均约慢 0.78 秒，且波动更大。不能据此推断长期稳定性，因为本轮明确没有做长连接测试。

## 4. WSL 剩余问题

WSL 当前永久配置仍调用 Linux 版 `/home/t/.local/bin/cloudflared`。首次 Access 登录需要从 WSL 打开 Windows 浏览器，但本机没有 `xdg-open`/`wslview`，所以原别名无法自动弹出登录页。

本轮已经证明一个更简单的可用路径：WSL 的 OpenSSH 和 WSL 私钥不变，只把当次 ProxyCommand 临时指向已认证的 Windows `cloudflared.exe`，连接立即成功。该临时覆盖没有写入 `~/.ssh/config`。

若要让 WSL 日常直接运行 `ssh home-mac-access`，建议下一步先备份 WSL SSH config，再仅把这一条 ProxyCommand 改为 Windows `cloudflared.exe` 路径；改后重新执行 `ssh -G`和真实 hostname 验证。未获用户确认前不执行。

## 5. 当前结论

- B 通道功能验收通过，可作为不依赖 WARP CIDR 的单主机 SSH 备用入口。
- 现有 A 通道本轮仍可用，3 次冷连接平均值略优于 B；不能以“Access 架构更直接”代替实测结论。
- 当前不删除 B，也不扩展更多 Published Application；先保留 A 为主、B 为备用。
- WSL 永久配置尚有一行客户端兼容性尾项；Windows 端已经可以直接使用。
- 本轮未操作远程 Git。
