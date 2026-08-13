# 集采业务管理报表和取值 · UAT 本地交付执行记录

> 本文取代 `20-UAT部署执行-oc.md` 中“代码分支准备”部分，取代原因：范围新增 06_2，并已实际生成和验证交付分支；其 Nacos、调度、菜单及补数步骤仍然有效。
>
> 日期：2026-08-11
>
> 工具：codex
>
> 当前状态：4 个本地交付分支已完成；AI push 被工作区 Git guard 阻止，远端分支尚未创建。
>
> 下一步：用户执行本文第 2 节命令，随后提 4 个目标为 `uat` 的 MR。

## 1. 已准备的交付分支

所有分支名均为 `jicai-uat-yang`，基线均为各仓最新 `origin/uat`。

| 仓库 | 本地 HEAD | 相对 UAT 提交数 | 最终业务文件数 | 验证 |
|---|---|---:|---:|---|
| `01zhaocai-end/scm-source-all` | `2baf3e0782` | 9 | 13 | 13 个 Java 文件隔离编译 0 错误 |
| `01zhaocai-end/scm-report-all` | `717c58b` | 2 | 5 | 5 个 Java 文件隔离编译 0 错误 |
| `01zhaocai-end/scm-order-all` | `7f0788844` | 2 | 2 | 2 个 Java 文件隔离编译 0 错误 |
| `02zhaocai-front/scm-vue-all-procurementscheme` | `9aa0760a` | 3 | 3 | `npm run build` 成功，只有项目既有 CSS/体积警告 |

### source 提交

```text
2baf3e078 fix: 修改取值-各集团率的分母
dcb51d0ad fix: 云采改为前缀匹配
03c5af2c7 fix: JD同步按机电公司组织编码筛选
18c0cec09 fix: 轴承2502精确匹配
091ac7d16 fix: 完善集采首页取值
2fc032d61 fix: 拼写错误
0552d1d5a feat: 驾驶舱接入台账
7b3be33f0 feat: 完成取值基础查询
748b74bdc feat: 增加集采管理业务统计报表同步
```

### report 提交

```text
717c58b feat: 报表增加查询条件
84ec3c8 feat: 集采业务统计报表
```

### order 提交

```text
7f0788844 fix: 云采日计划统计同步幂等
c3e97840e fix: 集采日计划统计率的分母改为计划总数量
```

### procurementScheme 提交

```text
9aa0760a fix: 收窄集采报表路由交付范围
a78e0018 feat: 集采日计划台账增加完成率和滞后率
7b45deb6 feat: 增加集采管理业务统计报表
```

路由曾在第一次构建时发现直接复制 test 整文件会引用 UAT 不存在的 4 个页面；最终差异已收窄为只新增 `/reportForms/centralizedProcurement`，重新生产构建通过。

## 2. 用户执行 push

```bash
cd /home/t/projects/work-wsl/01zhaocai-end/scm-source-all && git-human-push -u origin jicai-uat-yang
cd /home/t/projects/work-wsl/01zhaocai-end/scm-report-all && git-human-push -u origin jicai-uat-yang
cd /home/t/projects/work-wsl/01zhaocai-end/scm-order-all && git-human-push -u origin jicai-uat-yang
cd /home/t/projects/work-wsl/02zhaocai-front/scm-vue-all-procurementscheme && git-human-push -u origin jicai-uat-yang
```

AI 尝试普通 `git push` 时被 `[work-wsl Git guard]` 正常拦截，没有任何仓库被部分推送。

## 3. MR 清单

| 仓库 | 源分支 | 目标分支 | 建议标题 |
|---|---|---|---|
| source | `jicai-uat-yang` | `uat` | `集采业务统计报表和首页取值上UAT` |
| report | `jicai-uat-yang` | `uat` | `集采业务统计报表上UAT` |
| order | `jicai-uat-yang` | `uat` | `集采日计划新口径上UAT` |
| procurementScheme | `jicai-uat-yang` | `uat` | `集采报表和日计划页面上UAT` |

给审核人的话术：

> 这次共 4 个 MR，都是从各仓最新 UAT 基线准备的干净分支，只带已经进入远端 test 的集采业务提交。source 含 03 报表同步和 06 首页取值；report 是报表查询导出；order 与 procurementScheme 增加日计划四个率的新口径和页面展示。Fastjson 未提交修改、环境配置及依赖锁都没有带入，请审核合入 UAT。

## 4. 仍未完成的 06_2 部分

`centerHeader/categoryAmount/situA/doRate` 不是本次漏摘提交，而是远端 test 上没有完整的新实现提交：

- `centerHeader/categoryAmount/situA` 仍调用 `SourceCollectionMapper` 的旧 MySQL SQL，或受字典开关影响回退静态缓存；
- `doRate` 没有进入 `queryCollectionData()` 的新链路，现有 `queryDoRate()` 返回 `null`，实际请求仍回退静态缓存；
- `830771811` 只把新首页 `CentralizedProcurementPortalServiceImpl` 的类目筛选改成前缀匹配，并没有接通上述四个老驾驶舱入口。

因此本轮 MR 可以交付 03、06 和 06_2 已完成的日计划部分，但驾驶舱四块必须另行开发、进 test 验证后再发下一轮 UAT。

