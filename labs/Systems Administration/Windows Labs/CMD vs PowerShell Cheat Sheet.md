# CMD vs PowerShell Cheat Sheet

Every classic Command Prompt (CMD) command you meet in the [Windows Administration Lab Guide](Windows%20Administration%20Lab%20Guide.md), next to its PowerShell equivalent.

> **Why learn both?** CMD commands work everywhere and show up in old scripts and attacker tooling. PowerShell is the modern tool, and it returns **objects** instead of plain text, so you can filter and sort the results properly. Defenders need to read both.

**Open each one:** CMD is `cmd.exe`. PowerShell is `powershell.exe` (Windows PowerShell 5.1, built in) or `pwsh.exe` (PowerShell 7, if installed). Run either **as Administrator** when a command changes the system.

**Pipe characters in the tables.** In a table, `\|` is a pipe (`|`). Type a plain `|` in the shell.

**Shortcut:** most CMD habits work in PowerShell because of built-in aliases. `dir`, `cd`, `cls`, `copy`, `del`, `type` and `ls` all run in PowerShell. They are shortcuts for the longer commands below, and they don't take CMD's `/switches`.

---

## 1. dir: list files

| CMD | PowerShell |
|---|---|
| `dir` | `Get-ChildItem` (aliases `gci`, `ls`, `dir`) |
| `dir /a` (include hidden and system files) | `Get-ChildItem -Force` |
| `dir /a:h` (hidden only) | `Get-ChildItem -Hidden` |
| `dir /b` (names only) | `(Get-ChildItem).Name` |
| `dir /s` (include subfolders) | `Get-ChildItem -Recurse` |
| `dir /r` (show alternate data streams) | `Get-ChildItem -Recurse \| ForEach-Object { Get-Item $_.FullName -Stream * }` |
| `dir /a /s /r` (everything, with streams) | `Get-ChildItem -Recurse -Force \| ForEach-Object { Get-Item $_.FullName -Stream * -ErrorAction SilentlyContinue } \| Where-Object { $_.Stream -ne ':$DATA' }` |

The last row keeps only the **extra** streams. Every file has a main stream called `:$DATA`, so filtering it out leaves just the hidden ones.

---

## 2. echo: print text and write files

| CMD | PowerShell |
|---|---|
| `echo text` | `Write-Output "text"` or just `"text"` |
| `echo text > file.txt` (overwrite) | `Set-Content file.txt "text"` |
| `echo text >> file.txt` (append) | `Add-Content file.txt "text"` |
| `echo %VARNAME%` (environment variable) | `$env:VARNAME` |
| `echo off` (top of a script) | not needed. PowerShell doesn't echo commands. |

> **Gotcha.** In Windows PowerShell 5.1, `>` and `Out-File` write **UTF-16** text. Other tools may choke on it. `Set-Content` and `Add-Content` write plain text.
>
> `$env:USERNAME` reads an *environment* variable. A bare `$name` is a PowerShell variable you made yourself, a different thing.

---

## 3. schtasks: scheduled tasks

| CMD | PowerShell |
|---|---|
| `schtasks /query` | `Get-ScheduledTask` |
| `schtasks /query /fo LIST /v` (full detail) | `Get-ScheduledTask \| Get-ScheduledTaskInfo` |
| `schtasks /query /tn "Name"` | `Get-ScheduledTask -TaskName "Name"` |
| `schtasks /create /tn "Name" /tr "cmd" /sc daily /st 09:00` | `Register-ScheduledTask` (you first build the action and trigger with `New-ScheduledTaskAction` and `New-ScheduledTaskTrigger`. Longer, but clearer for complex schedules.) |
| `schtasks /delete /tn "Name" /f` | `Unregister-ScheduledTask -TaskName "Name" -Confirm:$false` |
| `schtasks /run /tn "Name"` | `Start-ScheduledTask -TaskName "Name"` |
| `schtasks /end /tn "Name"` | `Stop-ScheduledTask -TaskName "Name"` |

---

## 4. tasklist and taskkill: processes

| CMD | PowerShell |
|---|---|
| `tasklist` | `Get-Process` |
| `tasklist /svc` (services inside each process) | `Get-CimInstance Win32_Service \| Select-Object Name, ProcessId, State` |
| `tasklist /fi "PID eq 488"` | `Get-Process -Id 488` |
| `tasklist /fi "IMAGENAME eq chrome.exe"` | `Get-Process -Name chrome` |
| `tasklist /v` (verbose) | `Get-Process \| Select-Object Name, Id, StartTime, Path` (no exact match. For the owner, add `Get-CimInstance Win32_Process`.) |
| `tasklist /m` (loaded DLLs) | `(Get-Process -Id 488).Modules` |
| `taskkill /pid 488` | `Stop-Process -Id 488` |
| `taskkill /pid 488 /f` (force) | `Stop-Process -Id 488 -Force` |
| `taskkill /im chrome.exe` | `Stop-Process -Name chrome` |
| `taskkill /im chrome.exe /f /t` (kill the whole tree) | `Get-Process chrome \| Stop-Process -Force` (this does **not** kill child processes. Find children through `Win32_Process` and its `ParentProcessId`.) |

---

## 5. find and findstr: search text

CMD's `find` and `findstr` are case-**sensitive** unless you add `/i`. PowerShell's `Select-String` is the opposite: case-**in**sensitive unless you add `-CaseSensitive`.

| CMD | PowerShell |
|---|---|
| `find "text" file.txt` | `Select-String -Path file.txt -Pattern "text" -SimpleMatch -CaseSensitive` |
| `find /i "text" file.txt` | `Select-String -Path file.txt -Pattern "text" -SimpleMatch` |
| `find /c "text" file.txt` (count lines) | `(Select-String -Path file.txt -Pattern "text").Count` |
| `dir /b \| find "name"` | `Get-ChildItem -Name \| Where-Object { $_ -like "*name*" }` |
| `findstr "text" file.txt` | `Select-String -Path file.txt -Pattern "text" -CaseSensitive` |
| `findstr /i "text" file.txt` | `Select-String -Path file.txt -Pattern "text"` |
| `findstr /s /i "text" *.log` (search subfolders) | `Get-ChildItem -Recurse -Filter *.log \| Select-String -Pattern "text"` |
| `findstr /r "regex.*pattern" file.txt` | `Select-String -Path file.txt -Pattern "regex.*pattern"` (regex is built in, no `/r` needed) |
| `findstr /v "text" file.txt` (lines that do NOT match) | `Select-String -Path file.txt -Pattern "text" -NotMatch` |
| `dir /s /b \| findstr /i "budget"` (find files by name) | `Get-ChildItem -Recurse \| Where-Object { $_.Name -like "*budget*" }` |

---

## 6. netstat: network connections

| CMD | PowerShell |
|---|---|
| `netstat -an` | `Get-NetTCPConnection` (TCP) and `Get-NetUDPEndpoint` (UDP) |
| `netstat -ano` (with owning process ID) | `Get-NetTCPConnection \| Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess` |
| `netstat -an \| findstr LISTENING` | `Get-NetTCPConnection -State Listen` |
| Turn a PID from netstat into a process name | `Get-Process -Id (Get-NetTCPConnection -LocalPort 443).OwningProcess` |
| `netstat -r` (routing table) | `Get-NetRoute` |
| `netstat -e` (interface statistics) | `Get-NetAdapterStatistics` |

---

## 7. sc: services

| CMD | PowerShell |
|---|---|
| `sc query` | `Get-Service` |
| `sc query "ServiceName"` | `Get-Service -Name "ServiceName"` |
| `sc query state= all` | `Get-Service \| Select-Object Name, Status` |
| `sc qc "ServiceName"` (config, including the program path) | `Get-CimInstance Win32_Service -Filter "Name='ServiceName'" \| Select-Object Name, PathName, StartMode, StartName` |
| `sc start "ServiceName"` | `Start-Service -Name "ServiceName"` |
| `sc stop "ServiceName"` | `Stop-Service -Name "ServiceName"` |
| `sc config "ServiceName" start= disabled` | `Set-Service -Name "ServiceName" -StartupType Disabled` |

> In CMD's `sc`, the space after `=` is required: `start= disabled`, not `start=disabled`.

---

## 8. net: users, groups and shares

| CMD | PowerShell |
|---|---|
| `net user` | `Get-LocalUser` |
| `net user username` | `Get-LocalUser -Name username` |
| `net user username password /add` | `New-LocalUser -Name username -Password (ConvertTo-SecureString "password" -AsPlainText -Force)` |
| `net localgroup` | `Get-LocalGroup` |
| `net localgroup Administrators` | `Get-LocalGroupMember -Group Administrators` |
| `net localgroup Administrators username /add` | `Add-LocalGroupMember -Group Administrators -Member username` |
| `net share` | `Get-SmbShare` |
| `net use` (mapped drives) | `Get-SmbMapping` |
| `net start` (running services) | `Get-Service \| Where-Object { $_.Status -eq "Running" }` |
| `net view` (other computers on the network) | No exact match. `Get-NetNeighbor` lists devices your PC has recently talked to. |

> These are for **local** accounts and groups. On a domain controller, the Active Directory commands (`Get-ADUser`, `Get-ADGroupMember`) are the ones you need.

---

## 9. takeown and icacls: ownership and permissions

PowerShell can do this with `Get-Acl` and `Set-Acl`, but it takes several lines. Most administrators simply run the classic `.exe` straight from PowerShell, and that is perfectly normal.

| Task | Easiest way (works in CMD and PowerShell) | Pure PowerShell |
|---|---|---|
| Take ownership of a file | `takeown /f file.txt` | `$acl = Get-Acl file.txt; $acl.SetOwner([System.Security.Principal.NTAccount]"$env:USERNAME"); Set-Acl file.txt $acl` |
| Take ownership of a folder and everything in it | `takeown /f folder /r /d y` | no clean equivalent |
| View permissions | `icacls file.txt` | `Get-Acl file.txt \| Format-List` (less detail) |
| Grant full control | `icacls file.txt /grant user:F` | `$acl = Get-Acl file.txt; $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("user","FullControl","Allow"); $acl.SetAccessRule($rule); Set-Acl file.txt $acl` |
| Reset to inherited permissions | `icacls file.txt /reset` | no clean equivalent |

Note that `takeown` changes the **owner** only. You usually follow it with `icacls ... /grant` to give yourself access.

---

## 10. Files and folders

| CMD | PowerShell |
|---|---|
| `mkdir folder` (or `md`) | `New-Item -Path folder -ItemType Directory` |
| `rmdir folder` (empty folders only) | `Remove-Item folder` |
| `rmdir /s /q folder` (folder and contents, no prompt) | `Remove-Item folder -Recurse -Force` |
| `del file.txt` | `Remove-Item file.txt` |
| `del /f /q file.txt` (force, quiet) | `Remove-Item file.txt -Force` |
| `ren old.txt new.txt` | `Rename-Item old.txt new.txt` |
| `copy src.txt dst.txt` | `Copy-Item src.txt dst.txt` |
| `xcopy src dst /e /h /k` (folders, hidden files, keep attributes) | `Copy-Item src dst -Recurse -Force` |
| `move src.txt dst\` | `Move-Item src.txt dst\` |
| `type file.txt` | `Get-Content file.txt` |
| `cd folder` | `Set-Location folder` (alias `cd`) |
| `attrib +h file.txt` (hide a file) | `(Get-Item file.txt).Attributes += 'Hidden'` |
| `attrib -h file.txt` (unhide it) | `(Get-Item file.txt).Attributes -= 'Hidden'` |

> **Be careful with `Remove-Item -Recurse -Force`.** It deletes without asking and skips the Recycle Bin. Run it with `-WhatIf` first and PowerShell will tell you what it *would* delete without doing it.

---

## 11. The big idea: text versus objects

CMD output is just **text**, so you filter it by searching the text with `find` or `findstr`.

PowerShell output is **objects** with named properties. Once you move past the one-to-one translations above, filter with these three instead of text matching:

```powershell
Get-Process | Where-Object { $_.CPU -gt 100 } | Sort-Object CPU -Descending | Select-Object Name, Id, CPU
```

| Cmdlet | Job |
|---|---|
| `Where-Object` | keep only the items that meet a condition |
| `Sort-Object` | put them in order |
| `Select-Object` | choose which properties to show |

Not sure what properties an object has? Pipe it to `Get-Member`: `Get-Process | Get-Member`. For help on any command, use `Get-Help <command> -Examples`.
