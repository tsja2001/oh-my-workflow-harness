param(
    [Parameter(Mandatory=$true)]
    [string]$ExpectedEtlPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory=$true)]
    [datetime]$Deadline,

    [Parameter(Mandatory=$true)]
    [string]$StopRequestPath
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$pktmon = Join-Path $env:SystemRoot 'System32\pktmon.exe'
$pcapPath = Join-Path $OutputDirectory 'packets.pcapng'
$watchdogLog = Join-Path $OutputDirectory 'watchdog.txt'
$graceDeadline = $Deadline.AddSeconds(15)

function Write-WatchdogLog([string]$Message) {
    $line = '{0:o} {1}{2}' -f (Get-Date), $Message, [Environment]::NewLine
    [IO.File]::AppendAllText($watchdogLog, $line, [Text.UTF8Encoding]::new($false))
}

function Get-ActiveEtlPath {
    $status = & $pktmon status 2>&1 | Out-String -Width 300
    $match = [regex]::Match($status, '(?im)([A-Z]:\\[^\r\n]+\.etl)')
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ''
}

Write-WatchdogLog ('Started. ExpectedEtl={0}; Deadline={1:o}' -f $ExpectedEtlPath, $Deadline)

while ((Get-Date) -lt $graceDeadline) {
    if (Test-Path -LiteralPath $StopRequestPath) {
        Write-WatchdogLog 'Stop flag observed; allowing the main watcher five seconds to clean up.'
        Start-Sleep -Seconds 5
        break
    }
    Start-Sleep -Seconds 2
}

$activeEtl = Get-ActiveEtlPath
if ([string]::IsNullOrWhiteSpace($activeEtl)) {
    Write-WatchdogLog 'No active Pktmon session; the main watcher already cleaned up.'
    if (Test-Path -LiteralPath $StopRequestPath) { Remove-Item -LiteralPath $StopRequestPath -Force -ErrorAction SilentlyContinue }
    exit 0
}

if (-not [string]::Equals($activeEtl, $ExpectedEtlPath, [StringComparison]::OrdinalIgnoreCase)) {
    Write-WatchdogLog ('REFUSED: active ETL path belongs to another session: {0}' -f $activeEtl)
    exit 3
}

Write-WatchdogLog 'Expected Pktmon session is still active; stopping it now.'
$stopOutput = & $pktmon stop 2>&1 | Out-String -Width 300
Write-WatchdogLog ('Pktmon stop exit={0}; output={1}' -f $LASTEXITCODE, $stopOutput.TrimEnd())

if ((Test-Path -LiteralPath $ExpectedEtlPath) -and -not (Test-Path -LiteralPath $pcapPath)) {
    $convertOutput = & $pktmon etl2pcap $ExpectedEtlPath --out $pcapPath 2>&1 | Out-String -Width 300
    Write-WatchdogLog ('PCAP conversion exit={0}; output={1}' -f $LASTEXITCODE, $convertOutput.TrimEnd())
}

if (Test-Path -LiteralPath $StopRequestPath) { Remove-Item -LiteralPath $StopRequestPath -Force -ErrorAction SilentlyContinue }
exit 0
