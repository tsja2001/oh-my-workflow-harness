# WSL B通道客户端收口执行记录

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：WSL `home-mac-access` 已永久复用 Windows `cloudflared.exe`，并启用10分钟SSH连接复用；真实SSH、家庭路由器、Home Assistant及A通道复验均通过。  
> 下一步：日常在WSL直接运行 `ssh home-mac-access`；如需测试VS Code，只做一次小目录实际使用，不要求30分钟等待。

> 本文接续 `30f-B通道公司端短版验收报告-codex.md`，只记录WSL客户端尾项，不覆盖前序报告。

## 1. 修改前与备份

- 修改文件：`/home/t/.ssh/config`
- 修改前权限：`0600`，属主 `t:t`
- 修改前SHA-256：`fed9027c50446e1102cda97203f71a36d8e49eebf448e2001bed77270088deb9`
- 完整备份：`/home/t/.ssh/config.bak-home-mac-access-20260825-104607`
- 备份权限：`0600`，备份SHA-256与修改前原文件一致

## 2. 实际修改

只修改 `Host home-mac-access`：

1. `ProxyCommand`从WSL Linux版 `cloudflared`改为已验收的Windows版 `cloudflared.exe`，复用Windows Access登录和浏览器能力。
2. 新增 `ControlMaster auto`。
3. 新增 `ControlPersist 10m`。
4. 新增 `ControlPath ~/.ssh/cm-%C`。

GitHub、公司GitLab、旧Mac别名、SSH密钥、known_hosts、Clash、WARP、Cloudflare后台及Windows SSH配置均未修改。

修改后文件保持 `0600`，SHA-256为：

```text
07f57431ba568df2a1748abd46cda813a4df4afb72f169268a17f211fb12a5c8
```

## 3. 验收结果

| 检查项 | 实际结果 |
|---|---|
| `ssh -G home-mac-access` | Windows helper、WSL密钥、严格主机指纹、600秒复用参数均正确展开 |
| WSL真实SSH | 返回 `macdeMac-mini.local` |
| 首次冷连接 | 约7.43～7.65秒 |
| 同一主连接后连续命令 | 1.00、1.07、1.06、1.03秒 |
| 显式主连接验证 | `Master running`，复用命令0.96秒 |
| 家庭路由器 | `router-ok` |
| Home Assistant | `ha-ok` |
| 原A通道 | Windows `home-mac`仍返回相同Mac主机名 |

Codex的单次命令执行器会在一次工具调用结束时清理其后台子进程，因此跨Codex工具调用不应拿控制套接字是否仍在作为失败证据。普通WSL终端和VS Code不受该隔离机制影响；同一执行上下文内已经证明OpenSSH连接复用生效。

## 4. 日常使用

```bash
ssh home-mac-access
ssh home-mac-access 'hostname'
```

第一次连接仍需建立Access、WebSocket和SSH，之后10分钟内的SSH命令会尝试复用同一主连接。主机指纹不一致时必须停止，不能接受新指纹。

## 5. 回退

只回退本次WSL SSH配置：

```bash
cp -a /home/t/.ssh/config.bak-home-mac-access-20260825-104607 /home/t/.ssh/config
chmod 600 /home/t/.ssh/config
ssh -G home-mac-access
```

回退不触碰Windows、Clash、WARP、Cloudflare或家庭Mac。本轮未执行回退，未操作远程Git。
