# 台账需求2 · 接口文档

> 日期：2026-07-10 ｜ 工具：codex ｜ 状态：台账管理接口保留；驾驶舱实时接线撤回已合入并推送 `test`（merge `03a3117fe`），待 Jenkins 部署
> 下一阶段：Jenkins 部署后，测试 AI 只验证台账管理接口；网关和 TOKEN 只从 `ai-docs/creds.env` 读取

> **范围变更：** `GET /e/business/source/source/cockpit_collection_data_kengk` 是既有接口，但本版本不再接入新台账，继续读取旧缓存；本文原驾驶舱联动用例取消，留到下一版本重新设计。

## 基础规则

- 管理接口前缀：`/e/business/source/coalPitDailyIndicator`
- 驾驶舱既有地址保持不变，但不属于本版本台账联动验收范围。
- 管理接口均为 `POST` + `application/json`；登录即可调用，菜单权限只影响页面入口。
- `publishDate` 是价格归属/发布日期，格式 `yyyy-MM-dd`；新增不传时后端默认当天，修改时不可变更。
- `publishTime`、`publishBy`、`publishByName` 全由后端填写，前端传入不会生效。
- 坑口名称和价格必须成对；至少 1 组、最多 5 组；价格非负且最多两位小数。

## 接口清单

| # | 功能 | 方法 + 路径 | 请求体示例（可直接替换值） | 成功响应要点 |
|---|---|---|---|---|
| 1 | 分页查询 | `POST /e/business/source/coalPitDailyIndicator/queryPageList` | `{"currentPage":1,"limit":10,"model":{"indicatorNo":"JCKK-","executeUnitCode":"DEMO001","publishTimeArr":["2025-12-01 00:00:00","2025-12-31 23:59:59"]}}` | `data.root` 返回主表字段和坑口1~5平铺字段 |
| 2 | 新增并发布 | `POST /e/business/source/coalPitDailyIndicator/add` | 见下方完整 JSON | `data` 返回 `JCKK-当天-NNN` 流水号 |
| 3 | 详情 | `POST /e/business/source/coalPitDailyIndicator/detail` | `{"indicatorId":"<分页返回的主键>"}` | 返回该记录及坑口1~5 |
| 4 | 修改并重新发布 | `POST /e/business/source/coalPitDailyIndicator/modify` | 见下方完整 JSON | 成功；流水号/发布日期/创建信息不变，发布时间和操作人刷新 |
| 5 | 删除 | `POST /e/business/source/coalPitDailyIndicator/delete` | `{"indicatorId":"<主键>"}` | 成功；列表、详情和导出不再返回该记录 |
| 6 | Excel 导出 | `POST /e/business/source/coalPitDailyIndicator/queryPageList` | 查询体额外带 `exportRequest` 等字段，见下方 | 导出 14 列，模板编码 `coal-pit-daily-export` |

## 可直接运行的请求

### 1. 查询 test 演示数据

```bash
bash scripts/api.sh POST /e/business/source/coalPitDailyIndicator/queryPageList '{"currentPage":1,"limit":10,"model":{"indicatorNo":"JCKK-20251208-001"}}'
```

### 2. 新增并发布

```bash
bash scripts/api.sh POST /e/business/source/coalPitDailyIndicator/add '{"executeUnitId":"<组织ID>","executeUnitCode":"<组织编码>","executeUnitName":"<组织名称>","publishDate":"2026-07-10","pit1Name":"金鸡滩5000大卡","pit1TaxPrice":540.00,"pit2Name":"金鸡滩5600大卡","pit2TaxPrice":530.00,"pit3Name":"转龙湾5500大卡","pit3TaxPrice":575.00}'
```

新增成功后保存响应 `data`（流水号），再用分页查询拿到 `indicatorId`。前端即使伪造 `indicatorNo/publishTime/publishBy/deleteSign`，后端也会忽略。

### 3. 详情

```bash
bash scripts/api.sh POST /e/business/source/coalPitDailyIndicator/detail '{"indicatorId":"<主键>"}'
```

### 4. 修改并重新发布

```bash
bash scripts/api.sh POST /e/business/source/coalPitDailyIndicator/modify '{"indicatorId":"<主键>","executeUnitId":"<组织ID>","executeUnitCode":"<组织编码>","executeUnitName":"<组织名称>","pit1Name":"金鸡滩5000大卡（修改）","pit1TaxPrice":541.25,"pit2Name":"金鸡滩5600大卡","pit2TaxPrice":531.00}'
```

修改接口不接收发布日期变更；前端必须把仍需保留的坑口全部传回，因为明细采用整批替换。

### 5. 删除

```bash
bash scripts/api.sh POST /e/business/source/coalPitDailyIndicator/delete '{"indicatorId":"<主键>"}'
```

### 6. 导出

```bash
bash scripts/api.sh POST /e/business/source/coalPitDailyIndicator/queryPageList '{"currentPage":1,"limit":100,"exportRequest":true,"exportTemplateCode":"coal-pit-daily-export","exportFileName":"煤炭重点坑口日指标台账","model":{}}'
```

导出列：流水号、执行单位、坑口1~5名称与价格、发布时间、操作人。

## 边界错误预期

| 场景 | 预期提示/结果 |
|---|---|
| 单位编码或名称为空 | `集采执行单位不能为空` |
| 5 组坑口全空 | `至少填写一组坑口名称和价格` |
| 只有名称没有价格，或只有价格没有名称 | `坑口N名称和价格必须同时填写` |
| 价格为负数或超过两位小数 | `坑口N价格必须大于等于0且最多保留两位小数` |
| 修改/删除主键为空 | `台账主键不能为空` |
| 修改/删除已不存在或已删除记录 | `台账记录不存在或已删除` |

## 链路验收标准（测试 AI 逐条勾选）

1. [ ] test 演示记录能分页查到，5 个坑口与原驾驶舱价格 `575/677/650/660/730` 一致。
2. [ ] 新增返回 `JCKK-当天-NNN`，服务端写入发布时间和当前登录操作人。
3. [ ] 流水号模糊、单位编码/名称、发布时间区间筛选正确。
4. [ ] 详情完整回显；只填 1~3 组也能保存，未填位置为 null。
5. [ ] 修改后流水号、发布日期、创建信息不变；业务字段、发布时间、操作人更新。
6. [ ] 删除后列表、详情、导出不可见，数据库主子记录 `delete_sign=1`。
7. [ ] 导出成功且 14 列顺序、标题和 DTO 字段一致。
8. [ ] 空参数、半组坑口、负数、三位小数、不存在主键均返回明确业务错误，不产生半条主子数据。
