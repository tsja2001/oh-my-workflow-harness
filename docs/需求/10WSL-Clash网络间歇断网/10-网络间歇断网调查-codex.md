# WSL + Clash 网络间歇断网调查

> 日期：2026-08-12 ｜ 工具：codex
> 当前状态：已复现并锁定故障边界；未修改 Clash、WSL、Codex、Claude 或 OpenCode 配置。
> 下一步：先让三个 AI 工具显式走 Clash 的本地 HTTP 代理恢复稳定，再单独治理 WSL NAT → Clash TUN 的间歇黑洞。

## 结论

这不是 Codex、Claude、OpenCode 三个工具各自坏了，也不是 WSL DNS 整体失效。

已证实的共同故障点是：三个工具当前都没有显式代理，WSL 出网完全依赖“WSL NAT → Windows → Clash TUN”。这段链路今天会间歇性黑洞：域名可在几毫秒内解析成 Clash fake-IP，但 TCP 连接发不出去。相同时间改为显式访问 Windows Clash `7890` 端口后，五个测试站点全部恢复。

`openaiDeveloperDocs` 的 30 秒启动超时是该网络故障的结果，不是独立根因。仅把 `startup_timeout_sec` 调大只能延后报错；网络链路恢复后，再把它作为容错项配置才有意义。

## 直接证据

### 1. WSL 网络模式没有退回昨天的问题模式

- `/mnt/c/Users/29455/.wslconfig` 当前仍是 `networkingMode=nat`。
- WSL 当前地址为 `172.21.117.53/20`，默认网关为 `172.21.112.1`。
- `/etc/resolv.conf` 使用 WSL DNS tunneling 地址 `10.255.255.254`。
- 当前 shell 没有任何 HTTP/HTTPS/ALL_PROXY 环境变量。

证据命令：`ip route`、`sed -n '1,80p' /etc/resolv.conf`、脱敏后的 `printenv`、读取 `.wslconfig`。

### 2. 今天上午确实发生过代理节点连接超时

Windows Clash core 日志：

- 08:41:43 至 09:04:21，代理服务器连接失败 49 次。
- 其中 41 次为 `context deadline exceeded`，8 次为 `i/o timeout`。
- 09:02:22～09:03:15 可直接看到 Claude 的资源域名和 Anthropic API 同时失败。

这解释了上午一段时间 Windows 和 WSL 上的代理请求都不稳定，但不是 15 点后 WSL 单独失败的完整解释：15 点后裸连代理服务器连续 6 次成功，显式走 `7890` 也全部成功。

证据文件：`C:\Users\29455\AppData\Roaming\mihomo-party\logs\core-2026-08-12.log`；证据查询为按小时统计 `connect error`，未在本文记录节点地址。

### 3. OpenCode 的失败时间线与现象一致

`/home/t/.local/share/opencode/log/opencode.log` 在今天 11:10、11:12、13:45、14:43、15:07～15:10（北京时间）多次记录 `Failed to fetch models.dev` / `TimeoutError`。

这说明故障不是 Codex MCP 专属；OpenCode 对另一个公网域名也在同一台 WSL 中反复超时。

### 4. 15:19 已现场复现“DNS 正常、TCP 黑洞”

在 WSL 中连续三轮并发访问 OpenAI Docs、Anthropic、models.dev、GitHub、DeepSeek：

- 五个域名都在约 2～60 毫秒内完成 DNS，均拿到 `198.18.0.0/15` 内的 Clash fake-IP。
- 第一轮仅 Anthropic、models.dev 成功；后两轮仅 Anthropic 成功，其余在 4 秒连接超时。
- 随后的 15 秒测试中五个站点全部 `time_connect=0` 并超时，说明连接甚至没有完成 TCP 建连，不是 TLS、证书或应用层错误。

证据命令：`getent ahostsv4`、三轮 `curl --connect-timeout 4 --max-time 8`、一轮 `curl --connect-timeout 15 --max-time 20`。

### 5. 显式走 Clash 代理后立即全部恢复

WSL 可以访问 Windows 网关的 Clash `7890/7891/7892` 三个端口。相同时间把 curl 显式指向 `http://172.21.112.1:7890`：

| 目标 | 结果 | 总耗时 |
|---|---:|---:|
| OpenAI Docs MCP | HTTP 405（GET 方法不允许，证明服务可达） | 0.77 秒 |
| Anthropic API | HTTP 404（根路径响应，证明服务可达） | 0.78 秒 |
| DeepSeek | HTTP 200 | 1.21 秒 |
| GitHub | HTTP 200 | 1.81 秒 |
| models.dev | HTTP 200 | 2.23 秒 |

同一次对照中，OpenAI 官方 Codex manual 拉取脚本在无代理时约 25 秒无结果；带相同显式代理后 5.3 秒成功下载并校验。

最后又用 MCP `initialize` 做了协议级复核：WSL 直连在 5 秒 TCP 超时；显式代理返回 HTTP 200、`text/event-stream`，服务端名称 `openai-docs-mcp`、协议版本 `2025-06-18`。这证明 MCP 服务本身及配置 URL 都正常。

证据命令：`curl -x http://<WSL默认网关>:7890 ...`、OpenAI Docs skill 的 `fetch-codex-manual.mjs`。本文只记录端口，不记录订阅或节点信息。

### 6. Windows 本体正常，故障边界落在 WSL NAT/HNS → TUN

15 点末从 Windows 本体直连同一批五个站点，全部成功，耗时 1.54～3.25 秒；Clash 的 Mihomo 网卡同时为 `Up`。

因此当时的边界是：

`WSL 应用 → WSL NAT/HNS → Windows Clash TUN` 失败；

`Windows 应用 → Clash TUN` 正常；

`WSL 应用 → Clash HTTP 7890` 正常。

### 7. 当前 TUN 配置有一个高风险放大因素，但尚不能定为唯一根因

- `mihomo.yaml` 和生成的 `work/config.yaml` 都有 7,508 条 `route-exclude-address`。
- Mihomo 网卡当前产生 27,193 条路由（IPv4 11,978；IPv6 15,215）。
- 配置还启用了 `strict-route: true`；mihomo 官方文档说明 Windows 上该项会增加防火墙规则。

这组超大路由表来自昨天为避免 DIRECT 回环而加入的全国 CN 网段排除。它很可能放大 Windows HNS/TUN 的路由或状态波动，但本次没有抓包或 HNS 事件日志能证明“27,193 条路由就是唯一根因”，因此这里只列为候选诱因。

另外，今天 08:39 和 14:17 仍出现订阅 CDN 走 DIRECT 后被判定 loopback、Clash Party API 返回 503；这是昨天已经记录的遗留问题，主要影响订阅更新，不足以解释今天所有 AI 域名的间歇超时。

## MCP 报错判断

当前 `/home/t/.codex/config.toml` 只有：

```toml
[mcp_servers.openaiDeveloperDocs]
url = "https://developers.openai.com/mcp"
```

官方 Codex manual 已核实：这是正确的 streamable HTTP 地址；`startup_timeout_sec` 是合法的可选配置，官方公开默认值为 10 秒。本次使用中的 Codex 表面实际在 30 秒时报错，以现场报错为准。

本次失败发生时，WSL 直连 `developers.openai.com` 连 TCP 都建不起来；显式走 Clash `7890` 后 0.77 秒返回。因此不应把 30 秒改成 60 秒当成根治。

## 临时恢复办法（不改文件）

在准备启动 Codex / Claude / OpenCode 的同一个 WSL 终端执行：

```bash
clash_proxy_url="http://$(ip route show default | awk '/default/{print $3; exit}'):7890"
export HTTP_PROXY="$clash_proxy_url" HTTPS_PROXY="$clash_proxy_url"
export http_proxy="$clash_proxy_url" https_proxy="$clash_proxy_url"
export ALL_PROXY="$clash_proxy_url" all_proxy="$clash_proxy_url"
export NO_PROXY="127.0.0.1,localhost,::1" no_proxy="$NO_PROXY"
```

然后从这个终端重新启动三个工具。这个办法绕过有问题的 WSL→TUN 自动接管，但仍由同一个 Clash 规则和节点出网。

如果显式代理稳定后 MCP 偶尔仍因启动抖动失败，可再在现有 MCP 小节补 `startup_timeout_sec = 60`；它是容错，不是本次根因修复。

## 安全附带发现

定点检索前曾误做过一次较宽的 OpenCode 日志搜索，输出带出一条历史 shell 命令中的 Nexus 基础认证串。后续检索已改为只输出错误计数和时间，不再输出日志原文。

该凭据必须按已泄露处理并轮换。`opencode.log` 会保存完整 shell 命令，轮换后还需要清理或脱敏旧日志；新凭据只能更新到 `ai-docs/creds.env`，不能写入其他文件或命令行历史。

## 后续治理建议

1. 优先把三个 AI 工具统一包装为“启动前动态读取 WSL 默认网关并设置 Clash 代理”，避免继续依赖 TUN 自动接管。
2. 单独重做 Clash TUN 的 DIRECT 出口设计，目标是取消 7,508 条 CN 静态排除，降回正常规模的路由表；修改前必须保留昨天备份并逐项回归内网、国内、国外、Tailscale、WSL。
3. 对订阅 CDN 的 DIRECT loopback 单独修复，避免订阅更新触发 503。
4. 网络稳定后再观察 `openaiDeveloperDocs`；只有仍有偶发慢启动时才增加 `startup_timeout_sec`。

## 参考

- Microsoft Learn：WSL 默认 NAT 架构、WSL 访问 Windows 服务时默认网关就是宿主机地址；DNS tunneling 默认启用，用于复杂网络/VPN兼容。
- mihomo 官方 TUN 文档：`auto-route`、`strict-route`、`route-exclude-address` 的 Windows 行为，以及 mixed/system 栈的防火墙注意事项。
- OpenAI Codex manual：Docs MCP 地址与 `startup_timeout_sec` 配置项。
