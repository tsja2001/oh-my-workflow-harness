#!/bin/bash
# 查库工具。用法：
#   bash scripts/dbq.sh "SELECT ..." [库名]
#   bash scripts/dbq.sh 某文件.sql [库名]
# 凭据来自 ai-docs/creds.env。优先用 mysql 客户端；未安装则回退 Java SqlRunner（用 .m2 里的 JDBC 驱动）。
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$DIR/ai-docs/creds.env"; set +a
DB="${2:-}"
if [ -f "$1" ]; then
  SQL_FILE="$1"
else
  SQL_FILE=$(mktemp /tmp/dbq-XXXX.sql)
  printf '%s' "$1" > "$SQL_FILE"
fi
if command -v mysql >/dev/null 2>&1; then
  mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" --default-character-set=utf8mb4 --table ${DB:+"$DB"} < "$SQL_FILE"
else
  J=$(find "$HOME/.m2" -name "mysql-connector*.jar" 2>/dev/null | grep -v sources | head -1)
  [ -n "$J" ] || { echo "未找到 JDBC 驱动，且未装 mysql 客户端。请执行: sudo apt install -y mysql-client-core-8.0"; exit 1; }
  C="$DIR/scripts/.cache"; mkdir -p "$C"
  [ -f "$C/SqlRunner.class" ] || javac -encoding UTF-8 -d "$C" "$DIR/scripts/SqlRunner.java"
  DB_NAME="$DB" java -cp "$C:$J" SqlRunner "$SQL_FILE"
fi
