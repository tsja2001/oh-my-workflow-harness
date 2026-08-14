#!/usr/bin/env bash
# MySQL 数据库考试用 CSV 导入导出工具。
# 凭据只从 ai-docs/creds.env 的 MYSQL_EXAM_* 变量读取。
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CREDS_FILE="$WORKSPACE_ROOT/ai-docs/creds.env"

die() {
  echo "错误：$*" >&2
  exit 1
}

usage() {
  sed -n '2,35p' "$0" | sed -n 's/^# \{0,1\}//p'
}

# 用法：
#   bash mysql-csv.sh test
#   bash mysql-csv.sh import <数据库名> <表名> <CSV文件>
#   bash mysql-csv.sh export <数据库名> <表名> <CSV文件> [--force]
#
# 示例：
#   bash mysql-csv.sh test
#   bash mysql-csv.sh import exam_db student 'C:\Users\29455\Desktop\student.csv'
#   bash mysql-csv.sh export exam_db student 'C:\Users\29455\Desktop\student-result.csv'
#   bash mysql-csv.sh export exam_db student ./student-result.csv --force
#
# 约定：
#   1. 导入的 CSV 第一行必须是数据库字段名，字段顺序可以和表结构不同。
#   2. CSV 使用逗号分隔、双引号包裹，支持 UTF-8 BOM、中文、逗号和换行。
#   3. 空单元格导入可为空字段时转成 NULL；不可为空字段保持空字符串交给 MySQL 校验。
#   4. 遇到重复主键时导入会跳过并显示警告，不会覆盖原记录。
#   5. 导出包含第一行字段名，NULL 导出为空单元格，并写入 UTF-8 BOM 方便 Excel 识别中文。
#   6. 本工具只允许普通字母、数字和下划线组成的数据库名、表名。

[[ -f "$CREDS_FILE" ]] || die "找不到凭据文件：$CREDS_FILE"
# shellcheck disable=SC1090
set -a
source "$CREDS_FILE"
set +a

: "${MYSQL_EXAM_HOST:?ai-docs/creds.env 缺少 MYSQL_EXAM_HOST}"
: "${MYSQL_EXAM_PORT:?ai-docs/creds.env 缺少 MYSQL_EXAM_PORT}"
: "${MYSQL_EXAM_USER:?ai-docs/creds.env 缺少 MYSQL_EXAM_USER}"
: "${MYSQL_EXAM_PASSWORD:?ai-docs/creds.env 缺少 MYSQL_EXAM_PASSWORD}"

command -v mysql >/dev/null 2>&1 || die "未安装 mysql 命令行客户端"
command -v python3 >/dev/null 2>&1 || die "未安装 python3（用于可靠处理 CSV 转义）"

mysql_cli() {
  MYSQL_PWD="$MYSQL_EXAM_PASSWORD" mysql \
    --connect-timeout=10 \
    --local-infile=1 \
    --default-character-set=utf8mb4 \
    -h"$MYSQL_EXAM_HOST" \
    -P"$MYSQL_EXAM_PORT" \
    -u"$MYSQL_EXAM_USER" \
    "$@"
}

validate_identifier() {
  local kind="$1"
  local value="$2"
  [[ "$value" =~ ^[A-Za-z0-9_]+$ ]] || die "$kind只能包含字母、数字和下划线：$value"
}

quote_identifier() {
  local value="$1"
  value="${value//\`/\`\`}"
  printf '`%s`' "$value"
}

normalize_input_path() {
  local path="$1"
  if [[ "$path" =~ ^[A-Za-z]:[\\/].* ]]; then
    command -v wslpath >/dev/null 2>&1 || die "收到 Windows 路径，但当前环境没有 wslpath"
    path="$(wslpath -u "$path")"
  fi
  [[ -f "$path" ]] || die "CSV 文件不存在：$path"
  realpath "$path"
}

normalize_output_path() {
  local path="$1"
  if [[ "$path" =~ ^[A-Za-z]:[\\/].* ]]; then
    command -v wslpath >/dev/null 2>&1 || die "收到 Windows 路径，但当前环境没有 wslpath"
    path="$(wslpath -u "$path")"
  fi
  realpath -m "$path"
}

declare -a TABLE_COLUMNS=()
declare -A TABLE_NULLABLE=()

load_table_metadata() {
  local database="$1"
  local table="$2"
  local metadata
  if ! metadata="$(mysql_cli --batch --raw --skip-column-names -e \
    "SELECT COLUMN_NAME, IS_NULLABLE
       FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = '$database'
        AND TABLE_NAME = '$table'
      ORDER BY ORDINAL_POSITION")"; then
    die "读取表结构失败"
  fi
  [[ -n "$metadata" ]] || die "表不存在或没有读取权限：$database.$table"

  TABLE_COLUMNS=()
  TABLE_NULLABLE=()
  local column nullable
  while IFS=$'\t' read -r column nullable; do
    [[ -n "$column" ]] || continue
    TABLE_COLUMNS+=("$column")
    TABLE_NULLABLE["$column"]="$nullable"
  done <<< "$metadata"
}

table_has_column() {
  local wanted="$1"
  local column
  for column in "${TABLE_COLUMNS[@]}"; do
    [[ "$column" == "$wanted" ]] && return 0
  done
  return 1
}

check_connection() {
  local result version local_infile
  if ! result="$(mysql_cli --batch --raw --skip-column-names -e \
    "SELECT VERSION(), @@local_infile")"; then
    die "数据库连接失败，请检查考试库地址、端口、账号和密码"
  fi
  IFS=$'\t' read -r version local_infile <<< "$result"
  echo "连接成功：MySQL $version"
  if [[ "$local_infile" == "1" ]]; then
    echo "CSV 导入方式：LOAD DATA LOCAL INFILE（高速模式）"
  else
    echo "CSV 导入方式：批量 INSERT 兼容模式"
    echo "说明：服务端未开启 local_infile，脚本会自动降级，不影响使用。"
  fi
}

import_with_insert() {
  local database="$1"
  local quoted_table="$2"
  local csv_file="$3"
  local column_count="$4"
  shift 4

  python3 -c '
import csv
import sys

csv_file = sys.argv[1]
table = sys.argv[2]
column_count = int(sys.argv[3])
columns = sys.argv[4:4 + column_count]
nullable = [value == "YES" for value in sys.argv[4 + column_count:]]

if len(columns) != column_count or len(nullable) != column_count:
    raise SystemExit("内部错误：字段元数据数量不一致")

prefix = "INSERT IGNORE INTO " + table + " (" + ",".join(columns) + ") VALUES "
rows = []
statement_size = len(prefix)
max_statement_size = 512 * 1024

def sql_value(value, can_be_null):
    if value == "" and can_be_null:
        return "NULL"
    if value == "":
        return chr(39) * 2
    return "CONVERT(0x" + value.encode("utf-8").hex() + " USING utf8mb4)"

def flush():
    global rows, statement_size
    if rows:
        print(prefix + ",".join(rows) + ";")
        rows = []
        statement_size = len(prefix)

print("SET NAMES utf8mb4;")
print("START TRANSACTION;")
with open(csv_file, "r", encoding="utf-8-sig", newline="") as stream:
    reader = csv.reader(stream)
    next(reader)
    for row in reader:
        encoded = "(" + ",".join(
            sql_value(value, nullable[index]) for index, value in enumerate(row)
        ) + ")"
        if rows and statement_size + len(encoded) + 1 > max_statement_size:
            flush()
        rows.append(encoded)
        statement_size += len(encoded) + 1
flush()
print("COMMIT;")
' "$csv_file" "$quoted_table" "$column_count" "$@" | \
    mysql_cli --show-warnings "$database"
}

import_csv() {
  local database="$1"
  local table="$2"
  local requested_file="$3"
  validate_identifier "数据库名" "$database"
  validate_identifier "表名" "$table"

  local csv_file
  csv_file="$(normalize_input_path "$requested_file")"
  [[ "$csv_file" != *"'"* ]] || die "CSV 路径暂不支持英文单引号：$csv_file"

  local local_infile
  local_infile="$(mysql_cli --batch --raw --skip-column-names -e "SELECT @@local_infile")" \
    || die "无法检查 local_infile 配置"

  load_table_metadata "$database" "$table"

  local csv_summary
  if ! csv_summary="$(python3 -c '
import csv
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8-sig", newline="") as stream:
    reader = csv.reader(stream)
    try:
        header = next(reader)
    except StopIteration:
        raise SystemExit("CSV 是空文件")
    if not header or any(not name for name in header):
        raise SystemExit("CSV 第一行存在空字段名")
    if len(set(header)) != len(header):
        raise SystemExit("CSV 第一行存在重复字段名")
    for name in header:
        if any(ch in name for ch in "\r\n\0"):
            raise SystemExit("CSV 字段名不能包含换行或 NUL")
    row_count = 0
    for line_number, row in enumerate(reader, 2):
        if len(row) != len(header):
            raise SystemExit(
                f"CSV 第 {line_number} 行有 {len(row)} 列，表头有 {len(header)} 列"
            )
        row_count += 1
print(row_count)
for name in header:
    print(name)
' "$csv_file")"; then
    die "CSV 格式校验失败"
  fi

  local -a summary_lines csv_columns quoted_columns nullable_flags load_variables set_clauses
  mapfile -t summary_lines <<< "$csv_summary"
  local csv_rows="${summary_lines[0]}"
  csv_columns=("${summary_lines[@]:1}")
  [[ "${#csv_columns[@]}" -gt 0 ]] || die "CSV 没有字段"

  local column index quoted
  for index in "${!csv_columns[@]}"; do
    column="${csv_columns[$index]}"
    table_has_column "$column" || die "CSV 字段在目标表中不存在：$column"
    quoted="$(quote_identifier "$column")"
    quoted_columns+=("$quoted")
    nullable_flags+=("${TABLE_NULLABLE[$column]}")
    load_variables+=("@csv_$((index + 1))")
    if [[ "${TABLE_NULLABLE[$column]}" == "YES" ]]; then
      set_clauses+=("$quoted = NULLIF(@csv_$((index + 1)), '')")
    else
      set_clauses+=("$quoted = @csv_$((index + 1))")
    fi
  done

  local line_terminator
  line_terminator="$(python3 -c '
import sys
data = open(sys.argv[1], "rb").read()
print("\\r\\n" if b"\r\n" in data else "\\n")
' "$csv_file")"

  local quoted_table variables_sql set_sql sql before_rows after_rows
  quoted_table="$(quote_identifier "$table")"
  local IFS=,
  variables_sql="${load_variables[*]}"
  set_sql="${set_clauses[*]}"

  printf -v sql '%s\n' \
    "SELECT COUNT(*) AS before_rows FROM $quoted_table;" \
    "LOAD DATA LOCAL INFILE '$csv_file' IGNORE" \
    "INTO TABLE $quoted_table" \
    "CHARACTER SET utf8mb4" \
    "FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' ESCAPED BY '\"'" \
    "LINES TERMINATED BY '$line_terminator'" \
    "IGNORE 1 LINES" \
    "($variables_sql)" \
    "SET $set_sql;" \
    "SHOW WARNINGS LIMIT 50;" \
    "SELECT COUNT(*) AS after_rows FROM $quoted_table;"

  echo "准备导入：$csv_file"
  echo "目标表：$database.$table；CSV 数据行：$csv_rows"
  if [[ "$local_infile" == "1" ]]; then
    echo "导入方式：LOAD DATA LOCAL INFILE（高速模式）"
    mysql_cli --table "$database" -e "$sql" || die "CSV 导入失败"
    echo "导入完成。请根据 before_rows、after_rows 和警告确认结果。"
  else
    echo "导入方式：批量 INSERT 兼容模式（当前考试库未开启 local_infile）"
    before_rows="$(mysql_cli --batch --raw --skip-column-names "$database" \
      -e "SELECT COUNT(*) FROM $quoted_table")" || die "导入前计数失败"
    if ! import_with_insert "$database" "$quoted_table" "$csv_file" \
      "${#csv_columns[@]}" "${quoted_columns[@]}" "${nullable_flags[@]}"; then
      die "CSV 批量导入失败，事务已回滚"
    fi
    after_rows="$(mysql_cli --batch --raw --skip-column-names "$database" \
      -e "SELECT COUNT(*) FROM $quoted_table")" || die "导入后计数失败"
    echo "before_rows：$before_rows"
    echo "after_rows：$after_rows"
    echo "导入完成：表内净增加 $((after_rows - before_rows)) 行。"
  fi
}

export_csv() {
  local database="$1"
  local table="$2"
  local requested_file="$3"
  local force="${4:-}"
  validate_identifier "数据库名" "$database"
  validate_identifier "表名" "$table"
  [[ -z "$force" || "$force" == "--force" ]] || die "未知参数：$force"

  local csv_file
  csv_file="$(normalize_output_path "$requested_file")"
  [[ "${csv_file,,}" == *.csv ]] || die "导出文件名必须以 .csv 结尾"
  [[ -d "$(dirname "$csv_file")" ]] || die "导出目录不存在：$(dirname "$csv_file")"
  if [[ -e "$csv_file" && "$force" != "--force" ]]; then
    die "文件已存在；确认覆盖时请在命令最后加 --force：$csv_file"
  fi

  load_table_metadata "$database" "$table"

  local -a select_expressions=()
  local column quoted
  for column in "${TABLE_COLUMNS[@]}"; do
    quoted="$(quote_identifier "$column")"
    select_expressions+=(
      "IF($quoted IS NULL, 'N', CONCAT('V', HEX(CAST($quoted AS CHAR CHARACTER SET utf8mb4))))"
    )
  done

  local quoted_table select_sql
  quoted_table="$(quote_identifier "$table")"
  local IFS=,
  select_sql="SELECT ${select_expressions[*]} FROM $quoted_table"

  local temp_file="${csv_file}.tmp.$$"
  trap 'rm -f "$temp_file"' EXIT

  echo "准备导出：$database.$table"
  if ! mysql_cli --batch --raw --skip-column-names --quick "$database" -e "$select_sql" | \
    python3 -c '
import csv
import sys

output = sys.argv[1]
columns = sys.argv[2:]
rows = 0
with open(output, "w", encoding="utf-8-sig", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\r\n")
    writer.writerow(columns)
    for line_number, line in enumerate(sys.stdin, 1):
        encoded_values = line.rstrip("\n").split("\t")
        if len(encoded_values) != len(columns):
            raise SystemExit(
                f"第 {line_number} 行字段数异常：{len(encoded_values)} != {len(columns)}"
            )
        values = []
        for value in encoded_values:
            if value == "N":
                values.append("")
            elif value.startswith("V"):
                values.append(bytes.fromhex(value[1:]).decode("utf-8", errors="replace"))
            else:
                raise SystemExit(f"第 {line_number} 行出现无法识别的编码")
        writer.writerow(values)
        rows += 1
print(f"导出行数：{rows}")
' "$temp_file" "${TABLE_COLUMNS[@]}"; then
    die "CSV 导出失败，未覆盖原文件"
  fi

  mv -f "$temp_file" "$csv_file"
  trap - EXIT
  echo "导出完成：$csv_file"
  echo "文件格式：UTF-8 CSV（含字段名，可直接用 Excel 打开）"
}

main() {
  local command="${1:-help}"
  case "$command" in
    test)
      [[ "$#" -eq 1 ]] || die "test 不需要其他参数"
      check_connection
      ;;
    import)
      [[ "$#" -eq 4 ]] || { usage; die "import 需要：数据库名、表名、CSV 文件"; }
      import_csv "$2" "$3" "$4"
      ;;
    export)
      [[ "$#" -eq 4 || "$#" -eq 5 ]] || { usage; die "export 需要：数据库名、表名、CSV 文件，可选 --force"; }
      export_csv "$2" "$3" "$4" "${5:-}"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      usage
      die "未知命令：$command"
      ;;
  esac
}

main "$@"
