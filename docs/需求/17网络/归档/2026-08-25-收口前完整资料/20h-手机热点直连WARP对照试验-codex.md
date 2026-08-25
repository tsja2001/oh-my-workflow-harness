# Cloudflare 家庭私网 · 手机热点直连 WARP 对照试验

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：试验完成；手机热点下WARP物理直连持续Healthy，家庭SSH/网页及全部19项验收通过；临时Clash配置已逐字节恢复。  
> 下一步：回到公司网络后，不再把“WARP被普遍封锁”作为前提；先选择继续经代理使用，或单独评估向公司网络申请放行官方WARP入口。

> 本文接续 `10g-Windows端Clash单端优化方案-codex.md`。10g中的“公司网络直连失败”仍然成立；本文用手机热点补齐对照组，缩小失败原因范围。

## 1. 一句话结论

不是Cloudflare WARP在当前位置被普遍“墙死”。同一台Windows、同一套WARP和Clash配置，换到手机热点后，WARP绕开Mihomo即可稳定显示：

```text
Connected
Network: healthy
```

而此前公司网络下，同样的物理直连方法持续停在 `Connecting`。因此当前证据指向**公司办公出口链路**是决定性差异，范围包括公司防火墙、出口策略及公司所用上游线路；仅凭本试验还不能把责任精确到其中某一台设备或某一条规则。

## 2. 对照条件

Windows无线网卡已确认连接手机热点：

```text
SSID: tttt
IPv4: 10.104.93.216/24
默认网关: 10.104.93.112
```

本轮没有修改Mac、Cloudflare后台、WARP Device Profile、家庭Tunnel或持久Clash配置源。

为了在strict-TUN下实现真正物理直连，只临时修改当前运行文件：

```text
C:\Users\29455\AppData\Roaming\mihomo-party\work\config.yaml
```

临时加入Cloudflare官方WARP ingress/API路由排除：

```text
162.159.197.0/24
2606:4700:102::/48
162.159.137.105/32
162.159.138.105/32
2606:4700:7::a29f:8969/128
2606:4700:7::a29f:8a69/128
```

这些地址只用于A/B试验，没有写入 `mihomo.yaml`、订阅profile或override。

## 3. 实测结果

### 3.1 WARP状态

Mihomo热重载返回HTTP 204，执行WARP连接后，从10:39:04到10:39:34每约3秒检查一次，共10次，全部为：

```text
Connected / Network: healthy
```

Mihomo日志中没有出现WARP外层到 `162.159.197.0/24` 等入口地址命中代理的记录，符合 `route-exclude-address` 已让外层连接绕过TUN的预期。

日志仍可看到 `warp-svc.exe → time.cloudflare.com:123` 命中普通代理。这是WARP进程的NTP业务流，不是建立WARP隧道的外层连接，不影响上述判断。

另有对 `162.159.197.2` 的ICMP超时，但WARP同时持续Healthy且家庭业务真实可用，说明这些入口不能用ping结果代替隧道和业务验收。

### 3.2 家庭业务链路

手机热点、WARP物理直连时，Windows访问家庭Home Assistant三次均返回HTTP 200：

| 次数 | TCP建连 | 首字节 | 总耗时 |
|---|---:|---:|---:|
| 1 | 0.430秒 | 0.849秒 | 1.088秒 |
| 2 | 0.420秒 | 0.824秒 | 0.824秒 |
| 3 | 0.413秒 | 0.822秒 | 1.021秒 |

另一次路由器访问为HTTP 200，总耗时1.040秒。Home Assistant直连对照总耗时约0.82～1.09秒，低于公司网络经当前CDN代理路径此前约1.42～1.48秒。

## 4. 恢复与最终状态

试验前备份：

```text
C:\Users\29455\AppData\Roaming\mihomo-party\codex-backups\windows-warp-hotspot-20260824\config.yaml.before
```

恢复后备份与运行文件SHA-256均为：

```text
93196ab159c22e3349c95b7c946c5326cfbb14d0e08aeee9fc47e5f22bab54f4
```

`cmp`确认逐字节相同，Mihomo再次热重载返回HTTP 204。随后 `bash scripts/windows-cloudflare-one.sh verify` 的19项全部PASS，包括Windows/WSL到家庭SSH与网页、公网与DNS、默认路由不变、Clash仍运行。

恢复原路径后WARP回到：

```text
Connected
Network: unstable
```

这是试验前的原状态：WARP外层再次被当前Clash CDN节点承载，不是回退失败。Mac全程未动。

## 5. 这次能证明与不能证明什么

能证明：

- WARP官方入口在当前手机运营商热点上可物理直连。
- Windows、WARP账号、Cloudflare策略和家庭Tunnel本身具备正常工作的条件。
- 公司办公出口链路是公司网直连失败与热点成功之间的关键变量。
- 在手机热点上仍让WARP套当前CDN代理没有必要，且恢复后仍显示Unstable。

不能证明：

- 不能仅凭一次热点试验断言公司具体封了哪个IP、端口或协议。
- 不能断言所有公司网络、所有运营商或全国范围的WARP状态。
- 不能把手机热点当成长期公司办公方案；它只是诊断对照组。

## 6. 后续决策

如果必须在公司网络使用家庭私网，现实上有两条路：

1. 保持WARP外层经Clash，优先试验 `warp-svc.exe → Daily-Reality-443`，目标是把当前CDN的额外延迟降下来。
2. 走公司批准流程，请网络侧核对Cloudflare官方WARP MASQUE ingress及UDP/TCP回退端口的出口策略；若公司允许直连，才可取消WARP外层代理。

“直接把Cloudflare域名写成DIRECT”仍不是有效方案：strict-TUN下规则级DIRECT可能回环，真正物理绕过必须用路由排除；而公司网是否允许该直连已经由上一轮失败实测否定。
