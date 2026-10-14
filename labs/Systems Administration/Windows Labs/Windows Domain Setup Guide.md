# Domain Setup & Workstation Join Guide
### Promoting DC01 to a domain controller and joining WKS01 to it

**Prerequisite:** you've completed the **Windows ISO & VM Foundation Guide** — `DC01` (Windows Server 2022) and `WKS01` (Windows 11 Enterprise) are both installed and sitting at a logged-in desktop, and you took a `post-install-clean` snapshot of each.

**Domain built in this guide:** `gielinor.local` (NetBIOS `GIELINOR`), with `DC01` as the first (and only) domain controller and `WKS01` joined as a member workstation.

---

## Step 1 — Put both VMs on a private virtual network

The DC and workstation need to see each other on a stable, private network segment. A VirtualBox **NAT Network** gives you that plus outbound internet (for time sync and Windows Update) without exposing the lab to your real LAN.

1. In the VirtualBox Manager, go to **File → Tools → Network Manager → NAT Networks**.
2. Click **Create**, name it `GielinorNAT`, and set the network CIDR to `10.10.10.0/24` (edit the auto-generated one if needed). Leave DHCP disabled — we're assigning static IPs by hand so DNS behaves predictably.
3. For **both** DC01 and WKS01 (each VM must be powered off to edit this): **Settings → Network → Adapter 1** → Attached to: **NAT Network** → Name: `GielinorNAT`.

---

## Step 2 — Configure DC01's network identity

Power on DC01, log in as `Administrator`.

**Set a static IP** (PowerShell, run as Administrator):
```powershell
Get-NetAdapter                                         # confirm the adapter name/index, usually "Ethernet"
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.10.10.10 -PrefixLength 24 -DefaultGateway 10.10.10.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.10.10.10
```
DC01 points DNS at *itself* because once AD DS is installed, the DC becomes the DNS server for the domain.

**Rename the computer** (if it isn't already `DC01`):
```powershell
Rename-Computer -NewName "DC01" -Restart
```
Log back in after the reboot.

---

## Step 3 — Install AD DS and promote DC01 to a domain controller

Still on DC01, as Administrator:

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
```

Then promote the server to a new forest:

```powershell
Install-ADDSForest `
  -DomainName "gielinor.local" `
  -DomainNetbiosName "GIELINOR" `
  -InstallDns `
  -DatabasePath "C:\Windows\NTDS" `
  -LogPath "C:\Windows\NTDS" `
  -SysvolPath "C:\Windows\SYSVOL" `
  -ForestMode "WinThreshold" `
  -DomainMode "WinThreshold"
```

You'll be prompted for a **Directory Services Restore Mode (DSRM)** password — pick something you'll remember; it's only used for AD disaster recovery, not day-to-day logins. The command finishes with an automatic reboot.

**Verify the promotion** after logging back in (now as `GIELINOR\Administrator`):
```powershell
Get-ADDomain
dcdiag /q          # should return with no errors (a few warnings on a brand-new single DC are normal)
nslookup gielinor.local
```
`nslookup` should resolve to `10.10.10.10` — if it doesn't, DNS wasn't pointed at itself correctly in Step 2.

---

## Step 4 — Create a domain user account for the workstation

Still on DC01:

```powershell
New-ADUser -Name "student" `
  -SamAccountName "student" `
  -UserPrincipalName "student@gielinor.local" `
  -AccountPassword (ConvertTo-SecureString "ChangeMe123!" -AsPlainText -Force) `
  -Enabled $true `
  -ChangePasswordAtLogon $false
```

This is the account you'll log into `WKS01` with once it's domain-joined. (The full cast of characters used in the Windows Administration Lab is created separately by that lab's own setup script — see the **Windows Administration Lab Guide** — so don't duplicate them here.)

---

## Step 5 — Configure WKS01's network identity

Power on WKS01, log in with the local account you created during install.

**Set a static IP** (PowerShell, run as Administrator):
```powershell
Get-NetAdapter
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.10.10.20 -PrefixLength 24 -DefaultGateway 10.10.10.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.10.10.10
```
Note the DNS server here is `10.10.10.10` — **DC01**, not a public resolver. If WKS01 can't find the domain controller by name, this is the first thing to check.

**Rename the computer** (if it isn't already `WKS01`):
```powershell
Rename-Computer -NewName "WKS01" -Restart
```

**Sanity check before joining** — from WKS01:
```powershell
Test-NetConnection -ComputerName 10.10.10.10 -Port 445   # SMB reachable?
nslookup gielinor.local                                  # should resolve to 10.10.10.10
```
If either of these fails, fix networking before attempting the domain join — a failed join usually means a name-resolution problem, not an AD problem.

---

## Step 6 — Join WKS01 to the domain

**Option A — PowerShell (fastest):**
```powershell
Add-Computer -DomainName "gielinor.local" -Credential (Get-Credential) -Restart
```
When prompted, enter `GIELINOR\Administrator` (or `student`, if you gave it rights to join computers — by default only Domain Admins can) and the matching password.

**Option B — GUI, if you'd rather click through it:**
1. **Settings → Accounts → Access work or school → Connect**
2. At the bottom, choose **Join this device to a local Active Directory domain**
3. Enter `gielinor.local`, then the domain admin credentials when prompted
4. Restart when asked

---

## Step 7 — Verify the join

After the restart, at the sign-in screen you should now see an option for **Other user** (or the account list shows the domain). Sign in as `GIELINOR\student` (password `ChangeMe123!` from Step 4).

From inside that session, confirm:
```powershell
whoami                 # should show gielinor\student
whoami /fqdn           # confirms the domain-qualified identity
echo $env:USERDOMAIN   # GIELINOR
```

Back on DC01, confirm the computer object landed in AD:
```powershell
Get-ADComputer -Identity "WKS01"
```

---

## Troubleshooting notes

- **"The domain specified is not available"** almost always means DNS. WKS01's DNS server must be `10.10.10.10`, not a public DNS address, and both VMs must be on the same VirtualBox NAT Network.
- **Time drift** between DC and workstation beyond ~5 minutes will cause Kerberos authentication failures. If you paused a VM for a long time, resync: `w32tm /resync` (as Administrator) on WKS01 after it's joined.
- **Only Domain Admins can join computers to the domain by default.** If you want `student` to be able to join machines without elevated creds, that's a deliberate AD delegation exercise outside the scope of this guide — for the lab, just join using the `Administrator` credential.
- If you rebuilt DC01 from the `post-install-clean` snapshot after already promoting it once, the domain is gone and WKS01's existing join will be stale — remove WKS01 from the domain (or restore its own snapshot) and redo Steps 3–6.

---

## Where you should be now

- `gielinor.local` domain live, with `DC01` as its only domain controller and DNS server
- A domain user account (`GIELINOR\student`) that can log into workstations
- `WKS01` renamed, statically addressed, joined to `gielinor.local`, and logged in as a domain user

**Take a fresh snapshot of both VMs now**, labeled something like `domain-joined-clean` — this is the baseline you'll want to roll back to before (and between) runs of the Windows Administration Lab.

Next: **The Wrkstation Chronicles — Windows Garrison** (Windows Administration Lab Guide).
