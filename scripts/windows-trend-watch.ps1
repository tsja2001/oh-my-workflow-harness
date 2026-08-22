param(
    [ValidateRange(60, 14400)]
    [int]$DurationSeconds = 600,

    [ValidateRange(1, 30)]
    [int]$IntervalSeconds = 2,

    [switch]$FullPackets,

    [ValidateRange(64, 4096)]
    [int]$MaxCaptureMB = 512
)

<#
.SYNOPSIS
    Observe Trend Micro driver consumers, WSL host activity and related network metadata.

.DESCRIPTION
    Safe defaults do not enable Windows auditing or packet capture. Passing -FullPackets
    starts the built-in Pktmon on NIC components with full packet bytes, a bounded circular
    ETL file, and converts the result to PCAPNG after the observation window.

    The script never stops services, unloads drivers, changes audit policy, edits firewall
    rules or closes handles. It must run elevated because system handle enumeration and
    Pktmon require administrator privileges.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'Administrator privileges are required. Use windows-trend-watch.sh to launch through UAC.'
    exit 5
}

$startedAt = Get-Date
$stamp = $startedAt.ToString('yyyyMMdd-HHmmss')
$outputDirectory = Join-Path $env:TEMP "codex-trend-watch-$stamp"
$eventsPath = Join-Path $outputDirectory 'events.jsonl'
$reportPath = Join-Path $outputDirectory 'summary.md'
$metadataPath = Join-Path $outputDirectory 'run-metadata.json'
$etlPath = Join-Path $outputDirectory 'packets.etl'
$pcapPath = Join-Path $outputDirectory 'packets.pcapng'
$latestPath = Join-Path $env:TEMP 'codex-trend-watch-latest.txt'
$stopRequestPath = Join-Path $env:TEMP 'codex-trend-watch-stop.flag'
$watchdogScript = Join-Path $env:TEMP 'codex-windows-trend-watch-watchdog.ps1'

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
[IO.File]::WriteAllText($latestPath, $outputDirectory, [Text.UTF8Encoding]::new($false))
if (Test-Path -LiteralPath $stopRequestPath) { Remove-Item -LiteralPath $stopRequestPath -Force }

$counters = [ordered]@{
    ProcessObserved = 0
    WslLaunch = 0
    TrendProcess = 0
    HandleMatch = 0
    TcpConnection = 0
    UdpEndpoint = 0
    TrendLogAppend = 0
    ObservationError = 0
}
$seenProcesses = @{}
$seenTcp = @{}
$seenUdp = @{}
$seenHandleLines = @{}
$companyCache = @{}
$trendLogLineCounts = @{}
$startedPktmon = $false
$captureStopOutput = ''
$captureConvertOutput = ''
$handleExecutable = $null
$watchdogProcess = $null

function Write-ObservationEvent {
    param(
        [Parameter(Mandatory=$true)][string]$Kind,
        [Parameter(Mandatory=$true)]$Data
    )
    $row = [ordered]@{
        time = (Get-Date).ToString('o')
        kind = $Kind
        data = $Data
    }
    $json = $row | ConvertTo-Json -Depth 8 -Compress
    [IO.File]::AppendAllText($eventsPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    if ($counters.Contains($Kind)) { $counters[$Kind]++ }
}

function Get-CompanyName {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    if ($companyCache.ContainsKey($Path)) { return $companyCache[$Path] }
    $company = ''
    try { $company = [string](Get-Item -LiteralPath $Path -ErrorAction Stop).VersionInfo.CompanyName }
    catch {}
    $companyCache[$Path] = $company
    return $company
}

function Get-VerifiedHandleExecutable {
    $candidates = @(
        (Join-Path $env:TEMP 'codex-sysinternals-handle\handle64.exe'),
        (Join-Path $env:TEMP 'codex-handle-20260820\handle64.exe')
    )
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        $signature = Get-AuthenticodeSignature -LiteralPath $candidate
        if ($signature.Status -eq 'Valid' -and $signature.SignerCertificate.Subject -match 'Microsoft Corporation') {
            return $candidate
        }
    }

    $directory = Join-Path $env:TEMP 'codex-sysinternals-handle'
    $archive = Join-Path $directory 'Handle.zip'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/Handle.zip' -OutFile $archive -UseBasicParsing
    Expand-Archive -LiteralPath $archive -DestinationPath $directory -Force
    $candidate = Join-Path $directory 'handle64.exe'
    $signature = Get-AuthenticodeSignature -LiteralPath $candidate
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        throw 'Downloaded Handle executable does not have a valid Microsoft signature.'
    }
    return $candidate
}

function Scan-RelevantProcesses {
    $currentRelevant = @{
        4 = 'System'
    }
    $processes = @(Get-CimInstance Win32_Process -ErrorAction Stop)
    foreach ($process in $processes) {
        $pidValue = [int]$process.ProcessId
        $name = [string]$process.Name
        $path = [string]$process.ExecutablePath
        $commandLine = [string]$process.CommandLine
        $company = Get-CompanyName -Path $path
        $isWsl = $name -match '^(wsl|wslhost|wslservice|wslrelay|vmmem|vmmemWSL|vmwp|WindowsTerminal|OpenConsole)(\.exe)?$'
        $isTrend = $name -match 'trend|aegis|tmactmon|tmcomm|tmevtmgr' -or
            $path -match 'Trend Micro|AEGIS|tmactmon|tmcomm|tmevtmgr' -or
            $company -match 'Trend Micro'

        if ($isWsl) { $currentRelevant[$pidValue] = "WSL:$name" }
        if ($isTrend) { $currentRelevant[$pidValue] = "Trend:$name" }

        $processKey = '{0}:{1}' -f $pidValue, ([string]$process.CreationDate)
        if (($isWsl -or $isTrend) -and -not $seenProcesses.ContainsKey($processKey)) {
            $seenProcesses[$processKey] = $true
            Write-ObservationEvent -Kind 'ProcessObserved' -Data ([ordered]@{
                processId = $pidValue
                parentProcessId = [int]$process.ParentProcessId
                name = $name
                executablePath = $path
                commandLine = $commandLine
                company = $company
                category = $(if ($isTrend) { 'Trend' } else { 'WSL' })
            })
            if ($isTrend) { $counters.TrendProcess++ }
            if ($name -ieq 'wsl.exe') { $counters.WslLaunch++ }
        }
    }
    return $currentRelevant
}

function Scan-TrendHandles {
    param([hashtable]$RelevantPids)
    $output = @(& $handleExecutable -accepteula -nobanner -a Tm 2>&1)
    $matches = @($output | Where-Object { [string]$_ -match 'TmComm|TmActMon|TmEvtMgr|VprotectTMFilter' })
    foreach ($match in $matches) {
        $line = ([string]$match).Trim()
        if (-not $line -or $seenHandleLines.ContainsKey($line)) { continue }
        $seenHandleLines[$line] = $true
        Write-ObservationEvent -Kind 'HandleMatch' -Data ([ordered]@{ line = $line })
        if ($line -match 'pid:\s*(\d+)') {
            $RelevantPids[[int]$Matches[1]] = 'TrendHandleOwner'
        }
    }
}

function Scan-RelevantNetwork {
    param([hashtable]$RelevantPids)
    $tcpConnections = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue)
    foreach ($connection in $tcpConnections) {
        $pidValue = [int]$connection.OwningProcess
        if (-not $RelevantPids.ContainsKey($pidValue)) { continue }
        $key = '{0}|{1}|{2}|{3}|{4}' -f $pidValue, $connection.LocalAddress, $connection.LocalPort, $connection.RemoteAddress, $connection.RemotePort
        if ($seenTcp.ContainsKey($key)) { continue }
        $seenTcp[$key] = $true
        Write-ObservationEvent -Kind 'TcpConnection' -Data ([ordered]@{
            processId = $pidValue
            processCategory = $RelevantPids[$pidValue]
            localAddress = [string]$connection.LocalAddress
            localPort = [int]$connection.LocalPort
            remoteAddress = [string]$connection.RemoteAddress
            remotePort = [int]$connection.RemotePort
            state = [string]$connection.State
        })
    }

    $udpEndpoints = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
    foreach ($endpoint in $udpEndpoints) {
        $pidValue = [int]$endpoint.OwningProcess
        if (-not $RelevantPids.ContainsKey($pidValue)) { continue }
        $key = '{0}|{1}|{2}' -f $pidValue, $endpoint.LocalAddress, $endpoint.LocalPort
        if ($seenUdp.ContainsKey($key)) { continue }
        $seenUdp[$key] = $true
        Write-ObservationEvent -Kind 'UdpEndpoint' -Data ([ordered]@{
            processId = $pidValue
            processCategory = $RelevantPids[$pidValue]
            localAddress = [string]$endpoint.LocalAddress
            localPort = [int]$endpoint.LocalPort
        })
    }
}

function Scan-TrendLogs {
    foreach ($path in @(
        (Join-Path $env:SystemRoot 'TmComm.log'),
        (Join-Path $env:SystemRoot 'TmEvtMgr.log'),
        (Join-Path $env:SystemRoot 'TmActMon.log')
    )) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $allLines = @([IO.File]::ReadAllLines($path))
        if (-not $trendLogLineCounts.ContainsKey($path)) {
            $trendLogLineCounts[$path] = $allLines.Count
            continue
        }
        $previousCount = [int]$trendLogLineCounts[$path]
        if ($allLines.Count -le $previousCount) { continue }
        $newLines = @($allLines[$previousCount..($allLines.Count - 1)])
        $trendLogLineCounts[$path] = $allLines.Count
        Write-ObservationEvent -Kind 'TrendLogAppend' -Data ([ordered]@{
            path = $path
            newLines = $newLines
        })
    }
}

function Write-SummaryReport {
    param([datetime]$FinishedAt)
    $durationActual = [math]::Round(($FinishedAt - $startedAt).TotalSeconds, 1)
    $captureFiles = @()
    foreach ($path in @($etlPath, $pcapPath)) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path
            $captureFiles += [ordered]@{
                name = $item.Name
                bytes = $item.Length
                sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            }
        }
    }

    $summary = @(
        '# Trend Micro / WSL observation summary',
        '',
        ('- Started: {0:o}' -f $startedAt),
        ('- Finished: {0:o}' -f $FinishedAt),
        ('- Actual duration seconds: {0}' -f $durationActual),
        ('- Requested duration seconds: {0}' -f $DurationSeconds),
        ('- Poll interval seconds: {0}' -f $IntervalSeconds),
        ('- Full packet capture: {0}' -f [bool]$FullPackets),
        ('- Capture limit MB: {0}' -f $MaxCaptureMB),
        '',
        '## Event counts',
        '',
        ('- Relevant processes observed: {0}' -f $counters.ProcessObserved),
        ('- WSL launches observed: {0}' -f $counters.WslLaunch),
        ('- Trend processes observed: {0}' -f $counters.TrendProcess),
        ('- Trend handle matches: {0}' -f $counters.HandleMatch),
        ('- Relevant TCP connections: {0}' -f $counters.TcpConnection),
        ('- Relevant UDP endpoints: {0}' -f $counters.UdpEndpoint),
        ('- Trend log appends: {0}' -f $counters.TrendLogAppend),
        ('- Observation errors: {0}' -f $counters.ObservationError),
        '',
        '## Files',
        '',
        ('- Event timeline: {0}' -f $eventsPath),
        ('- Run metadata: {0}' -f $metadataPath)
    )
    foreach ($captureFile in $captureFiles) {
        $summary += ('- Capture: {0}; bytes={1}; sha256={2}' -f $captureFile.name, $captureFile.bytes, $captureFile.sha256)
    }
    if ($captureStopOutput) {
        $summary += ''
        $summary += '## Pktmon stop output'
        $summary += ''
        $summary += '```text'
        $summary += $captureStopOutput.TrimEnd()
        $summary += '```'
    }
    if ($captureConvertOutput) {
        $summary += ''
        $summary += '## Pktmon conversion output'
        $summary += ''
        $summary += '```text'
        $summary += $captureConvertOutput.TrimEnd()
        $summary += '```'
    }
    [IO.File]::WriteAllLines($reportPath, $summary, [Text.UTF8Encoding]::new($false))
}

$runMetadata = [ordered]@{
    started = $startedAt.ToString('o')
    durationSeconds = $DurationSeconds
    intervalSeconds = $IntervalSeconds
    fullPackets = [bool]$FullPackets
    maxCaptureMB = $MaxCaptureMB
    packetCaptureScope = $(if ($FullPackets) { 'All NIC components; full packet bytes; circular bounded ETL' } else { 'Disabled' })
    privacy = 'Artifacts remain in the local Windows TEMP directory and may contain sensitive endpoints or packet payloads.'
}
[IO.File]::WriteAllText($metadataPath, ($runMetadata | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))

try {
    $handleExecutable = Get-VerifiedHandleExecutable
    $handleSignature = Get-AuthenticodeSignature -LiteralPath $handleExecutable
    Write-ObservationEvent -Kind 'MonitorStarted' -Data ([ordered]@{
        durationSeconds = $DurationSeconds
        intervalSeconds = $IntervalSeconds
        fullPackets = [bool]$FullPackets
        maxCaptureMB = $MaxCaptureMB
        handlePath = $handleExecutable
        handleSigner = $handleSignature.SignerCertificate.Subject
    })

    foreach ($path in @(
        (Join-Path $env:SystemRoot 'TmComm.log'),
        (Join-Path $env:SystemRoot 'TmEvtMgr.log'),
        (Join-Path $env:SystemRoot 'TmActMon.log')
    )) {
        if (Test-Path -LiteralPath $path) {
            $trendLogLineCounts[$path] = @([IO.File]::ReadAllLines($path)).Count
        }
    }

    if ($FullPackets) {
        $systemDriveName = $env:SystemDrive.TrimEnd(':')
        $systemDrive = Get-PSDrive -Name $systemDriveName -ErrorAction Stop
        $requiredFreeBytes = ([int64]$MaxCaptureMB * 3MB) + 512MB
        if ($systemDrive.Free -lt $requiredFreeBytes) {
            throw ('Insufficient free space for bounded ETL plus PCAPNG conversion. Required={0} bytes, available={1} bytes.' -f $requiredFreeBytes, $systemDrive.Free)
        }
        $existingFilters = @(& "$env:SystemRoot\System32\pktmon.exe" filter list 2>&1) | Out-String -Width 300
        Write-ObservationEvent -Kind 'PacketFilterState' -Data ([ordered]@{ output = $existingFilters.TrimEnd() })
        $pktmonStartOutput = @(& "$env:SystemRoot\System32\pktmon.exe" start --capture --comp nics --type all --pkt-size 0 --file-name $etlPath --file-size $MaxCaptureMB --log-mode circular 2>&1) | Out-String -Width 300
        if ($LASTEXITCODE -ne 0) {
            $statusAfterFailure = @(& "$env:SystemRoot\System32\pktmon.exe" status 2>&1) | Out-String -Width 300
            $activePathMatch = [regex]::Match($statusAfterFailure, '(?im)([A-Z]:\\[^\r\n]+\.etl)')
            $activePath = $(if ($activePathMatch.Success) { $activePathMatch.Groups[1].Value.Trim() } else { '(unknown)' })
            throw "Pktmon could not start because another session is active. Active ETL: $activePath"
        }
        $startedPktmon = $true
        Write-ObservationEvent -Kind 'PacketCaptureStarted' -Data ([ordered]@{
            etlPath = $etlPath
            packetBytes = 'full'
            componentScope = 'nics'
            fileMode = 'circular'
            maxCaptureMB = $MaxCaptureMB
            output = $pktmonStartOutput.TrimEnd()
        })

        if (-not (Test-Path -LiteralPath $watchdogScript)) {
            throw "Missing watchdog script: $watchdogScript"
        }
        $watchdogArguments = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $watchdogScript),
            '-ExpectedEtlPath', ('"{0}"' -f $etlPath),
            '-OutputDirectory', ('"{0}"' -f $outputDirectory),
            '-Deadline', ('"{0:o}"' -f $startedAt.AddSeconds($DurationSeconds)),
            '-StopRequestPath', ('"{0}"' -f $stopRequestPath)
        )
        $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $watchdogProcess = Start-Process -FilePath $powershell -ArgumentList ($watchdogArguments -join ' ') -WindowStyle Hidden -PassThru
        Write-ObservationEvent -Kind 'WatchdogStarted' -Data ([ordered]@{
            processId = $watchdogProcess.Id
            deadline = $startedAt.AddSeconds($DurationSeconds).ToString('o')
            script = $watchdogScript
        })
    }

    $deadline = $startedAt.AddSeconds($DurationSeconds)
    $nextHandleScan = Get-Date
    $nextProgress = Get-Date
    Write-Host ('Observation started. Output={0}' -f $outputDirectory)
    Write-Host 'Keep this window open. If it closes, the watchdog will stop this Pktmon session at the requested deadline.'
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $stopRequestPath) {
            Write-ObservationEvent -Kind 'MonitorStopRequested' -Data ([ordered]@{ path = $stopRequestPath })
            break
        }
        try {
            $relevantPids = Scan-RelevantProcesses
            if ((Get-Date) -ge $nextHandleScan) {
                Scan-TrendHandles -RelevantPids $relevantPids
                $nextHandleScan = (Get-Date).AddSeconds([math]::Max(10, $IntervalSeconds))
            }
            Scan-RelevantNetwork -RelevantPids $relevantPids
            Scan-TrendLogs
        }
        catch {
            Write-ObservationEvent -Kind 'ObservationError' -Data ([ordered]@{ message = $_.Exception.Message })
        }
        $remaining = ($deadline - (Get-Date)).TotalSeconds
        if ($remaining -le 0) { break }
        if ((Get-Date) -ge $nextProgress) {
            Write-Host ('Observing: about {0}s remaining; Trend handles={1}, Trend processes={2}, errors={3}' -f [math]::Ceiling($remaining), $counters.HandleMatch, $counters.TrendProcess, $counters.ObservationError)
            $nextProgress = (Get-Date).AddSeconds(15)
        }
        Start-Sleep -Seconds ([math]::Min($IntervalSeconds, [math]::Ceiling($remaining)))
    }
}
catch {
    Write-ObservationEvent -Kind 'FatalError' -Data ([ordered]@{ message = $_.Exception.Message; stack = $_.ScriptStackTrace })
    throw
}
finally {
    if ($startedPktmon) {
        try {
            $captureStopOutput = @(& "$env:SystemRoot\System32\pktmon.exe" stop 2>&1) | Out-String -Width 300
            Write-ObservationEvent -Kind 'PacketCaptureStopped' -Data ([ordered]@{ output = $captureStopOutput.TrimEnd() })
        }
        catch {
            Write-ObservationEvent -Kind 'ObservationError' -Data ([ordered]@{ message = "Pktmon stop failed: $($_.Exception.Message)" })
        }
        if (Test-Path -LiteralPath $etlPath) {
            try {
                $captureConvertOutput = @(& "$env:SystemRoot\System32\pktmon.exe" etl2pcap $etlPath --out $pcapPath 2>&1) | Out-String -Width 300
                Write-ObservationEvent -Kind 'PacketCaptureConverted' -Data ([ordered]@{
                    pcapPath = $pcapPath
                    output = $captureConvertOutput.TrimEnd()
                })
            }
            catch {
                Write-ObservationEvent -Kind 'ObservationError' -Data ([ordered]@{ message = "ETL to PCAPNG conversion failed: $($_.Exception.Message)" })
            }
        }
    }
    $finishedAt = Get-Date
    Write-ObservationEvent -Kind 'MonitorFinished' -Data ([ordered]@{ finished = $finishedAt.ToString('o') })
    Write-SummaryReport -FinishedAt $finishedAt
    if (Test-Path -LiteralPath $stopRequestPath) { Remove-Item -LiteralPath $stopRequestPath -Force }
    [IO.File]::WriteAllText($latestPath, $outputDirectory, [Text.UTF8Encoding]::new($false))
    Write-Output "OUTPUT_DIRECTORY=$outputDirectory"
    Write-Output "SUMMARY=$reportPath"
    if (Test-Path -LiteralPath $pcapPath) { Write-Output "PCAPNG=$pcapPath" }
}
