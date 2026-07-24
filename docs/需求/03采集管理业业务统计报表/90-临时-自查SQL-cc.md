# 采购业务分类字段自查 SQL（给用户自己看数据用）

> 日期：2026-07-23 ｜ 工具：cc
> 用途：用户想自己进数据库确认"采购业务分类为什么基本都是空的"。
> 连接信息在 `ai-docs/creds.env`（gitignore，不往这里抄）。

## 库和表

| 库名 | 存什么 |
|---|---|
| `scm_source_test` | 业务数据。非平台录入主表 `sc_supplier_green_channel`、物料明细表 `sc_supplier_channel_projects` |
| `scm_ubm_test` | 字典。表 `ubm_dict`，本次相关的字典类型是 `purchase_business_type` |

主机/端口/账号/密码看 `ai-docs/creds.env` 的 `DB_HOST` `DB_PORT` `DB_USER` `DB_PASS`。

## 不想配客户端就直接跑这个（自动读 creds.env）

```bash
cd /home/t/projects/work-wsl && bash scripts/dbq.sh "把下面任意一条 SQL 贴这儿" scm_source_test
```

---

## 1. 字典是怎么定义的（跑在 scm_ubm_test）

```sql
SELECT dict_code, dict_name, dict_status, create_time
FROM ubm_dict WHERE dict_type_code = 'purchase_business_type' ORDER BY dict_code;
```

预期：101 集团集采 / 102 二级集团集采 / 103 区域集采 / 104 分散采购，建于 2026-06-22。

## 2. 全表有多少单填了这个字段（核心证据）

```sql
SELECT CASE WHEN purchase_business_type IS NULL THEN '空' ELSE '有值' END AS 分类,
       COUNT(*) AS 单数, MIN(create_time) AS 最早建单, MAX(create_time) AS 最晚建单
FROM sc_supplier_green_channel GROUP BY 分类;
```

预期：有值 7 单（6/24~6/30），空 304 单（2023 年至 7/15）。
7 单的时间窗口正好卡在前端"6/23 加录入框 ~ 7/3 注释掉"之间。

## 3. 有值的那 7 单具体是哪些

```sql
SELECT purchase_business_code, purchase_business_name,
       purchase_business_type, purchase_business_type_desc,
       is_jc, approve_status, create_time
FROM sc_supplier_green_channel
WHERE purchase_business_type IS NOT NULL ORDER BY create_time;
```

## 4. 7/3 之后新建的单是不是又空了

```sql
SELECT purchase_business_code, purchase_business_name,
       purchase_business_type, is_jc, create_time
FROM sc_supplier_green_channel
WHERE create_time >= '2026-07-03' ORDER BY create_time DESC;
```

预期：分类全空（证明"新数据也不会有值"）。

## 5. 报表现在为什么只出 5 条

```sql
SELECT g.approve_status AS 审批状态, g.purchase_business_type AS 业务分类,
       g.purchase_business_type_desc AS 分类名, COUNT(*) AS 单数
FROM sc_supplier_green_channel g
WHERE g.update_time >= '2026-01-01'
GROUP BY g.approve_status, g.purchase_business_type, g.purchase_business_type_desc;
```

预期：审批通过(101) 的有 31 单，其中分类=101 的 1 单、102 的 4 单、104 的 1 单、**空的 25 单**。
报表只要 101/102/103 → 只剩 5 单。

## 6. 三种口径分别能出多少行

```sql
SELECT '现在: 分类=集采三类' AS 口径, COUNT(p.projects_id) AS 物料行数
FROM sc_supplier_green_channel g JOIN sc_supplier_channel_projects p ON p.channel_id=g.channel_id
WHERE g.approve_status=101 AND g.update_time>='2026-01-01'
  AND g.purchase_business_type IN ('101','102','103')
UNION ALL
SELECT '方案B: 分类为空时看是否集采', COUNT(p.projects_id)
FROM sc_supplier_green_channel g JOIN sc_supplier_channel_projects p ON p.channel_id=g.channel_id
WHERE g.approve_status=101 AND g.update_time>='2026-01-01'
  AND (g.purchase_business_type IN ('101','102','103')
       OR ((g.purchase_business_type IS NULL OR g.purchase_business_type='') AND g.is_jc=1))
UNION ALL
SELECT '方案C: 不看分类全要', COUNT(p.projects_id)
FROM sc_supplier_green_channel g JOIN sc_supplier_channel_projects p ON p.channel_id=g.channel_id
WHERE g.approve_status=101 AND g.update_time>='2026-01-01';
```

预期：5 / 7 / 36。

## 7. 产品那单测试数据为什么进不来

```sql
SELECT g.purchase_business_code, g.purchase_business_name, g.approve_status,
       g.purchase_business_type AS 分类, g.is_jc AS 是否集采, g.update_time,
       p.product_code, p.product_desc, p.total_price
FROM sc_supplier_green_channel g
JOIN sc_supplier_channel_projects p ON p.channel_id = g.channel_id
WHERE g.purchase_business_code = '10930000-DY-FPT-2026-0001';
```

预期：审批通过、是否集采=是、**分类是空的**、2 条物料。就是被分类这一关挡掉的。

---

## 几个查数据时容易踩的坑

- `sc_supplier_green_channel` 和 `sc_supplier_channel_projects` **都没有 `delete_sign` 字段**，别加这个条件，加了直接报错。
- `approve_status` 是数字类型，`=101` 就行，`='101'` 也能匹配但别写成 `'审批通过'`。
- 字典表在**另一个库** `scm_ubm_test`，字段是 `dict_type_code`/`dict_code`/`dict_name`（不是 `type_code`/`dict_value`）。
- 时间统一用 `update_time`（报表把它当"审批结束时间"），不是 `create_time`。
