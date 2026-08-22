param(
    [ValidateRange(60, 14400)]
    [int]$DurationSeconds = 600,

    [ValidateRange(1, 30)]
    [int]$IntervalSeconds = 2,

    [switch]$FullPackets,

    [ValidateRange(64, 4096)]
    [int]$MaxCaptureMB = 512
)

$ErrorActionPreference = 'Stop'
$watchScript = Join-Path $env:TEMP 'codex-windows-trend-watch.ps1'
if (-not (Test-Path -LiteralPath $watchScript)) {
    throw "Missing watcher script: $watchScript"
}

$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', ('"{0}"' -f $watchScript),
    '-DurationSeconds', $DurationSeconds,
    '-IntervalSeconds', $IntervalSeconds,
    '-MaxCaptureMB', $MaxCaptureMB
)
if ($FullPackets) { $arguments += '-FullPackets' }

$process = Start-Process -FilePath $powershell -Verb RunAs -ArgumentList ($arguments -join ' ') -Wait -PassThru
if ($process.ExitCode -ne 0) {
    $latestPath = Join-Path $env:TEMP 'codex-trend-watch-latest.txt'
    $detail = ''
    if (Test-Path -LiteralPath $latestPath) {
        $directory = [IO.File]::ReadAllText($latestPath).Trim()
        $eventsPath = Join-Path $directory 'events.jsonl'
        if (Test-Path -LiteralPath $eventsPath) {
            $fatal = Get-Content -LiteralPath $eventsPath -ErrorAction SilentlyContinue |
                ForEach-Object { try { $_ | ConvertFrom-Json } catch {} } |
                Where-Object kind -eq 'FatalError' |
                Select-Object -Last 1
            if ($fatal) { $detail = [string]$fatal.data.message }
        }
    }
    throw "Elevated watcher exited with code $($process.ExitCode). $detail"
}

$latestPath = Join-Path $env:TEMP 'codex-trend-watch-latest.txt'
if (Test-Path -LiteralPath $latestPath) {
    Write-Output ('OUTPUT_DIRECTORY={0}' -f ([IO.File]::ReadAllText($latestPath).Trim()))
}
