# The Wrkstation Chronicles: The Three Keeps

*A hands-on Tiered Administration lab — part of Project AegisForge's Sysadmin path (security hardening for people who already run Windows).*

---

## The story so far

Gielinor has three places worth defending: the **Citadel** (the domain controller — whoever holds it holds the realm), the **Keep** (the servers where the guild's work lives), and the **Village** (the everyday workstations).

Right now the Vaultkeeper's keys open every door in all three. The General runs the Keep as a Domain Admin. Navi the help desk fairy is a Domain Admin "so she can reset passwords". A backup job runs as a Domain Admin "so it never fails". And every one of them logs on to Village machines every single day.

You've been named **Warden of the Gates**. Your job: split the realm into tiers, make sure a key from a lower tier can never open a higher door, and make sure a *stolen* key can't walk upward — then prove it.

**Time:** about 6–8 hours across 8 modules.
**Cost:** free (Windows evaluation ISOs + VirtualBox).
**Level:** you should already be comfortable with Windows administration and basic Active Directory — if not, finish the **Windows Garrison** lab first.

---

## Why this matters (read this before you start)

Most big Windows-domain breaches follow the same path:

1. An attacker lands on an ordinary workstation (a phished user — Tier 2).
2. A privileged person has logged on to that workstation at some point. Their credentials (hashes, tickets, cached secrets) are sitting in memory or on disk.
3. The attacker uses them to reach a server (Tier 1), then a domain controller (Tier 0). **Game over.**

The fix is not a firewall or an antivirus. It's *credential hygiene by tier*:

> **A credential may only be used in the tier it belongs to — and never in a lower one.**

If a Domain Admin password is never typed into a workstation, it can never be stolen from a workstation.

### The three tiers

| Tier | What lives here | Who administers it |
|---|---|---|
| **Tier 0** — control of identity | Domain controllers, AD itself, Domain/Enterprise/Schema Admins, anything that can change them (PKI, Entra Connect, backups of DCs, the hypervisor under a DC) | Tier 0 admins only |
| **Tier 1** — servers & applications | Member servers, business apps, databases, file servers, server admins | Tier 1 admins |
| **Tier 2** — devices & users | Workstations, laptops, standard users, help desk | Tier 2 admins (help desk) |

**The two rules:**

1. **Logon restriction (credentials don't travel down):** a Tier 0 account must never log on to a Tier 1 or Tier 2 machine; a Tier 1 account never to Tier 2 (or Tier 0). Lower tiers don't log on upward either — but the damage in *that* direction is smaller, so we block it too.
2. **Control restriction (privilege doesn't leak up):** a Tier 2 admin must not be able to change anything that would give them Tier 1 or Tier 0 power (a group, a GPO, a computer object, a service account).

> *Modern note:* Microsoft now frames this as the **Enterprise Access Model** (control plane / management plane / data plane / user access), which also covers cloud and Entra ID. The three-tier model is its on-premises ancestor and the best way to learn the core idea. Credit where due: this lab teaches the thinking; real environments add privileged access workstations, Credential Guard, LAPS, and authentication policies on top.

---

## Your lab (what you need)

Three Windows VMs on the `GielinorNAT` network — the same domain you built in the Windows Garrison lab:

| VM | Role | OS | IP | Tier |
|---|---|---|---|---|
| **DC01** | Domain controller + DNS | Windows Server 2022 | `10.10.10.10` | 0 |
| **SRV01** *(new)* | Member server | Windows Server 2022 | `10.10.10.40` | 1 |
| **WKS01** | Workstation | Windows 11 Enterprise | `10.10.10.20` | 2 |

Follow **Tiered Admin Lab Environment Setup.md** to build SRV01 and run the setup scripts. When you finish, **snapshot all three VMs** as `tiered-baseline`. You will break things on purpose; the snapshot is how you get back.

> ⚠️ **Isolated lab only.** The baseline is insecure on purpose, and every account uses the same published lab password. Never run any of this against a real domain.

### Files you'll use

| File | Purpose |
|---|---|
| `Get-TierLogons.ps1` | Reads logon events from any machine and shows them as clean tables |
| `Invoke-LazyAdminDay.ps1` | Generates the "everyone logs on everywhere" evidence for Module 1 |
| `Test-TieredAdminLab.ps1` | Self-check scorecard — tells you which controls are in place |

Get in the habit of running the scorecard at the end of each module.

### Conventions used in this guide

- Commands run in an **elevated PowerShell on DC01** unless the step says otherwise.
- Set these once per PowerShell session (many commands use them):

  ```powershell
  $dn    = (Get-ADDomain).DistinguishedName      # DC=gielinor,DC=local
  $realm = "OU=Realm,$dn"
  ```

- Sign in to DC01 as the built-in **`GIELINOR\Administrator`** for the build modules. It is a Tier 0 account, so it is your way back into the Citadel; each machine's **local** Administrator is your way back into that machine if a policy goes wrong. Keep both.
- **Use host names (FQDNs), not IP addresses**, when connecting (`srv01.gielinor.local`). Kerberos needs names. Later, protections you add will refuse NTLM — and an IP address forces NTLM.

---

## Module 1 — The Realm Is Flat (assess the starting point)

**Goal:** prove, with evidence, how exposed the current setup is.

### 1A — Who holds the keys?

```powershell
'Domain Admins','Enterprise Admins','Schema Admins','Administrators' | ForEach-Object {
    "`n== $_"
    Get-ADGroupMember -Identity $_ | Select-Object Name, SamAccountName, objectClass
}
```

1. List every account that is a member of each group.
2. Which of those are *people doing everyday work*? Which are *service accounts*?
3. Which group should normally have almost nobody in it (the built-in `Administrator` is a default member of three of these groups)? Why?

### 1B — Dangerous service accounts

```powershell
Get-ADUser -Filter 'ServicePrincipalName -like "*"' `
    -Properties ServicePrincipalName, MemberOf, PasswordNeverExpires, PasswordLastSet |
    Select-Object SamAccountName, ServicePrincipalName, PasswordNeverExpires, PasswordLastSet, MemberOf |
    Format-List
```

4. Which service accounts have an SPN? Which of those are privileged?
5. Any account with an SPN can have a Kerberos service ticket requested for it by **any authenticated user**. That ticket is encrypted with the account's password. Why does this make a *privileged* service account with a *non-expiring* password a problem? (You do not need to attack anything — reason about it.)

### 1C — Generate the evidence

Make the realm behave the way it does on a normal Tuesday:

```powershell
.\Invoke-LazyAdminDay.ps1
```

Now do one thing by hand, because it needs a human at a keyboard: from DC01 open Remote Desktop and sign in to the Village workstation as a Domain Admin, then sign out.

```
mstsc /v:wks01.gielinor.local
   user: GIELINOR\General_Graardor     (lab password)
```

(If Windows asks to trust the connection, accept — it's your lab.) Sign out when you're in.

### 1D — Read the evidence

```powershell
# Which privileged accounts logged on to WKS01 (Tier 2), and how?
.\Get-TierLogons.ps1 -ComputerName wks01.gielinor.local -Id 4624 -Max 300 -HideMachineAccounts |
    Where-Object Account -in 'General_Graardor','Zelda_Warden','Navi','Vaultkeeper','svc-backup' |
    Format-Table -AutoSize

# Same question for SRV01 (Tier 1)
.\Get-TierLogons.ps1 -ComputerName srv01.gielinor.local -Id 4624 -Max 300 -HideMachineAccounts |
    Where-Object Account -in 'General_Graardor','Zelda_Warden','Navi','Vaultkeeper','svc-backup' |
    Format-Table -AutoSize

# Admin-level logons
.\Get-TierLogons.ps1 -ComputerName wks01.gielinor.local -Id 4672 -Max 100 -HideMachineAccounts |
    Format-Table -AutoSize
```

Logon types you'll see: **2** interactive (keyboard), **3** network, **4** batch (scheduled task), **5** service, **10** Remote Desktop.

6. Fill in an **exposure table**:

   | Privileged account | Machine (tier) | Logon type(s) seen | Could a stolen copy of this credential be found on that machine? |
   |---|---|---|---|

7. Which logon types normally leave a *reusable* credential on the target machine (in memory or in stored secrets), and which do not? *(Hint: think about "I typed my password into this computer" versus "I proved I know it over the network".)*
8. Navi's scheduled task `VillageInventoryCheck` runs on WKS01 as `GIELINOR\Navi`. What does the **stored** password for that task mean for WKS01's tier? Do the same for `KeepNightlyBackup` on SRV01 and `svc-backup`.
9. In two sentences: if Bandit's laptop (WKS01) is phished and the attacker gets local administrator on it, which of your evidence rows becomes the shortest path to the Citadel?

> ✅ **Deliverable:** your completed exposure table. You will compare it with a second one in Module 8.

---

## Module 2 — Draw the Map (design before you build)

**Goal:** decide what belongs in which tier *before* touching AD. Most failed tiering projects fail here.

### 2A — Classify the assets

Put each item in Tier 0, 1, or 2, and give a one-line reason. Some are tricky on purpose.

| Item | Tier? | Why |
|---|---|---|
| DC01 | | |
| SRV01 (file/app server) | | |
| WKS01 | | |
| `Domain Admins` group | | |
| The backup server that holds DC backups | | |
| The hypervisor hosting DC01 | | |
| A GPO linked to the **domain root** | | |
| A GPO linked to the Workstations OU only | | |
| `svc-backup` today (a Domain Admin) | | |
| A certificate authority that issues smartcard certs | | |
| Vaultkeeper's *laptop* | | |
| The help desk ticketing server | | |

### 2B — Decide who gets what

Each person gets **one account per tier they administer** (never a single account for several). Standard everyday accounts stay unprivileged.

| Person | Everyday account | Admin account(s) you will create | Tier(s) |
|---|---|---|---|
| Vaultkeeper | `Vaultkeeper` | | |
| Zelda Warden | `Zelda_Warden` | | |
| General Graardor | `General_Graardor` | | |
| Navi | `Navi` | | |
| Princess Irulan | `Princess_Irulan` | | |

Naming convention used in this lab: **`t0-`**, **`t1-`**, **`t2-`** prefix + name (`t0-vaultkeeper`, `t1-zelda`, `t2-navi`). Groups: **`T0-Admins`**, **`T1-Admins`**, **`T2-Admins`**.

### 2C — The rules table

For each row, decide **Allowed** or **Denied** — and where each denial is enforced:

| Admin tier ↓ / Machine tier → | Tier 0 (DC) | Tier 1 (server) | Tier 2 (workstation) |
|---|---|---|---|
| T0 admin | | | |
| T1 admin | | | |
| T2 admin | | | |

Also answer:

1. Why do we still *deny* a Tier 2 admin from logging on to a DC if they could not do much there anyway?
2. Why are **dedicated admin accounts** better than "use the same account but be careful"?
3. Where do the built-in **domain** `Administrator` and each machine's built-in **local** `Administrator` fit, and why do we keep both?
4. You will nest `T0-Admins` inside `Domain Admins` rather than adding people directly. What does that buy you?

> ✅ **Deliverable:** the asset table, the person table, and the rules table. Keep them — the capstone refers to them.

---

## Module 3 — Build the Keeps (structure, groups, and admin accounts)

**Goal:** create the tier skeleton and the new admin identities. You are **not** removing anyone's old privileges yet — the point is to build the new house *before* moving out of the old one.

### 3A — Sub-OUs

The baseline already created `OU=Realm` with empty `Tier0`, `Tier1`, `Tier2` and `Staging` OUs. Add the rest:

```powershell
foreach ($t in 'Tier0','Tier1','Tier2') {
    foreach ($sub in 'Admins','Groups') {
        New-ADOrganizationalUnit -Name $sub -Path "OU=$t,$realm" -ProtectedFromAccidentalDeletion $false
    }
}
New-ADOrganizationalUnit -Name 'Servers'          -Path "OU=Tier1,$realm" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name 'Service Accounts' -Path "OU=Tier1,$realm" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name 'Workstations'     -Path "OU=Tier2,$realm" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name 'Users'            -Path "OU=Tier2,$realm" -ProtectedFromAccidentalDeletion $false
```

(Domain controllers stay in the built-in **Domain Controllers** OU — that *is* Tier 0's computer container.)

### 3B — Tier groups

```powershell
New-ADGroup -Name 'T0-Admins' -SamAccountName 'T0-Admins' -GroupScope Global -GroupCategory Security `
            -Path "OU=Groups,OU=Tier0,$realm" -Description 'Tier 0 administrators (control of identity)'
New-ADGroup -Name 'T1-Admins' -SamAccountName 'T1-Admins' -GroupScope Global -GroupCategory Security `
            -Path "OU=Groups,OU=Tier1,$realm" -Description 'Tier 1 administrators (servers)'
New-ADGroup -Name 'T2-Admins' -SamAccountName 'T2-Admins' -GroupScope Global -GroupCategory Security `
            -Path "OU=Groups,OU=Tier2,$realm" -Description 'Tier 2 administrators (workstations / help desk)'
```

### 3C — The admin accounts

```powershell
$pw = Read-Host 'Lab password for the new admin accounts' -AsSecureString

New-ADUser -Name 't0-vaultkeeper' -SamAccountName 't0-vaultkeeper' -UserPrincipalName "t0-vaultkeeper@gielinor.local" `
           -Path "OU=Admins,OU=Tier0,$realm" -AccountPassword $pw -Enabled $true `
           -Description 'Tier 0 admin identity of Vaultkeeper'
New-ADUser -Name 't1-zelda' -SamAccountName 't1-zelda' -UserPrincipalName "t1-zelda@gielinor.local" `
           -Path "OU=Admins,OU=Tier1,$realm" -AccountPassword $pw -Enabled $true `
           -Description 'Tier 1 admin identity of Zelda Warden'
New-ADUser -Name 't2-navi' -SamAccountName 't2-navi' -UserPrincipalName "t2-navi@gielinor.local" `
           -Path "OU=Admins,OU=Tier2,$realm" -AccountPassword $pw -Enabled $true `
           -Description 'Tier 2 admin identity of Navi'

Add-ADGroupMember -Identity 'T0-Admins' -Members 't0-vaultkeeper'
Add-ADGroupMember -Identity 'T1-Admins' -Members 't1-zelda'
Add-ADGroupMember -Identity 'T2-Admins' -Members 't2-navi'

# Tier 0 identity gets its power through ONE nested group, not through individual memberships
Add-ADGroupMember -Identity 'Domain Admins' -Members 'T0-Admins'
```

Optional: if your Module 2 plan gave General Graardor a Tier 1 admin identity, create `t1-graardor` the same way.

### 3D — Move things where they belong

```powershell
# Computers
Get-ADComputer 'SRV01' | Move-ADObject -TargetPath "OU=Servers,OU=Tier1,$realm"
Get-ADComputer 'WKS01' | Move-ADObject -TargetPath "OU=Workstations,OU=Tier2,$realm"

# Everyday (unprivileged) accounts -> Tier2\Users
'Bandit','Kerbe','DAME','Princess_Irulan','Navi','Zelda_Warden','General_Graardor','Vaultkeeper' | ForEach-Object {
    Get-ADUser $_ | Move-ADObject -TargetPath "OU=Users,OU=Tier2,$realm"
}

# Service accounts -> Tier1\Service Accounts
'svc-backup','svc-web' | ForEach-Object {
    Get-ADUser $_ | Move-ADObject -TargetPath "OU=Service Accounts,OU=Tier1,$realm"
}
```

Let Group Policy catch up on both members (so they notice the new OU):

```powershell
Invoke-Command -ComputerName srv01.gielinor.local,wks01.gielinor.local -ScriptBlock { gpupdate /force | Out-Null }
```

### 3E — Check yourself

```powershell
.\Test-TieredAdminLab.ps1 -Module 3
```

### Questions

1. Why create the **new** admin accounts and groups *before* removing the old privileges?
2. `T0-Admins` is nested in `Domain Admins`. Which attack on group membership becomes easier to **detect** because of this?
3. What is the risk of leaving `Vaultkeeper` (everyday) in `Domain Admins` while `t0-vaultkeeper` exists?
4. DC01 stays in the Domain Controllers OU. Why is it fine that Tier 0 doesn't have a "Servers" OU yet?

> 📸 Snapshot DC01 as `m3-structure`.

---

## Module 4 — Delegation, Not Membership

**Goal:** give the help desk exactly the powers it needs, in exactly one OU, and nothing else.

Navi was a Domain Admin "to reset passwords". The right way: one narrow permission on one OU.

### 4A — Let T2-Admins reset passwords and unlock accounts in `Tier2\Users`

```powershell
$ou = "OU=Users,OU=Tier2,$realm"
dsacls $ou /I:S /G "GIELINOR\T2-Admins:CA;Reset Password;user"
dsacls $ou /I:S /G "GIELINOR\T2-Admins:RPWP;pwdLastSet;user"
dsacls $ou /I:S /G "GIELINOR\T2-Admins:RPWP;lockoutTime;user"
```

Read it back and confirm:

```powershell
dsacls $ou | Select-String 'T2-Admins'
```

### 4B — Let tier admins join computers into their own tier only

Use the GUI wizard (it knows the right permissions):

1. `Active Directory Users and Computers` → right-click **Tier2 → Workstations** → **Delegate Control…**
2. Add **`T2-Admins`** → *Next* → tick **Join a computer to the domain** → Finish.
3. Repeat on **Tier1 → Servers** for **`T1-Admins`**.

### 4C — Prove it (positive and negative tests)

```powershell
$c = Get-Credential GIELINOR\t2-navi
# Should SUCCEED: reset an ordinary user's password
Set-ADAccountPassword -Identity Bandit -Reset -Credential $c `
    -NewPassword (ConvertTo-SecureString 'Villager-Reset-2026!' -AsPlainText -Force)

# Should be DENIED: try the same on a Tier 0 admin
Set-ADAccountPassword -Identity t0-vaultkeeper -Reset -Credential $c `
    -NewPassword (ConvertTo-SecureString 'Villager-Reset-2026!' -AsPlainText -Force)
```

### Questions

1. Which result did you get for the second command, and **why** does the delegation not reach it?
2. Why is *where* the delegation is applied (which OU) part of the security design — not just a tidy-up?
3. If a Tier 2 admin could modify the membership of `T1-Admins`, what would that mean for the model?
4. Why must **Tier 2 admins never be able to reset a Tier 0 admin's password**? (Think about what a password reset lets you do next.)

---

## Module 5 — Lock the Doors (logon restrictions)

**Goal:** make Rule 1 real. Build three GPOs that stop higher-tier credentials from being used on lower-tier computers — and give each tier its own local administrators.

> 📸 **Snapshot all three VMs first** (`m5-before-gpo`). This is the module where you can lock yourself out.

### 5A — Create and link the GPOs

```powershell
New-GPO -Name 'Tier2-Workstation-Restrictions'  | New-GPLink -Target "OU=Workstations,OU=Tier2,$realm"
New-GPO -Name 'Tier1-Server-Restrictions'       | New-GPLink -Target "OU=Servers,OU=Tier1,$realm"
New-GPO -Name 'Tier0-DC-Logon-Restrictions'     | New-GPLink -Target "OU=Domain Controllers,$dn"
```

### 5B — The deny lists

Open **Group Policy Management** (`gpmc.msc`) → edit each GPO →
**Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → User Rights Assignment**.

For **each** GPO, define these five rights and add the groups listed. Use `GIELINOR\<name>`:

| Right | What it blocks |
|---|---|
| Deny access to this computer from the network | PowerShell remoting, file shares, remote admin |
| Deny log on as a batch job | Scheduled tasks running as that identity |
| Deny log on as a service | Services running as that identity |
| Deny log on locally | Keyboard/console |
| Deny log on through Remote Desktop Services | RDP |

| GPO (linked to) | Add to **all five** deny rights |
|---|---|
| **Tier2-Workstation-Restrictions** (Tier2\Workstations) | `T0-Admins`, `T1-Admins`, `Domain Admins`, `Enterprise Admins`, `Schema Admins` |
| **Tier1-Server-Restrictions** (Tier1\Servers) | `T0-Admins`, `T2-Admins`, `Domain Admins`, `Enterprise Admins`, `Schema Admins` |
| **Tier0-DC-Logon-Restrictions** (Domain Controllers) | `T1-Admins`, `T2-Admins` |

> ⚠️ **Never** put `Domain Admins` on a deny list that applies to the **domain controllers**. That locks your own Tier 0 out of Tier 0.

> 📝 Why list both `T0-Admins` *and* `Domain Admins`? `T0-Admins` is nested inside `Domain Admins`, so either would match — but listing the explicit tier group makes the policy readable and survives someone un-nesting the group.

### 5C — Local administrators per tier (Group Policy Preferences)

The built-in `Domain Admins` group is automatically a local administrator on every domain-joined machine. In a tiered model, **each tier's computers are administered by that tier's admins**, not by Tier 0.

In **Tier2-Workstation-Restrictions**:
**Computer Configuration → Preferences → Control Panel Settings → Local Users and Groups → New → Local Group**

- Action: **Update**
- Group name: **Administrators (built-in)**
- Members → *Add*: `GIELINOR\T2-Admins` → Action: **Add to this group**
- Members → *Add*: `GIELINOR\Domain Admins` → Action: **Remove from this group**

In **Tier1-Server-Restrictions** do the same with `GIELINOR\T1-Admins` (add) and `GIELINOR\Domain Admins` (remove).

> Do **not** use "Replace" or remove the local `Administrator`. That is your break-glass account.

### 5D — Apply and verify

```powershell
# Make everything pick up the new policy
Invoke-Command -ComputerName srv01.gielinor.local,wks01.gielinor.local -ScriptBlock { gpupdate /force | Out-Null }
gpupdate /force      # DC01 itself (Tier0 GPO)
```

> 🔑 That `Invoke-Command` is the **last time** a Domain Admin can manage SRV01 or WKS01 remotely. From here on, Tier 1 and Tier 2 machines are administered by `t1-zelda` and `t2-navi` — exactly the point.

Confirm a deny right actually landed on WKS01 (run **on WKS01**, elevated — sign in as `GIELINOR\t2-navi`, which is now a local admin there):

```powershell
secedit /export /cfg "$env:TEMP\ur.cfg" /areas USER_RIGHTS | Out-Null
Select-String -Path "$env:TEMP\ur.cfg" -Pattern 'SeDeny'
```

The values are raw SIDs. Translate one back to a name:

```powershell
(Get-ADGroup T0-Admins).SID.Value
```

### 5E — The test matrix

From DC01, try every combination below. A quick **network-logon** test:

```powershell
$cred = Get-Credential        # type the account you are testing
Invoke-Command -ComputerName wks01.gielinor.local -Credential $cred -ScriptBlock { hostname }
```

…and an **RDP** test for the interactive types:

```
mstsc /v:wks01.gielinor.local          # then sign in as the account under test
```

Fill in the matrix with what actually happened (**OK** / **Denied** and the exact message):

| Account ↓ / Target → | DC01 (T0) | SRV01 (T1) | WKS01 (T2) |
|---|---|---|---|
| `t0-vaultkeeper` | | | |
| `t1-zelda` | | | |
| `t2-navi` | | | |
| `Administrator` (domain; a Domain Admin = Tier 0) | | | |
| `General_Graardor` (old Domain Admin) | | | |

*Expected behaviour on RDP when the right is denied:* **"The sign-in method you're trying to use isn't allowed."**

### 5F — What did you break?

The legacy scheduled tasks still run as Domain Admin accounts. Look at them:

```powershell
# On WKS01 (as t2-navi) and SRV01 (as t1-zelda):
schtasks /Run /TN VillageInventoryCheck      # WKS01
schtasks /Run /TN KeepNightlyBackup          # SRV01
schtasks /Query /TN KeepNightlyBackup /V /FO LIST | Select-String 'Last Result|Run As User'
```

Then read the failures:

```powershell
$c = Get-Credential GIELINOR\t2-navi
.\Get-TierLogons.ps1 -ComputerName wks01.gielinor.local -Credential $c -Id 4625 -Max 50 | Format-Table -AutoSize
```

Look at **SubStatus**. `0xC000015B` means "the user has not been granted the requested logon type at this machine" — that is a deny right doing its job.

### Questions

1. Which cell(s) in your matrix surprised you? Why?
2. Both scheduled tasks now fail. Is that a *bug* or the model working? Which of the two failures points at a bigger design problem?
3. The old Domain Admin accounts are denied — but they are still Domain Admins. Why is that still a problem even though the deny rights work? *(Hint: what else can a Domain Admin do from DC01?)*
4. The domain `Administrator` is a Domain Admin, so it is denied on Tier 1 and Tier 2 machines — but the **local** `Administrator` on each machine (never removed from local Administrators) is still a way in. What is it for, and what control would you add so it isn't the *same* password on every machine?

Run the scorecard:

```powershell
.\Test-TieredAdminLab.ps1 -Module 5
```

> 📸 Snapshot all three VMs as `m5-gpo-done`.

---

## Module 6 — Clear the Throne Room (remove legacy privilege, protect the keys)

**Goal:** now that the new model works, remove the old privilege and harden the Tier 0 identities.

### 6A — Take everyday accounts out of the privileged groups

Run as the built-in **`GIELINOR\Administrator`** — not as `Vaultkeeper` (you're about to remove it).

```powershell
Remove-ADGroupMember -Identity 'Domain Admins' -Confirm:$false `
    -Members 'General_Graardor','Zelda_Warden','Navi','svc-backup','Vaultkeeper'
Remove-ADGroupMember -Identity 'Enterprise Admins' -Members 'Vaultkeeper' -Confirm:$false
Remove-ADGroupMember -Identity 'Schema Admins'     -Members 'Vaultkeeper' -Confirm:$false
```

### 6B — The AdminSDHolder trap

Accounts that were ever in a protected group get `adminCount = 1` and **stop inheriting permissions** (a background process called SDProp enforces this and does *not* undo it when they leave). That quietly breaks the delegation from Module 4 for those users.

Look:

```powershell
Get-ADUser -Filter 'adminCount -eq 1' -Properties adminCount | Select-Object SamAccountName, adminCount
```

Clean up the former admins:

```powershell
foreach ($u in 'General_Graardor','Zelda_Warden','Navi','Vaultkeeper','svc-backup') {
    $obj = Get-ADUser -Identity $u -Properties adminCount
    Set-ADUser -Identity $obj -Clear adminCount
    $path = "AD:$($obj.DistinguishedName)"
    $acl  = Get-Acl -Path $path
    $acl.SetAccessRuleProtection($false, $false)       # re-enable inheritance
    Set-Acl -Path $path -AclObject $acl
}
```

Verify: Navi's everyday account should now be resettable by `t2-navi` again.

### 6C — Fix the service accounts

`svc-backup` should be able to back up SRV01 — **on SRV01** — and nothing else.

**On SRV01, as `t1-zelda`:**

```powershell
Add-LocalGroupMember -Group 'Backup Operators' -Member 'GIELINOR\svc-backup'
schtasks /Run /TN KeepNightlyBackup
schtasks /Query /TN KeepNightlyBackup /V /FO LIST | Select-String 'Last Result|Run As User'
```

**On WKS01, as `t2-navi`:** the inventory job never needed a Domain Admin. Delete it.

```powershell
schtasks /Delete /TN VillageInventoryCheck /F
```

### 6D — Protect the Tier 0 identity

```powershell
Add-ADGroupMember -Identity 'Protected Users' -Members 't0-vaultkeeper'
Set-ADAccountControl -Identity 't0-vaultkeeper' -AccountNotDelegated $true
```

*Protected Users* members: can't use NTLM, DES or RC4; no cached credentials; Kerberos tickets limited to ~4 hours with no renewal; no unconstrained delegation. *"Sensitive and cannot be delegated"*: the account's identity can't be forwarded to another service.

Test it (from DC01):

```powershell
$c = Get-Credential GIELINOR\t0-vaultkeeper
Enter-PSSession -ComputerName dc01.gielinor.local -Credential $c      # Kerberos by name: works
Exit-PSSession
```

Now try again using the DC's **IP address** instead of its name. What happens, and why? (This is why the guide kept insisting on FQDNs.)

### 6E — Admin-grade passwords

Admin accounts should have longer, rotating passwords than everyone else. A fine-grained password policy (PSO) can enforce that on the tier groups only:

```powershell
New-ADFineGrainedPasswordPolicy -Name 'PSO-Tier-Admins' -Precedence 10 `
    -MinPasswordLength 16 -ComplexityEnabled $true -ReversibleEncryptionEnabled $false `
    -PasswordHistoryCount 24 -MinPasswordAge '1.00:00:00' -MaxPasswordAge '60.00:00:00' `
    -LockoutThreshold 5 -LockoutDuration '00:30:00' -LockoutObservationWindow '00:30:00'

Add-ADFineGrainedPasswordPolicySubject -Identity 'PSO-Tier-Admins' -Subjects 'T0-Admins','T1-Admins','T2-Admins'

Get-ADUserResultantPasswordPolicy -Identity t0-vaultkeeper     # confirm it applies
```

### 6F — Stretch: replace `svc-backup` with a group-managed service account

A **gMSA** has a 120-character password that AD rotates automatically; no human ever knows it.

```powershell
Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))     # lab shortcut; real domains wait ~10 hours
New-ADServiceAccount -Name 'gmsa-backup' -DNSHostName 'gmsa-backup.gielinor.local' `
    -PrincipalsAllowedToRetrieveManagedPassword 'SRV01$' -Path "OU=Service Accounts,OU=Tier1,$realm"
```

On SRV01, `Install-ADServiceAccount gmsa-backup` and re-register the task with principal `GIELINOR\gmsa-backup$` and logon type *Password*. Document what you did.

### Questions

1. After 6A the old Domain Admin accounts can't do admin things anywhere. What did Module 5's deny rights add that 6A alone wouldn't have?
2. Why is the deny-right design **still necessary** even though Tier 0 admins now have separate accounts?
3. What does `adminCount = 1` do, and why is it a trap for helpdesk delegation?
4. Name two things that break when an account is placed in *Protected Users*. Why might that be acceptable for Tier 0 admins and not for service accounts?
5. Why is a gMSA a better answer than "give the service account a really long password"?

```powershell
.\Test-TieredAdminLab.ps1 -Module 6
```

> 📸 Snapshot as `m6-hardened`.

---

## Module 7 — Watch the Gates (verify and detect)

**Goal:** a control you can't observe is a control you can't trust. Prove the model holds and write down how you'd notice it breaking.

### 7A — The deny events

```powershell
$c = Get-Credential GIELINOR\t2-navi
.\Get-TierLogons.ps1 -ComputerName wks01.gielinor.local -Credential $c -Id 4625 -Max 100 |
    Format-Table -AutoSize
```

For each failure: *who*, *from where*, *which logon type*, and the **SubStatus**.

### 7B — Zero Tier 0 on lower tiers

```powershell
$c1 = Get-Credential GIELINOR\t1-zelda
.\Get-TierLogons.ps1 -ComputerName srv01.gielinor.local -Credential $c1 -Id 4624 -Max 500 -User 't0-*'
.\Get-TierLogons.ps1 -ComputerName wks01.gielinor.local -Credential $c  -Id 4624 -Max 500 -User 't0-*'
```

Both should return nothing *new since the controls went in*. State exactly what you'd conclude from a Tier 0 name appearing in either output.

### 7C — Where are Tier 0 tickets coming from?

On the DC (Kerberos TGT requests):

```powershell
.\Get-TierLogons.ps1 -Id 4768 -Max 200 -User 't0-*' | Format-Table Time, Account, SourceIP -AutoSize
```

Tier 0 TGT requests should only come from Tier 0 locations. Is that true in your lab? (Be honest about what you ran from where.)

### 7D — Catch a privilege change

Watch the front door while someone tries to open it:

```powershell
Add-ADGroupMember -Identity 'Domain Admins' -Members 'Bandit'      # simulate the bad guy
Start-Sleep 3
Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4728 } -MaxEvents 5 | ForEach-Object {
    $d = @{}; ([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $d[$_.Name] = $_.'#text' }
    [pscustomobject]@{ Time=$_.TimeCreated; Group=$d.TargetUserName; Member=$d.MemberName; ChangedBy=$d.SubjectUserName }
}
Remove-ADGroupMember -Identity 'Domain Admins' -Members 'Bandit' -Confirm:$false     # undo it
```

Now write the detection rules (pseudo-code or KQL is fine) you'd deploy:

1. **Any change to Tier 0 groups** (`Domain Admins`, `Enterprise Admins`, `Schema Admins`, `Administrators`, `T0-Admins`) — which event IDs?
2. **Any successful logon by a `t0-` account on a non-Tier-0 host.**
3. **Any `0xC000015B` failure for a `t0-` or `t1-` account** (someone — or a script — is bumping into a tier wall).

*KQL starter (Microsoft Sentinel / Log Analytics `SecurityEvent` table):*

```kusto
SecurityEvent
| where EventID == 4728 and TargetUserName in ("Domain Admins","Enterprise Admins","Schema Admins","T0-Admins")
| project TimeGenerated, TargetUserName, MemberName, SubjectUserName, Computer
```

### 7E — Re-run the scorecard

```powershell
.\Test-TieredAdminLab.ps1
```

### Questions

1. Which would you page someone for at 3 a.m. — a 4728 on `Domain Admins`, or a 4625/0xC000015B for `t1-zelda` on `wks01`? Defend your choice.
2. A deny right produces a *failure* event. Why is that more valuable than the absence of a success event?
3. What does **not** show up in the Security log that you would still want to know? *(Think: where do the logs live, and who can clear them?)*

---

## Module 8 — The Warlord's Path (capstone: before and after)

**Scenario.** Bandit's workstation has been phished. The attacker has a foothold on **WKS01** with the privileges of an ordinary user — and then finds a local-admin bug. They have everything a Tier 2 machine can give them.

**Your job:** show, with evidence from *your own lab*, what that foothold could reach **before** your work (use your Module 1 exposure table) and **after** — and write it up.

> This is an analysis exercise. You are *reading* your own domain, not attacking it. The point is to see what an attacker would see.

### 8A — Enumerate like the attacker would (defensive view)

```powershell
# 1. Who is local admin where?
Invoke-Command -ComputerName wks01.gielinor.local,srv01.gielinor.local -Credential (Get-Credential GIELINOR\t2-navi) `
    -ScriptBlock { "== $env:COMPUTERNAME"; Get-LocalGroupMember -Group Administrators }
#   (srv01 will refuse a Tier 2 admin -- that IS the control working; use t1-zelda for that one)

# 2. Which accounts are Kerberoastable, and how privileged are they?
Get-ADUser -Filter 'ServicePrincipalName -like "*"' -Properties ServicePrincipalName,MemberOf,PasswordLastSet,PasswordNeverExpires |
    Select-Object SamAccountName, @{n='SPN';e={$_.ServicePrincipalName -join ';'}}, PasswordNeverExpires, @{n='Groups';e={($_.MemberOf | ForEach-Object {($_ -split ',')[0] -replace 'CN='}) -join ', '}}

# 3. Who still has adminCount = 1 (orphaned protection)?
Get-ADUser -Filter 'adminCount -eq 1' -Properties adminCount | Select-Object SamAccountName

# 4. Scheduled tasks storing credentials
$c1 = Get-Credential GIELINOR\t1-zelda
Invoke-Command -ComputerName srv01.gielinor.local -Credential $c1 -ScriptBlock { schtasks /Query /FO LIST /V | Select-String 'TaskName|Run As User' }

# 5. Final scorecard
.\Test-TieredAdminLab.ps1
```

### 8B — Build the after-picture

Rebuild the **exposure table** from Module 1 using fresh evidence (rerun `Invoke-LazyAdminDay.ps1` and see what now fails; read the logs). Put both tables in your report.

### 8C — Write the report

```markdown
# Tiered Administration Assessment — Gielinor
**Author:** <you>   **Date:** <date>   **Scope:** DC01, SRV01, WKS01

## 1. Summary
Three sentences for a non-technical reader: what was wrong, what changed, what is left.

## 2. Before (Module 1 evidence)
Exposure table + the shortest path from WKS01 to the Citadel.

## 3. What I built
Tier model, groups/accounts, delegation, GPOs, credential protections, PSO. One line each.

## 4. After (Module 8 evidence)
Exposure table after changes + the test matrix from Module 5.

## 5. Detection
The three rules from Module 7 and how each would fire.

## 6. Residual risk
At least four things this lab does NOT solve (e.g. Tier 2 admin laptop is still a normal PC;
the built-in Administrator; backups and the hypervisor; no PAWs, Credential Guard or LAPS;
Domain Admins can still change GPOs from DC01...).

## 7. Next steps (ordered)
Five concrete recommendations, with the reason for the order.
```

### 8D — Stretch (pick one)

- **Windows LAPS:** unique, rotating local administrator passwords per machine (`Update-LapsADSchema`, then a LAPS policy GPO) — removes the "same local admin everywhere" problem.
- **Authentication policy silos:** constrain *where* Tier 0 accounts can obtain a TGT from.
- **Privileged Access Workstation (PAW):** design (on paper) the machine Vaultkeeper must use for `t0-`. What is on it? What is blocked? How does it get patched?
- **Entra ID:** draw how this on-premises model maps onto cloud admin roles (Global Admin, break-glass accounts, PIM).

---

## What you can now put on your résumé (and in your portfolio)

- Designed and implemented a tiered administrative model (Tier 0/1/2) in Active Directory
- Built OU, group, and delegation structure with least-privilege separation of duties
- Enforced logon restrictions with GPO user-rights assignments and local-admin preferences
- Remediated privileged-account sprawl, AdminSDHolder residue, and a Domain-Admin service account
- Hardened Tier 0 identities with Protected Users, non-delegable flags, and fine-grained password policy
- Verified and detected tier violations from Windows Security events (4624/4625/4672/4728/4768)
- Wrote a before/after assessment with residual-risk analysis

**Next in the Sysadmin path:** put this domain under Microsoft Defender for Identity or a SIEM, and replay the Module 7 detections against real telemetry.
