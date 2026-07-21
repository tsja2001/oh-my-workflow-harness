# 集采管理业务统计报表（第一期：非平台录入）· 待确认问题

> 日期：2026-07-20
> 工具：codex
> 当前状态：FP 写入侧的公共 Model、实际 test 索引名和跨仓库协作方式均已确认，当前没有阻塞开发的待确认问题。
> 下一阶段：从 `scm-source-all` 最新 `prod` 创建本需求 feature 分支并进入开发；部署后再验收实际 mapping。
>
> **本文取代 `11-待确认问题-cc.md`。**

## 已确认结果

1. test 实际 ES 索引名为 `index_centralized_procurement_report_test`。
2. `scm-order-all` 与 `scm-source-all` 是两个独立 Git 仓库；双方各自在自己的服务新增 Model，不会修改同一 Java 文件，因此没有 Git 合并冲突。
3. 双方共享的是字段名、字段类型、主键规则和物理索引名，不是共用一个 Java 文件。
4. 同事订单侧使用 `orderESConfig` 并先部署创建索引；我方 source 侧使用 `sourceChaseConfig`、设置 `createIndex=false`，只写 `FP`。
5. 我方 source 配置项拟使用：

```properties
source.chase.es.centralizedProcurementReportIndex=index_centralized_procurement_report_test
```

该值来自环境配置，Java 代码不直接写死 `_test` 索引名；以后 uat/prod 只需更换对应环境的配置值。

## “没有 Git 冲突”不等于什么都不用统一

Git 冲突只会发生在两个人合并同一仓库、同一文件的重叠修改时。本需求两个服务各有自己的 Git 仓库和 Model 文件，因此不会发生这种冲突。

仍然必须保持下面四项一致，否则产生的是运行问题而不是 Git 冲突：

1. 两边最终指向同一个 ES 索引。
2. Model 字段名与 ES 类型一致。
3. `id` 都使用 `planCode + materialCode`。
4. 数据来源使用约定编码 `ZC/FP/YC/MT/JD`，我方固定写 `FP`。

## 部署阶段再验收

1. 同事订单侧应用启动后，确认出现 `index_centralized_procurement_report_test`。
2. AI 使用 `scripts/esq.sh` 核对实际 mapping 是否与公共 Model 一致。
3. 确认首批文档的数据来源不是 `FP`，再部署我方 source 服务写入 FP 数据。
4. 若同事后续修改公共 Model，只需把改动后的字段或 commit 发给 AI 做差异核对，不需要双方共用分支。
