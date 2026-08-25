# Cloudflare 家庭私网接入 · 架构总览与公司端下一步

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：家庭电脑、家庭路由器、Cloudflare 和公司 Windows 的预配置已经完成；只差在公司网络注册 Windows 客户端并做最终验收。  
> 下一步：先执行只读体检，通过后运行公司端一键脚本；用户只处理一次邮箱验证码，最后打开一个公司内部页面确认办公网络正常。

## 1. 先记住一句话

这套方案就是：**公司 Windows 被设计为只把访问家庭网段 `192.168.5.0/24` 的流量交给 Cloudflare，Cloudflare 再通过家里 Mac 主动建立的 Tunnel 把流量送回家；公司内网、普通上网、DNS 和 Clash 应保持原路。今天的最后验收就是证明实际效果与这个设计一致。**

它不是把家里的 SSH、Home Assistant 或路由器直接公开到互联网，也没有给这些服务创建公网域名。

## 2. 整个架构怎么走

```text
访问家庭设备时：

公司 Windows
  │ Cloudflare One Client（WARP）
  │ 只接管 192.168.5.0/24
  ▼
Cloudflare Zero Trust
  │ 根据 CIDR Route 找到 home-lan
  ▼
家里 Mac 上的 cloudflared
  │
  ├── Mac SSH：192.168.5.35:22
  ├── Home Assistant：192.168.5.35:8123
  └── 家庭路由器：192.168.5.1:80

访问公司内网或普通网站时：

公司 Windows ──────────> 原来的公司网络 / Clash / DNS
                         不经过家庭 Tunnel
```

几个名字可以这样理解：

- `cloudflared`：家里 Mac 主动连出去的“接线员”，家里不用开放公网端口。
- `home-lan` Tunnel：Cloudflare 中专门给家庭网络建的一条通道。
- CIDR Route：告诉 Cloudflare，`192.168.5.0/24` 在 `home-lan` 后面。
- Cloudflare One Client / WARP：公司 Windows 上进入这条通道的客户端。
- Split Tunnel Include：只把明确列出的家庭网段放进通道，其他流量不接管。

## 3. 在此之前已经做完什么

### 3.1 家里电脑和路由器

- 家里 Mac 的固定地址已设为 `192.168.5.35`，DHCP 续租后地址仍然不变。
- Mac 的 SSH `22`、Home Assistant `8123` 已在家中局域网实测可用。
- Mac 已安装 `cloudflared 2026.8.2`，并作为用户服务运行。
- Connector 重启后能自动恢复，Cloudflare 中的 `home-lan` 会重新变为 Healthy。
- Mac 接通电源时系统不会自动睡眠，所以日常可以持续在线。
- 家庭路由器仍为 `192.168.5.1/24`；没有改 DNS、DHCP 地址池、WAN、Wi-Fi 或 NAT。

一个已知限制：`cloudflared` 是当前 Mac 用户的登录服务。Mac 重启后，需要该用户登录 macOS，Connector 才会启动；仅停在登录界面时不能保证远程可用。

### 3.2 Cloudflare

- 新建了独立 Tunnel：`home-lan`，状态已回查为 Healthy。
- 新增私网路由：`192.168.5.0/24` → `home-lan`。
- 注册规则 `home-lan-owner` 只允许指定的本人邮箱用一次性验证码注册设备。
- 客户端策略已定为 `Traffic only + Include IPs`：只纳入家庭网段和 Cloudflare 登录所需的两个地址。
- 旧的 `saturate` Tunnel、`tttthappy1111.org` DNS、VLESS、VPS 和 Clash 都没有修改；`saturate` 与 `home-lan` 是两套互不混用的东西。

### 3.3 公司 Windows

- 已安装官方签名的 `Cloudflare One Client 26.7.1343.0`，Windows 服务正在运行。
- 已预填组织 `mute-cake-c395`，但**故意没有提前注册和连接**。
- Windows SSH 配置中已准备 `home-mac` 别名，并备份了修改前的配置。
- 已准备一键脚本，能保存启用前基线、打开注册页面、等待最小路由策略并自动测试 Windows、WSL、Clash、DNS、公网和家庭服务。

之所以当时不注册，是因为电脑还在家中 Wi-Fi。那时访问 `192.168.5.x` 会直接走局域网，不能证明 Cloudflare 这条异地链路真的可用。

## 4. 现在还差什么

现在只剩公司网络下的最终验收：

1. Windows 注册到 `mute-cake-c395`，由你接收并填写一次邮箱验证码。
2. WARP 连接后确认只接管家庭 `192.168.5.0/24`。
3. 实测 Windows 能登录家里 Mac，并访问 Home Assistant 和家庭路由器。
4. 实测 WSL、普通公网、DNS、默认路由和 Clash 没受影响。
5. 你亲自打开一个日常使用的公司内部页面，确认公司内网正常。

此前 Windows → Mac 的免密 SSH 测试在家庭环境中超时过一次，因此仍要由今天的脚本重新证明，不能把它当成已通过。

## 5. 你现在具体做什么

你已经完成 Git 同步，不需要再拉代码。接下来让 Codex 按顺序执行：

```bash
cd /home/t/projects/work-wsl
bash scripts/windows-cloudflare-one.sh doctor
```

`doctor` 只读取 Windows、WSL、Clash、路由和客户端状态，不注册、不连接、不改网络。确认没有家庭网段冲突后，再执行：

```bash
bash scripts/windows-cloudflare-one.sh setup
```

你本人只需要在浏览器出现登录页时：

1. 使用已获准的邮箱登录。
2. 接收并填写一次性验证码。
3. 同意浏览器打开 Cloudflare One Client。
4. 脚本全部结束后，打开一个平时使用的公司内部页面。

验证码、认证链接、Token、Cookie、密码和 SSH 私钥都不要复制到终端、聊天或文档。

## 6. 什么才算真正完成

必须同时满足下面三点：

1. 脚本最后显示 `All automated checks passed.`。
2. `ssh home-mac` 能真正登录到家里 Mac，不只是显示端口可连。
3. 你打开的公司内部页面仍能正常使用。

完成后，日常使用方式是：

```powershell
ssh home-mac
```

- VS Code Remote - SSH：选择 `home-mac`。
- Home Assistant：浏览器打开 `http://192.168.5.35:8123/`。
- 家庭路由器：浏览器打开 `http://192.168.5.1/`。

第一阶段没有配置家庭私有域名，因此先记住这两个固定 IP 地址。

## 7. 如果网络异常

只要普通网页、公司内网、DNS、Clash 或 WSL 有一项异常，先执行：

```bash
bash scripts/windows-cloudflare-one.sh disconnect
bash scripts/windows-cloudflare-one.sh doctor
```

然后保留终端输出交给 Codex。不要反复注册、删除 Cloudflare 设备、修改 Include/Exclude、改 Clash，尤其不要动旧的 `saturate` Tunnel。

断开 Cloudflare One Client 只会停掉公司电脑到家庭网的这条新通道，不会删除家里的 Tunnel，也不会影响旧代理。

## 8. 这些结论从哪里来的

平时只看本文即可；需要追查技术证据时再看下面几处：

- 家庭 Mac、Connector、服务可达和自动恢复：`docs/需求/17网络/20b-家庭端部署执行结果-codex.md:27-56`。
- Mac 固定地址及续租复验：`docs/需求/17网络/20d-路由器固定租约执行-codex.md:14-50`。
- Cloudflare Tunnel、Route、注册规则和最小流量策略：`docs/需求/17网络/20b-家庭端部署执行结果-codex.md:10-25`。
- 明确没有改旧 Tunnel、DNS、VLESS、VPS 和 Clash：`docs/需求/17网络/20b-家庭端部署执行结果-codex.md:76-82`。
- Windows 客户端、组织预填、SSH 别名和未完成项：`docs/需求/17网络/20e-Windows端预配置与明日执行-codex.md:10-50`。
- 公司端脚本步骤、成功标准和止损方式：`docs/需求/17网络/20e-Windows端预配置与明日执行-codex.md:52-124`；实际入口为 `scripts/windows-cloudflare-one.sh:8-97`。
- “完整链路仍待验收”的最终判定：`docs/需求/17网络/30c-Windows预配置测试报告-codex.md:33-51`。
