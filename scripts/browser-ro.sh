#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREDS_FILE="$ROOT_DIR/ai-docs/creds.env"
PW_CONFIG="$ROOT_DIR/.playwright/cli.config.json"
PW_VERSION="0.1.17"
PW_VERSION_CHECKED=0
PW_CACHE_ROOT="/home/t/.cache/work-wsl-browser"
WINDOWS_CHROME_SCRIPT="$ROOT_DIR/scripts/browser/launch-windows-chrome-readonly.ps1"

pw() {
  if [[ "$PW_VERSION_CHECKED" -eq 0 ]]; then
    local installed_version
    installed_version="$(mise x node@24 -- playwright-cli --version)"
    if [[ "$installed_version" != "$PW_VERSION" ]]; then
      echo "Playwright CLI 版本不匹配：需要 $PW_VERSION，当前 $installed_version" >&2
      echo "执行：mise x node@24 -- npm install -g @playwright/cli@$PW_VERSION" >&2
      exit 1
    fi
    PW_VERSION_CHECKED=1
  fi
  mise x node@24 -- playwright-cli "$@"
}

load_creds() {
  if [[ ! -f "$CREDS_FILE" ]]; then
    echo "缺少凭据文件：$CREDS_FILE" >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$CREDS_FILE"
  set +a
}

session_for() {
  case "$1" in
    scheduling-test) echo "scheduling-test-readonly" ;;
    scheduling-uat) echo "scheduling-uat-readonly" ;;
    nacos-test) echo "nacos-test-readonly" ;;
    kubesphere-prod) echo "kubesphere-prod-readonly" ;;
    jenkins) echo "jenkins-readonly" ;;
    *)
      echo "未知平台：$1" >&2
      exit 2
      ;;
  esac
}

start_linux_browser() {
  local platform="$1"
  local url="$2"
  local session
  session="$(session_for "$platform")"
  local profile="$PW_CACHE_ROOT/profiles/$session"

  mkdir -p "$profile" "$PW_CACHE_ROOT/artifacts"
  pw -s="$session" close >/dev/null 2>&1 || true
  mapfile -t stale_pids < <(pgrep -f -- "--user-data-dir=$profile" || true)
  if (( ${#stale_pids[@]} > 0 )); then
    kill "${stale_pids[@]}" 2>/dev/null || true
    for _ in 1 2 3 4; do
      sleep 0.25
      mapfile -t stale_pids < <(pgrep -f -- "--user-data-dir=$profile" || true)
      (( ${#stale_pids[@]} == 0 )) && break
    done
    if (( ${#stale_pids[@]} > 0 )); then
      kill -KILL "${stale_pids[@]}" 2>/dev/null || true
    fi
  fi
  pw -s="$session" open "$url" \
    --config "$PW_CONFIG" \
    --persistent \
    --profile "$profile" >/dev/null
}

login_scheduling_if_needed() {
  local session="$1"
  : "${SCHEDULING_USER:?请在 ai-docs/creds.env 配置 SCHEDULING_USER}"
  : "${SCHEDULING_PASS:?请在 ai-docs/creds.env 配置 SCHEDULING_PASS}"

  if [[ "$(pw --raw -s="$session" eval "location.href")" != *"/toLogin"* ]]; then
    return 0
  fi

  pw -s="$session" fill "getByPlaceholder('请输入登录账号')" "$SCHEDULING_USER" >/dev/null
  pw -s="$session" fill "getByPlaceholder('请输入登录密码')" "$SCHEDULING_PASS" >/dev/null
  pw -s="$session" click "getByRole('button', { name: '登录' })" >/dev/null

  if [[ "$(pw --raw -s="$session" eval "location.href")" == *"/toLogin"* ]]; then
    echo "调度平台登录失败；请检查凭据或只读护栏日志。" >&2
    exit 1
  fi
}

login_nacos_if_possible() {
  local session="$1"
  if [[ -z "${NACOS_USER:-}" || -z "${NACOS_PASS:-}" ]]; then
    echo "Nacos 登录页可达；尚缺 NACOS_USER/NACOS_PASS，未尝试猜密码。" >&2
    return 0
  fi

  if [[ "$(pw --raw -s="$session" eval "location.href")" != *"#/login"* ]]; then
    return 0
  fi

  pw -s="$session" fill "getByPlaceholder('Please input username')" "$NACOS_USER" >/dev/null
  pw -s="$session" fill "getByPlaceholder('Please input password')" "$NACOS_PASS" >/dev/null
  pw -s="$session" click "getByRole('button', { name: 'Submit' })" >/dev/null

  if [[ "$(pw --raw -s="$session" eval "location.href")" == *"#/login"* ]]; then
    echo "Nacos 登录失败；请检查凭据或只读护栏日志。" >&2
    exit 1
  fi
}

start_jenkins() {
  local session
  session="$(session_for jenkins)"
  local windows_script
  windows_script="$(wslpath -w "$WINDOWS_CHROME_SCRIPT")"

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$windows_script" >/dev/null

  for _ in 1 2 3 4 5; do
    if curl -fsS --max-time 2 "http://127.0.0.1:9223/json/version" >/dev/null; then
      break
    fi
    sleep 1
  done
  curl -fsS --max-time 2 "http://127.0.0.1:9223/json/version" >/dev/null

  pw -s="$session" detach >/dev/null 2>&1 || true
  pw attach \
    --cdp "http://127.0.0.1:9223" \
    --session "$session" \
    --config "$PW_CONFIG" >/dev/null
  pw -s="$session" goto "http://jenkins.jdsn.com/login" >/dev/null

  : "${JENKINS_USER:?请在 ai-docs/creds.env 配置 JENKINS_USER}"
  : "${JENKINS_PASS:?请在 ai-docs/creds.env 配置 JENKINS_PASS}"
  if [[ "$(pw --raw -s="$session" eval "location.href")" == *"/login"* ]]; then
    pw -s="$session" fill "getByRole('textbox', { name: '用户名' })" "$JENKINS_USER" >/dev/null
    pw -s="$session" fill "getByRole('textbox', { name: '密码' })" "$JENKINS_PASS" >/dev/null
    pw -s="$session" click "getByRole('button', { name: '登录' })" >/dev/null
  fi

  if [[ "$(pw --raw -s="$session" eval "location.href")" == *"/login"* ]]; then
    echo "Jenkins 登录失败；请检查凭据或 Windows 网络。" >&2
    exit 1
  fi
}

start_platform() {
  local platform="$1"
  load_creds

  case "$platform" in
    scheduling-test)
      start_linux_browser "$platform" "http://10.0.54.16:32740/scm-scheduling-web/toLogin"
      login_scheduling_if_needed "$(session_for "$platform")"
      ;;
    scheduling-uat)
      start_linux_browser "$platform" "http://10.0.54.16:31799/scm-scheduling-web/toLogin"
      login_scheduling_if_needed "$(session_for "$platform")"
      ;;
    nacos-test)
      start_linux_browser "$platform" "http://10.0.54.16:30996/nacos/#/login"
      login_nacos_if_possible "$(session_for "$platform")"
      ;;
    kubesphere-prod)
      start_linux_browser "$platform" "http://10.79.10.201:30880/"
      ;;
    jenkins)
      start_jenkins
      ;;
    *)
      session_for "$platform" >/dev/null
      ;;
  esac

  pw -s="$(session_for "$platform")" snapshot --depth=3
}

run_safe_command() {
  local platform="$1"
  shift
  local command_name="${1:-}"

  case "$command_name" in
    run-code|route|unroute|dialog-accept|request|request-headers|cookie-*|localstorage-*|sessionstorage-*|state-save|state-load)
      echo "只读包装器禁止命令：$command_name" >&2
      echo "需要扩展能力时先审查 scripts/browser/readonly-guard.js，不要绕过护栏。" >&2
      exit 3
      ;;
  esac

  pw -s="$(session_for "$platform")" "$@"
}

stop_platform() {
  local platform="$1"
  local session
  session="$(session_for "$platform")"

  if [[ "$platform" == "jenkins" ]]; then
    pw -s="$session" detach >/dev/null 2>&1 || true
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$WINDOWS_CHROME_SCRIPT")" \
      -Stop >/dev/null
  else
    pw -s="$session" close >/dev/null 2>&1 || true
  fi
  echo "已关闭：$platform"
}

usage() {
  cat <<'EOF'
用法：
  bash scripts/browser-ro.sh start <scheduling-test|scheduling-uat|nacos-test|kubesphere-prod|jenkins>
  bash scripts/browser-ro.sh cmd   <平台> <playwright-cli 安全命令...>
  bash scripts/browser-ro.sh stop  <平台>
  bash scripts/browser-ro.sh list

示例：
  bash scripts/browser-ro.sh start scheduling-test
  bash scripts/browser-ro.sh cmd scheduling-test goto http://10.0.54.16:32740/scm-scheduling-web/jobinfo
  bash scripts/browser-ro.sh cmd scheduling-test snapshot
  bash scripts/browser-ro.sh cmd jenkins goto http://jenkins.jdsn.com/job/scm-source-all-uat/

说明：
  登录和只读查询会放行；保存、发布、构建、执行、启停、增删改请求由网络护栏拦截。
EOF
}

case "${1:-}" in
  start)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    start_platform "$2"
    ;;
  cmd)
    [[ $# -ge 3 ]] || { usage; exit 2; }
    platform="$2"
    shift 2
    run_safe_command "$platform" "$@"
    ;;
  stop)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    stop_platform "$2"
    ;;
  list)
    pw list
    ;;
  *)
    usage
    exit 2
    ;;
esac
