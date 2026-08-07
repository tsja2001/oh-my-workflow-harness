#!/usr/bin/env bash

# Low-level, read-only adapters for internal SCM platforms.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CREDS_FILE="$WORKSPACE_ROOT/ai-docs/creds.env"
BROWSER_RO="$WORKSPACE_ROOT/scripts/browser-ro.sh"
SAFE_OUTPUT="$SCRIPT_DIR/safe-output.js"
KUBESPHERE_PASSWORD="$SCRIPT_DIR/kubesphere-password.js"
USER_HOME_DIR="$(getent passwd "$(id -u)" | cut -d: -f6)"
CACHE_BASE="${XDG_CACHE_HOME:-$USER_HOME_DIR/.cache}"
CACHE_ROOT="$CACHE_BASE/work-wsl-platforms"
DOCS_BASE="http://yingle.jdsn.com/yingle1991/"
JENKINS_BASE="http://jenkins.jdsn.com"
NACOS_BASE="${NACOS_BASE_URL:-http://10.0.54.16:30996/nacos}"

mkdir -p "$CACHE_ROOT"
chmod 700 "$CACHE_ROOT"

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

with_browser_lock() {
  local profile="$1"
  shift
  local safe_profile="${profile//[^A-Za-z0-9._-]/_}"
  local lock_file="$CACHE_ROOT/browser-$safe_profile.lock"
  (
    flock -w 120 9 ||
      die "等待 $profile 浏览器会话超过 120 秒；请勿并行操作同一平台"
    "$@"
  ) 9>"$lock_file"
}

load_creds() {
  [[ -f "$CREDS_FILE" ]] || die "缺少凭据文件：$CREDS_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$CREDS_FILE"
  set +a
}

urlencode() {
  jq -rn --arg value "$1" '$value | @uri'
}

valid_k8s_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9.-]*$ ]] ||
    die "K8s 名称只允许小写字母、数字、点和短横线：$1"
}

environment_namespace() {
  case "$1" in
    dev)
      [[ -n "${K8S_NAMESPACE_DEV:-}" ]] ||
        die "dev 的真实命名空间未固定；请先查询 namespaces 并配置 K8S_NAMESPACE_DEV"
      printf '%s\n' "$K8S_NAMESPACE_DEV"
      ;;
    test) printf '%s\n' "${K8S_NAMESPACE_TEST:-si-scm-product-test}" ;;
    uat) printf '%s\n' "${K8S_NAMESPACE_UAT:-si-scm-product-uat}" ;;
    prod)
      [[ -n "${K8S_NAMESPACE_PROD:-}" ]] ||
        die "生产真实命名空间尚未核实；请先由运维确认并配置 K8S_NAMESPACE_PROD"
      printf '%s\n' "$K8S_NAMESPACE_PROD"
      ;;
    *) die "环境必须是 dev、test、uat 或 prod：$1" ;;
  esac
}

nacos_namespace() {
  case "$1" in
    dev) printf '%s\n' "${NACOS_NAMESPACE_DEV:-scm-jdsn}" ;;
    test) printf '%s\n' "${NACOS_NAMESPACE_TEST:-scm-jdsn-test}" ;;
    uat) printf '%s\n' "${NACOS_NAMESPACE_UAT:-scm-jdsn-uat}" ;;
    prod) printf '%s\n' "${NACOS_NAMESPACE_PROD:-jdsn-prod}" ;;
    *) die "环境必须是 dev、test、uat 或 prod：$1" ;;
  esac
}

k8s_select_connection() {
  local env_name="$1"
  local need_namespace="${2:-1}"
  load_creds
  if [[ "$need_namespace" -eq 1 ]]; then
    KS_NAMESPACE="$(environment_namespace "$env_name")"
  else
    KS_NAMESPACE=""
  fi

  if [[ "$env_name" == "prod" ]]; then
    KS_URL="${K8S_PROD_URL:-http://10.79.10.201:30880}"
    KS_USER="${K8S_PROD_USER:-${K8S_USER:-}}"
    KS_PASS="${K8S_PROD_PASS:-${K8S_PASS:-}}"
  else
    KS_URL="${K8S_URL:-}"
    KS_USER="${K8S_USER:-}"
    KS_PASS="${K8S_PASS:-}"
  fi

  [[ -n "$KS_URL" ]] || die "未配置 K8S_URL"
  [[ -n "$KS_USER" ]] || die "未配置 K8S_USER"
  [[ -n "$KS_PASS" ]] || die "未配置 K8S_PASS"
  KS_URL="${KS_URL%/}"

  local cache_key
  cache_key="$(printf '%s' "$KS_URL|$KS_USER" | sha256sum | cut -c1-16)"
  KS_COOKIE="$CACHE_ROOT/kubesphere-$cache_key.cookies"
  touch "$KS_COOKIE"
  chmod 600 "$KS_COOKIE"
}

k8s_login() {
  local encrypted payload status
  encrypted="$(printf '%s' "$KS_PASS" | node "$KUBESPHERE_PASSWORD")"
  payload="$(jq -cn \
    --arg username "$KS_USER" \
    --arg encrypt "$encrypted" \
    '{username: $username, encrypt: $encrypt}')"

  status="$(curl -sS \
    --connect-timeout 5 \
    --max-time 30 \
    -o /dev/null \
    -w '%{http_code}' \
    -c "$KS_COOKIE" \
    -H 'Content-Type: application/json' \
    -X POST \
    --data "$payload" \
    "$KS_URL/login")"
  [[ "$status" =~ ^[23] ]] || die "KubeSphere 登录失败（HTTP $status），请检查凭据或网络"
  chmod 600 "$KS_COOKIE"
}

k8s_ensure_login() {
  local status
  status="$(curl -sS \
    --connect-timeout 5 \
    --max-time 15 \
    -o /dev/null \
    -w '%{http_code}' \
    -b "$KS_COOKIE" \
    "$KS_URL/api/v1/namespaces")" || status="000"
  if [[ "$status" != "200" ]]; then
    k8s_login
  fi
}

k8s_get() {
  local path="$1"
  local body_file status
  body_file="$(mktemp "$CACHE_ROOT/k8s-response.XXXXXX")"
  chmod 600 "$body_file"

  status="$(curl -sS \
    --connect-timeout 5 \
    --max-time 45 \
    -o "$body_file" \
    -w '%{http_code}' \
    -b "$KS_COOKIE" \
    "$KS_URL$path")" || status="000"

  if [[ "$status" == "401" || "$status" == "403" ]]; then
    k8s_login
    status="$(curl -sS \
      --connect-timeout 5 \
      --max-time 45 \
      -o "$body_file" \
      -w '%{http_code}' \
      -b "$KS_COOKIE" \
      "$KS_URL$path")" || status="000"
  fi

  if [[ ! "$status" =~ ^2 ]]; then
    printf 'K8s 查询失败（HTTP %s）：' "$status" >&2
    node "$SAFE_OUTPUT" redact <"$body_file" | head -c 800 >&2
    printf '\n' >&2
    rm -f "$body_file"
    return 1
  fi

  cat "$body_file"
  rm -f "$body_file"
}

k8s_deployments_json() {
  k8s_get "/apis/apps/v1/namespaces/$KS_NAMESPACE/deployments"
}

k8s_pods_json() {
  k8s_get "/api/v1/namespaces/$KS_NAMESPACE/pods"
}

resolve_deployment() {
  local query="$1"
  k8s_deployments_json | jq -r --arg query "$query" '
    (
      [.items[] | select(.metadata.name == $query)] +
      [.items[] | select(.metadata.name != $query and (.metadata.name | contains($query)))]
    )[0].metadata.name // empty
  '
}

resolve_pod() {
  local query="$1"
  k8s_pods_json | jq -r --arg query "$query" '
    [
      .items[]
      | select(
          .metadata.name == $query
          or (.metadata.name | startswith($query + "-"))
          or (.metadata.name | contains($query))
        )
      | select(.metadata.deletionTimestamp == null)
    ]
    | sort_by(.metadata.creationTimestamp)
    | reverse
    | .[0].metadata.name // empty
  '
}

k8s_namespaces() {
  local env_name="$1"
  k8s_select_connection "$env_name" 0
  k8s_ensure_login
  k8s_get "/api/v1/namespaces" |
    jq -r '.items | sort_by(.metadata.name)[] | .metadata.name'
}

k8s_deployments() {
  local env_name="$1"
  local filter="${2:-}"
  k8s_select_connection "$env_name"
  k8s_ensure_login
  k8s_deployments_json | jq -r --arg filter "$filter" '
    ["NAME", "READY", "UP-TO-DATE", "AVAILABLE", "IMAGE", "CREATED"],
    (
      .items
      | map(select($filter == "" or (.metadata.name | contains($filter))))
      | sort_by(.metadata.name)[]
      | [
          .metadata.name,
          ((.status.readyReplicas // 0) | tostring) + "/" + ((.spec.replicas // 0) | tostring),
          (.status.updatedReplicas // 0),
          (.status.availableReplicas // 0),
          ([.spec.template.spec.containers[].image] | join(",")),
          .metadata.creationTimestamp
        ]
    )
    | @tsv
  '
}

k8s_deployment() {
  local env_name="$1"
  local query="$2"
  valid_k8s_name "$query"
  k8s_select_connection "$env_name"
  k8s_ensure_login

  local deployment
  deployment="$(resolve_deployment "$query")"
  [[ -n "$deployment" ]] || die "命名空间 $KS_NAMESPACE 未找到 Deployment：$query"

  k8s_get "/apis/apps/v1/namespaces/$KS_NAMESPACE/deployments/$deployment" |
    jq '{
      namespace: .metadata.namespace,
      deployment: .metadata.name,
      generation: .metadata.generation,
      rolloutRevision: .metadata.annotations["deployment.kubernetes.io/revision"],
      replicas: {
        desired: (.spec.replicas // 0),
        updated: (.status.updatedReplicas // 0),
        ready: (.status.readyReplicas // 0),
        available: (.status.availableReplicas // 0),
        unavailable: (.status.unavailableReplicas // 0)
      },
      strategy: .spec.strategy.type,
      containers: [
        .spec.template.spec.containers[]
        | {name, image, ports: [.ports[]?.containerPort]}
      ],
      conditions: [
        .status.conditions[]?
        | {type, status, reason, message, lastUpdateTime}
      ]
    }'
}

k8s_pods() {
  local env_name="$1"
  local filter="${2:-}"
  k8s_select_connection "$env_name"
  k8s_ensure_login
  k8s_pods_json | jq -r --arg filter "$filter" '
    ["NAME", "READY", "PHASE", "RESTARTS", "IMAGE", "NODE", "CREATED"],
    (
      .items
      | map(select($filter == "" or (.metadata.name | contains($filter))))
      | sort_by(.metadata.creationTimestamp)
      | reverse[]
      | [
          .metadata.name,
          (
            ([.status.containerStatuses[]? | select(.ready == true)] | length | tostring)
            + "/"
            + ([.spec.containers[]] | length | tostring)
          ),
          .status.phase,
          ([.status.containerStatuses[]?.restartCount] | add // 0),
          ([.spec.containers[].image] | join(",")),
          (.spec.nodeName // ""),
          .metadata.creationTimestamp
        ]
    )
    | @tsv
  '
}

k8s_logs() {
  local env_name="$1"
  local query="$2"
  shift 2
  valid_k8s_name "$query"

  local tail_lines=300
  local previous=0
  local errors_only=0
  local container=""
  local since_spec=""
  local since_seconds=""
  local match=""
  while (($#)); do
    case "$1" in
      --tail)
        [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--tail 后必须是数字"
        tail_lines="$2"
        shift 2
        ;;
      --previous)
        previous=1
        shift
        ;;
      --errors)
        errors_only=1
        shift
        ;;
      --since)
        [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*[smhd]$ ]] ||
          die "--since 格式必须是正整数加 s/m/h/d，例如 30m、3h、2d"
        since_spec="$2"
        shift 2
        ;;
      --match)
        [[ $# -ge 2 && -n "$2" ]] || die "--match 后必须有正则关键词"
        ((${#2} <= 200)) || die "--match 不能超过 200 个字符"
        [[ "$2" != *$'\n'* && "$2" != *$'\r'* ]] ||
          die "--match 不能包含换行"
        match="$2"
        shift 2
        ;;
      --container)
        [[ $# -ge 2 ]] || die "--container 后必须有容器名"
        container="$2"
        shift 2
        ;;
      *) die "未知日志参数：$1" ;;
    esac
  done
  ((${#tail_lines} <= 5)) || die "--tail 数值过大"
  ((tail_lines >= 1)) || die "--tail 必须大于 0"
  if [[ -n "$match" ]]; then
    ((tail_lines <= 10000)) ||
      die "使用 --match 时，--tail 最大为 10000"
  else
    ((tail_lines <= 2000)) ||
      die "未使用 --match 时，--tail 最大为 2000"
  fi

  if [[ -n "$since_spec" ]]; then
    local since_value="${since_spec%?}"
    ((${#since_value} <= 6)) ||
      die "--since 数值过大；最大允许 7d"
    case "${since_spec: -1}" in
      s) since_seconds="$since_value" ;;
      m) since_seconds="$((since_value * 60))" ;;
      h) since_seconds="$((since_value * 3600))" ;;
      d) since_seconds="$((since_value * 86400))" ;;
    esac
    ((since_seconds <= 604800)) ||
      die "--since 最大为 7d；更长时间请先缩小问题窗口"
  fi

  k8s_select_connection "$env_name"
  k8s_ensure_login
  local pod
  pod="$(resolve_pod "$query")"
  [[ -n "$pod" ]] || die "命名空间 $KS_NAMESPACE 未找到 Pod：$query"

  local path
  path="/api/v1/namespaces/$KS_NAMESPACE/pods/$pod/log?timestamps=true&tailLines=$tail_lines"
  [[ "$previous" -eq 1 ]] && path="$path&previous=true"
  [[ -n "$since_seconds" ]] && path="$path&sinceSeconds=$since_seconds"
  if [[ -n "$container" ]]; then
    valid_k8s_name "$container"
    path="$path&container=$(urlencode "$container")"
  fi

  local output_file
  output_file="$(mktemp "$CACHE_ROOT/k8s-log.XXXXXX")"
  chmod 600 "$output_file"
  if [[ "$errors_only" -eq 1 ]]; then
    if ! k8s_get "$path" | node "$SAFE_OUTPUT" errors >"$output_file"; then
      rm -f "$output_file"
      return 1
    fi
  else
    if ! k8s_get "$path" | node "$SAFE_OUTPUT" redact >"$output_file"; then
      rm -f "$output_file"
      return 1
    fi
  fi

  if [[ -n "$match" ]]; then
    local matched_output
    matched_output="$(rg -i -- "$match" "$output_file" | sed -n '1,500p' || true)"
    if [[ -n "$matched_output" ]]; then
      printf '%s\n' "$matched_output"
    else
      printf 'INFO 在指定的时间/尾部窗口内未找到匹配日志；这不代表历史上从未出现。\n'
    fi
  else
    cat "$output_file"
  fi
  rm -f "$output_file"
}

k8s_eslogs() {
  local env_name="$1"
  local query="$2"
  shift 2
  valid_k8s_name "$query"

  local tail_lines=300
  local errors_only=0
  local since_spec=""
  local since_seconds=""
  local match=""
  while (($#)); do
    case "$1" in
      --tail)
        [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--tail 后必须是数字"
        tail_lines="$2"
        shift 2
        ;;
      --errors)
        errors_only=1
        shift
        ;;
      --since)
        [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*[smhd]$ ]] ||
          die "--since 格式必须是正整数加 s/m/h/d，例如 30m、3h、2d"
        since_spec="$2"
        shift 2
        ;;
      --match)
        [[ $# -ge 2 && -n "$2" ]] || die "--match 后必须有正则关键词"
        ((${#2} <= 200)) || die "--match 不能超过 200 个字符"
        [[ "$2" != *$'\n'* && "$2" != *$'\r'* ]] ||
          die "--match 不能包含换行"
        match="$2"
        shift 2
        ;;
      *) die "未知日志参数：$1" ;;
    esac
  done
  ((${#tail_lines} <= 4)) || die "--tail 数值过大"
  ((tail_lines >= 1)) || die "--tail 必须大于 0"
  if [[ -n "$match" ]]; then
    ((tail_lines <= 5000)) ||
      die "使用 --match 时，--tail 最大为 5000"
  else
    ((tail_lines <= 2000)) ||
      die "未使用 --match 时，--tail 最大为 2000"
  fi

  if [[ -n "$since_spec" ]]; then
    local since_value="${since_spec%?}"
    ((${#since_value} <= 6)) ||
      die "--since 数值过大；最大允许 7d"
    case "${since_spec: -1}" in
      s) since_seconds="$since_value" ;;
      m) since_seconds="$((since_value * 60))" ;;
      h) since_seconds="$((since_value * 3600))" ;;
      d) since_seconds="$((since_value * 86400))" ;;
    esac
    ((since_seconds <= 604800)) ||
      die "--since 最大为 7d；更长时间请先缩小问题窗口"
  fi

  k8s_select_connection "$env_name"
  k8s_ensure_login

  local param="workloads"
  local value=""
  if [[ "$query" =~ -[a-z0-9]{9,10}-[a-z0-9]{5}$ ]]; then
    param="pods"
    value="$query"
  else
    value="$(resolve_deployment "$query")"
  fi
  [[ -n "$value" ]] || die "命名空间 $KS_NAMESPACE 未找到 Deployment 或 Pod：$query"

  local path="/kapis/tenant.kubesphere.io/v1alpha2/logs?operation=query"
  path="$path&namespaces=$KS_NAMESPACE&$param=$(urlencode "$value")"
  local end_time start_time
  end_time="$(date +%s)"
  if [[ -n "$since_spec" ]]; then
    start_time="$((end_time - since_seconds))"
    path="$path&start_time=$start_time&end_time=$end_time"
  fi
  local log_query=""
  if [[ -n "$match" && "$match" =~ ^[A-Za-z0-9_]+$ ]]; then
    log_query="$match"
    path="$path&log_query=$(urlencode "$log_query")"
  fi
  path="$path&size=$tail_lines&sort=desc"

  local raw_file total
  raw_file="$(mktemp "$CACHE_ROOT/k8s-eslog-raw.XXXXXX")"
  chmod 600 "$raw_file"
  if ! k8s_get "$path" >"$raw_file"; then
    rm -f "$raw_file"
    return 1
  fi
  total="$(jq -r '.query.total // 0' "$raw_file")"
  printf 'ES 日志窗口内命中 %s 条，已取最新 %s 条%s\n' \
    "$total" "$tail_lines" \
    "${log_query:+（关键词 $log_query 已下推检索）}" >&2

  local output_file
  output_file="$(mktemp "$CACHE_ROOT/k8s-eslog.XXXXXX")"
  chmod 600 "$output_file"
  if ! jq -r '
      .query.records[]? |
      (.time // "") as $t |
      (.log // "" | sub("\n$"; "")) as $l |
      "\($t) \($l)"
    ' "$raw_file" | LC_ALL=C sort -k1,1 >"$output_file"; then
    rm -f "$raw_file" "$output_file"
    return 1
  fi
  rm -f "$raw_file"

  if [[ "$errors_only" -eq 1 ]]; then
    if ! node "$SAFE_OUTPUT" errors <"$output_file" >"$output_file.clean"; then
      rm -f "$output_file" "$output_file.clean"
      return 1
    fi
  else
    node "$SAFE_OUTPUT" redact <"$output_file" >"$output_file.clean"
  fi

  if [[ -n "$match" ]]; then
    local matched_output
    matched_output="$(rg -i -- "$match" "$output_file.clean" | sed -n '1,500p' || true)"
    if [[ -n "$matched_output" ]]; then
      printf '%s\n' "$matched_output"
    else
      printf 'INFO 在指定窗口内未找到匹配日志；这不代表历史上从未出现。\n'
    fi
  else
    cat "$output_file.clean"
  fi
  rm -f "$output_file" "$output_file.clean"
}

k8s_events() {
  local env_name="$1"
  local query="$2"
  valid_k8s_name "$query"
  k8s_select_connection "$env_name"
  k8s_ensure_login
  local pod
  pod="$(resolve_pod "$query")"
  [[ -n "$pod" ]] || die "命名空间 $KS_NAMESPACE 未找到 Pod：$query"

  local selector
  selector="$(urlencode "involvedObject.name=$pod")"
  k8s_get "/api/v1/namespaces/$KS_NAMESPACE/events?fieldSelector=$selector" |
    jq -r '
      ["TIME", "TYPE", "REASON", "COUNT", "MESSAGE"],
      (
        .items
        | sort_by(.lastTimestamp // .eventTime // .metadata.creationTimestamp)[]
        | [
            (.lastTimestamp // .eventTime // .metadata.creationTimestamp),
            .type,
            .reason,
            (.count // 1),
            .message
          ]
      )
      | @tsv
    ' |
    node "$SAFE_OUTPUT" redact
}

k8s_diagnose() {
  local env_name="$1"
  local query="$2"
  valid_k8s_name "$query"

  printf '## Deployment\n'
  k8s_deployment "$env_name" "$query"
  printf '\n## Pods\n'
  k8s_pods "$env_name" "$query"
  printf '\n## Latest pod events\n'
  k8s_events "$env_name" "$query" || true
  printf '\n## Current error lines\n'
  k8s_logs "$env_name" "$query" --tail 500 --errors || true

  k8s_select_connection "$env_name"
  k8s_ensure_login
  local pod restart_count
  pod="$(resolve_pod "$query")"
  restart_count="$(k8s_pods_json | jq -r --arg pod "$pod" '
    [.items[] | select(.metadata.name == $pod) | .status.containerStatuses[]?.restartCount]
    | add // 0
  ')"
  if ((restart_count > 0)); then
    printf '\n## Previous container error lines\n'
    k8s_logs "$env_name" "$pod" --previous --tail 500 --errors || true
  fi
}

browser_ensure() {
  local platform="$1"
  [[ -x "$BROWSER_RO" || -f "$BROWSER_RO" ]] || die "缺少只读浏览器包装器：$BROWSER_RO"
  if bash "$BROWSER_RO" cmd "$platform" --raw eval "location.href" >/dev/null 2>&1; then
    return 0
  fi
  bash "$BROWSER_RO" start "$platform" >/dev/null
}

browser_goto() {
  local platform="$1"
  local url="$2"
  bash "$BROWSER_RO" cmd "$platform" goto "$url" >/dev/null
}

browser_goto_authenticated() {
  local platform="$1"
  local url="$2"
  local login_marker="$3"
  browser_ensure "$platform"
  browser_goto "$platform" "$url"

  local current_url
  current_url="$(browser_eval "$platform" "location.href")"
  if [[ "$current_url" == *"$login_marker"* ]]; then
    bash "$BROWSER_RO" start "$platform" >/dev/null
    browser_goto "$platform" "$url"
    current_url="$(browser_eval "$platform" "location.href")"
  fi
  [[ "$current_url" != *"$login_marker"* ]]
}

browser_eval() {
  local platform="$1"
  local expression="$2"
  local result
  result="$(bash "$BROWSER_RO" cmd "$platform" --raw eval "$expression")"
  if printf '%s' "$result" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$result" | jq -r 'if type == "string" then . else tostring end'
  else
    printf '%s\n' "$result"
  fi
}

nacos_config_url() {
  local env_name="$1"
  local data_id="$2"
  local group="$3"
  local namespace
  namespace="$(nacos_namespace "$env_name")"
  printf '%s/#/configdetail?serverId=center&dataId=%s&group=%s&namespace=%s\n' \
    "$NACOS_BASE" \
    "$(urlencode "$data_id")" \
    "$(urlencode "$group")" \
    "$(urlencode "$namespace")"
}

nacos_content() {
  local env_name="$1"
  local data_id="$2"
  local group="${3:-common}"
  load_creds
  NACOS_BASE="${NACOS_BASE_URL:-$NACOS_BASE}"
  browser_goto_authenticated \
    "nacos-test" \
    "$(nacos_config_url "$env_name" "$data_id" "$group")" \
    "#/login" ||
    die "Nacos 仍在登录页；请先在 ai-docs/creds.env 配置 NACOS_USER/NACOS_PASS"

  local expression
  expression='(() => {
    const candidates = [];
    for (const element of document.querySelectorAll("textarea")) {
      if (element.value && element.value.trim()) candidates.push(element.value);
    }
    for (const element of document.querySelectorAll(".CodeMirror-code, .view-lines, .cm-content, pre")) {
      const text = element.innerText || element.textContent || "";
      if (text.trim()) candidates.push(text);
    }
    candidates.sort((left, right) => right.length - left.length);
    return candidates[0] || "";
  })()'
  local content
  content="$(browser_eval "nacos-test" "$expression")"
  [[ -n "${content//[[:space:]]/}" ]] ||
    die "页面未提取到配置正文；请核对 Data ID、命名空间和只读权限"
  printf '%s\n' "$content"
}

nacos_read() {
  nacos_content "$@" | node "$SAFE_OUTPUT" redact
}

nacos_keys() {
  nacos_content "$@" | node "$SAFE_OUTPUT" keys
}

nacos_compare() {
  local left_env="$1"
  local left_data_id="$2"
  local right_env="$3"
  local right_data_id="$4"
  local group="${5:-common}"
  local temp_dir
  temp_dir="$(mktemp -d "$CACHE_ROOT/nacos-compare.XXXXXX")"
  chmod 700 "$temp_dir"

  if ! nacos_content "$left_env" "$left_data_id" "$group" |
    node "$SAFE_OUTPUT" keys >"$temp_dir/left"; then
    rm -f "$temp_dir/left" "$temp_dir/right"
    rmdir "$temp_dir"
    return 1
  fi
  if ! nacos_content "$right_env" "$right_data_id" "$group" |
    node "$SAFE_OUTPUT" keys >"$temp_dir/right"; then
    rm -f "$temp_dir/left" "$temp_dir/right"
    rmdir "$temp_dir"
    return 1
  fi

  printf '## 只在 %s/%s 中存在\n' "$left_env" "$left_data_id"
  comm -23 "$temp_dir/left" "$temp_dir/right"
  printf '\n## 只在 %s/%s 中存在\n' "$right_env" "$right_data_id"
  comm -13 "$temp_dir/left" "$temp_dir/right"

  rm -f "$temp_dir/left" "$temp_dir/right"
  rmdir "$temp_dir"
}

jenkins_job_path() {
  local job_name="$1"
  [[ -n "$job_name" && "$job_name" != *".."* ]] || die "Jenkins Job 名称无效"
  local path=""
  local segment
  IFS='/' read -r -a segments <<<"$job_name"
  for segment in "${segments[@]}"; do
    [[ -n "$segment" ]] || continue
    path="$path/job/$(urlencode "$segment")"
  done
  printf '%s\n' "$path"
}

jenkins_get() {
  local relative_url="$1"
  browser_goto_authenticated "jenkins" "$JENKINS_BASE$relative_url" "/login" ||
    die "Jenkins 登录失败，请检查 JENKINS_USER/JENKINS_PASS"
  browser_eval "jenkins" "document.body.innerText"
}

jenkins_last_build_number() {
  local job_name="$1"
  local job_path
  job_path="$(jenkins_job_path "$job_name")"
  jenkins_get "$job_path/api/json?tree=lastBuild[number]" | jq -r '.lastBuild.number // empty'
}

jenkins_jobs() {
  local query="${1:-}"
  jenkins_get "/api/json?tree=jobs[name,url,color]" |
    jq --arg query "$query" '
      [
        .jobs[]
        | select(
            $query == ""
            or (.name | ascii_downcase | contains($query | ascii_downcase))
          )
        | {name, color, url}
      ]
    '
}

jenkins_job() {
  local job_name="$1"
  local job_path
  job_path="$(jenkins_job_path "$job_name")"
  jenkins_get "$job_path/api/json?tree=name,url,color,buildable,inQueue,lastBuild[number,url],lastCompletedBuild[number,url],lastSuccessfulBuild[number,url],lastFailedBuild[number,url]" |
    jq .
}

jenkins_builds() {
  local job_name="$1"
  local limit="${2:-10}"
  [[ "$limit" =~ ^[0-9]+$ && ${#limit} -le 2 && "$limit" -ge 1 && "$limit" -le 50 ]] ||
    die "构建数量必须是 1 到 50"
  local job_path
  job_path="$(jenkins_job_path "$job_name")"
  jenkins_get "$job_path/api/json?tree=builds[number,result,building,timestamp,duration,url]{0,$limit}" |
    jq '[
      .builds[]
      | . + {startedAtUtc: ((.timestamp / 1000) | todateiso8601)}
    ]'
}

jenkins_parameter_build() {
  local job_name="$1"
  local parameter_name="$2"
  local parameter_value="$3"
  local limit="${4:-30}"
  [[ "$parameter_name" =~ ^[A-Za-z0-9_.-]+$ ]] ||
    die "Jenkins 参数名无效：$parameter_name"
  [[ -n "$parameter_value" && "$parameter_value" != *$'\n'* && "$parameter_value" != *$'\r'* ]] ||
    die "Jenkins 参数值不能为空或包含换行"
  ((${#parameter_value} <= 200)) || die "Jenkins 参数值不能超过 200 个字符"
  [[ "$limit" =~ ^[0-9]+$ && ${#limit} -le 3 && "$limit" -ge 1 && "$limit" -le 100 ]] ||
    die "搜索构建数量必须是 1 到 100"

  local job_path
  job_path="$(jenkins_job_path "$job_name")"
  jenkins_get "$job_path/api/json?tree=builds[number,result,building,timestamp,duration,url,actions[parameters[name,value]]]{0,$limit}" |
    jq --arg name "$parameter_name" --arg value "$parameter_value" '
      [
        .builds[]
        | select(any(.actions[]?.parameters[]?; .name == $name and (.value | tostring) == $value))
        | {
            number,
            result,
            building,
            timestamp,
            startedAtUtc: ((.timestamp / 1000) | todateiso8601),
            durationMs: .duration,
            url,
            matchedParameter: {name: $name, value: $value}
          }
      ][0] // error("最近查询窗口没有匹配参数的构建")
    ' |
    node "$SAFE_OUTPUT" redact
}

jenkins_build() {
  local job_name="$1"
  local build_number="${2:-lastBuild}"
  local job_path
  job_path="$(jenkins_job_path "$job_name")"
  [[ "$build_number" == "lastBuild" || "$build_number" =~ ^[0-9]+$ ]] ||
    die "构建号必须是数字或 lastBuild：$build_number"

  local tree
  tree='number,result,building,duration,timestamp,url,displayName,fullDisplayName,actions[parameters[name,value],causes[shortDescription,upstreamProject,upstreamBuild],lastBuiltRevision[SHA1]],changeSet[items[commitId,msg,author[fullName]]]'
  jenkins_get "$job_path/$build_number/api/json?tree=$tree" |
    jq '
      {
        number,
        result,
        building,
        timestamp,
        startedAtUtc: ((.timestamp / 1000) | todateiso8601),
        durationMs: .duration,
        url,
        causes: [.actions[]?.causes[]?],
        revisions: [.actions[]?.lastBuiltRevision.SHA1? | select(. != null)],
        parameters: [
          .actions[]?.parameters[]?
          | {
              name,
              value: (
                if (.name | test("password|passwd|pwd|secret|token|credential|creid|key"; "i"))
                then "[REDACTED]"
                else .value
                end
              )
            }
        ],
        changes: [
          .changeSet.items[]?
          | {commitId, message: .msg, author: .author.fullName}
        ]
      }
    ' |
    node "$SAFE_OUTPUT" redact
}

jenkins_log() {
  local job_name="$1"
  shift
  local build_number=""
  if [[ "${1:-}" =~ ^[0-9]+$ || "${1:-}" == "lastBuild" ]]; then
    build_number="$1"
    shift
  fi
  local tail_lines=300
  local errors_only=0
  while (($#)); do
    case "$1" in
      --tail)
        [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--tail 后必须是数字"
        tail_lines="$2"
        shift 2
        ;;
      --errors)
        errors_only=1
        shift
        ;;
      *) die "未知 Jenkins 日志参数：$1" ;;
    esac
  done
  ((${#tail_lines} <= 4)) || die "--tail 数值过大"
  ((tail_lines >= 1 && tail_lines <= 5000)) ||
    die "Jenkins 日志 --tail 必须是 1 到 5000"

  [[ -n "$build_number" ]] || build_number="lastBuild"
  [[ "$build_number" == "lastBuild" || "$build_number" =~ ^[0-9]+$ ]] ||
    die "构建号必须是数字或 lastBuild：$build_number"

  local job_path
  job_path="$(jenkins_job_path "$job_name")"
  if [[ "$errors_only" -eq 1 ]]; then
    jenkins_get "$job_path/$build_number/consoleText" |
      tail -n "$tail_lines" |
      node "$SAFE_OUTPUT" errors
  else
    jenkins_get "$job_path/$build_number/consoleText" |
      tail -n "$tail_lines" |
      node "$SAFE_OUTPUT" redact
  fi
}

jenkins_evidence() {
  local job_name="$1"
  local build_number="${2:-lastBuild}"
  [[ "$build_number" == "lastBuild" || "$build_number" =~ ^[0-9]+$ ]] ||
    die "构建号必须是数字或 lastBuild：$build_number"
  local job_path
  job_path="$(jenkins_job_path "$job_name")"
  jenkins_get "$job_path/$build_number/consoleText" |
    tail -n 2500 |
    grep -Ei 'checking out revision|commit message|git_branch|git rev-parse|git checkout|docker (build|push)|successfully built|successfully tagged|kubectl (apply|set image|rollout)|deployment\.apps|^[[:space:]]*image:|build (success|failure)|finished:|upstream project' |
    tail -n 160 |
    node "$SAFE_OUTPUT" redact || true
}

scheduling_platform() {
  case "$1" in
    test) printf '%s\n' "scheduling-test" ;;
    uat) printf '%s\n' "scheduling-uat" ;;
    *) die "当前已验证的调度平台环境只有 test、uat；其他环境请按 references/platform-index.md 扩展" ;;
  esac
}

scheduling_base() {
  case "$1" in
    test) printf '%s\n' "http://10.0.54.16:32740/scm-scheduling-web" ;;
    uat) printf '%s\n' "http://10.0.54.16:31799/scm-scheduling-web" ;;
    *) die "当前已验证的调度平台环境只有 test、uat" ;;
  esac
}

scheduling_executors() {
  local env_name="$1"
  local platform base
  platform="$(scheduling_platform "$env_name")"
  base="$(scheduling_base "$env_name")"
  browser_goto_authenticated "$platform" "$base/jobinfo" "/toLogin" ||
    die "调度平台登录失败，请检查 SCHEDULING_USER/SCHEDULING_PASS"
  browser_eval "$platform" \
    'JSON.stringify([...document.querySelectorAll("#jobGroup option")].map(option => ({id: option.value, name: option.textContent.trim()})))' |
    jq .
}

scheduling_jobs() {
  local env_name="$1"
  shift
  local executor=""
  local description=""
  local handler=""
  local status="all"
  while (($#)); do
    case "$1" in
      --executor)
        [[ $# -ge 2 ]] || die "--executor 后必须有执行器名称或 ID"
        executor="$2"
        shift 2
        ;;
      --desc)
        [[ $# -ge 2 ]] || die "--desc 后必须有关键词"
        description="$2"
        shift 2
        ;;
      --handler)
        [[ $# -ge 2 ]] || die "--handler 后必须有关键词"
        handler="$2"
        shift 2
        ;;
      --status)
        [[ $# -ge 2 ]] || die "--status 后必须是 all、running 或 stopped"
        status="$2"
        shift 2
        ;;
      *) die "未知调度任务查询参数：$1" ;;
    esac
  done

  local platform base
  platform="$(scheduling_platform "$env_name")"
  base="$(scheduling_base "$env_name")"
  browser_goto_authenticated "$platform" "$base/jobinfo" "/toLogin" ||
    die "调度平台登录失败，请检查 SCHEDULING_USER/SCHEDULING_PASS"

  if [[ -n "$executor" ]]; then
    bash "$BROWSER_RO" cmd "$platform" select "#jobGroup" "$executor" >/dev/null
  fi
  [[ -z "$description" ]] ||
    bash "$BROWSER_RO" cmd "$platform" fill "#jobDesc" "$description" >/dev/null
  [[ -z "$handler" ]] ||
    bash "$BROWSER_RO" cmd "$platform" fill "#executorHandler" "$handler" >/dev/null
  case "$status" in
    all) bash "$BROWSER_RO" cmd "$platform" select "#triggerStatus" "全部" >/dev/null ;;
    stopped) bash "$BROWSER_RO" cmd "$platform" select "#triggerStatus" "停止" >/dev/null ;;
    running) bash "$BROWSER_RO" cmd "$platform" select "#triggerStatus" "启动" >/dev/null ;;
    *) die "--status 必须是 all、running 或 stopped" ;;
  esac
  bash "$BROWSER_RO" cmd "$platform" click "getByRole('button', { name: '搜索' })" >/dev/null

  local expression
  expression='JSON.stringify([...document.querySelectorAll("#job_list tbody tr")].map(row => {
    const cells = [...row.querySelectorAll("td")].map(cell => cell.innerText.trim());
    return {
      id: cells[0] || "",
      description: cells[1] || "",
      schedule: cells[2] || "",
      mode: cells[3] || "",
      owner: cells[4] || "",
      status: cells[5] || ""
    };
  }).filter(item => item.id))'
  browser_eval "$platform" "$expression" | jq .
}

scheduling_logs() {
  local env_name="$1"
  shift
  local executor=""
  local job_id=""
  local status="all"
  while (($#)); do
    case "$1" in
      --executor)
        [[ $# -ge 2 ]] || die "--executor 后必须有执行器名称或 ID"
        executor="$2"
        shift 2
        ;;
      --job)
        [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--job 后必须是任务 ID"
        job_id="$2"
        shift 2
        ;;
      --status)
        [[ $# -ge 2 ]] || die "--status 后必须是 all、success、failed 或 running"
        status="$2"
        shift 2
        ;;
      *) die "未知调度日志查询参数：$1" ;;
    esac
  done

  local platform base
  platform="$(scheduling_platform "$env_name")"
  base="$(scheduling_base "$env_name")"
  browser_goto_authenticated "$platform" "$base/joblog" "/toLogin" ||
    die "调度平台登录失败，请检查 SCHEDULING_USER/SCHEDULING_PASS"

  if [[ -n "$executor" ]]; then
    bash "$BROWSER_RO" cmd "$platform" select "#jobGroup" "$executor" >/dev/null
  fi
  if [[ -n "$job_id" ]]; then
    [[ -n "$executor" ]] || die "按任务 ID 查日志时还需要 --executor，平台要靠执行器加载任务下拉框"
  fi
  case "$status" in
    all) bash "$BROWSER_RO" cmd "$platform" select "#logStatus" "全部" >/dev/null ;;
    success) bash "$BROWSER_RO" cmd "$platform" select "#logStatus" "成功" >/dev/null ;;
    failed) bash "$BROWSER_RO" cmd "$platform" select "#logStatus" "失败" >/dev/null ;;
    running) bash "$BROWSER_RO" cmd "$platform" select "#logStatus" "进行中" >/dev/null ;;
    *) die "--status 必须是 all、success、failed 或 running" ;;
  esac
  bash "$BROWSER_RO" cmd "$platform" click "getByRole('button', { name: '搜索' })" >/dev/null
  if [[ -n "$job_id" ]]; then
    bash "$BROWSER_RO" cmd "$platform" select "select[name='joblog_list_length']" "100" >/dev/null
  fi

  local expression
  expression='JSON.stringify((() => {
    const table = document.querySelector("table");
    if (!table) return [];
    const headers = [...table.querySelectorAll("thead th")].map(cell => cell.innerText.trim());
    return [...table.querySelectorAll("tbody tr")].map(row => {
      const values = [...row.querySelectorAll("td")].map(cell => cell.innerText.trim());
      return Object.fromEntries(values.slice(0, Math.max(0, headers.length - 1)).map((value, index) => [headers[index] || `col${index}`, value]));
    });
  })())'
  browser_eval "$platform" "$expression" |
    jq --arg job_id "$job_id" '
      if $job_id == ""
      then .
      else map(select(.["任务ID"] == $job_id))
      end
    ' |
    node "$SAFE_OUTPUT" redact
}

docs_search() {
  local query="$1"
  browser_ensure "jenkins"
  browser_goto "jenkins" "$DOCS_BASE"
  bash "$BROWSER_RO" cmd "jenkins" fill "getByRole('textbox', { name: 'Search' })" "$query" >/dev/null
  browser_eval "jenkins" "new Promise(resolve => setTimeout(() => resolve('ready'), 1200))" >/dev/null
  local expression
  expression='JSON.stringify([...document.querySelectorAll("a")]
    .filter(link => link.href.startsWith("http://yingle.jdsn.com/pages/"))
    .map(link => ({
      title: (link.innerText || "").trim().split("\n")[0],
      url: link.href.replace("http://yingle.jdsn.com/pages/", "http://yingle.jdsn.com/yingle1991/pages/")
    }))
    .filter(item => item.title)
    .slice(0, 30))'
  browser_eval "jenkins" "$expression" | jq .
}

docs_url() {
  local path_or_url="$1"
  if [[ "$path_or_url" == http://* || "$path_or_url" == https://* ]]; then
    [[ "$path_or_url" == "$DOCS_BASE"* ]] || die "只允许读取项目文档站：$DOCS_BASE"
    printf '%s\n' "$path_or_url"
    return
  fi
  path_or_url="${path_or_url#/}"
  [[ "$path_or_url" != *".."* ]] || die "项目文档路径不允许包含 .."
  [[ -z "$path_or_url" || "$path_or_url" == pages/* ]] ||
    die "只允许读取项目文档站内 pages/ 路径"
  printf '%s%s\n' "$DOCS_BASE" "$path_or_url"
}

docs_headings() {
  local target
  target="$(docs_url "$1")"
  browser_ensure "jenkins"
  browser_goto "jenkins" "$target"
  browser_eval "jenkins" \
    'JSON.stringify({title: document.title, url: location.href, headings: [...document.querySelectorAll("main h1, main h2, main h3, main h4")].map(item => ({level: item.tagName, text: item.innerText.replace(/^#\s*/, "").trim()}))})' |
    jq .
}

release_diagnose() {
  local env_name="$1"
  local job_name="$2"
  local deployment="$3"
  local build_number="${4:-}"

  printf '## Jenkins build\n'
  jenkins_build "$job_name" "$build_number"
  printf '\n## Jenkins release evidence\n'
  jenkins_evidence "$job_name" "$build_number"
  printf '\n## K8s deployment and pod evidence\n'
  k8s_diagnose "$env_name" "$deployment"
}

doctor() {
  local failed=0
  local command_name
  for command_name in bash curl jq node sha256sum getent flock rg; do
    if command -v "$command_name" >/dev/null 2>&1; then
      printf 'OK   command %-14s\n' "$command_name"
    else
      printf 'MISS command %-14s\n' "$command_name"
      failed=1
    fi
  done
  if command -v powershell.exe >/dev/null 2>&1; then
    printf 'OK   Windows 网络桥接\n'
  else
    printf 'MISS powershell.exe（Jenkins/项目文档可能不可用）\n'
    failed=1
  fi
  [[ -f "$CREDS_FILE" ]] && printf 'OK   凭据文件存在（未输出内容）\n' ||
    {
      printf 'MISS 凭据文件 %s\n' "$CREDS_FILE"
      failed=1
    }
  [[ -f "$BROWSER_RO" ]] && printf 'OK   只读浏览器护栏存在\n' ||
    {
      printf 'MISS 只读浏览器护栏 %s\n' "$BROWSER_RO"
      failed=1
    }

  if [[ -f "$CREDS_FILE" ]]; then
    load_creds
    local pair label left right
    for pair in \
      "K8S_USER:K8S_PASS:K8s" \
      "JENKINS_USER:JENKINS_PASS:Jenkins" \
      "NACOS_USER:NACOS_PASS:Nacos" \
      "SCHEDULING_USER:SCHEDULING_PASS:调度平台"; do
      IFS=: read -r left right label <<<"$pair"
      if [[ -n "${!left:-}" && -n "${!right:-}" ]]; then
        printf 'OK   %-14s 凭据已配置\n' "$label"
      else
        printf 'MISS %-14s 凭据未完整配置\n' "$label"
        failed=1
      fi
    done
  fi
  printf 'INFO 会话缓存目录：%s（权限 700）\n' "$CACHE_ROOT"
  return "$failed"
}

usage() {
  cat <<'EOF'
统一只读平台巡检

用法：
  platform.sh doctor

  platform.sh k8s namespaces <dev|test|uat|prod>
  platform.sh k8s deployments <环境> [名称片段]
  platform.sh k8s deployment <环境> <deployment>
  platform.sh k8s pods <环境> [名称片段]
  platform.sh k8s logs <环境> <pod或deployment> [--tail N] [--since 3h] [--match 正则] [--previous] [--errors] [--container 名称]
  platform.sh k8s events <环境> <pod或deployment>
  platform.sh k8s diagnose <环境> <deployment>

  platform.sh jenkins job <job>
  platform.sh jenkins jobs [关键词]
  platform.sh jenkins builds <job> [数量，默认10]
  platform.sh jenkins parameter-build <job> <参数名> <参数值> [搜索数量，默认30]
  platform.sh jenkins build <job> [构建号|lastBuild]
  platform.sh jenkins log <job> [构建号|lastBuild] [--tail N] [--errors]
  platform.sh jenkins evidence <job> [构建号|lastBuild]

  platform.sh nacos read <环境> <dataId> [group]
  platform.sh nacos keys <环境> <dataId> [group]
  platform.sh nacos compare <环境A> <dataIdA> <环境B> <dataIdB> [group]

  platform.sh scheduling executors <test|uat>
  platform.sh scheduling jobs <test|uat> [--executor 名称或ID] [--desc 关键词] [--handler 关键词] [--status all|running|stopped]
  platform.sh scheduling logs <test|uat> [--executor 名称或ID] [--job 任务ID] [--status all|success|failed|running]

  platform.sh docs search <关键词>
  platform.sh docs headings <站内路径或URL>

  platform.sh release <环境> <Jenkins job> <K8s deployment> [构建号]

所有命令都是查询；不会构建、发布、重启、保存配置、执行任务或进入容器。
配置与日志输出会自动遮盖常见密码、token、cookie 和密钥。
EOF
}

main() {
  need_command bash
  need_command jq
  need_command node

  case "${1:-}" in
    help|-h|--help)
      usage
      ;;
    doctor)
      [[ $# -eq 1 ]] || die "doctor 不接收参数"
      doctor
      ;;
    k8s)
      [[ $# -ge 3 ]] || {
        usage
        exit 2
      }
      case "$2" in
        namespaces) [[ $# -eq 3 ]] || die "用法：k8s namespaces <环境>"; k8s_namespaces "$3" ;;
        deployments) [[ $# -le 4 ]] || die "用法：k8s deployments <环境> [名称片段]"; k8s_deployments "$3" "${4:-}" ;;
        deployment) [[ $# -eq 4 ]] || die "用法：k8s deployment <环境> <deployment>"; k8s_deployment "$3" "$4" ;;
        pods) [[ $# -le 4 ]] || die "用法：k8s pods <环境> [名称片段]"; k8s_pods "$3" "${4:-}" ;;
        logs) [[ $# -ge 4 ]] || die "用法：k8s logs <环境> <pod或deployment>"; shift 2; k8s_logs "$@" ;;
        eslogs) [[ $# -ge 4 ]] || die "用法：k8s eslogs <环境> <deployment或pod> [--tail N] [--since X] [--match RE] [--errors]"; shift 2; k8s_eslogs "$@" ;;
        events) [[ $# -eq 4 ]] || die "用法：k8s events <环境> <pod或deployment>"; k8s_events "$3" "$4" ;;
        diagnose) [[ $# -eq 4 ]] || die "用法：k8s diagnose <环境> <deployment>"; k8s_diagnose "$3" "$4" ;;
        *) die "未知 K8s 命令：$2" ;;
      esac
      ;;
    jenkins)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      case "$2" in
        jobs) [[ $# -le 3 ]] || die "用法：jenkins jobs [关键词]"; with_browser_lock jenkins jenkins_jobs "${3:-}" ;;
        job) [[ $# -eq 3 ]] || die "用法：jenkins job <job>"; with_browser_lock jenkins jenkins_job "$3" ;;
        builds) [[ $# -ge 3 && $# -le 4 ]] || die "用法：jenkins builds <job> [数量]"; with_browser_lock jenkins jenkins_builds "$3" "${4:-10}" ;;
        parameter-build) [[ $# -ge 5 && $# -le 6 ]] || die "用法：jenkins parameter-build <job> <参数名> <参数值> [搜索数量]"; with_browser_lock jenkins jenkins_parameter_build "$3" "$4" "$5" "${6:-30}" ;;
        build) [[ $# -ge 3 && $# -le 4 ]] || die "用法：jenkins build <job> [构建号|lastBuild]"; with_browser_lock jenkins jenkins_build "$3" "${4:-}" ;;
        log) [[ $# -ge 3 ]] || die "用法：jenkins log <job> [构建号|lastBuild] [--tail N] [--errors]"; shift 2; with_browser_lock jenkins jenkins_log "$@" ;;
        evidence) [[ $# -ge 3 && $# -le 4 ]] || die "用法：jenkins evidence <job> [构建号|lastBuild]"; with_browser_lock jenkins jenkins_evidence "$3" "${4:-}" ;;
        *) die "未知 Jenkins 命令：$2" ;;
      esac
      ;;
    nacos)
      [[ $# -ge 4 ]] || {
        usage
        exit 2
      }
      case "$2" in
        read) [[ $# -le 5 ]] || die "用法：nacos read <环境> <dataId> [group]"; with_browser_lock nacos-test nacos_read "$3" "$4" "${5:-common}" ;;
        keys) [[ $# -le 5 ]] || die "用法：nacos keys <环境> <dataId> [group]"; with_browser_lock nacos-test nacos_keys "$3" "$4" "${5:-common}" ;;
        compare) [[ $# -ge 6 && $# -le 7 ]] || die "用法：nacos compare <环境A> <dataIdA> <环境B> <dataIdB> [group]"; with_browser_lock nacos-test nacos_compare "$3" "$4" "$5" "$6" "${7:-common}" ;;
        *) die "未知 Nacos 命令：$2" ;;
      esac
      ;;
    scheduling)
      [[ $# -ge 3 ]] || {
        usage
        exit 2
      }
      case "$2" in
        executors) with_browser_lock "scheduling-$3" scheduling_executors "$3" ;;
        jobs) with_browser_lock "scheduling-$3" scheduling_jobs "$3" "${@:4}" ;;
        logs) with_browser_lock "scheduling-$3" scheduling_logs "$3" "${@:4}" ;;
        *) die "未知调度平台命令：$2" ;;
      esac
      ;;
    docs)
      [[ $# -ge 3 ]] || {
        usage
        exit 2
      }
      case "$2" in
        search) [[ $# -eq 3 ]] || die "用法：docs search <关键词>"; with_browser_lock jenkins docs_search "$3" ;;
        headings) [[ $# -eq 3 ]] || die "用法：docs headings <路径或URL>"; with_browser_lock jenkins docs_headings "$3" ;;
        *) die "未知项目文档命令：$2" ;;
      esac
      ;;
    release)
      [[ $# -ge 4 && $# -le 5 ]] || die "用法：release <环境> <Jenkins job> <K8s deployment> [构建号]"
      with_browser_lock jenkins release_diagnose "$2" "$3" "$4" "${5:-}"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
