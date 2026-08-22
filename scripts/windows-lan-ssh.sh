#!/usr/bin/env bash

set -euo pipefail

action="${1:-status}"
case "$action" in
  apply|status|rollback) ;;
  *)
    echo "用法：bash scripts/windows-lan-ssh.sh apply|status|rollback" >&2
    exit 2
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
main_script="$script_dir/windows-lan-ssh.ps1"
launcher_script="$script_dir/windows-lan-ssh-launcher.ps1"

windows_temp="$(cd /mnt/c && cmd.exe /d /c echo %TEMP% 2>/dev/null | tr -d '\r' | tail -n 1)"
if [[ ! "$windows_temp" =~ ^[A-Za-z]:\\ ]]; then
  echo "无法解析 Windows TEMP：$windows_temp" >&2
  exit 1
fi
wsl_temp="$(wslpath -u "$windows_temp")"
mkdir -p "$wsl_temp"
cp "$main_script" "$wsl_temp/codex-windows-lan-ssh.ps1"
cp "$launcher_script" "$wsl_temp/codex-windows-lan-ssh-launcher.ps1"

launcher_windows="$(wslpath -w "$wsl_temp/codex-windows-lan-ssh-launcher.ps1")"
echo "即将请求 Windows UAC：动作=$action；端口=2222；网卡=WLAN；不会改 WSL NAT、Tailscale 或 Clash。"
(cd /mnt/c && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$launcher_windows" \
  -Action "${action^}" -Port 2222 -InterfaceAlias WLAN -WindowsUser 29455)

echo "Windows LAN SSH 动作完成：$action"
