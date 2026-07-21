-- =====================================================================
-- 【⚠️ 高感知 · 必须产品/领导签字确认后再交给运维执行】
-- 集采驾驶舱：collectionShow 字典开关切换（台账1 驾驶舱联动启用）
-- ---------------------------------------------------------------------
-- 对应需求：docs/需求/台账/
-- 对应代码：scm-source-all 提交 2f33fa77f（已 merge test: b7fcf7cff，已推 origin/test）
--          —— 已把 SourceCollectionMapper 里 1501/1701/2302/2502 四个类目
--             及机电公司行（situA2）的汇总 SQL 改为读台账表
--          —— 但 Service 层 SourceCollectionDataServiceImpl 用 collectionShow 字典
--             做开关：开关=0 走旧缓存表 sc_collection_data；开关=1 才走新 SQL
-- 产出时间：2026-07-16
-- 执行库：scm_ubm（生产环境字典库；test 对应 scm_ubm_test）
--
-- 当前状态（2026-07-16 实测）：
--   centerHeader=1   （大屏头部总数，已是实时算，本次不动）
--   categoryAmount=0 （左侧"集采类目分项金额"7 行，本次要切）
--   situA=0          （右侧"集采情况分析"3 行，本次要切）
--
-- ⚠️ 切了之后会发生什么（这就是为什么要先确认）：
--   1) 这两个面板的整组数据从"读缓存表"切到"实时算台账汇总"
--   2) 煤炭(1001)、办公设备(2102)、办公文具(2113)、水泥北分、金隅云采等
--      非台账类目也会跟着变 —— 因为它们的 SQL 没改，但走了不同的代码分支，
--      显示值可能与旧缓存数有出入（缓存早已失真，2026-01-29 后未再刷新）
--   3) 四个台账类目（钢材/润滑剂/电线电缆/轴承及备件）和机电公司行
--      会变成 SUM(sc_collection_daily_amount_ledger.tax_amount)，
--      生产台账目前是空的，切了之后这几个数会先变成 0，要等业务录数据
--   4) 单位坑：台账存"元"，驾驶舱显示"/10000 取万元整数"，
--      单条金额 <5000 元的会显示成 0（业务录入单位必须和"元"一致）
--
-- 确认要点（建议对着 test 大屏和产品/领导一起过）：
--   □ 煤炭/办公等非台账类目切换后的实时值是否可接受
--   □ 台账类目在业务录数据前的"暂时为 0"是否可接受
--   □ 是否需要先把台账历史数据补录，再切开关
--   □ 是否需要保留回退能力（保留 sc_collection_data 旧数据即可随时切回 0）
-- =====================================================================


USE `scm_ubm`;

-- 切换前先看一眼当前值（确认没有别人正在动）
SELECT dict_type_code, dict_code, dict_name, dict_status, delete_sign
FROM `ubm_dict`
WHERE dict_type_code='collectionShow'
ORDER BY dict_code;

-- ===== 切到实时（确认无误后执行以下两段 UPDATE）=====
-- 1. 集采类目分项金额 → 实时汇总台账
UPDATE `ubm_dict`
SET `dict_name`='1', `update_time`=NOW()
WHERE dict_type_code='collectionShow' AND dict_code='categoryAmount' AND delete_sign=0;

-- 2. 集采情况分析（机电公司行）→ 实时汇总台账
UPDATE `ubm_dict`
SET `dict_name`='1', `update_time`=NOW()
WHERE dict_type_code='collectionShow' AND dict_code='situA' AND delete_sign=0;


-- ===== 回退方法（万一上线后大屏异常，立即执行以下两段切回缓存）=====
-- UPDATE `ubm_dict` SET `dict_name`='0', `update_time`=NOW()
--   WHERE dict_type_code='collectionShow' AND dict_code='categoryAmount' AND delete_sign=0;
-- UPDATE `ubm_dict` SET `dict_name`='0', `update_time`=NOW()
--   WHERE dict_type_code='collectionShow' AND dict_code='situA' AND delete_sign=0;


-- =====================================================================
-- 备注：台账2（煤炭重点坑口日指标台账）的驾驶舱联动已经从 test 撤回
--      （提交 d4eb7d21b revert 了 3992bf54e），本次发版无需任何相关 SQL。
--      大屏坑口表继续读旧缓存表 sc_collection_data。
-- =====================================================================
