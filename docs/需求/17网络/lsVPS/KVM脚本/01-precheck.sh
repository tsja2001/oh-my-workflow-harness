#!/usr/bin/env bash
set -euo pipefail

[[ $(id -u) -eq 0 ]] || { echo 'STOP: must run as root'; exit 1; }

echo '=== system ==='
. /etc/os-release
printf 'os=%s version=%s arch=%s\n' "$ID" "$VERSION_ID" "$(uname -m)"
df -h /
df -i /

echo '=== cloudflared ==='
/usr/local/bin/cloudflared --version
[[ -x /usr/local/lib/cloudflared-la-vps/cloudflared ]] \
  && /usr/local/lib/cloudflared-la-vps/cloudflared --version \
  || echo 'isolated_binary=missing'

echo '=== ssh loopback ==='
SSH_BANNER=$(timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/22; IFS= read -r x <&3; printf %s "$x"' || true)
[[ $SSH_BANNER == SSH-* ]] || { echo 'STOP: localhost:22 unavailable'; exit 1; }
printf 'ssh_loopback=%s\n' "$SSH_BANNER"

echo '=== existing new-service files ==='
[[ -f /etc/cloudflared-la-vps-admin/token ]] \
  && printf 'token_bytes=%s mode=%s owner=%s\n' \
       "$(wc -c < /etc/cloudflared-la-vps-admin/token)" \
       "$(stat -c %a /etc/cloudflared-la-vps-admin/token)" \
       "$(stat -c %U:%G /etc/cloudflared-la-vps-admin/token)" \
  || echo 'token_file=missing'
systemctl show cloudflared-la-vps-admin.service \
  -p LoadState -p ActiveState -p SubState -p MainPID 2>/dev/null || true

echo PRECHECK_OK

