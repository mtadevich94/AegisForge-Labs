# The Wrkstation Chronicles — Windows Garrison — Answer Key
### Most-efficient commands, within the scope list, for every task in the Lab Guide

---

## Module 1 — CMD Navigation & Dir Switches

1. `dir Chronicles /a /s`
2. `dir Chronicles /b /s`
3. `dir Chronicles /a:h` (non-recursive by default — exactly one file: `hidden.txt`)
4. `pushd Chronicles\Subfolder1\Subfolder2` → `cd` (confirms path) → `popd`
5. `dir Chronicles /s /r` → `normal.txt` and `Subfolder1\Subfolder2\deepfile.txt` show more than the default `:$DATA` stream.

---

## Module 2 — File & Folder Operations

1. CMD: `type nul > a.txt`, `type nul > b.txt`, `type nul > c.txt` (or `echo.>file`). PowerShell: `'d.txt','e.txt','f.txt' | ForEach-Object { New-Item -ItemType File -Name $_ }`
2. `copy a.txt %USERPROFILE%\` ; `Copy-Item d.txt $env:USERPROFILE`
3. `ren b.txt b_renamed.txt` ; `Rename-Item e.txt e_renamed.txt`
4. `type ..\Chronicles\warplans.txt` ; `Get-Content ..\Chronicles\warplans.txt`
5. `attrib +h +s c.txt` → `dir /a` shows it → `attrib -h -s c.txt` clears both.
6. From the parent folder: `del /q Scratch\*` then `rmdir Scratch`. `rmdir /s /q Scratch` would have deleted the folder **and everything still inside it** in one shot, without the separate `del` step and without a confirmation prompt — useful, but only once you're sure nothing in there still matters.

---

## Module 3 — PowerShell Discovery Deep Dive

1.
   ```powershell
   Get-ChildItem -Path . -Recurse | Where-Object {$_.BaseName.Length -eq 10 -and $_.Length -eq 512}
   ```
   → matches `Nightshade`. `Get-Acl .\Nightshade | Select-Object Owner` → owner is `Vaultkeeper`.
2. `Get-ChildItem -Recurse | Where-Object {$_.Name -like "*_1?.dat"}` (or any wildcard covering a subset of the 25 junk files).
3. `Get-ChildItem -Recurse -Attributes !Directory`
4. `Get-ChildItem -Recurse | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-24)}` → roughly half the junk files (the other half were backdated 10 days by the setup script).
5. `Get-ChildItem -Recurse -File | Sort-Object Length -Descending | Select-Object -First 3`
6. `Select-String -Path ..\Chronicles\sector_scan.log -Pattern "ERROR"` then narrow with `Select-String -Path ..\Chronicles\sector_scan.log -Pattern "failed login"`.

---

## Module 4 — Ownership & ACLs

1. Notepad reports "You don't currently have permission to access this file."
2. `icacls locked.txt` → a `DENY` entry for your own domain/account with `(F)` (Full control).
3. `takeown /f locked.txt`
4. `icacls locked.txt /grant "$env:USERDOMAIN\$env:USERNAME:F"`
5. Locked.txt now opens and saves normally.
6. `icacls . /save acl_backup.txt /t` (run from inside `Chronicles`, or give the full path).
7. `icacls warplans.txt` (or `(Get-Acl warplans.txt).Owner`) → `General_Graardor`, unchanged.

---

## Module 5 — Alternate Data Streams

1. `dir /s /r` inside `Chronicles` — `normal.txt` and `deepfile.txt` both show a stream beyond `:$DATA`.
2.
   ```powershell
   Get-ChildItem -Recurse -Force |
       ForEach-Object { Get-Item -Path $_.FullName -Stream * -ErrorAction SilentlyContinue } |
       Where-Object { $_.Stream -ne ':$DATA' } |
       Select-Object FileName, Stream
   ```
3. `Get-Content -Path normal.txt -Stream payload`
4. `Remove-Item -Path normal.txt -Stream payload` — `normal.txt` itself still opens fine afterward; `deepfile.txt`'s `notes` stream is untouched.

---

## Module 6 — Process Discovery & Filtering

1. `Get-Process | Format-List Name, Id, Path`
2.
   ```powershell
   Get-CimInstance Win32_Process | Where-Object {$_.CommandLine -like "*100000*"} | Select-Object ProcessId, CommandLine
   ```
   → identifies the specific `powershell.exe` PID running the `WizardTower` sleep.
3. `Get-Process | Where-Object {$_.Id -eq <PID from step 2>}`
4. `Get-Process | Where-Object {$_.Name -match "powershell"}` — returns every PowerShell host process on the box, not just the one you want; this is why step 2's `CommandLine` filter mattered.
5. `Get-Process | Sort-Object CPU -Descending | Select-Object -First 5`

---

## Module 7 — Process ↔ Service Mapping

1. First get the PID: `Get-CimInstance Win32_Service -Filter "Name='Spooler'"` → note `ProcessId`. Then `tasklist /svc | findstr <PID>`.
2. `Get-CimInstance Win32_Service -Filter "Name='Spooler'" | Select-Object Name, ProcessId, State`
3. `Get-CimInstance Win32_Service | Where-Object {$_.ProcessId -eq <PID>} | Select-Object Name, DisplayName, State`
4. `Get-Service Spooler` → `Stop-Service Spooler` → `Get-Service Spooler` (Stopped) → `Start-Service Spooler`.
5. `taskkill /PID <pid> /F` (from Module 6, step 2) — then restart with `Start-ScheduledTask -TaskName "WizardTower"` and get the new PID again — then `Stop-Process -Name powershell -Force`. **Risk:** this second form kills *every* process literally named `powershell.exe`, which on a real box could include other users' sessions or your own terminal if it's hosted in `powershell.exe` rather than `pwsh.exe`/Windows Terminal's conhost. In production, always prefer killing by a verified `-Id`, not by name, once you've confirmed which PID you actually mean.
6. `net start` ; `Get-Service | Where-Object {$_.Status -eq "Running"}`

---

## Module 8 — Users, Groups & Shares

1. `net user` ; `Get-LocalUser`
2. `net localgroup Gielinor` ; `Get-LocalGroupMember -Group Gielinor`
3.
   ```powershell
   New-LocalUser -Name "Feyd" -FullName "Harkonnen Heir" `
     -Password (ConvertTo-SecureString "ChangeMe123!" -AsPlainText -Force)
   ```
4. `Add-LocalGroupMember -Group Arrakis -Member Feyd` ; `Get-LocalGroupMember -Group Arrakis`
5. `Disable-LocalUser -Name Feyd` → `Get-LocalUser -Name Feyd` (Enabled: False) → `Remove-LocalUser -Name Feyd`
6. `net share` ; `Get-SmbShare` — both list `GielinorArchive`.
7. `net use` ; `Get-SmbMapping` and `Get-PSDrive` — all three show the `Z:` mapping.

---

## Module 9 — Networking Enumeration

1. `netstat -an`
2. `Get-NetTCPConnection -State Listen`
3. `netstat -ano` (rightmost column is the owning PID) → `Get-Process -Id <that PID>` to name it.
4. `netstat -r` ; `Get-NetRoute`
5. `netstat -e` ; `Get-NetAdapterStatistics`

---

## Module 10 — Scheduled Tasks

1. `schtasks /query /tn "WizardTower"` ; `Get-ScheduledTask -TaskName "WizardTower"`
2. `schtasks /query /tn "WizardTower" /fo LIST /v` ; `Get-ScheduledTask -TaskName "WizardTower" | Get-ScheduledTaskInfo`
3.
   ```powershell
   $action  = New-ScheduledTaskAction -Execute "cmd.exe" `
     -Argument '/c type C:\GielinorArchive\Chronicles\warplans.txt >> C:\GielinorArchive\Chronicles\warplans.bak'
   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
     -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration ([TimeSpan]::MaxValue)
   Register-ScheduledTask -TaskName "WarplansBackup" -Action $action -Trigger $trigger
   ```
   (`schtasks /create /tn "WarplansBackup" /tr "cmd /c type C:\GielinorArchive\Chronicles\warplans.txt >> C:\GielinorArchive\Chronicles\warplans.bak" /sc minute /mo 2` is the equivalent one-liner.)
4. `Get-ScheduledTask -TaskName WarplansBackup` to confirm it's registered; after a few minutes, `Get-Item C:\GielinorArchive\Chronicles\warplans.bak` should show a growing file size.
5. `Unregister-ScheduledTask -TaskName WarplansBackup -Confirm:$false` (or `schtasks /delete /tn "WarplansBackup" /f`).

---

## Module 11 — Logs & Event Auditing

1. `Get-EventLog -List`
2. `Get-EventLog -LogName Security -Newest 20`
3. `Get-EventLog -LogName System -EntryType Error`
4. `Get-WinEvent -LogName Security -MaxEvents 20`
5.
   ```powershell
   Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688; StartTime=(Get-Date).AddDays(-1)}
   ```
   Should include entries for the `powershell.exe`/`cmd.exe` launches from Modules 6, 7, and 10 — the setup script's `auditpol /set /subcategory:"Process Creation" /success:enable` is what makes these events exist at all.

---

## Module 12 — Scripting Capstone

**Prompt-for-name function (PowerShell):**
```powershell
function Get-OrCreatePath {
    $name = Read-Host "Enter file or folder name"
    $path = Join-Path -Path (Get-Location) -ChildPath $name

    if (Test-Path -Path $path) {
        Write-Output "Found: $path"
    } else {
        $choice = Read-Host "'$name' not found. Create as folder? (Y/N)"
        if ($choice -match '^[Yy]') {
            New-Item -Path $path -ItemType Directory | Out-Null
            Write-Output "Created folder: $path"
        } else {
            Write-Output "Not created. Path would be: $path"
        }
    }
    return $path
}
Get-OrCreatePath
```
Save as `Get-OrCreatePath.ps1` and run with `.\Get-OrCreatePath.ps1` (you may need `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first if script execution is restricted).

**Batch equivalent:**
```bat
@echo off
set /p name="Enter file or folder name: "
set "target=%CD%\%name%"
if exist "%target%" (
    echo Found: %target%
) else (
    mkdir "%target%"
    echo Created folder: %target%
)
echo Full path: %target%
```

**Batch — search for a file that might exist somewhere under the current tree:**
```bat
@echo off
set /p fname="Enter filename to locate: "
set "found=0"
for /r %%f in ("%fname%") do (
    if exist "%%f" (
        echo Found: %%f
        set "found=1"
    )
)
if "%found%"=="0" echo No matches found.
```

**Completed `Get-AccountStatus.ps1`:**
```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$Username
)

$acct = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

if (-not $acct) {
    Write-Output "No such user"
} elseif (-not $acct.Enabled) {
    Write-Output "Disabled"
} else {
    Write-Output "Active"
}
```

---

## Notes for re-running the lab

- Re-running `Setup-WindowsGarrisonLab.ps1` is safe — local users/groups, the SMB share, and the ADS streams are all created idempotently (existing ones are left alone or silently skipped), and the script explicitly undoes the prior run's restrictive ACLs on `Nightshade` and `locked.txt` before rebuilding them, so a second run doesn't lock itself out of its own files.
- The `WizardTower` scheduled task is unregistered and recreated fresh each run, so its PID will change between runs — don't hardcode a PID anywhere in your own scripts.
- Module 4's `locked.txt` deny entry targets whichever account actually ran the setup script. If you run the script as `GIELINOR\Administrator` but do the lab logged in as a different account, the deny entry won't apply to you and Module 4 will look like it's already unlocked — re-run the setup script while logged in as the account you intend to do the lab as.
- Module 11's Event ID 4688 results depend on Process Creation auditing staying enabled (`auditpol /set /subcategory:"Process Creation" /success:enable`) — reverting to a pre-setup snapshot will also revert that audit policy setting, so re-run the setup script (or re-enable it manually) after any revert.
- The Security event log has a size cap; on a long-lived VM that's seen a lot of process activity, very old 4688 events may have rolled off — this doesn't affect the lab as written since it only asks for the last 24 hours.
