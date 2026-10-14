<#
.SYNOPSIS
  The Wrkstation Chronicles: Tiered Admin -- member machine prep (SRV01 and WKS01).  Lab version 1.0.0

.DESCRIPTION
  Run in an elevated PowerShell on EACH member machine:
     SRV01 (Windows Server 2022)  ->  -Role Server
     WKS01 (Windows 11)           ->  -Role Workstation

  It:
    1. (Optional) pins a static IP address            -StaticIP 10.10.10.40  /  10.10.10.20
    2. Enables RDP, WinRM (PowerShell remoting), and remote event-log access
    3. Turns on logon auditing
    4. Plants a "legacy" scheduled task that runs as a Domain Admin -- the kind of thing
       that quietly leaves privileged credentials on a lower-tier machine:
         SRV01 : KeepNightlyBackup      runs as GIELINOR\svc-backup  (Domain Admin)
         WKS01 : VillageInventoryCheck  runs as GIELINOR\Navi        (Domain Admin)
       (Only created once the machine is domain-joined and DC01's baseline script has run.)

  Idempotent. !! ISOLATED LAB ONLY. !!

.EXAMPLE
  # on SRV01
  .\Setup-TieredAdminLab-Member.ps1 -Role Server -StaticIP 10.10.10.40
  # on WKS01
  .\Setup-TieredAdminLab-Member.ps1 -Role Workstation -StaticIP 10.10.10.20
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Server','Workstation')][string]$Role,
    [string]$StaticIP,
    [int]$PrefixLength = 24,
    [string]$Gateway   = '10.10.10.1',
    [string]$DnsServer = '10.10.10.10',
    [string]$LabPassword = 'Gielinor!Lab#2026',
    [string]$NetBios = 'GIELINOR'
)

$ErrorActionPreference = 'Stop'
function Say($m)  { Write-Host "[tiered-admin] $m" -ForegroundColor Yellow }
function Good($m) { Write-Host "  [ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [WARN] $m" -ForegroundColor DarkYellow }
function Bad($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red }

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Bad 'Run this from an elevated (Administrator) PowerShell window.'; exit 1
}
New-Item -ItemType Directory -Force -Path 'C:\GielinorTiered' | Out-Null

# --- 1. static IP ------------------------------------------------------------------------------
Say 'Step 1/4: network'
if ($StaticIP) {
    $nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
    if (-not $nic) { Bad 'No active network adapter found.'; exit 1 }
    $cur = Get-NetIPAddress -InterfaceAlias $nic.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cur -and $cur.IPAddress -eq $StaticIP -and $cur.PrefixOrigin -eq 'Manual') {
        Good "Already using static $StaticIP"
    } else {
        Say "Setting $($nic.Name) to $StaticIP/$PrefixLength (your session may drop for a moment)..."
        Set-NetIPInterface -InterfaceAlias $nic.Name -Dhcp Disabled
        Get-NetIPAddress -InterfaceAlias $nic.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $nic.Name -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -InterfaceAlias $nic.Name -IPAddress $StaticIP -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
        Set-DnsClientServerAddress -InterfaceAlias $nic.Name -ServerAddresses $DnsServer
        Good "Static IP set: $StaticIP  (DNS $DnsServer, gateway $Gateway)"
    }
} else {
    Warn 'No -StaticIP given; leaving addressing as it is. (The guide assumes SRV01=10.10.10.40, WKS01=10.10.10.20, DC01=10.10.10.10.)'
}

# --- 2. remote management -----------------------------------------------------------------------
Say 'Step 2/4: remote access (RDP, WinRM, remote event logs)'
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue
Good 'Remote Desktop enabled'
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
    Good 'PowerShell remoting (WinRM) enabled'
} catch { Warn "WinRM: $($_.Exception.Message)" }
foreach ($grp in 'Remote Event Log Management','Windows Management Instrumentation (WMI)','File and Printer Sharing') {
    Enable-NetFirewallRule -DisplayGroup $grp -ErrorAction SilentlyContinue
}
Good 'Remote event log / WMI / ping firewall rules enabled'

# --- 3. auditing ------------------------------------------------------------------------------------
Say 'Step 3/4: logon auditing'
foreach ($sub in 'Logon','Logoff','Special Logon','Credential Validation') {
    & auditpol.exe /set /subcategory:"$sub" /success:enable /failure:enable | Out-Null
}
Good 'Audit subcategories enabled (Logon, Logoff, Special Logon, Credential Validation)'

# --- 4. legacy privileged task --------------------------------------------------------------------------
Say 'Step 4/4: legacy scheduled task (stores a privileged credential on this machine)'
$cs = Get-CimInstance Win32_ComputerSystem
if (-not $cs.PartOfDomain) {
    Warn 'This machine is not domain-joined yet. Join it to gielinor.local, then re-run this script to plant the legacy task.'
} else {
    if ($Role -eq 'Server') { $taskName = 'KeepNightlyBackup';     $runAs = "$NetBios\svc-backup"; $cmd = 'cmd.exe /c echo backup ok %date% %time% >> C:\GielinorTiered\backup.log' ; $sched = @('/SC','DAILY','/ST','02:00') }
    else                    { $taskName = 'VillageInventoryCheck'; $runAs = "$NetBios\Navi";       $cmd = 'cmd.exe /c echo inventory ok %date% %time% >> C:\GielinorTiered\inventory.log'; $sched = @('/SC','MINUTE','/MO','30') }
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    schtasks.exe /Query /TN $taskName *> $null
    $taskExists = ($LASTEXITCODE -eq 0)
    if ($taskExists) {
        Good "Task $taskName already exists"
    } else {
        $schArgs = @('/Create','/TN',$taskName,'/TR',$cmd) + $sched + @('/RU',$runAs,'/RP',$LabPassword,'/RL','HIGHEST','/F')
        $out = & schtasks.exe @schArgs 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Good "Created task $taskName running as $runAs"
            & schtasks.exe /Run /TN $taskName *> $null
            Good 'Ran it once now (so a batch-logon event exists to find in Module 1)'
        } else {
            Warn "Could not create the task (has DC01's baseline script been run, and can this machine reach DC01?): $out"
        }
    }
    $ErrorActionPreference = $prevEap
}

Write-Host ''
Say "Member prep complete for role: $Role"
Say 'Next: make sure this VM is joined to gielinor.local, then snapshot it as tiered-baseline.'
