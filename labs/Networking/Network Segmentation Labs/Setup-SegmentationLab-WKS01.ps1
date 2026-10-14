<#
.SYNOPSIS
  The Wrkstation Chronicles: The Gatehouse -- WKS01 setup (Garrison workstation).

.DESCRIPTION
  Prepares your existing Windows 11 lab VM (WKS01) to be the "Garrison" client in the
  Network Segmentation lab:

    * Opens inbound TCP 8080 in Windows Defender Firewall and starts a tiny listener
      (the "canary") so other zones have a real service to try -- and fail -- to reach.
      Without it you could not tell "the OPNsense firewall blocked me" from "Windows
      Firewall blocked me".
    * Allows inbound ping (ICMPv4 echo) so basic connectivity checks work.
    * Shows your current IP address so you can confirm DHCP from the firewall worked.

  It does NOT change your IP address (the lab gets it from the firewall by DHCP),
  join or leave a domain, or touch your Windows or Wireshark lab files.

  !! ISOLATED LAB VM ONLY. The canary answers anyone who connects to port 8080. !!

.PARAMETER Remove
  Undo everything this script created (canary task, listener file, firewall rules).

.EXAMPLE
  # In an elevated PowerShell on WKS01:
  powershell -ExecutionPolicy Bypass -File .\Setup-SegmentationLab-WKS01.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Setup-SegmentationLab-WKS01.ps1 -Remove

.NOTES
  Lab version 1.0.0.
#>
[CmdletBinding()]
param(
  [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$LabDir   = 'C:\GielinorGatehouse'
$Canary   = Join-Path $LabDir 'canary.ps1'
$TaskName = 'GatehouseCanary'
$RuleTcp  = 'Gatehouse lab - canary TCP 8080'
$RuleIcmp = 'Gatehouse lab - ICMPv4 echo'

function Say([string]$Message) { Write-Host "[gatehouse] $Message" -ForegroundColor Cyan }

# ---- must be Administrator ------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error 'Please run this script from an elevated PowerShell (right-click -> Run as administrator).'
  exit 1
}

# ---- remove mode ------------------------------------------------------------------
if ($Remove) {
  Say 'Removing the canary and its firewall rules...'
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  }
  # The listener runs inside a powershell.exe started by the task; stop any copy still holding the port.
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*canary.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Get-NetFirewallRule -DisplayName $RuleTcp  -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  Get-NetFirewallRule -DisplayName $RuleIcmp -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  if (Test-Path $Canary) { Remove-Item $Canary -Force }
  Say 'Done.'
  exit 0
}

# ---- listener script --------------------------------------------------------------
Say "Creating $LabDir ..."
New-Item -ItemType Directory -Path $LabDir -Force | Out-Null

$listener = @'
# Gatehouse lab canary: answers every connection on TCP 8080 with a tiny HTTP page.
$body = 'Garrison workstation canary - FORGE{the_garrison_was_reachable_from_the_wrong_zone}'
$bytes = [System.Text.Encoding]::ASCII.GetBytes($body)
$header = "HTTP/1.1 200 OK`r`nContent-Type: text/plain`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
$headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, 8080)
$listener.Start()
while ($true) {
  try {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $stream.Write($headerBytes, 0, $headerBytes.Length)
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush()
    } catch { }
    finally { $client.Close() }
  } catch { Start-Sleep -Milliseconds 200 }
}
'@
Set-Content -Path $Canary -Value $listener -Encoding ASCII

# ---- scheduled task: start at boot as SYSTEM, and start it now --------------------------
Say 'Registering the canary as a scheduled task (starts at boot)...'
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
             -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Canary`""
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principalT = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
  -Principal $principalT -Settings $settings -Description 'Gatehouse segmentation lab canary listener' | Out-Null
Start-ScheduledTask -TaskName $TaskName

# ---- Windows Defender Firewall rules ------------------------------------------------------
Say 'Opening TCP 8080 and ICMP echo in Windows Defender Firewall...'
Get-NetFirewallRule -DisplayName $RuleTcp  -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Get-NetFirewallRule -DisplayName $RuleIcmp -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $RuleTcp -Direction Inbound -Protocol TCP -LocalPort 8080 `
  -Action Allow -Profile Any | Out-Null
New-NetFirewallRule -DisplayName $RuleIcmp -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
  -Action Allow -Profile Any | Out-Null

# ---- self-test ---------------------------------------------------------------------------------
Say 'Self-test...'
Start-Sleep -Seconds 3
$ok = $false
try {
  $c = New-Object System.Net.Sockets.TcpClient
  $t = $c.ConnectAsync('127.0.0.1', 8080)
  if ($t.Wait(3000) -and $c.Connected) { $ok = $true }
  $c.Close()
} catch { $ok = $false }

if ($ok) { Write-Host '  canary :8080  listening' -ForegroundColor Green }
else     { Write-Host '  canary :8080  NOT answering -- see Troubleshooting ("The WKS01 canary is not answering")' -ForegroundColor Red }

Write-Host ''
Say 'Your current IPv4 addresses:'
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
  Select-Object InterfaceAlias, IPAddress, PrefixLength | Format-Table -AutoSize | Out-String | Write-Host

Write-Host 'Expected once WKS01 is on the Garrison network: an address like 10.20.10.100 (from the firewall''s DHCP).'
Write-Host 'Next step: return to the Environment Setup guide.'
