# Cloudflare 家庭私网接入 · Cloudflare 现状与配置定稿

> 日期：2026-08-22  
> 工具：codex  
> 当前状态：Cloudflare 只读侦察完成，已证明新 Tunnel 与旧代理 Tunnel 可以完全隔离；待用户对即将发生的 Token、权限和网络设置变更做动作前确认。  
> 下一步：确认后创建 `home-lan`、安装 Connector、添加 `192.168.5.0/24` Route、限制设备注册，并配置最小 Include Split Tunnel。

> 本文补充 `10c-Mac与家庭网络现状侦察-codex.md` 中尚未核实的 Cloudflare 部分，不覆盖此前记录。

## 1. Cloudflare 现状

| 项目 | 实际值 | Dashboard 证据 |
|---|---|---|
| Zero Trust 套餐 | Zero Trust Free，50 席位，当前 0 席位使用 | Settings → Cloudflare One plan |
| Team Name | `mute-cake-c395` | Settings → Team name and domain |
| Team Domain | `mute-cake-c395.cloudflareaccess.com` | Settings → Team name and domain |
| 当前管理员权限 | Super Administrator / All Privileges | Settings → Permission details；具体邮箱不在本文复述 |
| 现有 Tunnel | 仅 `saturate` 一条，类型 cloudflared，Healthy，已运行 46 天 | Networks → Tunnels & Mesh |
| 旧 Tunnel 管理方式 | 本地配置，Dashboard 明确提示不可管理；迁移不可逆 | 点击 `saturate` 后的 Migrate 页面 |
| 现有 CIDR Route | 0 条 | Networks → Routes → CIDR routes 显示 No results |
| Virtual Network | 仅自动生成的 `default` | Networks → Routes → Virtual networks |
| 已注册设备 | 0 台 | Team & Resources → Devices；套餐席位也为 0/50 |
| 注册策略 | 无关联策略；默认可用 One-time PIN，但没有策略时设备不能注册 | Devices → Management → Enrollment |
| Device Profile | 仅 `Default` 一条，启用 | Devices → Device profiles |
| 默认客户端协议 | MASQUE | Default Profile → Device tunnel protocol |
| 默认 Service mode | Traffic and DNS | Default Profile → Service mode |
| 默认 Split Tunnel | Exclude IPs and domains，共 16 条默认排除项 | Default Profile → Split Tunnels |
| 与家庭网段直接冲突 | 默认排除了 `192.168.0.0/16`，包含家庭 `192.168.5.0/24` | Split Tunnel exclude 表格 |

## 2. 旧代理 Tunnel 隔离结论

`saturate` 的 ID 与 DNS 快照中所有旧 CNAME 指向的 Tunnel ID一致，且 Dashboard 说明它由远端主机的本地配置文件管理。因此本需求：

- 不点击 `Start migration`。
- 不编辑、不迁移、不重启 `saturate`。
- 新建独立、Dashboard 管理的 `home-lan`。
- 新家庭 CIDR Route只指向 `home-lan`；不为家庭私网创建公网 Hostname/DNS记录。

这样不会修改 `cdn.tttthappy1111.org`、根域名、`www` 或现有 VLESS入口。

## 3. 配置定稿

| 配置项 | 定稿值 | 理由 |
|---|---|---|
| Tunnel | 新建 `home-lan` / cloudflared | 与旧代理完全隔离 |
| Connector | 家庭 Mac mini | 全天开机、系统睡眠已关闭 |
| CIDR Route | `192.168.5.0/24` → `home-lan` → `default` | 家庭真实 LAN；当前 Cloudflare无重复 Route |
| WARP Service mode | **Traffic only** | 只接管 IP路由，DNS继续由公司系统/Clash管理，降低与公司内网、WSL、Clash TUN的冲突面 |
| Tunnel protocol | MASQUE | 保持现有默认，走标准 HTTPS兼容性更好 |
| Split Tunnel mode | **Include IPs and domains** | Cloudflare官方把“只访问特定私网”列为 Include模式典型场景 |
| Include 项 1 | `192.168.5.0/24` | 只有家庭网段进入 WARP |
| Include 项 2 | `104.19.194.29/32` | Traffic-only Include模式下的 Team Domain 官方固定地址之一 |
| Include 项 3 | `104.19.195.29/32` | Traffic-only Include模式下的 Team Domain 官方固定地址之一 |
| Enrollment | 仅当前用户的一个真实邮箱，One-time PIN | Free计划无需新增 IdP；限制注册范围 |
| 客户端开关 | 允许用户断开、允许离开组织 | 初期验证保留快速回退能力 |
| Gateway内容检查 | 第一阶段不启用 | 本需求只需路由；避免公司其他流量和证书配置被接管 |
| 私有 DNS | 第一阶段不配 | 直接用固定家庭 IP，排除 DNS变量 |

## 4. 为什么不继续用默认 Exclude 模式

默认 Exclude模式会把除 16 个排除段外的大部分流量交给 WARP。要只放行家庭 `/24`，必须删除 `192.168.0.0/16` 后再手工补回大量剩余网段，配置复杂且更容易误接管公司/家庭本地资源。

Include模式只需声明家庭 `/24` 和 Cloudflare团队登录地址，其余流量全部绕过 WARP，更符合“只代理家庭网段、普通办公不变”的目标。

Cloudflare官方依据：

- [Split Tunnels](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/route-traffic/split-tunnels/)：Include模式只把显式 IP/域名送入 Cloudflare；Traffic-only模式下用官方 Team Domain IP。
- [Connect an IP/CIDR](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/cloudflared/connect-cidr/)：私网 Route与客户端 Split Tunnel必须同时配置。
- [Cloudflare One Client with legacy VPNs](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/vpn/)：Traffic-only只控制 IP路由、不接管 DNS，适合与既有 VPN/隧道共存。
- [Device enrollment permissions](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/device-enrollment/)：至少一条注册策略，并可用 One-time PIN限制到特定邮箱。

## 5. 动作前确认范围

下一步会发生四类持久变更：

1. Cloudflare创建 `home-lan`，由此生成 Connector持久 Token；Token只在浏览器与本机进程之间使用，不写入项目、文档或聊天。
2. Cloudflare新增 `192.168.5.0/24` CIDR Route并修改 Default Device Profile为上表最小 Include配置。
3. Cloudflare创建仅允许当前用户邮箱的 Device Enrollment策略；这会把该邮箱作为身份规则提交给 Cloudflare。
4. 中兴路由器新增一条 DHCP静态绑定，把 Mac Wi-Fi设备固定到 `192.168.5.35`；不改 LAN、DHCP池、DNS或网关。

根据浏览器动作安全要求，执行这些最终提交前需要用户在当前会话明确确认一次。
