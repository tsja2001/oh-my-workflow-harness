# Cloudflare 家庭私网接入 · Windows 端预配置与明日执行

> 日期：2026-08-23
> 工具：codex
> 当前状态：目标 Windows 已装好并预配置 Cloudflare One Client，家庭端保持正常；设备注册、连接及异地数据面验收按设计留到公司网络执行。
> 下一步：本文对应的仓库提交推送后，明天在公司电脑 WSL 拉取 `main`，执行 `bash scripts/windows-cloudflare-one.sh setup`，本人只需完成一次邮箱验证码。

> 本文接续 `20d-路由器固定租约执行-codex.md`，补齐公司 Windows 的实机预配置、可重复脚本和明日唯一入口；不覆盖前序过程记录。

## 1. 今晚已经做完的事

| 项目 | 实际结果 | 证据 |
|---|---|---|
| Mac → Windows SSH | 成功 | Mac 标准 `~/.ssh/config` 的 `work-windows-lan` 实连 `192.168.5.88:2222`，返回 Windows 主机与当前用户 |
| 目标系统 | Windows 11，build `26200`，AMD64 | Windows PowerShell 实机体检 |
| WSL | Ubuntu 24.04 / WSL2 可用 | `wsl.exe --status` 与脚本体检 |
| 现有网络软件 | Clash Party 与 Mihomo 正在运行 | Windows 进程实查；安装后仍存在 |
| Cloudflare 客户端 | `Cloudflare One Client 26.7.1343.0` | Windows 卸载注册表与 `warp-cli` 实查 |
| 安装包可信性 | Authenticode 有效，签发给 `Cloudflare, Inc.` | 安装前 `Get-AuthenticodeSignature` 硬校验通过 |
| Windows 服务 | `CloudflareWARP` 为 Running | 安装后实查 |
| 组织预填 | `mute-cake-c395` | `warp-cli settings` 显示 local policy Organization |
| 当前注册/连接 | 未注册、未连接，这是预期状态 | `warp-cli registration show` 为 Missing registration；`status` 为 Unable / Registration Missing |
| 当前家庭路由 | `192.168.5.35` 仍经 WLAN 的 `192.168.5.0/24` 直连 | 安装后有效路由实查；尚无 WARP 数据面 |
| Windows SSH 别名 | 已新增 `home-mac`、`Macmini-Home`，复用原 `Macmini-Tailscale` 的既有密钥 | `C:\Users\29455\.ssh\config`；一次性备份为同目录 `config.codex-before-cloudflare` |

安装时只向官方 MSI 传了 `ORGANIZATION`。没有在 Windows 本地固化 Service mode、Split Tunnel 或 DNS 设置，避免本地策略压过已经在 Cloudflare Dashboard 定稿的 `Traffic only + Include` 配置。

## 2. 还没有宣称成功的部分

1. **Windows 尚未注册到 Zero Trust。** 这是故意留下的：注册必须由当前 Windows 用户在浏览器完成一次 One-time PIN，且不能在家庭网里把直连误当成 Cloudflare 成功。
2. **公司网络下的 WARP、Clash、WSL 共存尚未实测。** 今晚只证明安装没有让现有家庭网络和 Clash 退出。
3. **Windows → Mac 的免密 SSH 登录未得到成功证据。** 别名写入后，本次嵌套验证超过限定时间；已精确终止该测试且未重试。明日脚本会用 `-n + BatchMode + publickey only + 20 秒硬超时`重新验收，不会卡住。
4. **Mac → WSL 的 ProxyJump 别名本次连接被关闭。** 按用户要求未重试；不影响 Mac → Windows 已成功，也不影响明天在 Windows 本机 WSL 执行脚本。

## 3. 已固化进 Git 的两个入口

| 文件 | 用途 |
|---|---|
| `scripts/windows-cloudflare-one.sh` | 给用户的 WSL 入口；一条命令编排基线、SSH 别名、安装、注册、连接和验收 |
| `scripts/windows-cloudflare-one.ps1` | Windows 实际执行器；验签安装、路由冲突阻断、浏览器注册、策略等待、Windows/WSL 双侧测试和断开止损 |

脚本内已经写死本需求核实过的非敏感参数：

- Team：`mute-cake-c395`
- 家庭网段：`192.168.5.0/24`
- Mac：`192.168.5.35`，SSH `22`，Home Assistant `8123`
- 路由器：`192.168.5.1:80`
- Split Tunnel 登录端点：`104.19.194.29/32`、`104.19.195.29/32`

没有写入邮箱、验证码、Token、Cookie、密码或私钥内容。

## 4. 明天到公司的唯一主流程

在目标公司电脑的 Ubuntu 24.04 WSL 中执行：

```bash
cd /home/t/projects/work-wsl
git pull --ff-only
bash scripts/windows-cloudflare-one.sh setup
```

`setup` 会按以下顺序自己做完：

1. 把启用 WARP 前的默认路由、非 Cloudflare DNS 和 Clash 进程基线保存到 Windows 本机 `%LOCALAPPDATA%\codex-network\`，不进 Git。
2. 幂等写入 Windows/VS Code Remote-SSH 使用的 `home-mac` 别名。
3. 检查客户端；因为今晚已经安装，正常会显示“Already installed”，不会重复安装，也不会再弹 UAC。
4. 打开浏览器注册 Team `mute-cake-c395`。
5. 等 Cloudflare 下发 `Traffic only + Include + 192.168.5.0/24`；官方允许最长 10 分钟，超时会自动断开 WARP，而不是带着错误策略继续。
6. 自动验证 Windows 和 WSL 的家庭 SSH、Home Assistant、公网、DNS、默认路由与 Clash 状态。

过程中本人只需要做一件事：浏览器出现 Cloudflare 登录页后，用已经加入 `home-lan-owner` 规则的邮箱接收并填写一次验证码，再允许浏览器打开 Cloudflare One Client。不要把验证码或页面中的认证 URL复制到终端、聊天或仓库。

## 5. 怎么看结果

只有脚本末尾同时出现以下关键 `PASS`，才算公司端真正完成：

- `registered-to-team`
- `warp-connected`
- `settings-traffic-only`
- `settings-include-mode`
- `settings-home-cidr`
- 两条 `settings-team-endpoint-*`
- `windows-mac-ssh-login`
- `windows-home-assistant-http`
- `windows-router-http`
- `wsl-mac-ssh-tcp`
- `wsl-home-assistant-http`
- `windows-public-internet`、`windows-public-dns`、`wsl-public-internet`
- `default-routes-unchanged`、`dns-servers-unchanged`、`clash-still-running`

最后再由本人打开一个每天使用的公司内部页面。脚本不知道公司内网系统地址，不能替用户编造该项。这个页面也正常，才把“公司内网未受影响”勾为通过。

## 6. 日常使用

Windows Terminal：

```powershell
ssh home-mac
```

VS Code：安装/启用 Remote - SSH 后，选择 `home-mac`。它读取同一个 `C:\Users\29455\.ssh\config`，不需要再填 IP 或私钥。

浏览器：

- Home Assistant：`http://192.168.5.35:8123/`
- 家庭路由器：`http://192.168.5.1/`

第一阶段不配置私有 DNS，因此统一使用固定 IP；这和前序定稿一致。

## 7. 失败时只做这两步

如果普通网页、公司内网、DNS、Clash 或 WSL 任一异常，先立即执行：

```bash
bash scripts/windows-cloudflare-one.sh disconnect
bash scripts/windows-cloudflare-one.sh doctor
```

然后保留终端输出交给 Codex，不要反复注册、删除设备、切换 Include/Exclude 或编辑旧 `saturate` Tunnel。

两类阻断提示必须照做：

- 提示当前仍在 `192.168.5.0/24`：说明电脑还在家庭网，换到公司网络或手机热点再执行。
- 提示 `Route overlap`：说明公司/其他 VPN 已经占用家庭地址，立即停；不能用调高优先级硬抢路由。

## 8. Git 交付边界

本轮只做本地提交，不推远程。明天能 `git pull` 到这些文件的前提，是用户今晚把本轮提交推到 `origin/main`。推送属于远程 Git 写操作，必须由用户本人执行或另行当次明确授权。

## 9. 官方依据（2026-08-23 核对）

- Stable Windows 客户端与当前版本：<https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/download/>
- Windows MSI 与 `ORGANIZATION` 部署参数：<https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/>
- 当前用户 CLI 注册流程：<https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/manual-deployment/>
- Include 模式、Team Domain 两个固定 IP 与最长 10 分钟下发时间：<https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/route-traffic/split-tunnels/>
