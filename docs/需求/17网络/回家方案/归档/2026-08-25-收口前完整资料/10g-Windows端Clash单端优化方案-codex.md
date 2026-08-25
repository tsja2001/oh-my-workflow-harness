# Cloudflare 家庭私网 · Windows 端 Clash 单端优化方案

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：研究完成，Windows直连WARP入口方案已实测失败并完整回退；当前19项自动验收全部通过，本文只给下一轮Windows单端A/B方案，尚未实施。  
> 下一步：用户确认后，只给 `warp-svc.exe` 指定 `Daily-Reality-443`，由用户重启一次Clash Party，再按本文门槛决定保留或回退；Mac保持不动。

> 本文接续 `10f-Windows端Clash优化前延迟基线-codex.md`。10f保留优化前现场，本文记录核实后的正式方案，不覆盖前文。

## 1. 一句话方案

不再尝试让WARP直连公司网络，也不切换全局代理节点。只增加一条最高优先级的Mihomo进程规则：

```yaml
+rules:
  - PROCESS-NAME,warp-svc.exe,Daily-Reality-443
```

效果是：

```text
普通浏览器/WSL/Claude等 → 继续走原有Clash规则和PROXY选择
Cloudflare WARP外层       → 固定走Daily-Reality-443
家庭192.168.5.0/24       → 仍由WARP送进Cloudflare Zero Trust
Mac cloudflared           → 本轮完全不动
```

这是一轮可回退的性能A/B，不是必须修改。若真实家庭链路没有明显改善，就恢复原规则，不为“理论更优”增加长期复杂度。

## 2. 已核实事实

### 2.1 当前状态已经恢复安全

Windows直连试验失败后，`mihomo.yaml` 和 `work/config.yaml` 已从以下备份恢复，并通过原文件SHA-256核对：

```text
C:\Users\29455\AppData\Roaming\mihomo-party\codex-backups\windows-warp-bypass-20260824-101202
```

恢复后：

- Mihomo完整配置测试成功。
- WARP恢复 `Connected`；仍显示 `Network: unstable`。
- `bash scripts/windows-cloudflare-one.sh verify` 的19项自动检查全部PASS。
- 家庭有效路由仍为 `192.168.5.0/24 → CloudflareWARP`。
- Mac配置和进程全程未改。

### 2.2 为什么不采用“Cloudflare域名/IP直连”

已把Cloudflare官方MASQUE ingress和客户端编排地址临时加入Windows `tun.route-exclude-address`，这才是strict-TUN下真正绕开Mihomo的直连，而不只是规则层的 `DIRECT`。

实测WARP反复尝试：

```text
162.159.197.2:443
162.159.197.2:500
162.159.197.2:8095
```

约25秒始终停在 `Connecting`。恢复原Clash路径后才重新连接。因此公司网络目前不支持WARP直接到Cloudflare ingress，Windows Clash同时承担“可达性出口”，不能简单移除。

Cloudflare官方列出的MASQUE ingress和回退端口见：

- <https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/firewall/>

### 2.3 Reality节点能力

当前Windows订阅缓存和最终 `work/config.yaml` 中的安全字段一致：

| 字段 | Daily-Reality-443 | Daily-CDN-WS |
|---|---|---|
| type | vless | vless |
| network | tcp | ws |
| tls | true | true |
| udp | true | true |
| flow | xtls-rprx-vision | 无 |
| packet-encoding | 默认/raw | xudp |

Mihomo官方说明VLESS可启用UDP，`packet-encoding`为空表示raw，可选XUDP：

- <https://wiki.metacubex.one/en/config/proxies/vless/>

更重要的是，Mac当前两条 `cloudflared → region1/region2.v2.argotunnel.com:7844` 活跃连接都通过 `Daily-Reality-443`，协议为UDP；`cloudflared` 已注册两条QUIC连接且家庭Tunnel真实可用。这是当前服务端能双向承载UDP的业务证据，不只是面板延迟。

### 2.4 同目标延迟对比

通过当前Windows Mihomo命名管道，对两个节点各做3次相同Cloudflare 204测试：

| 节点 | 三次结果 | 中位数 |
|---|---|---|
| Daily-Reality-443 | 166 / 164 / 176 ms | 166 ms |
| Daily-CDN-WS | 373 / 351 / 359 ms | 359 ms |

该结果只证明当前Reality节点建立测试请求更快，不能代替真实WARP验证。历史日志已经证明健康检查可能“假活”。

恢复原路径后的新日志又记录：

- `warp-svc.exe` 86条，其中80条走 `PROXY[Daily-CDN-WS]`，Reality为0。
- WARP ingress相关49条。
- loopback为0。
- 但WARP经CDN已有6条连接失败，错误为CDN入口超时或 `context deadline exceeded`。

因此本方案主要目标是避开当前较慢且有超时的CDN WebSocket/XUDP外层；两个节点同机房，跨境基础RTT仍存在，不承诺降到几十毫秒。

## 3. 为什么按进程，不按域名/IP

Mihomo规则从上到下匹配，官方支持 `PROCESS-NAME`：

- <https://wiki.metacubex.one/en/config/rules/>

当前核心日志能够稳定识别数据面进程为 `warp-svc.exe`。按进程有三个好处：

1. WARP ingress可能切换IPv4/IPv6和端口，进程规则不依赖具体目的IP。
2. 不会把浏览器访问的其他Cloudflare网站一起改到Reality。
3. 只改变WARP外层；普通Clash规则、公司内网和WSL不动。

不把规则写成 `DIRECT`，因为公司网络直连已实测失败；规则目标必须是 `Daily-Reality-443`。

## 4. 正确落点

持久文件：

```text
C:\Users\29455\AppData\Roaming\mihomo-party\override\19fc53966e1.yaml
```

该文件当前包含 `+rules`，生成后的规则位置已经核实：override中的规则位于最终 `work/config.yaml` 第0项起，订阅自带规则和末尾 `MATCH,PROXY` 在其后。

不能只改：

- `work/config.yaml`：它是生成文件，下次重启/重载会被覆盖。
- `profiles/19f21b41eb4.yaml`：订阅更新会覆盖，而且本次无需改节点定义。
- `mihomo.yaml`：它适合TUN路由排除，不是本次进程分流规则的落点。

## 5. 下一轮执行步骤

本轮研究不实施。用户确认实施后按以下顺序：

1. 保存当前WARP状态、最终配置摘要、日志起始行和10f同口径延迟。
2. 单独备份 `override/19fc53966e1.yaml`、订阅缓存和 `work/config.yaml`，记录备份目录。
3. 只在override的 `+rules` 第一项增加：

   ```yaml
   - PROCESS-NAME,warp-svc.exe,Daily-Reality-443
   ```

4. 生成候选完整配置并运行 `mihomo.exe -t`；不通过就不重启。
5. 把一次“退出并重新打开Clash Party/TUN”的动作交给用户执行。
6. 重启后先核对 `work/config.yaml` 确实包含该规则且位于 `MATCH` 前；再检查核心日志。
7. 运行完整Cloudflare验收、公司内网页面人工验证和同口径延迟对比。
8. 达不到成功门槛就恢复单个override备份，再由用户重启一次Clash。

## 6. 成功门槛

必须同时满足：

| 类别 | 成功条件 |
|---|---|
| 配置 | Mihomo完整配置测试成功；最终配置只有新增的一条WARP规则 |
| 规则命中 | 新 `warp-svc.exe` ingress连接明确命中 `Daily-Reality-443`，不再命中CDN |
| WARP | 30秒内达到Connected；不持续Connecting/Disconnected |
| 家庭业务 | Windows/WSL、SSH、HA、路由器及19项自动验收全部PASS |
| 公司环境 | 公司内网页面正常；默认路由、DNS、Clash进程保持基线 |
| 普通代理 | 浏览器/WSL真实HTTPS响应正常，不只看 `using PROXY` |
| 稳定性 | 无新loopback、TUN Access denied、Reality连接超时或WARP反复重连 |
| 性能 | 10f同口径测量至少有可重复改善；建议以中位数改善≥15%作为保留门槛 |

如果仅节点面板数字好看，但HA/SSH延迟没有稳定改善，视为无收益并回退。

## 7. Mac为什么继续不动

Mac当前已经让 `cloudflared` 走Reality；而本次实测Mac到Cloudflare测试点：

- DIRECT约198ms。
- 当前Reality约185ms。

没有证据表明Mac改成直连会更快。更重要的是，Mac既是家庭Connector也是当前远程目标，远程修改其TUN/路由一旦失败，可能同时失去家庭Tunnel和SSH入口。

因此：

1. Windows方案至少稳定使用一个工作日后，才重新评估Mac。
2. 即使Windows有改善，也不自动推出“Mac也该改”。
3. 若未来必须测试Mac，只能在用户能远程桌面/物理操作Mac时进行，并准备定时自动回退；本方案不包含该动作。

## 8. 已吸收的历史教训

- YAML流式 `[]` 和块式 `-` 混写曾导致Clash Party无法启动，修改后必须先解析和完整配置测试。
- strict-TUN下规则层 `DIRECT` 可能再次进TUN形成loopback；不能把DIRECT等同于物理直连。
- `interface-name: WLAN` 曾通过语法但未解决回环，不能以“配置被接受”代替数据面证据。
- `mihomo.yaml` 最后合并；TUN路由写错override可能被覆盖。普通追加规则则应写override。
- `work/config.yaml`是最终事实，但不是持久源。
- `using PROXY`不代表响应已返回；必须测真实HTTP、SSH和UDP响应。
- Mac v1.19.24曾两次出现入站处理僵死，健康检查正常但真实流量挂；以后不能据单一delay结果改Mac。

详细Clash专项记录见：

```text
/home/t/projects/personal/05clash/2026-08-24-cloudflare-warp-windows-reality-plan.log.md
```
