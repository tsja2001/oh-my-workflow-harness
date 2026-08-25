#!/usr/bin/env bash
set -euo pipefail

# 只在 KiwiVM Advanced 中替换下方占位符，不要把真实 Token 保存回工作区。
TOKEN='__PASTE_FULL_EYJ_TOKEN_HERE__'
TOKEN_FILE=/etc/cloudflared-la-vps-admin/token
UNIT=cloudflared-la-vps-admin.service

[[ $(id -u) -eq 0 ]] || { echo 'STOP: must run as root'; exit 1; }
[[ $TOKEN == eyJ* ]] || { echo 'STOP: replace the token placeholder first'; exit 1; }
[[ ${#TOKEN} -ge 100 ]] || { echo 'STOP: token too short'; exit 1; }
[[ -f /etc/systemd/system/$UNIT ]] || { echo 'STOP: run 02 first'; exit 1; }

umask 077
printf '%s\n' "$TOKEN" > "$TOKEN_FILE"
TOKEN=''
chown root:cloudflared-la-vps "$TOKEN_FILE"
chmod 0640 "$TOKEN_FILE"
printf 'token_bytes=%s mode=%s owner=%s\n' \
  "$(wc -c < "$TOKEN_FILE")" \
  "$(stat -c %a "$TOKEN_FILE")" \
  "$(stat -c %U:%G "$TOKEN_FILE")"

SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || true)
if [[ $SCRIPT_PATH == /root/03-token-and-start.sh ]]; then
  rm -f -- "$SCRIPT_PATH"
  echo 'token_script_deleted=yes'
else
  echo "WARNING: delete the token script manually: $SCRIPT_PATH"
fi

systemctl daemon-reload
systemctl enable --now "$UNIT"
sleep 8

if ! systemctl is-active --quiet "$UNIT"; then
  echo 'STOP: service failed'
  systemctl disable --now "$UNIT" >/dev/null 2>&1 || true
  journalctl -u "$UNIT" -n 50 --no-pager \
    | sed -E 's/eyJ[A-Za-z0-9._=-]+/[TOKEN-REDACTED]/g'
  exit 1
fi

systemctl show "$UNIT" -p ActiveState -p SubState -p MainPID -p FragmentPath
journalctl -u "$UNIT" -n 20 --no-pager \
  | sed -E 's/eyJ[A-Za-z0-9._=-]+/[TOKEN-REDACTED]/g'
echo CONNECTOR_INSTALL_OK

