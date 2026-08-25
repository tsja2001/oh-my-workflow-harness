# Cloudflare 家庭私网接入 · Mac 系统服务迁移与公司端最终验收

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：Mac Connector 已迁为 root LaunchDaemon；公司 Windows 自动验收及 WARP 断开/重连恢复全部通过，仅待用户打开一个公司内部网页做人工确认。  
> 下一步：用户确认常用公司内部网页正常；若正常，本专题即可收口，不再改网络配置。

> 本文接续 `20f-公司端注册与首次验收-codex.md`。前文记录首次失败现场，本文记录修复和最终结果，不覆盖前文。

## 1. 最终架构

```text
公司 Windows
  └─ 只有 192.168.5.0/24 进入 CloudflareWARP
       └─ Cloudflare Zero Trust / home-lan Route
            └─ 家里 Mac 的 root cloudflared LaunchDaemon
                 ├─ Mac SSH                  192.168.5.35:22
                 ├─ Home Assistant           192.168.5.35:8123
                 └─ 家庭路由器/其他 LAN 设备 192.168.5.x

公网、公司内网、DNS、Clash：仍走公司电脑原来的路径，不进入家庭 Tunnel。
```

关键点：Mac 现在既是被访问的家庭主机，也是 Cloudflare 流量进入家庭局域网后的“接线员”。将 `cloudflared` 改为系统 LaunchDaemon 后，它可以把流量继续送到路由器等其他家庭设备，并且不依赖 `mac` 用户登录后才启动。

## 2. Mac 实际执行结果

使用 `scripts/macos-cloudflared-launchdaemon.sh` 迁移。首次 `apply` 启动系统服务后，在停掉旧用户服务时当前 SSH 短暂断开；再次执行 `apply` 被脚本的防覆盖保护拒绝，没有覆盖已经运行的系统服务。随后执行 `resume` 完成备份指针和旧服务清理。

最终只读状态：

| 检查项 | 实际结果 |
|---|---|
| 用户 LaunchAgent plist | missing |
| 用户 LaunchAgent 服务 | not loaded |
| 系统 LaunchDaemon plist | present |
| 系统 LaunchDaemon 服务 | loaded |
| cloudflared 进程身份 | root |
| Token 文件 | present、non-empty、权限 `0600`；内容未读取 |
| 当前回退备份 | `/Library/Application Support/codex-cloudflared-migration/backups/20260824-094740` |

迁移没有读取、输出或复制 Token 内容，也没有修改 Tunnel Token、Cloudflare DNS、旧 VLESS/CDN Tunnel、路由器配置或 SSH 密钥。

## 3. 公司 Windows 最终自动验收

最终执行：

```bash
bash scripts/windows-cloudflare-one.sh verify
```

以下 19 项全部 PASS：

| 范围 | 通过项 |
|---|---|
| 注册与策略 | 正确 Team、WARP Connected、Traffic-only、Include mode、家庭 CIDR、两个 Team endpoint |
| Windows → 家庭 | Mac SSH TCP、公钥 SSH 登录、Home Assistant HTTP、路由器 HTTP |
| Windows 非目标流量 | 公网、公共 DNS |
| WSL | Mac SSH TCP、Home Assistant、公网 |
| 原公司电脑环境 | 默认路由未变、DNS 服务器未变、Clash 仍运行 |

实际家庭路由为：`192.168.5.0/24 → 192.0.2.1 → CloudflareWARP`。这只是 WARP 虚拟接口内的下一跳，不是家庭真实网关；家庭真实网关仍是 `192.168.5.1`。

### SSH 红字的真实原因

前两轮验收只有 `windows-mac-ssh-login` 显示 FAIL，但对应输出文件已经包含 Mac 主机名，紧接着用完全相同参数执行 SSH 得到：公钥认证成功、远程 `hostname` 返回 `macdeMac-mini.local`、退出码 0。

根因是 `scripts/windows-cloudflare-one.ps1` 中 Windows PowerShell 5.1 的 `Start-Process` 对象没有预先实例化进程 Handle，导致成功结束后 `ExitCode` 仍为空，被脚本误判为失败。脚本已在 `Test-WindowsSshLogin` 中先访问 `$process.Handle`，修正后同一套完整验收 19 项全部 PASS；SSH 配置、密钥和服务端均未修改。

## 4. 断开与重连恢复测试

已真实执行一次，不是只看按钮状态：

1. `disconnect` 返回成功，客户端状态为 Disconnected。
2. 断开后 Home Assistant `192.168.5.35:8123` 不可达，证明没有走旧 Tailscale 或其他旁路。
3. 同时 Windows 公网仍可访问，证明断开家庭通道不影响普通上网。
4. `connect` 后客户端恢复 Connected。
5. 重连后再次运行完整 `verify`，19 项全部 PASS。

客户端文字状态仍可能短暂显示 `Network: unstable`，但本次 SSH、HTTP、DNS、Windows、WSL 和断开/重连的实际数据面测试均成功。以后判断故障以真实访问和 `verify` 为准，不只看这个状态词。

## 5. 用户只剩一个人工动作

在公司 Windows 上打开一个平时只能在公司的网络中访问、且你每天会用的内部网页：

- 能正常打开：本次配置最终通过。
- 打不开或明显异常：先运行 `bash scripts/windows-cloudflare-one.sh disconnect` 止损，再记录具体网址和报错交给 AI 排查。

脚本不能替你选择公司内部网址，所以这一项不能自动完成。除此之外不要再改 Cloudflare、Clash、DNS、网卡或路由。

## 6. 日常命令与回退

公司 Windows/WSL 日常只需要：

```bash
# 看完整链路是否正常
bash scripts/windows-cloudflare-one.sh verify

# 出现公司网络异常时最快止损
bash scripts/windows-cloudflare-one.sh disconnect

# 恢复家庭私网
bash scripts/windows-cloudflare-one.sh connect
```

Mac 服务只读体检：

```bash
bash scripts/macos-cloudflared-launchdaemon.sh status mac
```

只有系统服务自身出现确认过的故障时才回退，不要因为客户端显示一次 `unstable` 就回退：

```bash
sudo bash scripts/macos-cloudflared-launchdaemon.sh rollback mac
```

回退会读取 Mac 上的备份指针，停止系统 LaunchDaemon，并恢复原用户 LaunchAgent。若公司端已经无法 SSH 到 Mac，需要通过家里的 Mac 远程桌面/本地终端执行；不要删除上述备份目录。
