#!/bin/bash
# 字段体检（Phase 4 探针）。用法：
#   bash scripts/fieldcheck.sh <表名> <字段名> [库名，默认 scm_source_test]
#
# 什么时候必须跑：需求里凡是拿来**筛选、统计、分组**的字段，开工前先跑一次。
#
# 看什么：
#   ① 填充率  —— 低于 50% 就是红灯，必须问人，不能默默按原口径写代码
#   ② 取值分布 —— 和数据字典对不对得上；有没有脏值
#   ③ 有值/无值的时间窗口 —— 这一项最能暴露"字段是新加的、录入功能还没发版"
#      典型信号：有值的只集中在最近一小段时间，无值的横跨全部历史
#
# 真实教训：某报表需求指定按"采购业务分类"筛选，全表 311 单只有 7 单有值
# （录入入口加上去 10 天后又被注释掉了），按原口径做出来的报表几乎是空的，返工三轮。
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
T="${1:-}"; F="${2:-}"; DB="${3:-scm_source_test}"
[ -n "$T" ] && [ -n "$F" ] || {
  echo "用法: bash scripts/fieldcheck.sh <表名> <字段名> [库名，默认 scm_source_test]"; exit 1; }

# 找一个时间列用来画"有值/无值的时间窗口"，优先 create_time
CT=$(bash "$DIR/scripts/dbq.sh" \
  "SELECT column_name FROM information_schema.columns WHERE table_schema='$DB' AND table_name='$T' AND column_name IN ('create_time','update_time');" \
  "$DB" 2>/dev/null | grep -oE 'create_time|update_time' | head -1)

SQL=$(mktemp /tmp/fieldcheck-XXXX.sql)
cat > "$SQL" <<EOF
SELECT '① 填充率（低于50%是红灯）' AS 检查项;
SELECT COUNT(*) AS 总行数,
       SUM(CASE WHEN \`$F\` IS NULL THEN 1 ELSE 0 END) AS 空值,
       SUM(CASE WHEN \`$F\` = '' THEN 1 ELSE 0 END) AS 空串,
       CONCAT(ROUND(100 * SUM(CASE WHEN \`$F\` IS NOT NULL AND \`$F\` <> '' THEN 1 ELSE 0 END) / COUNT(*), 1), '%') AS 填充率
FROM \`$T\`;

SELECT '② 取值分布（前20，核对字典和脏值）' AS 检查项;
SELECT \`$F\` AS 取值, COUNT(*) AS 行数
FROM \`$T\` GROUP BY \`$F\` ORDER BY 行数 DESC LIMIT 20;
EOF

if [ -n "$CT" ]; then
  cat >> "$SQL" <<EOF

SELECT '③ 有值 vs 无值 的时间窗口（按 $CT）' AS 检查项;
SELECT '有值' AS 分组, COUNT(*) AS 行数, MIN(\`$CT\`) AS 最早, MAX(\`$CT\`) AS 最晚
FROM \`$T\` WHERE \`$F\` IS NOT NULL AND \`$F\` <> ''
UNION ALL
SELECT '无值', COUNT(*), MIN(\`$CT\`), MAX(\`$CT\`)
FROM \`$T\` WHERE \`$F\` IS NULL OR \`$F\` = '';
EOF
else
  echo "（提示：表 $T 没有 create_time/update_time 列，跳过时间窗口检查）"
fi

bash "$DIR/scripts/dbq.sh" "$SQL" "$DB"
rm -f "$SQL"

cat <<'TIP'

判读提示：
  · 填充率低于 50%          -> 红灯。别按这个字段筛，先问业务："这字段是新加的还没发版，还是废弃了？"
  · 有值窗口窄、无值窗口宽  -> 字段是后加的，历史数据补不上，用它筛会漏掉全部历史单
  · 取值里有字典外的值      -> 脏数据，或者存的是另一套编码（会导致下拉框筛不出来）
  · 想拿另一个字段替代它    -> 先跑一次交叉核对，确认两者在"都有值"的样本上不矛盾，再提方案
TIP
