# 云采板块列显示全称 · 根因调查

> 日期：2026-08-11
> 工具：oc
> 当前状态：根因已核实、修复代码已按方案 A 落地（`scm-order-all` 分支 `fix/jicai-report-umb-yang@f4e45eeff`，本地提交未推送，隔离编译 0 报错）。
> 下一步：用户推送分支 → 合 test → 点 Jenkins 部署 scm-order-all → 调 `syncToEs` 重跑 2026 年至今覆盖存量 → test 页面核对 → uat 同样走一遍。
>
> 本文是 `90-临时-云采板块名称不一致排查-codex.md`（2026-07-23）的后续扩大版：当时只发现 2 条 BU002/冀东水泥，本次反馈覆盖更多板块、还出现了全称。

## 反馈原文（节选）

> 板块信息部分显示全称，比如出现了"北京金隅新型建材产业化集团有限公司"等好几个不在所属板块字典里的值。我看好像都是云采的吧。

**属实。** test 库 ES 中 10 条 YC 数据有 8 条板块名称与字典标准名不一致（列表见下）。"都是云采"判断正确。

## 一句话结论

**云采写入侧写 ES 时，板块名称直接抄了组织系统返回的 `belongBuName` 原值，没像其他四个来源那样按 `buCode` 查 Owningplate 字典换成标准名。而组织系统里这个字段本身就是脏的（有的填公司全称、有的填非标准简称、有的才是标准名），所以页面上出现了字典里没有的全称。** 筛选不受影响（按编码筛），纯显示问题。

## 证据链

### 1. ES 里 YC 数据的板块名（test，10 条）

`index_centralized_procurement_report_test`，`dataSource=YC`，按 buCode/buName：

| 记录 | buCode | ES 里的 buName | 字典标准名 | 一致? |
|---|---|---|---|---|
| PO2607280001、PO2607280003 | BU006 | **北京金隅地产开发集团有限公司** | 地产集团 | ✗ 全称 |
| PO2606250001/0002、PO2607270002/0003 | BU002 | **冀东水泥** | 水泥集团 | ✗ |
| PO2607280002、PO2608010001 | BU004 | **冀东集团** | 冀东发展集团 | ✗ |
| PO2608010002、PO2607310001 | BU006 | 地产集团 | 地产集团 | ✓ |

同一条公司（唐山盾石房地产开发有限公司）在 07-28 两单写的是全称、07-31/08-01 两单却是标准名——说明组织库里这个字段**后来被人工修过**，但 ES 存量没重跑同步，旧的脏值一直留着。

### 2. 字典标准名（test）

`scm_ubm_test.ubm_dict WHERE dict_type_code='Owningplate'`，共 10 个：BU001 金隅集团 / BU002 水泥集团 / BU003 混凝土集团 / BU004 冀东发展集团 / BU005 新材产业化集团 / BU006 地产集团 / BU007 投资物业集团 / BU008 天津建材集团 / BU009 财务公司 / BU010 北京建研总院。

### 3. 组织表 belong_bu_name 本身是脏的

`scm_ubm_test.ubm_organization_manage` 实测：

| org_code | org_name | belong_bu_code | belong_bu_name |
|---|---|---|---|
| 18001000 | **北京金隅新型建材产业化集团有限公司** | BU005 | **北京金隅新型建材产业化集团有限公司**（全称）|
| 18002000 | 北京金隅地产开发集团有限公司 | BU006 | 北京金隅地产开发集团有限公司（全称）|
| 18002016 | 北京金隅地产开发集团有限公司北京管理中心 | BU006 | 北京金隅地产开发集团有限公司（全称）|
| 12000000 | 唐山盾石房地产开发有限公司 | BU006 | 地产集团（标准）|
| 18002075 | 北京金隅地产开发集团有限公司天津管理中心 | BU006 | 地产集团（标准）|
| 11761000 | 唐山盾石建筑工程有限责任公司 | BU004 | 冀东集团（非标准简称）|

用户反馈的"北京金隅新型建材产业化集团有限公司"就是 org 18001000（BU005），**推断**：UAT 只要有该公司下的云采订单，写进 ES 的板块名就是全称（UAT ES 无凭据未直查）。

### 4. 写入侧代码（问题所在）

- 云采：`01zhaocai-end/scm-order-all` `CentralizedProcurementReportServiceImpl.java:308-311` 调 `getBuInfoByCompanyId`（:335-362），**原样取组织接口返回的 belongBuName/belongBuCode 写 ES**，没有字典归一。该文件只有 1 个提交 `1f6fd0093 集采管理业务统计报表-云采`，尚无修复。
- 其他四路（FP/ZC/JD/MT）：`01zhaocai-end/scm-source-all` `scm-source-chase/CentralizedProcurementReportServiceImpl.java:886-893` 的 `resolveBuName()`：**按 buCode 查 Owningplate 字典取标准名，字典查不到才回退原名**，在 :258/:453/:577/:677 四处调用。对照验证：ES 中 ZC 数据板块名全部是标准名（水泥集团/冀东发展集团）。

### 5. 读取侧代码（只是原样显示）

`01zhaocai-end/scm-report-all` `SourceMetaQueryServiceImpl.java:1588`（列表）`:1726`（导出）直接输出 ES 的 buName；下拉框选项走 Owningplate 字典（`SourceCockpitQueryServiceImpl.java:356` nameTrans）。所以"下拉里没有、列表里有"。

## 修复方案（推荐）

沿用其他四路已统一的做法，改**云采写入侧**一处：

1. 在 `getBuInfoByCompanyId` 取到 `belongBuCode` 后，按 Owningplate 字典换成标准名写 `buName`；字典查不到再回退 `belongBuName`（照抄 `scm-source-chase` 的 `resolveBuName` 写法）。
2. 修完重跑 YC 同步覆盖存量：`POST /d/business/order/centralizedProcurementReport/syncToEs`（`CentralizedProcurementReportController.java:35`），时间范围覆盖 2026 年至今。ES 主键 = 订单号_物料编码（`convertToModel:269`），稳定不变，重跑同 id 覆盖、不会新增重复。
3. test 修完验证 → uat 部署 → 同样重跑 uat 同步。
4. 组织表 belong_bu_name 的脏值**不建议顺手改**：那是主数据，人工维护还会再脏，且影响其他系统；报表侧按编码走字典后就不再依赖它。

备选方案（不推荐）：读取侧按 buCode 现查字典显示——影响所有来源且与其他四路已归一逻辑重复；修组织数据——治标不治本，还扩到报表外。
