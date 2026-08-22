param(
    [ValidateSet('Apply', 'Status', 'Rollback')]
    [string]$Action = 'Status',

    [ValidateRange(1024, 65535)]
    [int]$Port = 2222,

    [string]$InterfaceAlias = 'WLAN',

    [string]$WindowsUser = $env:USERNAME
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $env:TEMP 'codex-windows-lan-ssh.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing configuration script: $scriptPath" }

$powershellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', ('"{0}"' -f $scriptPath),
    '-Action', $Action,
    '-Port', $Port,
    '-InterfaceAlias', ('"{0}"' -f $InterfaceAlias),
    '-WindowsUser', ('"{0}"' -f $WindowsUser)
)
$process = Start-Process -FilePath $powershellPath -Verb RunAs -ArgumentList ($arguments -join ' ') -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Elevated Windows LAN SSH task exited with code $($process.ExitCode)." }

