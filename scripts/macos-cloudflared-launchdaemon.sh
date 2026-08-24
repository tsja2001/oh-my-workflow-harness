#!/usr/bin/env bash

set -Eeuo pipefail

LABEL='com.cloudflare.cloudflared'
STATE_ROOT='/Library/Application Support/codex-cloudflared-migration'
POINTER_FILE="$STATE_ROOT/last-backup.txt"

usage() {
  cat <<'EOF'
用法：
  bash scripts/macos-cloudflared-launchdaemon.sh status [macOS用户名]
  sudo bash scripts/macos-cloudflared-launchdaemon.sh apply [macOS用户名]
  sudo bash scripts/macos-cloudflared-launchdaemon.sh resume [macOS用户名]
  sudo bash scripts/macos-cloudflared-launchdaemon.sh rollback [macOS用户名]

用途：
  status    只读检查 cloudflared 用户 LaunchAgent、系统 LaunchDaemon 和 Token 文件状态
  apply     备份后将现有用户 LaunchAgent 迁为开机系统 LaunchDaemon
  resume    系统服务已启动但 SSH 中断时，补备份指针并清理旧用户 plist
  rollback  读取上次备份，停用系统 LaunchDaemon 并恢复原用户 LaunchAgent

脚本只检查 Token 文件是否存在、非空且权限为 0600，不读取或输出 Token 内容。
EOF
}

if (( $# < 1 || $# > 2 )); then
  usage >&2
  exit 2
fi

case "$1" in
  status|apply|resume|rollback) action="$1" ;;
  -h|--help) usage; exit 0 ;;
  *)
    echo "未知命令：$1" >&2
    usage >&2
    exit 2
    ;;
esac

target_user="${2:-mac}"

if [[ "$(uname -s)" != 'Darwin' ]]; then
  echo '这个脚本只能在家里的 macOS 上运行。' >&2
  exit 1
fi

if ! id "$target_user" >/dev/null 2>&1; then
  echo "macOS 用户不存在：$target_user" >&2
  exit 1
fi

target_uid="$(id -u "$target_user")"
target_gid="$(id -g "$target_user")"
target_home="$(dscl . -read "/Users/$target_user" NFSHomeDirectory | awk '{print $2}')"

if [[ -z "$target_home" || ! -d "$target_home" ]]; then
  echo "无法确认用户主目录：$target_user" >&2
  exit 1
fi

user_plist="$target_home/Library/LaunchAgents/$LABEL.plist"
token_file="$target_home/Library/Application Support/$LABEL/token"
system_plist="/Library/LaunchDaemons/$LABEL.plist"
user_service="gui/$target_uid/$LABEL"
system_service="system/$LABEL"

service_loaded() {
  launchctl print "$1" >/dev/null 2>&1
}

token_mode() {
  stat -f '%Lp' "$token_file" 2>/dev/null || true
}

show_status() {
  echo "目标用户：$target_user（uid=$target_uid）"
  echo "用户 plist：$(if [[ -f "$user_plist" ]]; then echo 'present'; else echo 'missing'; fi)"
  echo "用户服务：$(if service_loaded "$user_service"; then echo 'loaded'; else echo 'not loaded'; fi)"
  echo "系统 plist：$(if [[ -f "$system_plist" ]]; then echo 'present'; else echo 'missing'; fi)"
  echo "系统服务：$(if service_loaded "$system_service"; then echo 'loaded'; else echo 'not loaded'; fi)"
  if [[ -s "$token_file" ]]; then
    echo "Token 文件：present, non-empty, mode=$(token_mode)（内容未读取）"
  else
    echo 'Token 文件：missing or empty'
  fi

  if service_loaded "$system_service"; then
    system_pid="$(launchctl print "$system_service" | awk '/^[[:space:]]*pid = / {print $3; exit}')"
    if [[ -n "${system_pid:-}" ]]; then
      system_owner="$(ps -o user= -p "$system_pid" | xargs)"
      echo "系统服务进程：pid=$system_pid, user=$system_owner"
    fi
  fi
}

require_root() {
  if (( EUID != 0 )); then
    echo '该动作需要 sudo；请在 Mac SSH 终端中输入管理员密码。' >&2
    exit 1
  fi
}

validate_source() {
  if [[ ! -f "$user_plist" ]]; then
    echo "找不到原用户服务：$user_plist" >&2
    exit 1
  fi
  if [[ ! -s "$token_file" ]]; then
    echo "Token 文件不存在或为空：$token_file" >&2
    exit 1
  fi
  if [[ "$(token_mode)" != '600' ]]; then
    echo "Token 文件权限不是 0600，拒绝迁移：mode=$(token_mode)" >&2
    exit 1
  fi
  if ! plutil -lint "$user_plist" >/dev/null; then
    echo "原用户 plist 校验失败：$user_plist" >&2
    exit 1
  fi

  plist_binary="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$user_plist")"
  plist_token_flag="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' "$user_plist")"
  plist_token_path="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:4' "$user_plist")"
  if [[ ! -x "$plist_binary" || "$plist_token_flag" != '--token-file' || "$plist_token_path" != "$token_file" ]]; then
    echo '原用户服务参数与已核实结构不一致，拒绝自动迁移。' >&2
    exit 1
  fi
}

restore_from_backup() {
  local backup_dir="$1"
  set +e
  if service_loaded "$system_service"; then
    launchctl bootout system "$system_plist" >/dev/null 2>&1
  fi
  if [[ -f "$system_plist" ]]; then
    rm -f "$system_plist"
  fi
  if [[ -f "$backup_dir/user-launchagent.plist" ]]; then
    install -o "$target_uid" -g "$target_gid" -m 0644 \
      "$backup_dir/user-launchagent.plist" "$user_plist"
    if ! service_loaded "$user_service"; then
      launchctl bootstrap "gui/$target_uid" "$user_plist" >/dev/null 2>&1
    fi
    launchctl kickstart -k "$user_service" >/dev/null 2>&1
  fi
  set -e
}

create_backup() {
  local timestamp backup_dir
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  backup_dir="$STATE_ROOT/backups/$timestamp"
  install -d -o root -g wheel -m 0700 "$STATE_ROOT"
  install -d -o root -g wheel -m 0700 "$STATE_ROOT/backups"
  install -d -o root -g wheel -m 0700 "$backup_dir"
  cp -p "$user_plist" "$backup_dir/user-launchagent.plist"
  if [[ -f "$system_plist" ]]; then
    cp -p "$system_plist" "$backup_dir/system-launchdaemon.plist"
  fi
  launchctl print "$user_service" >"$backup_dir/user-service-before.txt" 2>&1 || true
  launchctl print "$system_service" >"$backup_dir/system-service-before.txt" 2>&1 || true
  printf '%s\n' "$backup_dir"
}

schedule_user_bootout() {
  nohup /bin/sh -c "sleep 2; /bin/launchctl bootout 'gui/$target_uid' '$user_plist' >/dev/null 2>&1" \
    >/dev/null 2>&1 &
}

apply_migration() {
  require_root
  validate_source

  if [[ -e "$system_plist" ]] || service_loaded "$system_service"; then
    echo '系统 cloudflared 服务已经存在；拒绝覆盖，请先运行 status。' >&2
    exit 1
  fi

  backup_dir="$(create_backup)"

  temp_plist="$(mktemp -t codex-cloudflared-launchdaemon)"
  cp "$user_plist" "$temp_plist"
  /usr/libexec/PlistBuddy -c 'Set :StandardOutPath /Library/Logs/com.cloudflare.cloudflared.out.log' "$temp_plist"
  /usr/libexec/PlistBuddy -c 'Set :StandardErrorPath /Library/Logs/com.cloudflare.cloudflared.err.log' "$temp_plist"
  plutil -lint "$temp_plist" >/dev/null

  migration_succeeded=false
  system_ready=false
  cleanup_on_error() {
    exit_code=$?
    rm -f "${temp_plist:-}"
    if [[ "$migration_succeeded" != true ]]; then
      echo '迁移失败，正在恢复原用户 LaunchAgent。' >&2
      restore_from_backup "$backup_dir"
    fi
    exit "$exit_code"
  }
  trap cleanup_on_error ERR INT TERM

  install -o root -g wheel -m 0644 "$temp_plist" "$system_plist"
  rm -f "$temp_plist"
  launchctl bootstrap system "$system_plist"
  launchctl kickstart -k "$system_service"

  for _ in {1..20}; do
    if service_loaded "$system_service"; then
      system_pid="$(launchctl print "$system_service" | awk '/^[[:space:]]*pid = / {print $3; exit}')"
      if [[ -n "$system_pid" && "$(ps -o user= -p "$system_pid" | xargs)" == 'root' ]]; then
        system_ready=true
        break
      fi
    fi
    sleep 1
  done

  if [[ "$system_ready" != true ]]; then
    false
  fi

  printf '%s\n' "$backup_dir" >"$POINTER_FILE"
  chmod 0600 "$POINTER_FILE"
  rm -f "$user_plist"
  migration_succeeded=true
  trap - ERR INT TERM

  echo 'PASS  cloudflared 已迁移为 root 系统 LaunchDaemon。'
  echo "备份目录：$backup_dir"
  echo 'Token 内容未读取或输出，原 0600 Token 文件保留。'
  if service_loaded "$user_service"; then
    echo '旧用户服务将在 2 秒后退出；当前 SSH 可能短暂断开。'
    schedule_user_bootout
  fi
}

resume_migration() {
  require_root
  validate_source

  if [[ ! -f "$system_plist" ]] || ! service_loaded "$system_service"; then
    echo '系统 LaunchDaemon不存在或未加载，不能执行 resume。' >&2
    exit 1
  fi
  system_pid="$(launchctl print "$system_service" | awk '/^[[:space:]]*pid = / {print $3; exit}')"
  if [[ -z "$system_pid" || "$(ps -o user= -p "$system_pid" | xargs)" != 'root' ]]; then
    echo '系统 LaunchDaemon没有以 root 正常运行，不能执行 resume。' >&2
    exit 1
  fi

  backup_dir="$(create_backup)"
  printf '%s\n' "$backup_dir" >"$POINTER_FILE"
  chmod 0600 "$POINTER_FILE"
  rm -f "$user_plist"

  echo 'PASS  已补齐迁移备份指针并清理旧用户 plist。'
  echo "备份目录：$backup_dir"
  echo '系统 LaunchDaemon保持运行；Token 内容未读取或输出。'
  if service_loaded "$user_service"; then
    echo '旧用户服务将在 2 秒后退出；当前 SSH 可能短暂断开。'
    schedule_user_bootout
  fi
}

rollback_migration() {
  require_root
  if [[ ! -f "$POINTER_FILE" ]]; then
    echo "找不到备份指针：$POINTER_FILE" >&2
    exit 1
  fi
  backup_dir="$(<"$POINTER_FILE")"
  case "$backup_dir" in
    "$STATE_ROOT"/backups/*) ;;
    *)
      echo "备份路径不可信，拒绝回退：$backup_dir" >&2
      exit 1
      ;;
  esac
  if [[ ! -f "$backup_dir/user-launchagent.plist" ]]; then
    echo "备份不完整：$backup_dir" >&2
    exit 1
  fi

  restore_from_backup "$backup_dir"
  echo 'PASS  已停用系统 LaunchDaemon并恢复原用户 LaunchAgent。'
  echo "备份仍保留：$backup_dir"
  show_status
}

case "$action" in
  status) show_status ;;
  apply) apply_migration ;;
  resume) resume_migration ;;
  rollback) rollback_migration ;;
esac
