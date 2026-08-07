#!/bin/bash
# 招采/云采业务接口自动登录管理工具。不会输出密码、token 或 Cookie。
# 用法：
#   bash scripts/auth.sh doctor
#   bash scripts/auth.sh status [test|uat] [admin|supplier]
#   bash scripts/auth.sh login  [test|uat] [admin|supplier]

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/scm-auth.sh"

usage() {
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
}

command_name="${1:-status}"
environment="${2:-}"
account="${3:-}"

case "$command_name" in
  doctor)
    scm_auth_check_tools
    scm_auth_load_creds
    failed=0
    for environment_name in test uat; do
      for account_name in admin supplier; do
        if ! scm_auth_status "$environment_name" "$account_name"; then
          failed=1
        fi
      done
    done
    [ "$failed" -eq 0 ]
    ;;
  status)
    if [ -n "$environment" ]; then
      scm_auth_status "$environment" "${account:-admin}"
    else
      for environment_name in test uat; do
        for account_name in admin supplier; do
          scm_auth_status "$environment_name" "$account_name"
        done
      done
    fi
    ;;
  login)
    environment="${environment:-test}"
    account="${account:-admin}"
    scm_auth_force_login "$environment" "$account"
    printf '%s/%s 登录成功，token 已写入受控缓存（未输出 token）。\n' "$environment" "$account"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    printf '未知命令：%s\n' "$command_name" >&2
    usage >&2
    exit 2
    ;;
esac
