# Cloudflare 家庭私网 · Mac 端 Clash 直连修正

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：家庭 Mac 的 `cloudflared` 已物理绕过 Clash TUN，直接连接 Cloudflare Tunnel 公网入口；严格路由、家庭服务和 Connector 均复验通过。  
> 下一步：用户把同样的便携默认值同步到服务器订阅；Mac 日常仍以 Clash Party 应用级 TUN/DNS 设置和最终运行配置为准。

> 本文接续 `50b-项目阶段复盘与AI交接-codex.md`，只补记 2026-08-25 家庭 Mac 新发现的 Clash 分流问题及最终结果，不覆盖此前基线。

## 1. 问题与根因

- 旧现场中，Mac 根服务 `cloudflared` 解析 `region1/region2.v2.argotunnel.com` 得到 Clash Fake-IP `198.18.3.2/3`，随后命中 `MATCH,PROXY`，外层经 `Daily-Reality-443` 洛杉矶节点再进入 Cloudflare。
- 服务器订阅虽包含 TUN/DNS 设置，但 Clash Party 会在其后叠加本机应用级常用配置；冲突字段以本机值为准。此前最终运行配置中的 `route-exclude-address` 是空数组，订阅文件的排除值没有进入内核运行配置。
- Clash Party 的 YAML 覆写采用深度合并，但优先级同样低于应用常用配置；`work/config.yaml` 才是 Mihomo 实际读取的最终事实，不能直接编辑。

## 2. 最终生效配置

配置落点为 Clash Party 本机 TUN/DNS 页面，对应应用级 `mihomo.yaml`，最终生成到 `work/config.yaml`：

```yaml
tun:
  strict-route: true
  route-exclude-address:
    - 198.41.192.0/24
    - 198.41.200.0/24

dns:
  fake-ip-filter:
    - "+.argotunnel.com"
    - "+.cftunnel.com"
```

说明：`198.41.192.0/24`、`198.41.200.0/24` 是 Cloudflare Tunnel 官方公网入口所在网段；`198.18.0.0/16` 是 Mihomo Fake-IP 使用的保留测试网段，两者不是同一类地址。

## 3. 复验证据

2026-08-25 21:23～21:26 在家庭 Mac 实测：

| 检查项 | 最终结果 |
|---|---|
| 最终运行配置 | `strict-route: true`；两个公网网段和两个 Fake-IP 排除域名均存在 |
| DNS | `region1` 返回 `198.41.192.*`，`region2` 返回 `198.41.200.*`，不再返回 `198.18.*` |
| 系统路由 | Cloudflare 入口经家庭网关 `192.168.5.1`、Wi-Fi `en1`，不再经 `utun1500` |
| Connector | root LaunchDaemon 正常运行，建立 4 条到真实 `198.41.*` 的 QUIC 连接 |
| Clash 日志 | 新连接未再出现 `cloudflared → Daily-Reality-443`；最后一次旧代理记录停在直连切换前 |
| 家庭服务 | Home Assistant `127.0.0.1:8123` HTTP 200；路由器 `192.168.5.1` HTTP 200 |

Connector 日志仍显示 `location=lax*`，含义是 Cloudflare 自己选择了洛杉矶边缘机房，不代表流量仍经过个人洛杉矶 VLESS 节点。最终链路为：

```text
家庭 Mac cloudflared → 家庭宽带 → Cloudflare Tunnel 边缘
```

公司 Windows、Cloudflare Zero Trust 后台、既有 Tunnel/Route、代理节点和远程 Git 本轮均未修改。

