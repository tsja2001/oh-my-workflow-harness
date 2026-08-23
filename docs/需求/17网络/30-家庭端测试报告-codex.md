# Cloudflare 家庭私网接入 · 家庭端测试报告

> 日期：2026-08-22  
> 工具：codex  
> 当前状态：家庭端核心配置与恢复性测试通过；完整端到端验收因路由器固定租约和公司 Windows 异地客户端尚未完成，结论为“有条件通过”。  
> 下一步：补路由器静态 DHCP 后，从非家庭网络的公司 Windows 执行最后五项验收并把结果追加为新测试报告。

## 1. 测试结论

| 编号 | 测试项 | 结果 | 证据 |
|---|---|---|---|
| T01 | 新 Tunnel 独立创建 | 通过 | `home-lan` 与 `saturate` 同时存在 |
| T02 | 新 Tunnel 健康 | 通过 | Dashboard 显示 Healthy |
| T03 | 旧 Tunnel 不受影响 | 通过 | `saturate` 仍 Healthy、46 天运行时长 |
| T04 | 家庭 CIDR Route | 通过 | `192.168.5.0/24`、`home-lan`、`default` 回查一致 |
| T05 | Connector 环境预检查 | 通过 | DNS、QUIC、HTTP2、Cloudflare API 全部 PASS |
| T06 | Connector 自动恢复 | 通过 | 强制重启后 PID 更新、2 条 QUIC 连接重新注册、Dashboard 恢复 Healthy |
| T07 | 注册权限最小化 | 通过 | `home-lan-owner` / Allow / 单一邮箱规则持久存在 |
| T08 | 客户端流量最小化 | 通过 | MASQUE + Traffic only + Include IPs，三条 CIDR 全部回查 |
| T09 | 家庭 SSH | 通过 | `192.168.5.35:22` TCP 成功 |
| T10 | Home Assistant | 通过 | `192.168.5.35:8123` HTTP 200 |
| T11 | 路由器本地页面 | 通过 | `192.168.5.1:80` HTTP 200 |
| T12 | 路由器固定租约 | 未执行 | 管理登录会话过期，未猜密码、未冒险改 Mac 静态 IP |
| T13 | 公司 Windows 异地 SSH/HA/路由器 | 未执行 | 当前无可控的公司 Windows 客户端 |
| T14 | 公司公网/内网/DNS不被接管 | 配置回查通过，实机待验 | Traffic only + Include IPs 已生效；仍需 Windows 路由表/诊断实测 |

## 2. 判定

- 家庭侧：通过。Tunnel、路由、权限、客户端策略、本地服务和自动恢复均有实际回查证据。
- 完整组网：有条件通过。路由器租约固定与公司 Windows 异地数据面仍是上线前最后两项。
- 安全边界：通过。旧代理、DNS、VPS、Clash、Tailscale、ToDesk、Home Assistant 均未改。

## 3. 后续验收通过标准

只有同时满足以下条件，才能把完整组网标记为最终通过：

1. 路由器静态绑定表出现 Mac → `192.168.5.35`，断开重连或续租后地址仍不变。
2. 公司 Windows 在非家庭网络注册成功，Dashboard出现 1 台设备。
3. Windows 能访问家庭 SSH、Home Assistant、路由器三个目标。
4. Windows 普通公网、公司内网和 DNS 行为与启用 WARP 前一致。
5. 断开 WARP 后家庭三目标不可通过 Cloudflare访问，重新连接后恢复。

