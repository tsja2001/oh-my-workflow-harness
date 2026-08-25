#!/usr/bin/env bash
set -euo pipefail

UNIT=cloudflared-la-vps-admin.service
UNIT_PATH=/etc/systemd/system/$UNIT
SOURCE=/usr/local/bin/cloudflared
TARGET=/usr/local/lib/cloudflared-la-vps/cloudflared

[[ $(id -u) -eq 0 ]] || { echo 'STOP: must run as root'; exit 1; }
[[ -x $SOURCE ]] || { echo 'STOP: cloudflared missing'; exit 1; }

if [[ -r /root/la-vps-admin-last-backup.txt ]] \
  && [[ -d $(</root/la-vps-admin-last-backup.txt) ]]; then
  BACKUP_DIR=$(</root/la-vps-admin-last-backup.txt)
else
  BACKUP_DIR=/root/la-vps-admin-backup-$(date +%Y%m%d-%H%M%S)
  install -d -m 700 "$BACKUP_DIR"
  cp -a --parents /etc/ssh "$SOURCE" "$BACKUP_DIR"
  printf '%s\n' "$BACKUP_DIR" > /root/la-vps-admin-last-backup.txt
  chmod 600 /root/la-vps-admin-last-backup.txt
fi
printf 'backup=%s\n' "$BACKUP_DIR"

install -d -m 755 /usr/local/lib/cloudflared-la-vps
[[ -x $TARGET ]] || install -m 0755 "$SOURCE" "$TARGET"

getent group cloudflared-la-vps >/dev/null \
  || groupadd --system cloudflared-la-vps
id cloudflared-la-vps >/dev/null 2>&1 \
  || useradd --system --gid cloudflared-la-vps --home-dir /nonexistent \
       --shell /usr/sbin/nologin cloudflared-la-vps
install -d -m 0750 -o root -g cloudflared-la-vps /etc/cloudflared-la-vps-admin

if [[ -f $UNIT_PATH ]]; then
  cp -a "$UNIT_PATH" "$BACKUP_DIR/$UNIT.before-fix-$(date +%Y%m%d-%H%M%S)"
fi
systemctl disable --now "$UNIT" >/dev/null 2>&1 || true

printf '%s\n' \
  '[Unit]' \
  'Description=Cloudflare Tunnel - LA VPS Admin SSH' \
  'Wants=network-online.target' \
  'After=network-online.target' \
  '' \
  '[Service]' \
  'Type=notify' \
  'User=cloudflared-la-vps' \
  'Group=cloudflared-la-vps' \
  'ExecStart=/usr/local/lib/cloudflared-la-vps/cloudflared tunnel --no-autoupdate --loglevel info run --token-file /etc/cloudflared-la-vps-admin/token' \
  'Restart=on-failure' \
  'RestartSec=5s' \
  'TimeoutStartSec=0' \
  'UMask=0077' \
  'NoNewPrivileges=true' \
  'PrivateTmp=true' \
  'ProtectSystem=strict' \
  'ProtectHome=true' \
  '' \
  '[Install]' \
  'WantedBy=multi-user.target' > "$UNIT_PATH"

chmod 0644 "$UNIT_PATH"
systemd-analyze verify "$UNIT_PATH"
systemctl daemon-reload
echo PREPARE_OK

