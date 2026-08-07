#!/bin/bash
# 开工体检：新会话/新 AI 接手时先跑这一条，30 秒内回答"今天能到哪"。
# 把 skill Phase 4「开工侦察」里那些每次都要手敲的探针固化下来。
#
# 用法：
#   bash scripts/doctor.sh              # 全部快检（不联外网、不 fetch）
#   bash scripts/doctor.sh --fetch      # 额外对公司子仓 git fetch，检查是否落后远端（慢，要网）
#   bash scripts/doctor.sh --auth       # 额外跑业务接口登录体检（会真的登录一次）
#   bash scripts/doctor.sh env|creds|db|es|repos    # 只跑其中一节
#
# 铁律：本脚本只读。不打印任何密码/token/cookie；凭据只报"有没有配"，不报值。

set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
CREDS="$DIR/ai-docs/creds.env"

DO_FETCH=0; DO_AUTH=0; SECTION="all"
for a in "$@"; do
  case "$a" in
    --fetch) DO_FETCH=1 ;;
    --auth)  DO_AUTH=1 ;;
    env|creds|db|es|repos) SECTION="$a" ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "未知参数: $a（-h 看用法）"; exit 1 ;;
  esac
done
run() { [ "$SECTION" = "all" ] || [ "$SECTION" = "$1" ]; }

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
head_() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

tcp() { timeout 5 bash -c "cat < /dev/null > /dev/tcp/$1/$2" 2>/dev/null; }

# ---------- 1. 工具链 ----------
if run env; then
head_ "工具链"
v=$(java -version 2>&1 | head -1 | grep -oE '"[^"]+"' | tr -d '"')
[ -n "$v" ] && { case "$v" in 1.8*) ok "java $v" ;; *) warn "java $v（项目是 Java 8，高版本可能编不过）" ;; esac; } || bad "java 没装"
v=$(mvn -version 2>/dev/null | head -1 | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $3}')
[ -n "$v" ] && ok "maven $v（3.8+ 封 http 私服，用 mvn 时要带临时 settings）" || bad "maven 没装"
command -v mysql >/dev/null && ok "mysql 客户端 $(mysql --version | grep -oE 'Ver [0-9.]+' | awk '{print $2}')" \
                            || warn "没装 mysql 客户端，dbq.sh 会回退 Java 驱动（慢）：sudo apt install -y mysql-client-core-8.0"
command -v jq >/dev/null && ok "jq $(jq --version)" || bad "jq 没装（esq.sh/api.sh 依赖它）"
if command -v node >/dev/null; then
  nv=$(node -v)
  case "$nv" in v14.*) ok "node $nv / npm $(npm -v 2>/dev/null)" ;; *) warn "node $nv —— 前端项目必须用 14.21.3，记得先 nvm use 14" ;; esac
else
  warn "当前 PATH 上没有 node（走 nvm，前端活开始前先 nvm use 14）"
fi
fi

# ---------- 2. 凭据 ----------
if run creds; then
head_ "凭据"
if [ ! -f "$CREDS" ]; then
  bad "$CREDS 不存在——几乎所有脚本都用不了"
else
  perm=$(stat -c '%a' "$CREDS")
  [ "$perm" = "600" ] && ok "creds.env 权限 600" || warn "creds.env 权限是 $perm，建议 chmod 600"
  git -C "$DIR" check-ignore -q ai-docs/creds.env && ok "creds.env 已被 gitignore" || bad "creds.env 没被 gitignore —— 立刻停下处理"
  keys=$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$CREDS" | tr -d '=' | sort)
  miss=""
  for k in DB_HOST DB_USER DB_PASS ES_URL ES_USER ES_PASS SCM_ADMIN_USER SCM_ADMIN_PASS SCM_TEST_PROCURE_GATEWAY; do
    grep -qx "$k" <<<"$keys" || miss="$miss $k"
  done
  [ -z "$miss" ] && ok "必需变量齐全（共 $(wc -l <<<"$keys") 个键）" || bad "缺变量:$miss"
  dup=$(uniq -d <<<"$keys" | tr '\n' ' ')
  [ -n "$dup" ] && warn "有重复定义的键（后面的会覆盖前面的）: $dup"
  [ -d "$DIR/ai-docs/.auth-cache" ] && ok "auth 缓存目录存在（token 自动管理）" || warn "还没有 auth 缓存，首次调接口会自动登录"
fi
fi

# ---------- 3. 数据库 ----------
if run db; then
head_ "数据库（test）"
if [ -f "$CREDS" ]; then
  set -a; . "$CREDS" >/dev/null 2>&1; set +a
  if tcp "${DB_HOST:-}" "${DB_PORT:-3306}"; then
    ok "${DB_HOST}:${DB_PORT:-3306} 端口可达"
    if command -v mysql >/dev/null; then
      n=$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" -N -B -e "SHOW DATABASES" 2>/dev/null | wc -l)
      [ "$n" -gt 0 ] && ok "账号可登录，可见 $n 个库（查库用 bash scripts/dbq.sh \"SQL\" [库名]）" || bad "端口通但登录失败——账号或密码变了？"
    fi
  else
    bad "${DB_HOST:-未配置}:${DB_PORT:-3306} 不可达（没连内网？）"
  fi
fi
fi

# ---------- 4. ES ----------
if run es; then
head_ "Elasticsearch（test）"
if [ -f "$CREDS" ]; then
  set -a; . "$CREDS" >/dev/null 2>&1; set +a
  if [ -n "${ES_HOST:-}" ] && tcp "${ES_HOST}" "${ES_PORT:-9200}"; then
    st=$(curl -s -m 8 -u "$ES_USER:$ES_PASS" "${ES_URL%/}/_cluster/health" 2>/dev/null | jq -r '.status // empty' 2>/dev/null)
    [ -n "$st" ] && ok "集群健康度 $st（查 ES 用 bash scripts/esq.sh）" || bad "端口通但查询失败——账号或地址变了？"
  else
    bad "${ES_HOST:-未配置}:${ES_PORT:-9200} 不可达"
  fi
fi
fi

# ---------- 5. 代码仓状态 ----------
if run repos; then
head_ "代码仓（脏工作区 / 分支基线）"
printf '  %-48s %-32s %s\n' "仓库" "当前分支" "状态"
for d in "$DIR"/0[123]zhaocai-*/*/ "$DIR"; do
  [ -d "$d/.git" ] || continue
  name=${d%/}; name=${name#$DIR/}; [ "$name" = "$DIR" ] && name="(顶层文档仓)"
  br=$(git -C "$d" branch --show-current 2>/dev/null); [ -n "$br" ] || br="(detached)"
  [ "$DO_FETCH" = "1" ] && git -C "$d" fetch --quiet --all --prune 2>/dev/null
  dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
  ahead_behind=$(git -C "$d" rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
  msg=""
  [ "$dirty" -gt 0 ] && msg="脏 ${dirty} 个文件"
  if [ -n "$ahead_behind" ]; then
    b=$(awk '{print $1}' <<<"$ahead_behind"); a=$(awk '{print $2}' <<<"$ahead_behind")
    [ "${b:-0}" -gt 0 ] && msg="${msg:+$msg / }落后远端 $b"
    [ "${a:-0}" -gt 0 ] && msg="${msg:+$msg / }本地未推 $a"
  fi
  [ -z "$msg" ] && msg="干净"
  printf '  %-48s %-32s %s\n' "$name" "$br" "$msg"
done
[ "$DO_FETCH" = "1" ] || printf '\n  （没加 --fetch，"落后远端"是按本地缓存算的；开工前建议 bash scripts/doctor.sh --fetch）\n'
fi

# ---------- 6. 业务接口登录 ----------
if [ "$DO_AUTH" = "1" ]; then
head_ "业务接口登录"
bash "$DIR/scripts/auth.sh" doctor
fi

printf '\n下一步：动手前扫一眼 ai-docs/工具箱.md，别自己拼 curl / javac / mysql 命令。\n'
