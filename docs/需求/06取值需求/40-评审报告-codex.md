# 集采门户首页取值（06）· 代码评审报告

> 日期：2026-08-05
> 工具：codex
> 当前状态：**前后端代码阻塞项已全部处理，可进入推送、部署和 test 联调；尚不能称为已上线验收。**
> 下一阶段：用户决定推送和部署时点；部署后复验网关接口、真实页面，并用受控数据验证 D2。

> 评审对象：后端 `scm-source-all/feature/jicai-portal-yang@89be56b57`（连同基础 `ade85c7f6`、cockpit `1f419cc84`、D2 `759884d47`）；前端 `scm-vue-hpc/feature/quzhi-yang@292fbcd`。
> 口径基线：`13-需求定稿-开发基线-cc.md`。`public/statics/config.js` 可能含令牌，仅确认它未被提交，未展开内容。

## 结论

- **代码层面无剩余阻塞项**：原评审的 ES 53 次查询、错误伪装成 0、钢材月指标空白、本地代理/敏感配置、固定 2026 起点、缺 `buCode` 告警、业务假数/两位小数和 MT 供应商编码均已处理。
- **本地运行证据完整**：后端隔离编译、fat jar 构建、Spring 启动和真实 ES overview 调用通过；前端生产构建及浏览器成功/失败/重试三态通过。
- **仍有非代码验收项**：test 的 3.6 亿 FP 垃圾数据尚未清理，D2 没有北分 FP 样本，代码也尚未推送/部署；这些不应被写成“代码 bug”，但会影响最终业务数字和验收结论。

## 发现清单

| # | 文件:行 | 复评结论 | 处理结果 | 严重程度 | 把握度 |
|---|---|---|---|---|---|
| 1 | `CentralizedProcurementPortalServiceImpl.java:132-160,364-391` | overview 现在把全部指标装进命名 `filters + sum`，整个方法只执行一次 `restTemplate.search()`；2026 实调结果与改造前逐项一致。 | **已处理** | 原阻塞 | 高 |
| 2 | `CentralizedProcurementPortalServiceImpl.java:127-130,411-416` | 年度/累计固定从 2026-01-01 起；同一次聚合统计缺失/空 `buCode`，命中时记录笔数和金额。2027 查询日运行验证仍返回 2026 起累计值。 | **已处理** | 原建议 | 高 |
| 3 | `CentralizedProcurementPortalServiceImpl.java:187-191` | D2 仅从水泥集团 BU002 扣减，筛选条件包含北分 FP 统一社会信用代码；非水泥集团不扣。 | **代码已处理，待样本验证** | 数据验收项 | 高 |
| 4 | `CentralizedProcurementReportServiceImpl.java:130-135,596-598` | MT 同步现写入固定供应商编码 `CN11005095`；供应商名称仍沿用 03 既定值，避免在法人名称未确认时擅改。 | **已处理** | 原建议 | 高 |
| 5 | `overviewStore.js:18-66`、`index.vue:28-30,96-106` | 前端明确区分未加载、成功和失败；失败清空旧值、展示告警和 `--`，可点击重新加载；只有响应中的真实 0 显示 `0.00`。 | **已处理** | 原阻塞 | 高 |
| 6 | `CoalTransaction.vue`、`SteelTransaction.vue` | 煤/钢金额读 overview；价格空值不转 0；钢材最新月份的螺纹/中厚板正确映射到月指标，无值显示 `--`。 | **已处理** | 原阻塞 | 高 |
| 7 | `data.js:1-27` 及门户各激活组件 | 业务 mock 数字和随机圆环已清，金额统一千分位与两位小数；浏览器验证 `0.20`、`0.00`、`14,143.72` 均正确，旧假数 `47,688.16` 不存在。 | **已处理** | 原建议 | 高 |
| 8 | `vue.config.js`、`public/statics/config.js` | 本地 8110 代理未进入最终差异；敏感配置仍只作为本机未提交修改存在，前端提交只含 9 个业务文件。 | **已处理** | 原提交阻塞 | 高 |

## 检查过的维度

- [x] 正确性：时间左闭右开、固定业务起点、D1/D2/D3、分集团、品类、负数、金额/比率精度、空聚合、失败/重试状态。
- [x] 与样板一致性：网关 POST 路径、`Result.success`、Spring Data ES 聚合解析、Vue 2 与 `scm-request` 调用方式。
- [x] 安全：未发现凭据进入代码或提交；敏感 `public/statics/config.js` 保持未提交且未读取内容。
- [x] 影响面：overview 改动集中在 `scm-source-chase`；cockpit 只分流 `kengk/mt/gc`；前端只提交集采门户目录文件，未带全局代理配置。

## 验证记录

1. 后端隔离编译：`CentralizedProcurementPortalServiceImpl.java`、`CentralizedProcurementReportServiceImpl.java`，`javac exit 0`、总错误 0。
2. 后端构建/启动：`scripts/srun.sh build scm-source-chase` 成功生成 fat jar；本地 8110 Spring 服务启动成功，测试后已停止。
3. 真实接口：`queryDate=2026-08-03` 返回平台 50776.09万、年度集采 14143.72万、集采率 27.86%、煤 14121.28万、钢 1.47万、办公 4.98万；`queryDate=2027-01-02` 年度/累计仍从 2026 起算。
4. 前端构建：Node 14.21.3 / npm 6.14.18 下 `npm run build` 成功；仅有项目既有包体积和 Browserslist 更新提示。
5. 浏览器：受控 overview 成功响应能显示真实 0、两位小数和千分位；HTTP 500 时出现明确告警、关键数字变 `--`；切回成功响应点击“重新加载”后告警消失、数值恢复。

## 非代码遗留

1. 未经用户授权，不清 test ES 的 3.6 亿 FP 测试垃圾；它会继续把集采率压到 27.86%。
2. test 当前没有 `supplierCode=9111010577406207XG` 的 FP 北分样本；需准备“北分煤炭 + 其他供应商煤炭”受控样本证明只扣北分。
3. 两个提交均未推送，test 未部署；FP/ZC/MT/JD 同步调度任务仍需用户在管理页面配置。
