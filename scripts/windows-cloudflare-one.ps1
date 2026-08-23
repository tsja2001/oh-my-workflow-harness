[CmdletBinding()]
param(
    [ValidateSet('Doctor', 'Baseline', 'Install', 'SshConfig', 'Enroll', 'Connect', 'Disconnect', 'Verify')]
    [string]$Action = 'Doctor',

    [ValidatePattern('^[a-zA-Z0-9-]+$')]
    [string]$TeamName = 'mute-cake-c395',

    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$')]
    [string]$HomeCidr = '192.168.5.0/24',

    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$MacAddress = '192.168.5.35',

    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$RouterAddress = '192.168.5.1',

    [ValidateRange(1, 65535)]
    [int]$SshPort = 22,

    [ValidateRange(1, 65535)]
    [int]$HomeAssistantPort = 8123
)

<#
.SYNOPSIS
    Prepare and verify the Windows side of the approved Cloudflare One private route.

.DESCRIPTION
    The script deliberately keeps Cloudflare routing policy in the dashboard. It installs
    only the official, Authenticode-verified stable MSI and passes only ORGANIZATION to
    the installer. Enrollment runs as the current desktop user and requires that user to
    finish the one-time PIN flow in a browser.

    Enroll and Verify refuse to claim success while the Windows device is already on the
    home LAN. This prevents a direct 192.168.5.0/24 path from being mistaken for a working
    Cloudflare path.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$downloadUrl = 'https://downloads.cloudflareclient.com/v1/download/windows/ga'
$stateDirectory = Join-Path $env:LOCALAPPDATA 'codex-network'
$baselinePath = Join-Path $stateDirectory 'cloudflare-one-baseline.json'

function Write-Stage {
    param([string]$Message)
    Write-Host "`n== $Message ==" -ForegroundColor Cyan
}

function Write-Pass {
    param([string]$Message)
    Write-Host "PASS  $Message" -ForegroundColor Green
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "WARN  $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "FAIL  $Message" -ForegroundColor Red
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-ElevatedInstall {
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath),
        '-Action', 'Install',
        '-TeamName', $TeamName,
        '-HomeCidr', $HomeCidr,
        '-MacAddress', $MacAddress,
        '-RouterAddress', $RouterAddress,
        '-SshPort', $SshPort,
        '-HomeAssistantPort', $HomeAssistantPort
    )
    Write-Host 'Windows will show one UAC prompt for the signed MSI installation.'
    $process = Start-Process -FilePath $powershell -Verb RunAs -ArgumentList ($arguments -join ' ') -Wait -PassThru
    return $process.ExitCode
}

function Get-WarpCliPath {
    $knownPath = Join-Path $env:ProgramFiles 'Cloudflare\Cloudflare WARP\warp-cli.exe'
    if (Test-Path -LiteralPath $knownPath) { return $knownPath }
    $command = Get-Command warp-cli.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Get-WarpProduct {
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    return Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match '^Cloudflare (One Client|WARP)$' } |
        Select-Object -First 1 DisplayName, DisplayVersion, Publisher, UninstallString
}

function Invoke-WarpCli {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $warpCli = Get-WarpCliPath
    if (-not $warpCli) {
        return [pscustomobject]@{ ExitCode = 127; Text = 'warp-cli.exe is not installed.' }
    }
    $previousErrorAction = $ErrorActionPreference
    try {
        # warp-cli reports normal states such as "Missing registration" on stderr.
        # Capture that output without letting the script-wide Stop policy abort Doctor.
        $ErrorActionPreference = 'Continue'
        $lines = @(& $warpCli @Arguments 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    return [pscustomobject]@{
        ExitCode = $code
        Text = (($lines | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
    }
}

function Test-IpInCidr {
    param(
        [Parameter(Mandatory = $true)][string]$IpAddress,
        [Parameter(Mandatory = $true)][string]$Cidr
    )
    try {
        $cidrParts = $Cidr.Split('/')
        $ipBytes = [Net.IPAddress]::Parse($IpAddress).GetAddressBytes()
        $networkBytes = [Net.IPAddress]::Parse($cidrParts[0]).GetAddressBytes()
        $prefixLength = [int]$cidrParts[1]
        if ($ipBytes.Count -ne 4 -or $networkBytes.Count -ne 4 -or $prefixLength -lt 0 -or $prefixLength -gt 32) {
            return $false
        }
        for ($index = 0; $index -lt 4; $index++) {
            $bits = [Math]::Min([Math]::Max($prefixLength - ($index * 8), 0), 8)
            $mask = if ($bits -eq 0) { 0 } else { (256 - [Math]::Pow(2, 8 - $bits)) }
            if (($ipBytes[$index] -band [int]$mask) -ne ($networkBytes[$index] -band [int]$mask)) {
                return $false
            }
        }
        return $true
    }
    catch {
        return $false
    }
}

function Get-ActiveIpv4Addresses {
    return @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -ne '127.0.0.1' -and
            $_.AddressState -eq 'Preferred' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        Sort-Object InterfaceAlias, IPAddress |
        Select-Object InterfaceAlias, IPAddress, PrefixLength)
}

function Test-OnHomeLan {
    foreach ($address in @(Get-ActiveIpv4Addresses)) {
        if (Test-IpInCidr -IpAddress $address.IPAddress -Cidr $HomeCidr) { return $true }
    }
    return $false
}

function Get-EffectiveRoute {
    param([Parameter(Mandatory = $true)][string]$Destination)
    return Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { Test-IpInCidr -IpAddress $Destination -Cidr $_.DestinationPrefix } |
        Sort-Object -Property @(
            @{ Expression = { [int]$_.DestinationPrefix.Split('/')[1] }; Descending = $true },
            @{ Expression = { [int]$_.RouteMetric + [int]$_.InterfaceMetric }; Descending = $false }
        ) |
        Select-Object -First 1 DestinationPrefix, NextHop, InterfaceAlias, RouteMetric, InterfaceMetric
}

function Get-DefaultRouteSnapshot {
    return @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object State -eq 'Alive' |
        ForEach-Object {
            '{0}|{1}|{2}|{3}' -f $_.InterfaceAlias, $_.NextHop, $_.RouteMetric, $_.InterfaceMetric
        } |
        Sort-Object -Unique)
}

function Get-DnsSnapshot {
    $upIndexes = @(Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object Status -eq 'Up' |
        Select-Object -ExpandProperty ifIndex)
    return @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $upIndexes -contains $_.InterfaceIndex -and
            $_.InterfaceAlias -notmatch 'Cloudflare'
        } |
        ForEach-Object {
            foreach ($server in @($_.ServerAddresses)) {
                '{0}|{1}' -f $_.InterfaceAlias, $server
            }
        } |
        Sort-Object -Unique)
}

function Get-ClashProcesses {
    return @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match 'clash|mihomo' } |
        Select-Object -ExpandProperty ProcessName |
        Sort-Object -Unique)
}

function Test-InternetAccess {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri 'https://www.cloudflare.com/cdn-cgi/trace' -TimeoutSec 15
        return ($response.StatusCode -eq 200)
    }
    catch {
        return $false
    }
}

function Test-HttpEndpoint {
    param([Parameter(Mandatory = $true)][string]$Uri)
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 10
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
    }
    catch [Net.WebException] {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            return ($statusCode -ge 200 -and $statusCode -lt 500)
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-TcpEndpoint {
    param(
        [Parameter(Mandatory = $true)][string]$HostAddress,
        [Parameter(Mandatory = $true)][int]$Port
    )
    return [bool](Test-NetConnection -ComputerName $HostAddress -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)
}

function Get-ExistingMacIdentityFile {
    $configPath = Join-Path $env:USERPROFILE '.ssh\config'
    if (-not (Test-Path -LiteralPath $configPath)) { return $null }
    $insideMacHost = $false
    foreach ($line in @(Get-Content -LiteralPath $configPath)) {
        if ($line -match '^\s*Host\s+(.+?)\s*$') {
            $aliases = @($Matches[1] -split '\s+')
            $insideMacHost = ($aliases -contains 'Macmini-Tailscale')
            continue
        }
        if ($insideMacHost -and $line -match '^\s*IdentityFile\s+(.+?)\s*$') {
            $candidate = $Matches[1].Trim().Trim('"')
            $candidate = [Environment]::ExpandEnvironmentVariables($candidate)
            if (Test-Path -LiteralPath $candidate) { return $candidate }
            return $null
        }
    }
    return $null
}

function Test-WindowsSshLogin {
    param([switch]$AcceptNewHostKey)
    if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) { return $false }
    $arguments = @(
        '-n',
        '-T',
        '-o', 'BatchMode=yes',
        '-o', 'ConnectTimeout=8',
        '-o', 'ConnectionAttempts=1',
        '-o', 'PreferredAuthentications=publickey',
        '-o', 'PasswordAuthentication=no',
        '-o', 'KbdInteractiveAuthentication=no'
    )
    if ($AcceptNewHostKey) { $arguments += @('-o', 'StrictHostKeyChecking=accept-new') }
    $arguments += @('home-mac', 'hostname')
    $stdoutPath = Join-Path $env:TEMP 'codex-home-mac-ssh.stdout.txt'
    $stderrPath = Join-Path $env:TEMP 'codex-home-mac-ssh.stderr.txt'
    $process = Start-Process -FilePath (Get-Command ssh.exe).Source `
        -ArgumentList ($arguments -join ' ') `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru
    if (-not $process.WaitForExit(20000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $process.WaitForExit()
        return $false
    }
    return ($process.ExitCode -eq 0)
}

function Set-HomeSshConfig {
    Write-Stage 'Configure Windows OpenSSH alias for the home Mac'
    $sshDirectory = Join-Path $env:USERPROFILE '.ssh'
    $configPath = Join-Path $sshDirectory 'config'
    New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Windows SSH config is missing: $configPath. The existing Macmini-Tailscale identity cannot be reused safely."
    }
    $identityFile = Get-ExistingMacIdentityFile
    if (-not $identityFile) {
        throw 'The identity file used by Host Macmini-Tailscale was not found. No new key was guessed or generated.'
    }

    $backupPath = "$configPath.codex-before-cloudflare"
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Copy-Item -LiteralPath $configPath -Destination $backupPath
    }
    $beginMarker = '# BEGIN codex-cloudflare-home'
    $endMarker = '# END codex-cloudflare-home'
    $managedBlock = @"
$beginMarker
Host home-mac Macmini-Home
    HostName $MacAddress
    User mac
    Port $SshPort
    IdentityFile $identityFile
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
$endMarker
"@
    $current = [IO.File]::ReadAllText($configPath)
    $escapedBegin = [regex]::Escape($beginMarker)
    $escapedEnd = [regex]::Escape($endMarker)
    $pattern = "(?ms)^$escapedBegin\r?\n.*?^$escapedEnd\r?\n?"
    if ($current -match $pattern) {
        $updated = [regex]::Replace($current, $pattern, $managedBlock + [Environment]::NewLine)
    }
    else {
        $separator = if ($current.EndsWith("`n")) { '' } else { [Environment]::NewLine }
        $updated = $current + $separator + [Environment]::NewLine + $managedBlock + [Environment]::NewLine
    }
    [IO.File]::WriteAllText($configPath, $updated, [Text.UTF8Encoding]::new($false))
    Write-Pass "Configured aliases home-mac and Macmini-Home in $configPath"
    Write-Host "One-time backup: $backupPath"

    if (Test-OnHomeLan) {
        if (Test-WindowsSshLogin -AcceptNewHostKey) {
            Write-Pass "Key-based SSH login works now: ssh home-mac"
        }
        else {
            throw 'The alias was written, but key-based SSH login failed on the home LAN. The existing key was not replaced.'
        }
    }
    else {
        Write-WarnLine 'Not on the home LAN; the alias is ready and will be tested by Verify after WARP connects.'
    }
}

function Test-WslTcpEndpoint {
    param(
        [Parameter(Mandatory = $true)][string]$HostAddress,
        [Parameter(Mandatory = $true)][int]$Port
    )
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    $command = "timeout 8 bash -lc '</dev/tcp/$HostAddress/$Port'"
    & wsl.exe --exec bash -lc $command *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-WslHttpEndpoint {
    param([Parameter(Mandatory = $true)][string]$Uri)
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    $command = "curl --silent --show-error --output /dev/null --max-time 10 '$Uri'"
    & wsl.exe --exec bash -lc $command *> $null
    return ($LASTEXITCODE -eq 0)
}

function Save-Baseline {
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    $snapshot = [ordered]@{
        capturedAt = (Get-Date).ToString('o')
        computerName = $env:COMPUTERNAME
        ipv4Addresses = @(Get-ActiveIpv4Addresses)
        defaultRoutes = @(Get-DefaultRouteSnapshot)
        dnsServers = @(Get-DnsSnapshot)
        clashProcesses = @(Get-ClashProcesses)
    }
    $json = $snapshot | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($baselinePath, $json, [Text.UTF8Encoding]::new($false))
    Write-Pass "Saved pre-WARP baseline outside the repository: $baselinePath"
}

function Show-Doctor {
    Write-Stage 'Windows and network preflight'
    $os = Get-CimInstance Win32_OperatingSystem
    $product = Get-WarpProduct
    $service = Get-Service CloudflareWARP -ErrorAction SilentlyContinue
    Write-Host ('Computer: {0}' -f $env:COMPUTERNAME)
    Write-Host ('Windows: {0}, build {1}, architecture {2}' -f $os.Caption, $os.BuildNumber, $env:PROCESSOR_ARCHITECTURE)
    Write-Host ('Current process elevated: {0}' -f (Test-IsAdministrator))
    Write-Host ('WSL available: {0}' -f [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue))
    Write-Host ('Clash/Mihomo processes: {0}' -f ((Get-ClashProcesses) -join ', '))
    foreach ($address in @(Get-ActiveIpv4Addresses)) {
        Write-Host ('IPv4: {0} {1}/{2}' -f $address.InterfaceAlias, $address.IPAddress, $address.PrefixLength)
    }

    if (Test-OnHomeLan) {
        Write-WarnLine "This Windows device is currently on $HomeCidr. Do not use local reachability as Cloudflare proof."
    }
    else {
        Write-Pass "This Windows device is not directly attached to $HomeCidr."
    }

    $route = Get-EffectiveRoute -Destination $MacAddress
    if ($route) {
        Write-Host ('Effective route to {0}: {1}, next hop {2}, interface {3}' -f $MacAddress, $route.DestinationPrefix, $route.NextHop, $route.InterfaceAlias)
        if (-not (Test-OnHomeLan) -and $route.DestinationPrefix -ne '0.0.0.0/0' -and $route.InterfaceAlias -notmatch 'Cloudflare') {
            Write-WarnLine "A non-Cloudflare private route already captures $MacAddress. Resolve this overlap before enrollment."
        }
    }

    if ($product) {
        Write-Pass ('Installed: {0} {1}, publisher {2}' -f $product.DisplayName, $product.DisplayVersion, $product.Publisher)
        Write-Host ('Service: {0}' -f $(if ($service) { $service.Status } else { 'missing' }))
        $registration = Invoke-WarpCli -Arguments @('registration', 'show')
        Write-Host "Registration:`n$($registration.Text)"
        $status = Invoke-WarpCli -Arguments @('status')
        Write-Host "Status:`n$($status.Text)"
        $settings = Invoke-WarpCli -Arguments @('settings')
        Write-Host "Settings:`n$($settings.Text)"
    }
    else {
        Write-WarnLine 'Cloudflare One Client is not installed.'
    }
}

function Install-CloudflareOne {
    $existing = Get-WarpProduct
    if ($existing -and (Get-WarpCliPath)) {
        Write-Stage 'Install official Cloudflare One Client stable release'
        Write-Pass ('Already installed: {0} {1}' -f $existing.DisplayName, $existing.DisplayVersion)
        return
    }
    if (-not (Test-IsAdministrator)) {
        $elevatedExitCode = Invoke-ElevatedInstall
        if ($elevatedExitCode -ne 0 -and $elevatedExitCode -ne 3010) {
            throw "Elevated installer exited with code $elevatedExitCode."
        }
        return
    }

    Write-Stage 'Install official Cloudflare One Client stable release'

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installerPath = Join-Path $env:TEMP 'Cloudflare-One-Client-latest-stable.msi'
    $logPath = Join-Path $env:TEMP 'Cloudflare-One-Client-install.log'
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $installerPath

    $installer = Get-Item -LiteralPath $installerPath
    if ($installer.Length -lt 10MB) {
        throw "Downloaded installer is unexpectedly small: $($installer.Length) bytes."
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Cloudflare') {
        throw "Installer signature rejected. Status=$($signature.Status); signer=$($signature.SignerCertificate.Subject)"
    }
    Write-Pass ('Verified MSI signature: {0}' -f $signature.SignerCertificate.Subject)

    $arguments = @(
        '/i', ('"{0}"' -f $installerPath),
        '/qn',
        '/norestart',
        ('ORGANIZATION="{0}"' -f $TeamName),
        ('/L*v "{0}"' -f $logPath)
    )
    $process = Start-Process -FilePath msiexec.exe -ArgumentList ($arguments -join ' ') -Wait -PassThru
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "MSI installation failed with exit code $($process.ExitCode). Log: $logPath"
    }

    $service = Get-Service CloudflareWARP -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne 'Running') {
        Start-Service CloudflareWARP
        $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
    }
    $installed = Get-WarpProduct
    if (-not $installed -or -not (Get-WarpCliPath)) {
        throw "MSI returned success but the client is not discoverable. Log: $logPath"
    }
    Write-Pass ('Installed {0} {1}; organization preset to {2}' -f $installed.DisplayName, $installed.DisplayVersion, $TeamName)
    if ($process.ExitCode -eq 3010) {
        Write-WarnLine 'The MSI requested a Windows restart. Restart before enrollment.'
    }
}

function Assert-RemoteEnrollmentNetwork {
    if (Test-OnHomeLan) {
        throw "Enrollment is blocked while Windows is directly on $HomeCidr. Run it at the office or on a phone hotspot."
    }
    $route = Get-EffectiveRoute -Destination $MacAddress
    if ($route -and $route.DestinationPrefix -ne '0.0.0.0/0' -and $route.InterfaceAlias -notmatch 'Cloudflare') {
        throw "Route overlap: $MacAddress currently uses $($route.DestinationPrefix) on $($route.InterfaceAlias)."
    }
}

function Register-AndConnect {
    Assert-RemoteEnrollmentNetwork
    if (-not (Get-WarpCliPath)) { throw 'Cloudflare One Client is not installed. Run Install first.' }

    Write-Stage "Enroll current Windows user into $TeamName"
    $registration = Invoke-WarpCli -Arguments @('registration', 'show')
    if ($registration.ExitCode -eq 0 -and $registration.Text -match [regex]::Escape($TeamName)) {
        Write-Pass "Existing registration already belongs to $TeamName."
    }
    elseif ($registration.Text -and $registration.Text -notmatch 'No registration|not registered|Missing') {
        throw "A different or unrecognized registration exists. It was not deleted. Output: $($registration.Text)"
    }
    else {
        Write-Host 'A browser will open. Complete the one-time PIN sign-in, then approve opening Cloudflare One Client.'
        $newRegistration = Invoke-WarpCli -Arguments @('registration', 'new', $TeamName)
        if ($newRegistration.ExitCode -ne 0) {
            throw "Registration command failed: $($newRegistration.Text)"
        }
        $registered = $false
        for ($attempt = 0; $attempt -lt 90; $attempt++) {
            $registration = Invoke-WarpCli -Arguments @('registration', 'show')
            if ($registration.ExitCode -eq 0 -and $registration.Text -match [regex]::Escape($TeamName)) {
                $registered = $true
                break
            }
            Start-Sleep -Seconds 2
        }
        if (-not $registered) { throw 'Registration was not visible after three minutes. Re-run Enroll; do not paste the auth token into the repository.' }
        Write-Pass "Registration confirmed for $TeamName."
    }

    $connect = Invoke-WarpCli -Arguments @('connect')
    if ($connect.ExitCode -ne 0) { throw "Connect failed: $($connect.Text)" }
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $status = Invoke-WarpCli -Arguments @('status')
        if ($status.ExitCode -eq 0 -and $status.Text -match 'Connected') {
            Write-Pass 'Cloudflare One Client is connected.'
            $profileReady = $false
            Write-Host 'Waiting for the dashboard Traffic-only + Include profile (Cloudflare allows up to 10 minutes).'
            for ($profileAttempt = 0; $profileAttempt -lt 40; $profileAttempt++) {
                $settings = Invoke-WarpCli -Arguments @('settings')
                $modeReady = ($settings.ExitCode -eq 0 -and $settings.Text -match 'Traffic only|TrafficOnly|TunnelOnly')
                $includeReady = ($settings.Text -match 'Include mode|Include IPs')
                $homeRouteReady = ($settings.Text -match [regex]::Escape($HomeCidr))
                if ($modeReady -and $includeReady -and $homeRouteReady) {
                    $profileReady = $true
                    break
                }
                if (($profileAttempt + 1) % 2 -eq 0) {
                    Write-Host ('Still waiting for the device profile ({0}/10 minutes)...' -f (($profileAttempt + 1) / 4))
                }
                Start-Sleep -Seconds 15
            }
            if (-not $profileReady) {
                $null = Invoke-WarpCli -Arguments @('disconnect')
                throw 'The minimal Traffic-only Include profile did not arrive within 10 minutes. WARP was disconnected automatically.'
            }
            Write-Pass "Dashboard profile is active: Traffic-only, Include, $HomeCidr."
            return
        }
        Start-Sleep -Seconds 2
    }
    throw "Cloudflare One Client did not reach Connected. Last status: $($status.Text)"
}

function Set-WarpConnection {
    param([Parameter(Mandatory = $true)][bool]$Connected)
    if (-not (Get-WarpCliPath)) { throw 'Cloudflare One Client is not installed.' }
    $verb = if ($Connected) { 'connect' } else { 'disconnect' }
    $result = Invoke-WarpCli -Arguments @($verb)
    if ($result.ExitCode -ne 0) { throw "$verb failed: $($result.Text)" }
    Write-Pass "Cloudflare One Client command completed: $verb"
}

function Compare-StringArrays {
    param([object[]]$Before, [object[]]$After)
    return (@(Compare-Object -ReferenceObject @($Before) -DifferenceObject @($After)).Count -eq 0)
}

function Verify-CloudflareOne {
    Assert-RemoteEnrollmentNetwork
    if (-not (Get-WarpCliPath)) { throw 'Cloudflare One Client is not installed.' }

    Write-Stage 'End-to-end verification from Windows'
    $status = Invoke-WarpCli -Arguments @('status')
    $registration = Invoke-WarpCli -Arguments @('registration', 'show')
    $settings = Invoke-WarpCli -Arguments @('settings')
    $checks = [ordered]@{}
    $checks['registered-to-team'] = ($registration.ExitCode -eq 0 -and $registration.Text -match [regex]::Escape($TeamName))
    $checks['warp-connected'] = ($status.ExitCode -eq 0 -and $status.Text -match 'Connected')
    $checks['settings-traffic-only'] = ($settings.ExitCode -eq 0 -and $settings.Text -match 'Traffic only|TrafficOnly|TunnelOnly')
    $checks['settings-include-mode'] = ($settings.ExitCode -eq 0 -and $settings.Text -match 'Include mode|Include IPs')
    $checks['settings-home-cidr'] = ($settings.ExitCode -eq 0 -and $settings.Text -match [regex]::Escape($HomeCidr))
    $checks['settings-team-endpoint-1'] = ($settings.ExitCode -eq 0 -and $settings.Text -match '104\.19\.194\.29/32')
    $checks['settings-team-endpoint-2'] = ($settings.ExitCode -eq 0 -and $settings.Text -match '104\.19\.195\.29/32')
    $checks['windows-mac-ssh-tcp'] = Test-TcpEndpoint -HostAddress $MacAddress -Port $SshPort
    $checks['windows-mac-ssh-login'] = Test-WindowsSshLogin
    $checks['windows-home-assistant-http'] = Test-HttpEndpoint -Uri "http://${MacAddress}:$HomeAssistantPort/"
    $checks['windows-router-http'] = Test-HttpEndpoint -Uri "http://${RouterAddress}/"
    $checks['windows-public-internet'] = Test-InternetAccess
    try {
        $null = Resolve-DnsName 'www.microsoft.com' -DnsOnly -ErrorAction Stop
        $checks['windows-public-dns'] = $true
    }
    catch {
        $checks['windows-public-dns'] = $false
    }

    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        $checks['wsl-mac-ssh-tcp'] = Test-WslTcpEndpoint -HostAddress $MacAddress -Port $SshPort
        $checks['wsl-home-assistant-http'] = Test-WslHttpEndpoint -Uri "http://${MacAddress}:$HomeAssistantPort/"
        $checks['wsl-public-internet'] = Test-WslHttpEndpoint -Uri 'https://www.cloudflare.com/cdn-cgi/trace'
    }

    if (Test-Path -LiteralPath $baselinePath) {
        $baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
        $checks['default-routes-unchanged'] = Compare-StringArrays -Before @($baseline.defaultRoutes) -After @(Get-DefaultRouteSnapshot)
        $checks['dns-servers-unchanged'] = Compare-StringArrays -Before @($baseline.dnsServers) -After @(Get-DnsSnapshot)
        $beforeClash = @($baseline.clashProcesses)
        if ($beforeClash.Count -gt 0) {
            $checks['clash-still-running'] = Compare-StringArrays -Before $beforeClash -After @(Get-ClashProcesses)
        }
    }
    else {
        Write-WarnLine "No baseline found at $baselinePath; route and DNS before/after comparison is unavailable."
    }

    foreach ($entry in $checks.GetEnumerator()) {
        if ([bool]$entry.Value) { Write-Pass $entry.Key } else { Write-Fail $entry.Key }
    }
    $route = Get-EffectiveRoute -Destination $MacAddress
    if ($route) {
        Write-Host ('Effective route to {0}: {1}, next hop {2}, interface {3}' -f $MacAddress, $route.DestinationPrefix, $route.NextHop, $route.InterfaceAlias)
    }
    Write-Host "`nManual final check: open one normal company-only site that you use every day. The script cannot guess its address."

    $failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value })
    if ($failed.Count -gt 0) {
        throw "$($failed.Count) automated verification check(s) failed. Run Disconnect if normal office networking is affected."
    }
    Write-Pass 'All automated checks passed.'
}

try {
    switch ($Action) {
        'Doctor' { Show-Doctor }
        'Baseline' { Save-Baseline; Show-Doctor }
        'Install' { Install-CloudflareOne }
        'SshConfig' { Set-HomeSshConfig }
        'Enroll' { Register-AndConnect }
        'Connect' { Set-WarpConnection -Connected $true }
        'Disconnect' { Set-WarpConnection -Connected $false }
        'Verify' { Verify-CloudflareOne }
    }
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
