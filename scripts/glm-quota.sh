#!/bin/bash
# 查智谱 GLM Coding Plan 的订阅信息和用量配额。key 自动从 ai-docs/creds.env 的 ZHIPU_API_KEY 读。
#
# 两个背景坑（这个脚本存在的理由）：
# 1. Coding Plan 的额度不走按量付费接口——拿 /api/paas/v4 去查/调只会报 1113「余额不足」，
#    不是真没钱，是走错了门。订阅额度要走 Anthropic 兼容端点 /api/anthropic。
# 2. 本脚本查的这两个接口是 open.bigmodel.cn 网页管理后台自用的内部接口，官方 API 文档没收录；
#    字段含义来自社区逆向文档 https://github.com/PowerUserZ/OpenTokenUsage/blob/main/docs/providers/zai.md
#    接口哪天变了先跑 raw 模式看原始返回。
#
# 用法：
#   bash scripts/glm-quota.sh        # 摘要：订阅 + 5小时/周 token 窗口百分比 + 工具调用次数
#   bash scripts/glm-quota.sh raw    # 原始 JSON（接口结构变化时排查用）
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$DIR/ai-docs/creds.env"; set +a

[ -n "$ZHIPU_API_KEY" ] || { echo "creds.env 的 ZHIPU_API_KEY 为空，请补 ZHIPU_API_KEY"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "需要 jq（解析 JSON 用）"; exit 1; }

BASE="https://open.bigmodel.cn"
AUTH=(-H "Authorization: Bearer $ZHIPU_API_KEY" -H "Accept: application/json")

sub_json=$(curl -sS --max-time 20 "$BASE/api/biz/subscription/list" "${AUTH[@]}")
quota_json=$(curl -sS --max-time 20 "$BASE/api/monitor/usage/quota/limit" "${AUTH[@]}")

# 毫秒时间戳 → 可读时间；距今 还有多久
ts2t()  { date -d "@$(( $1 / 1000 ))" '+%Y-%m-%d %H:%M'; }
until_() {
  local diff=$(( $1 / 1000 - $(date +%s) ))
  [ $diff -le 0 ] && { echo "已到重置点"; return; }
  local d=$((diff/86400)) h=$(( (diff%86400)/3600 )) m=$(( (diff%3600)/60 ))
  if [ $d -gt 0 ]; then echo "${d}天${h}小时后"
  elif [ $h -gt 0 ]; then echo "${h}小时${m}分后"
  else echo "${m}分后"; fi
}

if [ "${1:-}" = "raw" ]; then
  echo "== subscription =="; echo "$sub_json" | jq .
  echo; echo "== quota =="; echo "$quota_json" | jq .
  exit 0
fi

echo "$sub_json"  | jq -e '.code == 200' >/dev/null || { echo "订阅接口异常："; echo "$sub_json" | jq .; exit 1; }
echo "$quota_json" | jq -e '.code == 200' >/dev/null || { echo "配额接口异常："; echo "$quota_json" | jq .; exit 1; }

echo "===== GLM Coding 订阅 ====="
echo "$sub_json" | jq -r '.data[0] |
  "套餐: \(.productName)（¥\(.actualPrice)/月，本期第\(.currentPeriod)期）\n" +
  "付款: \(.paymentType | if . == "WAIT_PAY" then "⚠️ 待支付——建议去控制台核对支付方式，避免断供" else . end)\n" +
  "下次续费: \(.nextRenewTime)（自动续费: \(.autoRenew // 0 | if . == 1 then "开" else "关" end)）"'

echo
echo "===== 用量（订阅制看滚动窗口，没有「余额」概念） ====="
echo "套餐等级: $(echo "$quota_json" | jq -r '.data.level // "?"')"

# TOKENS_LIMIT：百分比窗口。unit=3 是 5 小时窗口，unit=6 是 7 天窗口（zai.md 逆向结论）
echo "$quota_json" | jq -r '.data.limits[] | select(.type == "TOKENS_LIMIT") | "\(.unit)|\(.percentage)|\(.nextResetTime)"' \
| while IFS='|' read -r unit pct reset; do
    case "$unit" in
      3) label="5小时窗口" ;;
      6) label="周窗口(7天)" ;;
      *) label="unit=$unit 窗口" ;;
    esac
    printf "%-14s %s%%   重置: %s（%s）\n" "$label" "$pct" "$(ts2t "$reset")" "$(until_ "$reset")"
  done

# TIME_LIMIT：工具调用次数（搜索/读网页/zread，月度额度，随订阅周期重置）
echo "$quota_json" | jq -r '.data.limits[] | select(.type == "TIME_LIMIT") |
    "\(.currentValue)|\(.usage)|\(.percentage)|\(.nextResetTime)|\([.usageDetails[]? | "\(.modelCode):\(.usage)"] | join("  "))"' \
| while IFS='|' read -r used total pct reset details; do
    printf "工具调用       %s/%s 次（%s%%）  %s\n" "$used" "$total" "$pct" "$details"
    printf "               重置: %s\n" "$(ts2t "$reset")"
  done
