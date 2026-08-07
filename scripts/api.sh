#!/bin/bash
# 调招采/云采业务接口，自动获取和刷新 token。
# 兼容旧用法：
#   bash scripts/api.sh POST /e/business/source/xxx '{"a":1}'
# 新用法：
#   bash scripts/api.sh --env uat --platform cloud --account supplier GET /c/business/xxx

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/scm-auth.sh"

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  printf '\n参数：--env test|uat；--platform procurement|cloud；--account admin|supplier\n'
}

environment="${SCM_API_ENV:-test}"
platform="${SCM_API_PLATFORM:-procurement}"
account="${SCM_API_ACCOUNT:-admin}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env)
      [ "$#" -ge 2 ] || { printf '%s\n' '--env 缺少值' >&2; exit 2; }
      environment="$2"
      shift 2
      ;;
    --platform)
      [ "$#" -ge 2 ] || { printf '%s\n' '--platform 缺少值' >&2; exit 2; }
      platform="$2"
      shift 2
      ;;
    --account)
      [ "$#" -ge 2 ] || { printf '%s\n' '--account 缺少值' >&2; exit 2; }
      account="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf '未知参数：%s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -ge 2 ] || { usage >&2; exit 2; }
method="$1"
request_path="$2"
body="${3:-}"
if [ "${request_path#/}" = "$request_path" ]; then
  printf '接口路径必须以 / 开头：%s\n' "$request_path" >&2
  exit 2
fi

case "$platform" in
  procurement|zc) platform='procurement' ;;
  cloud|yc) platform='cloud' ;;
  *) printf 'platform 只能是 procurement/cloud（也支持 zc/yc）\n' >&2; exit 2 ;;
esac

scm_auth_load_creds
gateway="$(scm_auth_gateway "$environment" "$platform")"
if [ -z "$gateway" ]; then
  printf '%s/%s 网关未配置，请补 ai-docs/creds.env\n' "$environment" "$platform" >&2
  exit 1
fi
gateway="${gateway%/}"
scm_auth_get_token "$environment" "$account"

request_once() {
  local combined curl_result
  local -a curl_args
  curl_args=(
    -sS --insecure --connect-timeout 5 --max-time 60
    -w $'\n%{http_code}'
    -X "$method" "$gateway$request_path"
    -H "Authorization: ${SCM_AUTH_TOKEN_TYPE:-bearer} $SCM_AUTH_TOKEN"
    -H 'Content-Type: application/json'
    -H 'Accept: application/json, text/plain, */*'
  )
  if [ -n "$body" ]; then
    curl_args+=(--data-raw "$body")
  fi
  set +e
  combined="$(curl "${curl_args[@]}")"
  curl_result=$?
  set -e
  if [ "$curl_result" -ne 0 ]; then
    printf '接口连接失败（curl exit=%s）：%s%s\n' "$curl_result" "$gateway" "$request_path" >&2
    return "$curl_result"
  fi
  API_HTTP_CODE="${combined##*$'\n'}"
  API_RESPONSE="${combined%$'\n'*}"
}

is_auth_failure() {
  if [ "$API_HTTP_CODE" = "401" ]; then
    return 0
  fi
  if printf '%s' "$API_RESPONSE" | jq -e \
    '(.code | tostring) as $code
     | ["900301", "401", "ERROR_JWT_INVALIDITY", "ERROR_JWT_401"]
     | index($code) != null' \
    >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

request_once
if is_auth_failure; then
  printf '%s/%s 登录态已失效，正在自动重新登录并重试一次。\n' "$environment" "$account" >&2
  rejected_token="$SCM_AUTH_TOKEN"
  scm_auth_refresh_token "$environment" "$account" "$rejected_token"
  request_once
fi

printf '%s\n' "$API_RESPONSE"
