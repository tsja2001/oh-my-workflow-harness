# CLAUDE.md

先读 `AGENTS.md`（所有 AI 的总入口，含目录地图、命名规范、安全红线），再读 `ai-docs/工作规范与习惯.md`。

- 完整工作流 skill 正史在 `skills/enterprise-dev-workflow/`（项目级加载器在 `.claude/skills/enterprise-dev-workflow/`，自动触发）。
- 凭据在 `ai-docs/creds.env`（gitignore，禁止写进提交/文档/聊天）。
- 对用户永远说大白话；技术执行 AI 全包；需要用户动手的事攒成清单最后一次性给。
- 复杂 shell 命令先写 `/tmp/xx.sh` 再 `wsl.exe -d ubuntu-24.04 -- bash /tmp/xx.sh` 执行（内联变量会被吞）。
