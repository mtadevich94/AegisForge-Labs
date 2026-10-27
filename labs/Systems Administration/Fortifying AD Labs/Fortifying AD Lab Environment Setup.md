# The Iron Gates: Environment Setup

Small, and almost entirely checks. You already built the domain.

> **Isolated lab only.** Some steps deliberately re-create insecure legacy settings so you can watch them fail. Never do these on a real network.

## What you need

| VM | Role | OS | IP |
|---|---|---|---|
| **DC01** | Domain controller + DNS | Windows Server 2022 | `10.10.10.10` |
| **SRV01** | Member server (Tier 1) | Windows Server 2022 | `10.10.10.40` |
| **WKS01** | Workstation (Tier 2) | Windows 11 Enterprise | `10.10.10.20` |
| **WATCHTOWER** | The "legacy device" | Ubuntu Server 24.04 | `10.10.10.30` |

All on `GielinorNAT` (`10.10.10.0/24`), domain `gielinor.local`. The three Windows VMs must be **domain-joined**, and the Tiered Admin lab should be done through at least Module 6. VULN01 (the Nessus scanner) is optional, and is useful in Module 9.

**RAM:** about 10 GB across the four VMs, plus your host.

## Step 0 — Snapshot everything

Snapshot **all four VMs** as **`fortify-start`**. You'll want to come back here.

## Step 1 — Check the foundations (DC01, elevated PowerShell)

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
Get-ADComputer -Filter * | Select-Object Name, DistinguishedName
Get-ADOrganizationalUnit -Filter 'Name -like "Tier*"' | Select-Object Name
```

You should see `gielinor.local`, WKS01 and SRV01 in the Tier OUs, and the Tier OUs under `Realm`. If your OUs are named differently, use your own names wherever the guide says `OU=Realm`.

**DNS must be healthy.** Many steps assume it.

```powershell
Resolve-DnsName srv01.gielinor.local
Resolve-DnsName wks01.gielinor.local
```

## Step 2 — Create a test share on SRV01

On **SRV01** (elevated PowerShell):

```powershell
New-Item -ItemType Directory -Path C:\Keep -Force | Out-Null
"The Keep's records." | Set-Content C:\Keep\readme.txt
New-SmbShare -Name Keep -Path C:\Keep -ReadAccess 'GIELINOR\Domain Users'
```

It gives you something to connect to in later modules.

## Step 3 — Prepare WATCHTOWER

On **WATCHTOWER** (Ubuntu), install the tools it needs to play an old, quirky client:

```bash
sudo apt update
sudo apt install -y ldap-utils smbclient netcat-openbsd openssl
```

Check it can reach the domain:

```bash
ping -c1 10.10.10.10
nc -zv 10.10.10.10 389
nc -zv 10.10.10.40 445
```

## Step 4 — Know your way around Group Policy

You'll create GPOs on **DC01** in **Group Policy Management** (`gpmc.msc`). Names used in this lab:

| GPO | Linked to | Used for |
|---|---|---|
| `GPO-Fortify-DC` | `Domain Controllers` OU | Settings that apply on domain controllers |
| `GPO-Fortify-Members` | `OU=Realm` | Settings for every server and workstation in the realm |
| `GPO-Fortify-SRV01` | `OU=Servers,OU=Tier1,OU=Realm` | A stricter set, tested on SRV01 first |
| `GPO-Fortify-WKS` | `OU=Workstations,OU=Tier2,OU=Realm` | Workstation-only settings |

You'll create each when a module first needs it. After changing a GPO, refresh with `gpupdate /force` on the target machine. A few settings need a reboot, which the guide says.

> **Tip:** to see what a machine actually received, run `gpresult /r` (summary) or `gpresult /h C:\gp.html` (a full report you can open in a browser).

## Step 5 — Check everything

- [ ] All four VMs snapshotted as `fortify-start`
- [ ] DNS resolves `srv01` and `wks01` from DC01
- [ ] `\\SRV01\Keep` exists and `Domain Users` can read it
- [ ] WATCHTOWER can reach DC01 on port 389 and SRV01 on port 445
- [ ] You've read the **Legacy Field Guide**

Ready? Start the **Lab Guide** at Module 1.

## Quick troubleshooting

| Symptom | Fix |
|---|---|
| `Resolve-DnsName` fails | Check each VM's DNS points at `10.10.10.10` |
| WATCHTOWER can't reach the Windows VMs | Check its address and adapter (`GielinorNAT`), and Windows Firewall on the target |
| Can't create the share | Run PowerShell as Administrator |
| Locked out later | See **Fortifying AD Lab Troubleshooting.md**, and restore the last snapshot |
