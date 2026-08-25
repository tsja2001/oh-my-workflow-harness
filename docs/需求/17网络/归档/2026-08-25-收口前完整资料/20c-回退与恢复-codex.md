# Cloudflare 家庭私网接入 · 回退与恢复

> 日期：2026-08-22  
> 工具：codex  
> 当前状态：已形成与本次实际配置对应的回退顺序，尚未执行回退。  
> 下一步：只有在异地验收失败且无法就地修正时，按“先客户端、再 Route、再 Connector”的顺序回退；旧 `saturate` 永远不在回退范围内。

## 1. 最快止损

公司 Windows 若出现网络冲突，优先在 Cloudflare One Client 中断开连接或离开组织。当前策略保留了这两个能力，因此不必先删除云端对象。

这一步只停止新客户端接管流量，不影响家庭 Mac、本地网络、旧代理 Tunnel 或普通公司网络。

## 2. 家庭端停用顺序

按以下顺序操作，避免残留 Route 指向离线 Connector：

1. Cloudflare Routes 删除本需求新增的 `192.168.5.0/24`。
2. 家庭 Mac 卸载用户级 cloudflared 服务：`cloudflared service uninstall`。
3. 回查 `launchctl print gui/$(id -u)/com.cloudflare.cloudflared` 已不存在，且没有 cloudflared 进程。
4. Cloudflare Tunnels & Mesh 只删除 `home-lan`。
5. 如确认不再使用，再执行 `brew uninstall cloudflared`。

禁止删除、迁移、编辑或重启 `saturate`。

## 3. Device Profile 回退

本账号执行前没有已注册设备，因此最安全的回退不是立即恢复全局默认排除表，而是先让新设备断开/离开组织。若确实要恢复 Profile：

1. 先记录当时正在使用的 Split Tunnel 条目。
2. 把 Service mode 改回需要的模式。
3. 按 Cloudflare 当前官方默认清单或组织既有基线重建 Exclude 项；不要凭记忆补默认网段。
4. 保存后重新载入页面，核验 Service mode、Split Tunnel 模式和条目数量。

切换 Include/Exclude 会立即删除当前条目，属于破坏性操作；没有当次明确回退需要时不要执行。

## 4. 路由器恢复

当前没有写入 DHCP 静态绑定，因此无需回退。若后续补上绑定，需要撤销时只删除对应 Mac 的那一行，不能重置路由器或改 DHCP 池。

## 5. 恢复上线

若只是家庭 Mac 重启或 Connector 临时离线：

1. 登录当前 macOS 用户。
2. 回查 LaunchAgent 为 running。
3. 等待两个 Connector 连接注册。
4. Dashboard 确认 `home-lan` Healthy。
5. 再从异地客户端测试家庭 IP。

