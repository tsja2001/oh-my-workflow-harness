#!/bin/bash
# Git 发版体检：只检查本需求涉及的仓库，不 push、不建远程分支、不改提交。
#
# 用法：
#   bash scripts/git-release.sh audit [--fetch] <仓库>...
#   bash scripts/git-release.sh manifest <仓库> <开发基线> <候选分支或提交>
#   bash scripts/git-release.sh check [--fetch] <仓库> <test|uat|prod|目标ref> <交付分支或提交>
#
# audit    判断 prod/test/uat 是否同源，告诉你应走“同一 feature”还是“目标基线交付分支”。
# manifest test 验收通过时冻结提交、文件和高风险文件清单，结果可直接贴进交接文档。
# check    提 MR 前确认交付分支确实基于目标环境、净差异可读且没有明显夹带。
#
# --fetch  只 fetch 命令中列出的仓库；每仓最多等 25 秒。fetch 只更新本地远端跟踪引用，
#          不会改公司远程仓库。脚本从不执行 push/merge/cherry-pick/reset/checkout。

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

repo_path() {
  local input="$1"
  if [ -d "$input" ] && git -C "$input" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    (cd "$input" && pwd)
  elif [ -d "$ROOT/$input" ] && git -C "$ROOT/$input" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    (cd "$ROOT/$input" && pwd)
  else
    return 1
  fi
}

fetch_repo() {
  local repo="$1"
  printf 'fetch origin（最多 25 秒）... '
  if timeout 25 git -C "$repo" fetch origin --prune >/dev/null 2>&1; then
    printf '完成\n'
  else
    printf '失败或超时，以下结果使用本地缓存；不能宣称已同步远端最新\n'
  fi
}

need_ref() {
  local repo="$1" ref="$2"
  git -C "$repo" rev-parse --verify --quiet "$ref^{commit}" >/dev/null || \
    die "$(basename "$repo") 缺少引用 $ref"
}

short_hash() {
  git -C "$1" rev-parse --short=12 "$2"
}

is_ancestor() {
  git -C "$1" merge-base --is-ancestor "$2" "$3" 2>/dev/null
}

target_ref() {
  case "$1" in
    test|uat|prod) printf 'origin/%s\n' "$1" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

show_risky_files() {
  local repo="$1" base="$2" head="$3" risky
  risky=$(git -C "$repo" diff --name-only "$base..$head" | awk '
    /(^|\/)public\/statics\/config\.js$/ ||
    /(^|\/)package-lock\.json$/ ||
    /(^|\/)yarn\.lock$/ ||
    /(^|\/)pnpm-lock\.yaml$/ ||
    /(^|\/)\.env([.].*)?$/ ||
    /(^|\/)creds\.env$/ ||
    /(^|\/)dist\// ||
    /(^|\/)node_modules\// ||
    /(^|\/)(application|bootstrap)(-[^.]+)?\.(yml|yaml|properties)$/
  ')
  if [ -n "$risky" ]; then
    printf '高风险文件（必须逐个说明，不能默认带入）：\n%s\n' "$risky" | sed '2,$s/^/  ! /'
  else
    printf '高风险文件：未发现常见环境配置、依赖锁或构建产物\n'
  fi
}

audit_one() {
  local repo="$1" name prod_test prod_uat test_uat pt_count tu_count mode
  name="${repo#$ROOT/}"
  need_ref "$repo" origin/prod
  need_ref "$repo" origin/test
  need_ref "$repo" origin/uat

  prod_test=no
  prod_uat=no
  test_uat=no
  is_ancestor "$repo" origin/prod origin/test && prod_test=yes
  is_ancestor "$repo" origin/prod origin/uat && prod_uat=yes
  is_ancestor "$repo" origin/test origin/uat && test_uat=yes
  pt_count=$(git -C "$repo" rev-list --left-right --count origin/prod...origin/test)
  tu_count=$(git -C "$repo" rev-list --left-right --count origin/test...origin/uat)

  printf '\n[%s]\n' "$name"
  printf '当前工作区：%s\n' "$(git -C "$repo" status --short --branch | head -1)"
  printf 'prod=%s  test=%s  uat=%s\n' \
    "$(short_hash "$repo" origin/prod)" \
    "$(short_hash "$repo" origin/test)" \
    "$(short_hash "$repo" origin/uat)"
  printf '祖先关系：prod<=test %s，prod<=uat %s，test<=uat %s\n' "$prod_test" "$prod_uat" "$test_uat"
  printf '分叉计数：prod...test %s；test...uat %s（左独有/右独有）\n' \
    "${pt_count//$'\t'/ / }" "${tu_count//$'\t'/ / }"

  if [ "$prod_test" = yes ] && [ "$prod_uat" = yes ]; then
    mode='同源模式：feature 可从 origin/prod 开；保持 feature 独立，不把 test/uat 合回 feature，才能按同一提交序列逐级提 MR。'
  else
    mode='分叉模式：不要机械从 prod 开再合 test。开发分支从本需求实际依赖的 test 基线开；UAT、prod 各自从目标环境最新基线开交付分支，只搬冻结清单里的提交。'
  fi
  printf '建议：%s\n' "$mode"
}

cmd_audit() {
  local do_fetch=0 repo input
  if [ "${1:-}" = "--fetch" ]; then
    do_fetch=1
    shift
  fi
  [ "$#" -gt 0 ] || die "audit 至少要给一个仓库"
  for input in "$@"; do
    repo=$(repo_path "$input") || die "不是 Git 仓库：$input"
    [ "$do_fetch" -eq 1 ] && fetch_repo "$repo"
    audit_one "$repo"
  done
}

cmd_manifest() {
  [ "$#" -eq 3 ] || die "用法：git-release.sh manifest <仓库> <开发基线> <候选分支或提交>"
  local repo base="$2" head="$3" name
  repo=$(repo_path "$1") || die "不是 Git 仓库：$1"
  need_ref "$repo" "$base"
  need_ref "$repo" "$head"
  name="${repo#$ROOT/}"

  printf '# Git 发布清单片段\n\n'
  printf -- '- 仓库：`%s`\n' "$name"
  printf -- '- 开发基线：`%s@%s`\n' "$base" "$(short_hash "$repo" "$base")"
  printf -- '- 候选头：`%s@%s`\n' "$head" "$(short_hash "$repo" "$head")"
  printf -- '- 提交顺序：\n'
  git -C "$repo" log --reverse --format='  - `%h` %s' "$base..$head"
  printf -- '- 净变更文件：\n'
  git -C "$repo" diff --name-status "$base..$head" | sed 's/^/  - `/' | sed 's/$/`/'
  printf -- '- 风险扫描：\n'
  show_risky_files "$repo" "$base" "$head" | sed 's/^/  /'
}

cmd_check() {
  local do_fetch=0 repo target candidate target_full ahead_count merge_count name
  if [ "${1:-}" = "--fetch" ]; then
    do_fetch=1
    shift
  fi
  [ "$#" -eq 3 ] || die "用法：git-release.sh check [--fetch] <仓库> <目标环境或ref> <交付分支或提交>"
  repo=$(repo_path "$1") || die "不是 Git 仓库：$1"
  target="$2"
  candidate="$3"
  target_full=$(target_ref "$target")
  [ "$do_fetch" -eq 1 ] && fetch_repo "$repo"
  need_ref "$repo" "$target_full"
  need_ref "$repo" "$candidate"
  name="${repo#$ROOT/}"

  printf '[%s]\n' "$name"
  printf '目标：%s@%s\n' "$target_full" "$(short_hash "$repo" "$target_full")"
  printf '候选：%s@%s\n' "$candidate" "$(short_hash "$repo" "$candidate")"

  if ! is_ancestor "$repo" "$target_full" "$candidate"; then
    printf '阻断：目标环境不是候选分支的祖先。这个 MR 可能夹带别的环境历史；请从最新 %s 重建干净交付分支。\n' "$target_full" >&2
    exit 2
  fi

  ahead_count=$(git -C "$repo" rev-list --count "$target_full..$candidate")
  merge_count=$(git -C "$repo" rev-list --count --merges "$target_full..$candidate")
  printf '基线检查：通过；候选领先目标 %s 个提交\n' "$ahead_count"
  if [ "$ahead_count" -eq 0 ]; then
    printf '提醒：候选相对目标没有新提交，MR 将没有可合内容\n'
  fi
  if [ "$merge_count" -gt 0 ]; then
    printf '提醒：候选含 %s 个 merge 提交，确认没有把 test/uat 整段历史合进来\n' "$merge_count"
  fi

  printf '\n提交（按应用顺序）：\n'
  git -C "$repo" log --reverse --format='  %h %s' "$target_full..$candidate"
  printf '\n净变更文件：\n'
  git -C "$repo" diff --name-status "$target_full..$candidate" | sed 's/^/  /'
  printf '\n'
  show_risky_files "$repo" "$target_full" "$candidate"
  printf '结论：Git 基线合格；业务范围、编译/构建和配置清单仍需按需求文档验收。\n'
}

case "${1:-}" in
  audit)
    shift
    cmd_audit "$@"
    ;;
  manifest)
    shift
    cmd_manifest "$@"
    ;;
  check)
    shift
    cmd_check "$@"
    ;;
  -h|--help|help|'')
    usage
    ;;
  *)
    die "未知命令：$1（-h 看用法）"
    ;;
esac
