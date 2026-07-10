# 集采日金额统计台账 · 当前接口清单

> 日期：2026-07-10 ｜ 工具：codex ｜ 状态：已删除台账专用组织查询，其余台账接口保持不变
> 下一阶段：无需接口测试；前端将组织控件改为复用已有组织接口

> 本文取代 `集采日金额统计台账-接口文档.md` 中的“当前接口清单”。旧文档保留原接口的历史记录，不再作为联调依据。

## 基础信息

- 网关前缀：`/gateway/e/business/source`
- 台账路径前缀：`/collectionDailyAmountLedger`
- 请求方式：`POST`
- 请求格式：`application/json`

## 接口清单

| 功能 | 完整路径 | 请求体要点 |
|---|---|---|
| 分页查询/导出 | `/gateway/e/business/source/collectionDailyAmountLedger/queryPageList` | `currentPage`、`limit`、`model`；导出另带 `exportRequest` |
| 新增 | `/gateway/e/business/source/collectionDailyAmountLedger/add` | 台账 10 个业务字段 |
| 修改 | `/gateway/e/business/source/collectionDailyAmountLedger/modify` | `ledgerId` + 台账业务字段 |
| 删除 | `/gateway/e/business/source/collectionDailyAmountLedger/delete` | `ledgerId` |
| 详情 | `/gateway/e/business/source/collectionDailyAmountLedger/detail` | `ledgerId` |
| 集采类目字典 | `/gateway/e/business/source/collectionDailyAmountLedger/queryCategoryDict` | `{}` |
| 所属板块字典 | `/gateway/e/business/source/collectionDailyAmountLedger/queryOwningplateDict` | `{}` |

## 已删除接口

`POST /gateway/e/business/source/collectionDailyAmountLedger/queryOrgForSelect` 已删除，不再提供。集采执行单位和采购企业应复用现有组织接口；具体复用路径由同事/前端现有方案确定，本文不猜测。

## 请求示例

### 分页查询

```json
{
  "currentPage": 1,
  "limit": 10,
  "model": {
    "ledgerNo": "JCRJE-",
    "categoryCode": "1501"
  }
}
```

### 新增

```json
{
  "executeUnitCode": "<现有组织接口返回的编码>",
  "executeUnitName": "<执行单位名称>",
  "categoryCode": "1501",
  "categoryName": "钢材",
  "statisticDate": "2026-07-01",
  "purchaseCompanyCode": "<现有组织接口返回的编码>",
  "purchaseCompanyName": "<采购企业名称>",
  "taxAmount": 500.00,
  "buCode": "BU002",
  "buName": "冀东水泥"
}
```

### 修改/删除/详情

- 修改：在新增请求体基础上增加 `"ledgerId":"<主键>"`。
- 删除：`{"ledgerId":"<主键>"}`。
- 详情：`{"ledgerId":"<主键>"}`。

## 变更边界

- 类目字典和板块字典接口保留。
- 台账查询、新增、修改、删除、详情、导出均未改。
- 数据库表和配置未改。
