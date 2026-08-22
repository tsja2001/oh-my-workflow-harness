#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCH_SCRIPT="$ROOT_DIR/scripts/windows-trend-watch.ps1"
LAUNCHER_SCRIPT="$ROOT_DIR/scripts/windows-trend-watch-launcher.ps1"
WATCHDOG_SCRIPT="$ROOT_DIR/scripts/windows-trend-watch-watchdog.ps1"

duration_seconds=600
interval_seconds=2
full_packets=0
max_capture_mb=512
stop_requested=0

usage() {
  cat <<'EOF'
用法：
  bash scripts/windows-trend-watch.sh [选项]

选项：
  --minutes N       观察 N 分钟，1～240；默认 10
  --seconds N       观察 N 秒，60～14400
  --interval N      元数据轮询间隔秒数，1～30；默认 2
  --full-packets    使用 Windows Pktmon 抓取网卡层完整数据包并转为 PCAPNG
  --max-mb N        抓包循环文件上限 MB，64～4096；默认 512
  --stop            请求当前观察任务提前结束并自动收尾
  -h, --help        显示帮助

示例：
  bash scripts/windows-trend-watch.sh --minutes 10
  bash scripts/windows-trend-watch.sh --minutes 30 --full-packets --max-mb 1024
  bash scripts/windows-trend-watch.sh --stop

脚本会触发一次 Windows UAC。默认不抓包；完整抓包只在显式传
--full-packets 时开启。结果保存在 Windows %TEMP%\codex-trend-watch-*。
EOF
}

require_integer() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "$name 必须是整数：$value" >&2
    exit 2
  fi
}

while (( $# > 0 )); do
  case "$1" in
    --minutes)
      [[ $# -ge 2 ]] || { echo "--minutes 缺少数值" >&2; exit 2; }
      require_integer "--minutes" "$2"
      (( 10#$2 >= 1 && 10#$2 <= 240 )) || { echo "--minutes 范围是 1～240" >&2; exit 2; }
      duration_seconds=$((10#$2 * 60))
      shift 2
      ;;
    --seconds)
      [[ $# -ge 2 ]] || { echo "--seconds 缺少数值" >&2; exit 2; }
      require_integer "--seconds" "$2"
      (( 10#$2 >= 60 && 10#$2 <= 14400 )) || { echo "--seconds 范围是 60～14400" >&2; exit 2; }
      duration_seconds=$((10#$2))
      shift 2
      ;;
    --interval)
      [[ $# -ge 2 ]] || { echo "--interval 缺少数值" >&2; exit 2; }
      require_integer "--interval" "$2"
      (( 10#$2 >= 1 && 10#$2 <= 30 )) || { echo "--interval 范围是 1～30" >&2; exit 2; }
      interval_seconds=$((10#$2))
      shift 2
      ;;
    --full-packets)
      full_packets=1
      shift
      ;;
    --max-mb)
      [[ $# -ge 2 ]] || { echo "--max-mb 缺少数值" >&2; exit 2; }
      require_integer "--max-mb" "$2"
      (( 10#$2 >= 64 && 10#$2 <= 4096 )) || { echo "--max-mb 范围是 64～4096" >&2; exit 2; }
      max_capture_mb=$((10#$2))
      shift 2
      ;;
    --stop)
      stop_requested=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

windows_temp="$(cd /mnt/c && cmd.exe /d /c echo %TEMP% 2>/dev/null | tr -d '\r' | tail -n 1)"
if [[ ! "$windows_temp" =~ ^[A-Za-z]:\\ ]]; then
  echo "无法解析 Windows TEMP：$windows_temp" >&2
  exit 1
fi
wsl_temp="$(wslpath -u "$windows_temp")"
mkdir -p "$wsl_temp"

if (( stop_requested == 1 )); then
  touch "$wsl_temp/codex-trend-watch-stop.flag"
  echo "已请求当前观察任务停止；它会在下一次轮询时停止抓包、转换 PCAPNG 并生成报告。"
  exit 0
fi

watch_copy="$wsl_temp/codex-windows-trend-watch.ps1"
launcher_copy="$wsl_temp/codex-windows-trend-watch-launcher.ps1"
watchdog_copy="$wsl_temp/codex-windows-trend-watch-watchdog.ps1"
cp "$WATCH_SCRIPT" "$watch_copy"
cp "$LAUNCHER_SCRIPT" "$launcher_copy"
cp "$WATCHDOG_SCRIPT" "$watchdog_copy"

launcher_windows="$(wslpath -w "$launcher_copy")"
powershell_args=(
  -NoProfile
  -ExecutionPolicy Bypass
  -File "$launcher_windows"
  -DurationSeconds "$duration_seconds"
  -IntervalSeconds "$interval_seconds"
  -MaxCaptureMB "$max_capture_mb"
)
if (( full_packets == 1 )); then
  powershell_args+=(-FullPackets)
fi

echo "即将请求 Windows UAC：时长 ${duration_seconds}s，轮询 ${interval_seconds}s，完整抓包=$([[ $full_packets -eq 1 ]] && echo 是 || echo 否)，上限 ${max_capture_mb}MB"
(cd /mnt/c && powershell.exe "${powershell_args[@]}")

latest_file="$wsl_temp/codex-trend-watch-latest.txt"
if [[ -f "$latest_file" ]]; then
  result_windows="$(tr -d '\r\n' < "$latest_file")"
  result_wsl="$(wslpath -u "$result_windows")"
  echo "观察完成：$result_windows"
  echo "WSL 路径：$result_wsl"
fi
