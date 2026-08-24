#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POWERSHELL_SOURCE="$ROOT_DIR/scripts/windows-cloudflare-one.ps1"

usage() {
  cat <<'EOF'
用法：
  bash scripts/windows-cloudflare-one.sh doctor
  bash scripts/windows-cloudflare-one.sh ssh-config
  bash scripts/windows-cloudflare-one.sh setup
  bash scripts/windows-cloudflare-one.sh verify
  bash scripts/windows-cloudflare-one.sh connect
  bash scripts/windows-cloudflare-one.sh disconnect

命令：
  doctor      只读检查 Windows、WSL、Clash、路由与客户端状态
  ssh-config  配置 Windows/VS Code 使用的 home-mac 别名，并复用已有 SSH 密钥
  setup       明天在公司电脑执行的主入口：留基线 → SSH别名 → 安装 → 浏览器验证码注册 → 验收
  verify      重跑 Windows + WSL + SSH端口 + Home Assistant + 路由器 + 公网验收
  connect     重新连接 Cloudflare One Client
  disconnect  最快止损；断开 Cloudflare One Client，不删注册和云端配置

客户端缺失时 setup 会弹一次 Windows UAC；这台电脑今晚已经装好，明天正常不会再弹。
注册时会打开浏览器，要求本人完成 Cloudflare 邮箱验证码。
脚本在家庭 192.168.5.0/24 内会拒绝注册和最终验收，防止把局域网直连误判为成功。
EOF
}

if (( $# != 1 )); then
  usage >&2
  exit 2
fi

case "$1" in
  doctor|ssh-config|setup|verify|connect|disconnect) action="$1" ;;
  -h|--help) usage; exit 0 ;;
  *)
    echo "未知命令：$1" >&2
    usage >&2
    exit 2
    ;;
esac

if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
  echo "这个入口需要在目标 Windows 的 WSL 里运行。" >&2
  echo "如果直接使用 Windows PowerShell，请运行 scripts/windows-cloudflare-one.ps1。" >&2
  exit 1
fi

windows_temp="$(cmd.exe /d /c echo %TEMP% 2>/dev/null | tr -d '\r' | tail -n 1)"
if [[ ! "$windows_temp" =~ ^[A-Za-z]:\\ ]]; then
  echo "无法解析 Windows TEMP：$windows_temp" >&2
  exit 1
fi
wsl_temp="$(wslpath -u "$windows_temp")"
mkdir -p "$wsl_temp"
working_copy="$wsl_temp/codex-windows-cloudflare-one.ps1"
cp "$POWERSHELL_SOURCE" "$working_copy"
windows_script="$(wslpath -w "$working_copy")"

run_action() {
  local powershell_action="$1"
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$windows_script" -Action "$powershell_action"
}

case "$action" in
  doctor)
    run_action Doctor
    ;;
  ssh-config)
    run_action SshConfig
    ;;
  setup)
    echo "第 1/5 步：保存启用 WARP 前的路由、DNS、Clash 基线（只存 Windows 本机）。"
    run_action Baseline
    echo "第 2/5 步：配置 Windows 和 VS Code 使用的 home-mac SSH 别名。"
    run_action SshConfig
    echo "第 3/5 步：下载 Cloudflare 官方最新稳定版、验签并安装。"
    run_action Install
    echo "第 4/5 步：打开浏览器，注册到家庭 Zero Trust 组织。"
    run_action Enroll
    echo "第 5/5 步：自动验收 Windows、WSL、SSH 登录、家庭服务和非目标流量。"
    run_action Verify
    ;;
  verify)
    run_action Verify
    ;;
  connect)
    run_action Connect
    ;;
  disconnect)
    run_action Disconnect
    ;;
esac
