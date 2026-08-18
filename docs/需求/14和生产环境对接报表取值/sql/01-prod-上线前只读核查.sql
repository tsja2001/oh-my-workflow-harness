-- =====================================================================
-- 生产环境：集采业务管理报表及取值需求上线前只读核查
-- 日期：2026-08-18
--
-- 本文件只有 SELECT，不包含 DDL/DML，不会修改生产数据。
-- 本批需求不新增 MySQL 业务表；这里只核对 04 期的 5 张前置业务表，
-- 以及本次新增的 Excel 导出模板是否已存在。
-- =====================================================================

-- 1. 记录实际连接，执行人需人工确认这是生产连接。
SELECT DATABASE() AS current_database,
       @@hostname AS mysql_host,
       @@port AS mysql_port,
       NOW() AS check_time;

-- 2. 核对 04 期 5 张前置业务表。结果应为 5 行，且 table_exists 全为 1。
SELECT expected.table_schema,
       expected.table_name,
       CASE WHEN actual.table_name IS NULL THEN 0 ELSE 1 END AS table_exists
FROM (
    SELECT 'scm_source' AS table_schema, 'sc_collection_daily_amount_ledger' AS table_name
    UNION ALL SELECT 'scm_source', 'sc_coal_pit_daily_indicator'
    UNION ALL SELECT 'scm_source', 'sc_coal_pit_daily_indicator_item'
    UNION ALL SELECT 'scm_source', 'sc_price_trend'
    UNION ALL SELECT 'scm_order', 'to_central_purchase_daily_statistics'
) expected
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = expected.table_schema
 AND actual.table_name = expected.table_name
ORDER BY expected.table_schema, expected.table_name;

-- 3. 核对本次导出模板主记录。未配置时返回 0 行；已配置时只能有 1 条有效记录。
SELECT template_id,
       template_code,
       template_desc,
       group_code,
       group_name,
       status,
       check_code,
       enable_check_code,
       delete_sign,
       data_version
FROM scm_ubm.scm_simple_template
WHERE template_code = 'centralized-procurement-export'
  AND delete_sign = 0;

-- 4. 核对模板明细。已配置时应返回 15 行，sort_name 为 0～14，字段不能重复。
SELECT sort_name,
       field_name,
       field_val,
       field_type,
       status,
       template_code,
       group_code,
       delete_sign
FROM scm_ubm.scm_simple_template_sub
WHERE template_code = 'centralized-procurement-export'
  AND delete_sign = 0
ORDER BY CAST(sort_name AS UNSIGNED), tmp_id;

-- 5. 汇总判定：active_main_count 应为 0（待创建）或 1（已创建）；
--    已创建时 active_detail_count 必须为 15，重复字段和重复排序必须均为 0。
SELECT
  (SELECT COUNT(*)
     FROM scm_ubm.scm_simple_template
    WHERE template_code = 'centralized-procurement-export'
      AND delete_sign = 0) AS active_main_count,
  (SELECT COUNT(*)
     FROM scm_ubm.scm_simple_template_sub
    WHERE template_code = 'centralized-procurement-export'
      AND delete_sign = 0) AS active_detail_count,
  (SELECT COUNT(*)
     FROM (
       SELECT field_name
         FROM scm_ubm.scm_simple_template_sub
        WHERE template_code = 'centralized-procurement-export'
          AND delete_sign = 0
        GROUP BY field_name
       HAVING COUNT(*) > 1
     ) duplicated_fields) AS duplicated_field_count,
  (SELECT COUNT(*)
     FROM (
       SELECT sort_name
         FROM scm_ubm.scm_simple_template_sub
        WHERE template_code = 'centralized-procurement-export'
          AND delete_sign = 0
        GROUP BY sort_name
       HAVING COUNT(*) > 1
     ) duplicated_sorts) AS duplicated_sort_count;
