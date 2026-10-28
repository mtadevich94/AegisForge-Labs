# The Three Keeps — Environment Setup

You'll use **three Windows VMs** in the domain you built in the Windows Garrison lab:

| VM | Role | OS | IP | Notes |
|---|---|---|---|---|
| **DC01** | Domain controller + DNS (Tier 0) | Windows Server 2022 | `10.10.10.10` | Already built |
| **WKS01** | Workstation (Tier 2) | Windows 11 Enterprise | `10.10.10.20` | Already built; must be domain-joined |
| **SRV01** | Member server (Tier 1) | Windows Server 2022 | `10.10.10.40` | **New — you build this one** |

Network: VirtualBox NAT Network **`GielinorNAT`** (`10.10.10.0/24`), domain **`gielinor.local`**.

> ⚠️ **Isolated lab only.** The baseline is deliberately insecure and every lab account shares one published password. Never run these scripts against a real domain.

**Resources:** budget about 2 GB RAM for DC01, 2 GB for SRV01 and 4 GB for WKS01 (8 GB total, plus your host). If you're tight, run SRV01 and WKS01 with 2 GB each and close other apps.

**Prerequisites:** you finished the **Windows ISO & VM Foundation Guide** and **Domain Setup & Workstation Join Guide** from the Windows Labs. If your DC01/WKS01 addresses differ from the table, either change them to match (easiest — the member script can set a static IP) or substitute your own addresses throughout.

---

## Step 0 — Snapshot first

Take a snapshot of **DC01** and **WKS01** now (`pre-tiered`). The baseline script changes the directory.

## Step 1 — Check the foundations

On **DC01** (elevated PowerShell, as `GIELINOR\Administrator`):

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
Get-ADComputer -Filter * | Select-Object Name, DNSHostName
ipconfig | findstr IPv4
```

You want `DNSRoot = gielinor.local` and `WKS01` in the computer list. Note DC01's address; the lab assumes `10.10.10.10`.

## Step 2 — Build SRV01

1. Use the same **Windows Server 2022 evaluation ISO** you used for DC01 (Windows Labs, Foundation guide). Create a VirtualBox VM:
   - Name `SRV01`, Type Microsoft Windows, Version *Windows 2022 (64-bit)*
   - **2 GB** RAM, 2 CPUs, 50 GB dynamically allocated disk
   - Tick **Skip Unattended Installation**
   - Network: **NAT Network → `GielinorNAT`**
2. Install **Windows Server 2022 Standard Evaluation (Desktop Experience)**. Set the local Administrator password (lab use).
3. Rename the computer to `SRV01` (Server Manager → Local Server, or `Rename-Computer -NewName SRV01 -Restart`).

## Step 3 — Give SRV01 and WKS01 stable addresses, and join SRV01

Copy the lab folder to SRV01 and WKS01 (clone the repo, or download the ZIP).

On **SRV01** (elevated PowerShell, from the lab folder):

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Setup-TieredAdminLab-Member.ps1 -Role Server -StaticIP 10.10.10.40
```

> Your session may drop for a moment while the address changes. Reconnect at the VM console.

Join the domain and reboot:

```powershell
Add-Computer -DomainName gielinor.local -Credential GIELINOR\Administrator -Restart
```

On **WKS01** (elevated, from the lab folder), pin the address and prepare it:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Setup-TieredAdminLab-Member.ps1 -Role Workstation -StaticIP 10.10.10.20
```

> **Local administrator accounts.** DC01 and SRV01 have the built-in `Administrator`. WKS01 doesn't: Windows 11 disables the built-in one. Wherever this lab says "the local Administrator" on WKS01, use `labadmin`, the local administrator you created at install. Don't remove it from the local Administrators group: it is your way back in if a policy locks you out.

## Step 4 — Run the DC01 baseline

On **DC01** (elevated, from the lab folder, as a Domain Admin):

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Setup-TieredAdminLab-DC01.ps1
```

It builds the **flat realm**: the cast accounts, the deliberate privilege mistakes, the `svc-backup`/`svc-web` accounts with SPNs, the empty `Realm\Tier0/Tier1/Tier2/Staging` OUs, the DNS record for `srv01`, and advanced auditing. It prints `DC01 baseline ready` when done.

Want a different lab password? `-LabPassword 'YourOwn16+Chars!'` (must be 16+ characters). Pass the **same** value to the member script (`-LabPassword`) and to `Invoke-LazyAdminDay.ps1` (the guide's `Get-Credential` prompts take whatever you set).

> **Same names, two accounts.** If you did Windows Garrison first, WKS01 already has **local** accounts called `General_Graardor`, `Zelda_Warden`, `Navi` and so on. This lab's baseline creates **domain** accounts with the same names. A bare `Navi` at the sign-in screen signs you in to the local one. Always type the prefix: `GIELINOR\Navi` for the domain account, `WKS01\Navi` for the local one. The passwords differ (`ChangeMe123!` for local, the lab password above for domain), which tells you which one you hit.

## Step 5 — Re-run the member scripts (domain-joined)

The member script plants the "legacy" scheduled tasks (`KeepNightlyBackup` on SRV01, `VillageInventoryCheck` on WKS01) that run as Domain Admin accounts. They can only be created once the machine is domain-joined **and** the DC01 baseline has run, so run each one again:

On **SRV01**:   `.\Setup-TieredAdminLab-Member.ps1 -Role Server`
On **WKS01**:   `.\Setup-TieredAdminLab-Member.ps1 -Role Workstation`

(No `-StaticIP` the second time — that part is already done.)

## Step 6 — Verification checklist

On **DC01**:

- [ ] `Get-ADUser -Filter * | Select SamAccountName` lists the eight cast accounts plus `svc-backup` and `svc-web`
- [ ] `Get-ADGroupMember 'Domain Admins' | Select SamAccountName` lists `Administrator, Vaultkeeper, General_Graardor, Zelda_Warden, Navi, svc-backup`
- [ ] `Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Realm,$((Get-ADDomain).DistinguishedName)" | Select Name` lists `Realm, Tier0, Tier1, Tier2, Staging`
- [ ] `Resolve-DnsName srv01.gielinor.local` returns `10.10.10.40`
- [ ] `Test-NetConnection srv01.gielinor.local -Port 5985` and `... wks01.gielinor.local -Port 5985` are `True` (WinRM)
- [ ] `Invoke-Command -ComputerName srv01.gielinor.local,wks01.gielinor.local -ScriptBlock { hostname }` returns both names
- [ ] On SRV01: `schtasks /Query /TN KeepNightlyBackup` exists. On WKS01: `schtasks /Query /TN VillageInventoryCheck` exists.

All ticked? **Snapshot DC01, SRV01 and WKS01 as `tiered-baseline`**, then start the Lab Guide at Module 1.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `Add-Computer` says the domain can't be contacted | SRV01's DNS must point to DC01 (`10.10.10.10`). `ipconfig /all`. The member script sets it when you give `-StaticIP`. |
| Baseline script says "does not look like a domain controller" | Run it on DC01, as a Domain Admin, in an **elevated** window. |
| `Invoke-Command` to a member says "Access is denied" or WinRM errors | The member script hasn't been run (it enables WinRM), the VM isn't domain-joined yet, or you used an IP address instead of the FQDN. |
| The member script warns it can't create the scheduled task | Machine isn't domain-joined yet, or DC01's baseline hasn't been run so `svc-backup`/`Navi` don't exist. Fix and re-run it. |
| `Test-TieredAdminLab.ps1` shows SKIP lines | The thing it needs (a GPO, group or OU) doesn't exist yet. That's expected before you build it. |
| Locked out after Module 5 | Revert the VM to the `m5-before-gpo` snapshot — or sign in to the machine's **local** administrator at the console (`Administrator` on SRV01, `labadmin` on WKS01). |
| A cast account such as `Navi` says the password is wrong, or has the wrong rights | You probably signed in to the **local** account of the same name on WKS01. Local accounts use `ChangeMe123!`; domain accounts use the Tiered lab password (`Gielinor!Lab#2026` by default). Type the prefix: `GIELINOR\Navi` (domain) or `WKS01\Navi` (local). |

## Resetting

- **Quick reset of the directory:** run `.\Setup-TieredAdminLab-DC01.ps1 -Reset` on DC01 (removes the tier objects and GPOs and restores the insecure memberships). Note that Group Policy Preferences changes already applied to SRV01/WKS01 (for example `T1-Admins`/`T2-Admins` added to local Administrators) are *not* automatically undone, so for a truly clean start prefer the snapshots below.
- **Clean slate:** revert all three VMs to `tiered-baseline`.
