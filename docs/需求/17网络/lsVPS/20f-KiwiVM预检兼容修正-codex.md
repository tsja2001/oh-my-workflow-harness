# 洛杉矶 VPS SSH · KiwiVM 预检兼容修正

> 日期：2026-08-26  
> 工具：codex  
> 当前状态：已根据 AlmaLinux 两次真实预检输出修正脚本并生成新哈希载荷；两次失败均发生在 Token 提示、备份和配置写入之前。  
> 下一步：用户在 Advanced 执行 `KVM脚本2/02-Advanced-预检兼容修正版生成命令.txt`，退出码为 0 后在 Interactive 校验新哈希并执行。

> 本文取代 `20e-KiwiVM-Advanced一键生成与交互安装-codex.md` 中的首版载荷和哈希。取代原因：VPS 实证显示最小系统没有 `xargs`，并且 `set -o pipefail` 与 `grep -q` 组合会偶发把已支持 `--token-file` 的 cloudflared 误判为不支持。20e 保留作为首轮执行记录。

## 两次失败的事实

第一次输出已显示 AlmaLinux 9.7、cloudflared 2026.6.1 和 `localhost:22` SSH Banner，随后在旧脚本第 109 行退出 127。该行依赖 `xargs`，而 VPS 最小系统没有这个命令。

第二次在 `--token-file` 能力检查处退出。第一次已经越过同一检查并打印 cloudflared 版本，因此不是二进制能力改变；根因是 `pipefail` 下 `grep -q` 找到目标后提前关闭管道，前级命令可能收到 SIGPIPE，从而让整条管道偶发失败。

两次都发生在以下动作之前：

- `PRECHECK_OK`；
- Token 提示和 Token 写入；
- 备份目录创建；
- systemd unit、账号、独立二进制和服务启动。

因此 VPS 配置未被本轮脚本修改，不需要回退。

## 修正内容

- 删除 `xargs` 依赖，直接执行 `command -v sshd` 得到的绝对路径；
- 所有 cloudflared 帮助检查先完整收集输出，再匹配 `--token-file`；
- 注册日志匹配不再使用会提前关闭管道的 `grep -q`；
- 保留原来的 Token 无回显、备份、限定写入范围和自动回退逻辑。

修正版 SHA-256：

```text
7197c4879852bfaa20f94bec2689835548d2bb8854fa7ef23d132f7b7dfbcee6
```

本地已验证：`bash -n` 通过；脚本中无 `xargs`/`grep -q`；5,000 行模拟帮助输出在 `pipefail` 下仍能稳定匹配；新 Advanced 载荷由 `build-advanced-command.sh` 从源脚本机械生成，解码后与 406 行源脚本哈希一致。
