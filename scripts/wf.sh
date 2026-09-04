#!/bin/bash
# 工作流（DPS）只读查询工具。用法：
#   bash scripts/wf.sh doctor                     # 体检：直连/登录/关键 API 全通不通
#   bash scripts/wf.sh login [test|uat]           # 手动登录（一般不用，查询命令会自动登）
#   bash scripts/wf.sh templates [test|uat] [关键字]   # DPS 流程模板列表（live 控制台）
#   bash scripts/wf.sh metas [test|uat]           # DPS 流程变量定义（分支条件用）
#   bash scripts/wf.sh todo [test|uat] [数] [appId]   # DPS 待办监控（全平台当前卡在哪）
#   bash scripts/wf.sh biz [test|uat]             # 业务侧模板对照（business_type→回调→模板码）
#   bash scripts/wf.sh records [test|uat] [业务类型]  # 近期真实启动码分布（四级降级的实际结果）
#   bash scripts/wf.sh trace <businessId> [test|uat]  # 一张单子的流程轨迹（业务记录+DPS待办+审批意见）
#   bash scripts/wf.sh open [test|uat]            # 打印控制台/流程图入口 URL（人工看图用）
# 红线：本脚本只有读操作。控制台/引擎的一切写接口（保存/发布/审批/转移/补救）一律不封装。
# 封掉的坑：
#   ① dps.scmflow-*.jdsn.com 走 Clash 代理必 502，必须 --noproxy 直连；
#   ② 登录是三段式：POST ssoauth(userName/password/appid/userid=1001) → 302 带 token → GET sso 建立 JSESSIONID，
#      少一段都会落在 noaccess/ssoerrors，之前 curl 直接打 /index 全部失败；
#   ③ DPS 引擎自己的库(dps_test/dps_uat@10.0.54.19)是 2023/2024 年的旧库，线上数据看不到，
#      看运行时真象要走控制台 API 或业务库 scm_wf_* 表——所以本脚本不查 dps_* 库。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$ROOT_DIR/ai-docs/creds.env"; set +a

CACHE_DIR="$ROOT_DIR/ai-docs/.auth-cache"; mkdir -p "$CACHE_DIR"; chmod 700 "$CACHE_DIR" 2>/dev/null || true
usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

env_of() { case "${1:-test}" in test|uat) printf '%s' "$1";; *) echo "环境只能是 test|uat" >&2; return 1;; esac; }
url_of()  { local e; e="$(env_of "$1")"; local v="DPS_$(echo "$e" | tr 'a-z' 'A-Z')_URL";  printf '%s' "${!v}"; }
user_of() { local e; e="$(env_of "$1")"; local v="DPS_$(echo "$e" | tr 'a-z' 'A-Z')_USER";  printf '%s' "${!v}"; }
pass_of() { local e; e="$(env_of "$1")"; local v="DPS_$(echo "$e" | tr 'a-z' 'A-Z')_PASS";  printf '%s' "${!v}"; }
appid_of(){ local e; e="$(env_of "$1")"; local v="DPS_$(echo "$e" | tr 'a-z' 'A-Z')_APPID"; printf '%s' "${!v}"; }
cookie_of(){ printf '%s/dps-%s.cookies' "$CACHE_DIR" "$(env_of "$1")"; }

# Clash 会间歇断内网域名，重试几次
curl_ro() { local code; for i in 1 2 3; do code=000; curl -s --noproxy '*' --max-time 20 "$@" && return 0; sleep 2; done; return 1; }

# 三段式登录；成功返回 0。cookie 文件权限 600。
dps_login() {
  local env1="$1" base user pass appid ck
  base="$(url_of "$env1")"; user="$(user_of "$env1")"; pass="$(pass_of "$env1")"; appid="$(appid_of "$env1")"
  ck="$(cookie_of "$env1")"; rm -f "$ck"; : > "$ck"; chmod 600 "$ck"
  local loc
  loc=$(curl -s -o /dev/null -D - --noproxy '*' --max-time 20 -c "$ck" \
        --data-urlencode "userName=$user" --data-urlencode "password=$pass" \
        --data-urlencode "appid=$appid" --data-urlencode "userid=1001" \
        "$base/ssoauth" | grep -i '^location' | tail -1 | tr -d '\r' | cut -d' ' -f2) || true
  [ -n "$loc" ] || { echo "登录失败：ssoauth 未跳转（账号/密码/网络）" >&2; return 1; }
  curl -s -o /dev/null -L --noproxy '*' --max-time 20 -b "$ck" -c "$ck" "$loc" || { echo "登录失败：sso 建立会话出错" >&2; return 1; }
}

# 会话有效则复用，失效自动重登一次
dps_get() {
  local env1="$1" path="$2" base ck out
  base="$(url_of "$env1")"; ck="$(cookie_of "$env1")"
  [ -s "$ck" ] || dps_login "$env1"
  out=$(curl -s -b "$ck" --noproxy '*' --max-time 20 -w '\n%{http_code}' "$base$path") || true
  local code="${out##*$'\n'}"; local body="${out%$'\n'*}"
  if [ "$code" != "200" ] || grep -q 'noaccess\|ssoerrors\|login' <<<"$body" && ! grep -q '"rows"' <<<"$body"; then
    dps_login "$env1" || return 1
    curl_ro -b "$ck" "$base$path"
  else
    printf '%s' "$body"
  fi
}

j() { command -v jq >/dev/null 2>&1 && jq "$@" || python3 -c "import json,sys;d=json.load(sys.stdin);print(json.dumps($1,ensure_ascii=False,indent=1))"; }

cmd_doctor() {
  local ok=0 fail=0
  for e in test uat; do
    local base; base="$(url_of "$e")"
    local host="${base#http://}"; host="${host%%/*}"
    if ! getent hosts "$host" >/dev/null 2>&1; then echo "FAIL [$e] 域名解析（hosts 里应有 10.0.54.19）"; fail=$((fail+1)); continue; fi
    dps_login "$e" && echo "OK   [$e] 控制台登录（cookie: $(basename "$(cookie_of "$e")")）" || { echo "FAIL [$e] 登录"; fail=$((fail+1)); continue; }
    dps_get "$e" "/partial/menu" >/dev/null 2>&1 && echo "OK   [$e] 会话+菜单接口" || { echo "FAIL [$e] 会话接口"; fail=$((fail+1)); }
    ok=$((ok+1))
  done
  bash "$ROOT_DIR/scripts/dbq.sh" "SELECT COUNT(*) AS wf_template_rows FROM scm_ubm_test.scm_wf_template" >/dev/null 2>&1 \
    && echo "OK   业务库 scm_ubm_test.scm_wf_template 可查" || echo "FAIL 业务库 scm_wf_template 查询失败"
  [ "$fail" -eq 0 ] && echo "结论：可用。" || echo "结论：有 FAIL，看上面。"
}

cmd_templates() {
  local e="${1:-test}" kw="${2:-}"
  dps_get "$e" "/workflow/listresult.json?offset=1&limit=200&keyValue=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$kw")&orgId=P18000000&isUnit=0" \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('total:', d.get('total'))
for r in (d.get('rows') or []):
    print(' ', r.get('categoryCode'), '|', r.get('categoryName'), '| ownKind:', r.get('ownKind'), '| 版本:', r.get('versions'), '| 状态:', r.get('publishState'))
"
}

cmd_metas() {
  local e="${1:-test}"
  dps_get "$e" "/metas/listresult.json?offset=1&limit=100" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('metas total:', d.get('total'), '（这些就是流程图分支条件能引用的变量）')
for r in (d.get('rows') or []):
    print(' ', r.get('metaCode'), '|', r.get('metaName'), '| 类型:', r.get('metaTypeName') or r.get('metaType'))
"
}

cmd_todo() {
  local e="${1:-test}" n="${2:-10}" app="${3:-}"
  local q=""; [ -n "$app" ] && q="&appId=$app"
  dps_get "$e" "/mon/taskResult.json?offset=1&limit=$n$q" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('待办总数:', d.get('total'))
for r in (d.get('rows') or []):
    print(' ', (r.get('categoryCode') or '?').ljust(24), (r.get('activityName') or '?').ljust(12), (r.get('executorName') or '?').ljust(10), (r.get('businessId') or '?')[:40], (r.get('businessName') or ''))
"
}

cmd_biz() {
  local e="${1:-test}"; local db="scm_ubm_${e}"
  bash "$ROOT_DIR/scripts/dbq.sh" "SELECT business_type, template_code, callback_method, revert_method, sign_version, use_template_code, template_group_code FROM ${db}.scm_wf_template WHERE template_version=1 ORDER BY business_type" "${db}"
}

cmd_records() {
  local e="${1:-test}" bt="${2:-}"; local db="scm_ubm_${e}"
  local w=""; [ -n "$bt" ] && w=" AND business_type='$bt'"
  bash "$ROOT_DIR/scripts/dbq.sh" "SELECT business_type, template_start_code, COUNT(*) cnt, MAX(create_time) latest FROM ${db}.scm_wf_template_record WHERE 1=1$w GROUP BY business_type, template_start_code ORDER BY latest DESC LIMIT 30" "${db}"
}

cmd_trace() {
  local bid="$1" e="${2:-test}"; [ -n "$bid" ] || { echo "用法：wf.sh trace <businessId> [test|uat]" >&2; exit 2; }
  local db="scm_ubm_${e}"
  # DPS 里 businessId 可能带 SCHEME- 这类前缀，业务表存的是裸雪花 ID，两种都查
  local bare; bare=$(sed -E 's/^[A-Za-z_]+-//' <<<"$bid")
  local where="business_key='$bid'"; [ "$bare" != "$bid" ] && where="business_key IN ('$bid','$bare')"
  echo "== 业务侧（${db}）=="
  bash "$ROOT_DIR/scripts/dbq.sh" "SELECT business_key, business_type, template_code, template_start_code, callback_method, create_time FROM ${db}.scm_wf_template_record WHERE $where ORDER BY create_time DESC LIMIT 3" "${db}" 2>/dev/null || true
  bash "$ROOT_DIR/scripts/dbq.sh" "SELECT temp_sign, ins_status, business_type, business_key, create_time FROM ${db}.wf_instance WHERE $where ORDER BY create_time DESC LIMIT 5" "${db}" 2>/dev/null || true
  echo "== DPS 侧（控制台，按 businessId 查当前待办/意见需引擎 Basic 凭据，这里给人工入口）=="
  local base; base="$(url_of "$e")"
  echo "  流程图:   $base/graphic/view?businessId=$bid&appId=$(appid_of "$e")"
  echo "  控制台:   $base/index（登录后 业务管理→实例详情 搜 $bid）"
}

cmd_open() {
  local e="${1:-test}"; local base; base="$(url_of "$e")"
  echo "控制台登录页: $base/xlogin?xflag=sscdps"
  echo "  填法：帐号/密码见 ai-docs/creds.env（DPS_*），应用Id=jdsn，用户Id=1001"
  echo "机构模板列表页: $base/workflow/index"
  echo "待办监控页:    $base/mon/task"
  echo "流程图查看:    $base/graphic/view?businessId=<单据ID>&appId=$(appid_of "$e")"
}

[ "$#" -ge 1 ] || { usage >&2; exit 2; }
cmd="$1"; shift || true
case "$cmd" in
  doctor) cmd_doctor ;;
  login)  dps_login "${1:-test}" && echo "OK 已登录 $(env_of "${1:-test}")" ;;
  templates) cmd_templates "${1:-test}" "${2:-}" ;;
  metas)   cmd_metas "${1:-test}" ;;
  todo)    cmd_todo "${1:-test}" "${2:-10}" "${3:-}" ;;
  biz)     cmd_biz "${1:-test}" ;;
  records) cmd_records "${1:-test}" "${2:-}" ;;
  trace)   cmd_trace "$1" "${2:-test}" ;;
  open)    cmd_open "${1:-test}" ;;
  -h|--help|help) usage ;;
  *) printf '未知命令：%s\n' "$cmd" >&2; usage >&2; exit 2 ;;
esac
