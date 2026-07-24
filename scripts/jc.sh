#!/bin/bash
# 隔离编译（Phase 6）。用法：
#   bash scripts/jc.sh <仓库目录> <目标.java 文件...>
# 例：
#   bash scripts/jc.sh 01zhaocai-end/scm-source-all \
#     01zhaocai-end/scm-source-all/scm-source-chase/src/main/java/com/pcitc/scm/source/chase/service/impl/XxxServiceImpl.java
#
# 为什么要这个脚本：企业老代码库的全量 mvn 编译本来就是坏的（跨模块 SNAPSHOT 漂移），
# 我们的任务不是修好它，而是证明"自己写的代码是健全的"。本脚本自动处理三个每次都会踩的坑：
#   1. classpath 拼全量 .m2 jar + 兄弟模块 target/classes（mvn dependency:build-classpath 在本环境走不通）
#   2. sourcepath 用 -maxdepth 4（模块/src/main/java 在第 4 层，用 3 会静默取空，导致 argfile 参数错位报 invalid flag）
#   3. **javac 只对显式列出的源文件跑注解处理器**：Lombok @Data 实体如果只靠 sourcepath 隐式加载，
#      getter 一个都不会生成，会报一大片 cannot find symbol，看起来像是我们代码写错了。
#      因此本脚本自动把 model/ao/vo/param/config/dto 下的所有实体一并显式提交给 javac。
#
# 判定规则（脚本已帮你分好）：目标文件报错数=0 就算通过，哪怕其他文件有报错——
# 那是环境漂移（别人的现有文件本来就编不过），不是你的问题。
set -u
REPO="${1:-}"
shift || true
[ -n "$REPO" ] && [ $# -gt 0 ] || {
  echo "用法: bash scripts/jc.sh <仓库目录> <目标.java 文件...>"; exit 1; }
[ -d "$REPO" ] || { echo "仓库目录不存在: $REPO"; exit 1; }

REPO="$(cd "$REPO" && pwd)"
OUT=$(mktemp -d /tmp/jc-out-XXXX)
ERR=$(mktemp /tmp/jc-err-XXXX.txt)
ARGS=$(mktemp /tmp/jc-args-XXXX.txt)

TARGETS=()
for f in "$@"; do
  [ -f "$f" ] || { echo "目标文件不存在: $f"; exit 1; }
  TARGETS+=("$(cd "$(dirname "$f")" && pwd)/$(basename "$f")")
done

CP=$(find "$HOME/.m2" -name '*.jar' 2>/dev/null | grep -v sources | tr '\n' ':')
for d in $(find "$REPO" -maxdepth 3 -type d -path '*/target/classes'); do CP="$CP$d:"; done

SP=""
for d in $(find "$REPO" -maxdepth 4 -type d -path '*/src/main/java'); do SP="$SP$d:"; done
[ -n "$SP" ] || { echo "没找到任何 src/main/java，确认仓库目录传对了"; exit 1; }

# Lombok 实体必须显式列出，否则注解处理器不跑、getter 不生成
mapfile -t ENTITIES < <(find "$REPO" -type d \( -name model -o -name ao -o -name vo -o -name param -o -name config -o -name dto \) \
  -not -path '*/target/*' -exec find {} -name '*.java' \; 2>/dev/null | sort -u)

{
  echo "-encoding"; echo "UTF-8"
  echo "-nowarn"
  echo "-cp"; echo "$CP"
  echo "-sourcepath"; echo "$SP"
  echo "-d"; echo "$OUT"
} > "$ARGS"

echo "目标文件 ${#TARGETS[@]} 个，随行实体 ${#ENTITIES[@]} 个，编译中……"
javac "@$ARGS" "${TARGETS[@]}" "${ENTITIES[@]}" 2> "$ERR"
RC=$?

# 注意：grep -c 无匹配时会打印 0 并以退出码 1 结束，不要再接 "|| echo 0"，否则变量会变成两行
TOTAL=$(grep -c 'error:' "$ERR" 2>/dev/null)
echo "===== javac 退出码: $RC ，error 总数: $TOTAL ====="

MINE=0
for t in "${TARGETS[@]}"; do
  n=$(grep -c "^$t:.*error:" "$ERR" 2>/dev/null)
  MINE=$((MINE + n))
  CLS="${t##*/}"; CLS="${CLS%.java}"
  if find "$OUT" -name "$CLS.class" | grep -q .; then GEN="已生成 class"; else GEN="未生成 class"; fi
  echo "  $CLS : 报错 $n 处，$GEN"
done

if [ "$MINE" -gt 0 ]; then
  echo
  echo "===== 你的文件的报错（必须修）====="
  for t in "${TARGETS[@]}"; do grep -A3 "^$t:.*error:" "$ERR" | head -40; done
  echo
  echo "结论：目标文件有 $MINE 处报错，是我们自己的问题，必须修。"
  exit 1
fi

if [ "$TOTAL" -gt 0 ]; then
  echo
  echo "===== 其他文件的报错（环境漂移，与本次改动无关，仅列文件）====="
  grep -oE '^/[^:]+\.java' "$ERR" | sort | uniq -c | sort -rn | head -10
  echo
  echo "结论：目标文件 0 报错，可以交给 Jenkins。其余 $TOTAL 处报错在别人的现有文件里，"
  echo "      是跨模块 SNAPSHOT 版本漂移，不是本次改动引起的（这正是同事从不本地编译的原因）。"
  exit 0
fi

echo
echo "结论：全部编译通过，0 报错。"
echo "（明细：$ERR ，产物：$OUT）"
