# 驾驶舱负滞后率前端显示修复

> 日期：2026-08-14
> 工具：codex
> 当前状态：前端修复已完成，并已准备本地 test、功能和 UAT 三个分支。
> 下一步：用户推送本地 `test` 和 `jicai-cockpit-yang-uat`；后者向 `uat` 提 MR。

> 本文补充 `20-UAT发布准备-codex.md` 的前端发布范围。补充原因：后续确认滞后率允许为负，前端需要新增负数图形兼容；原文关于数据库、字典、Nacos 和定时任务无需新增配置的结论不变。

## 改动

- 仓库：`02zhaocai-front/scm-vue-all-cockpit`
- 文件：`src/views/procurementCatalogMgt/index.vue`、`src/views/procurementCatalogMgt/js/dashboardUtils.js`
- 逻辑：滞后率小于 0 时，统计柱按 0 绘制；右侧百分比仍显示接口返回的原始负数。响应率、完成率和执行中不变。

## 本地分支

- `jicai-cockpit-yang@37380a4`：基于缓存的 `origin/test@bf0259f` 开发提交。
- `test@73087b1`：已在本地合并 `jicai-cockpit-yang`。
- `jicai-cockpit-yang-uat@b5ff092`：基于缓存的 `origin/uat@c419c6d`，仅带入同一前端修复，供提 MR 到 `uat`。

## 边界

- 按用户要求未运行浏览器、构建或测试验证。
- 未 fetch、push、创建远程分支或提 MR。
- 未修改数据库、字典、Nacos、定时任务、Jenkins 或任何环境数据。
