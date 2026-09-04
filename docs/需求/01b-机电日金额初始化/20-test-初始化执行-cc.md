# 01b 机电日金额初始化 · TEST 执行手册（灌库 + 同步 + 对账）

> 日期：2026-09-04 ｜ 工具：cc ｜ 状态：**灌库完成且逐行核验通过（81/81 零差异，2026-09-04 15:21 入库），同步未执行** ｜ 下一步：执行第 3 步同步 → 第 4 步对账
>
> 数据源：`机电公司导入模板2026.9.4全.xlsx`（81 行 / 128,740,939.09 元，华姐 2026-09-04 版，全称与 BU 代码已连库核实）
> 口径（用户已确认）：数据为月合计挂在每月 1 号；采购企业落到二级集团级；类目名由脚本自动映射字典标准名。

## 0. 交付物（本目录 `sql/`）

| 文件 | 用途 | 性质 |
|---|---|---|
| `01-test-预检.sql` | 灌库前四项检查（只读） | 必须先跑，全部符合期望才继续 |
| `02-test-初始化.sql` | 81 行幂等灌库（ON DUPLICATE KEY UPDATE，重跑安全） | 事务包裹 |
| `03-test-回滚.sql` | 逻辑删 81 行（双保险定位：INITJD 前缀 + 创建人董杰） | 出问题才用 |
| `04-test-对账.sql` | 同步后 MySQL 侧四个口径的数字 | 配合第 4 步 |

生成脚本：`/tmp/opencode/gen_init_sql.py`（映射依据全部注释在脚本头；Excel 换版时改路径重跑即可再生成）。

## 1. 灌库前预检

```bash
bash scripts/dbq.sh "$(cat docs/需求/01b-机电日金额初始化/sql/01-test-预检.sql)" scm_source_test
```

四节期望（详见 SQL 内注释）：
① 8 个统计日流水号中段占用数全为 0；② 六家组织在 test 库存在且 BU 正确；③ Owningplate 字典六个短名齐全；④ 记下「灌库前基线」两个数字（15 行 / 433,923.93 元，是历史测试数据，属正常）。

> 实际执行：灌库时本节未单独跑（用户直接执行了 02）；四项检查已由 cc 事后逐项核实，全部符合。

## 2. 灌库

```bash
bash scripts/dbq.sh "$(cat docs/需求/01b-机电日金额初始化/sql/02-test-初始化.sql)" scm_source_test
```

末尾自检期望：`init_rows=81 ｜ init_amt=128740939.09`。

## 3. 触发同步（二选一）

**方案 A：直接调接口（test 惯用，我来执行）**

```bash
bash scripts/api.sh POST /e/business/source/centralizedProcurementReport/syncJd \
  '{"startTime":"2026-01-01 00:00:00","endTime":"2026-09-01 23:59:59"}'
```

（endTime = 初始化最大统计日 2026-09-01 当天末尾；同步按 ledger_no 覆盖写 ES，重跑不翻倍）

**方案 B：调度中心网页「执行一次」（照 14 部署文档第六节任务 #5 的范式）**

任务：寻源模块 →「集采业务统计报表-机电四大类」→ 执行一次，参数：

```
source-centralizedProcurementReportService-syncJdData-{"startTime":"2026-01-01 00:00:00","endTime":"2026-09-01 23:59:59"}
```

（每日 03:40 的自动任务之后会照常跑，无需改任务配置）

## 4. 对账（三处一致才算通）

**① MySQL 侧**（跑 `04-test-对账.sql`），期望：

| 口径 | 期望 |
|---|---|
| 初始化行 | 81 行 / 128,740,939.09 |
| 全部机电行 | 96 行 / 129,174,863.02（= 初始化 81 + 历史测试 15） |
| 钢材 | 22 行 / 82,811,628.57 |
| 电线电缆 | 21 行 / 20,112,227.72 |
| 润滑剂 | 21 行 / 14,860,017.45 |
| 轴承及备件 | 17 行 / 10,957,065.35 |

**② ES 侧**（index_centralized_procurement_report_test，金额字段叫 `taxTotal`）：

```bash
bash scripts/esq.sh count index_centralized_procurement_report_test '{"query":{"bool":{"filter":[{"term":{"dataSource":"JD"}}]}}}'
bash scripts/esq.sh search index_centralized_procurement_report_test '{"size":0,"query":{"bool":{"filter":[{"term":{"dataSource":"JD"}}]}},"aggs":{"amt":{"sum":{"field":"taxTotal"}}}}'
```

期望：count = 96，sum ≈ 129,174,863.02（= MySQL ② 号口径）。同步前基线（2026-09-04 实测）：count = 15。

**③ 驾驶舱/首页**：

```bash
bash scripts/api.sh GET /e/business/source/source/cockpit_collection_data_categoryAmount
```

期望：钢材/电线电缆/润滑剂/轴承及备件四格 = 预检④记录的灌库前数字 + 上表对应增量。
注意：**test 数字里含历史测试脏数据**（如「钢材-接口测试修改」这类行），四格绝对值不用纠结，看「灌库前后增量 = 初始化金额」即可。

## 5. 回滚（出问题时）

```bash
bash scripts/dbq.sh "$(cat docs/需求/01b-机电日金额初始化/sql/03-test-回滚.sql)" scm_source_test
```

然后**必须重新执行一次第 3 步同步**（ES 覆盖写，数字即回落）。

## 6. 已知差异与注意（都核实过，非遗留问题）

1. test 组织表 10010000 是旧名「冀东水泥股份有限公司」，uat 为「金隅冀东水泥集团股份有限公司」——本环境灌本环境名，仅显示差异。【推断】uat 更接近 prod，prod 执行前由运维在预检里实查 prod 组织名后定稿（预检 SQL 到时加一条同款查询）。
2. 数据是月合计挂在每月 1 号：驾驶舱「日」数字在这 8 天 = 整月金额，月/季/年不受影响（口径已获用户确认）。
3. test 历史测试行（张雨录入的 16 行）不清理、不覆盖，与初始化数据并存，回滚互不影响。
4. uat 复用：把 `sql/01~04` 的 `scm_source_test`/`scm_ubm_test` 后缀换 `_uat`、库名同步改，映射值（组织名/字典）以 uat 库实查为准后再执行。

## 7. 执行记录（执行后回填）

- [x] 灌库完成：2026-09-04 15:21 入库，81 行（用户执行；cc 事后逐行核验 81/81 全字段零差异，含类目映射/板块短名/流水号/金额/审计字段；ES 同步前基线 count=15）
- [ ] 预检（未单独执行，四项检查已事后核实通过）
- [ ] 同步触发方式：A 接口 / B 调度中心（＿＿＿）
- [ ] ES count=96 sum≈129,174,863.02（＿＿＿）
- [ ] 驾驶舱四格增量对上（＿＿＿）
