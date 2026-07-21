#!/bin/bash
# 查 Elasticsearch 工具。用法跟 dbq.sh 一个风格：凭据自动从 ai-docs/creds.env 读，省得每次拼 curl。
# ES 是 HTTP REST，本脚本底层就是 curl + jq。设计目标：让后续 AI 一句话查 ES，省 token。
#
# 用法（动词模式，覆盖 90% 场景）：
#   bash scripts/esq.sh                              # 不带参 = 列索引（test/uat/prod 环境）
#   bash scripts/esq.sh indices [pattern]            # 列索引，可用通配符过滤，如 'index_web_*_test'
#   bash scripts/esq.sh mapping  <index> [field]     # 看 mapping；field 可用通配符，如 'bu*'
#   bash scripts/esq.sh count    <index> [dsl_json]  # 数文档；可选 DSL，如 '{"query":{"term":{"buCode":"BU002"}}}'
#   bash scripts/esq.sh head     <index> [n] [sort]  # 取前 n 条（默认 5），只回 _source 省 token；sort 如 'createTime:desc'
#   bash scripts/esq.sh one      <index> <field> <value>  # 按 keyword 字段精确取一条
#   bash scripts/esq.sh search   <index> <dsl_json>  # 自定义 _search，DSL 原样塞进 body
#   bash scripts/esq.sh agg      <index> <field>     # 对某 keyword 字段做 terms 聚合，看分布
#
# 通用兜底（任意 endpoint）：
#   bash scripts/esq.sh get  <endpoint>              # GET 任意 endpoint，如 'index_web_fpt_meta_test/_settings'
#   bash scripts/esq.sh post <endpoint> [body_json]  # POST 任意 endpoint
#
# 索引命名规律（实测）：index_web_<业务>_test / index_<业务>_test / *_dev *_uat 后缀对应环境。
# 业务示例：fpt_meta=绿色通道主表、apply_meta=投标、collection_meta=集采、trade_data=交易数据报表。
# 完整索引列表用 `bash scripts/esq.sh indices` 看。
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
set -a; source "$DIR/ai-docs/creds.env"; set +a

[ -n "$ES_URL" ] || { echo "creds.env 的 ES_URL 为空，请补 ES_URL/ES_USER/ES_PASS"; exit 1; }
AUTH=(-u "$ES_USER:$ES_PASS")
HDR=(-H 'Content-Type: application/json')

# 美化输出：jq 可用走 jq，否则回退 python -m json.tool，再不行原样吐
pp() {
  if command -v jq >/dev/null 2>&1; then jq . -
  elif command -v python3 >/dev/null 2>&1; then python3 -m json.tool
  else cat; fi
}

# 所有请求统一封装：$1=method $2=endpoint $3=body(可空)
req() {
  local m="$1" ep="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS --max-time 30 "${AUTH[@]}" "${HDR[@]}" -X "$m" --data-raw "$body" "$ES_URL/$ep"
  else
    curl -sS --max-time 30 "${AUTH[@]}" -X "$m" "$ES_URL/$ep"
  fi
}

verb="${1:-}"
[ $# -gt 0 ] && shift

case "$verb" in
  indices)
    # 默认过滤到 test 环境；带参数则交给 ES 服务端 pattern 匹配（支持 * ? 通配符）
    pat="${1:-*_test}"
    curl -sS --max-time 15 "${AUTH[@]}" "$ES_URL/_cat/indices/$pat?v&s=index&h=health,status,index,docs.count,store.size"
    ;;
  mapping)
    [ $# -ge 1 ] || { echo "用法: esq.sh mapping <index> [field_pattern]"; exit 2; }
    idx="$1"; field="${2:-}"
    if [ -n "$field" ]; then
      # field 过滤：把 glob 转 regex 给 grep -E
      re=$(echo "$field" | sed 's/\./\\./g; s/\*/.*/g; s/\?/./g')
      req GET "$idx/_mapping" | jq -r ".\"$idx\".mappings.properties // {} | to_entries[] | select(.key | test(\"^${re}$\")) | {(.key): .value.type}"
    else
      req GET "$idx/_mapping" | pp
    fi
    ;;
  count)
    [ $# -ge 1 ] || { echo "用法: esq.sh count <index> [dsl_json]"; exit 2; }
    idx="$1"; body="${2:-}"
    if [ -n "$body" ]; then req GET "$idx/_count" "$body" | pp; else req GET "$idx/_count" | pp; fi
    ;;
  head)
    [ $# -ge 1 ] || { echo "用法: esq.sh head <index> [n] [sort]"; exit 2; }
    idx="$1"; n="${2:-5}"; sort="${3:-}"
    body="{\"size\":$n"
    [ -n "$sort" ] && body="$body,\"sort\":[{\"${sort%%:*}\":{\"order\":\"${sort##*:}\"}}]"
    body="$body}"
    req GET "$idx/_search" "$body" | jq '{total: .hits.total.value, hits: [.hits.hits[]._source]}'
    ;;
  one)
    [ $# -ge 3 ] || { echo "用法: esq.sh one <index> <field> <value>"; exit 2; }
    idx="$1"; f="$2"; v="$3"
    body="{\"size\":1,\"query\":{\"term\":{\"$f\":\"$v\"}}}"
    req GET "$idx/_search" "$body" | jq '{total: .hits.total.value, hit: (.hits.hits[0]._source // null)}'
    ;;
  search)
    [ $# -ge 2 ] || { echo "用法: esq.sh search <index> <dsl_json>"; exit 2; }
    idx="$1"; body="$2"
    req GET "$idx/_search" "$body" | pp
    ;;
  agg)
    [ $# -ge 2 ] || { echo "用法: esq.sh agg <index> <field> [size]"; exit 2; }
    idx="$1"; f="$2"; sz="${3:-20}"
    req GET "$idx/_search" "{\"size\":0,\"aggs\":{\"by_${f}\":{\"terms\":{\"field\":\"$f\",\"size\":$sz}}}}" \
      | jq ".aggregations.by_${f}.buckets"
    ;;
  get)
    [ $# -ge 1 ] || { echo "用法: esq.sh get <endpoint>"; exit 2; }
    req GET "$1" | pp
    ;;
  post)
    [ $# -ge 1 ] || { echo "用法: esq.sh post <endpoint> [body_json]"; exit 2; }
    req POST "$1" "${2:-}" | pp
    ;;
  "" )
    echo "# ES_URL=$ES_URL  (集群信息)"
    req GET "" | pp
    echo
    echo "# 默认列 test 环境索引；查全部用: bash scripts/esq.sh indices '*'"
    curl -sS --max-time 15 "${AUTH[@]}" "$ES_URL/_cat/indices?v&s=index&h=index,docs.count,store.size" | grep '_test' | head -50
    ;;
  *)
    echo "未知动词: $verb"; echo "看脚本头部注释或运行: bash scripts/esq.sh"; exit 2
    ;;
esac
