# Cloudflare 家庭私网接入 · 待提供信息

> 日期：2026-08-21  
> 工具：codex  
> 当前状态：等待用户一次性填写；目前只有“公司批准 Cloudflare One Client”这一项由用户口头确认。  
> 下一步：用户填写 P0 内容并通知 Codex；Codex先做只读侦察，不会拿到信息就直接改网络。

## 0. 填写方法和安全要求

1. 把每个 `【待填写】` 替换成真实答案；不知道就写“未知”，不要按常见值猜。
2. 截图和命令输出统一放在 `docs/需求/17网络/00-补充材料/`，在本文写相对路径。
3. **禁止提供或粘贴**：Cloudflare Tunnel Token、API Token、Cookie、密码、SSH 私钥、VLESS UUID、Clash订阅链接。
4. Cloudflare Dashboard 给出的安装命令通常包含 Tunnel Token：可以直接在 Mac 本机执行，但不要保存到本文、截图或聊天。
5. 截图先遮住无关账号、账单、其他域名和个人信息；保留页面标题、对象名称、状态和 Route 即可。
6. P0 全部填完即可开始；P1 可以在只读侦察阶段继续补。

---

## 1. 公司批准范围（P0，必须）

| 字段 | 用户填写 |
|---|---|
| 确认日期 | 【待填写】 |
| 确认人角色/部门（不用写姓名） | 【待填写】 |
| 批准方式：口头/聊天/邮件/工单 | 【待填写】 |
| 已批准安装并运行 Cloudflare One Client | 已确认（用户 2026-08-21 转述） |
| 是否明确批准 Device-to-Network / WARP 私网路由 | 【待填写：是/否/没有明确说】 |
| 是否明确批准访问整个家庭 CIDR，而不只是 Mac 单机 | 【待填写：是/否/没有明确说】 |
| 是否限制为本人、一台公司电脑 | 【待填写】 |
| 是否规定到期时间、日志或备案要求 | 【待填写】 |
| 批准材料路径（如有） | 【待填写，例如 `00-补充材料/01-公司批准范围.png`】 |

这些都是允许的，没那么多限制，你多虑了

如果对方只说“客户端可以装”，但没说整个家庭网段，可直接补问：

> 我们计划使用 Cloudflare 官方 Device-to-Network 模式：公司电脑的 WARP 只路由我的家庭局域网网段，其他公司内网和互联网流量不走它；家里不能反向访问公司。请确认批准范围是否包含这种整网段私网访问，而不只是安装客户端。

## 2. 家庭网络（P0，必须）

| 字段 | 用户填写 |
|---|---|
| 路由器品牌/型号 | 中兴 |
| 家庭 LAN CIDR，例如 `192.168.50.0/24` |192.168.5.1网段 |
| 家庭网关，例如 `192.168.50.1` | 192.168.5.1 |
| DHCP 地址范围 | 【待填写】 |
| Mac mini 当前局域网 IP | 【待填写】 |
| 是否已给 Mac 做 DHCP Reservation/固定租约 | 【待填写】 |
| 如果网段与公司冲突，是否可以修改家庭网段 | 【待填写：可以/不可以/需要评估】 |
| 是否还有旁路由、第二路由器、VLAN 或访客网络 | 【待填写】 |
| 路由器 LAN/DHCP 页面截图 | 【待填写，例如 `00-补充材料/02-家庭路由器-LAN.png`】 |

注意：家庭公网 IP不需要提供，本方案不开放家庭公网端口。

## 3. Mac mini / 家庭 Connector（P0，必须）

| 字段 | 用户填写 |
|---|---|
| macOS 版本 | 26 |
| Apple Silicon 还是 Intel | M4苹果芯片 |
| Mac 本地用户名（只写用户名，不写密码） | mac |
| 主要联网方式：有线/Wi-Fi | wifi |
| 是否全天开机 | 是 |
| 是否允许睡眠 | 不造啊，好像是会熄屏，但是之前tailscale ssh和todesk都能直接连上 |
| 系统设置中的“远程登录/SSH”是否开启 | 开了 |
| 目前能否从家中另一台设备 `ssh <用户>@<Mac-IP>` | 可用 |
| 是否安装 Homebrew | 是 |
| 是否已经安装 `cloudflared` 或存在相关服务 | 没有 |
| Home Assistant 运行方式：Docker/Home Assistant OS/其他 | docker |
| Home Assistant 局域网 IP和端口 | 默认的吧 |
| 现在是否有办法操作 Mac：人在家/现有 SSH/其他获批方式 | 没有 |

在 Mac 终端执行以下只读命令，将输出保存为 `00-补充材料/03-Mac只读信息.txt`。命令不会修改配置；出现 sudo 密码提示时只在终端输入，密码不会显示，也不要复制出来。

```bash
sw_vers
uname -m
networksetup -listallhardwareports
route -n get default
sudo systemsetup -getremotelogin
pmset -g custom
command -v cloudflared || true
cloudflared --version 2>/dev/null || true
command -v docker || true
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null || true
sudo lsof -nP -iTCP -sTCP:LISTEN
```

命令输出可能包含本地用户名、容器名和内网 IP，可以保留；如果意外出现 Token、密码或公网凭据，先删除那一行再保存。

## 4. 公司 Windows / WARP 使用环境（P0，必须）

| 字段 | 用户填写 |
|---|---|
| Windows 版本 | 11 |
| x64 还是 ARM64 | x64 |
| 当前账号是否有管理员权限 | 是 |
| Cloudflare One Client 是否已安装 | no |
| 若已安装，客户端版本 | 【待填写】 |
| 公司要求从哪个软件源安装 | 没要求 |
| Clash/Mihomo TUN 是否常开 | 是一直开 |
| WSL 是否必须与 WARP 同时正常使用 | 没听懂啊什么意思 |
| 公司内网是否有必须访问的私网段/系统 | 【待填写，不清楚可写“由 AI 只读检测”】 |
| 是否存在其他 VPN/虚拟网卡客户端 | clash |

Windows 路由、网卡、DNS和服务状态由 Codex 在开始配置前从当前 WSL/Windows做只读采集，用户不需要手抄整张路由表。若当前 WSL 不是那台获批公司电脑，请在这里说明：

> 【待填写：当前 WSL 就是目标公司电脑 / 不是，目标电脑需要另行采集】

## 5. Cloudflare Zero Trust（P0，必须）

不造啊，回去我在家用mac 的codex和chrome控制能力让让自己去查吧

| 字段 | 用户填写 |
|---|---|
| Zero Trust Team Name / Team Domain | 【待填写】 |
| 当前套餐 | Zero Trust Free（来自原始需求；请确认仍是）【待填写：是/否】 |
| 域名是否继续使用 `tttthappy1111.org` | 【待填写】 |
| 当前登录身份方式：Cloudflare账号/OTP/Google/GitHub/其他 | 【待填写】 |
| 计划允许注册 WARP 的账号范围 | 【待填写，例如仅本人某一账号；不要写密码】 |
| 现有 Tunnel 名称和状态 | 【待填写】 |
| DNS 快照中既有 Tunnel 的 Connector 在哪台设备 | 【待填写：洛杉矶VPS/其他/未知】 |
| 是否已有 CIDR Route / Virtual Network | 【待填写】 |
| 是否已有 Device Enrollment Rule | 【待填写】 |
| 是否已有 Device Profile / Split Tunnel 自定义 | 【待填写】 |

请提供以下截图，截图中不要包含 Tunnel Token：

| 建议文件名 | Dashboard 页面 | 必须保留的信息 |
|---|---|---|
| `04-Cloudflare-Tunnels.png` | Zero Trust → Networking → Tunnels | Tunnel 名称、类型、状态、Connector 数 |
| `05-Cloudflare-现有Tunnel-Routes.png` | 既有 Tunnel → Routes | Published Applications、CIDR Routes |
| `06-Cloudflare-Network-Routes.png` | Zero Trust → Networking → Routes | CIDR、目标 Tunnel、Virtual Network |
| `07-Cloudflare-DeviceEnrollment.png` | Zero Trust → Devices → Enrollment | 当前规则名称、允许范围 |
| `08-Cloudflare-DeviceProfile.png` | Zero Trust → Devices → Device Profiles | Profile 名称、模式、Split Tunnel 类型 |

## 6. 最小验收目标（P0，必须）

不需要列出家里所有设备，只选三个真实目标证明整条链路：

| 验收目标 | 设备/IP | 端口/协议 | 家中本地是否可用 | 用户填写 |
|---|---|---|---|---|
| Mac SSH | Mac mini | TCP 22 / SSH | 【待填写】 | 【待填写 IP】 |
| Home Assistant | 【待填写】 | 【待填写，例如 TCP 8123/HTTP】 | 【待填写】 | 【待填写 URL或IP:端口】 |
| 另一台 LAN 设备网页/API | 【待填写】 | 【待填写】 | 【待填写】 | 【待填写 URL或IP:端口】 |

可选目标（P1，不阻塞第一轮）：

| 能力 | 是否需要 | 目标/说明 |
|---|---|---|
| VS Code Remote-SSH | 【待填写】 | 默认需要，复用 Mac SSH |
| SMB 文件共享 | 【待填写】 | 【待填写 Mac/其他NAS IP】 |
| 远程桌面/VNC | 【待填写】 | 【待填写；第一轮默认不专项优化】 |
| 私有域名/MagicDNS 类体验 | 【待填写】 | 第一轮默认直接用 IP |
| 手机访问家庭网 | 【待填写】 | 需要时还要批准并注册第二台设备 |

## 7. 执行窗口和回退（P1，可稍后补）

| 字段 | 用户填写 |
|---|---|
| 适合变更的日期/时间 | 【待填写】 |
| 变更时是否有人在家能操作 Mac/路由器 | 【待填写】 |
| 公司电脑网络中断时是否有手机热点备用 | 【待填写】 |
| 是否允许本次验证过程中重启 Mac | 【待填写】 |
| 是否允许安装后重启 Cloudflare One Client | 【待填写】 |
| 出现异常时，是否接受立即断开 WARP并回退 | 默认是；如不同请填写【待填写】 |

## 8. 用户填完后的交接话术

填完后只需回复：

> `10-待提供信息-codex.md` 的 P0 已填写，补充材料已放入 `00-补充材料/`。请先做只读侦察和冲突检查，通过后再给我一次性页面操作清单；不要直接改现有 Tunnel、DNS 或 VLESS。

