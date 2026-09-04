-- ============================================================
-- 01b 机电日金额初始化 · UAT 字典脏数据修正（可选，执行需用户点头）
-- 日期：2026-09-04 ｜ 生成：oc
-- 现象（均已 HEX 实证）：
--   1) collection_category「电线电缆」dict_code = ' 2302'（前导空格）
--      → uat 页面录入的电线电缆行 category_code 带空格，驾驶舱按类目匹配可能认不出
--      （uat 现有台账 2 行无电线电缆，修字典无连带影响；ES 里旧脏数据另行观察）
--   2) Owningplate「新材产业化集团」dict_name 尾部带 0x09 制表符
--      → 页面录入的板块名会带 TAB，列表展示/筛选易出现两个变体
-- 修正后重跑 01 预检第④节应得 4 行。
-- ============================================================

USE `scm_ubm_uat`;

-- 修正前留证
SELECT dict_id, CONCAT('[',dict_code,']') code_q, HEX(dict_code) code_hex,
       CONCAT('[',dict_name,']') name_q, HEX(dict_name) name_hex
FROM `ubm_dict`
WHERE dict_id IN ('b532cc4af36573be391f8c3659cd47e1')
   OR (dict_type_code='Owningplate' AND dict_code='BU005' AND delete_sign=0);

-- 1) 电线电缆编码去前导空格
UPDATE `ubm_dict` SET `dict_code`='2302', `update_time`=NOW()
WHERE `dict_id`='b532cc4af36573be391f8c3659cd47e1' AND `dict_code`=' 2302';

-- 2) 新材产业化集团去尾部 TAB
UPDATE `ubm_dict` SET `dict_name`='新材产业化集团', `update_time`=NOW()
WHERE `dict_type_code`='Owningplate' AND `dict_code`='BU005' AND `delete_sign`=0
  AND `dict_name` LIKE '%	';

-- 修正后核验（期望两行都干净：[2302]/[新材产业化集团]）
SELECT dict_code, CONCAT('[',dict_code,']') code_q FROM `ubm_dict`
WHERE dict_type_code='collection_category' AND dict_name='电线电缆' AND delete_sign=0;
SELECT dict_code, CONCAT('[',dict_name,']') name_q FROM `ubm_dict`
WHERE dict_type_code='Owningplate' AND dict_code='BU005' AND delete_sign=0;
