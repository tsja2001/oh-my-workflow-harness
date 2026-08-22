param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 2222,

    [string]$InterfaceAlias = 'WLAN',

    [string]$WindowsUser = $env:USERNAME
)

<#
.SYNOPSIS
    Repair the Windows in-box OpenSSH Server capability, then apply the LAN SSH config.

.DESCRIPTION
    The OpenSSH Client is not removed. Before changing the Server capability, the script
    records capability/service state and copies C:\ProgramData\ssh to a persistent backup.
    It stops before removal when Windows already has a pending reboot, and stops after a
    remove/add operation when Windows reports that a reboot is required.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator privileges are required.'
}

$capabilityName = 'OpenSSH.Server~~~~0.0.1.0'
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$resultDirectory = Join-Path $env:TEMP "codex-openssh-repair-$stamp"
$backupDirectory = Join-Path $env:ProgramData "codex-openssh-repair-backups\$stamp"
$sourceSshDirectory = Join-Path $env:ProgramData 'ssh'
$backupSshDirectory = Join-Path $backupDirectory 'ssh'
$repairLog = Join-Path $resultDirectory 'repair.log'
$metadataPath = Join-Path $backupDirectory 'metadata.json'
$configScript = Join-Path $env:TEMP 'codex-windows-lan-ssh.ps1'

New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

function Write-RepairLog {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date).ToString('o'), $Message
    [IO.File]::AppendAllText($repairLog, $line + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    Write-Output $Message
}

function Test-PendingReboot {
    $reasons = [Collections.Generic.List[string]]::new()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons.Add('ComponentBasedServicing')
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons.Add('WindowsUpdate')
    }
    $sessionManager = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
    if ($sessionManager.PendingFileRenameOperations) { $reasons.Add('PendingFileRenameOperations') }
    return $reasons.ToArray()
}

try {
    $capabilityBefore = Get-WindowsCapability -Online -Name $capabilityName
    $serviceBefore = Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction SilentlyContinue
    $binaryPath = Join-Path $env:SystemRoot 'System32\OpenSSH\sshd.exe'
    $binaryVersion = if (Test-Path $binaryPath) { (Get-Item $binaryPath).VersionInfo.FileVersion } else { '' }
    $pendingReboot = @(Test-PendingReboot)
    $blockingPendingReboot = @($pendingReboot | Where-Object { $_ -ne 'PendingFileRenameOperations' })

    $metadata = [ordered]@{
        CreatedAt = (Get-Date).ToString('o')
        CapabilityName = $capabilityName
        CapabilityState = [string]$capabilityBefore.State
        BinaryVersion = [string]$binaryVersion
        ServiceState = if ($serviceBefore) { [string]$serviceBefore.State } else { 'Missing' }
        ServiceStartMode = if ($serviceBefore) { [string]$serviceBefore.StartMode } else { 'Missing' }
        ServicePath = if ($serviceBefore) { [string]$serviceBefore.PathName } else { '' }
        PendingReboot = $pendingReboot
        BlockingPendingReboot = $blockingPendingReboot
    }
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
    & reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Services\sshd' (Join-Path $backupDirectory 'sshd-service.reg') /y 2>&1 |
        Out-File -LiteralPath (Join-Path $backupDirectory 'reg-export.txt') -Encoding UTF8

    if (Test-Path $sourceSshDirectory) {
        New-Item -ItemType Directory -Path $backupSshDirectory -Force | Out-Null
        & robocopy.exe $sourceSshDirectory $backupSshDirectory /E /COPYALL /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NP |
            Out-File -LiteralPath (Join-Path $backupDirectory 'robocopy.txt') -Encoding UTF8
        if ($LASTEXITCODE -gt 7) { throw "OpenSSH data backup failed with robocopy exit code $LASTEXITCODE" }
    }

    Write-RepairLog "CAPABILITY_BEFORE=$($capabilityBefore.State)"
    Write-RepairLog "BINARY_VERSION_BEFORE=$binaryVersion"
    Write-RepairLog "BACKUP=$backupDirectory"
    if ($pendingReboot -contains 'PendingFileRenameOperations') {
        Write-RepairLog 'NONBLOCKING_PENDING_FILE_RENAMES=True'
    }
    if ($blockingPendingReboot.Count -gt 0) {
        Write-RepairLog "PENDING_REBOOT_BEFORE_REPAIR=$($blockingPendingReboot -join ',')"
        Write-RepairLog 'No component changes were made.'
        exit 20
    }
    if ([string]$capabilityBefore.State -ne 'Installed') {
        throw "Unexpected OpenSSH Server capability state: $($capabilityBefore.State)"
    }

    Write-RepairLog 'Removing only the OpenSSH Server capability...'
    $removeResult = Remove-WindowsCapability -Online -Name $capabilityName
    Write-RepairLog "REMOVE_RESTART_NEEDED=$($removeResult.RestartNeeded)"
    if ($removeResult.RestartNeeded) {
        Write-RepairLog 'REBOOT_REQUIRED_AFTER_REMOVE=True'
        exit 21
    }

    Write-RepairLog 'Installing the OpenSSH Server capability from Windows Update/component store...'
    $addResult = Add-WindowsCapability -Online -Name $capabilityName
    Write-RepairLog "ADD_RESTART_NEEDED=$($addResult.RestartNeeded)"
    if ($addResult.RestartNeeded) {
        Write-RepairLog 'REBOOT_REQUIRED_AFTER_ADD=True'
        exit 22
    }

    $capabilityAfter = Get-WindowsCapability -Online -Name $capabilityName
    $serviceAfter = Get-Service sshd -ErrorAction SilentlyContinue
    $signature = Get-AuthenticodeSignature $binaryPath
    Write-RepairLog "CAPABILITY_AFTER=$($capabilityAfter.State)"
    Write-RepairLog "SERVICE_AFTER_INSTALL=$(if ($serviceAfter) { $serviceAfter.Status } else { 'Missing' })"
    Write-RepairLog "BINARY_SIGNATURE=$($signature.Status)"
    if ([string]$capabilityAfter.State -ne 'Installed' -or -not $serviceAfter -or [string]$signature.Status -ne 'Valid') {
        throw 'OpenSSH Server capability reinstallation did not pass component validation.'
    }
    if (-not (Test-Path $configScript)) { throw "Missing LAN SSH configuration script: $configScript" }

    Write-RepairLog 'Applying the backed-up LAN SSH configuration workflow...'
    $powershellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $configScript),
        '-Action', 'Apply',
        '-Port', $Port,
        '-InterfaceAlias', ('"{0}"' -f $InterfaceAlias),
        '-WindowsUser', ('"{0}"' -f $WindowsUser)
    )
    $configProcess = Start-Process -FilePath $powershellPath -ArgumentList ($arguments -join ' ') -Wait -PassThru
    Write-RepairLog "CONFIG_EXIT_CODE=$($configProcess.ExitCode)"
    if ($configProcess.ExitCode -ne 0) { throw 'OpenSSH was reinstalled, but LAN SSH configuration still failed.' }

    Write-RepairLog 'REPAIR_AND_CONFIG=SUCCESS'
    Write-Output "RESULT_DIRECTORY=$resultDirectory"
    exit 0
} catch {
    Write-RepairLog "FATAL=$($_.Exception.Message)"
    Write-Output "RESULT_DIRECTORY=$resultDirectory"
    exit 1
}
