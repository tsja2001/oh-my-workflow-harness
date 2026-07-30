#!/usr/bin/env bash

# High-level, read-only diagnosis entry point for the SCM workspace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CATALOG="$SCRIPT_DIR/../references/modules.json"
PLATFORM="$SCRIPT_DIR/platform.sh"
SAFE_OUTPUT="$SCRIPT_DIR/safe-output.js"
DBQ="$WORKSPACE_ROOT/scripts/dbq.sh"
PROBE_FAILURES=0

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

valid_env() {
  case "$1" in
    dev|test|uat|prod) ;;
    *) die "环境必须是 dev、test、uat 或 prod：$1" ;;
  esac
}

valid_task_env() {
  case "$1" in
    test|uat) ;;
    *) die "任务数据库只确认了 test 和 uat；不能猜测 $1 环境" ;;
  esac
}

valid_keyword() {
  [[ -n "$1" ]] || die "关键词不能为空"
  ((${#1} <= 200)) || die "关键词不能超过 200 个字符"
  [[ "$1" != *$'\n'* && "$1" != *$'\r'* ]] || die "关键词不能包含换行"
}

render_env() {
  local template="$1"
  local env_name="$2"
  [[ -n "$template" && "$template" != "null" ]] || return 0
  printf '%s\n' "${template//\{env\}/$env_name}"
}

catalog_records() {
  jq -c '
    (.modules | map(. + {catalogSection: "modules"}))
    + (.frontends | map(. + {catalogSection: "frontends"}))
    | .[]
  ' "$CATALOG"
}

resolve_record() {
  local input="$1"
  jq -c --arg input "$input" '
    def lower: ascii_downcase;
    def normalized:
      ($input
        | sub("^[a-zA-Z]+://[^/]+"; "")
        | sub("[?#].*$"; "")
        | sub("^/gateway"; ""));
    def exact($record):
      (($record.id | lower) == ($input | lower))
      or (($record.application // "" | lower) == ($input | lower))
      or (($record.deployment // "" | lower) == ($input | lower))
      or (any($record.aliases[]?; (lower == ($input | lower))));
    def path_match($record):
      any(
        ($record.apiPrefixes // [])[];
        . as $prefix | (normalized | startswith($prefix))
      )
      or any(
        ($record.urlPrefixes // [])[];
        . as $prefix | ($input | contains($prefix))
      )
      or (
        ($record.kind == "backend")
        and (
          (normalized | contains("/business/" + $record.id + "/"))
          or (($input | lower) | startswith((($record.scheduler.appPrefix // "__none__") | lower) + "-"))
        )
      );
    (
      (.modules | map(. + {catalogSection: "modules"}))
      + (.frontends | map(. + {catalogSection: "frontends"}))
    )
    | ([.[] | select(exact(.))] + [.[] | select(path_match(.))])
    | unique_by(.id)
    | .[0] // empty
  ' "$CATALOG"
}

require_record() {
  local input="$1"
  local record
  record="$(resolve_record "$input")"
  [[ -n "$record" ]] ||
    die "模块目录无法识别：$input。先执行 project.sh modules 查看已固化名称"
  printf '%s\n' "$record"
}

record_field() {
  local record="$1"
  local expression="$2"
  jq -r "$expression // empty" <<<"$record"
}

print_record() {
  local record="$1"
  jq '{
    id,
    name,
    kind,
    aliases,
    repository,
    starter,
    application,
    deployment,
    port,
    jenkins,
    nacos,
    databasePattern,
    scheduler,
    apiPrefixes,
    urlPrefixes
  } | with_entries(select(.value != null))' <<<"$record"
}

modules_list() {
  printf 'ID\t类型\t名称\tApplication/Deployment\t代码仓库\n'
  jq -r '
    (
      (.modules | map(. + {catalogSection: "modules"}))
      + (.frontends | map(. + {catalogSection: "frontends"}))
    )
    | sort_by(.kind, .id)[]
    | [
        .id,
        .kind,
        .name,
        (.application // .deployment // "-"),
        .repository
      ]
    | @tsv
  ' "$CATALOG"
}

module_show() {
  local record
  record="$(require_record "$1")"
  print_record "$record"
}

section() {
  local title="$1"
  shift
  printf '\n## %s\n' "$title"
  if ! "$@"; then
    printf 'WARN 此项查询失败，继续收集其余证据。\n' >&2
    PROBE_FAILURES=$((PROBE_FAILURES + 1))
  fi
}

finish_probes() {
  if ((PROBE_FAILURES > 0)); then
    printf 'WARN 共有 %s 项证据未取到；不能把当前输出当成完整结论。\n' "$PROBE_FAILURES" >&2
    return 1
  fi
}

db_query() {
  local sql="$1"
  local database="$2"
  bash "$DBQ" "$sql" "$database" \
    2> >(sed '/Using a password on the command line interface can be insecure/d' >&2) |
    node "$SAFE_OUTPUT" redact
}

search_api_code() {
  local record="$1"
  local resource="$2"
  local endpoint="$3"
  valid_keyword "$resource"
  valid_keyword "$endpoint"

  local repository starter path found=0
  repository="$(record_field "$record" '.repository')"
  starter="$(record_field "$record" '.starter')"
  for path in "$repository" "$starter"; do
    [[ -n "$path" && -d "$WORKSPACE_ROOT/$path" ]] || continue
    local -a route_files=()
    mapfile -t route_files < <(
      rg -l -m 1 \
        --glob '*.java' \
        --glob '*.xml' \
        --glob '!**/target/**' \
        --fixed-strings -- "$resource" "$WORKSPACE_ROOT/$path" |
        sed -n '1,20p'
    )
    if ((${#route_files[@]} > 0)); then
      found=1
      printf '\n### %s：路由段 %s\n' "$path" "$resource"
      rg -H -n -m 20 --fixed-strings -- "$resource" "${route_files[@]}" |
        sed "s#^$WORKSPACE_ROOT/##" |
        sed -n '1,40p'
      printf '\n### 对应方法 %s\n' "$endpoint"
      rg -H -n -C 2 -m 10 --fixed-strings -- "$endpoint" "${route_files[@]}" |
        sed "s#^$WORKSPACE_ROOT/##" |
        sed -n '1,80p' || true
      continue
    fi

    local method_lines
    method_lines="$(
      rg -H -n -m 10 \
        --glob '*.java' \
        --glob '*.xml' \
        --glob '!**/target/**' \
        --fixed-strings -- "$endpoint" "$WORKSPACE_ROOT/$path" |
        sed "s#^$WORKSPACE_ROOT/##" |
        sed -n '1,40p' || true
    )"
    if [[ -n "$method_lines" ]]; then
      found=1
      printf '\n### %s：只找到方法名候选\n%s\n' "$path" "$method_lines"
    fi
  done
  ((found == 1)) ||
    printf '未在已映射代码目录找到路由段 %s 或方法 %s\n' "$resource" "$endpoint"
}

trace_api() {
  local target="$1"
  valid_keyword "$target"
  local record endpoint path_without_query parent resource
  record="$(require_record "$target")"
  path_without_query="${target%%\?*}"
  path_without_query="${path_without_query%/}"
  endpoint="$path_without_query"
  endpoint="${endpoint##*/}"
  parent="${path_without_query%/*}"
  resource="${parent##*/}"
  [[ "$endpoint" =~ ^[A-Za-z0-9_.-]+$ ]] ||
    die "无法从接口中提取安全的方法关键词：$endpoint"
  [[ "$resource" =~ ^[A-Za-z0-9_.-]+$ ]] ||
    die "无法从接口中提取安全的资源关键词：$resource"

  printf '## 模块定位\n'
  print_record "$record"
  printf '\n## 代码定位（资源：%s；方法：%s）\n' "$resource" "$endpoint"
  search_api_code "$record" "$resource" "$endpoint"
}

trace_page() {
  local target="$1"
  valid_keyword "$target"
  local record repository marker repository_abs
  record="$(require_record "$target")"
  [[ "$(record_field "$record" '.kind')" == "frontend" ]] ||
    die "页面 URL 没有解析到前端项目：$target"
  repository="$(record_field "$record" '.repository')"
  repository_abs="$WORKSPACE_ROOT/$repository"
  [[ -d "$repository_abs" ]] || die "前端代码目录不存在：$repository"

  marker="${target%%\?*}"
  marker="${marker##*#/}"
  marker="${marker%/}"
  marker="${marker##*/}"
  [[ "$marker" =~ ^[A-Za-z0-9_.-]+$ ]] ||
    die "无法从页面 URL 提取安全的页面关键词：$marker"

  printf '## 前端定位\n'
  print_record "$record"
  printf '\n## 页面文件（关键词：%s）\n' "$marker"

  local -a files=()
  mapfile -t files < <(
    {
      rg -l -m 1 \
        --glob '*.{js,jsx,ts,tsx,vue}' \
        --glob '!**/{node_modules,dist}/**' \
        --fixed-strings -- "$marker" "$repository_abs" || true
      rg --files "$repository_abs" |
        rg "/$marker(/|\\.)" || true
    } |
      awk '!seen[$0]++' |
      sed -n '1,20p'
  )
  if ((${#files[@]} == 0)); then
    printf '未找到页面关键词。可改用路由片段或页面组件名再次查询。\n'
    return 0
  fi

  printf '%s\n' "${files[@]}" | sed "s#^$WORKSPACE_ROOT/##"
  printf '\n## 页面中的 API 候选\n'
  local api_lines api_paths
  api_lines="$(
    rg -n -o \
      '(/gateway)?/[a-zA-Z][a-zA-Z0-9_-]*/business/[a-zA-Z0-9_./${}-]+' \
      -- "${files[@]}" 2>/dev/null |
      sed "s#^$WORKSPACE_ROOT/##" |
      sed -n '1,60p' || true
  )"
  if [[ -n "$api_lines" ]]; then
    printf '%s\n' "$api_lines"
    api_paths="$(
      rg -o --no-filename \
        '(/gateway)?/[a-zA-Z][a-zA-Z0-9_-]*/business/[a-zA-Z0-9_./${}-]+' \
        -- "${files[@]}" 2>/dev/null |
        sort -u || true
    )"
    printf '\n## 后端模块候选\n'
    local api_path backend_record
    while IFS= read -r api_path; do
      [[ -n "$api_path" ]] || continue
      backend_record="$(resolve_record "$api_path")"
      [[ -n "$backend_record" ]] || continue
      jq -r '[.id, .name, .application, .repository] | @tsv' <<<"$backend_record"
    done <<<"$api_paths" | awk '!seen[$0]++'
    printf '\n提示：把具体接口交给 `trace api`，可继续定位 Controller 和方法。\n'
  else
    printf '未直接提取到标准 /<gateway-prefix>/business/<module>/... 形式的 API；请沿 import 的 API 文件继续查。\n'
  fi
}

diagnose_release() {
  local env_name="$1"
  local module_input="$2"
  valid_env "$env_name"
  local record kind all_template web_template job_template project_parameter all_job web_job deployment
  PROBE_FAILURES=0
  record="$(require_record "$module_input")"
  kind="$(record_field "$record" '.kind')"
  deployment="$(record_field "$record" '.deployment')"

  if [[ "$kind" == "frontend" ]]; then
    job_template="$(record_field "$record" '.jenkins.job')"
    project_parameter="$(record_field "$record" '.jenkins.project')"
    web_job="$(render_env "$job_template" "$env_name")"
    [[ -n "$web_job" ]] || die "前端模块没有 Jenkins Job 映射：$module_input"
    [[ -n "$project_parameter" ]] ||
      die "共享静态站 Job 必须配置 PROJECT 参数值：$module_input"
    printf '# 前端发布证据：%s / %s\n' "$env_name" "$(record_field "$record" '.name')"
    local build_json build_number
    printf '\n## Jenkins 静态站发布：%s / PROJECT=%s\n' "$web_job" "$project_parameter"
    if build_json="$(
      bash "$PLATFORM" jenkins parameter-build \
        "$web_job" PROJECT "$project_parameter" 50
    )"; then
      printf '%s\n' "$build_json"
      build_number="$(jq -r '.number // empty' <<<"$build_json")"
      if [[ "$build_number" =~ ^[0-9]+$ ]]; then
        section "Jenkins 发布关键行：$web_job #$build_number" \
          bash "$PLATFORM" jenkins evidence "$web_job" "$build_number"
      else
        printf 'WARN Jenkins 返回中缺少有效构建号，无法获取控制台证据。\n' >&2
        PROBE_FAILURES=$((PROBE_FAILURES + 1))
      fi
    else
      printf 'WARN 最近 50 个构建中未找到该 PROJECT，继续检查 K8s 运行态。\n' >&2
      PROBE_FAILURES=$((PROBE_FAILURES + 1))
    fi
    section "K8s Deployment：$deployment" bash "$PLATFORM" k8s deployment "$env_name" "$deployment"
    section "K8s Pods：$deployment" bash "$PLATFORM" k8s pods "$env_name" "$deployment"
    finish_probes
    return
  fi

  [[ "$kind" == "backend" ]] || die "未知模块类型：$kind"
  all_template="$(record_field "$record" '.jenkins.all')"
  web_template="$(record_field "$record" '.jenkins.web')"
  all_job="$(render_env "$all_template" "$env_name")"
  web_job="$(render_env "$web_template" "$env_name")"
  printf '# 发布证据：%s / %s\n' "$env_name" "$(record_field "$record" '.name')"
  if [[ -n "$all_job" ]]; then
    section "Jenkins 上游构建：$all_job" bash "$PLATFORM" jenkins build "$all_job" lastBuild
  fi
  if [[ -n "$web_job" ]]; then
    section "Jenkins 镜像发布：$web_job" bash "$PLATFORM" jenkins build "$web_job" lastBuild
    section "Jenkins 发布关键行：$web_job" bash "$PLATFORM" jenkins evidence "$web_job" lastBuild
  fi
  section "K8s Deployment：$deployment" bash "$PLATFORM" k8s deployment "$env_name" "$deployment"
  section "K8s Pods：$deployment" bash "$PLATFORM" k8s pods "$env_name" "$deployment"
  finish_probes
}

diagnose_api() {
  local env_name="$1"
  local target="$2"
  valid_env "$env_name"
  valid_keyword "$target"
  local record kind deployment path_without_query endpoint parent resource match
  PROBE_FAILURES=0
  record="$(require_record "$target")"
  kind="$(record_field "$record" '.kind')"
  [[ "$kind" == "backend" ]] || die "API 没有解析到后端模块：$target"
  deployment="$(record_field "$record" '.deployment')"
  path_without_query="${target%%\?*}"
  path_without_query="${path_without_query%/}"
  endpoint="${path_without_query##*/}"
  parent="${path_without_query%/*}"
  resource="${parent##*/}"
  [[ "$endpoint" =~ ^[A-Za-z0-9_.-]+$ && "$resource" =~ ^[A-Za-z0-9_.-]+$ ]] ||
    die "API 的资源段或方法段不安全"
  match="$resource|$endpoint|No mapping|NoResourceFound|No static resource"

  trace_api "$target"
  section "业务服务 Deployment" bash "$PLATFORM" k8s deployment "$env_name" "$deployment"
  section "业务服务 Pods" bash "$PLATFORM" k8s pods "$env_name" "$deployment"
  section "网关 Pods" bash "$PLATFORM" k8s pods "$env_name" scm-gateway-web
  section "最近 1 小时相关业务日志" \
    bash "$PLATFORM" k8s logs "$env_name" "$deployment" \
      --since 1h --tail 10000 --match "$match"
  finish_probes
}

diagnose_runtime() {
  local env_name="$1"
  local module_input="$2"
  valid_env "$env_name"
  local record deployment
  record="$(require_record "$module_input")"
  deployment="$(record_field "$record" '.deployment')"
  [[ -n "$deployment" ]] || die "模块没有 Deployment 映射：$module_input"
  bash "$PLATFORM" k8s diagnose "$env_name" "$deployment"
}

task_database() {
  local env_name="$1"
  jq -r --arg env "$env_name" '.schedulerDatabases[$env] // empty' "$CATALOG"
}

diagnose_task() {
  local env_name="$1"
  local module_input="$2"
  local job_id="$3"
  valid_task_env "$env_name"
  [[ "$job_id" =~ ^[0-9]+$ ]] || die "任务 ID 必须是正整数"

  local record scheduler_id scheduler_name database deployment
  PROBE_FAILURES=0
  record="$(require_record "$module_input")"
  scheduler_id="$(record_field "$record" '.scheduler.id')"
  scheduler_name="$(record_field "$record" '.scheduler.name')"
  [[ "$scheduler_id" =~ ^[0-9]+$ ]] ||
    die "模块没有调度执行器映射：$module_input"
  database="$(task_database "$env_name")"
  [[ "$database" =~ ^[A-Za-z0-9_]+$ ]] || die "任务数据库映射无效"
  deployment="$(record_field "$record" '.deployment')"

  printf '# 定时任务证据：%s / %s / Job %s\n' "$env_name" "$scheduler_name" "$job_id"
  printf '\n## 任务配置\n'
  local config_sql
  config_sql="SELECT
    i.id,
    i.job_group,
    CASE WHEN i.job_group = $scheduler_id THEN 'MATCH' ELSE 'MISMATCH' END AS module_group_check,
    i.job_desc,
    CASE i.trigger_status WHEN 1 THEN 'RUNNING' ELSE 'STOP' END AS config_status,
    i.schedule_type,
    i.schedule_conf,
    i.executor_handler,
    i.executor_param,
    i.update_time
  FROM xxl_job_info i
  WHERE i.id = $job_id
  LIMIT 1"
  local config_output
  config_output="$(db_query "$config_sql" "$database")"
  [[ -n "${config_output//[[:space:]]/}" ]] ||
    die "$env_name 的 $database 未找到任务 ID $job_id"
  printf '%s\n' "$config_output"

  printf '\n## 最近 5 次执行（数据库精确记录）\n'
  local log_sql
  log_sql="SELECT
    l.id AS log_id,
    l.trigger_time,
    l.handle_time,
    l.trigger_code,
    l.handle_code,
    CASE
      WHEN l.handle_msg LIKE '%Caused by:%'
        THEN LEFT(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(l.handle_msg, 'Caused by:', -1), CHAR(10), 1)), 500)
      ELSE LEFT(TRIM(SUBSTRING_INDEX(l.handle_msg, CHAR(10), 1)), 500)
    END AS deepest_cause
  FROM xxl_job_log l
  WHERE l.job_id = $job_id
  ORDER BY l.id DESC
  LIMIT 5"
  local log_output
  log_output="$(db_query "$log_sql" "$database")"
  if [[ -n "${log_output//[[:space:]]/}" ]]; then
    printf '%s\n' "$log_output"
  else
    printf 'INFO 未找到该任务的执行记录；这不代表任务配置不存在。\n'
  fi

  if [[ -n "$deployment" ]]; then
    section "当前执行器服务 Pod" bash "$PLATFORM" k8s pods "$env_name" "$deployment"
  fi
  printf '\n说明：模块执行器应为 %s（ID %s）。页面上的“失败”只是摘要，上表 deepest_cause 才是本次执行的直接原因。\n' \
    "$scheduler_name" "$scheduler_id"
  finish_probes
}

compare_config() {
  local module_input="$1"
  local left_env="$2"
  local right_env="$3"
  valid_env "$left_env"
  valid_env "$right_env"
  local record template group left_data_id right_data_id
  record="$(require_record "$module_input")"
  template="$(record_field "$record" '.nacos.dataId')"
  group="$(record_field "$record" '.nacos.group')"
  [[ -n "$template" ]] || die "模块没有 Nacos Data ID 映射：$module_input"
  left_data_id="$(render_env "$template" "$left_env")"
  right_data_id="$(render_env "$template" "$right_env")"
  bash "$PLATFORM" nacos compare \
    "$left_env" "$left_data_id" \
    "$right_env" "$right_data_id" \
    "${group:-common}"
}

ownership() {
  local module_input="$1"
  local keyword="$2"
  valid_keyword "$keyword"
  local record repository repository_abs
  record="$(require_record "$module_input")"
  repository="$(record_field "$record" '.repository')"
  repository_abs="$WORKSPACE_ROOT/$repository"
  [[ -d "$repository_abs/.git" ]] || die "模块目录不是独立 Git 仓库：$repository"

  printf '## 相关文件\n'
  local -a files=()
  mapfile -t files < <(
    rg -l -m 1 \
      --glob '!**/{target,node_modules,dist}/**' \
      --fixed-strings -- "$keyword" "$repository_abs" |
      sed -n '1,20p'
  )
  if ((${#files[@]} == 0)); then
    printf '未找到关键词：%s\n' "$keyword"
  else
    printf '%s\n' "${files[@]}" | sed "s#^$WORKSPACE_ROOT/##"
    printf '\n## 每个文件最近一次提交\n'
    local file relative
    for file in "${files[@]}"; do
      relative="${file#"$repository_abs/"}"
      git -C "$repository_abs" log -1 \
        --date=short \
        --format="$relative	%h	%ad	%an	%s" \
        -- "$relative"
    done
  fi

  printf '\n## 提交说明中命中关键词的最近记录\n'
  git -C "$repository_abs" log --all -n 10 \
    --date=short \
    --format='%h	%ad	%an	%s' \
    --regexp-ignore-case \
    --grep="$keyword" || true

  printf '\n## 实际增删过该关键词的最近记录\n'
  git -C "$repository_abs" log --all -n 10 \
    --date=short \
    --format='%h	%ad	%an	%s' \
    -S "$keyword" -- || true
}

doctor() {
  local failed=0
  local command_name
  for command_name in bash jq node rg git mysql; do
    if command -v "$command_name" >/dev/null 2>&1; then
      printf 'OK   command %-10s\n' "$command_name"
    else
      printf 'MISS command %-10s\n' "$command_name"
      failed=1
    fi
  done

  if jq -e '
      .schemaVersion == 1
      and (.modules | type == "array" and length > 0)
      and (.frontends | type == "array")
      and (
        [(.modules + .frontends)[].id]
        | length == (unique | length)
      )
      and all(
        .modules[];
        .kind == "backend"
        and (.id | type == "string" and length > 0)
        and (.repository | type == "string" and length > 0)
        and (.application | type == "string" and length > 0)
        and (.deployment | type == "string" and length > 0)
      )
      and all(
        .frontends[];
        .kind == "frontend"
        and (.repository | type == "string" and length > 0)
        and (.deployment | type == "string" and length > 0)
        and (.jenkins.project | type == "string" and length > 0)
      )
    ' "$CATALOG" >/dev/null; then
    printf 'OK   模块目录结构有效、ID 无重复\n'
  else
    printf 'MISS 模块目录结构或 ID 有问题：%s\n' "$CATALOG"
    failed=1
  fi

  [[ -f "$DBQ" ]] && printf 'OK   数据库只读脚本 %s\n' "${DBQ#"$WORKSPACE_ROOT/"}" ||
    {
      printf 'MISS 数据库只读脚本 %s\n' "$DBQ"
      failed=1
    }

  local record repository starter
  while IFS= read -r record; do
    repository="$(record_field "$record" '.repository')"
    if [[ -d "$WORKSPACE_ROOT/$repository" ]]; then
      printf 'OK   repo %s\n' "$repository"
    else
      printf 'MISS repo %s\n' "$repository"
      failed=1
    fi
    starter="$(record_field "$record" '.starter')"
    if [[ -n "$starter" ]]; then
      if [[ -d "$WORKSPACE_ROOT/$starter" ]]; then
        printf 'OK   starter %s\n' "$starter"
      else
        printf 'MISS starter %s\n' "$starter"
        failed=1
      fi
    fi
  done < <(catalog_records)

  printf '\n## 底层平台检查\n'
  bash "$PLATFORM" doctor || failed=1
  return "$failed"
}

usage() {
  cat <<'EOF'
SCM 项目级只读诊断

用法：
  project.sh doctor
  project.sh modules
  project.sh module <模块名|application|deployment|接口路径|页面URL>

  project.sh trace api <接口路径或URL>
  project.sh trace page <页面路径或URL>

  project.sh diagnose release <dev|test|uat|prod> <模块>
  project.sh diagnose api <dev|test|uat|prod> <接口路径或URL>
  project.sh diagnose runtime <dev|test|uat|prod> <模块>
  project.sh diagnose task <test|uat> <模块> <任务ID>

  project.sh compare config <模块> <环境A> <环境B>
  project.sh ownership <模块> <代码关键词>

所有命令均为查询；不会构建、发布、重启、改配置、执行任务或写数据库。
EOF
}

main() {
  need_command bash
  need_command jq
  need_command node
  need_command rg
  [[ -f "$CATALOG" ]] || die "缺少模块目录：$CATALOG"
  [[ -x "$PLATFORM" || -f "$PLATFORM" ]] || die "缺少平台适配器：$PLATFORM"

  case "${1:-}" in
    help|-h|--help)
      usage
      ;;
    doctor)
      [[ $# -eq 1 ]] || die "doctor 不接收参数"
      doctor
      ;;
    modules)
      [[ $# -eq 1 ]] || die "modules 不接收参数"
      modules_list
      ;;
    module)
      [[ $# -eq 2 ]] || die "用法：module <模块名|路径>"
      module_show "$2"
      ;;
    trace)
      [[ $# -eq 3 ]] || die "用法：trace <api|page> <路径或URL>"
      case "$2" in
        api) trace_api "$3" ;;
        page) trace_page "$3" ;;
        *) die "未知 trace 类型：$2" ;;
      esac
      ;;
    diagnose)
      [[ $# -ge 4 ]] || die "用法：diagnose <release|api|runtime|task> ..."
      case "$2" in
        release)
          [[ $# -eq 4 ]] || die "用法：diagnose release <环境> <模块>"
          diagnose_release "$3" "$4"
          ;;
        api)
          [[ $# -eq 4 ]] || die "用法：diagnose api <环境> <接口路径或URL>"
          diagnose_api "$3" "$4"
          ;;
        runtime)
          [[ $# -eq 4 ]] || die "用法：diagnose runtime <环境> <模块>"
          diagnose_runtime "$3" "$4"
          ;;
        task)
          [[ $# -eq 5 ]] || die "用法：diagnose task <test|uat> <模块> <任务ID>"
          diagnose_task "$3" "$4" "$5"
          ;;
        *) die "未知 diagnose 类型：$2" ;;
      esac
      ;;
    compare)
      [[ $# -eq 5 && "$2" == "config" ]] ||
        die "用法：compare config <模块> <环境A> <环境B>"
      compare_config "$3" "$4" "$5"
      ;;
    ownership)
      [[ $# -eq 3 ]] || die "用法：ownership <模块> <代码关键词>"
      ownership "$2" "$3"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
