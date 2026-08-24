# Cloudflare 家庭私网接入 · 公司端最终测试报告

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：自动化全链路、断开/重连恢复及用户人工公司内网验证全部通过，本专题验收完成。  
> 下一步：保持当前配置日常使用；只有出现真实访问故障时才运行验收或断开止损，不再执行迁移命令。

> 本文接续 `20g-Mac系统服务迁移与公司端最终验收-codex.md`，补记最后一项必须由用户完成的公司内网人工验证。

## 最终结论

**验收通过，可以正常使用。**

当前数据流边界符合设计：

- 家庭 `192.168.5.0/24` 经 CloudflareWARP → Cloudflare Zero Trust → 家里 Mac `cloudflared`。
- 公司内网、公网、DNS 和 Clash 保持原路径，不进入家庭 Tunnel。
- 家里 Mac 的 Connector 由 root LaunchDaemon 开机运行，不再依赖用户登录。

## 验收结果

| 范围 | 结果 | 证据 |
|---|---|---|
| Windows → Mac SSH TCP | 通过 | `windows-mac-ssh-tcp` PASS |
| Windows → Mac 公钥 SSH 登录 | 通过 | `windows-mac-ssh-login` PASS，远程 hostname 成功 |
| Windows → Home Assistant | 通过 | `windows-home-assistant-http` PASS |
| Windows → 家庭路由器 | 通过 | `windows-router-http` PASS |
| WSL → 家庭服务及公网 | 通过 | 三项自动检查 PASS |
| Windows 公网和公共 DNS | 通过 | 两项自动检查 PASS |
| 默认路由、DNS、Clash | 通过 | 与启用前基线一致，Clash保持运行 |
| WARP 断开隔离 | 通过 | 断开后家庭地址不可达，公网保持可达 |
| WARP 重新连接恢复 | 通过 | 重连后完整19项自动检查全部 PASS |
| 公司内部网页 | 通过 | 2026-08-24 用户在公司 Windows 人工确认“公司内网正常” |

## 日常使用边界

正常情况下不需要再运行 `apply` 或 `resume`，也不要调整 Cloudflare、Clash、DNS、网卡或路由。

真实访问异常时先检查：

```bash
bash scripts/windows-cloudflare-one.sh verify
```

如果公司网络受到影响，立即止损：

```bash
bash scripts/windows-cloudflare-one.sh disconnect
```

恢复家庭私网：

```bash
bash scripts/windows-cloudflare-one.sh connect
```

Mac 系统服务的回退备份和操作方法见 `20g-Mac系统服务迁移与公司端最终验收-codex.md`；不要删除备份目录。
