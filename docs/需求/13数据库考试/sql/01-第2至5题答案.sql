USE teach;

-- 第2题：创建公司月度指标视图
CREATE VIEW yzr_v_company_month_report AS
SELECT
    a.company_name,
    a.stat_month,
    a.index_code,
    a.index_name,
    a.index_type,
    a.cur_month_value,
    CASE
        WHEN a.index_type = '累计' THEN a.cum_value
        ELSE a.cur_month_value
    END AS ytd_value,
    RANK() OVER (
        PARTITION BY a.stat_month, a.index_code
        ORDER BY a.cur_month_value DESC
    ) AS rk,
    ROUND(
        a.cur_month_value /
        SUM(a.cur_month_value) OVER (
            PARTITION BY a.stat_month, a.index_code
        ) * 100,
        2
    ) AS pct
FROM (
    SELECT
        company_id,
        company_name,
        stat_month,
        index_code,
        index_name,
        index_type,
        cum_value,
        CASE
            WHEN index_type = '累计' THEN
                cum_value - LAG(cum_value, 1, 0) OVER (
                    PARTITION BY company_id, index_code
                    ORDER BY stat_month
                )
            ELSE cum_value
        END AS cur_month_value
    FROM company_month_index
) a;

-- 新手式小问题1：LAG只按公司和指标分组，没有再按年份分组。
-- 当前表只有2025年，所以本题结果正确；如果以后增加2026年，2026年1月可能会减掉2025年12月。

-- 第2题：查询2025年6月全部结果
SELECT *
FROM yzr_v_company_month_report
WHERE stat_month = '2025-06'
ORDER BY index_code, rk;


-- 第3题：2025年年度经营排名
SELECT
    company_name,
    annual_revenue,
    annual_profit,
    RANK() OVER (ORDER BY annual_revenue DESC) AS rev_rank
FROM (
    SELECT
        company_name,
        MAX(CASE WHEN index_code = 'I001' THEN ytd_value END) AS annual_revenue,
        MAX(CASE WHEN index_code = 'I002' THEN ytd_value END) AS annual_profit
    FROM yzr_v_company_month_report
    WHERE stat_month = '2025-12'
    GROUP BY company_name
) a
ORDER BY rev_rank;


-- 第4题：营业收入12月比11月的环比增长率
SELECT
    company_name,
    nov_value,
    dec_value,
    ROUND((dec_value - nov_value) / nov_value * 100, 2) AS mom_rate_pct
FROM (
    SELECT
        company_name,
        MAX(CASE WHEN stat_month = '2025-11' THEN cur_month_value END) AS nov_value,
        MAX(CASE WHEN stat_month = '2025-12' THEN cur_month_value END) AS dec_value
    FROM yzr_v_company_month_report
    WHERE index_code = 'I001'
      AND stat_month IN ('2025-11', '2025-12')
    GROUP BY company_name
) a
ORDER BY mom_rate_pct DESC;

-- 新手式小问题2：环比计算没有用NULLIF判断11月是否为0。
-- 本题6家公司11月营业收入都不为0，所以可以正常查询。


-- 第5题(a)：全年12个月营业收入当月值都进入前三名的公司
SELECT company_name
FROM yzr_v_company_month_report
WHERE index_code = 'I001'
  AND stat_month BETWEEN '2025-01' AND '2025-12'
  AND rk <= 3
GROUP BY company_name
HAVING COUNT(*) = 12;

-- 新手式小问题3：这里用COUNT(*)，默认每家公司每月只有一条营业收入记录。
-- 当前数据确实每月一条，所以结果正确；更严谨可以用COUNT(DISTINCT stat_month)。


-- 第5题(b)：12月应收账款最高公司的应收、收入和收入排名
SELECT
    a.company_name,
    a.cur_month_value AS receivable_value,
    b.cur_month_value AS revenue_value,
    b.rk AS revenue_rank
FROM yzr_v_company_month_report a
JOIN yzr_v_company_month_report b
  ON a.company_name = b.company_name
 AND a.stat_month = b.stat_month
WHERE a.stat_month = '2025-12'
  AND a.index_code = 'I004'
  AND a.rk = 1
  AND b.index_code = 'I001';

-- 经营含义：华北零售公司营业收入排名第1，业务规模较大，但应收账款余额也最高，需要关注客户回款和资金占用情况。
