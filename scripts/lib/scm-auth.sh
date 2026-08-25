#!/bin/bash
# 招采/云采业务接口自动登录公共库。
# 只供 scripts/auth.sh、scripts/api.sh source；任何函数都不得打印密码或 token。

SCM_AUTH_ROOT="${SCM_AUTH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCM_AUTH_CREDS_FILE="${SCM_AUTH_CREDS_FILE:-$SCM_AUTH_ROOT/ai-docs/creds.env}"
SCM_AUTH_CACHE_DIR="${SCM_AUTH_CACHE_DIR:-$SCM_AUTH_ROOT/ai-docs/.auth-cache}"

scm_auth_error() {
  printf '自动登录：%s\n' "$*" >&2
}

scm_auth_load_creds() {
  if [ "${SCM_AUTH_CREDS_LOADED:-0}" = "1" ]; then
    return 0
  fi
  if [ ! -r "$SCM_AUTH_CREDS_FILE" ]; then
    scm_auth_error "找不到凭据文件 $SCM_AUTH_CREDS_FILE"
    return 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$SCM_AUTH_CREDS_FILE"
  set +a
  SCM_AUTH_CREDS_LOADED=1
}

scm_auth_check_tools() {
  local tool_name missing=0
  for tool_name in curl jq base64 flock mktemp; do
    if ! command -v "$tool_name" >/dev/null 2>&1; then
      scm_auth_error "缺少命令 $tool_name"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ]
}

scm_auth_gateway() {
  local environment="$1" platform="$2"
  case "$environment:$platform" in
    test:procurement)
      printf '%s' "${SCM_TEST_PROCURE_GATEWAY:-${GATEWAY:-}}"
      ;;
    test:cloud)
      printf '%s' "${SCM_TEST_CLOUD_GATEWAY:-}"
      ;;
    uat:procurement)
      printf '%s' "${SCM_UAT_PROCURE_GATEWAY:-${UAT_GATEWAY:-}}"
      ;;
    uat:cloud)
      printf '%s' "${SCM_UAT_CLOUD_GATEWAY:-}"
      ;;
    prod:*)
      scm_auth_error "prod 按需求暂未开放自动登录"
      return 1
      ;;
    *)
      scm_auth_error "不支持 environment=$environment platform=$platform"
      return 1
      ;;
  esac
}

scm_auth_normalize() {
  local environment="$1" account="$2"
  case "$environment" in
    test|uat) ;;
    prod)
      scm_auth_error "prod 按需求暂未开放自动登录"
      return 1
      ;;
    *)
      scm_auth_error "环境只能是 test、uat（prod 暂未开放）"
      return 1
      ;;
  esac

  SCM_AUTH_ENVIRONMENT="$environment"
  SCM_AUTH_ACCOUNT="$account"
  SCM_AUTH_LOGIN_GATEWAY="$(scm_auth_gateway "$environment" procurement)" || return 1
  if [ -z "$SCM_AUTH_LOGIN_GATEWAY" ]; then
    scm_auth_error "$environment 招采网关未配置"
    return 1
  fi
  SCM_AUTH_LOGIN_GATEWAY="${SCM_AUTH_LOGIN_GATEWAY%/}"

  # 账号别名表驱动：creds.env 里每有一对 SCM_<别名大写>_USER / _PASS，就多一个可用别名。
  # 加账号不需要改这里。可用别名见 scm_auth_aliases。
  local alias_upper user_key pass_key
  alias_upper="$(printf '%s' "$account" | tr 'a-z-' 'A-Z_')"
  user_key="SCM_${alias_upper}_USER"
  pass_key="SCM_${alias_upper}_PASS"
  SCM_AUTH_USERNAME="${!user_key:-}"
  SCM_AUTH_PASSWORD="${!pass_key:-}"
  if [ -z "$SCM_AUTH_USERNAME" ] || [ -z "$SCM_AUTH_PASSWORD" ]; then
    scm_auth_error "未知账号别名 $account（creds.env 里缺 $user_key / $pass_key）。可用别名：$(scm_auth_aliases | tr '\n' ' ')"
    return 1
  fi
  # 手工粘贴的 legacy token 只对 admin 有意义（历史用法，见 creds.env 注释）
  if [ "$account" = "admin" ]; then
    if [ "$environment" = "test" ]; then
      SCM_AUTH_LEGACY_TOKEN="${TOKEN:-}"
    else
      SCM_AUTH_LEGACY_TOKEN="${UAT_TOKEN:-}"
    fi
  else
    SCM_AUTH_LEGACY_TOKEN=""
  fi
}

# 列出 creds.env 里配好的账号别名（小写，一行一个）。不打印任何值。
scm_auth_aliases() {
  [ -r "$SCM_AUTH_CREDS_FILE" ] || return 0
  sed -n 's/^[[:space:]]*SCM_\([A-Z0-9_]*\)_USER=.*/\1/p' "$SCM_AUTH_CREDS_FILE" \
    | grep -vE '^(TEST|UAT)$' | awk '!seen[$0]++' | tr 'A-Z' 'a-z'
}

scm_auth_cache_file() {
  printf '%s/%s-%s.json' "$SCM_AUTH_CACHE_DIR" "$1" "$2"
}

scm_auth_prepare_cache() {
  umask 077
  mkdir -p "$SCM_AUTH_CACHE_DIR"
  chmod 700 "$SCM_AUTH_CACHE_DIR"
}

scm_auth_read_valid_cache() {
  local environment="$1" account="$2" cache_file now expires_at token
  cache_file="$(scm_auth_cache_file "$environment" "$account")"
  [ -r "$cache_file" ] || return 1
  if ! jq -e '.accessToken | type == "string" and length > 0' "$cache_file" >/dev/null 2>&1; then
    return 1
  fi
  token="$(jq -r '.accessToken' "$cache_file")"
  # 当前认证服务签发 JWT。坏缓存若直接发给网关，会被旧网关包装成 HTTP 500。
  if [[ ! "$token" =~ ^[^.]+\.[^.]+\.[^.]+$ ]]; then
    return 1
  fi
  expires_at="$(jq -r '.expiresAt // 0' "$cache_file")"
  now="$(date +%s)"
  if ! [[ "$expires_at" =~ ^[0-9]+$ ]] || [ "$expires_at" -le $((now + 60)) ]; then
    return 1
  fi
  SCM_AUTH_TOKEN="$token"
  SCM_AUTH_TOKEN_TYPE="$(jq -r '.tokenType // "bearer"' "$cache_file")"
  SCM_AUTH_TOKEN_SOURCE="cache"
}

scm_auth_encode_password() {
  local value="$1" alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890'
  local prefix='' suffix='' encoded index
  while [ "${#prefix}" -lt 6 ]; do
    index=$((RANDOM % ${#alphabet}))
    prefix+="${alphabet:index:1}"
  done
  while [ "${#suffix}" -lt 5 ]; do
    index=$((RANDOM % ${#alphabet}))
    suffix+="${alphabet:index:1}"
  done
  encoded="$(printf '%s' "$value" | base64 | tr -d '\n')"
  printf '%s%s%s' "$prefix" "$encoded" "$suffix"
}

scm_auth_login_unlocked() {
  local body combined response http_code token token_type expires_in expires_at
  local cache_file temp_file now message code
  if [ -z "$SCM_AUTH_USERNAME" ] || [ -z "$SCM_AUTH_PASSWORD" ]; then
    scm_auth_error "$SCM_AUTH_ACCOUNT 账号未配置，请补 ai-docs/creds.env"
    return 1
  fi

  body="$(jq -nc \
    --arg username "$SCM_AUTH_USERNAME" \
    --arg password "$(scm_auth_encode_password "$SCM_AUTH_PASSWORD")" \
    '{username:$username,password:$password,vCode:"1",vCodeSign:"auto-login",phoneVCode:"1",phoneVCodeSign:""}')"

  if ! combined="$(curl -sS --connect-timeout 5 --max-time 30 \
    -w $'\n%{http_code}' \
    -X POST "$SCM_AUTH_LOGIN_GATEWAY/obs/business/auth/login/authUnity" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/plain, */*' \
    --data-raw "$body")"; then
    scm_auth_error "$SCM_AUTH_ENVIRONMENT 登录接口连接失败"
    return 1
  fi
  http_code="${combined##*$'\n'}"
  response="${combined%$'\n'*}"
  if ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    scm_auth_error "$SCM_AUTH_ENVIRONMENT 登录接口没有返回 JSON（HTTP $http_code）"
    return 1
  fi

  token="$(printf '%s' "$response" | jq -r '.data.access_token // empty')"
  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ] || [ -z "$token" ]; then
    code="$(printf '%s' "$response" | jq -r '.code // "unknown"')"
    message="$(printf '%s' "$response" | jq -r '.msg // .message // "登录失败"')"
    scm_auth_error "$SCM_AUTH_ENVIRONMENT/$SCM_AUTH_ACCOUNT 登录失败（HTTP $http_code，code=$code，$message）"
    return 1
  fi

  token_type="$(printf '%s' "$response" | jq -r '.data.token_type // "bearer"')"
  expires_in="$(printf '%s' "$response" | jq -r '.data.expires_in // 0')"
  if ! [[ "$expires_in" =~ ^[0-9]+$ ]] || [ "$expires_in" -le 0 ]; then
    scm_auth_error "登录响应缺少有效 expires_in，拒绝缓存未知有效期的 token"
    return 1
  fi
  now="$(date +%s)"
  expires_at=$((now + expires_in))

  scm_auth_prepare_cache
  cache_file="$(scm_auth_cache_file "$SCM_AUTH_ENVIRONMENT" "$SCM_AUTH_ACCOUNT")"
  temp_file="$(mktemp "$SCM_AUTH_CACHE_DIR/.${SCM_AUTH_ENVIRONMENT}-${SCM_AUTH_ACCOUNT}.XXXXXX")"
  jq -nc \
    --arg accessToken "$token" \
    --arg tokenType "$token_type" \
    --arg environment "$SCM_AUTH_ENVIRONMENT" \
    --arg account "$SCM_AUTH_ACCOUNT" \
    --argjson createdAt "$now" \
    --argjson expiresAt "$expires_at" \
    '{accessToken:$accessToken,tokenType:$tokenType,environment:$environment,account:$account,createdAt:$createdAt,expiresAt:$expiresAt}' \
    > "$temp_file"
  chmod 600 "$temp_file"
  mv -f "$temp_file" "$cache_file"

  SCM_AUTH_TOKEN="$token"
  SCM_AUTH_TOKEN_TYPE="$token_type"
  SCM_AUTH_TOKEN_SOURCE="login"
}

scm_auth_get_token() {
  local environment="$1" account="$2" lock_file lock_fd result
  scm_auth_check_tools || return 1
  scm_auth_load_creds || return 1
  scm_auth_normalize "$environment" "$account" || return 1

  if scm_auth_read_valid_cache "$environment" "$account"; then
    return 0
  fi
  if [ -n "$SCM_AUTH_LEGACY_TOKEN" ]; then
    SCM_AUTH_TOKEN="$SCM_AUTH_LEGACY_TOKEN"
    SCM_AUTH_TOKEN_TYPE="bearer"
    SCM_AUTH_TOKEN_SOURCE="legacy"
    return 0
  fi

  scm_auth_prepare_cache
  lock_file="$SCM_AUTH_CACHE_DIR/$environment-$account.lock"
  exec {lock_fd}>"$lock_file"
  flock "$lock_fd"
  if scm_auth_read_valid_cache "$environment" "$account"; then
    flock -u "$lock_fd"
    return 0
  fi
  scm_auth_login_unlocked
  result=$?
  flock -u "$lock_fd"
  return "$result"
}

scm_auth_refresh_token() {
  local environment="$1" account="$2" rejected_token="${3:-}"
  local lock_file lock_fd result
  scm_auth_check_tools || return 1
  scm_auth_load_creds || return 1
  scm_auth_normalize "$environment" "$account" || return 1
  scm_auth_prepare_cache
  lock_file="$SCM_AUTH_CACHE_DIR/$environment-$account.lock"
  exec {lock_fd}>"$lock_file"
  flock "$lock_fd"

  if scm_auth_read_valid_cache "$environment" "$account" \
    && [ -n "$rejected_token" ] \
    && [ "$SCM_AUTH_TOKEN" != "$rejected_token" ]; then
    flock -u "$lock_fd"
    return 0
  fi
  scm_auth_login_unlocked
  result=$?
  flock -u "$lock_fd"
  return "$result"
}

scm_auth_force_login() {
  local environment="$1" account="$2" lock_file lock_fd result
  scm_auth_check_tools || return 1
  scm_auth_load_creds || return 1
  scm_auth_normalize "$environment" "$account" || return 1
  scm_auth_prepare_cache
  lock_file="$SCM_AUTH_CACHE_DIR/$environment-$account.lock"
  exec {lock_fd}>"$lock_file"
  flock "$lock_fd"
  scm_auth_login_unlocked
  result=$?
  flock -u "$lock_fd"
  return "$result"
}

scm_auth_status() {
  local environment="$1" account="$2" cache_file now expires_at gateway cloud_gateway
  local credentials='missing' cache='missing' gateways='missing' result=0
  scm_auth_load_creds || return 1
  scm_auth_normalize "$environment" "$account" || return 1
  gateway="$(scm_auth_gateway "$environment" procurement)"
  cloud_gateway="$(scm_auth_gateway "$environment" cloud)"
  if [ -n "$SCM_AUTH_USERNAME" ] && [ -n "$SCM_AUTH_PASSWORD" ]; then
    credentials='configured'
  else
    result=1
  fi
  if [ -n "$gateway" ] && [ -n "$cloud_gateway" ]; then
    gateways='configured'
  else
    result=1
  fi
  cache_file="$(scm_auth_cache_file "$environment" "$account")"
  if [ -r "$cache_file" ]; then
    expires_at="$(jq -r '.expiresAt // 0' "$cache_file" 2>/dev/null || printf '0')"
    now="$(date +%s)"
    if [[ "$expires_at" =~ ^[0-9]+$ ]] && [ "$expires_at" -gt $((now + 60)) ]; then
      cache="valid-until-$(date -d "@$expires_at" '+%F %T %z')"
    else
      cache='expired-or-invalid'
    fi
  elif [ -n "$SCM_AUTH_LEGACY_TOKEN" ]; then
    cache='legacy-token-present'
  fi
  printf '%s/%s credentials=%s gateways=%s token=%s\n' \
    "$environment" "$account" "$credentials" "$gateways" "$cache"
  return "$result"
}
