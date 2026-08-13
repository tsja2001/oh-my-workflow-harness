# 集采业务管理报表和取值 · UAT 部署方案（范围修正版）

> 本文取代 `10-UAT部署方案-codex.md`，取代原因：本次 UAT 范围新增 06_2 已进入远端 test 的日计划口径与采购方案前端改动。
>
> 日期：2026-08-11
>
> 工具：codex
>
> 当前状态：4 个仓库的 `jicai-uat-yang` 本地交付分支已从最新 `origin/uat` 准备完成并验证通过；尚未推送远端、尚未提 MR。
>
> 下一步：用户执行本文第 3 节的 4 条 `git-human-push` 命令，再分别提 MR 到 `uat`。

## 1. 本次实际交付范围

| 仓库 | 本次带入 UAT 的内容 | 处理结果 |
|---|---|---|
| `scm-source-all` | 03 五路统一 ES 中 source 的 FP/ZC/MT/JD；06 首页 overview、坑口/价格趋势接台账及 test 收口修复 | 已准备本地分支 |
| `scm-report-all` | 03 集采业务统计报表查询、筛选和导出 | 已准备本地分支 |
| `scm-order-all` | 06_2 日计划执行率/完成率分母改为计划总数量、滞后率改为三率相减；云采日计划同步幂等修复 | 已准备本地分支 |
| `scm-vue-all-procurementscheme` | 03 集采报表页面与固定路由；06_2 台账页面显示完成率和滞后率 | 已准备本地分支 |
| `scm-vue-hpc` | 06 首页前端 | `origin/test` 已是 `origin/uat@948ae824e0` 的祖先，不重复提 MR |

## 2. 明确没有带入

1. source 当前工作区未提交的 `SourceCollectionServiceImpl.java`（Fastjson 修复）没有进入任何交付分支。
2. `config.js`、`package-lock.json`、`yarn.lock`、token、凭据和其他环境文件均未进入交付分支。
3. order 的 `beab9ac09` 尚未进入远端 `test`，本轮按“只搬远端 test 已提交代码”的规则不带。
4. `centerHeader/categoryAmount/situA/doRate` 四块没有可搬运的新实现提交：当前前三块仍走旧 MySQL/缓存链路，`doRate` 仍落静态缓存；不能在本次 MR 中宣称已完成。

## 3. 用户现在执行的 4 条命令

```bash
cd /home/t/projects/work-wsl/01zhaocai-end/scm-source-all && git-human-push -u origin jicai-uat-yang
cd /home/t/projects/work-wsl/01zhaocai-end/scm-report-all && git-human-push -u origin jicai-uat-yang
cd /home/t/projects/work-wsl/01zhaocai-end/scm-order-all && git-human-push -u origin jicai-uat-yang
cd /home/t/projects/work-wsl/02zhaocai-front/scm-vue-all-procurementscheme && git-human-push -u origin jicai-uat-yang
```

推送后，每个仓库各提一个 MR：

- 源分支：`jicai-uat-yang`
- 目标分支：`uat`
- 审核人：兰宇

## 4. MR 合并后的部署顺序

1. 后端：source → report → order，分别确认 `*-all-uat` 和下游 `*-web-uat` 都成功。
2. 前端：`scm-vue-statics-uat`，`PROJECT=procurementScheme`、`GIT_BRANCH=uat`。
3. HPC 代码已在 UAT 分支；若尚未构建，再单独执行 `PROJECT=hpc` 的 UAT 前端构建。
4. Nacos、5 个 ES 同步任务、菜单和历史补数仍按 `20-UAT部署执行-oc.md` 第 1.4～2 节执行。
5. 本次 UAT 不执行需求目录中的 test 清理 SQL，也不创建已有业务表。

