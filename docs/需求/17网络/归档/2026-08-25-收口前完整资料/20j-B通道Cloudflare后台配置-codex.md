# B通道 Cloudflare 后台配置执行记录

> 日期：2026-08-24
> 工具：codex
> 当前状态：`home-mac-ssh` Access 应用、仅本人 Allow 策略、`home-lan → ssh://localhost:22` 发布路由和自动 DNS 已创建并逐项回查；既有 A 通道保持正常。
> 下一步：明天在公司 Windows 和 WSL 分别运行一次 `ssh home-mac-access`，完成公司网络、现有客户端密钥和长连接验收。

> 本文接续 `10i-B通道今晚家庭端与明日公司端收口计划-codex.md` 和 `20i-B通道AccessSSH预配置与测试准备-codex.md`，只记录 2026-08-24 家庭端实际执行结果，不覆盖前文。

## 1. 执行前核查

通过 Cloudflare 页面实际回查：

- Access Applications 列表为空，说明公司端尚未创建 B 通道应用。
- `home-lan` Tunnel 状态为 `Healthy`。
- `home-lan` 原 CIDR Route 为 `192.168.5.0/24`。
- 旧 `saturate` Tunnel 状态为 `Healthy`，本轮未进入其配置页。

因此按既定顺序先建立 Access 保护，再发布 SSH 路由，避免先暴露未受保护的主机名。

## 2. Access 应用和策略

已创建 Self-hosted 应用：

| 项目 | 实际值 |
|---|---|
| 应用名 | `home-mac-ssh` |
| Public hostname | `ssh-home.tttthappy1111.org` |
| Path | 留空 |
| Browser rendering | Off |
| Session Duration | `24 hours` |

已创建并关联策略：

| 项目 | 实际值 |
|---|---|
| 策略名 | `allow-owner-only` |
| Action | `Allow` |
| Include | `Emails`，值为当前 Cloudflare 登录账号 |
| 规则数量 | 1 |
| Everyone / Bypass | 均未配置 |

页面回查显示应用、主机名和策略三列分别为 `home-mac-ssh`、`ssh-home.tttthappy1111.org`、`allow-owner-only`。账号值未抄入本文，未读取或保存 Cookie、OTP、Token、密码和私钥。

## 3. Tunnel 发布路由

在既有 `home-lan` Tunnel 的 Published application routes 中新增：

| 项目 | 实际值 |
|---|---|
| Hostname | `ssh-home.tttthappy1111.org` |
| Path | 留空；列表显示 `*` |
| Service type | `SSH` |
| Origin URL | `localhost:22` |
| 列表回显 | `ssh://localhost:22` |
| Origin advanced settings | 默认值，未展开修改 |

保存后首次返回列表曾短暂显示空表；等待并刷新后稳定显示 1 条上述路由。Cloudflare DNS 页面随后实际显示：

```text
ssh-home.tttthappy1111.org  Tunnel  home-lan  Proxied  Auto
```

该记录由 Published application 自动生成，没有手工猜写 Tunnel UUID 或 CNAME 目标。

## 4. 无损回查

配置后再次从页面核实：

- `home-lan` 仍为 `Healthy`。
- `192.168.5.0/24` CIDR Route 仍存在。
- SSH Published application route 单独新增，未替换 CIDR Route。
- `saturate`、`cdn.tttthappy1111.org`、WARP、Device Profile、Enrollment、Clash 和 Mac LaunchDaemon 均未修改。

本轮没有删除对象、重建 Tunnel、重启 Connector、生成新 Token或改动远程 Git。

## 5. 回退边界

若明天公司端确认 B 通道不可用或体验无收益，最小回退对象仅有：

1. `home-lan` 下的 `ssh-home.tttthappy1111.org → ssh://localhost:22` Published application route；
2. `home-mac-ssh` Access 应用及其独立策略。

不要删除 `home-lan`、Connector、`192.168.5.0/24` CIDR Route、Device Profile、Enrollment、`saturate` 或旧 DNS。当前尚未执行回退。
