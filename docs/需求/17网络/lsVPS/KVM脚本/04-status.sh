#!/usr/bin/env bash
set -euo pipefail

UNIT=cloudflared-la-vps-admin.service
TOKEN_FILE=/etc/cloudflared-la-vps-admin/token

[[ $(id -u) -eq 0 ]] || { echo 'STOP: must run as root'; exit 1; }

[[ -f $TOKEN_FILE ]] \
  && printf 'token_bytes=%s mode=%s owner=%s\n' \
       "$(wc -c < "$TOKEN_FILE")" \
       "$(stat -c %a "$TOKEN_FILE")" \
       "$(stat -c %U:%G "$TOKEN_FILE")" \
  || echo 'token_file=missing'

systemctl show "$UNIT" \
  -p LoadState -p UnitFileState -p ActiveState -p SubState -p MainPID -p FragmentPath
journalctl -u "$UNIT" -n 40 --no-pager \
  | sed -E 's/eyJ[A-Za-z0-9._=-]+/[TOKEN-REDACTED]/g'

