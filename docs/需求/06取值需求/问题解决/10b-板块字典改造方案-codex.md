# 集团整体集采规模 · 板块字典改造方案

> 本文取代 `10-板块字典取值调查-codex.md` 中“是否需要改首页”的待确认判断，取代原因：产品已明确确认“集团整体集采规模”下的集团名称要从字典取值。  
> 日期：2026-08-12  
> 工具：codex  
> 当前状态：改造范围和技术方案已明确，本次未改代码。  
> 下一步：按本文修改 `scm-source-all` 后端和 `scm-vue-hpc` 前端，再做接口对照和前端构建验证。

## 一句话方案

**六个集团仍按需求规定的固定 `buCode` 计算金额，但显示名称统一由后端根据 `buCode` 查询 `Owningplate` 字典；前端只展示后端返回的名称，不再自己写死名称。**

“直管单位”是“六个集团以外全部板块”的计算分组，不是一个真实板块，也没有 `Owningplate` 字典编码，因此继续固定显示“直管单位”。

## 为什么不能直接把整份字典都展示出来

当前需求只点名六个集团：

| 展示分组 | 板块编码 |
|---|---|
| 水泥集团 | BU002 |
| 地产集团 | BU006 |
| 新材产业化集团 | BU005 |
| 投资物业集团 | BU007 |
| 冀东发展集团 | BU004 |
| 天津建材集团 | BU008 |
| 直管单位 | 上述六个编码之外的全部板块 |

依据：`docs/需求/06取值需求/13-需求定稿-开发基线-cc.md:127-136、154-165`。

字典里还存在 BU001、BU003、BU009、BU010，UAT 还有 BU011、BU013。它们按现有需求都应汇总进“直管单位”。因此：

- **字典决定名称**；
- **固定的六个 `buCode` 决定显示哪些集团以及金额怎么算**；
- 不能遍历整份字典动态生成卡片，否则会改变已经确认的业务口径。

## 后端改法

改动文件：

`01zhaocai-end/scm-source-all/scm-source-chase/src/main/java/com/pcitc/scm/source/chase/service/impl/CentralizedProcurementPortalServiceImpl.java`

1. 复用同模块 `CentralizedProcurementReportServiceImpl` 已有做法，注入 `DictFeignService` 和 `InnerFeignService`，查询字典类型 `Owningplate`。
2. 把当前 `NAMED_GROUPS` 的“编码+写死名称”改成只保留六个固定编码，顺序不变。
3. `overview()` 每次页面请求只查询一次字典，生成 `buCode -> label` 对照表；不能在六个集团循环里查六次。
4. 组装 `groups` 返回值时，根据 `buCode` 从字典对照表取 `name`。字典名称取值前去掉首尾空白，避免配置里的 Tab 或空格进入页面。
5. 字典服务异常或某个编码缺少名称时，金额接口不能整体失败：记录告警，并暂时用该 `buCode` 作为页面名称，例如显示 `BU002`。这样不会拿代码里的旧名称伪装成字典值，也不会影响金额展示。
6. `ZG` 继续返回固定名称“直管单位”。它是计算分组，不去 `Owningplate` 查找。

金额计算逻辑不改。当前后端本来就是用 `buCode` 查询 ES：`CentralizedProcurementPortalServiceImpl.java:137-142、191-208`，本次只替换响应中的 `group.name` 来源。

## 前端改法

改动文件：

`02zhaocai-front/scm-vue-hpc/src/views/procurementPortal/components/OfficeTransaction.vue`

1. 删除 `groupMeta` 中写死的六个集团名称和“直管单位”名称。
2. `groupCards` 直接按后端 `groups` 数组生成卡片，名称使用 `group.name`，金额使用 `group.amount`。
3. 卡片的 Vue `key` 改用稳定的 `group.buCode`，不能再用可能随字典变化的名称。
4. 后端已按六个固定编码顺序返回，并把直管放最后，前端沿用接口顺序，不再维护第二份顺序和名称配置。

`GroupRanking.vue` 已经使用后端返回的 `group.name`，无需修改。

## 接口约定

接口路径不变：

`POST /e/business/source/centralizedProcurementPortal/overview`

响应结构也不变，只改变 `groups[].name` 的来源：

```json
{
  "groups": [
    { "buCode": "BU002", "name": "字典中 BU002 的名称", "amount": 0, "rate": 0 },
    { "buCode": "ZG", "name": "直管单位", "amount": 0, "rate": 0 }
  ]
}
```

不新增接口、不改数据库、不改 ES 数据，也不需要重跑同步任务。

## 验收办法

1. 调现有板块字典接口和首页汇总接口，核对六个编码的名称逐一相等：
   - 字典：`POST /e/business/source/collectionDailyAmountLedger/queryOwningplateDict`
   - 首页：`POST /e/business/source/centralizedProcurementPortal/overview`
2. 保存改动前后的首页响应，确认六个集团及直管单位的 `amount/rate` 完全不变，只有 `name` 可能变化。
3. 验证“直管单位”仍在最后，字典里的其他板块没有被新增成独立卡片。
4. 验证金额卡和“二级集团集采率排名”显示同一套字典名称。
5. 后端做目标 Java 文件隔离编译，前端做生产构建。

## 改动范围

- 后端一个文件：查询字典并给六个固定编码填名称。
- 前端一个文件：删除重复写死的名称，使用接口名称。
- 不改金额公式、不改集团归属、不改字典配置、不改 ES、不需要重新同步历史数据。
