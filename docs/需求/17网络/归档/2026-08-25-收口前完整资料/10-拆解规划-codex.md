# Cloudflare 家庭私网接入 · 任务拆解计划文档

> 日期：2026-08-21  
> 工具：codex  
> 当前状态：已确定采用“Cloudflare One Client（WARP）+ 新建家庭 Tunnel + 整个家庭 CIDR 私网路由”；用户已口头说明公司批准该客户端，尚未开始任何配置。  
> 下一步：用户填写 `10-待提供信息-codex.md`；Codex 核对网段、现有 Cloudflare 配置和客户端冲突后，才进入实际配置阶段。

> **本文档的定位**：整合并取代本需求此前聊天中的方案讨论，作为后续实施的唯一主计划；不覆盖用户原始输入 `01需求-方案.md`、DNS 快照和 `16安全` 下的历史调查证据。  
> 第一部分写给用户，第二部分写给后续执行配置的 AI。任何聊天结论变化，都要回写本文档，不能靠会话记忆继续做。

## ⭐ 执行进度

**已完成：**

1. ✅ 用户于 2026-08-21 明确表示公司已批准 Cloudflare One Client；这是用户转述，批准的精确范围仍待补入信息清单。
2. ✅ 已确认目标不是逐个发布公网子域名，而是让一台公司电脑通过 WARP 访问整个家庭网段的可路由 TCP/UDP 服务。
3. ✅ 已核对 DNS 快照：`cdn`、根域名、`www` 等记录当前共用一条既有 Cloudflare Tunnel；本需求不得改动该 Tunnel 和现有 VLESS 节点，证据见 `tttthappy1111.org-DNS.txt:33-39`。
4. ✅ 已确认 Cloudflare 官方支持 Device-to-Network：在家庭 Tunnel 上发布一个 IP/CIDR，公司端 One Client 登录后可直接访问家庭私网 IP。
5. ✅ 用户已部分回填 Mac/Windows/家庭网络信息，并确定晚上在 Mac本地接手；具体交接、浏览器方式和异地验证条件见 `10b-Mac本地执行准备-codex.md`。

**需要用户做的：**

1. 一次性填写 `10-待提供信息-codex.md` 中标为“必须”的内容。
2. 将截图或命令输出放入 `docs/需求/17网络/00-补充材料/`；不得放 Token、密码、Cookie、私钥或完整安装命令中的 Tunnel Token。

**现在做不到的：** 尚不能创建 Tunnel、填写 CIDR、调整 WARP Split Tunnel 或安装服务，因为家庭网段、Mac 固定 IP、Zero Trust Team Name、现有 Tunnel 归属和批准范围还未核实。

---

# 第一部分：写给用户看的

## 1. 这个需求到底是做什么

把 Cloudflare 当成一个“获批的中转路由器”：公司电脑只要开启 Cloudflare One Client，就能像以前用 Tailscale 子网路由一样，直接访问家里 Mac 和其他局域网设备的 IP、SSH、网页、Home Assistant、API 等服务，不再给每个端口单独建公网域名。

目标链路：

```text
公司 Windows 电脑
  └─ Cloudflare One Client（WARP，只接管家庭网段）
       └─ Cloudflare Zero Trust
            └─ 家庭 Mac mini 上的新 cloudflared Tunnel
                 ├─ Mac mini 的局域网 IP 和可监听端口
                 ├─ Home Assistant / Docker 已发布端口
                 └─ 家庭网段内其他设备的可路由 TCP/UDP 服务
```

这不是二层局域网复制：SSH、HTTP、HTTPS、SMB、数据库等基于 IP 的服务可以访问；Bonjour、AirDrop、mDNS、广播自动发现通常不能直接跨越这条路由，初期统一使用固定 IP。

## 2. 需求逐条翻译

| 用户原话/已确认口径 | 大白话翻译 | 谁来做 |
|---|---|---|
| 公司批准那个客户端 | 公司电脑允许安装并运行 Cloudflare One Client；仍需记录批准是否覆盖“整个家庭 CIDR” | 用户提供批准范围；AI据此设边界 |
| 像 Tailscale 一样代理整个家庭网络 | 在 Cloudflare Tunnel 上新增家庭网段 CIDR Route，不逐个发布公网 Hostname | AI规划和配置；用户完成管理页面点击 |
| 包括 Mac 上所有端口 | WARP 将发往 Mac 局域网 IP 的流量送入 Tunnel；能否连上仍取决于服务监听地址和 macOS 防火墙 | AI检查；用户提供 Mac 当前状态 |
| 包括局域网所有 IP | 发布家庭 LAN 的 `/24` 等真实网段，访问其他设备时直接使用内网 IP | AI配置与验证 |
| 访问 SSH、VS Code、网页、Home Assistant、API | 先验证 Mac SSH、HA 和一台其他 LAN 设备；VS Code 复用普通 SSH，不再使用逐主机 `ProxyCommand` | AI配置和测试 |
| 不影响现有 CDN/VLESS | 新建独立 Tunnel；禁止改现有 Tunnel、`cdn` DNS、Clash 配置、洛杉矶 VPS 和腾讯云 VPS | AI遵守禁改区 |
| 方便优先 | 第一阶段不做逐 IP、逐端口 Access Application；只把设备注册权限限制为本人账号和批准的公司电脑 | AI拍板；用户可否决 |

## 3. 当前已核实的事实与未知项

### 3.1 已核实

| 事实 | 证据 |
|---|---|
| 域名由 Cloudflare NS 托管 | `tttthappy1111.org-DNS.txt:27-31` |
| 现有多个域名记录指向同一个 `cfargotunnel.com` Tunnel | `tttthappy1111.org-DNS.txt:33-39` |
| 当前 Clash 配置使用 `cdn.tttthappy1111.org:443` 的 VLESS/WebSocket/TLS 节点 | `/home/t/projects/personal/05clash/订阅备份/26-08-21修改cdn为主要方案后备份.yaml:68-76`（仅核对非密钥字段） |
| Cloudflare 官方支持向 Tunnel 添加整个 IP/CIDR | <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/cloudflared/connect-cidr/> |
| Device-to-Network 需要家庭 `cloudflared` 和公司 Cloudflare One Client | <https://developers.cloudflare.com/cloudflare-one/setup/replace-vpn/device-to-network/> |
| WARP 默认排除 RFC1918 私网，需要正确调整 Split Tunnel 才能送入家庭 Tunnel | <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/cloudflared/connect-cidr/> |

### 3.2 仍未知，禁止猜

1. 公司批准的是“允许安装客户端”，还是同时批准“公司电脑访问整个家庭网段”。
2. 家庭真实 CIDR、网关、DHCP 范围、Mac 固定 IP，以及是否与公司/WSL/Docker/Clash 路由重叠。
3. 现有 Cloudflare Tunnel 的名称、Connector 所在设备和 Dashboard 中的实际 Routes。
4. Zero Trust Team Name、身份提供方、设备注册规则和当前 Device Profile。
5. Mac 是否全天在线、是否睡眠、SSH 是否开启、服务是否监听在局域网地址、Docker 端口是否发布。
6. 公司电脑上的 WARP 与 Clash/Mihomo TUN、WSL、公司内网是否会发生路由或虚拟网卡冲突。

## 4. 实施边界

### 4.1 本期范围

- 一名用户、一台获批的公司 Windows 电脑。
- 一个家庭局域网，一个新建的 `home-lan` Cloudflare Tunnel。
- 一个真实家庭 CIDR；初期通过固定 IP 使用服务。
- Mac SSH、VS Code Remote-SSH、Mac/Docker 网页、Home Assistant/API，以及家庭网段内其他可路由 TCP/UDP 服务。
- 公司电脑只把家庭 CIDR 送入 WARP；普通互联网、公司内网和其他流量保持原路径。
- 完成开机自启、断线恢复、验证清单和可复制回退步骤。

### 4.2 明确不做

- 不改现有 VLESS、Clash、`cdn.tttthappy1111.org`、既有 Tunnel 或 VPS。
- 不把家庭网络配置成公司互联网出口，不开 Exit Node，不提供 HTTP/SOCKS 通用代理。
- 不发布公司网段，不允许家庭设备通过本方案主动访问公司网络。
- 不把客户环境接入家庭 Tunnel；客户环境必须单独取得客户与公司双方授权。
- 不承诺 AirDrop、Bonjour、mDNS、局域网广播或二层发现能力。
- 不在第一阶段配置私有 DNS、逐应用 Access、远程桌面优化或高可用第二 Connector。
- 不把规避态势感知、隐藏客户端或协议伪装作为目标；按公司已批准的产品和范围实施。

## 5. 分阶段推进

| 阶段 | AI负责 | 用户负责 | 通过标准 | 失败处理 |
|---|---|---|---|---|
| 0. 信息回收 | 审核补充材料、标出缺口 | 填信息清单、提供截图/输出 | 所有 P0 字段有真实值 | 未齐不写配置 |
| 1. 只读侦察 | 检查 Windows/WSL 路由、虚拟网卡、现有 Cloudflare/DNS、Mac 网络和监听 | 在需要登录的页面打开对应位置 | 家庭 CIDR无冲突，现有 Tunnel 可明确隔离 | 冲突先改方案，不试错 |
| 2. Cloudflare 控制面 | 给出逐字段配置值和检查点 | 按清单在 Zero Trust 页面创建新 Tunnel/Route | 新 Tunnel 独立，旧 Tunnel/路由未变 | 删除新 Route/Tunnel，旧配置不动 |
| 3. 家庭 Connector | 准备安装、开机自启和日志检查命令 | 若 AI 无现成到 Mac 的通道，在 Mac 终端执行一次 | Connector Healthy，重启后自动上线 | 停止新服务并保留日志 |
| 4. 公司 WARP | 配置单用户注册和只含家庭 CIDR 的路由 | 完成客户端登录/MFA | WARP Connected，普通网络不受影响 | 断开 WARP并恢复 Profile |
| 5. 最小验证 | 依次测 Mac SSH、HA、另一台 LAN 设备、VS Code、重连 | 配合在家确认目标设备在线 | 测试矩阵全部通过 | 单项失败即停在对应层排查 |
| 6. 收尾交接 | 写 `20-部署执行-codex.md`、回退和运维说明 | 收藏文档，确认批准范围未变化 | 可关闭、可恢复、可复测 | 按回退步骤撤销本需求新增项 |

## 6. 你需要知道的几个概念

- **Tunnel CIDR Route**：告诉 Cloudflare“去这个家庭网段的包交给哪台家庭 Connector”，类似 Tailscale 的 Subnet Router。
- **Cloudflare One Client / WARP**：公司电脑上的入口客户端；只有它登录到你的 Zero Trust Team 后，私网 IP 才能走 Tunnel。
- **Split Tunnel**：路由分流清单。本需求只让家庭 CIDR 进 WARP，其余流量不接管。
- **服务监听地址**：服务若只监听 `127.0.0.1`，只能由 Mac 自己访问；要通过 Mac 局域网 IP 访问，通常需监听该 IP 或 `0.0.0.0`。
- **网段重叠**：公司和家里同时使用 `192.168.1.0/24` 时，同一个 IP 可能代表两台不同设备，路由无法可靠判断目的地。

## 7. 用户行动清单

1. 填完 `10-待提供信息-codex.md` 的 P0 部分。
2. 截图按建议文件名放进 `00-补充材料/`，先遮住 Token、账号编号、Cookie 和个人无关信息。
3. 告诉 Codex“信息已填完，可以开始只读侦察”。
4. 侦察通过后，Codex 会把所有 Cloudflare 页面点击集中成一份清单，不在过程中零碎叫用户操作。

---

# 第二部分：给执行配置 AI 的计划

## 0. 总体纪律

1. 当前阶段只允许写文档；用户补齐信息并明确开始配置后，才能修改 Cloudflare、Mac 或 Windows。
2. 现有 VLESS Tunnel、DNS、Clash/VLESS 配置、两个 VPS均为禁改区。
3. Tunnel Token、API Token、Cookie、SSH 私钥和密码禁止进入聊天、命令记录和主题文档；如确需凭据，只能由用户写入 `ai-docs/creds.env`。
4. 所有外部写操作前先记录旧值或截图；只新增独立对象，不复用既有 Tunnel。
5. 一次只改变一层：Cloudflare Route → 家庭 Connector → WARP Profile → 目标服务；每层验证通过再继续。
6. 初次验证只测已声明的家庭设备，不扫描整个 `/24`，不做端口全扫。

## 1. 配置落点

| 位置 | 计划动作 | 验证 | 回退 |
|---|---|---|---|
| Cloudflare Zero Trust / Networking / Tunnels | 新建 `home-lan` Tunnel | Connector Healthy；旧 Tunnel 状态/Routes 不变 | 停止新 Connector，删除本需求新增 Route/Tunnel |
| Cloudflare Zero Trust / Networking / Routes | 添加真实家庭 CIDR | Route 指向 `home-lan` | 只删除新增 CIDR Route |
| Cloudflare Zero Trust / Devices / Enrollment | 仅允许本人获批账号注册 | 仅目标公司电脑出现在设备列表 | 撤销该设备或关闭新增规则 |
| Cloudflare Device Profile / Split Tunnels | 仅让家庭 CIDR进入 WARP | 家庭 IP走 WARP；其他流量路径不变 | 恢复前置截图中的旧 Profile |
| 家庭 Mac mini | 安装 `cloudflared` 服务并开机自启 | 进程、服务、Tunnel Healthy；重启后恢复 | 停止并卸载本需求服务，不删除其他配置 |
| 公司 Windows | 安装/登录 Cloudflare One Client | Connected；WSL/Clash/公司内网正常 | Disconnect/Logout，必要时卸载新客户端 |

## 2. 开工侦察

### 2.1 Cloudflare

- 核对 Account、Zone、Zero Trust Team Name。
- 从 Dashboard 核对既有 Tunnel 名称、Connector、Routes；不能只凭 DNS CNAME 推断运行位置。
- 导出或截图 Tunnel、Routes、Device Enrollment、Device Profile/Split Tunnel 旧值。
- 确认没有与计划家庭 CIDR 重复的 Route；有重复时先确定是否使用不同 Virtual Network 或更换家庭网段。

### 2.2 家庭网络与 Mac

- 核对家庭 CIDR、网关、DHCP 范围、Mac DHCP Reservation。
- 核对 Mac 架构、macOS、默认网卡、睡眠策略、SSH Remote Login、macOS 防火墙。
- 核对 `cloudflared` 是否已安装或已有服务，禁止覆盖不明实例。
- 核对 SSH、Home Assistant、Docker 及验收网页的真实监听地址和端口。
- 若某服务只监听 `127.0.0.1`，单独记录；不为了“所有端口”盲目改成 `0.0.0.0`。

### 2.3 公司 Windows / WSL / Clash

- 记录 IPv4 路由表、DNS、虚拟网卡、公司内网网段和当前默认路由。
- 核对 Cloudflare One Client 安装状态和版本。
- 核对 Clash/Mihomo TUN 是否运行；WARP 接管后测试其与 WSL NAT、Clash 显式代理和公司内网的共存。
- 若家庭 CIDR与公司、WSL、Docker、VPN 或其他虚拟网卡重叠，停止实施并先处理网段。

## 3. 计划配置值

| 参数 | 计划值 | 状态 |
|---|---|---|
| Tunnel 名称 | `home-lan` | 自行拍板，可由用户改名 |
| Route 类型 | Tunnel CIDR | 已确定 |
| 家庭 CIDR | `＿＿＿＿/＿＿` | 待用户提供，禁止猜 |
| Virtual Network | `default` | 暂定；有重叠 Route 时重新决定 |
| 公司端模式 | Cloudflare One Client，Traffic and DNS | 待核对当前 Profile |
| Split Tunnel | 只纳入真实家庭 CIDR | 已确定目标；具体 Exclude/Include 配法待核当前模式 |
| 身份范围 | 仅本人获批账号 | 待用户提供 Team/IdP 信息 |
| 设备范围 | 初期仅一台公司电脑 | 已确定 |
| 私有 DNS | 第一阶段不配，直接用固定 IP | 自行拍板 |
| 按应用 Access | 第一阶段不配 | 自行拍板；公司批准范围若要求则补 |
| Connector 主机 | 家庭 Mac mini | 待确认全天在线与架构 |
| 高可用副本 | 第一阶段不配 | 自行拍板 |

## 4. 验收矩阵

| # | 验收项 | 方法 | 通过标准 |
|---:|---|---|---|
| 1 | 旧业务无影响 | 对比既有 Tunnel/Routes/DNS，验证现有 CDN 节点按原方式工作 | 旧配置无差异，现有节点可用 |
| 2 | 家庭 Connector | Dashboard + Mac 服务状态 | Tunnel Healthy，Mac 重启后自动恢复 |
| 3 | 路由范围 | 公司端查看路由并访问已知家庭 IP | 只有家庭 CIDR进入 WARP |
| 4 | Mac SSH | `ssh <user>@<mac-lan-ip>` | 密钥登录成功，命令返回正确主机 |
| 5 | VS Code | Remote-SSH 连接同一 IP | 能打开一个测试目录并运行终端 |
| 6 | Home Assistant | 浏览器访问 `<ha-ip>:<port>` | 登录页、前端加载和 WebSocket 状态正常 |
| 7 | 其他 LAN 设备 | 访问用户指定的一台设备/端口 | 与家中本地访问结果一致 |
| 8 | Docker 服务 | 访问一个已发布端口 | 可连接；未发布/仅 localhost 端口保持不可达 |
| 9 | 非目标流量 | 公司内网、普通网页、WSL、Clash 显式代理各测一次 | 不因 WARP 路由变化中断 |
| 10 | 断线恢复 | WARP重连、Mac服务重启各一次 | 无需重新建 Tunnel/Route即可恢复 |

不以 `ping`、Dashboard 显示 Healthy、客户端显示 Connected 中的任意一项单独作为最终成功；必须至少完成 SSH、HA/网页、另一台 LAN 设备和非目标流量四类端到端验证。

## 5. 回退原则

出现公司内网中断、Clash/WSL大面积异常、未知 Route 被改、旧 Tunnel受影响或身份范围超出预期时立即停止：

1. 公司端先 Disconnect Cloudflare One Client，恢复办公网络。
2. Cloudflare 只撤销本需求新增的家庭 CIDR Route。
3. 停止 Mac 上本需求新装的 `cloudflared` 服务。
4. 对照实施前截图复核旧 Tunnel、Routes、DNS、Device Profile未变化。
5. 保留日志和失败时间，不通过删日志或继续叠加配置“试出来”。

精确命令和对象 ID 必须等实际对象创建后写入 `20-部署执行-codex.md`，当前不编造占位 ID。

## 6. 自行拍板记录

| 决定 | 理由 | 猜错的返工代价 |
|---|---|---|
| 使用新 Tunnel `home-lan` | 与现有代理 Tunnel彻底隔离，回退清楚 | 很低，只改新对象名称 |
| 首期发布整个家庭 CIDR | 满足用户“像 Tailscale、方便优先”的明确要求 | 中；若批准范围不含整网，需改成单主机 `/32` 或按应用入口 |
| 首期不用公网 Hostname | 私网 IP已覆盖 SSH/网页/API，避免逐端口配置 | 低；以后可按需新增 |
| 首期不用私有 DNS | 先排除 DNS 变量，固定 IP最容易验收 | 低；验证后再加名称解析 |
| 首期不做逐端口策略 | 只有一名用户和一台获批设备，先实现主要体验 | 中；设备注册范围扩大前必须补策略 |
| 不使用家庭公网 IP和两个 VPS | Cloudflare Tunnel只需出站连接，额外中转增加故障点 | 低 |
| 不接客户环境 | 客户资产需要独立授权和边界，不能混进家庭 Route | 无；后续另立需求 |

## 7. 主要风险

| 风险 | 影响 | 预防/处置 |
|---|---|---|
| 批准只覆盖客户端安装、不覆盖家庭整网 | 方案超出批准范围 | 用户补精确批准口径；不清楚时先只规划不配置 |
| 家庭与公司网段重叠 | 访问错误设备或完全不通 | 开工前同时核两侧路由；必要时更换家庭 LAN 网段 |
| WARP 与 Clash/Mihomo TUN冲突 | 公司网络、WSL或代理中断 | 记录旧路由；只纳入家庭 CIDR；先小范围验证，失败即断开 WARP |
| Mac 睡眠/断电 | 整个家庭 Tunnel离线 | 固定供电、合理睡眠策略、开机自启；以后可加第二 Connector |
| 服务只监听 localhost | “Mac所有端口”实际上不可达 | 按服务核监听；只改明确需要的服务，不全局放开 |
| 家庭设备 IP漂移 | 收藏的 IP和路由目标失效 | 路由器做 DHCP Reservation |
| Cloudflare Free 日志短、无 SLA | 长期审计与可用性有限 | 按公司要求决定是否保留本地日志或升级；当前先做单人验证 |
| WARP不是二层组网 | mDNS/AirDrop/广播发现不可用 | 使用固定 IP；需要名称时再配私有 DNS |

## 8. 后续交付物

完成实施后必须新增而不是覆盖：

1. `20-部署执行-codex.md`：真实对象、页面配置、命令、前后状态、失败记录。
2. `20-回退与恢复-codex.md`：断开、停止、移除新增 Route、重新启用的可复制步骤。
3. `30-测试报告-codex.md`：按第 4 节矩阵记录原始结果与结论。
4. `ai-docs/工作日志.md` 顶部记录实际改动和验证结果。
