# Cloudflare 家庭私网接入 · Mac 与家庭网络现状侦察

> 日期：2026-08-22  
> 工具：codex  
> 当前状态：Mac 与中兴路由器只读侦察已完成，Cloudflare 控制台因等待用户本人登录而尚未核对。  
> 下一步：用户在已保留的 Chrome Cloudflare 标签页完成登录/MFA；Codex 随后只读核对现有 Tunnel、Routes、Enrollment 与 Device Profile，再实施新增配置。

## 1. 本轮边界

- 已读取本主题全部前序文档，并按 `10-拆解规划-codex.md` 先做只读侦察。
- 已读取 Mac 本机状态和中兴路由器 LAN/DHCP 页面；未点击“提交”，未修改路由器、DNS、现有 Tunnel、VLESS、Clash、Tailscale、Docker 或 macOS 设置。
- 已在 Chrome 打开 `https://dash.cloudflare.com/`，当前停在登录页；未读取、保存或输出密码、Cookie、Token、MFA。

## 2. 已核实事实

| 项目 | 实际值 | 证据 |
|---|---|---|
| 路由器 | 中兴晴天 BE5100 Pro+，固件 `V1.0.0.3B7.8000` | Chrome 中兴管理页首页只读结果 |
| 家庭网关 | `192.168.5.1` | `route -n get default` 与路由器 LAN 页面 |
| 家庭 LAN CIDR | `192.168.5.0/24` | 路由器 LAN IP `192.168.5.1`、掩码 `255.255.255.0` |
| DHCP | 已启用，地址池 `192.168.5.2`–`192.168.5.254`，租期 86400 秒 | 路由器 LAN/DHCP 页面 |
| DHCP 静态绑定 | 当前为空 | 路由器“静态地址绑定”显示暂无数据 |
| Mac 系统 | macOS 15.5（24F74）、Apple Silicon `arm64` | `sw_vers`、`uname -m` |
| Mac 网络 | Wi-Fi `en1`，当前 IP `192.168.5.35/24` | `networksetup -getinfo Wi-Fi` |
| Mac 睡眠 | 交流电下系统睡眠为 0（关闭），显示器 30 分钟休眠；支持网络唤醒和断电后自动启动 | `pmset -g custom` |
| Mac SSH | TCP 22 从回环地址和 `192.168.5.35` 均可连接；由 macOS launchd 按需拉起 | `launchctl print system/com.openssh.sshd`、两次 `nc -vz` |
| macOS 防火墙 | 当前全局关闭 | `socketfilterfw --getglobalstate` |
| cloudflared | 未安装，Homebrew services 中无实例 | `command -v cloudflared`、`brew list --versions cloudflared`、`brew services list` |
| Home Assistant | Docker 容器 `homeassistant` 正在运行，端口 `8123` 发布到所有 IPv4/IPv6 接口 | `docker ps`、`lsof` |
| Home Assistant 本地验证 | `127.0.0.1:8123` 和 `192.168.5.35:8123` 均返回 Home Assistant HTTP 响应；HEAD 为 405 且声明允许 GET，说明服务在线 | 两次 `curl -I --max-time 5` |
| 另一验收网页 | 中兴路由器 `192.168.5.1:80` 可达 | `curl -I --max-time 5` 与当前管理页 |
| 旧远程工具 | 家庭 Mac 当前仍运行 Tailscale 与 ToDesk；本轮未停用 | `ps` 只读结果 |
| 本机网络叠加 | Tailscale、Clash/Mihomo TUN 与 OrbStack 虚拟网段同时存在；家庭 `192.168.5.0/24` 当前走 Wi-Fi `en1`，未与本机 OrbStack 网段重叠 | `netstat -rn -f inet`、进程只读结果 |

## 3. 与旧记录的冲突

1. `10-待提供信息-codex.md` 写“macOS 版本 26”，实机为 macOS 15.5；后续以本机命令为准。
2. 旧记录只知道“192.168.5.1 网段”，本轮已确认掩码为 `/24`，因此计划 CIDR 可以填写 `192.168.5.0/24`。
3. Mac 当前地址 `192.168.5.35` 来自 DHCP，路由器没有固定租约；若直接长期收藏这个 IP，存在续租后漂移风险。
4. 原计划担心系统睡眠导致 Tunnel 离线；本机交流电下系统睡眠已经关闭，当前不需要为了 Connector 修改睡眠设置。

## 4. 实施前仍必须核对

| 未知项 | 为什么还不能猜 | 获取方式 |
|---|---|---|
| Zero Trust Team Name、Free 套餐状态 | 决定公司端注册入口 | 用户登录后从 Cloudflare Dashboard 读取 |
| 现有 Tunnel 名称、Connector 与 Routes | 必须证明新 `home-lan` 不会碰旧 VLESS Tunnel | Dashboard → Networks → Tunnels / Routes |
| Device Enrollment 与 Device Profile | 决定 WARP 登录范围和 Split Tunnel 改法 | Dashboard → Settings / Devices |
| Cloudflare 中是否已有 `192.168.5.0/24` | 重复私网 Route 会导致歧义 | Dashboard Routes 列表 |
| 公司 Windows 路由冲突 | 当前运行环境是家庭 Mac，无法读取目标公司电脑路由 | 家庭端配好后在目标 Windows 上只读采集 |

## 5. 下一步拟执行动作

Cloudflare 只读核对通过后，按以下顺序逐层实施并每层回读：

1. 在路由器把当前 Mac Wi-Fi 设备固定为 `192.168.5.35`，不改 LAN 网段和 DHCP 池。
2. 在 Cloudflare 新建独立 `home-lan` Tunnel；不复用、不编辑现有代理 Tunnel。
3. 为新 Tunnel 添加唯一私网 Route `192.168.5.0/24`，暂用默认 Virtual Network。
4. 在 Mac 安装并以服务方式运行该 Tunnel 的 `cloudflared` Connector；含 Token 的步骤只在本机完成，不写入本文或聊天。
5. 限制 WARP 注册身份并配置只纳入家庭 CIDR的 Split Tunnel。
6. 家庭端验证 Connector、SSH、Home Assistant、路由器网页；异地端到端测试留到公司 Windows 切到非家庭网络后完成。

## 6. 回退基线

- 路由器基线：LAN `192.168.5.1/24`，DHCP `.2`–`.254`，当前无静态绑定。
- Cloudflare 基线：尚待登录后记录；记录完成前不创建 Tunnel/Route。
- Mac 基线：无 `cloudflared` 可执行文件、无对应 Homebrew service；Tailscale/ToDesk/Clash 保持原状。
