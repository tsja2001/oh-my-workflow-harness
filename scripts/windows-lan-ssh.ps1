param(
    [ValidateSet('Apply', 'Status', 'Rollback')]
    [string]$Action = 'Status',

    [ValidateRange(1024, 65535)]
    [int]$Port = 2222,

    [string]$InterfaceAlias = 'WLAN',

    [string]$WindowsUser = $env:USERNAME,

    [string]$BackupDirectory = ''
)

<#
.SYNOPSIS
    Configure a key-only Windows OpenSSH entry for LAN access without changing WSL NAT.

.DESCRIPTION
    Apply backs up the current OpenSSH files, host keys, sshd service state and the
    script-owned firewall rule before changing anything. It configures Windows sshd on
    TCP/2222, keeps WSL's localhost TCP/22 relay untouched, restricts the firewall rule
    to the selected LAN interface and LocalSubnet, and automatically restores the backup
    if any validation fails.

    The source public-key file is C:\ProgramData\ssh\administrators_authorized_keys.txt,
    which already contains the intended Mac public keys. Private keys are never read.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$openSshDirectory = Join-Path $env:ProgramData 'ssh'
$configPath = Join-Path $openSshDirectory 'sshd_config'
$defaultConfigPath = Join-Path $env:SystemRoot 'System32\OpenSSH\sshd_config_default'
$sshdPath = Join-Path $env:SystemRoot 'System32\OpenSSH\sshd.exe'
$sshKeygenPath = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh-keygen.exe'
$adminKeysPath = Join-Path $openSshDirectory 'administrators_authorized_keys'
$preparedKeysPath = Join-Path $openSshDirectory 'administrators_authorized_keys.txt'
$logsPath = Join-Path $openSshDirectory 'logs'
$firewallRuleName = 'Codex-OpenSSH-LAN-2222'
$firewallDisplayName = 'OpenSSH Server (LAN TCP 2222)'
$backupRoot = Join-Path $openSshDirectory 'codex-backups'
$latestBackupPath = Join-Path $openSshDirectory 'codex-last-lan-ssh-backup.txt'
$resultRoot = Join-Path $env:TEMP ('codex-windows-lan-ssh-' + (Get-Date).ToString('yyyyMMdd-HHmmss'))
$summaryPath = Join-Path $resultRoot 'summary.txt'

function Write-Utf8NoBom {
    param([string]$Path, [string[]]$Lines)
    [IO.File]::WriteAllLines($Path, $Lines, [Text.UTF8Encoding]::new($false))
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator privileges are required. Launch through windows-lan-ssh.sh and approve UAC.'
    }
}

function Get-ServiceSnapshot {
    $service = Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction Stop
    return [ordered]@{
        State = [string]$service.State
        StartMode = [string]$service.StartMode
    }
}

function Get-FirewallSnapshot {
    $rule = Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue
    if (-not $rule) { return $null }
    $portFilter = $rule | Get-NetFirewallPortFilter
    $addressFilter = $rule | Get-NetFirewallAddressFilter
    $interfaceFilter = $rule | Get-NetFirewallInterfaceFilter
    return [ordered]@{
        Name = [string]$rule.Name
        DisplayName = [string]$rule.DisplayName
        Enabled = [string]$rule.Enabled
        Profile = [string]$rule.Profile
        Direction = [string]$rule.Direction
        Action = [string]$rule.Action
        Protocol = [string]$portFilter.Protocol
        LocalPort = @($portFilter.LocalPort)
        RemotePort = @($portFilter.RemotePort)
        LocalAddress = @($addressFilter.LocalAddress)
        RemoteAddress = @($addressFilter.RemoteAddress)
        InterfaceAlias = @($interfaceFilter.InterfaceAlias)
    }
}

function Set-GlobalSshDirective {
    param(
        [string[]]$Lines,
        [string]$Name,
        [string]$Value
    )
    $result = [Collections.Generic.List[string]]::new()
    $beforeMatch = $true
    $replaced = $false
    $directivePattern = '^\s*#?\s*' + [regex]::Escape($Name) + '\s+'
    foreach ($line in $Lines) {
        if ($beforeMatch -and $line -match '^\s*Match\s+') { $beforeMatch = $false }
        if ($beforeMatch -and $line -match $directivePattern) {
            if (-not $replaced) {
                $result.Add("$Name $Value")
                $replaced = $true
            }
            continue
        }
        $result.Add($line)
    }
    if (-not $replaced) { $result.Insert(0, "$Name $Value") }
    return $result.ToArray()
}

function Set-RestrictedFileAcl {
    param([Parameter(Mandatory)][string]$Path)
    $administratorsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $acl = [Security.AccessControl.FileSecurity]::new()
    $acl.SetOwner($administratorsSid)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @($administratorsSid, $systemSid)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Set-AdminKeyAcl {
    Set-RestrictedFileAcl -Path $adminKeysPath
}

function Set-OpenSshDirectoryAcl {
    param([string]$Path)
    $administratorsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $authenticatedUsersSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-11')
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($administratorsSid)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @($administratorsSid, $systemSid)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($rule)
    }
    $readRule = [Security.AccessControl.FileSystemAccessRule]::new(
        $authenticatedUsersSid,
        [Security.AccessControl.FileSystemRights]::ReadAndExecute,
        [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
        [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Allow
    )
    [void]$acl.AddAccessRule($readRule)
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Restore-FirewallSnapshot {
    param($Snapshot)
    Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue
    if ($null -eq $Snapshot) { return }
    $enabled = ([string]$Snapshot.Enabled -eq 'True')
    $restoreParameters = @{
        Name = [string]$Snapshot.Name
        DisplayName = [string]$Snapshot.DisplayName
        Enabled = $enabled
        Profile = [string]$Snapshot.Profile
        Direction = [string]$Snapshot.Direction
        Action = [string]$Snapshot.Action
        Protocol = [string]$Snapshot.Protocol
        LocalPort = @($Snapshot.LocalPort)
        RemotePort = @($Snapshot.RemotePort)
        LocalAddress = @($Snapshot.LocalAddress)
        RemoteAddress = @($Snapshot.RemoteAddress)
        InterfaceAlias = @($Snapshot.InterfaceAlias)
    }
    New-NetFirewallRule @restoreParameters | Out-Null
}

function Restore-Backup {
    param([string]$Directory)
    $metadataPath = Join-Path $Directory 'metadata.json'
    if (-not (Test-Path -LiteralPath $metadataPath)) { throw "Missing backup metadata: $metadataPath" }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json

    Stop-Service sshd -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $logsPath) { Remove-Item -LiteralPath $logsPath -Recurse -Force }
    if ([bool]$metadata.LogsExisted) {
        Copy-Item -LiteralPath (Join-Path $Directory 'logs') -Destination $logsPath -Recurse -Force
        if ($metadata.LogsSddl) {
            $logsAcl = Get-Acl -LiteralPath $logsPath
            $logsAcl.SetSecurityDescriptorSddlForm([string]$metadata.LogsSddl)
            Set-Acl -LiteralPath $logsPath -AclObject $logsAcl
        }
    }

    if ([bool]$metadata.ConfigExisted) {
        Copy-Item -LiteralPath (Join-Path $Directory 'sshd_config') -Destination $configPath -Force
        if ($metadata.ConfigSddl) {
            $acl = Get-Acl -LiteralPath $configPath
            $acl.SetSecurityDescriptorSddlForm([string]$metadata.ConfigSddl)
            Set-Acl -LiteralPath $configPath -AclObject $acl
        }
    } elseif (Test-Path -LiteralPath $configPath) {
        Remove-Item -LiteralPath $configPath -Force
    }

    if ([bool]$metadata.AdminKeysExisted) {
        Copy-Item -LiteralPath (Join-Path $Directory 'administrators_authorized_keys') -Destination $adminKeysPath -Force
        if ($metadata.AdminKeysSddl) {
            $acl = Get-Acl -LiteralPath $adminKeysPath
            $acl.SetSecurityDescriptorSddlForm([string]$metadata.AdminKeysSddl)
            Set-Acl -LiteralPath $adminKeysPath -AclObject $acl
        }
    } elseif (Test-Path -LiteralPath $adminKeysPath) {
        Remove-Item -LiteralPath $adminKeysPath -Force
    }

    Get-ChildItem -LiteralPath $openSshDirectory -Filter 'ssh_host_*_key*' -File -ErrorAction SilentlyContinue |
        Remove-Item -Force
    $hostKeyBackup = Join-Path $Directory 'host-keys'
    if (Test-Path -LiteralPath $hostKeyBackup) {
        Copy-Item -Path (Join-Path $hostKeyBackup '*') -Destination $openSshDirectory -Force
        foreach ($hostKey in @($metadata.HostKeys)) {
            $restoredPath = Join-Path $openSshDirectory ([string]$hostKey.Name)
            if ($hostKey.Sddl -and (Test-Path -LiteralPath $restoredPath)) {
                $acl = Get-Acl -LiteralPath $restoredPath
                $acl.SetSecurityDescriptorSddlForm([string]$hostKey.Sddl)
                Set-Acl -LiteralPath $restoredPath -AclObject $acl
            }
        }
    }

    Restore-FirewallSnapshot -Snapshot $metadata.FirewallRule

    switch ([string]$metadata.Service.StartMode) {
        'Auto' { Set-Service sshd -StartupType Automatic }
        'Disabled' { Set-Service sshd -StartupType Disabled }
        default { Set-Service sshd -StartupType Manual }
    }
    if ([string]$metadata.Service.State -eq 'Running') {
        Start-Service sshd
    } else {
        Stop-Service sshd -Force -ErrorAction SilentlyContinue
    }
    if ($metadata.OpenSshDirectorySddl) {
        $directoryAcl = Get-Acl -LiteralPath $openSshDirectory
        $directoryAcl.SetSecurityDescriptorSddlForm([string]$metadata.OpenSshDirectorySddl)
        Set-Acl -LiteralPath $openSshDirectory -AclObject $directoryAcl
    }
}

function Write-Status {
    $service = Get-Service sshd -ErrorAction SilentlyContinue
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    $port22 = @(Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction SilentlyContinue)
    $firewallRule = Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue
    $tailscale = Get-Service Tailscale -ErrorAction SilentlyContinue
    $lines = @(
        "WINDOWS_USER=$WindowsUser",
        "PORT=$Port",
        "INTERFACE=$InterfaceAlias",
        "SSHD=$($service.Status),$($service.StartType)",
        "CONFIG_EXISTS=$(Test-Path -LiteralPath $configPath)",
        "ADMIN_KEYS_EXISTS=$(Test-Path -LiteralPath $adminKeysPath)",
        "FIREWALL_RULE=$(if ($firewallRule) { [string]$firewallRule.Enabled } else { 'Missing' })",
        "LISTEN_$Port=$(@($listeners | ForEach-Object { $_.LocalAddress }) -join ',')",
        "LISTEN_22=$(@($port22 | ForEach-Object { $_.LocalAddress }) -join ',')",
        "TAILSCALE=$(if ($tailscale) { [string]$tailscale.Status + ',' + [string]$tailscale.StartType } else { 'Missing' })"
    )
    Write-Utf8NoBom -Path $summaryPath -Lines $lines
    $lines | ForEach-Object { Write-Output $_ }
    Write-Output "SUMMARY=$summaryPath"
}

function Write-SshdDiagnostic {
    $diagnosticPath = Join-Path $resultRoot 'sshd-debug.log'
    try {
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $sshdPath
        $startInfo.Arguments = '-ddd -E "{0}" -f "{1}"' -f $diagnosticPath, $configPath
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $process = [Diagnostics.Process]::Start($startInfo)
        if (-not $process.WaitForExit(3000)) {
            $process.Kill()
            [void]$process.WaitForExit(3000)
        }
        $service = Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction SilentlyContinue
        @(
            "DEBUG_EXIT_CODE=$($process.ExitCode)",
            "SERVICE_EXIT_CODE=$($service.ExitCode)",
            "SERVICE_SPECIFIC_EXIT_CODE=$($service.ServiceSpecificExitCode)"
        ) | Add-Content -LiteralPath $diagnosticPath -Encoding UTF8
    } catch {
        Write-Utf8NoBom -Path $diagnosticPath -Lines @("Unable to collect sshd diagnostic: $($_.Exception.Message)")
    }
    return $diagnosticPath
}

New-Item -ItemType Directory -Path $resultRoot -Force | Out-Null

try {
    if ($Action -eq 'Status') {
        Write-Status
        exit 0
    }

    Assert-Administrator
    New-Item -ItemType Directory -Path $openSshDirectory -Force | Out-Null

    if ($Action -eq 'Rollback') {
        if ([string]::IsNullOrWhiteSpace($BackupDirectory)) {
            if (-not (Test-Path -LiteralPath $latestBackupPath)) { throw 'No latest backup pointer was found.' }
            $BackupDirectory = [IO.File]::ReadAllText($latestBackupPath).Trim()
        }
        Restore-Backup -Directory $BackupDirectory
        Write-Output "ROLLBACK=SUCCESS"
        Write-Output "BACKUP=$BackupDirectory"
        Write-Status
        exit 0
    }

    foreach ($requiredPath in @($defaultConfigPath, $sshdPath, $sshKeygenPath, $preparedKeysPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Required file is missing: $requiredPath" }
    }
    if (-not (Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue)) {
        throw "Network interface was not found: $InterfaceAlias"
    }
    $serviceBefore = Get-ServiceSnapshot
    $firewallBefore = Get-FirewallSnapshot
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $BackupDirectory = Join-Path $backupRoot $stamp
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null

    $configExisted = Test-Path -LiteralPath $configPath
    $adminKeysExisted = Test-Path -LiteralPath $adminKeysPath
    $logsExisted = Test-Path -LiteralPath $logsPath
    $existingHostKeys = @(Get-ChildItem -LiteralPath $openSshDirectory -Filter 'ssh_host_*_key*' -File -ErrorAction SilentlyContinue)
    $hostKeyMetadata = @($existingHostKeys | ForEach-Object {
        [ordered]@{ Name = $_.Name; Sddl = (Get-Acl -LiteralPath $_.FullName).Sddl }
    })
    $metadata = [ordered]@{
        CreatedAt = (Get-Date).ToString('o')
        Port = $Port
        InterfaceAlias = $InterfaceAlias
        WindowsUser = $WindowsUser
        OpenSshDirectorySddl = (Get-Acl -LiteralPath $openSshDirectory).Sddl
        LogsExisted = $logsExisted
        LogsSddl = $(if ($logsExisted) { (Get-Acl -LiteralPath $logsPath).Sddl } else { '' })
        ConfigExisted = $configExisted
        ConfigSddl = $(if ($configExisted) { (Get-Acl -LiteralPath $configPath).Sddl } else { '' })
        AdminKeysExisted = $adminKeysExisted
        AdminKeysSddl = $(if ($adminKeysExisted) { (Get-Acl -LiteralPath $adminKeysPath).Sddl } else { '' })
        HostKeys = $hostKeyMetadata
        Service = $serviceBefore
        FirewallRule = $firewallBefore
    }
    $metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $BackupDirectory 'metadata.json') -Encoding UTF8
    if ($configExisted) { Copy-Item -LiteralPath $configPath -Destination (Join-Path $BackupDirectory 'sshd_config') }
    if ($adminKeysExisted) { Copy-Item -LiteralPath $adminKeysPath -Destination (Join-Path $BackupDirectory 'administrators_authorized_keys') }
    if ($logsExisted) { Copy-Item -LiteralPath $logsPath -Destination (Join-Path $BackupDirectory 'logs') -Recurse }
    if ($existingHostKeys.Count -gt 0) {
        $hostKeyBackup = Join-Path $BackupDirectory 'host-keys'
        New-Item -ItemType Directory -Path $hostKeyBackup | Out-Null
        $existingHostKeys | Copy-Item -Destination $hostKeyBackup
    }
    [IO.File]::WriteAllText($latestBackupPath, $BackupDirectory, [Text.UTF8Encoding]::new($false))

    try {
        Set-OpenSshDirectoryAcl -Path $openSshDirectory
        New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
        Set-OpenSshDirectoryAcl -Path $logsPath

        if (-not $configExisted) { Copy-Item -LiteralPath $defaultConfigPath -Destination $configPath }
        $configLines = [IO.File]::ReadAllLines($configPath)
        $configLines = Set-GlobalSshDirective -Lines $configLines -Name 'Port' -Value ([string]$Port)
        $configLines = Set-GlobalSshDirective -Lines $configLines -Name 'PubkeyAuthentication' -Value 'yes'
        $configLines = Set-GlobalSshDirective -Lines $configLines -Name 'PasswordAuthentication' -Value 'no'
        $configLines = Set-GlobalSshDirective -Lines $configLines -Name 'KbdInteractiveAuthentication' -Value 'no'
        $configLines = Set-GlobalSshDirective -Lines $configLines -Name 'AuthenticationMethods' -Value 'publickey'
        $configLines = Set-GlobalSshDirective -Lines $configLines -Name 'AllowTcpForwarding' -Value 'yes'
        Write-Utf8NoBom -Path $configPath -Lines $configLines

        $preparedKeys = @(
            Get-Content -LiteralPath $preparedKeysPath |
                ForEach-Object { ([string]$_).Trim() } |
                Where-Object { $_ -match '^(ssh-ed25519|sk-ssh-ed25519@openssh.com|ecdsa-[^ ]+|ssh-rsa)\s+' }
        )
        if ($preparedKeys.Count -lt 1) { throw 'The prepared administrators key file contains no valid SSH public keys.' }
        $allKeys = @($preparedKeys)
        if ($adminKeysExisted) {
            $allKeys += @(
                Get-Content -LiteralPath $adminKeysPath |
                    ForEach-Object { ([string]$_).Trim() } |
                    Where-Object { $_ -match '^(ssh-ed25519|sk-ssh-ed25519@openssh.com|ecdsa-[^ ]+|ssh-rsa)\s+' }
            )
        }
        $allKeys = @($allKeys | Select-Object -Unique)
        Write-Utf8NoBom -Path $adminKeysPath -Lines $allKeys
        Set-AdminKeyAcl

        Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue |
            Remove-NetFirewallRule -ErrorAction SilentlyContinue
        $firewallParameters = @{
            Name = $firewallRuleName
            DisplayName = $firewallDisplayName
            Enabled = 'True'
            Direction = 'Inbound'
            Action = 'Allow'
            Protocol = 'TCP'
            LocalPort = $Port
            Profile = 'Any'
            InterfaceAlias = $InterfaceAlias
            RemoteAddress = 'LocalSubnet'
        }
        New-NetFirewallRule @firewallParameters | Out-Null

        & $sshKeygenPath -A | Out-Null
        $privateHostKeys = @(
            Get-ChildItem -LiteralPath $openSshDirectory -Filter 'ssh_host_*_key' -File -ErrorAction SilentlyContinue
        )
        if ($privateHostKeys.Count -lt 1) { throw 'No OpenSSH private host keys were generated.' }
        foreach ($privateHostKey in $privateHostKeys) {
            Set-RestrictedFileAcl -Path $privateHostKey.FullName
        }
        & $sshdPath -t -f $configPath
        if ($LASTEXITCODE -ne 0) { throw "sshd configuration validation failed with exit code $LASTEXITCODE" }

        Set-Service sshd -StartupType Automatic
        if ((Get-Service sshd).Status -eq 'Running') {
            Restart-Service sshd -Force
        } else {
            Start-Service sshd
        }

        $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop)
        if ($listeners.Count -lt 1 -or -not ($listeners.LocalAddress -contains '0.0.0.0' -or $listeners.LocalAddress -contains '::')) {
            throw "sshd did not create a non-loopback listener on TCP/$Port"
        }
        $rule = Get-NetFirewallRule -Name $firewallRuleName -ErrorAction Stop
        if ([string]$rule.Enabled -ne 'True' -or [string]$rule.Action -ne 'Allow') {
            throw 'The LAN firewall rule is not enabled and allowing traffic.'
        }
    } catch {
        $applyError = $_.Exception.Message
        $diagnosticPath = Write-SshdDiagnostic
        try { Restore-Backup -Directory $BackupDirectory } catch { $applyError += "; automatic rollback also failed: $($_.Exception.Message)" }
        throw "$applyError; sshd diagnostic: $diagnosticPath"
    }

    Write-Output 'APPLY=SUCCESS'
    Write-Output "BACKUP=$BackupDirectory"
    Write-Output "AUTHORIZED_KEY_COUNT=$($allKeys.Count)"
    Write-Status
} catch {
    $fatalPath = Join-Path $resultRoot 'fatal.txt'
    Write-Utf8NoBom -Path $fatalPath -Lines @($_.Exception.Message)
    Write-Error $_.Exception.Message
    Write-Output "RESULT_DIRECTORY=$resultRoot"
    exit 1
}
