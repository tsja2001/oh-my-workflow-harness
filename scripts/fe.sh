#!/bin/bash
# 前端页面定位器。用一句话回答「这个功能/这个接口，对应前端哪个页面文件」。
#
# 用法：
#   bash scripts/fe.sh find <关键词>        中文菜单名 / 路由 / 文件名，模糊查（最常用）
#   bash scripts/fe.sh url  <页面URL或路由>  直接拿浏览器地址栏那串来查
#   bash scripts/fe.sh api  <接口路径片段>   后端接口 → 哪个 .vue 在调它 → 属于哪个菜单
#   bash scripts/fe.sh json <module>/<type>  动态页配置：这个页面到底调哪些接口、有哪些列
#   bash scripts/fe.sh repo <URL上下文>      如 procurementScheme → 是哪个前端仓库
#   bash scripts/fe.sh build [test|uat]     重建地图（要连网关，平时不用跑）
#   不带子命令 = find
#
# 为什么要有这东西：前端有 50 多个仓（02zhaocai-front/ 下 27 个新仓 + scm-vue-all/ 里 25 个旧仓，
# 大量同名重复），1200+ 条路由，菜单是中文而代码是英文，靠全树 grep 找页面又慢又容易找错仓。
# 所以先离线生成三张表（ai-docs/前端*.tsv），查的时候只读表，秒回、零 token 浪费。
#
# 三张表怎么来的：
#   前端页面地图.tsv   菜单树接口（/c/business/ubm/MenuMgr/queryMenuTree）拉到的中文菜单
#                      × 前端仓 src/router/*.js 里的路由 → 对上号，得到「中文名 → .vue 文件」
#   前端路由索引.tsv   全部 1200+ 条路由 → .vue 文件，覆盖菜单里没有的详情页/弹窗页
#   前端上下文对照.tsv URL 里 /xxx/index.html 的 xxx → 哪个前端仓库
#
# 已知边界（表里会明写，别当成 bug）：
#   · 「动态页」/dynamicPage/:module/:type 这类是通用壳子，页面长什么样由后端 JSON 配置决定，
#     定位到的是壳子文件，真正内容要去查后端配置（对应「平台管理 / JSON管理」菜单）。
#   · 找不到路由 = 该前端仓没克隆，或本地当前分支不含这个页面（交付分支切来切去很常见），
#     先 `git -C 02zhaocai-front/<仓> branch -a | grep <关键词>` 看看是不是在别的分支上。
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRONT="$DIR/02zhaocai-front"
MAP="$DIR/ai-docs/前端页面地图.tsv"
ROUTES="$DIR/ai-docs/前端路由索引.tsv"
CTXMAP="$DIR/ai-docs/前端上下文对照.tsv"
DYN="$DIR/ai-docs/前端动态页接口.tsv"

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

need_map() {
  [ -f "$MAP" ] || { echo "地图还没生成，先跑：bash scripts/fe.sh build" >&2; exit 1; }
}

# 把一行 TSV 打印成人和 AI 都好读的块
show_menu_row() {
  awk -F'\t' '{
    printf "菜单：%s\n", $1
    printf "URL ：%s\n", $2
    printf "仓库：02zhaocai-front/%s\n", ($5==""?"（未定位）":$5)
    if ($6!="") printf "路由：%s（%s）\n", $6, $4
    else        printf "路由：%s\n", $4
    if ($7!="") printf "页面：02zhaocai-front/%s\n", $7
    if ($8!="") printf "备注：%s\n", $8
    print  "---"
  }'
}

show_route_row() {
  awk -F'\t' '{
    printf "路由：%s\n", $1
    printf "仓库：02zhaocai-front/%s\n", $2
    printf "定义：02zhaocai-front/%s\n", $3
    if ($4!="") printf "页面：02zhaocai-front/%s\n", $4
    print  "---"
  }'
}

cmd_find() {
  need_map
  local kw="$1"
  echo "== 菜单命中（有中文名的正式页面）=="
  local hit
  hit=$(awk -F'\t' -v k="$kw" 'NR>1 && (index($1,k)||index($2,k)||index($4,k)||index($7,k)||index($8,k))' "$MAP")
  if [ -n "$hit" ]; then echo "$hit" | show_menu_row; else echo "（无）"; fi

  echo
  echo "== 路由命中（含菜单里没有的详情页/子页面，最多 20 条）=="
  hit=$(awk -F'\t' -v k="$kw" 'NR>1 && !($2 ~ /^scm-vue-all\//) && (index($1,k)||index($4,k))' "$ROUTES" | head -20)
  if [ -n "$hit" ]; then echo "$hit" | show_route_row; else echo "（无）"; fi
}

cmd_url() {
  need_map
  local raw="$1" route
  route="${raw#*#}"                       # 去掉 /ctx/index.html# 前缀
  [ "${route:0:1}" = "/" ] || route="/$route"
  echo "== 菜单命中 =="
  local hit
  hit=$(awk -F'\t' -v r="$route" 'NR>1 && ($2 ~ r"$" || $4==r)' "$MAP")
  if [ -n "$hit" ]; then echo "$hit" | show_menu_row; else echo "（无）"; fi

  echo
  echo "== 路由命中 =="
  hit=$(awk -F'\t' -v r="$route" 'NR>1 && $1==r' "$ROUTES")
  if [ -z "$hit" ]; then
    # 参数化路由：/dynamicPage/source/xxx 要去套 /dynamicPage/:module/:type
    hit=$(awk -F'\t' -v r="$route" 'NR>1 && $1 ~ /:/ {
      p=$1; gsub(/:[A-Za-z0-9_]+\??/, "[^/]+", p);
      if (r ~ "^" p "$") print $0 "\t(参数化路由)"
    }' "$ROUTES")
  fi
  if [ -n "$hit" ]; then echo "$hit" | show_route_row; else echo "（无，可能仓没克隆或分支不含此页）"; fi
}

# 动态页的接口不在前端源码里，在配置 JSON 里，build 时已经抓成表，这里直接查
cmd_api_dyn() {
  local api="$1"
  [ -f "$DYN" ] || return 0
  local hit
  hit=$(awk -F'\t' -v k="$api" 'NR>1 && index($5,k)' "$DYN")
  [ -n "$hit" ] || return 0
  echo
  echo "== 动态页命中（接口写在配置 JSON 里，前端源码搜不到）=="
  echo "$hit" | awk -F'\t' '{
    printf "菜单：%s\n", $1
    printf "URL ：%s\n", $2
    printf "配置：%s\n", $4
    printf "接口：%s\n", $5
    print  "---"
  }'
}

cmd_json() {
  local arg="$1" mod type
  # 支持 fe.sh json report/collectionProduct 或直接丢一整条路由/URL 进来
  arg="${arg#*#}"
  arg="$(echo "$arg" | sed -E 's#^/?(dynamicPage|dynamicMultipleTabs|dynamicReportPage|dynamicChart|dynPage)/##')"
  mod="${arg%%/*}"; type="${arg#*/}"
  [ -n "$mod" ] && [ -n "$type" ] || { echo "用法: bash scripts/fe.sh json <module>/<type>" >&2; exit 1; }
  echo "配置地址：/obs/json/plateform/$mod/$type"
  local body
  body=$(bash "$DIR/scripts/api.sh" --env "${FE_ENV:-test}" GET "/obs/json/plateform/$mod/$type" 2>/dev/null)
  [ -n "$body" ] || { echo "（拉不到，检查网关是否可达）"; return; }
  echo "-- 这个页面会调的后端接口 --"
  echo "$body" | jq -r '[..|objects|select(has("url"))|.url]|unique|.[]' 2>/dev/null || echo "（解析失败，原样看：$body）"
  echo "-- 表头字段 --"
  echo "$body" | jq -r '[.data.headers[]?|"\(.dataIndex)\t\(.title)"]|.[]' 2>/dev/null | head -40
}

cmd_api() {
  need_map
  local api="$1"
  echo "== 前端哪些文件在调这个接口 =="
  # 只搜顶层新仓的源码；dist 是打包产物、node_modules 是依赖，都排除
  local files
  files=$(grep -rl --include='*.vue' --include='*.js' \
            --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=router \
            -- "$api" "$FRONT"/scm-vue-all-*/src "$FRONT"/scm-vue-hpc/src 2>/dev/null \
          | sed "s#^$FRONT/##" | sort -u)
  if [ -z "$files" ]; then
    echo "（前端源码里没搜到：要么是动态页/报表页把接口写在配置里，要么路径是拼出来的——换个更短的片段再试）"
    cmd_api_dyn "$api"
    return
  fi
  echo "$files" | sed 's#^#02zhaocai-front/#'

  echo
  echo "== 这些文件挂在哪个路由 / 哪个菜单下 =="
  local f found=0
  while read -r f; do
    [ -n "$f" ] || continue
    local dir="${f%/*}"
    # 先精确匹配组件文件，再退一步按所在目录匹配（列表页和它的子组件常在同一目录）
    local r
    r=$(awk -F'\t' -v f="$f" -v d="$dir/" 'NR>1 && ($4==f || index($4,d)==1)' "$ROUTES")
    [ -n "$r" ] || continue
    found=1
    echo "$r" | show_route_row
    local rt
    rt=$(echo "$r" | awk -F'\t' '{print $1}' | sort -u)
    local one
    while read -r one; do
      awk -F'\t' -v r="$one" 'NR>1 && $4==r {print "  ↳ 菜单：" $1 "\n     URL ：" $2}' "$MAP"
    done <<< "$rt"
  done <<< "$files"
  [ "$found" = 1 ] || echo "（这些文件都不是路由入口，多半是被别的页面引用的子组件；用 fe.sh find <目录名> 再找一层）"
  cmd_api_dyn "$api"
}

cmd_repo() {
  need_map
  local ctx="$1"
  echo "== URL 上下文 → 前端仓库 =="
  awk -F'\t' -v c="$ctx" 'NR==1 || index($1,c)' "$CTXMAP" | column -t -s $'\t' 2>/dev/null \
    || awk -F'\t' -v c="$ctx" 'NR==1 || index($1,c)' "$CTXMAP"
}

cmd_build() {
  local env="${1:-test}"
  local tmp="/tmp/fe-menu-$env.json"
  echo "拉菜单树（$env）..."
  bash "$DIR/scripts/api.sh" --env "$env" POST /c/business/ubm/MenuMgr/queryMenuTree '{}' > "$tmp" || {
    echo "菜单接口调用失败；没有菜单也能只建路由索引，继续。" >&2; tmp="-"; }
  if [ "$tmp" != "-" ] && ! grep -q '"data"' "$tmp"; then
    echo "菜单接口返回异常，改为只建路由索引。" >&2; tmp="-"
  fi
  python3 "$DIR/scripts/lib/fe-build.py" "$tmp" "$FRONT" "$DIR/ai-docs"

  # 动态页/报表页的接口不在前端源码里，得单独抓一遍，否则「按接口反查页面」对这些页面永远失灵
  echo "抓动态页/报表页的接口..."
  printf '菜单全路径\t页面URL\t类型\t配置来源\t接口\n' > "$DYN"
  local n=0
  while IFS=$'\t' read -r chain url _ route _; do
    local seg body urls
    case "$url" in
      *"#/dynamicPage/"*|*"#/dynamicMultipleTabs/"*|*"#/dynamicReportPage/"*|*"#/dynamicChart/"*|*"#/dynPage/"*)
        seg="${url#*#/}"; seg="${seg#*/}"          # 去掉 dynamicXxx/ 前缀，剩 module/type
        body=$(bash "$DIR/scripts/api.sh" --env "$env" GET "/obs/json/plateform/$seg" 2>/dev/null)
        urls=$(echo "$body" | jq -r '[..|objects|select(has("url"))|.url]|unique|join(" ")' 2>/dev/null)
        [ -n "$urls" ] && [ "$urls" != "null" ] || continue
        printf '%s\t%s\t动态页\t/obs/json/plateform/%s\t%s\n' "$chain" "$url" "$seg" "$urls" >> "$DYN"
        n=$((n+1)) ;;
      *"#/reportForms/"*|*"#/supplierReportForms/"*)
        # 报表页不查配置：前端按路由参数直接拼接口名，规律固定
        seg="${url##*/}"
        printf '%s\t%s\t报表页\t路由参数拼接口名\t/e/business/report/source/headList_%s /e/business/report/source/agghead_%s /e/business/report/source/aggregation_%s /e/business/report/source/download_%s\n' \
               "$chain" "$url" "$seg" "$seg" "$seg" "$seg" >> "$DYN"
        n=$((n+1)) ;;
    esac
  done < <(tail -n +2 "$MAP")
  echo "动态页/报表页接口：$n 条 → $DYN"
  echo "提醒：地图反映的是**本地各前端仓当前分支**的状态，切过分支或拉过新代码后重新 build。"
}

case "${1:-}" in
  build) shift; cmd_build "${1:-test}" ;;
  json)  shift; [ $# -ge 1 ] || { usage; exit 1; }; cmd_json "$1" ;;
  url)   shift; [ $# -ge 1 ] || { usage; exit 1; }; cmd_url "$1" ;;
  api)   shift; [ $# -ge 1 ] || { usage; exit 1; }; cmd_api "$1" ;;
  repo)  shift; [ $# -ge 1 ] || { usage; exit 1; }; cmd_repo "$1" ;;
  find)  shift; [ $# -ge 1 ] || { usage; exit 1; }; cmd_find "$1" ;;
  -h|--help|"") usage ;;
  *)     cmd_find "$1" ;;
esac
