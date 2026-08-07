-- 仅用于 scm_source_test，禁止在生产环境执行。
-- 目的：修正 5 条早期机电接口测试数据的板块编码，使其与 Owningplate 正式字典一致。
-- 业务字段、金额、流水号、审计字段均不修改。
--
-- 修改前快照（2026-07-27）：
-- JCRJE-20260709-001 | SNJT | 水泥集团
-- JCRJE-20260709-002 | SNJT | 水泥集团
-- JCRJE-20260709-003 | SNJT | 水泥集团
-- JCRJE-20260709-006 | SNJT | 水泥集团
-- JCRJE-20260709-007 | HNT  | 混凝土集团
--
-- 2026-07-27 test 执行结果：
-- 1. 事务试跑命中 5 条，随后 ROLLBACK，原值恢复。
-- 2. 正式执行 affected_rows=5。
-- 3. 修改后 BU002=4 条/14745.93，BU003=1 条/35600.00，总额 50345.93。
-- 4. 重跑 syncJd 后 ES：JD=5、MT=0；report：BU002=4、BU003=1、SNJT=0、HNT=0。
-- 5. 非目标记录 JCRJE-20260709-008（质量公司，SNJT）保持不变。

-- 执行前核对：必须严格返回 5 条、金额合计 50345.93。
SELECT COUNT(*) AS target_rows,
       COUNT(DISTINCT ledger_no) AS distinct_ids,
       ROUND(SUM(tax_amount), 2) AS tax_sum
FROM sc_collection_daily_amount_ledger
WHERE delete_sign = 0
  AND execute_unit_name = '机电公司'
  AND (
    (
      ledger_no IN (
        'JCRJE-20260709-001',
        'JCRJE-20260709-002',
        'JCRJE-20260709-003',
        'JCRJE-20260709-006'
      )
      AND bu_code = 'SNJT'
      AND bu_name = '水泥集团'
    )
    OR
    (
      ledger_no = 'JCRJE-20260709-007'
      AND bu_code = 'HNT'
      AND bu_name = '混凝土集团'
    )
  );

START TRANSACTION;

UPDATE sc_collection_daily_amount_ledger
SET bu_code = CASE
  WHEN ledger_no IN (
    'JCRJE-20260709-001',
    'JCRJE-20260709-002',
    'JCRJE-20260709-003',
    'JCRJE-20260709-006'
  ) THEN 'BU002'
  WHEN ledger_no = 'JCRJE-20260709-007' THEN 'BU003'
  ELSE bu_code
END
WHERE delete_sign = 0
  AND execute_unit_name = '机电公司'
  AND (
    (
      ledger_no IN (
        'JCRJE-20260709-001',
        'JCRJE-20260709-002',
        'JCRJE-20260709-003',
        'JCRJE-20260709-006'
      )
      AND bu_code = 'SNJT'
      AND bu_name = '水泥集团'
    )
    OR
    (
      ledger_no = 'JCRJE-20260709-007'
      AND bu_code = 'HNT'
      AND bu_name = '混凝土集团'
    )
  );

SELECT ROW_COUNT() AS affected_rows;

COMMIT;

-- 执行后核对：BU002 应为 4 条，BU003 应为 1 条，总金额仍为 50345.93。
SELECT bu_code,
       bu_name,
       COUNT(*) AS row_count,
       ROUND(SUM(tax_amount), 2) AS tax_sum
FROM sc_collection_daily_amount_ledger
WHERE ledger_no IN (
  'JCRJE-20260709-001',
  'JCRJE-20260709-002',
  'JCRJE-20260709-003',
  'JCRJE-20260709-006',
  'JCRJE-20260709-007'
)
GROUP BY bu_code, bu_name
ORDER BY bu_code;

-- 回滚 SQL（出现问题时单独执行；执行后需重新调用一次 syncJd）：
-- START TRANSACTION;
-- UPDATE sc_collection_daily_amount_ledger
-- SET bu_code = 'SNJT'
-- WHERE delete_sign = 0
--   AND execute_unit_name = '机电公司'
--   AND ledger_no IN (
--     'JCRJE-20260709-001',
--     'JCRJE-20260709-002',
--     'JCRJE-20260709-003',
--     'JCRJE-20260709-006'
--   )
--   AND bu_code = 'BU002'
--   AND bu_name = '水泥集团';
--
-- UPDATE sc_collection_daily_amount_ledger
-- SET bu_code = 'HNT'
-- WHERE delete_sign = 0
--   AND execute_unit_name = '机电公司'
--   AND ledger_no = 'JCRJE-20260709-007'
--   AND bu_code = 'BU003'
--   AND bu_name = '混凝土集团';
-- COMMIT;
