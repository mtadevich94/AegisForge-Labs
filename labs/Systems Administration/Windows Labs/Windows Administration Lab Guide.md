# The Wrkstation Chronicles — Windows Garrison
### Student Lab Guide

**Environment:** `WKS01` — Windows 11 Enterprise, joined to `gielinor.local` (see the Domain Setup & Workstation Join Guide)
**Setup:** log in as an administrator on WKS01 and run `Setup-WindowsGarrisonLab.ps1` once, then **snapshot the VM**.
**How to use this guide:** work module by module. Each task tells you *what* to find or do — figure out the command yourself first, then check the Answer Key only if you're stuck or want to confirm. Commands are shown in whichever of CMD or PowerShell fits the task; several tasks deliberately ask for both so you can feel the difference.

---

## Access — Log into the Garrison
*Commands: none yet — just getting to a prompt*

1. Start `WKS01` in VirtualBox.
2. Sign in as a local administrator (or `GIELINOR\student` if you've given that account admin rights) — you need an elevated PowerShell/CMD prompt for most of this lab, so right-click the Start button and choose **Windows Terminal (Admin)** / **Terminal (Admin)**.

---

## Module 1 — CMD Navigation & Dir Switches
*Commands: cd, dir, dir /a, /a:h, /b, /s, /r, pushd, popd*
*Working folder: `C:\GielinorArchive\Chronicles`*

1. From `C:\GielinorArchive`, using **one** `dir` command, list every file and folder under `Chronicles` — *including* hidden/system ones — recursively.
2. List *only the names* (no header, no summary line) of every file under `Chronicles`, recursively — the kind of bare output you'd pipe into `findstr` or redirect to a file.
3. List only the hidden files directly inside `Chronicles` (not recursive).
4. Navigate into `Chronicles\Subfolder1\Subfolder2` using `pushd`, confirm you're there, then jump back to where you started using `popd`.
5. Using CMD's `dir /r` on `Chronicles`, recursively, spot which file(s) show more than the default `:$DATA` stream — don't worry about interpreting it yet, that's Module 5.

**Verify yourself:** task 1 should surface `hidden.txt` even though a plain `dir` doesn't. Task 3 should show exactly one file.

---

## Module 2 — File & Folder Operations
*Commands: copy, xcopy, robocopy, move, ren, del, mkdir, rmdir, attrib, and their PowerShell equivalents (New-Item, Copy-Item, Move-Item, Rename-Item, Remove-Item, Get-Content, Set-Location)*
*Working folder: `C:\GielinorArchive\Scratch`*

1. From `Scratch`, create three files named `a.txt`, `b.txt`, `c.txt` using CMD, then do the same for `d.txt`, `e.txt`, `f.txt` using PowerShell's `New-Item`.
2. Copy `a.txt` out to your own user profile folder using `copy` (CMD), then copy `d.txt` there using `Copy-Item` (PowerShell).
3. Rename `b.txt` to `b_renamed.txt` with `ren`, and rename `e.txt` to `e_renamed.txt` with `Rename-Item`.
4. View the contents of `warplans.txt` (in `..\Chronicles`) with `type` (CMD), then again with `Get-Content` (PowerShell) — same output, different tool.
5. Set the hidden **and** system attributes on `c.txt` with `attrib`, confirm with `dir /a`, then clear both attributes again.
6. Clean up: delete every file in `Scratch` and remove the (now-empty) folder — once with `del` / `rmdir`, and describe in one sentence what `rmdir /s /q` would have done differently if the folder still had files in it.

---

## Module 3 — PowerShell Discovery Deep Dive
*Commands: Get-ChildItem (-Recurse, -Force, -Filter, -Attributes), Where-Object (-like, -match, -gt/-lt), Sort-Object, Select-String*
*Working folder: `C:\GielinorArchive\ShadowFiles`*

1. **The Vault Puzzle:** inside `ShadowFiles`, find the one file that has a name **exactly 10 characters long** and a size of **exactly 512 bytes**, using a single `Get-ChildItem -Recurse` piped through `Where-Object`. Report the filename, then check who owns it with `Get-Acl`.
2. From that same recursive listing, filter down to only files whose name matches a wildcard pattern of your choosing (e.g. `*_1?.dat`).
3. Filter to files only (no directories) using the `-Attributes` parameter rather than piping to `Where-Object`.
4. Find every file under `ShadowFiles` **modified in the last 24 hours** — you should get roughly half the files (the setup script backdated the rest).
5. Sort every file under `ShadowFiles` by size, descending, and show the top 3.
6. In `..\Chronicles`, use `Select-String` against `sector_scan.log` to find every line containing `ERROR`, then narrow it further to just the line mentioning a failed login.

**Verify yourself:** task 1 should identify `Nightshade`, owned by `Vaultkeeper`.

---

## Module 4 — Ownership & ACLs
*Commands: icacls, takeown*
*Working folder: `C:\GielinorArchive\Chronicles`*

1. Try to open `locked.txt` and edit it. Confirm you're denied.
2. Run `icacls` on `locked.txt` and identify the **deny** entry — whose account is it denying, and what permission?
3. Take ownership of `locked.txt` with `takeown`.
4. Grant yourself Full Control back on `locked.txt` with `icacls /grant`.
5. Confirm you can now open and edit `locked.txt`.
6. Before you touch anything else, save a backup of the whole `Chronicles` folder's ACLs to a file with `icacls ... /save` — this is standard practice before making bulk permission changes in the real world.
7. Separately, on `warplans.txt`: confirm with `icacls` (or `Get-Acl`) that the file is owned by `General_Graardor`, without changing anything.

**Verify yourself:** step 5 should succeed. If it doesn't, recheck step 4's syntax — `/grant` needs a `user:permission` pair.

---

## Module 5 — Alternate Data Streams (ADS)
*Commands: dir /r, Get-Item -Stream, Get-Content -Stream, Remove-Item -Stream*
*Working folder: `C:\GielinorArchive\Chronicles`*

1. Using CMD's `dir /s /r`, scan `Chronicles` recursively and note which file(s) appear to carry more than the default data stream.
2. Using PowerShell, scan `Chronicles` recursively and produce a clean list of *file path + stream name* for every non-default stream — this should catch both the one CMD made you squint at, and one CMD's `dir /r` output is easy to miss entirely.
3. Read the contents of the `payload` stream on `normal.txt` without deleting anything.
4. Delete just the `payload` stream, leaving `normal.txt` itself intact. Confirm the file still opens normally afterward and the stream is gone.

**Verify yourself:** after step 4, repeating step 2 should show one fewer result than before, and `Subfolder1\Subfolder2\deepfile.txt`'s `notes` stream should still be present.

---

## Module 6 — Process Discovery & Filtering
*Commands: Get-Process, tasklist, Format-List, Select-Object, Sort-Object*

1. List all currently running processes, formatted as a list showing `Name`, `Id`, and `Path` only.
2. Find the PID of the background process launched by the `WizardTower` scheduled task — it's a `powershell.exe` process, so filtering by name alone will return several; use `Get-CimInstance Win32_Process` and filter on `CommandLine` to pin down the right one.
3. Filter `Get-Process` down to just that PID using `-eq`.
4. Now filter using `-match` on the *name* `powershell` instead — note how many more results come back compared to step 3.
5. Show the top 5 processes by CPU usage.

---

## Module 7 — Process ↔ Service Mapping
*Commands: tasklist /svc, Get-CimInstance Win32_Service, taskkill, Stop-Process, sc, Get-Service, net start*

1. Using CMD's `tasklist /svc`, find which services are hosted inside the `svchost.exe` PID that owns the **Spooler** (Print Spooler) service.
2. Reproduce that answer in PowerShell using `Get-CimInstance Win32_Service`, filtered by service name `Spooler`, showing `Name`, `ProcessId`, and `State`.
3. Reverse it: starting from the PID, confirm every service hosted in that same process using `Win32_Service` filtered on `ProcessId`.
4. Check the status of the `Spooler` service with `Get-Service`, stop it, confirm it's stopped, then start it again.
5. **End the WizardTower task's process two ways:** once by PID with `taskkill` (or `Stop-Process`), and — after restarting the task — once by name with `Stop-Process -Name powershell` (careful: on a real machine this would kill *every* PowerShell process; note in your answer why that's risky and what you'd do differently in production).
   - Restart the task with: `Start-ScheduledTask -TaskName "WizardTower"`
6. List every currently running service with `net start` (CMD), then reproduce the same list with `Get-Service | Where-Object {$_.Status -eq "Running"}`.

---

## Module 8 — Users, Groups & Shares
*Commands: net user, net localgroup, net share, net use, Get-LocalUser, New-LocalUser, Get-LocalGroupMember, Add-LocalGroupMember, Get-SmbShare, Get-SmbMapping*

1. List every local user account with `net user`, then again with `Get-LocalUser`.
2. Show the members of the `Gielinor` local group with `net localgroup Gielinor`, then again with `Get-LocalGroupMember`.
3. Create a new local user `Feyd` with a full name of "Harkonnen Heir" using `New-LocalUser` (you'll need to supply a password as a secure string).
4. Add `Feyd` to the `Arrakis` group using `Add-LocalGroupMember`, then confirm with `Get-LocalGroupMember -Group Arrakis`.
5. Disable `Feyd`'s account with `Disable-LocalUser`, confirm the change with `Get-LocalUser -Name Feyd`, then delete the account entirely with `Remove-LocalUser`.
6. List shared folders on this machine with `net share`, then with `Get-SmbShare` — you should see `GielinorArchive` in both.
7. Show mapped network drives with `net use`, then with `Get-SmbMapping` and `Get-PSDrive` — you should see the `Z:` mapping the setup script created.

---

## Module 9 — Networking Enumeration
*Commands: netstat, Get-NetTCPConnection, Get-NetUDPEndpoint, Get-NetRoute, Get-NetAdapterStatistics*

1. Show all active TCP connections and listening ports, with **numeric** addresses and ports (no DNS/service-name resolution), using `netstat`.
2. Reproduce the listening-ports view in PowerShell with `Get-NetTCPConnection -State Listen`.
3. Show the same output as `netstat -ano` (which adds the owning PID), then map one of those PIDs back to a process name with `Get-Process -Id`.
4. Show the routing table with `netstat -r`, then with `Get-NetRoute`.
5. Show interface statistics (bytes sent/received) with `netstat -e`, then with `Get-NetAdapterStatistics`.

---

## Module 10 — Scheduled Tasks
*Commands: schtasks, Get-ScheduledTask, Register-ScheduledTask, New-ScheduledTaskTrigger, New-ScheduledTaskAction, Unregister-ScheduledTask, Start-ScheduledTask, Stop-ScheduledTask*

1. View any existing scheduled task named `WizardTower` with `schtasks /query /tn "WizardTower"`, then again with `Get-ScheduledTask -TaskName "WizardTower"`.
2. Get full detail on it, including last run time, with `schtasks /query /tn "WizardTower" /fo LIST /v`, then with `Get-ScheduledTask -TaskName "WizardTower" | Get-ScheduledTaskInfo`.
3. Create your **own** scheduled task, `WarplansBackup`, that runs every 2 minutes and appends the contents of `C:\GielinorArchive\Chronicles\warplans.txt` into `C:\GielinorArchive\Chronicles\warplans.bak` — build the action and trigger with `New-ScheduledTaskAction` / `New-ScheduledTaskTrigger`, then `Register-ScheduledTask`. (If you'd rather do it the old-fashioned way, `schtasks /create` with a `/sc minute /mo 2` schedule and a small wrapper command works too.)
4. Confirm it's listed, wait for it to fire at least twice, and verify `warplans.bak` grew.
5. Stop and remove `WarplansBackup` when you're done, using `Unregister-ScheduledTask` (or `schtasks /delete /tn "WarplansBackup" /f`).

---

## Module 11 — Logs & Event Auditing
*Commands: Get-EventLog, Get-WinEvent, -FilterHashtable*

1. List every classic event log available on this machine with `Get-EventLog -List`.
2. Pull the 20 most recent entries from the Security log with `Get-EventLog -LogName Security -Newest 20`.
3. Pull only Error-level entries from the System log using `Get-EventLog -LogName System -EntryType Error`.
4. Do the modern equivalent of task 2 using `Get-WinEvent -LogName Security -MaxEvents 20`.
5. Use `Get-WinEvent` with a `-FilterHashtable` to pull Event ID **4688** (process creation) from the Security log for the last 24 hours — the setup script enabled this auditing category, so you should get real hits, including the `WizardTower` and `WarplansBackup` task launches from earlier modules.

**Verify yourself:** if task 5 returns zero rows, double-check that Process Creation auditing is actually enabled: `auditpol /get /subcategory:"Process Creation"`.

---

## Module 12 — Scripting Capstone
*Files: a new function/script you write, plus `C:\GielinorArchive\Scripts\Get-AccountStatus.ps1`*

1. **Prompt-for-name pattern (write from scratch):** write a PowerShell function that prompts the user for a name and:
   - if a file/folder with that name exists in the current directory, prints its full path
   - if it doesn't exist, asks whether to create it as a folder, creates it if yes, and returns the path either way
2. Convert your function into a standalone `.ps1` script file and run it directly (not just pasted into a live session).
3. Write the CMD/batch equivalent as a `.bat` file: prompt for a name with `set /p`, check existence with `if exist`, create the folder with `mkdir` if missing, and echo the final full path.
4. Extend the batch version: instead of assuming a folder, use `for /r` to search the current tree for a *file* matching the entered name and print every match found (handle the case where there are zero matches).
5. **Complete the skeleton:** open `C:\GielinorArchive\Scripts\Get-AccountStatus.ps1` and finish the `if / elseif / else` logic so that `.\Get-AccountStatus.ps1 -Username <name>` prints `No such user`, `Disabled`, or `Active` as appropriate. Test it against a real account, `Feyd` if you disabled rather than deleted them in Module 8, and a made-up username.

**Verify yourself:** run each script twice — once with a name/username that already exists, once with one that doesn't — and confirm both branches of your logic actually fire.

---

## Wrap-up

By the end of this lab you should be able to, from memory, under time pressure:
- Navigate and search the filesystem with both CMD's `dir` switches and PowerShell's `Get-ChildItem`/`Where-Object`
- Find, read, and remove hidden Alternate Data Streams
- Diagnose and fix a permissions lockout with `takeown` and `icacls`
- Correlate a running process back to the service or scheduled task that spawned it
- Manage local users, groups, and shares from both `net` commands and their PowerShell equivalents
- Enumerate network connections and routes with numeric, unresolved output
- Build and tear down a scheduled task
- Pull a targeted audit trail out of the Security event log
- Write the same small piece of logic in both PowerShell and batch

Good luck out there, Garrison Keeper.
