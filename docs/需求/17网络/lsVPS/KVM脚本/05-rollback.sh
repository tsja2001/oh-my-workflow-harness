#!/usr/bin/env bash
set -euo pipefail

UNIT=cloudflared-la-vps-admin.service
UNIT_PATH=/etc/systemd/system/$UNIT
TOKEN_FILE=/etc/cloudflared-la-vps-admin/token

[[ $(id -u) -eq 0 ]] || { echo 'STOP: must run as root'; exit 1; }
[[ -r /root/la-vps-admin-last-backup.txt ]] || { echo 'STOP: backup pointer missing'; exit 1; }
BACKUP_DIR=$(</root/la-vps-admin-last-backup.txt)
[[ -d $BACKUP_DIR ]] || { echo 'STOP: backup directory missing'; exit 1; }

systemctl disable --now "$UNIT" >/dev/null 2>&1 || true

if [[ -f $UNIT_PATH ]]; then
  mv "$UNIT_PATH" "$BACKUP_DIR/$UNIT.rolled-back-$(date +%Y%m%d-%H%M%S)"
fi
if [[ -f $TOKEN_FILE ]]; then
  mv "$TOKEN_FILE" "$BACKUP_DIR/token.rolled-back-$(date +%Y%m%d-%H%M%S)"
  chmod 600 "$BACKUP_DIR"/token.rolled-back-*
fi

systemctl daemon-reload
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true
echo ROLLBACK_OK

