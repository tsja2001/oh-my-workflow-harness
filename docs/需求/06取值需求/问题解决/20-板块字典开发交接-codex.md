# 集团整体集采规模 · 板块字典开发交接

> 日期：2026-08-12  
> 工具：codex  
> 当前状态：后端、前端代码已在本地分支完成提交，编译构建通过；未推送、未合入 test、未部署。  
> 下一步：推送前重新刷新前端仓 `origin/test`；用户确认后推送两个同名分支，合入 test 并由用户点 Jenkins，随后做接口对照验收。

## 1. 分支与提交

| 仓库 | 分支 | 开发基线 | 本地提交 |
|---|---|---|---|
| `01zhaocai-end/scm-source-all` | `fix/quzhi-ubm-yang` | 已刷新 `origin/test@620391263` | `a73ebcae5 fix: 集采规模集团名称改用字典` |
| `02zhaocai-front/scm-vue-hpc` | `fix/quzhi-ubm-yang` | 本地缓存 `origin/test@f0ffe03` | `7dab67c fix: 集采规模展示字典名称` |

前端 Git 远端在本次开发时连续 fetch / ls-remote 超时；本地 `origin/test@f0ffe03` 的更新时间为 2026-08-10，且是当前 UAT 的祖先，所需首页代码完整存在。**推送前必须重新 fetch 核实远端 test 是否前进**；若有新提交，先把本地这一笔干净提交校正到最新 test 基线。

## 2. 代码改动

### 后端

文件：`scm-source-chase/.../CentralizedProcurementPortalServiceImpl.java`

- 六个集团保留固定编码和固定顺序，删除后端写死名称。
- 首页请求通过现有 UBM Feign 查询一次 `Owningplate` 字典，用 `buCode` 填充 `groups[].name`。
- 字典名称去掉首尾空白。
- 字典异常或缺值时记录日志并显示 `buCode`，金额接口继续正常返回。
- “直管单位”是计算分组，继续固定显示。
- 金额筛选、扣减公式、交易率计算均未修改。

### 前端

文件：`src/views/procurementPortal/components/OfficeTransaction.vue`

- 删除六个集团和直管单位的写死名称。
- 金额卡直接按接口 `groups` 生成，名称使用 `group.name`。
- Vue 列表 key 改为稳定的 `group.buCode`。
- 排名图原本就使用接口名称，无需改动。

## 3. 验证结果

- 后端：`scripts/jc.sh` 隔离编译目标 Java 文件，0 报错，已生成 class。
- 前端：`npm run build:app` 生产构建成功；只有项目原有的 Browserslist 过期和包体积警告。
- 前端 lint：项目未安装 `vue-cli-service lint` 命令，无法单独执行；生产构建已通过。
- `git diff --check`：两个仓库均通过。
- test 字典接口已实查：BU002、BU006、BU005、BU007、BU004、BU008 六个编码全部存在。
- 两个仓库均只修改一个目标文件，提交后工作区干净。

## 4. 部署前后对照基线

部署前 test 首页接口 `POST /e/business/source/centralizedProcurementPortal/overview` 的集团数据：

| buCode | amount | rate |
|---|---:|---:|
| BU002 | 14136.17 | 96.30 |
| BU006 | 25.86 | 32.38 |
| BU005 | 1.24 | 100.00 |
| BU007 | 5.60 | 100.00 |
| BU004 | 26.31 | 42.76 |
| BU008 | 31.51 | 100.00 |
| ZG | 6.69 | 100.00 |

部署后验收：

1. 六个集团的 `name` 与 `queryOwningplateDict` 返回名称逐一相等。
2. 上表的 `amount/rate` 在数据未新增的前提下保持不变；若期间新增业务数据，则用部署前后同一 `queryDate` 重新对照。
3. “直管单位”仍在最后，其他字典板块没有新增成独立卡片。
4. 金额卡和二级集团集采率排名显示同一名称。

本次不改数据库、不新增字典、不改 ES，也不需要重跑历史同步。

## 5. 回退

- 后端回退提交：`git revert a73ebcae5`
- 前端回退提交：`git revert 7dab67c`

回退后重新构建对应 test 服务即可；没有数据回滚动作。
