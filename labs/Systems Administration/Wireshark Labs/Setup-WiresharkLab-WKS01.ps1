<#
.SYNOPSIS
  The Wrkstation Chronicles: Packet Watch -- WKS01 (Windows 11) setup. Lab version 1.0.0

.DESCRIPTION
  Run as Administrator on WKS01. It:
    1. Installs Wireshark (via winget) if it is not already installed.
    2. Creates C:\GielinorWatch\ and copies the lab's pcaps + traffic generator there.
    3. Checks that WKS01 can reach the Watchtower server (10.10.10.30) and resolve its DNS name.

  Place this script in the same folder as 'Invoke-GarrisonTraffic.ps1' and the 'pcaps' folder
  (i.e. run it from the unzipped 'Wireshark Labs' folder).

  !! Isolated lab VM only. !!

.EXAMPLE
  Set-ExecutionPolicy -Scope Process Bypass -Force
  .\Setup-WiresharkLab-WKS01.ps1
#>
[CmdletBinding()]
param(
    [string]$ServerIP   = '10.10.10.30',
    [string]$ServerName = 'watchtower.gielinor.local',
    [string]$LabRoot    = 'C:\GielinorWatch'
)

$ErrorActionPreference = 'Stop'
function Say($m)  { Write-Host "[packet-watch] $m" -ForegroundColor Yellow }
function Good($m) { Write-Host "  [ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [WARN] $m" -ForegroundColor DarkYellow }
function Bad($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red }

# --- must be admin ------------------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Bad 'Run this script from an elevated (Administrator) PowerShell window.'
    exit 1
}

# --- 1. Wireshark ---------------------------------------------------------------
Say 'Step 1/3: Wireshark'
$wsExe = 'C:\Program Files\Wireshark\Wireshark.exe'
if (Test-Path $wsExe) {
    Good 'Wireshark already installed.'
} else {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Say 'Installing Wireshark with winget (this can take a few minutes)...'
        try {
            winget install --id WiresharkFoundation.Wireshark -e --accept-package-agreements --accept-source-agreements --silent
        } catch { Warn "winget reported an error: $($_.Exception.Message)" }
    } else {
        Warn 'winget is not available on this VM.'
    }
    if (Test-Path $wsExe) {
        Good 'Wireshark installed.'
    } else {
        Warn 'Wireshark was not installed automatically.'
        Warn 'Install it by hand: https://www.wireshark.org/download.html -- keep the "Npcap" box ticked, accept the defaults, then re-run this script.'
    }
}

# Npcap is what lets Wireshark capture live traffic on Windows.
if (Get-Service -Name npcap -ErrorAction SilentlyContinue) {
    Good 'Npcap capture driver present (live capture will work).'
} else {
    Warn 'Npcap not detected -- you can still open the pcaps, but live capture needs it. Re-run the Wireshark installer and tick Npcap.'
}

# --- 2. lab folder ----------------------------------------------------------------
Say "Step 2/3: lab folder $LabRoot"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Force -Path "$LabRoot\pcaps", "$LabRoot\captures" | Out-Null

$copied = 0
if (Test-Path "$here\pcaps") {
    Get-ChildItem "$here\pcaps" -Filter *.pcap | ForEach-Object {
        Copy-Item $_.FullName "$LabRoot\pcaps\" -Force; $copied++
    }
}
if (Test-Path "$here\Invoke-GarrisonTraffic.ps1") {
    Copy-Item "$here\Invoke-GarrisonTraffic.ps1" "$LabRoot\" -Force
    Good 'Copied Invoke-GarrisonTraffic.ps1'
} else {
    Warn 'Invoke-GarrisonTraffic.ps1 not found next to this script -- copy it into the lab folder manually.'
}
if ($copied -gt 0) { Good "Copied $copied pcap file(s) to $LabRoot\pcaps" }
else { Warn "No pcaps found in '$here\pcaps' -- download the 'pcaps' folder from the repo and re-run." }

# --- 3. connectivity ----------------------------------------------------------------
Say 'Step 3/3: can WKS01 see Watchtower?'
if (Test-Connection -ComputerName $ServerIP -Count 2 -Quiet) { Good "Ping to $ServerIP works." }
else { Bad "Cannot ping $ServerIP. Check both VMs are on the 'GielinorNAT' NAT Network and the Ubuntu server has IP $ServerIP." }

try {
    $r = Resolve-DnsName $ServerName -Type A -ErrorAction Stop
    Good "DNS: $ServerName -> $(($r | Where-Object Type -eq 'A').IPAddress -join ', ')"
} catch {
    Warn "DNS cannot resolve $ServerName. On DC01 run:"
    Warn "  Add-DnsServerResourceRecordA -Name watchtower -ZoneName gielinor.local -IPv4Address $ServerIP"
    Warn 'The lab needs real DNS lookups on the wire, so avoid the hosts-file shortcut.'
}

foreach ($p in 21, 80, 443) {
    $t = New-Object Net.Sockets.TcpClient
    try {
        $iar = $t.BeginConnect($ServerIP, $p, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(1500) -and $t.Connected) { Good "TCP $p open on Watchtower" } else { Warn "TCP $p not reachable on Watchtower" }
    } catch { Warn "TCP $p not reachable on Watchtower" } finally { $t.Close() }
}

Write-Host ''
Say 'Done. Next: open Wireshark and start with Module 1 of the lab guide.'
Say "Lab files:  $LabRoot"
