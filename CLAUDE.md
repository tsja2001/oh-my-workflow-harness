# CLAUDE.md

先读 `AGENTS.md`（所有 AI 的唯一必读入口：红线、任务分级、索引、文档规范）。其余文档按 AGENTS.md 第 3 节的索引表**按需**查，不要开工前通读。

- 完整开发流程 skill 正史在 `skills/enterprise-dev-workflow/`（项目级加载器在 `.claude/skills/`，自动触发）。
- 线上排查用 `skills/diagnose-scm-project/`（项目级加载器在 `.claude/skills/`，自动触发；**脚本型，先跑命令别先猜**）。
- 用户想跳出项目聊行业/职业/软件品类时用 `skills/industry-perspective/`（谈话型，**聊完必须回写 `references/校准记录.md`**）。
- 凭据在 `ai-docs/creds.env`（gitignore，禁止写进提交/文档/聊天）。
- 对用户永远说大白话；技术执行 AI 全包；需要用户动手的事攒成清单最后一次性给。
- Windows 侧执行复杂 shell 命令要走脚本文件或 heredoc，内联的变量和引号会被 wsl 边界吞掉（AGENTS.md §4）。
