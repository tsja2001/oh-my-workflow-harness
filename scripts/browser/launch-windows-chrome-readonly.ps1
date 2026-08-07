param(
    [switch]$Stop
)

$ErrorActionPreference = "Stop"
$debugPort = 9223
$portArgument = "--remote-debugging-port=$debugPort"
$profilePath = Join-Path ${env:LOCALAPPDATA} "work-wsl-browser\jenkins-readonly"

$dedicatedProcesses = Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($portArgument) }

if ($Stop) {
    foreach ($process in $dedicatedProcesses) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Write-Output "STOPPED"
    exit 0
}

try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$debugPort/json/version" -TimeoutSec 2
    if ($response.StatusCode -eq 200) {
        Write-Output "ALREADY_RUNNING"
        exit 0
    }
}
catch {
    # Expected when the dedicated browser is not running yet.
}

$chromePath = Join-Path ${env:ProgramFiles} "Google\Chrome\Application\chrome.exe"
New-Item -ItemType Directory -Path $profilePath -Force | Out-Null

$arguments = @(
    "--headless=new",
    $portArgument,
    "--remote-debugging-address=127.0.0.1",
    "--user-data-dir=$profilePath",
    "--no-first-run",
    "--no-default-browser-check",
    "about:blank"
)

Start-Process -FilePath $chromePath -ArgumentList $arguments
Write-Output "STARTED"
