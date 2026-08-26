#!/bin/bash
# 账号 / 公司 / 岗位 / 角色 / 菜单 速查工具。
#
# 解决的问题：这套系统的权限是四层，而且岗位是【按公司】挂的——
#   用户 --(按公司)--> 岗位 --> 角色 --> 菜单
# 所以"同一个账号切到不同公司，看到的菜单不一样"。
# 要走一遍业务流程，必须知道"这一步该用哪个账号、切到哪家公司"。本脚本就是回答这个的。
#
# 红线：本脚本【绝不打印】密码、token；登录名默认打码。要真实登录名自己看 ai-docs/creds.env。
#
# 用法见 `bash scripts/perm.sh help`。

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREDS="$ROOT/ai-docs/creds.env"

ENV_NAME="uat"   # 默认 uat：真实的岗位/角色配置在 uat，test 的 rbac 数据有大量历史脏行
SHOW_SQL=0

# ---------- 参数解析 ----------
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --env) ENV_NAME="${2:-}"; shift 2 ;;
    --env=*) ENV_NAME="${1#*=}"; shift ;;
    --sql) SHOW_SQL=1; shift ;;
    -h|--help) ARGS+=("help"); shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]:-help}"
CMD="${1:-help}"; shift || true

case "$ENV_NAME" in
  test|uat) ;;
  *) echo "环境只能是 test 或 uat（prod 不碰）" >&2; exit 1 ;;
esac
DB="scm_ubm_${ENV_NAME}"

[ -r "$CREDS" ] || { echo "找不到凭据文件 $CREDS" >&2; exit 1; }
set -a; source "$CREDS"; set +a

q() {  # q <SQL>  -> 表格输出
  [ "$SHOW_SQL" = "1" ] && printf '\n--- SQL ---\n%s\n-----------\n' "$1" >&2
  mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" \
        --default-character-set=utf8mb4 --table "$DB" -e "$1" 2>/dev/null
}
qr() { # qr <SQL> -> 无表框、tab 分隔，给脚本内部用
  mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" \
        --default-character-set=utf8mb4 -N -B "$DB" -e "$1" 2>/dev/null
}
esc() { printf '%s' "${1//\'/\'\'}"; }
mask() { local v="$1"; local n=${#v}; if [ "$n" -le 4 ]; then printf '****'; else printf '%s****%s' "${v:0:2}" "${v: -2}"; fi; }

# ---------- 账号注册表：从 creds.env 自动发现 SCM_<别名>_USER ----------
# 加一个新账号 = 往 creds.env 加 SCM_XXX_USER / SCM_XXX_PASS 两行，本脚本无需改动。
aliases() {
  sed -n 's/^\s*SCM_\([A-Z0-9_]*\)_USER=.*/\1/p' "$CREDS" | awk '!seen[$0]++' | tr 'A-Z' 'a-z'
}
login_of() { # login_of <别名>
  local key="SCM_$(printf '%s' "$1" | tr 'a-z' 'A-Z')_USER"
  printf '%s' "${!key:-}"
}
member_of() { # member_of <别名> -> member_id（内部用 member_code，供应商用 member_name）
  local login; login="$(login_of "$1")"; [ -n "$login" ] || return 1
  local e; e="$(esc "$login")"
  qr "SELECT member_id FROM ubm_member
      WHERE member_code='$e' OR member_id='$e' OR member_name='$e'
      ORDER BY (member_code='$e') DESC, (member_name='$e') DESC LIMIT 1"
}

header() { printf '\n环境=%s  库=%s\n' "$ENV_NAME" "$DB"; }

# ---------- 子命令 ----------
cmd_accounts() {
  header
  {
  printf '别名\t登录名\t姓名/名称\t类型\t公司数\t岗位数\t权限来源\t最后登录\n'
  local a login mid row nm ty cc jc lt src
  for a in $(aliases); do
    login="$(login_of "$a")"
    if [ -z "$login" ]; then printf '%s\t(creds 里没有值)\t-\t-\t-\t-\t-\t-\n' "$a"; continue; fi
    mid="$(member_of "$a" || true)"
    if [ -z "$mid" ]; then printf '%s\t%s\t!! 在 %s 里找不到\t-\t-\t-\t-\t-\n' "$a" "$(mask "$login")" "$DB"; continue; fi
    row="$(qr "SELECT
        COALESCE((SELECT MIN(j.real_name) FROM ubm_member_job j WHERE j.member_id=m.member_id AND j.delete_sign=0 AND j.real_name<>''), m.member_name),
        COALESCE(m.member_type_name,m.member_type),
        (SELECT COUNT(*) FROM ubm_member_company c WHERE c.member_id=m.member_id AND c.delete_sign=0),
        (SELECT COUNT(*) FROM ubm_member_job j WHERE j.member_id=m.member_id AND j.delete_sign=0),
        COALESCE(m.last_login_time,'-'),
        COALESCE((SELECT MIN(c.company_sign) FROM ubm_member_company c WHERE c.member_id=m.member_id AND c.delete_sign=0),'-')
      FROM ubm_member m WHERE m.member_id='$mid'")"
    IFS=$'\t' read -r nm ty cc jc lt sign <<<"$row"
    if [ "$jc" = "0" ] && [ "$sign" = "supplier" ]; then src="供应商门户(隐式,无岗位)"; else src="岗位→角色"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$a" "$(mask "$login")" "$nm" "$ty" "$cc" "$jc" "$src" "$lt"
  done
  } | column -t -s $'\t'
  printf '\n真实登录名/密码看 ai-docs/creds.env（禁止复制进文档、提交、聊天）。\n'
  printf '「权限来源」为「供应商门户(隐式)」的账号没有岗位记录——供应商主账号的菜单由 company_sign=supplier + 用户类型决定，\n不走岗位链路（子账号才写 ubm_member_role）。【推测，未在代码中定位到分配点】\n'
}

cmd_companies() {
  local a="${1:?用法: perm.sh companies <别名> [公司关键词]}" kw="${2:-}"
  local mid; mid="$(member_of "$a")" || { echo "别名 $a 没配"; exit 1; }
  header; printf '账号别名=%s  member_id=%s\n\n' "$a" "$mid"
  q "SELECT c.company_code 公司编码, c.company_name 公司名称,
            IF(c.def_company='1','是','') 默认,
            (SELECT COUNT(*) FROM ubm_member_job j
              WHERE j.member_id=c.member_id AND j.company_id=c.company_id AND j.delete_sign=0) 岗位数,
            (SELECT GROUP_CONCAT(DISTINCT j.job_name ORDER BY j.job_name SEPARATOR ', ')
               FROM ubm_member_job j
              WHERE j.member_id=c.member_id AND j.company_id=c.company_id AND j.delete_sign=0) 岗位
       FROM ubm_member_company c
      WHERE c.member_id='$mid' AND c.delete_sign=0
        ${kw:+AND c.company_name LIKE '%$(esc "$kw")%'}
      ORDER BY 岗位数 DESC, c.def_company DESC, c.company_name"
}

cmd_jobs() {
  local a="${1:?用法: perm.sh jobs <别名> [公司关键词]}" kw="${2:-}"
  local mid; mid="$(member_of "$a")" || { echo "别名 $a 没配"; exit 1; }
  header; printf '账号别名=%s\n\n' "$a"
  q "SELECT j.company_name 公司, j.job_code 岗位编码, j.job_name 岗位,
            COALESCE(g.group_codes,'(岗位表里没有此岗位)') 适用层级
       FROM ubm_member_job j
       LEFT JOIN ubm_job_manage g ON g.job_code=j.job_code AND g.delete_sign=0
      WHERE j.member_id='$mid' AND j.delete_sign=0
        ${kw:+AND j.company_name LIKE '%$(esc "$kw")%'}
      ORDER BY j.company_name, j.job_name"
}

cmd_roles() {
  local a="${1:?用法: perm.sh roles <别名> [公司关键词]}" kw="${2:-}"
  local mid; mid="$(member_of "$a")" || { echo "别名 $a 没配"; exit 1; }
  header; printf '账号别名=%s\n\n' "$a"
  q "SELECT j.company_name 公司,
            GROUP_CONCAT(DISTINCT jr.role_name ORDER BY jr.role_name SEPARATOR ' | ') 角色
       FROM ubm_member_job j
       JOIN ubm_job_role jr ON jr.job_code=j.job_code AND jr.delete_sign=0
      WHERE j.member_id='$mid' AND j.delete_sign=0
        ${kw:+AND j.company_name LIKE '%$(esc "$kw")%'}
      GROUP BY j.company_name ORDER BY j.company_name"
}

cmd_menus() {
  local a="${1:?用法: perm.sh menus <别名> <公司关键词> [菜单关键词]}"
  local co="${2:?必须给公司关键词}" kw="${3:-}"
  local mid; mid="$(member_of "$a")" || { echo "别名 $a 没配"; exit 1; }
  header; printf '账号别名=%s  公司关键词=%s\n\n' "$a" "$co"
  q "SELECT m.group_name 门户, COALESCE(NULLIF(m.pname,''),'-') 上级菜单, m.menu_name 菜单,
            COALESCE(NULLIF(m.menu_url,''),'-') 地址,
            IF(m.state=1,'启用','⚠已停用') 状态,
            GROUP_CONCAT(DISTINCT jr.role_name ORDER BY jr.role_name SEPARATOR ',') 来自角色
       FROM ubm_member_job j
       JOIN ubm_job_role jr ON jr.job_code=j.job_code AND jr.delete_sign=0
       JOIN ubm_rbac_role r ON r.role_code=jr.role_code
       JOIN ubm_rbac_role_menu rm ON rm.role_id=r.role_id
       JOIN ubm_rbac_menu m ON m.menu_id=rm.menu_id
      WHERE j.member_id='$mid' AND j.delete_sign=0
        AND j.company_name LIKE '%$(esc "$co")%'
        ${kw:+AND m.menu_name LIKE '%$(esc "$kw")%'}
      GROUP BY m.group_name, m.pname, m.menu_name, m.menu_url, m.state
      ORDER BY m.group_name, m.pname, m.menu_name"
}

# 谁能点这个菜单 —— 本脚本最常用的一条
cmd_can() {
  local kw="${1:?用法: perm.sh can <菜单关键词>}"
  header; printf '问题：哪个账号切到哪家公司，能点到含「%s」的菜单？\n\n' "$kw"
  local a mid any=0
  for a in $(aliases); do
    mid="$(member_of "$a" 2>/dev/null || true)"; [ -n "$mid" ] || continue
    local out
    out="$(qr "SELECT DISTINCT CONCAT(m.menu_name, IF(m.state=1,'',' ⚠已停用'),' [',m.group_name,']'), j.company_name, j.job_name, jr.role_name, COALESCE(NULLIF(m.menu_url,''),'-')
       FROM ubm_member_job j
       JOIN ubm_job_role jr ON jr.job_code=j.job_code AND jr.delete_sign=0
       JOIN ubm_rbac_role r ON r.role_code=jr.role_code
       JOIN ubm_rbac_role_menu rm ON rm.role_id=r.role_id
       JOIN ubm_rbac_menu m ON m.menu_id=rm.menu_id
      WHERE j.member_id='$mid' AND j.delete_sign=0 AND m.menu_name LIKE '%$(esc "$kw")%'
      ORDER BY m.menu_name, j.company_name LIMIT 200")"
    [ -n "$out" ] || continue
    any=1
    printf '===== 账号别名：%s =====\n' "$a"
    printf '%s\n' "$out" | awk -F'\t' '
      { k=$1 "\t" $3 "\t" $4 "\t" $5; n[k]++; if(n[k]<=4) co[k]=co[k] (co[k]?"、":"") $2 }
      END { for (k in n) { split(k,f,"\t");
              extra = (n[k]>4) ? sprintf("…等共 %d 家", n[k]) : "";
              printf "  菜单：%s\n    岗位：%s   角色：%s\n    可用公司(%d)：%s%s\n    地址：%s\n\n", f[1], f[2], f[3], n[k], co[k], extra, f[4] } }'
    printf '\n'
  done
  [ "$any" = "1" ] || printf '⚠ 现有账号里没有任何一个能点到这个菜单。\n  要么菜单名写错了，要么这是缺的权限——用 `perm.sh whichrole "%s"` 看该找业务要哪个角色。\n' "$kw"
}

# 这个菜单要哪个角色（不管有没有账号）
cmd_whichrole() {
  local kw="${1:?用法: perm.sh whichrole <菜单关键词>}"
  header
  q "SELECT m.menu_name 菜单, m.group_name 门户, IF(m.state=1,'启用','⚠已停用') 状态,
            COALESCE(NULLIF(m.menu_url,''),'-') 地址,
            GROUP_CONCAT(DISTINCT r.role_name ORDER BY r.role_name SEPARATOR ' | ') 需要下列任一角色
       FROM ubm_rbac_menu m
       JOIN ubm_rbac_role_menu rm ON rm.menu_id=m.menu_id
       JOIN ubm_rbac_role r ON r.role_id=rm.role_id
      WHERE m.menu_name LIKE '%$(esc "$kw")%'
      GROUP BY m.menu_name, m.group_name, m.state, m.menu_url ORDER BY m.menu_name"
  printf '\n哪些岗位带这些角色：\n'
  q "SELECT jr.role_name 角色, GROUP_CONCAT(DISTINCT jr.job_name ORDER BY jr.job_name SEPARATOR ' | ') 挂在这些岗位上
       FROM ubm_job_role jr
      WHERE jr.delete_sign=0 AND jr.role_code IN (
        SELECT DISTINCT r.role_code FROM ubm_rbac_menu m
          JOIN ubm_rbac_role_menu rm ON rm.menu_id=m.menu_id
          JOIN ubm_rbac_role r ON r.role_id=rm.role_id
         WHERE m.menu_name LIKE '%$(esc "$kw")%')
      GROUP BY jr.role_name ORDER BY jr.role_name"
}

cmd_role() {
  local kw="${1:?用法: perm.sh role <角色关键词>}"
  header
  q "SELECT DISTINCT r.role_name 角色, m.group_name 门户, m.menu_name 菜单,
            IF(m.state=1,'启用','⚠停用') 状态, COALESCE(NULLIF(m.menu_url,''),'-') 地址
       FROM ubm_rbac_role r
       JOIN ubm_rbac_role_menu rm ON rm.role_id=r.role_id
       JOIN ubm_rbac_menu m ON m.menu_id=rm.menu_id
      WHERE r.role_name LIKE '%$(esc "$kw")%'
      ORDER BY r.role_name, m.group_name, m.menu_name LIMIT 300"
}

cmd_job() {
  local kw="${1:?用法: perm.sh job <岗位关键词>}"
  header
  q "SELECT jr.job_code 岗位编码, jr.job_name 岗位,
            GROUP_CONCAT(DISTINCT jr.role_name ORDER BY jr.role_name SEPARATOR ' | ') 角色
       FROM ubm_job_role jr
      WHERE jr.delete_sign=0 AND jr.job_name LIKE '%$(esc "$kw")%'
      GROUP BY jr.job_code, jr.job_name ORDER BY jr.job_name"
}

# 招采主流程 13 棒需要的关键菜单，逐条体检
FLOW_STEPS=(
"1|采购计划编制|企业|采购员编计划"
"2|采购计划审批|企业|审计划（必须换人）"
"3|采购方案编制|企业|采购员编采办方案"
"4|采购方案审批|企业|审方案（必须换人）"
"5|招标管理|企业|发招采公告，寻源单诞生"
"5b|询价管理|企业|询价方式的入口"
"6|投标管理|供应商|供应商投标"
"6b|中标管理|供应商|供应商看中标结果"
"7|保证金/标书费审批|企业|确认保证金/标书费到账（uat 里旧的「保证金审批」「标书费审批」两个菜单已停用，合并到这一个）"
"8|专家抽取|企业|抽评标专家"
"8b|专家抽取审批|企业|指定专家时才需要"
"9|评审响应|专家|专家接受邀请"
"9b|项目评审|专家|专家打分"
"10|定标方案审批|企业|审定标方案（必须换人）"
"11|终止公告审批|企业|中途终止"
"11b|延期公告审批|企业|延期"
"11c|澄清公告审批|企业|澄清"
"12|保证金台账|企业|退保证金对账"
"13|供应商入网审批|企业|供应商入网"
"13b|供应商入围审批|企业|供应商入围"
"14|设置监标人|企业|给项目指派监标人"
"14b|监标任务|企业|监标人干活的页面"
"15|商品上架管理|企业|商城商品上架（M 线）"
"15b|合同推送商城|企业|把中标合同推到商城（招采↔商城的接头）"
"16|订单管理|企业|企业端看订单（M 线）"
"16b|订单列表|供应商|供应商端看订单"
)

cmd_cover() {
  header
  printf '招采主流程覆盖体检：每一棒需要的菜单，现有账号里谁能点？\n\n'
  local names="" step menu
  for step in "${FLOW_STEPS[@]}"; do
    menu="$(printf '%s' "$step" | cut -d'|' -f2)"
    names="${names}${names:+,}'$(esc "$menu")'"
  done

  # 每个账号只查一次（一次连接拿全部命中），避免几十次 mysql 连接
  local tmp; tmp="$(mktemp)"; trap 'rm -f "$tmp"' RETURN
  local a mid
  for a in $(aliases); do
    mid="$(member_of "$a" 2>/dev/null || true)"; [ -n "$mid" ] || continue
    qr "SELECT DISTINCT m.menu_name, '$a', j.company_name, j.job_name, m.group_name
          FROM ubm_member_job j
          JOIN ubm_job_role jr ON jr.job_code=j.job_code AND jr.delete_sign=0
          JOIN ubm_rbac_role r ON r.role_code=jr.role_code
          JOIN ubm_rbac_role_menu rm ON rm.role_id=r.role_id
          JOIN ubm_rbac_menu m ON m.menu_id=rm.menu_id
         WHERE j.member_id='$mid' AND j.delete_sign=0 AND m.state=1
           AND m.group_name NOT LIKE '%移动%' AND m.menu_name IN ($names)" >> "$tmp"
    # 供应商主账号没有岗位记录，菜单由 company_sign=supplier 隐式决定，单独补一路
    qr "SELECT DISTINCT m.menu_name, '$a', c.company_name, CONCAT(m.group_name,'/隐式'), m.group_name
          FROM ubm_member_company c
          JOIN ubm_rbac_menu m ON m.group_name LIKE '%供应商%'
         WHERE c.member_id='$mid' AND c.delete_sign=0 AND c.company_sign='supplier'
           AND m.menu_name IN ($names)" >> "$tmp"
  done

  local miss_file; miss_file="$(mktemp)"
  local no desc hit portal
  {
  printf '棒次\t菜单\t状态\t可用 账号→公司(岗位)\n'
  for step in "${FLOW_STEPS[@]}"; do
    no="$(printf '%s' "$step" | cut -d'|' -f1)"
    menu="$(printf '%s' "$step" | cut -d'|' -f2)"
    portal="$(printf '%s' "$step" | cut -d'|' -f3)"
    desc="$(printf '%s' "$step" | cut -d'|' -f4)"
    hit="$(awk -F'\t' -v m="$menu" -v pt="$portal" '$1==m && index($5,pt)>0 {key=$2" → "$3" ("$4")"; if(!seen[$2]++) out=out (out?"； ":"") key} END{print out}' "$tmp")"
    if [ -n "$hit" ]; then
      printf '%s\t%s\t✅\t%s\n' "$no" "$menu" "$hit"
    else
      printf '%s\t%s\t❌\t(%s) —— 无账号可点\n' "$no" "$menu" "$desc"
      printf '%s|%s\n' "$menu" "$desc" >> "$miss_file"
    fi
  done
  } | column -t -s $'\t'

  local missing=()
  if [ -s "$miss_file" ]; then mapfile -t missing < "$miss_file"; fi
  rm -f "$miss_file"

  if [ ${#missing[@]} -gt 0 ]; then
    printf '\n===== 缺口清单：下面这些要找业务开权限 =====\n'
    local mm
    for mm in "${missing[@]}"; do
      menu="${mm%%|*}"; desc="${mm#*|}"
      printf '\n【%s】（%s）\n' "$menu" "$desc"
      qr "SELECT DISTINCT CONCAT('    需要角色：', r.role_name)
            FROM ubm_rbac_menu m
            JOIN ubm_rbac_role_menu rm ON rm.menu_id=m.menu_id
            JOIN ubm_rbac_role r ON r.role_id=rm.role_id
           WHERE m.menu_name='$(esc "$menu")'"
      qr "SELECT DISTINCT CONCAT('      带该角色的岗位：', jr.job_name)
            FROM ubm_job_role jr
           WHERE jr.delete_sign=0 AND jr.role_code IN (
             SELECT DISTINCT r.role_code FROM ubm_rbac_menu m
               JOIN ubm_rbac_role_menu rm ON rm.menu_id=m.menu_id
               JOIN ubm_rbac_role r ON r.role_id=rm.role_id
              WHERE m.menu_name='$(esc "$menu")')"
    done
    printf '\n把上面的「岗位」名字发给业务/管理员，让他给对应账号在对应公司挂这个岗位即可。\n'
  else
    printf '\n全部覆盖 ✅\n'
  fi
}

# 供应商账号能不能对某个采购单位投标：入网/黑名单/冻结/服务关系 一次看全
cmd_supplier() {
  local a="${1:-supplier}" buyer="${2:-}"
  local login; login="$(login_of "$a")"
  [ -n "$login" ] || { echo "别名 $a 没配"; exit 1; }
  local srmdb="scm_srm_${ENV_NAME}"
  header; printf '供应商别名=%s\n\n' "$a"
  qs() { mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" \
              --default-character-set=utf8mb4 --table "$srmdb" -e "$1" 2>/dev/null; }
  qsr() { mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" \
              --default-character-set=utf8mb4 -N -B "$srmdb" -e "$1" 2>/dev/null; }
  local e; e="$(esc "$login")"

  printf '— ① 供应商主档（srm_company）—\n'
  qs "SELECT company_code 供应商编码, LEFT(company_name,26) 名称,
             endisable_status_name 启用状态,
             IF(black_sign IS NULL,'否','⚠是') 已拉黑,
             IF(freeze_sign IS NULL,'否','⚠是') 已冻结,
             LEFT(audit_company_name,20) 入网审核单位
        FROM srm_company WHERE company_name='$e' AND delete_sign=0"

  printf '\n— ② 入网/扩充申请（srm_apply）—\n'
  qs "SELECT apply_info_name 申请类型, apply_status_name 状态, COUNT(*) 条数, MAX(create_time) 最近
        FROM srm_apply WHERE company_name='$e' AND delete_sign=0
       GROUP BY 1,2 ORDER BY 4 DESC LIMIT 8"

  printf '\n— ③ 服务关系：这家供应商服务哪些采购单位（决定能对谁投标）—\n'
  qs "SELECT service_company_code 编码, LEFT(service_company_name,26) 服务对象,
             relation_status_name 状态
        FROM srm_company_servicerela WHERE company_name='$e' AND delete_sign=0
       ORDER BY service_company_name LIMIT 20"
  printf '  注：服务关系登记在【板块/二级集团】那一层（如 10010000 冀东水泥），\n'
  printf '      不是逐个公司登记。下级公司发的标，靠上级板块的服务关系覆盖。【实测】\n'

  if [ -n "$buyer" ]; then
    printf '\n— ④ 对【%s】能不能投标 —\n' "$buyer"
    local orgrow
    orgrow="$(qr "SELECT CONCAT(org_code,'|',org_name,'|',COALESCE(parent_org_code,'-'),'|',COALESCE(parent_org_name,'-'),'|',COALESCE(belong_bu_code,'-'),'|',COALESCE(belong_bu_name,'-'))
                    FROM ubm_organization WHERE org_name LIKE '%$(esc "$buyer")%' LIMIT 1")"
    if [ -z "$orgrow" ]; then printf '  ✗ 在 ubm_organization 里找不到这个采购单位\n'; return 0; fi
    local oc on pc pn bc bn
    IFS='|' read -r oc on pc pn bc bn <<<"$orgrow"
    printf '  采购单位：%s (%s)\n  上级：%s (%s)\n  所属板块：%s (%s)\n' "$on" "$oc" "$pn" "$pc" "$bn" "$bc"
    local hit
    hit="$(qsr "SELECT service_company_name FROM srm_company_servicerela
                 WHERE company_name='$e' AND delete_sign=0
                   AND service_company_code IN ('$oc','$pc','$bc') LIMIT 3")"
    if [ -n "$hit" ]; then
      printf '  ✅ 有服务关系覆盖：%s\n' "$(printf '%s' "$hit" | tr '\n' '、')"
    else
      printf '  ⚠ 没有匹配到服务关系（本级/上级/板块都没有）——大概率投不了，开工前先真操作验一次\n'
    fi
  else
    printf '\n（想判断能不能对某个采购单位投标，加第二个参数，如：perm.sh supplier %s 沧州临港）\n' "$a"
  fi
}

# 当前登录态在哪家公司 + 专家身份体检
cmd_now() {
  local a="${1:-admin}"
  local mid; mid="$(member_of "$a")" || { echo "别名 $a 没配"; exit 1; }
  header; printf '账号别名=%s  member_id=%s\n\n' "$a" "$mid"

  printf '— 当前公司（服务端会话，POST c/business/ubm/memberCurrent/setCurrentCompany 写入）—\n'
  local cur; cur="$(qr "SELECT CONCAT(company_name,'  部门=',COALESCE(dept_name,'-'),'  sign=',COALESCE(company_sign,'-'),'  更新=',COALESCE(update_time,'-'))
                          FROM ubm_member_current WHERE member_id='$mid'")"
  if [ -n "$cur" ]; then printf '  %s\n' "$cur"
  else printf '  (ubm_member_current 里没有记录——多半是没登录，或退出时被 cleanCurrentCompany 清掉了；\n   页面右上角显示的才是准的)\n'; fi

  printf '\n— 专家身份（决定能不能进「我的工作台（专家）」）—\n'
  local prodb="scm_professor_${ENV_NAME}"
  local pro; pro="$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" --default-character-set=utf8mb4 -N -B "$prodb" -e \
    "SELECT CONCAT('专家库记录：', user_name,'  专家编号=',professor_code,
            '  类型=',IF(professor_type=1,'内部','外部'),
            '  状态=',IF(enable_status=1,'启用','停用'),'  pro_id=',pro_id)
       FROM pro_professor WHERE member_id='$mid' AND delete_sign=0" 2>/dev/null)"
  [ -n "$pro" ] && printf '  %s\n' "$pro" || printf '  ✗ 不在专家库（%s.pro_professor）里\n' "$prodb"

  local zj; zj="$(qr "SELECT CONCAT('  ✓ 在【',company_name,'】挂着岗位【',job_name,'】')
                        FROM ubm_member_job WHERE member_id='$mid' AND delete_sign=0 AND job_name LIKE '%专家%'")"
  if [ -n "$zj" ]; then
    printf '  能看到专家门户菜单的公司：\n%s\n' "$zj"
    printf '  → 想进专家工作台，先把公司切到上面任意一家，再开 /bidEvaluationt/index.html\n'
  else
    printf '  ✗ 没有任何公司挂着「专家」岗位 —— 即使在专家库里，登录后也看不到专家门户菜单。\n'
    printf '    要找管理员在某家公司给这个账号加「专家」岗位。\n'
  fi
}

# 角色编码在后端代码里被硬编码判断的地方（改角色前必看）
cmd_codeuse() {
  local kw="${1:?用法: perm.sh codeuse <角色关键词或角色编码>}"
  header
  local codes
  if [[ "$kw" =~ ^ROLE_ ]]; then codes="$kw"; else
    codes="$(qr "SELECT DISTINCT role_code FROM ubm_rbac_role WHERE role_name LIKE '%$(esc "$kw")%'")"
  fi
  [ -n "$codes" ] || { echo "没找到匹配的角色"; return 0; }
  printf '匹配到角色编码：\n%s\n\n后端代码里硬编码引用这些编码的地方：\n' "$codes"
  local c hit=0
  while read -r c; do
    [ -n "$c" ] || continue
    local out
    out="$(grep -rn --include='*.java' -- "$c" "$ROOT/01zhaocai-end" 2>/dev/null | sed "s|$ROOT/||" | head -20)"
    if [ -n "$out" ]; then hit=1; printf '\n[%s]\n%s\n' "$c" "$out"; fi
  done <<< "$codes"
  [ "$hit" = "1" ] || printf '（没有硬编码引用——这个角色纯靠菜单授权生效）\n'
}

cmd_help() {
cat <<'HELP'
perm.sh —— 账号 / 公司 / 岗位 / 角色 / 菜单 速查

  权限模型（关键：岗位是【按公司】挂的，所以切公司会换掉整套菜单）
      用户 --(ubm_member_job, 带 company_id)--> 岗位
           --(ubm_job_role)--> 角色
           --(ubm_rbac_role_menu)--> 菜单
      查这几张表【必须带 delete_sign=0】，=1 的是历史版本，不带条件会捞出几年前作废的配置。

  用法：bash scripts/perm.sh <子命令> [参数] [--env test|uat] [--sql]
        默认 --env uat（真实岗位/角色配置在 uat；test 的 rbac 表有大量历史脏行）

  accounts                        creds.env 里配了哪些业务账号，各是谁、几家公司、几个岗位
  companies <别名> [公司关键词]     这个账号能切到哪些公司，每家挂了什么岗位
  jobs      <别名> [公司关键词]     按公司列岗位（含岗位适用层级 JT/GS/QY/BS）
  roles     <别名> [公司关键词]     按公司列角色
  menus     <别名> <公司关键词> [菜单关键词]
                                  这个账号在这家公司实际能看到的菜单 + 菜单来自哪个角色
  can       <菜单关键词>            ★ 要点这个菜单，用哪个账号切到哪家公司
  whichrole <菜单关键词>            这个菜单需要什么角色、这些角色挂在哪些岗位上（找业务要权限时用）
  role      <角色关键词>            这个角色能看到哪些菜单
  job       <岗位关键词>            这个岗位带哪些角色
  codeuse   <角色关键词/编码>       后端 Java 里硬编码判断这个角色的地方（改权限前必看）
  now       [别名]                  当前停在哪家公司 + 专家身份体检（能不能进专家门户）
  supplier  [别名] [采购单位关键词]  供应商体检：入网/黑名单/冻结/服务关系，以及能不能对某采购单位投标
  cover                           ★ 招采主流程 13 棒逐条体检，直接列出"还缺什么角色"

  例：
    bash scripts/perm.sh accounts
    bash scripts/perm.sh can 采购方案编制
    bash scripts/perm.sh companies admin 盾石
    bash scripts/perm.sh menus admin 盾石建筑 审批
    bash scripts/perm.sh cover
    bash scripts/perm.sh whichrole 定标方案审批

  加账号：往 ai-docs/creds.env 加 SCM_<别名大写>_USER / SCM_<别名大写>_PASS 两行即可，
          本脚本自动发现，不用改代码。
  红线：本脚本不打印密码/token，登录名一律打码。要真实登录名自己看 creds.env。
HELP
}

case "$CMD" in
  accounts)  cmd_accounts "$@" ;;
  companies) cmd_companies "$@" ;;
  jobs)      cmd_jobs "$@" ;;
  roles)     cmd_roles "$@" ;;
  menus)     cmd_menus "$@" ;;
  can)       cmd_can "$@" ;;
  whichrole) cmd_whichrole "$@" ;;
  role)      cmd_role "$@" ;;
  job)       cmd_job "$@" ;;
  codeuse)   cmd_codeuse "$@" ;;
  now)       cmd_now "$@" ;;
  supplier)  cmd_supplier "$@" ;;
  cover)     cmd_cover "$@" ;;
  help|*)    cmd_help ;;
esac
