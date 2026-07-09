#!/bin/bash
# 调 test 环境接口。用法：
#   bash scripts/api.sh POST /e/business/source/collectionDailyAmountLedger/detail '{"ledgerId":"xxx"}'
#   bash scripts/api.sh GET  '/e/business/report/source/aggComapny_source?companyName=唐山'
# 网关和 TOKEN 来自 ai-docs/creds.env（TOKEN 过期让用户从浏览器 F12 重新复制粘贴进去）。
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$DIR/ai-docs/creds.env"; set +a
M="$1"; P="$2"; BODY="${3:-}"
[ -n "$TOKEN" ] || { echo "creds.env 的 TOKEN 为空。请用户登录 test 前端 → F12 → 任一请求 → 复制 Authorization bearer 后面整串填入 ai-docs/creds.env"; exit 1; }
curl -sS --insecure -X "$M" "$GATEWAY$P" \
  -H "Authorization: bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/plain, */*' \
  ${BODY:+--data-raw "$BODY"}
echo
