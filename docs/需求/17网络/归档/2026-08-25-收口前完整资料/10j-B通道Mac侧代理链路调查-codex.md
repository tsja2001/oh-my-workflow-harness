# B通道Mac侧代理链路调查

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：已通过公司端B通道只读核实，家庭Mac的root `cloudflared` Connector当前确实被Mac Mihomo strict-TUN捕获，并经 `Daily-Reality-443`连接Cloudflare Tunnel入口。  
> 下一步：暂不远程改Mac；如要验证物理直连收益，先设计备份、自动回退和带外恢复，再只改Mac单端做A/B。

> 本文接续 `20k-WSL-B通道客户端收口-codex.md`，只记录只读调查结果，不覆盖前序文档。

## 1. 结论

当前B通道只在公司Windows侧实现了物理直连；家庭侧仍经过Mac Clash Reality节点：

```text
公司Windows cloudflared
→ DIRECT
→ Cloudflare Access
→ Cloudflare Zero Trust
→ 家庭侧home-lan Connector
→ Mac Mihomo TUN
→ Daily-Reality-443
→ Cloudflare Tunnel入口
→ Mac sshd
```

因此B去掉了公司侧的WARP/CDN套娃，但没有去掉家庭侧Reality绕行。这能解释B持续会话实测略快、但VS Code仍明显卡顿。

## 2. 当前进程与生效配置

只读SSH回读：

- macOS版本：15.5。
- root `cloudflared` PID 22381，启动时间 `2026-08-24 09:40:26`。
- root Mihomo和Clash Party均在运行，存在 `utun1500`。
- Mac持久配置及最终 `work/config.yaml`均为 strict-TUN。
- 最终配置的 `route-exclude-address`为空。

本轮没有读取LaunchDaemon参数、Tunnel Token、节点UUID、私钥、Cookie或其他凭据。

## 3. 当前Connector真实路由证据

root Connector启动时间与Mihomo日志完全对齐。启动后访问：

```text
region1.v2.argotunnel.com:7844 using PROXY[Daily-Reality-443]
region2.v2.argotunnel.com:7844 using PROXY[Daily-Reality-443]
```

2026-08-25 09:11和09:21仍记录相同Connector UDP连接经 `Daily-Reality-443`；09:16还出现：

```text
cloudflared → region1.v2.argotunnel.com:7844
Daily-Reality-443 / 64.64.252.58:443 connect error: context deadline exceeded
```

这不是旧进程或历史猜测，而是当前root Connector生命周期内的真实流量证据。

Mac曾在家庭端自连接测试中出现 `cloudflared → ssh-home.tttthappy1111.org using DIRECT`，那是client-side Access SSH测试，不是root Connector连接Cloudflare Tunnel入口；不能拿它证明家庭Connector直连。

## 4. 为什么本轮不直接修改

A通道和B通道都依赖同一个家庭 `home-lan` Connector。若远程修改Mac TUN/规则后Connector无法直连Cloudflare，公司端会同时失去A、B两条回家路径。

安全测试至少需要：

1. 备份Mac Mihomo持久配置和最终配置哈希。
2. 先证明公司当前SSH会话和带外恢复手段可用。
3. 安排自动回退，不能依赖断线后再次SSH执行恢复。
4. 一次只改Mac侧 `cloudflared`路径，不改Windows、Cloudflare、Tunnel和节点。
5. 对比Connector Healthy、SSH冷连接、持续命令、VS Code体感和Mac普通网络。

本轮未修改Mac、Clash、Cloudflare、Windows、WSL或远程Git。
