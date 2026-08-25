# Cloudflare 家庭私网接入 · Windows 预配置测试报告

> 日期：2026-08-23
> 工具：codex
> 当前状态：Windows 安装与预配置通过，端到端结论仍为“待公司网络验收”。
> 下一步：明天运行 `bash scripts/windows-cloudflare-one.sh setup`，以脚本全 PASS 加一个公司内部页面实测作为最终通过标准。

> 本文接续 `30b-家庭端最终复验-codex.md`，新增 Windows 预配置证据；不把家庭 Wi-Fi 下的直连结果冒充异地数据面结果。

## 1. 用例结果

| 编号 | 测试项 | 结果 | 证据/说明 |
|---|---|---|---|
| W01 | Mac 标准 SSH 配置解析 | 通过 | `work-windows-lan` 解析到 `192.168.5.88:2222`、Windows 当前用户 |
| W02 | Mac → Windows SSH 实连 | 通过 | 一次连接成功，返回 Windows NT `10.0.26200.0` 与目标主机 |
| W03 | Windows 管理权限 | 通过 | SSH 会话 PowerShell `IsAdmin=True` |
| W04 | Windows/WSL 基线 | 通过 | Windows 11 build 26200、AMD64、Ubuntu 24.04 WSL2 可用 |
| W05 | Clash/Mihomo 共存基线 | 通过 | 安装前后均检测到 Clash Party 与 Mihomo 进程 |
| W06 | 官方 MSI 下载 | 通过 | 固定 GA 地址下载成功，文件大于 10 MB |
| W07 | 安装包签名 | 通过 | Authenticode `Valid`，Signer 为 `Cloudflare, Inc.` |
| W08 | 客户端安装 | 通过 | `Cloudflare One Client 26.7.1343.0` |
| W09 | Windows 服务 | 通过 | `CloudflareWARP` 为 Running |
| W10 | 组织预填 | 通过 | `warp-cli settings` 为 local policy Organization `mute-cake-c395` |
| W11 | 未提前注册/接管 | 通过 | Registration Missing；有效家庭路由仍是 WLAN `192.168.5.0/24` |
| W12 | Windows SSH 别名写入 | 通过 | `home-mac` / `Macmini-Home` 指向 `192.168.5.35:22`，复用既有专用 IdentityFile |
| W13 | SSH 配置回退点 | 通过 | 原配置备份到 `config.codex-before-cloudflare` |
| W14 | Windows → Mac 免密登录 | 未通过 | 本次嵌套验证超时；精确停止挂起测试，未重试；明日由 20 秒硬超时用例重验 |
| W15 | Mac → WSL ProxyJump | 未通过 | 连接被关闭；按用户要求未重试；明日改由 Windows 本机 WSL 验收 |
| W16 | Bash 入口语法 | 通过 | `bash -n scripts/windows-cloudflare-one.sh` exit 0 |
| W17 | PowerShell 脚本解析/Doctor | 通过 | 目标 Windows PowerShell 完整载入并执行 Doctor，无解析错误 |
| W18 | Git 差异格式 | 通过 | `git diff --check` exit 0 |
| W19 | ShellCheck | 未执行 | 当前 Mac 未安装 `shellcheck`；已有 Bash 内建语法检查与 Windows 实机执行证据 |
| W20 | 公司网络设备注册与 WARP | 待执行 | 不能在家庭 Wi-Fi 验收 |
| W21 | 公司网络 SSH/HA/路由器 | 待执行 | 由明日 `setup` 自动测 |
| W22 | 公司公网/内网/DNS/Clash/WSL | 待执行 | 自动项由脚本测，公司内部页面由用户最后打开一次 |

## 2. 当前判定

- 家庭端与 Cloudflare 控制面：沿用 `30b`，通过。
- Windows 客户端安装与组织预配置：通过。
- Windows SSH 登录凭据：已有配置和密钥落点，但实际登录尚未得到成功证据，不能写“通过”。
- 完整家庭 ↔ 公司链路：尚未通过，必须等公司网络数据面测试。

## 3. 明日最终判定规则

1. `setup` 退出码为 0，所有自动检查为 PASS。
2. `ssh home-mac` 确实登录到家庭 Mac，不只是 TCP 22 可连。
3. Windows 与 WSL 都能访问 Home Assistant。
4. 普通公网、DNS、默认路由与 Clash 保持基线。
5. 用户打开一个真实公司内部页面成功。
6. 任一项失败即保持“未通过”；先 `disconnect`，不带病继续。
