# Cloudflare 家庭私网接入 · Mac 本地执行准备

> 日期：2026-08-21  
> 工具：codex  
> 当前状态：用户已部分回填环境，计划晚上把公司电脑/Codex 与 Mac mini 放到同一家庭局域网，由 Mac 本机 Codex 侦察环境并通过浏览器配置 Cloudflare；方案可行。  
> 下一步：用户按第 3 节准备 Mac、项目文件、登录条件和手机热点；Mac Codex先执行第 5 节只读交接提示词，出具侦察结果后再进入写配置。

> **与前序文档的关系**：本文补充 `10-拆解规划-codex.md` 的“晚上如何在 Mac 接手执行”，不覆盖用户已填写的 `10-待提供信息-codex.md`。

## 1. 结论

这个安排可行，而且能减少用户手填信息：Mac Codex 可以在本机自动查出 macOS 版本、CPU架构、家庭 CIDR、Mac IP、默认网关、睡眠策略、SSH状态、Docker端口、Home Assistant实际端口和 `cloudflared` 状态；登录 Cloudflare 后也可以从 Dashboard 核实现有 Tunnel、Routes、Zero Trust Team、Enrollment和 Device Profile。

但需要分成两个网络阶段：

1. **同一家庭局域网阶段**：适合传项目、检查 Mac、登录 Cloudflare、备份现有配置、新建家庭 Tunnel、安装家庭 Connector。
2. **异地链路验证阶段**：公司电脑必须离开家庭 Wi-Fi，切到手机热点或第二天回公司网络，再验证 WARP → Cloudflare → 家庭 Tunnel。公司电脑和 Mac 同在 `192.168.5.x` 时，访问 Mac 会直接走局域网，不能证明 Cloudflare 链路可用。

## 2. Codex 和浏览器能力怎么选

### 2.1 推荐：Mac 上的 ChatGPT/Codex 桌面应用

根据 OpenAI Docs：内置 Browser只在 ChatGPT Web/桌面应用中提供，不在 Codex CLI或 Codex IDE扩展中提供。Mac 上建议：

1. 打开 ChatGPT桌面应用并切换到 Codex。
2. 以准备好的 `work-wsl` 交接目录根目录作为项目打开，不能只打开 `docs/需求/17网络` 子目录，否则根目录 `AGENTS.md` 和技能不会生效。
3. 在 Plugins 中安装/启用 Browser；使用内置 Browser登录 `dash.cloudflare.com`。
4. 用户本人手动输入 Cloudflare账号、密码和 MFA；Codex不询问、不保存、不复述这些内容。
5. Browser使用独立于日常 Chrome的浏览器 Profile，优先使用它，避免把个人 Chrome全部历史和其他登录状态交给任务。

官方依据：<https://learn.chatgpt.com/docs/browser.md>

### 2.2 如果用户所说的是“Codex CLI + Chrome控制”

Codex CLI本身没有内置 Browser，但本项目已有 `.agents/skills/playwright-cli/`。Mac 需要额外具备：

```bash
node --version
npm --version
command -v playwright-cli
test -d '/Applications/Google Chrome.app' && echo 'Chrome installed' || true
```

若 `playwright-cli` 不存在，等用户明确开始安装后再执行：

```bash
npm install -g @playwright/cli@latest
```

登录 Cloudflare时使用有界、命名的持久浏览器会话：

```bash
playwright-cli -s=cloudflare-admin open https://dash.cloudflare.com --persistent --headed
```

用户在打开的浏览器窗口中手动完成登录/MFA，再让 Codex继续。禁止执行 `state-save auth.json`、`cookie-get` 或把 Cookie/Storage导出到项目目录；完成后关闭会话：

```bash
playwright-cli -s=cloudflare-admin close
```

项目内技能依据：`.agents/skills/playwright-cli/SKILL.md` 和 `references/session-management.md`。

### 2.3 Chrome 扩展方式

如果用户已经在普通 Chrome登录 Cloudflare，也可以使用 ChatGPT/Codex 的 Chrome扩展或 Playwright attach到现有 Chrome。此方式会接触日常浏览器 Profile，权限更大，只有确认扩展来源、目标 Tab和授权范围后才用；本需求不需要开启全量 CDP Developer Mode就能完成普通页面点击。

## 3. 今晚用户一次性准备清单

### 3.1 设备和网络

- [ ] Mac mini开机并连入家庭 Wi-Fi。
- [ ] 公司 Windows电脑也带回家；确认当前 `work-wsl` 所在的 WSL就是以后安装 WARP 的目标电脑。
- [ ] 手机可以开热点，并有足够流量完成一次 SSH和网页验证。
- [ ] 不要在家庭 Wi-Fi内把“能访问 Mac IP”当成 Cloudflare验证通过。

### 3.2 本机权限

- [ ] 用户知道 Mac本地管理员密码；只在系统弹窗/终端输入，不写进文档或聊天。
- [ ] 用户能在 Mac上手动完成 Cloudflare登录和 MFA。
- [ ] 如果需要设置 DHCP固定租约，用户能登录中兴路由器管理页；路由器密码同样只手动输入。
- [ ] 用户允许本次在验证窗口内安装 `cloudflared`、设置开机服务，并在必要时重启该服务；是否重启整台 Mac由侦察后再决定。

### 3.3 软件

- [ ] Mac已安装 ChatGPT桌面应用并能使用 Codex，或者明确改走 Codex CLI。
- [ ] 使用桌面应用时，确认 Plugins 中能找到 Browser；使用普通 Chrome时，确认所需 Chrome扩展可用。
- [ ] 如果走 CLI/Playwright，Mac已有 Node/npm；`playwright-cli` 可在侦察阶段检查，缺失再安装。
- [ ] Homebrew、Docker和 SSH已可用（用户已口头说明 Homebrew、Docker、SSH存在，仍以本机命令为准）。

### 3.4 账号与敏感信息

- [ ] Cloudflare账号能进入 `tttthappy1111.org` 所在 Account 和 Zero Trust。
- [ ] 登录手机/邮箱可接收 MFA或验证邮件。
- [ ] 不把 Cloudflare密码、MFA、Tunnel Token、API Token、Cookie、SSH私钥复制到项目文档。
- [ ] 创建 Tunnel后，含 Token 的 Connector安装命令由用户在 Mac终端手动执行；Codex只检查命令退出状态和服务状态，不在文档中记录该命令原文。

## 4. 项目怎么放到 Mac

不要只复制两份 Markdown。Mac Codex至少要看到根目录 `AGENTS.md`、本需求、相关安全规则和浏览器技能。

### 4.1 推荐目录

```text
/Users/mac/Projects/work-wsl/
├── AGENTS.md
├── docs/需求/17网络/
├── docs/需求/16安全/10e-合规远程访问方案-codex.md
├── ai-docs/安全红线.md
├── ai-docs/协作规矩.md
├── ai-docs/工具箱.md
├── ai-docs/工作日志.md
├── skills/enterprise-dev-workflow/
└── .agents/skills/playwright-cli/
```

### 4.2 同一局域网后由当前 WSL 传给 Mac

先将 `192.168.5.xxx` 替换为 Mac真实 IP，只做预览：

```bash
cd /home/t/projects/work-wsl
MACMINI_LAN_IP='192.168.5.xxx'
rsync -avnR \
  AGENTS.md \
  docs/需求/17网络 \
  docs/需求/16安全/10e-合规远程访问方案-codex.md \
  ai-docs/安全红线.md ai-docs/协作规矩.md ai-docs/工具箱.md ai-docs/工作日志.md \
  skills/enterprise-dev-workflow \
  .agents/skills/playwright-cli \
  "mac@${MACMINI_LAN_IP}:/Users/mac/Projects/work-wsl/"
```

确认预览中只有上述文件后，再去掉 `-n` 执行实际复制：

```bash
cd /home/t/projects/work-wsl
MACMINI_LAN_IP='192.168.5.xxx'
rsync -avR \
  AGENTS.md \
  docs/需求/17网络 \
  docs/需求/16安全/10e-合规远程访问方案-codex.md \
  ai-docs/安全红线.md ai-docs/协作规矩.md ai-docs/工具箱.md ai-docs/工作日志.md \
  skills/enterprise-dev-workflow \
  .agents/skills/playwright-cli \
  "mac@${MACMINI_LAN_IP}:/Users/mac/Projects/work-wsl/"
```

这里没有 `--delete`，不会删除 Mac已有文件。Mac首次 SSH连接时由用户核对并确认主机指纹；SSH密码/密钥不写入命令文本。

## 5. Mac Codex 第一轮提示词：只读侦察

在 Mac Codex 中打开 `/Users/mac/Projects/work-wsl` 根目录后，原样发送：

> 先完整读取根目录 `AGENTS.md`，再按段号读取 `docs/需求/17网络/`，重点看 `10-拆解规划-codex.md`、`10-待提供信息-codex.md` 和 `10b-Mac本地执行准备-codex.md`。本轮只做只读侦察，不创建或修改 Cloudflare Tunnel/Route，不安装 cloudflared，不改路由器、Mac网络、SSH、Docker或睡眠设置。  
> 先自动核实 Mac 的 macOS/架构、局域网 IP/CIDR/网关、SSH、睡眠、监听端口、Docker/Home Assistant和 cloudflared状态；再使用 Browser打开 Cloudflare Dashboard，由我手动登录/MFA。登录后只读取并记录 Account/Zone、Zero Trust Team、现有 Tunnels/Connectors/Routes、Device Enrollment、Device Profile和 Split Tunnel，禁止打开、复制或输出任何 Tunnel Token/API Token/Cookie。  
> 将事实、未知、冲突和“今天能到哪”写入新的 `docs/需求/17网络/10c-Mac与Cloudflare现状侦察-codex.md`；核对 `192.168.5.1` 的真实子网掩码，不能直接猜成 `/24`。发现现有 VLESS Tunnel、DNS或家庭网段冲突时停止并报告，不做配置。

第一轮结束后，用户只需要检查侦察文档是否准确。确认无误，再另发“开始配置”的第二轮指令。

## 6. 第二轮开始配置前的唯一口令

侦察通过后，用户发送：

> `10c-Mac与Cloudflare现状侦察-codex.md` 已确认。现在按 `10-拆解规划-codex.md` 开始配置：先备份/截图现有 Cloudflare状态，再新建独立 `home-lan` Tunnel和真实家庭 CIDR Route，禁止修改现有 VLESS Tunnel、DNS、Clash或VPS。含 Tunnel Token 的安装命令停下来让我本人在 Mac终端执行；每层配置后验证，失败即停并保留回退。实际动作和前后状态写入新的 `20-部署执行-codex.md`。

## 7. 仍需用户本人提供、Codex无法自动推断的内容

现在剩余的人工信息已经很少：

1. **确认目标公司电脑**：当前 WSL所在的 Windows 11电脑是否就是后续安装 WARP 的那台。
2. **准备异地网络**：今晚用手机热点，还是只配家庭端、第二天到公司再测。
3. **提供登录动作**：Cloudflare/MFA、Mac管理员密码、路由器管理密码均由用户当场手动输入。
4. **决定是否允许重启**：默认只重启新服务，不重启 Mac和路由器；如必须重启，Codex先说明影响再由用户确认。

其余未填内容——Mac IP、`192.168.5.0/??`、DHCP/固定租约、HA端口、Cloudflare Team/Tunnel/Route、WARP Profile——晚上都应先由 Mac Codex和浏览器实际核实，不再要求用户凭记忆填写。

## 8. 今晚不应踩的坑

- 不把 `192.168.5.1网段`直接写成 `192.168.5.0/24`；先读子网掩码。
- 不在现有代理 Tunnel上追加家庭 Route；必须新建独立 Tunnel。
- 不让 Browser/Playwright保存 `auth.json`、导出 Cookie或把 Tunnel Token写入快照/文档。
- 不在公司电脑仍连家庭 Wi-Fi时宣布 WARP端到端成功。
- 不同时大改 WARP、Clash TUN、Mac睡眠和Docker监听；一次只改一层。
- 不扫描整个家庭 `/24` 的所有 IP/端口；只验证用户已知的 Mac、Home Assistant和一台指定 LAN设备。
