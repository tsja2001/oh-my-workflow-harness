# 家庭网络接入 · 日常使用与故障处理

> 日期：2026-08-25  
> 工具：codex  
> 当前状态：A、B 的日常入口和回退点均已准备好。  
> 下一步：正常使用即可；只有真实访问失败时才执行本页检查，不重复部署或迁移。

## 日常怎么连

在公司 Windows PowerShell：

```powershell
ssh home-mac-access          # B：推荐用于 Mac SSH / VS Code
ssh home-mac                 # A：WARP/CIDR 回退入口
```

在 WSL：

```bash
ssh home-mac-access
ssh home-mac-access 'hostname'
```

WSL 的 B 配置位于 `/home/t/.ssh/config`，复用 Windows `cloudflared.exe`，并启用 `ControlPersist 10m`。本次修改前备份为：

```text
/home/t/.ssh/config.bak-home-mac-access-20260825-104607
```

## VS Code Remote-SSH

1. 在公司 Windows 的 VS Code 安装并打开 Remote - SSH。
2. 选择 `Remote-SSH: Connect to Host...`。
3. 选择 `home-mac-access`。
4. 首次 Access 会要求在浏览器完成本人登录；之后 VS Code 使用既有 SSH 密钥。

Windows VS Code 读取 `C:\Users\29455\.ssh\config`，不是 WSL 的 `~/.ssh/config`。冷启动约 7～10 秒不代表故障；真正判断以目录浏览、终端输入和保存文件的持续体感为准。

## A 通道状态和止损

在仓库根目录运行：

```bash
bash scripts/windows-cloudflare-one.sh verify       # 全链路只读检查
bash scripts/windows-cloudflare-one.sh disconnect   # 公司网络异常时先断开 A
bash scripts/windows-cloudflare-one.sh connect      # 恢复 A
```

`verify` 的历史最终结果为 19/19 PASS，但每次排障仍要看本次实际结果。断开 A 不会删除配置，B 也不依赖 WARP。

## Mac 服务只读检查

在家里 Mac 的仓库克隆目录运行：

```bash
bash scripts/macos-cloudflared-launchdaemon.sh status mac
```

不要在公司远程盲目执行 `apply`、`resume` 或改 Mac Clash。只有确认系统服务本身故障、且能在 Mac 本地或带外控制时，才根据归档执行记录考虑回退。

## 出问题时按这个顺序

| 现象 | 先做什么 | 不要做什么 |
|---|---|---|
| 只有 A 不通 | 跑 `verify`，看 WARP 和家庭 CIDR 项 | 不先改 Mac 或 Cloudflare |
| B 首次不弹登录 | 先在 Windows 端运行一次 `ssh home-mac-access` | 不提供浏览器 Token、Cookie 或验证码给 AI |
| B 冷连接慢 | 进入后持续使用几分钟，再判断复用后的体感 | 不拿一次冷启动判定整条链路失败 |
| 主机指纹变化 | 立即停止并核对 | 不接受未知新指纹 |
| 公司内网异常 | 立即 `disconnect` A，再记录具体网址和错误 | 不同时改 WARP、Clash、DNS 和路由 |
| A、B 同时失败 | 优先怀疑家庭 Connector/Mac/家庭网络，找 Mac 本地或带外入口 | 不远程试改共同 Connector |

## WSL B 配置回退

仅在确认本次 WSL SSH 配置有问题时执行：

```bash
cp -a /home/t/.ssh/config.bak-home-mac-access-20260825-104607 /home/t/.ssh/config
chmod 600 /home/t/.ssh/config
ssh -G home-mac-access
```

这只回退 WSL SSH 配置，不触碰 Windows、Clash、WARP、Cloudflare 或家庭 Mac。

证据：归档 `20g-Mac系统服务迁移与公司端最终验收-codex.md:26-42,91-118`、`20k-WSL-B通道客户端收口-codex.md:10-69`、`30f-B通道公司端短版验收报告-codex.md:17-48`。
