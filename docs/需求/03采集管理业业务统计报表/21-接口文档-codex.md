# 集采管理业务统计报表 · 接口文档

> 日期：2026-07-22
> 工具：codex
> 当前状态：接口代码和协议已完成本地编译验证；report 接口尚未部署，test 当前返回 404。
> 下一阶段：部署 report 后端后，按本文示例完成列表、组合筛选、权限和导出运行时验收。

## 1. 分页查询

```http
POST /e/business/report/source/centralizedProcurementPageList
Content-Type: application/json
```

请求示例：

```json
{
  "currentPage": 1,
  "limit": 10,
  "model": {
    "purchaseCompanyName": "企业简称",
    "supplierName": "供应商简称",
    "buCode": "BU002",
    "beginTime": 1783612800000,
    "endTime": 1783699199999
  }
}
```

筛选规则：

| 参数 | 含义 | 规则 |
|---|---|---|
| `purchaseCompanyName` | 采购企业 | IK 分词后所有输入词必须命中 |
| `supplierName` | 供应商 | IK 分词后所有输入词必须命中 |
| `buCode` | 所属板块编码 | 精确匹配 |
| `beginTime/endTime` | 公示/下单时间 | 毫秒时间戳，闭区间 |
| `dataSource` | 数据来源 | 可选，精确匹配 ZC/FP/YC/MT/JD |

成功响应的 `data` 为统一分页对象，前端使用：

```json
{
  "status": true,
  "data": {
    "root": [],
    "totalCount": 0,
    "currentPage": 1,
    "limit": 10
  }
}
```

数据默认按 `bookTime` 倒序，并沿用现有 report 数据权限，按登录人可见的 `purchaseCompanyCode` 过滤。

## 2. Excel 导出

```http
POST /e/business/report/source/centralizedProcurementDownload
Content-Type: application/json
```

请求体与分页接口一致。导出最多 10000 条，筛选条件和数据权限与分页查询完全复用。文件名为“集采管理业务统计报表.xlsx”，列顺序为：序号、板块名称、采购企业、供应商、采购方案/订单编号、业务名称、物料编码、物料描述、类目编码、类目描述、交易金额（含税）、公示/下单时间、是否集采、采购业务类型、数据来源。

## 3. 所属板块下拉

```http
POST /e/business/source/collectionDailyAmountLedger/queryOwningplateDict
Content-Type: application/json

{}
```

该接口已部署并实调成功。前端显示 `name`，提交 `code`。

## 4. 已有采集同步接口

```http
POST /e/business/source/centralizedProcurementReport/sync
Content-Type: application/json
```

```json
{
  "startTime": "2026-07-01 00:00:00",
  "endTime": "2026-07-01 23:59:59"
}
```

该接口会写 ES；日常补跑才使用。两个时间都不传时默认同步前一天。
