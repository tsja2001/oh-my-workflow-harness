# 集采日金额统计台账 · 当前接口清单

> 日期：2026-07-10 ｜ 工具：codex ｜ 状态：组织查询已在 `jcrje-ledger-yangzhuoran` 恢复，未合并 `test`
> 下一阶段：等待新的修改需求，继续在同一开发分支上调整

## 基础信息

- 网关前缀：`/gateway/e/business/source`
- 台账路径前缀：`/collectionDailyAmountLedger`
- 请求方式：`POST`
- 请求格式：`application/json`
- 测试命令形式：`bash scripts/api.sh POST <路径> '<请求体>'`

## 接口清单

| 功能 | 完整路径 | 请求体要点 |
|---|---|---|
| 组织机构搜索 | `/gateway/e/business/source/collectionDailyAmountLedger/queryOrgForSelect` | `{"keyword":"唐山"}`；空关键字查全部 |
| 分页查询/导出 | `/gateway/e/business/source/collectionDailyAmountLedger/queryPageList` | `currentPage`、`limit`、`model`；导出另带 `exportRequest` |
| 新增 | `/gateway/e/business/source/collectionDailyAmountLedger/add` | 台账 10 个业务字段 |
| 修改 | `/gateway/e/business/source/collectionDailyAmountLedger/modify` | `ledgerId` + 台账业务字段 |
| 删除 | `/gateway/e/business/source/collectionDailyAmountLedger/delete` | `ledgerId` |
| 详情 | `/gateway/e/business/source/collectionDailyAmountLedger/detail` | `ledgerId` |
| 集采类目字典 | `/gateway/e/business/source/collectionDailyAmountLedger/queryCategoryDict` | `{}` |
| 所属板块字典 | `/gateway/e/business/source/collectionDailyAmountLedger/queryOwningplateDict` | `{}` |

## 组织机构搜索

集采执行单位和采购企业两个组织机构控件共用该接口。

### 请求

```json
{ "keyword": "唐山" }
```

- `keyword` 不传或传空：返回全部组织。
- `keyword` 有值：去掉首尾空格后，按组织名称模糊搜索。

### 成功响应要点

```json
{
  "code": "000000",
  "data": [
    {
      "orgCode": "<组织编码>",
      "orgName": "<组织名称>",
      "belongBuCode": "<所属板块编码>",
      "belongBuName": "<所属板块名称>"
    }
  ]
}
```

## 其他请求示例

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

### 删除/详情

- 删除：`{"ledgerId":"<主键>"}`。
- 详情：`{"ledgerId":"<主键>"}`。

## 变更边界

- 本次只恢复组织查询，未改其请求和响应字段。
- 类目字典和板块字典接口保留。
- 台账查询、新增、修改、删除、详情、导出均未改。
- 数据库表和配置未改。
