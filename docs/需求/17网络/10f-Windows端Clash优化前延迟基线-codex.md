# Cloudflare 家庭私网 · Windows 端 Clash 优化前延迟基线

> 日期：2026-08-24  
> 工具：codex  
> 当前状态：已确认 Windows WARP 外层和 Mac cloudflared 外层均被 Clash 代理；本文冻结 Windows 单端优化前的延迟、日志和配置基线，尚未修改 Clash。  
> 下一步：只在公司 Windows 的 Mihomo TUN 中排除 Cloudflare官方 MASQUE ingress和客户端编排端点，验证通过后停止；本轮不改 Mac。

## 1. 本轮边界

- 只允许修改公司 Windows 的 Clash Party持久配置和由它生成的当前运行配置。
- 家里 Mac 的 Clash、订阅、TUN、进程和 `cloudflared` 全部保持不动。
- 不修改 Cloudflare Zero Trust云端策略、Tunnel、CIDR Route、Windows WARP注册、公司网卡/DNS或Clash代理节点。
- 修改前备份；语法、公司内网、普通代理、WARP和家庭链路任一关键项失败即恢复。

## 2. 优化前延迟

| 测试 | 优化前实测 |
|---|---|
| Mac → 家庭路由器 ICMP | 8/8成功，平均 `3.849 ms`，0丢包 |
| Mac → 家庭路由器 HTTP | 总耗时 `42.983～48.055 ms` |
| Mac DIRECT → Cloudflare测试点 | `198 ms` |
| Mac 当前代理 → Cloudflare测试点 | `185 ms` |
| Windows → Home Assistant TCP建连 | `517.808～528.324 ms` |
| Windows → Home Assistant首字节 | `1.035～1.122 s` |
| Windows → Home Assistant总耗时 | `1.418～1.480 s` |
| Windows → 家庭路由器 TCP建连 | `517.061～571.327 ms` |
| Windows → 家庭路由器总耗时 | `1.074～1.135 s` |
| Windows → Microsoft公网 | 两次约 `2.17～2.33 s`，另两次15秒超时 |

家庭 LAN仅约4ms，主延迟不在家里 Wi-Fi或路由器。

## 3. 优化前路由证据

Windows 当日日志中：

- `warp-svc.exe` 到 Cloudflare `162.159.*` 的记录共195条，全部 `using PROXY[Daily-CDN-WS]`，0条 DIRECT。
- 其中177条 TCP、18条 UDP；WARP客户端同时显示 `Connected / Network: unstable`。
- 当前生成配置 `tun.route-exclude-address` 共7510条，但没有 Cloudflare MASQUE ingress `162.159.197.0/24`、`2606:4700:102::/48`，也没有客户端编排端点。

Mac 实时 Mihomo API中，两条 `cloudflared` 连接均为：

```text
cloudflared → region1/region2.v2.argotunnel.com:7844
rule=Match
chains=PROXY → Daily-Reality-443
```

因此优化前真实路径是：

```text
公司 Windows → WARP → Windows Clash → 代理机房 → Cloudflare
→ Cloudflare Tunnel → 代理机房 → Mac Clash → cloudflared → 家庭设备
```

## 4. Windows 单端最小方案依据

Mihomo官方 TUN文档说明 `route-exclude-address` 用于让指定目标网段绕过 TUN：

- <https://wiki.metacubex.one/en/config/inbound/tun/#route-exclude-address>

Cloudflare官方列出的当前 MASQUE/WARP必需外层地址为：

- MASQUE ingress：`162.159.197.0/24`、`2606:4700:102::/48`
- 客户端编排 IPv4：`162.159.137.105`、`162.159.138.105`
- 客户端编排 IPv6：`2606:4700:7::a29f:8969`、`2606:4700:7::a29f:8a69`

来源：<https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/firewall/>

本轮只加入上述 Cloudflare官方专用地址，不排除整个 Cloudflare地址空间，也不按进程简单加 `DIRECT`。原因是本机 strict-TUN历史上存在 DIRECT外层连接再次被 TUN抓回的回环问题，目的地址级路由排除才是已经验证过的生效层。
