#!/bin/bash
# 平台 Excel 导出模板工具。
#
# 只读：
#   bash scripts/export-template.sh validate <定义.json>
#   bash scripts/export-template.sh payload <定义.json>
#   bash scripts/export-template.sh inspect test|uat <templateCode>
#   bash scripts/export-template.sh verify test|uat <定义.json>
#   bash scripts/export-template.sh diff test|uat test|uat <templateCode>
#
# 新建（调用和管理页面相同的保存接口，不直接 INSERT）：
#   bash scripts/export-template.sh apply test <定义.json> \
#     --confirm-write --rollback docs/需求/<主题>/sql/03-test-导出模板回滚.sql
#   bash scripts/export-template.sh apply uat <定义.json> \
#     --confirm-write --confirm-uat --rollback docs/需求/<主题>/sql/04-uat-导出模板回滚.sql
#
# apply 只负责“编码尚不存在的新建”。编码存在且配置相同视为幂等成功；
# 编码存在但内容不同会拒绝，修改已有模板必须先做完整备份和专项回滚方案。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CREDS_FILE="$ROOT_DIR/ai-docs/creds.env"
API_SCRIPT="$ROOT_DIR/scripts/api.sh"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

load_db_creds() {
  need_command mysql
  [ -f "$CREDS_FILE" ] || die "缺少 $CREDS_FILE"
  # shellcheck disable=SC1090
  source "$CREDS_FILE"
  : "${DB_HOST:?creds.env 缺少 DB_HOST}"
  : "${DB_USER:?creds.env 缺少 DB_USER}"
  : "${DB_PASS:?creds.env 缺少 DB_PASS}"
  DB_PORT="${DB_PORT:-3306}"
}

db_name() {
  case "$1" in
    test) printf '%s\n' 'scm_ubm_test' ;;
    uat) printf '%s\n' 'scm_ubm_uat' ;;
    prod) die '生产环境禁止由 AI 查询或写入' ;;
    *) die '环境只能是 test 或 uat' ;;
  esac
}

mysql_raw() {
  local environment="$1"
  local sql="$2"
  local database
  database="$(db_name "$environment")"
  load_db_creds
  MYSQL_PWD="$DB_PASS" mysql \
    -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" \
    --default-character-set=utf8mb4 --batch --raw --skip-column-names \
    "$database" -e "$sql"
}

mysql_table() {
  local environment="$1"
  local sql="$2"
  local database
  database="$(db_name "$environment")"
  load_db_creds
  MYSQL_PWD="$DB_PASS" mysql \
    -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" \
    --default-character-set=utf8mb4 --table \
    "$database" -e "$sql"
}

assert_spec_file() {
  [ "$#" -eq 1 ] || die '缺少导出模板定义 JSON'
  [ -r "$1" ] || die "定义文件不可读：$1"
}

validate_spec() {
  local spec_file="$1"
  assert_spec_file "$spec_file"

  jq -e 'type == "object"' "$spec_file" >/dev/null || die '定义根节点必须是 JSON object'
  jq -e '
    [.templateCode, .templateDesc, .groupCode, .groupName, .status,
     (.checkCode // ""), (.enableCheckCode // "false")] | all(type == "string")
  ' "$spec_file" >/dev/null || die '主表字段必须是字符串'
  jq -e '
    (.templateCode | length > 0 and length <= 32 and test("^[A-Za-z0-9_-]+$")) and
    (.templateDesc | length > 0 and length <= 32) and
    (.groupCode | length > 0 and length <= 32) and
    (.groupName | length > 0 and length <= 32) and
    (.status == "1")
  ' "$spec_file" >/dev/null || die '模板编码/描述/分组超长或非法；新模板状态必须为 1'
  jq -e '
    ([.. | objects | keys[]] |
      any(. == "templateId" or . == "tmpId" or . == "createBy" or
          . == "createByName" or . == "createTime" or . == "updateBy" or
          . == "updateByName" or . == "updateTime" or . == "deleteSign" or
          . == "dataVersion")) | not
  ' "$spec_file" >/dev/null || die '定义中禁止出现 ID、审计、删除标记或版本字段；这些由后端生成'
  jq -e '
    (.details | type == "array" and length > 0) and
    (.details | all(
      (.sortName | type == "string" and test("^[0-9]+$")) and
      (.fieldName | type == "string" and length > 0 and length <= 64 and
        test("^[A-Za-z_][A-Za-z0-9_]*$")) and
      (.fieldVal | type == "string" and length > 0 and length <= 64 and
        ((contains("\t") or contains("\n") or contains("\r")) | not)) and
      (.fieldType | type == "string" and
        (. == "String" or . == "Date" or . == "BigDecimal" or . == "Integer" or . == "Long")) and
      (.status == "1")
    ))
  ' "$spec_file" >/dev/null || die '明细字段缺失、超长或非法；字段类型只允许 String/Date/BigDecimal/Integer/Long'
  jq -e '
    (. as $root |
      ($root.details | map(.sortName) | length) == ($root.details | map(.sortName) | unique | length) and
      ($root.details | map(.fieldName) | length) == ($root.details | map(.fieldName) | unique | length))
  ' "$spec_file" >/dev/null || die '明细排序和字段名必须各自唯一'
  jq -e '
    . as $root |
    ($root.details | map(.sortName | tonumber) | sort) as $sorts |
    ($root.details | map(select(.fieldName == "INDEX")) | length) as $index_count |
    if $index_count == 1 then
      (($root.details[] | select(.fieldName == "INDEX") | .sortName) == "0") and
      ($sorts == [range(0; ($root.details | length))])
    elif $index_count == 0 then
      ($sorts == [range(1; (($root.details | length) + 1))])
    else false end
  ' "$spec_file" >/dev/null || die '有序号列时必须唯一且 INDEX=0、其余列从 1 连续；无序号列时从 1 连续'
  jq -e '
    ((.enableCheckCode // "false") == "false" and (.checkCode // "") == "" and
      ([.details[].fieldName] | index("CHECK_CODE") | not)) or
    ((.enableCheckCode // "false") == "true" and
      ((.checkCode // "") | test("^[0-9]+(,[0-9]+)*$")) and
      ([.details[].fieldName] | map(select(. == "CHECK_CODE")) | length) == 1)
  ' "$spec_file" >/dev/null || die '校验码未启用时必须为空；启用时需数字索引列表且包含唯一 CHECK_CODE 列'

  printf '定义合法：%s（%s 列）\n' \
    "$(jq -r '.templateCode' "$spec_file")" \
    "$(jq -r '.details | length' "$spec_file")"
}

normalized_payload() {
  local spec_file="$1"
  jq -c '
    . as $root |
    {
      templateCode: $root.templateCode,
      templateDesc: $root.templateDesc,
      groupCode: $root.groupCode,
      groupName: $root.groupName,
      status: $root.status,
      checkCode: ($root.checkCode // ""),
      enableCheckCode: ($root.enableCheckCode // "false"),
      details: [
        $root.details[] |
        {
          sortName, fieldName, fieldVal, fieldType, status,
          templateCode: $root.templateCode,
          groupCode: $root.groupCode
        }
      ]
    }
  ' "$spec_file"
}

active_main_count() {
  local environment="$1"
  local template_code="$2"
  mysql_raw "$environment" \
    "SELECT COUNT(*) FROM scm_simple_template WHERE template_code='${template_code}' AND delete_sign=0;"
}

inspect_template() {
  local environment="$1"
  local template_code="$2"
  [[ "$template_code" =~ ^[A-Za-z0-9_-]{1,32}$ ]] || die 'templateCode 格式非法'

  printf '主模板（%s）：\n' "$environment"
  mysql_table "$environment" "
    SELECT template_id,template_code,template_desc,group_code,group_name,status,
           COALESCE(check_code,'') AS check_code,
           COALESCE(enable_check_code,'') AS enable_check_code,
           create_by,create_by_name,create_time,update_by,update_by_name,update_time,
           delete_sign,data_version,file_name,data_scan_limit
    FROM scm_simple_template
    WHERE template_code='${template_code}' AND delete_sign=0;
  "
  printf '有效明细：\n'
  mysql_table "$environment" "
    SELECT tmp_id,template_id,template_code,group_code,sort_name,field_name,field_val,
           field_type,status,create_by,create_by_name,create_time,update_time,
           delete_sign,data_version
    FROM scm_simple_template_sub
    WHERE template_code='${template_code}' AND delete_sign=0
    ORDER BY CAST(sort_name AS UNSIGNED),tmp_id;
  "
}

verify_spec() {
  local environment="$1"
  local spec_file="$2"
  local template_code expected_main actual_main expected_sub actual_sub main_count bad_count

  validate_spec "$spec_file" >/dev/null
  template_code="$(jq -r '.templateCode' "$spec_file")"
  main_count="$(active_main_count "$environment" "$template_code")"
  [ "$main_count" = '1' ] || die "${environment} 有效主模板数量应为 1，实际为 ${main_count}"

  expected_main="$(jq -r '[.templateCode,.templateDesc,.groupCode,.groupName,.status,(.checkCode // ""),(.enableCheckCode // "false")] | @tsv' "$spec_file")"
  actual_main="$(mysql_raw "$environment" "
    SELECT template_code,template_desc,group_code,group_name,status,
           COALESCE(check_code,''),COALESCE(enable_check_code,'')
    FROM scm_simple_template
    WHERE template_code='${template_code}' AND delete_sign=0;
  ")"
  if [ "$expected_main" != "$actual_main" ]; then
    printf '%s\n' '主模板语义不一致：' >&2
    diff -u <(printf '%s\n' "$expected_main") <(printf '%s\n' "$actual_main") || true
    return 1
  fi

  expected_sub="$(jq -r '
    . as $root | $root.details | sort_by(.sortName | tonumber)[] |
    [.sortName,.fieldName,.fieldVal,.fieldType,.status,$root.templateCode,$root.groupCode] | @tsv
  ' "$spec_file")"
  actual_sub="$(mysql_raw "$environment" "
    SELECT sort_name,field_name,field_val,field_type,status,template_code,group_code
    FROM scm_simple_template_sub
    WHERE template_code='${template_code}' AND delete_sign=0
    ORDER BY CAST(sort_name AS UNSIGNED),tmp_id;
  ")"
  if [ "$expected_sub" != "$actual_sub" ]; then
    printf '%s\n' '模板明细语义不一致：' >&2
    diff -u <(printf '%s\n' "$expected_sub") <(printf '%s\n' "$actual_sub") || true
    return 1
  fi

  bad_count="$(mysql_raw "$environment" "
    SELECT
      (SELECT COUNT(*) FROM scm_simple_template
       WHERE template_code='${template_code}' AND delete_sign=0
         AND (template_id='' OR status<>'1' OR create_by IS NULL OR create_by='' OR
              create_by_name IS NULL OR create_by_name='' OR create_time IS NULL OR
              update_by IS NULL OR update_by='' OR update_by_name IS NULL OR
              update_by_name='' OR update_time IS NULL OR data_version < 1 OR
              file_name IS NOT NULL OR data_scan_limit IS NOT NULL))
      +
      (SELECT COUNT(*) FROM scm_simple_template_sub
       WHERE template_code='${template_code}' AND delete_sign=0
         AND (tmp_id='' OR template_id='' OR status<>'1' OR sort_name NOT REGEXP '^[0-9]+$' OR
              create_by IS NULL OR create_by='' OR create_by_name IS NULL OR
              create_by_name='' OR create_time IS NULL OR update_by IS NULL OR
              update_by='' OR update_by_name IS NULL OR update_by_name='' OR
              update_time IS NULL OR data_version < 1));
  ")"
  [ "$bad_count" = '0' ] || die "${environment} 模板存在 ${bad_count} 条非页面标准记录（审计/状态/ID/版本/保留字段）"

  bad_count="$(mysql_raw "$environment" "
    SELECT COUNT(*) FROM (
      SELECT sort_name FROM scm_simple_template_sub
      WHERE template_code='${template_code}' AND delete_sign=0
      GROUP BY sort_name HAVING COUNT(*)>1
      UNION ALL
      SELECT field_name FROM scm_simple_template_sub
      WHERE template_code='${template_code}' AND delete_sign=0
      GROUP BY field_name HAVING COUNT(*)>1
    ) duplicate_items;
  ")"
  [ "$bad_count" = '0' ] || die "${environment} 模板存在重复排序或重复字段"

  printf '验证通过：%s/%s（%s 列，语义、关联、审计和状态均正常）\n' \
    "$environment" "$template_code" "$(jq -r '.details | length' "$spec_file")"
}

semantic_dump() {
  local environment="$1"
  local template_code="$2"
  local main_count
  main_count="$(active_main_count "$environment" "$template_code")"
  [ "$main_count" = '1' ] || die "${environment}/${template_code} 有效主模板数量不是 1，而是 ${main_count}"
  mysql_raw "$environment" "
    SELECT CONCAT('MAIN\t',template_code,'\t',template_desc,'\t',group_code,'\t',group_name,
                  '\t',status,'\t',COALESCE(check_code,''),'\t',COALESCE(enable_check_code,''),
                  '\t',COALESCE(file_name,'<NULL>'),'\t',COALESCE(CAST(data_scan_limit AS CHAR),'<NULL>'))
    FROM scm_simple_template
    WHERE template_code='${template_code}' AND delete_sign=0;
    SELECT CONCAT('DETAIL\t',sort_name,'\t',field_name,'\t',field_val,'\t',field_type,
                  '\t',status,'\t',template_code,'\t',group_code)
    FROM scm_simple_template_sub
    WHERE template_code='${template_code}' AND delete_sign=0
    ORDER BY CAST(sort_name AS UNSIGNED),tmp_id;
  "
}

diff_templates() {
  local left_env="$1"
  local right_env="$2"
  local template_code="$3"
  local left_dump right_dump
  [[ "$template_code" =~ ^[A-Za-z0-9_-]{1,32}$ ]] || die 'templateCode 格式非法'
  left_dump="$(semantic_dump "$left_env" "$template_code")"
  right_dump="$(semantic_dump "$right_env" "$template_code")"
  if [ "$left_dump" = "$right_dump" ]; then
    printf '语义一致：%s 与 %s 的 %s（已忽略 ID、审计和时间）\n' \
      "$left_env" "$right_env" "$template_code"
    return 0
  fi
  printf '语义不一致：%s 与 %s 的 %s\n' "$left_env" "$right_env" "$template_code" >&2
  diff -u \
    <(printf '%s\n' "$left_dump") \
    <(printf '%s\n' "$right_dump") || true
  return 1
}

write_create_rollback() {
  local environment="$1"
  local template_code="$2"
  local rollback_file="$3"
  local database template_id child_ids child_count id_list generated_at

  database="$(db_name "$environment")"
  template_id="$(mysql_raw "$environment" "
    SELECT template_id FROM scm_simple_template
    WHERE template_code='${template_code}' AND delete_sign=0;
  ")"
  [[ "$template_id" =~ ^-?[0-9]{1,32}$ ]] || die "后端生成的 template_id 形态异常：${template_id}"
  child_ids="$(mysql_raw "$environment" "
    SELECT tmp_id FROM scm_simple_template_sub
    WHERE template_id='${template_id}' AND template_code='${template_code}' AND delete_sign=0
    ORDER BY tmp_id;
  ")"
  child_count="$(printf '%s\n' "$child_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
  [ "$child_count" -gt 0 ] || die '未取得新模板明细 ID，无法生成回滚脚本'
  while IFS= read -r child_id; do
    [ -z "$child_id" ] && continue
    [[ "$child_id" =~ ^-?[0-9]{1,32}$ ]] || die "后端生成的 tmp_id 形态异常：${child_id}"
  done <<< "$child_ids"
  id_list="$(printf '%s\n' "$child_ids" | sed '/^$/d' | sed "s/.*/'&'/" | paste -sd, -)"
  generated_at="$(date '+%Y-%m-%d %H:%M:%S %z')"

  {
    printf '%s\n' '-- 平台导出模板新建回滚（由 scripts/export-template.sh 生成）'
    printf '%s\n' "-- 生成时间：${generated_at}"
    printf '%s\n' "-- 环境：${environment}；模板：${template_code}"
    printf '%s\n' '-- 本脚本默认不 COMMIT；核对 ready_to_commit=1 后再在同一会话手工 COMMIT。'
    printf '\nUSE `%s`;\n\n' "$database"
    printf "SET @template_id = '%s';\n" "$template_id"
    printf "SET @template_code = '%s';\n" "$template_code"
    printf 'SET @expected_sub_count = %s;\n\n' "$child_count"
    printf '%s\n' 'SELECT COUNT(*) INTO @main_count'
    printf '%s\n' 'FROM scm_simple_template'
    printf '%s\n' 'WHERE template_id=@template_id AND template_code=@template_code;'
    printf '%s\n' 'SELECT COUNT(*) INTO @sub_count'
    printf '%s\n' 'FROM scm_simple_template_sub'
    printf 'WHERE template_id=@template_id AND template_code=@template_code AND tmp_id IN (%s);\n' "$id_list"
    printf '%s\n' 'SET @precheck_ok = (@main_count=1 AND @sub_count=@expected_sub_count);'
    printf "%s\n\n" "SELECT @precheck_ok AS precheck_ok, '必须为1，否则禁止继续' AS instruction;"
    printf '%s\n' 'START TRANSACTION;'
    printf '%s\n' 'DELETE FROM scm_simple_template_sub'
    printf 'WHERE @precheck_ok=1 AND template_id=@template_id AND template_code=@template_code AND tmp_id IN (%s);\n' "$id_list"
    printf '%s\n' 'SET @deleted_sub = ROW_COUNT();'
    printf '%s\n' 'DELETE FROM scm_simple_template'
    printf '%s\n' 'WHERE @precheck_ok=1 AND template_id=@template_id AND template_code=@template_code;'
    printf '%s\n' 'SET @deleted_main = ROW_COUNT();'
    printf '%s\n' 'SET @ready_to_commit = (@precheck_ok=1 AND @deleted_main=1 AND @deleted_sub=@expected_sub_count);'
    printf '%s\n' 'SELECT @deleted_main AS deleted_main,@deleted_sub AS deleted_sub,@ready_to_commit AS ready_to_commit;'
    printf '%s\n' '-- ready_to_commit=1 后手工执行 COMMIT；否则执行 ROLLBACK。'
    printf '%s\n' '-- COMMIT;'
    printf '%s\n' '-- ROLLBACK;'
  } > "$rollback_file"
}

apply_new_template() {
  local environment="$1"
  local spec_file="$2"
  shift 2
  local confirm_write='false'
  local confirm_uat='false'
  local rollback_file=''
  local template_code count payload response rollback_abs rollback_dir

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --confirm-write) confirm_write='true'; shift ;;
      --confirm-uat) confirm_uat='true'; shift ;;
      --rollback)
        [ "$#" -ge 2 ] || die '--rollback 缺少文件路径'
        rollback_file="$2"
        shift 2
        ;;
      *) die "未知 apply 参数：$1" ;;
    esac
  done

  [ "$confirm_write" = 'true' ] || die 'apply 是写操作，必须显式传 --confirm-write'
  [ "$environment" != 'prod' ] || die '生产环境禁止由 AI 写入'
  if [ "$environment" = 'uat' ] && [ "$confirm_uat" != 'true' ]; then
    die 'UAT 写入必须当次明确确认，并传 --confirm-uat'
  fi
  [ -n "$rollback_file" ] || die '新建前必须用 --rollback 指定需求 sql/ 下的新回滚文件'
  case "$rollback_file" in
    /*) rollback_abs="$rollback_file" ;;
    *) rollback_abs="$ROOT_DIR/$rollback_file" ;;
  esac
  case "$rollback_abs" in
    "$ROOT_DIR"/docs/需求/*/sql/*.sql) ;;
    *) die '回滚文件必须位于 docs/需求/<主题>/.../sql/ 且以 .sql 结尾' ;;
  esac
  [ ! -e "$rollback_abs" ] || die "回滚文件已存在，按只增不覆盖规则请换新文件名：$rollback_abs"
  rollback_dir="$(dirname "$rollback_abs")"
  [ -d "$rollback_dir" ] || die "回滚目录不存在：$rollback_dir"

  validate_spec "$spec_file"
  template_code="$(jq -r '.templateCode' "$spec_file")"
  count="$(active_main_count "$environment" "$template_code")"
  if [ "$count" = '1' ]; then
    if verify_spec "$environment" "$spec_file"; then
      printf '%s\n' '目标环境已存在完全相同配置，本次不写库。'
      return 0
    fi
    die '目标编码已存在但内容不同；工具拒绝覆盖。请先做完整备份和专项回滚方案'
  fi
  [ "$count" = '0' ] || die "目标编码存在 ${count} 条有效主模板，必须先治理重复数据"

  payload="$(normalized_payload "$spec_file")"
  response="$(bash "$API_SCRIPT" --env "$environment" --platform procurement --account admin \
    POST /c/business/template/simple/changeTempDetail "$payload")"
  if ! printf '%s' "$response" | jq -e '.status == true' >/dev/null 2>&1; then
    printf '%s\n' "$response" >&2
    die '模板保存接口返回失败'
  fi

  write_create_rollback "$environment" "$template_code" "$rollback_abs"
  if ! verify_spec "$environment" "$spec_file"; then
    die "保存后验证失败；配置已经写入，请使用刚生成的回滚脚本检查并回退：$rollback_abs"
  fi
  printf '新建完成：%s/%s\n回滚脚本：%s\n' "$environment" "$template_code" "$rollback_abs"
}

main() {
  need_command jq
  [ "$#" -ge 1 ] || { usage >&2; exit 2; }
  local command="$1"
  shift

  case "$command" in
    validate)
      [ "$#" -eq 1 ] || die '用法：validate <定义.json>'
      validate_spec "$1"
      ;;
    payload)
      [ "$#" -eq 1 ] || die '用法：payload <定义.json>'
      validate_spec "$1" >/dev/null
      normalized_payload "$1" | jq .
      ;;
    inspect)
      [ "$#" -eq 2 ] || die '用法：inspect test|uat <templateCode>'
      inspect_template "$1" "$2"
      ;;
    verify)
      [ "$#" -eq 2 ] || die '用法：verify test|uat <定义.json>'
      verify_spec "$1" "$2"
      ;;
    diff)
      [ "$#" -eq 3 ] || die '用法：diff test|uat test|uat <templateCode>'
      diff_templates "$1" "$2" "$3"
      ;;
    apply)
      [ "$#" -ge 2 ] || die '用法：apply test|uat <定义.json> --confirm-write [--confirm-uat] --rollback <新文件.sql>'
      apply_new_template "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die "未知命令：$command"
      ;;
  esac
}

main "$@"
