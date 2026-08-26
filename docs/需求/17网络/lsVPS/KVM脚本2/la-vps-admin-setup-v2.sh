#!/usr/bin/env bash
set -Eeuo pipefail

readonly UNIT='cloudflared-la-vps-admin.service'
readonly UNIT_PATH="/etc/systemd/system/${UNIT}"
readonly SOURCE_BIN='/usr/local/bin/cloudflared'
readonly TARGET_DIR='/usr/local/lib/cloudflared-la-vps'
readonly TARGET_BIN="${TARGET_DIR}/cloudflared"
readonly SERVICE_USER='cloudflared-la-vps'
readonly SERVICE_GROUP='cloudflared-la-vps'
readonly TOKEN_DIR='/etc/cloudflared-la-vps-admin'
readonly TOKEN_FILE="${TOKEN_DIR}/token"
readonly LAST_BACKUP='/root/la-vps-admin-v2-last-backup.txt'

MODE="${1:-apply}"
BACKUP_DIR=''
TOKEN_TMP=''
UNIT_TMP=''
CF_TUNNEL_TOKEN=''
MUTATION_STARTED=0
COMPLETED=0

redact() {
  sed -E \
    -e 's/(--token(=|[[:space:]]+))[^[:space:]]+/\1[TOKEN-REDACTED]/g' \
    -e 's/eyJ[A-Za-z0-9._=-]+/[TOKEN-REDACTED]/g'
}

cleanup_temporary_files() {
  if [[ -n ${TOKEN_TMP:-} && -e $TOKEN_TMP ]]; then
    rm -f -- "$TOKEN_TMP"
  fi
  if [[ -n ${UNIT_TMP:-} && -e $UNIT_TMP ]]; then
    rm -f -- "$UNIT_TMP"
  fi
  TOKEN_TMP=''
  UNIT_TMP=''
  CF_TUNNEL_TOKEN=''
}

die() {
  echo "STOP: $*" >&2
  exit 1
}

require_root() {
  [[ $(id -u) -eq 0 ]] || die 'must run as root'
}

supports_token_file() {
  local binary=$1 help_output
  help_output=$("$binary" tunnel run --help 2>&1 || true)
  grep -- '--token-file' <<<"$help_output" >/dev/null
}

show_cloudflared_units() {
  echo '--- installed cloudflared units ---'
  systemctl list-unit-files --type=service --no-legend 2>/dev/null \
    | awk 'tolower($1) ~ /cloudflared/ {print $1, $2}' || true
  echo '--- running cloudflared units ---'
  systemctl list-units --all --type=service --no-legend 2>/dev/null \
    | awk 'tolower($1) ~ /cloudflared/ {print $1, $3, $4}' || true
}

show_status() {
  require_root
  echo '=== la-vps-admin status ==='
  if [[ -f $TOKEN_FILE ]]; then
    printf 'token_file=%s bytes=%s mode=%s owner=%s\n' \
      "$TOKEN_FILE" \
      "$(wc -c < "$TOKEN_FILE")" \
      "$(stat -c '%a' "$TOKEN_FILE")" \
      "$(stat -c '%U:%G' "$TOKEN_FILE")"
  else
    echo 'token_file=missing'
  fi

  systemctl show "$UNIT" \
    -p LoadState -p UnitFileState -p ActiveState -p SubState \
    -p MainPID -p FragmentPath 2>/dev/null || true
  journalctl -u "$UNIT" -n 50 --no-pager 2>/dev/null | redact || true
  show_cloudflared_units
  if [[ -r $LAST_BACKUP ]]; then
    printf 'last_backup=%s\n' "$(<"$LAST_BACKUP")"
  fi
}

precheck() {
  require_root
  command -v systemctl >/dev/null 2>&1 || die 'systemctl not found'
  command -v systemd-analyze >/dev/null 2>&1 || die 'systemd-analyze not found'
  command -v timeout >/dev/null 2>&1 || die 'timeout not found'
  command -v sshd >/dev/null 2>&1 || die 'sshd not found'
  [[ -x $SOURCE_BIN ]] || die "$SOURCE_BIN missing or not executable"

  supports_token_file "$SOURCE_BIN" \
    || die "$SOURCE_BIN does not support --token-file"

  local ssh_banner sshd_bin
  sshd_bin=$(command -v sshd)
  ssh_banner=$(timeout 5 bash -c \
    'exec 3<>/dev/tcp/127.0.0.1/22; IFS= read -r x <&3; printf %s "$x"' \
    || true)
  [[ $ssh_banner == SSH-* ]] || die 'localhost:22 is unavailable'

  echo '=== precheck ==='
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf 'os=%s version=%s arch=%s\n' \
      "${ID:-unknown}" "${VERSION_ID:-unknown}" "$(uname -m)"
  fi
  "$SOURCE_BIN" --version
  printf 'ssh_loopback=%s\n' "$ssh_banner"
  "$sshd_bin" -T 2>/dev/null \
    | awk '$1 ~ /^(port|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin)$/ {print}'
  show_cloudflared_units
  echo PRECHECK_OK
}

prompt_for_token() {
  [[ -r /dev/tty ]] || die '/dev/tty is unavailable; run from KiwiVM Interactive'
  printf '\nPaste only the full eyJ... Tunnel Token, then press Enter.\n' >/dev/tty
  printf 'Token will not be displayed: ' >/dev/tty
  if ! IFS= read -r -s CF_TUNNEL_TOKEN </dev/tty; then
    printf '\n' >/dev/tty
    die 'token input was cancelled'
  fi
  printf '\n' >/dev/tty
  CF_TUNNEL_TOKEN=${CF_TUNNEL_TOKEN%$'\r'}

  [[ $CF_TUNNEL_TOKEN == eyJ* ]] || die 'token must start with eyJ'
  [[ ${#CF_TUNNEL_TOKEN} -ge 100 ]] || die 'token is too short'
  [[ $CF_TUNNEL_TOKEN =~ ^[A-Za-z0-9._=-]+$ ]] \
    || die 'token contains unexpected characters; paste only the token'
  echo 'token_format=accepted token_value=not_displayed'
}

create_backup() {
  BACKUP_DIR="/root/la-vps-admin-backup-v2-$(date +%Y%m%d-%H%M%S)"
  install -d -m 0700 "$BACKUP_DIR"

  local unit_existed=0 token_existed=0 target_existed=0
  local unit_was_active=0 unit_was_enabled=0

  if [[ -e $UNIT_PATH ]]; then
    cp -a "$UNIT_PATH" "$BACKUP_DIR/unit.before"
    unit_existed=1
  fi
  if [[ -e $TOKEN_FILE ]]; then
    cp -a "$TOKEN_FILE" "$BACKUP_DIR/token.before"
    token_existed=1
  fi
  if [[ -e $TARGET_BIN ]]; then
    cp -a "$TARGET_BIN" "$BACKUP_DIR/cloudflared.before"
    target_existed=1
  fi
  if systemctl is-active --quiet "$UNIT"; then
    unit_was_active=1
  fi
  if systemctl is-enabled --quiet "$UNIT" 2>/dev/null; then
    unit_was_enabled=1
  fi

  {
    printf 'UNIT_EXISTED=%q\n' "$unit_existed"
    printf 'TOKEN_EXISTED=%q\n' "$token_existed"
    printf 'TARGET_EXISTED=%q\n' "$target_existed"
    printf 'UNIT_WAS_ACTIVE=%q\n' "$unit_was_active"
    printf 'UNIT_WAS_ENABLED=%q\n' "$unit_was_enabled"
  } > "$BACKUP_DIR/state.env"
  chmod 0600 "$BACKUP_DIR/state.env"

  show_cloudflared_units > "$BACKUP_DIR/cloudflared-units.before.txt"
  chmod 0600 "$BACKUP_DIR/cloudflared-units.before.txt"
  printf '%s\n' "$BACKUP_DIR" > "$LAST_BACKUP"
  chmod 0600 "$LAST_BACKUP"
  printf 'backup=%s\n' "$BACKUP_DIR"
}

load_backup_state() {
  local requested_backup=$1
  [[ $requested_backup == /root/la-vps-admin-backup-v2-* ]] \
    || die 'backup path is outside the expected scope'
  [[ -d $requested_backup && -r $requested_backup/state.env ]] \
    || die "backup is missing or incomplete: $requested_backup"
  [[ $(stat -c '%U' "$requested_backup") == root ]] \
    || die 'backup owner is not root'
  # shellcheck disable=SC1090
  . "$requested_backup/state.env"
}

restore_backup() {
  local requested_backup=$1
  local reason=${2:-manual}
  load_backup_state "$requested_backup"

  echo "=== restoring la-vps-admin only (${reason}) ==="
  systemctl disable --now "$UNIT" >/dev/null 2>&1 || true

  if [[ $UNIT_EXISTED == 1 ]]; then
    cp -a "$requested_backup/unit.before" "$UNIT_PATH"
  else
    rm -f -- "$UNIT_PATH"
  fi
  if [[ $TOKEN_EXISTED == 1 ]]; then
    install -d -m 0750 "$TOKEN_DIR"
    cp -a "$requested_backup/token.before" "$TOKEN_FILE"
  else
    rm -f -- "$TOKEN_FILE"
  fi
  if [[ $TARGET_EXISTED == 1 ]]; then
    install -d -m 0755 "$TARGET_DIR"
    cp -a "$requested_backup/cloudflared.before" "$TARGET_BIN"
  else
    rm -f -- "$TARGET_BIN"
  fi

  systemctl daemon-reload
  if [[ $UNIT_WAS_ENABLED == 1 ]]; then
    systemctl enable "$UNIT" >/dev/null 2>&1 || true
  else
    systemctl disable "$UNIT" >/dev/null 2>&1 || true
  fi
  if [[ $UNIT_WAS_ACTIVE == 1 ]]; then
    systemctl start "$UNIT"
  else
    systemctl stop "$UNIT" >/dev/null 2>&1 || true
  fi
  echo ROLLBACK_OK
}

on_error() {
  local rc=$?
  local line=${BASH_LINENO[0]:-unknown}
  trap - ERR
  set +e
  cleanup_temporary_files
  echo "STOP: setup failed at line ${line}, exit=${rc}" >&2
  if [[ $MUTATION_STARTED == 1 && $COMPLETED == 0 && -n $BACKUP_DIR ]]; then
    restore_backup "$BACKUP_DIR" automatic
    echo 'AUTO_ROLLBACK_OK: old saturate/SSH/firewall/DNS were not touched'
  fi
  exit "$rc"
}

on_signal() {
  local signal_name=$1
  trap - ERR INT TERM
  set +e
  cleanup_temporary_files
  echo "STOP: setup interrupted by ${signal_name}" >&2
  if [[ $MUTATION_STARTED == 1 && $COMPLETED == 0 && -n $BACKUP_DIR ]]; then
    restore_backup "$BACKUP_DIR" "signal-${signal_name}"
    echo 'AUTO_ROLLBACK_OK: old saturate/SSH/firewall/DNS were not touched'
  fi
  exit 130
}

ensure_isolated_binary() {
  install -d -m 0755 "$TARGET_DIR"
  if [[ -x $TARGET_BIN ]] \
    && supports_token_file "$TARGET_BIN"; then
    echo 'isolated_binary=kept_existing_supported_copy'
  else
    install -m 0755 "$SOURCE_BIN" "$TARGET_BIN"
    echo 'isolated_binary=copied_from_/usr/local/bin/cloudflared'
  fi
  "$TARGET_BIN" --version
  supports_token_file "$TARGET_BIN" \
    || return 1
}

ensure_service_account() {
  getent group "$SERVICE_GROUP" >/dev/null \
    || groupadd --system "$SERVICE_GROUP"
  if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    local nologin_shell
    nologin_shell=$(command -v nologin || printf '/usr/sbin/nologin')
    useradd --system --gid "$SERVICE_GROUP" --home-dir /nonexistent \
      --shell "$nologin_shell" "$SERVICE_USER"
  fi
  install -d -m 0750 -o root -g "$SERVICE_GROUP" "$TOKEN_DIR"
}

write_token_file() {
  umask 077
  TOKEN_TMP=$(mktemp "${TOKEN_DIR}/.token.tmp.XXXXXX")
  printf '%s\n' "$CF_TUNNEL_TOKEN" > "$TOKEN_TMP"
  CF_TUNNEL_TOKEN=''
  chown root:"$SERVICE_GROUP" "$TOKEN_TMP"
  chmod 0640 "$TOKEN_TMP"
  mv -f -- "$TOKEN_TMP" "$TOKEN_FILE"
  TOKEN_TMP=''
  printf 'token_file=%s bytes=%s mode=%s owner=%s\n' \
    "$TOKEN_FILE" \
    "$(wc -c < "$TOKEN_FILE")" \
    "$(stat -c '%a' "$TOKEN_FILE")" \
    "$(stat -c '%U:%G' "$TOKEN_FILE")"
}

write_unit_file() {
  UNIT_TMP=$(mktemp '/etc/systemd/system/.cloudflared-la-vps-admin.service.tmp.XXXXXX')
  cat > "$UNIT_TMP" <<'UNITFILE'
[Unit]
Description=Cloudflare Tunnel - LA VPS Admin SSH
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
User=cloudflared-la-vps
Group=cloudflared-la-vps
ExecStart=/usr/local/lib/cloudflared-la-vps/cloudflared tunnel --no-autoupdate --loglevel info run --token-file /etc/cloudflared-la-vps-admin/token
Restart=on-failure
RestartSec=5s
TimeoutStartSec=0
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
UNITFILE
  chmod 0644 "$UNIT_TMP"
  mv -f -- "$UNIT_TMP" "$UNIT_PATH"
  UNIT_TMP=''
  systemd-analyze verify "$UNIT_PATH"
}

start_and_verify() {
  local start_time registered=0
  start_time=$(date '+%Y-%m-%d %H:%M:%S')
  systemctl daemon-reload
  systemctl enable "$UNIT" >/dev/null
  systemctl restart "$UNIT"

  for _ in $(seq 1 15); do
    if systemctl is-active --quiet "$UNIT" \
      && journalctl -u "$UNIT" --since "$start_time" --no-pager 2>/dev/null \
        | grep 'Registered tunnel connection' >/dev/null; then
      registered=1
      break
    fi
    sleep 2
  done

  if ! systemctl is-active --quiet "$UNIT" || [[ $registered != 1 ]]; then
    echo '=== failed service evidence (redacted) ===' >&2
    systemctl show "$UNIT" \
      -p LoadState -p UnitFileState -p ActiveState -p SubState \
      -p MainPID -p FragmentPath >&2 || true
    journalctl -u "$UNIT" --since "$start_time" -n 80 --no-pager 2>/dev/null \
      | redact >&2 || true
    return 1
  fi

  COMPLETED=1
  echo '=== successful service evidence (redacted) ==='
  systemctl show "$UNIT" \
    -p LoadState -p UnitFileState -p ActiveState -p SubState \
    -p MainPID -p FragmentPath
  journalctl -u "$UNIT" --since "$start_time" -n 40 --no-pager 2>/dev/null \
    | redact || true
  show_cloudflared_units
  echo CONNECTOR_INSTALL_OK
  echo 'NEXT: send this redacted output to Codex; do not publish DNS/SSH Route yet.'
}

apply_setup() {
  trap on_error ERR
  trap 'on_signal INT' INT
  trap 'on_signal TERM' TERM
  precheck
  prompt_for_token
  create_backup
  MUTATION_STARTED=1
  ensure_isolated_binary
  ensure_service_account
  write_token_file
  write_unit_file
  start_and_verify
  cleanup_temporary_files
}

rollback_latest() {
  require_root
  [[ -r $LAST_BACKUP ]] || die "$LAST_BACKUP not found"
  BACKUP_DIR=$(<"$LAST_BACKUP")
  restore_backup "$BACKUP_DIR" manual
  show_status
}

case "$MODE" in
  apply) apply_setup ;;
  status) show_status ;;
  rollback) rollback_latest ;;
  *) die 'usage: bash la-vps-admin-setup-v2.sh [apply|status|rollback]' ;;
esac
