# Excel 导出模板工作手册

> 适用范围：本工作区内所有新增、改造、修复 Excel 导出功能，以及 test/UAT/prod 的导出模板配置。  
> 强制关系：只要需求涉及 Excel 导出，使用 `enterprise-dev-workflow` 时必须同时执行本手册。  
> 目标：AI 自动完成配置，同时让落库结果、审计语义和页面保存一致；接口不可用时才使用可审计、可回退的 SQL 兜底。

## 1. 先判定能不能用平台模板

普通列表、台账、单行表头、一个 Sheet 的导出，默认必须使用平台字段模板：

```text
前端复用分页接口
  → exportRequest/exportTemplateCode/exportFileName
  → Controller @DataRequestTransfer + @ExportRequestTransfer
  → 返回 data.root
  → UBM 按 template_code 读取主模板和明细
  → 公共导出组件生成 XLSX
```

禁止为了省配置另写 Java 字段数组、EasyExcel 表头或独立下载接口。

以下情况平台字段模板目前无法直接表达，可以申请例外：

- 多行或合并表头；
- 单元格合并、公式、图片、批注；
- 多 Sheet；
- 对颜色、字体、边框、冻结窗格、打印版式有强制要求；
- 固定版式文件填充，而不是普通列表导出。

例外必须在需求 `10-拆解规划` 写明“为什么模板做不了、采用什么实现、如何验收、会不会影响其他导出”。产品只说“导出 Excel”不构成例外。

## 2. 页面保存的真实语义

管理页面新增时不传 `templateId`；后端还会清空每条明细的 `tmpId`，然后在一个事务里插入主表和明细。主表与明细实体均使用 MyBatis-Plus `IdType.ASSIGN_ID`，审计字段由公共 `MetaObjectHandler` 从当前登录人填充。

因此“像页面新增”不是只看表里列齐不齐，而是同时满足：

- ID 由目标环境后端生成；
- 创建/修改人是实际授权登录人；
- 创建/修改时间是实际保存时间；
- `delete_sign=0`、`data_version=1`；
- 主表和所有明细在同一事务中成功；
- 保存服务检查 `template_code` 重复。

test 当前通常生成正 19 位 Snowflake ID；UAT 历史上启用过另一套生成器，存在负数 ID。**不能把“正 19 位”写成全环境规则，也不能把离线生成的正数冒充 UAT 页面结果。**正确规则是：优先让目标环境后端发号；SQL 兜底若无法调用同一生成器，只能称为“功能等价配置”，不得称为“页面同款 ID”。

## 3. 唯一机器源：模板定义 JSON

每个需求把模板定义保存在：

```text
docs/需求/<主题>/sql/00-导出模板定义.json
```

格式与 `scripts/examples/export-template-definition.json` 一致。定义中只写业务字段，不写以下后端字段：

```text
templateId/tmpId
createBy/createByName/createTime
updateBy/updateByName/updateTime
deleteSign/dataVersion
```

先运行：

```bash
bash scripts/export-template.sh validate docs/需求/<主题>/sql/00-导出模板定义.json
bash scripts/export-template.sh payload  docs/需求/<主题>/sql/00-导出模板定义.json
```

定义文件是 test/UAT/prod 的业务语义源；各环境的 ID、审计人和时间不是业务定义，不能互相复制。

## 4. 主表字段规则

目标表：`scm_ubm_<env>.scm_simple_template`。

| 字段 | 新模板规则 | 原因/注意 |
|---|---|---|
| `template_id` | 定义文件不写；页面同款接口由目标环境 `ASSIGN_ID` 生成 | 禁止英文业务 ID、UUID、跨环境复用；正负号不是功能判断依据 |
| `template_code` | 必填，ASCII 字母/数字/`_`/`-`，最长 32 | 前端、后端注解、主表、明细四处完全一致；DB 没有唯一索引，必须主动查重 |
| `template_desc` | 必填，最长 32 | 不照抄别的业务描述 |
| `group_code/group_name` | 必填，各最长 32，照同业务域已有页面模板 | 不凭模块中文名猜编码 |
| `status` | 新建固定 `1` | 当前读取链路没有可靠地用状态过滤，不能拿停用状态当隔离手段 |
| `check_code` | 普通导出固定空字符串 | 启用时索引规则容易写错，只能复用已验证同款并实导 |
| `enable_check_code` | 普通导出固定字符串 `false` | 不是 JSON boolean；页面控件传字符串 |
| 审计字段 | 实际授权操作人、实际执行时间 | 禁止复制任意同事、伪造 `system`、照抄旧时间 |
| `delete_sign/data_version` | 新建为 `0/1` | 由页面保存后端自动填充 |
| `file_name/data_scan_limit` | 普通同步导出保持 `NULL` | 当前管理页面不采集、当前简单模板实体也不保存；文件名来自导出请求 |

修改已有模板时：保留主 ID 和创建信息，修改人/时间必须更新，版本按平台规则递增。不能用新的 INSERT 假装修改。

## 5. 明细字段规则

目标表：`scm_ubm_<env>.scm_simple_template_sub`。

| 字段 | 规则 |
|---|---|
| `tmp_id` | 定义文件不写；每条明细由目标环境后端单独生成 |
| `template_id` | 必须等于主模板 ID |
| `template_code/group_code` | 必须和主表一致 |
| `sort_name` | 纯数字、唯一、连续；有序号列时 `INDEX=0`，其余从 1 开始；无序号列时从 1 开始 |
| `field_name` | 接口最终 JSON 字段名，不是数据库列名；最长 64，默认唯一 |
| `field_val` | Excel 表头文字，最长 64；逐字核产品标题 |
| `field_type` | 新配置只用 `String/Date/BigDecimal/Integer/Long` |
| `status` | 新建固定 `1` |
| 审计/删除/版本 | 和主表同一实际操作语义，新建为有效记录、版本 1 |

特殊字段：

- `INDEX`：公共组件按当前数据行生成 `1、2、3...`；字段类型填 `String`。
- `CHECK_CODE`：只有明确启用校验码时使用；`check_code` 是字段数组索引列表，不确认索引口径时禁止猜。
- 日期：优先绑定 `xxxStr` 等格式化后的最终字段，并填 `String`。原始 `java.util.Date` 可能导出成英文 CST 长串。
- 字典/枚举：绑定 `xxxDesc` 等描述字段，不直接导出编码，除非产品明确要求编码。
- 金额：绑定接口实际返回字段；Excel 内容还要检查精度、科学计数法和空值。

当前简单导出最终把二维字符串列表交给 EasyExcel，`field_type` 不能替代实际文件检查。

## 6. 前后端代码检查

四个位置必须对齐：

| 位置 | 检查内容 |
|---|---|
| 前端 | 复用分页接口；请求带 `exportRequest`、`exportTemplateCode`、`exportFileName` 和与列表相同的查询条件 |
| 后端请求转换 | 分页方法存在 `@DataRequestTransfer(exportValue={@ExportRequestTransfer(...)})`；默认编码或前端编码明确 |
| 后端返回 | 导出时结果仍位于 `data.root`；`field_name` 在最终序列化 JSON 中真实存在 |
| 数据库模板 | 主表和每条明细的编码、分组、状态、排序与定义文件一致 |

额外边界：

- 简单导出公共实现超过 50,000 个 `sources` 会拒绝；表头也占一个，因此当前最多 49,999 条数据。接口注解写 100,000 不代表最终能导出 100,000。
- 模板不存在或没有有效明细时，公共实现可能直接返回而不是给出清晰错误；所以配置验证必须先于业务下载。
- 平台字段模板本身不保存表头背景色、加粗字体等样式。看到样式不同先确认实际走的是平台模板链路还是旧 Java 导出链路。

## 7. AI 自动配置流程

### 7.1 test

```bash
bash scripts/export-template.sh validate docs/需求/<主题>/sql/00-导出模板定义.json
bash scripts/export-template.sh inspect test <templateCode>
bash scripts/export-template.sh apply test docs/需求/<主题>/sql/00-导出模板定义.json \
  --confirm-write \
  --rollback docs/需求/<主题>/sql/03-test-导出模板回滚.sql
bash scripts/export-template.sh verify test docs/需求/<主题>/sql/00-导出模板定义.json
```

`apply` 只新建：

- 编码不存在：调用页面同款保存接口，成功后生成带精确主/明细 ID 的回滚 SQL，再反查验证。
- 编码存在且定义完全相同：幂等成功，不写库。
- 编码存在但不同或存在多条：拒绝覆盖，转“修改已有模板”专项。

### 7.2 UAT

test 实导验收通过、配置定义冻结后再执行：

```bash
bash scripts/export-template.sh apply uat docs/需求/<主题>/sql/00-导出模板定义.json \
  --confirm-write --confirm-uat \
  --rollback docs/需求/<主题>/sql/04-uat-导出模板回滚.sql
bash scripts/export-template.sh diff test uat <templateCode>
bash scripts/export-template.sh verify uat docs/需求/<主题>/sql/00-导出模板定义.json
```

UAT 写入必须有用户当次明确授权。跨环境 `diff` 比较业务语义，忽略 ID、审计人和时间。

### 7.3 prod

AI 不查询、不写入 prod。交付内容包括：

- 冻结后的定义 JSON；
- 页面逐字段配置清单，或经评审的 prod SQL；
- 执行前检查、回滚脚本；
- 实际 XLSX 验收清单。

## 8. 修改已有模板

修改比新建危险：页面更新会保留主 ID，但逻辑删除旧明细并生成一批新明细 ID；数据库没有外键，历史上已出现孤儿和重复明细。

固定顺序：

1. `inspect` 保存主表和全部明细现状。
2. 生成能恢复主表、旧明细 ID、字段、状态、审计和版本的完整回滚 SQL。
3. 明确目标环境、目标编码和期望列数；查有效主模板必须恰好一条。
4. 再调用页面修改接口；禁止 `REPLACE INTO`、`INSERT IGNORE`、无条件 `ON DUPLICATE KEY UPDATE`。
5. DB、详情接口和实际 XLSX 全部验证。
6. 页面“删除后重建”不是回滚方案：当前删除服务只处理主表，可能留下明细孤儿。

当前 `export-template.sh apply` 故意拒绝覆盖已有差异；没有完整回滚方案时，不自动化修改。

## 9. SQL 兜底

只有页面同款接口不可用，且需求确实要继续时才允许直接 SQL。文档必须明确标注“SQL 兜底”及不能复现的页面语义。

SQL 必须包含：

1. `SHOW CREATE TABLE` 已核对的字段清单。
2. 执行环境和库名，禁止用未解析变量指向库。
3. 执行前检查：有效编码数量为 0、所有目标 ID 在主/明细两表均不碰撞、字段长度合法。
4. `START TRANSACTION`；先主表后全部明细。
5. ID 来自团队批准的目标环境生成方式；无法取得时显式写“功能等价 ID”，禁止假称页面生成。
6. 审计人来自实际授权执行人，时间为实际执行时间。
7. 主/明细编码、分组、状态、排序、关联和预期列数的执行后检查。
8. `ready_to_commit` 汇总；默认不内置 `COMMIT`，结果正确后在同一会话手工提交。
9. 独立回滚 SQL；新建回滚按精确 ID 删除本次新增的明细和主表，修改回滚恢复完整旧快照。

禁止：

- 英文业务主键、UUID、跨环境复制 ID；
- 复制任意同事或 `system` 当审计人；
- 固定历史时间；
- 只插主表或只按 `template_code` 插明细；
- 用 `INSERT IGNORE/REPLACE` 掩盖冲突；
- 主表编码重复时继续执行；
- 把 test SQL 原样重放到 UAT/prod。

## 10. 验收清单

每个环境逐项完成：

- [ ] 定义 JSON 通过 `validate`。
- [ ] 有效主模板恰好一条，明细数等于定义列数。
- [ ] 主子 ID 关联、编码、分组、排序、状态、审计、删除标记、版本正常。
- [ ] 无重复排序、重复字段和目标模板孤儿明细。
- [ ] 模板详情接口返回全部列且顺序正确。
- [ ] 业务接口不带导出参数时，列表仍正常。
- [ ] 实际下载的文件是有效 XLSX，不是 JSON/空响应伪装的 200。
- [ ] 表头、列序、行数和筛选条件与列表一致。
- [ ] `INDEX`、日期、金额、字典描述、空值逐项检查。
- [ ] 空数据能导出预期表头；接近上限的行为已确认。
- [ ] 如有样式要求，验收结果符合已确认的例外方案。
- [ ] test/UAT 语义 `diff` 通过；环境 ID、审计、时间允许不同。
- [ ] 回滚文件存在且执行条件明确。

只有以上结果进入 `30-测试报告`，才能写“导出验收通过”。
