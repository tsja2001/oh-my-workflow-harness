# WSL 自动跟随 Clash 代理配置

> 日期：2026-08-12 ｜ 工具：codex
> 当前状态：已配置并验证；新开的 zsh 终端会自动跟随 Windows Clash `7890` 端口。
> 下一步：正常使用即可；Clash 开关变化后，重启已经运行的 Codex、Claude 或 OpenCode 会话。

## 配置结果

- 自动脚本：`/home/t/.config/wsl-clash-proxy/auto-proxy.zsh`
- 加载入口：`/home/t/.zshrc`
- Clash `7890` 可访问：当前 WSL 终端自动设置 HTTP/HTTPS/ALL_PROXY，所有需要代理的流量交给 Clash 分流。
- Clash `7890` 不可访问：自动清除上述代理变量，当前 WSL 终端恢复直连。
- 显示终端提示符及真正执行命令前检查，最多每三秒一次；状态没有变化时不打印消息。
- `localhost`、`127.0.0.1`、`::1` 不走代理，避免本地回调和 OpenCode 本地服务绕圈。

## 验证

1. `zsh -n ~/.zshrc` 和 `zsh -n ~/.config/wsl-clash-proxy/auto-proxy.zsh` 均通过。
2. Clash 开启时，新 zsh 检测宿主机 `7890` 并设置六个大小写代理变量。
3. 模拟端口关闭时，六个代理变量全部清除。
4. 通过自动代理访问 OpenAI Docs MCP、Anthropic、GitHub、DeepSeek、models.dev 均成功。

## 边界

代理变量由 shell 传给启动时的子进程。已经运行中的 Codex、Claude、OpenCode 不会因 Clash 后续开关而自动重建连接；切换 Clash 后重新启动对应工具即可。

## 回退

从 `/home/t/.zshrc` 删除 `wsl-clash-proxy/auto-proxy.zsh` 的加载行即可停用；独立脚本可以保留，不加载就不会生效。
