#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_FILE="${SCRIPT_DIR}/la-vps-admin-setup-v2.sh"
REMOTE_FILE='/root/la-vps-admin-setup-v2.sh'

[[ -f $SOURCE_FILE ]] || { echo "STOP: source missing: $SOURCE_FILE" >&2; exit 1; }
bash -n "$SOURCE_FILE"

SOURCE_HASH=$(sha256sum "$SOURCE_FILE" | awk '{print $1}')
PAYLOAD=$(gzip -9n -c "$SOURCE_FILE" | base64 -w0)

printf "printf '%%s' '%s' | base64 -d | gzip -dc > /root/.la-vps-admin-setup-v2.sh.tmp && chmod 700 /root/.la-vps-admin-setup-v2.sh.tmp && mv -f /root/.la-vps-admin-setup-v2.sh.tmp %s && echo '%s  %s' | sha256sum -c - && echo SCRIPT_FIX_CREATE_OK\n" \
  "$PAYLOAD" "$REMOTE_FILE" "$SOURCE_HASH" "$REMOTE_FILE"

