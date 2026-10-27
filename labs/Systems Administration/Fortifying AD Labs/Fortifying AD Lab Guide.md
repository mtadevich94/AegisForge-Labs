# Fortifying AD: Lab Guide

*The Wrkstation Chronicles: The Iron Gates*

---

## The story

The Three Keeps are walled and every Warden has a proper key. But walk the courtyard at night and you'll hear the old habits: guards shouting orders to anyone who'll listen, gatekeepers who wave through anyone who knows the right password hash, and a few ancient locks that nobody dares to replace because nobody remembers what they open.

You are the Gatekeeper again. Quiet the shouting, replace the rusty keys, and, above all, **find out what still depends on the old ways before you take them away.**

## How to use this guide

| Symbol | Meaning |
|---|---|
| 🛡 | **Why this matters:** the attack or weakness in plain language |
| ⚠ | **What can break:** real-world consequences, so you'll recognize them at work |
| 📸 | Take a snapshot |
| ✅ | Check that it worked |
| ❓ | Questions to answer in your report |

**Conventions**

- Commands prefixed with a machine name run **there**. Elevated (Administrator) PowerShell unless noted.
- **GPO steps:** on DC01, open **Group Policy Management** (`gpmc.msc`), create or edit the GPO named in the step, then link it where the step says. Settings are named exactly as they appear in the editor. If your screen differs, search for the setting name.
- After a GPO change, run `gpupdate /force` on the target machine. Where a reboot is needed, the guide says so.
- **Read the Legacy Field Guide first.** The modules assume you have.

> 📸 **Before you start:** all four VMs snapshotted as `fortify-start` (see the Environment Setup).

## Contents

| # | Module | Topic |
|---|---|---|
| 1 | Read the Room | Measure the baseline |
| 2 | Turn On the Lanterns | Auditing: find the legacy dependencies |
| 3 | Silence the Whispers | LLMNR, NetBIOS, mDNS |
| 4 | Lock the SMB Gates | SMBv1, signing, encryption |
| 5 | The Legacy Warden | LDAP signing and channel binding |
| 6 | The NTLM Reckoning | NTLMv2-only and restricting NTLM |
| 7 | Harden the Tickets | Kerberos, RC4, service accounts |
| 8 | Stop the Quiet Walk | Lateral-movement and living-off-the-land controls |
| 9 | The Inspection | Capstone: re-measure, report, plan the rollout |

---

# Module 1 — Read the Room

**Goal:** record how exposed the domain is **before** you change anything. This is your "before".

🛡 You can't prove a fix without a "before". It also teaches you what "exposed" looks like in real output.

> 📸 Already on `fortify-start`. Don't change anything in this module.

Save the output of each check (copy it into your report's baseline table).

### 1A — SMB (run on DC01, SRV01 and WKS01)

```powershell
Get-SmbServerConfiguration | Select EnableSMB1Protocol, EnableSMB2Protocol, RequireSecuritySignature, EnableSecuritySignature, EncryptData
Get-SmbClientConfiguration | Select RequireSecuritySignature, EnableSecuritySignature
```

On a Windows **client** (WKS01): `Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol | Select State`. On a **server**: `Get-WindowsFeature FS-SMB1`.

Write down, for each machine: is SMBv1 present or enabled? Is signing **required** or only **enabled** (offered if the other side asks)? Defaults differ between Windows versions, so measure, don't assume.

### 1B — Name-resolution fallbacks (run on WKS01 and SRV01)

```powershell
# LLMNR: if this returns nothing, LLMNR is NOT disabled by policy (so it's on)
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name EnableMulticast -ErrorAction SilentlyContinue

# NetBIOS over TCP/IP: 0 = default (use DHCP/default), 1 = enabled, 2 = disabled
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' | Select Description, TcpipNetbiosOptions

# mDNS: if this returns nothing, it's at its default (on)
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name EnableMDNS -ErrorAction SilentlyContinue
```

### 1C — NTLM (run on DC01, SRV01 and WKS01)

```powershell
# LAN Manager authentication level. If missing, the OS default applies.
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa').LmCompatibilityLevel
```

| Value | Meaning |
|---|---|
| 0–2 | Allows weak, old NTLM responses (poor) |
| 3 | Clients send NTLMv2 only (a common default) |
| 4 | Domain controllers refuse LM |
| 5 | Domain controllers refuse LM and NTLMv1 (recommended) |

### 1D — LDAP (test from WATCHTOWER against DC01)

Instead of reading a registry value whose meaning varies, **test the behavior.** From **WATCHTOWER**, try an unsigned, cleartext "simple bind", the way an old app would:

```bash
ldapsearch -x -H ldap://10.10.10.10 -D "t2-navi@gielinor.local" -W \
  -b "DC=gielinor,DC=local" "(sAMAccountName=t2-navi)" dn
```

Enter the lab password when prompted. If you get a result (`dn: CN=...`), the DC **accepts unsigned cleartext binds**. That's today's baseline.

### 1E — Kerberos and accounts (run on DC01)

```powershell
# Accounts with an SPN (Kerberoastable), their encryption types, and password age
Get-ADUser -Filter 'ServicePrincipalName -like "*"' -Properties ServicePrincipalName, 'msDS-SupportedEncryptionTypes', PasswordLastSet, PasswordNeverExpires |
  Select SamAccountName, @{n='SPN';e={$_.ServicePrincipalName -join ';'}}, 'msDS-SupportedEncryptionTypes', PasswordLastSet, PasswordNeverExpires

# Accounts that don't require Kerberos pre-authentication
Get-ADUser -Filter 'DoesNotRequirePreAuth -eq $true' | Select SamAccountName

# Computers trusted for unconstrained delegation (DCs are expected; anything else is a finding)
Get-ADComputer -Filter 'TrustedForDelegation -eq $true' | Select Name
```

An empty `msDS-SupportedEncryptionTypes` means "the default". Note what the default allows.

### 1F — Local admin and LAPS (run on WKS01 and SRV01)

```powershell
Get-LocalGroupMember -Group Administrators
Get-Command Get-LapsADPassword -ErrorAction SilentlyContinue   # present = Windows LAPS is available
```

### 1G — Remote exposure (test from WATCHTOWER against WKS01)

```bash
for p in 135 445 3389 5985; do nc -zv -w2 10.10.10.20 $p 2>&1 | tail -1; done
```

A `succeeded` line means that port is reachable from *another machine on the network*. In the real world, "another machine" might be a compromised neighbor. Write down which ports answer.

### 1H — Logging and local protection (run on WKS01)

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -ErrorAction SilentlyContinue   # none = not enabled by policy
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa').RunAsPPL                                                       # 1 = LSA protection on
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -ErrorAction SilentlyContinue).UseLogonCredential   # 1 = cleartext creds in memory (bad)
```

### ❓ Questions for Module 1

1. Which of the checks surprised you? Which "weak" settings turned out to be fine?
2. Which findings could an attacker use **without any credentials** (just by being on the network)? Which need a stolen password first?
3. Which findings can you fix with **no** compatibility risk, and which could break something?

---

# Module 2 — Turn On the Lanterns

**Goal:** enable auditing so the network **tells you** who and what still uses NTLM, unsigned LDAP, SMBv1 and RC4. Change *nothing else.*

🛡 **This is the most important module in the lab.** Real outages come from enforcing before auditing. Auditing costs nothing, harms nothing, and turns "I think this is safe" into "I know what depends on this".

⚠ **How long should you audit in real life?** Weeks, not minutes. A scanner that runs monthly won't appear in a one-day log. In this lab you'll audit for a few minutes and *generate* the traffic yourself.

> 📸 Snapshot all four VMs as `f2-before-audit`.

### 2A — Audit NTLM

On **DC01**, create `GPO-Fortify-DC` and link it to the **Domain Controllers** OU. Edit it:

**Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options**

| Setting | Value |
|---|---|
| Network security: Restrict NTLM: Audit NTLM authentication in this domain | **Enable all** |

On DC01, create `GPO-Fortify-Members` and link it to **`OU=Realm`**. Edit it:

| Setting | Value |
|---|---|
| Network security: Restrict NTLM: Audit Incoming NTLM Traffic | **Enable auditing for all accounts** |
| Network security: Restrict NTLM: Outgoing NTLM traffic to remote servers | **Audit all** |

> These settings **only log**. They don't block anything.

### 2B — Make sure the relevant events are recorded

On **DC01**, in `GPO-Fortify-DC`, under **Computer Configuration → Policies → Windows Settings → Security Settings → Advanced Audit Policy Configuration → Audit Policies**:

| Subcategory | Setting |
|---|---|
| Account Logon → Audit Credential Validation | Success and Failure |
| Account Logon → Audit Kerberos Service Ticket Operations | Success and Failure |
| Logon/Logoff → Audit Logon | Success and Failure |

(Your Tiered Admin lab may already have these. If so, skip them.)

### 2C — Audit unsigned LDAP

On **DC01**, turn on the diagnostic that records unsigned binds (this one is a registry setting, so it's one line):

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics" /v "16 LDAP Interface Events" /t REG_DWORD /d 2 /f
```

Unsigned binds will now be logged to **Event Viewer → Applications and Services Logs → Directory Service** as **Event 2889**. A daily summary is **Event 2887**.

### 2D — Audit SMBv1 usage (SRV01)

```powershell
Set-SmbServerConfiguration -AuditSmb1Access $true -Force
```

If SMBv1 is ever used, it's logged (look for **Event 3000** in `Applications and Services Logs → Microsoft → Windows → SMBServer → Audit`). On a modern server with SMBv1 absent, there will be nothing to log until Module 4.

### 2E — Apply

On DC01, SRV01 and WKS01, run `gpupdate /force`. (Restart WKS01 and SRV01 once if auditing doesn't seem to take effect.)

### 2F — Generate some "legacy" traffic

You'll mimic what real networks do all day.

**From WKS01**, as a domain user (for example `t2-navi`), connect to SRV01's share **two ways**:

```powershell
dir \\srv01.gielinor.local\Keep      # by NAME: Kerberos works
dir \\10.10.10.40\Keep               # by IP: Kerberos can't be used, so NTLM
```

**From WATCHTOWER**, act as an old Linux client:

```bash
# An SMB connection (smbclient authenticates with NTLM)
smbclient //10.10.10.40/Keep -U 'GIELINOR\t2-navi' -c 'ls'

# An LDAP simple bind (the unsigned, cleartext kind)
ldapsearch -x -H ldap://10.10.10.10 -D "t2-navi@gielinor.local" -W \
  -b "DC=gielinor,DC=local" "(sAMAccountName=t2-navi)" dn
```

### 2G — Read the lanterns

On **SRV01**:

```powershell
Get-WinEvent -LogName 'Microsoft-Windows-NTLM/Operational' -MaxEvents 20 | Select TimeCreated, Id, Message | Format-List
```

On **DC01**:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Directory Service'; Id=2889} -MaxEvents 5 | Format-List TimeCreated, Message
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4776} -MaxEvents 10 | Select TimeCreated, Message | Format-List
```

What to look for:

| Where | Event | Means |
|---|---|---|
| SRV01, NTLM Operational | **8002** (incoming NTLM audit) | Something authenticated **to SRV01 with NTLM** |
| WKS01, NTLM Operational | **8001** (outgoing NTLM audit) | WKS01 **sent** NTLM to a server |
| DC01, NTLM Operational | **8004** | The DC handled an NTLM authentication |
| DC01, Security | **4776** | The DC validated an NTLM credential |
| DC01, Directory Service | **2889** | A client did an **unsigned or cleartext LDAP bind**, with its IP and account |

(Event IDs and log names can vary slightly by Windows build. Read the message text.)

You should see the **by-IP** connection and WATCHTOWER's `smbclient`, but **not** the by-name Kerberos one. That difference is the entire reason NTLM survives: **by-IP, by-alias, or non-Windows clients all fall back to it.**

### 2H — Start your Legacy Register

In your report's **Legacy Register**, add one row for everything you just found:

| Client | Target | What it used | Event that proves it | Owner | Decision |
|---|---|---|---|---|---|
| WKS01 (`t2-navi`) | `\\10.10.10.40\Keep` | NTLM (by IP) | 8001 / 8002 | | Fix the path to use the name |
| WATCHTOWER | SRV01 SMB | NTLM (`smbclient`) | 8002 | | ? |
| WATCHTOWER | DC01 LDAP | Unsigned simple bind | 2889 | | ? |

The "?" decisions are the point. You'll make them over the next modules.

⚠ **Leave the auditing on** for the rest of the lab.

### ❓ Questions for Module 2

1. Why did the by-name connection **not** show up as NTLM?
2. Name three real systems in a business that would show up in this log the way WATCHTOWER did.
3. How long would you audit before trusting this list? Why?

> 📸 Snapshot all four as `f2-audit-on`.

---

# Module 3 — Silence the Whispers

**Goal:** turn off **LLMNR**, **NetBIOS name service (NBT-NS)** and **mDNS**.

🛡 When DNS can't answer, Windows **asks everyone nearby** ("does anyone know where `fileserver` is?") over **LLMNR**, **NetBIOS** and **mDNS**. An attacker on the network can answer, claim to be that host, and the client will **send its credentials to them**. These protocols exist only as a **fallback**, so on a healthy network they only help the attacker.

⚠ **What can break**

| Thing | Why | What to do first |
|---|---|---|
| Old apps and scripts using **single-label names** or typos | They rely on the fallback | Fix the name or DNS record |
| **Workgroup file sharing and browsing** | Uses NetBIOS | Use DNS names |
| Some printers and legacy devices that advertise via mDNS/NetBIOS | Discovery stops | Configure by address or DNS |
| **Missing DNS records** | The fallback was hiding the gap | Fix **DNS first**, because turning the fallback off exposes the hole |

**Do DNS hygiene before you disable fallbacks.** Check that everything has a record: `Resolve-DnsName <name>` for each host you use.

> 📸 Snapshot all four as `f3-before-whispers`.

### 3A — See the whispers (before)

On **WKS01**, start **Wireshark** (you used it in Packet Watch), capture on the Ethernet interface, and use the display filter:

```
llmnr || nbns || mdns
```

Then, in PowerShell on WKS01, ask for a name that doesn't exist:

```powershell
ping nosuchserver01
```

You should see **LLMNR** (UDP 5355) and possibly **NBNS** (UDP 137) queries go out to the whole network. (No Wireshark? On WATCHTOWER: `sudo tcpdump -ni any 'udp port 5355 or udp port 137 or udp port 5353'`. Multicast may not cross every VirtualBox setup, so seeing the queries leave WKS01 is enough.)

That's the whisper. Anyone listening could have answered.

### 3B — Disable LLMNR (GPO)

In `GPO-Fortify-Members` (linked to `OU=Realm`):

**Computer Configuration → Policies → Administrative Templates → Network → DNS Client**

| Setting | Value |
|---|---|
| Turn off multicast name resolution | **Enabled** |

### 3C — Disable NetBIOS over TCP/IP and mDNS

NetBIOS over TCP/IP is configured **per network adapter**, not by a simple GPO. Our lab uses static addresses, so do it on **WKS01 and SRV01** with one command each:

```powershell
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' |
  Invoke-CimMethod -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions=2}
```

In production you'd set this through **DHCP option 001 (Microsoft Disable NetBIOS Option)** or through your management tool, so you aren't touching each machine.

Turn off **mDNS** (one line, per machine):

```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name EnableMDNS -Value 0 -Type DWord -Force
```

Apply: `gpupdate /force`, then **restart WKS01 and SRV01**.

### 3D — Prove it (after)

Repeat 3A:

```powershell
ping nosuchserver01
```

Wireshark should show **no** LLMNR/NBNS/mDNS queries now. Windows asks DNS only, gets "not found", and stops. Also re-run the 1B checks.

✅ `EnableMulticast` is `0`; NetBIOS options show `2`; no whisper traffic.

### ❓ Questions for Module 3

1. Why is "the name resolution fallback" worth removing even though it *helps* when DNS is broken?
2. What would you check in a real network **before** turning these off?
3. Which of the "what can break" items could realistically apply to a company with a manufacturing floor?

> 📸 Snapshot all four as `f3-whispers-off`.

---

# Module 4 — Lock the SMB Gates

**Goal:** make sure SMBv1 is gone, **require SMB signing**, understand when to use SMB encryption, and close anonymous access.

🛡 SMB is how Windows shares files, printers and admin tools. Three weaknesses matter:

- **SMBv1** is an ancient version with no modern protections, and it was the protocol behind some of the most damaging worm outbreaks. There's essentially no reason to run it except for a device that can't do better.
- **Unsigned SMB** lets an attacker in the middle **relay or tamper** with SMB traffic. **Signing** makes each packet prove it came from the real peer.
- **Anonymous access** lets someone with no account list users and shares.

⚠ **What can break**

| Setting | Breaks | In the real world |
|---|---|---|
| **Remove SMBv1** | Old scanners, NAS, XP/2003-era machines, industrial/OT gear | The #1 source of "we turned it off and the line stopped" stories |
| **Require signing** | Clients that don't support it (some old Samba, old appliances); slight CPU cost; third-party SMB stacks | Usually fine on modern gear, so audit first |
| **SMB encryption** | Clients older than Windows 8/Server 2012 or SMB3-incapable; extra CPU; can blind network inspection tools | Use selectively on sensitive shares, not blindly everywhere |
| **Restricting anonymous access** | Old apps that enumerate shares anonymously | Rare today |

> 📸 Snapshot all four as `f4-before-smb`.

### 4A — *(Optional)* Resurrect the dinosaur

To feel what removing SMBv1 means, bring it back **on SRV01 only**, then watch your "legacy device" use it.

> ⚠ **Isolated lab only.** You are deliberately re-installing a dangerous protocol. Don't do this on a real machine.

On **SRV01**:

```powershell
Install-WindowsFeature FS-SMB1
Restart-Computer
```

After the reboot, on **SRV01**: `Get-SmbServerConfiguration | Select EnableSMB1Protocol`. If it shows `False`, enable it with `Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force`. Keep auditing on:

```powershell
Set-SmbServerConfiguration -AuditSmb1Access $true -Force
```

From **WATCHTOWER**, pretend to be a very old scanner (allow the old protocol on the client side):

```bash
smbclient //10.10.10.40/Keep -U 'GIELINOR\t2-navi' -m NT1 --option='client min protocol=NT1' -c 'ls'
```

If it connects, on **SRV01** check `Applications and Services Logs → Microsoft → Windows → SMBServer → Audit` for **Event 3000** (an SMB1 client). That's your legacy device **showing up in the audit**, which is what you'd see in real life. (If `smbclient` refuses the old protocol on your version, treat this as a story and move on. The lesson doesn't need it to succeed.)

### 4B — Remove SMBv1

On **SRV01** and **WKS01** (and DC01, where it should already be absent):

```powershell
# Servers
Uninstall-WindowsFeature FS-SMB1
# Clients (Windows 11)
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
# Both
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
```

Restart SRV01 (and WKS01 if prompted). If you did 4A, repeat the `smbclient -m NT1` from WATCHTOWER now. **It should fail.** That's what an old device sees when you do this in production.

✅ `Get-SmbServerConfiguration | Select EnableSMB1Protocol` shows `False` on every machine.

### 4C — Require SMB signing (GPO)

In `GPO-Fortify-Members` (`OU=Realm`) **and** `GPO-Fortify-DC` (Domain Controllers):

**Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options**

| Setting | Value |
|---|---|
| Microsoft network server: Digitally sign communications (always) | **Enabled** |
| Microsoft network client: Digitally sign communications (always) | **Enabled** |

Apply with `gpupdate /force` and **restart** the machines so the SMB services pick it up.

Prove it, from WKS01:

```powershell
dir \\srv01.gielinor.local\Keep | Out-Null
Get-SmbConnection | Select ServerName, Dialect, Signed, Encrypted
```

✅ `Signed` is `True`. And on each machine, `Get-SmbServerConfiguration | Select RequireSecuritySignature` shows `True`.

> **Honest note:** in *your* lab nothing breaks, because every machine is modern and WATCHTOWER's `smbclient` supports signing. Real networks are different. The Legacy Field Guide lists what *would* break. Recent Windows releases are also moving towards requiring signing by default, so check what your builds already do.

### 4D — Encryption: when, and when not

SMB can also **encrypt** traffic. It protects against eavesdropping, not just tampering. It's best used on **specific sensitive shares**, because it costs CPU and rules out older clients.

On SRV01, encrypt just the `Keep` share:

```powershell
Set-SmbShare -Name Keep -EncryptData $true -Force
```

Test from WKS01 (`dir \\srv01.gielinor.local\Keep`, then `Get-SmbConnection | Select ServerName, Signed, Encrypted`). From WATCHTOWER, `smbclient` may or may not connect depending on your version's SMB3 encryption support. If it fails, **that's the lesson**: encryption narrows who can talk to you. Decide whether the protection is worth it, and if not, undo it:

```powershell
Set-SmbShare -Name Keep -EncryptData $false -Force
```

### 4E — Close anonymous access

In `GPO-Fortify-Members` and `GPO-Fortify-DC`, under **Security Options**:

| Setting | Value |
|---|---|
| Network access: Restrict anonymous access to Named Pipes and Shares | **Enabled** |
| Network access: Do not allow anonymous enumeration of SAM accounts and shares | **Enabled** |
| Network access: Let Everyone permissions apply to anonymous users | **Disabled** |

Test from WATCHTOWER (anonymous):

```bash
smbclient -L //10.10.10.40 -N
```

Expected: access denied, or an empty list, and no user or share names for an anonymous visitor.

### ❓ Questions for Module 4

1. What does SMB signing protect against that a password doesn't?
2. If you'd found a scanner in your audit that still needs SMBv1, list **three** options besides "leave it alone" (see the field guide).
3. Why not just turn on SMB encryption everywhere?

> 📸 Snapshot all four as `f4-smb-done`.

---

# Module 5 — The Legacy Warden (LDAP)

**Goal:** require **LDAP signing** and **channel binding**, watch a legacy client break, and fix it the right way with **LDAPS**.

🛡 **LDAP** is how applications query Active Directory (user lookups, group membership, "is this password right?"). By default, a client can send a password in **cleartext** over port 389 (a *simple bind*) or authenticate without signing, which lets an attacker **sniff or relay** it. **Signing** prevents tampering; **channel binding** ties an authentication to its encrypted channel so it can't be forwarded elsewhere.

⚠ **What can break (this one breaks more than people expect)**

| Thing | Why | Symptom | Fix |
|---|---|---|---|
| **VPNs, firewalls, wireless controllers, web apps** that look users up | They use **simple bind on 389** | "Strong authentication required" or login failures | Switch the device to **LDAPS (636)** or StartTLS |
| **Old Java/PHP/Python scripts** | Same | Same | Update the connection string and trust the DC's certificate |
| **Anything that can't validate a certificate** | LDAPS needs a trusted cert | Connection errors | Issue a proper certificate (an internal CA) |

Unlike NTLM, **LDAP signing has no per-client exception list.** If a device can't comply, the options are to upgrade it, isolate it, or keep signing at *none* and compensate. So **audit first (Module 2 gave you Event 2889).**

> 📸 Snapshot **DC01 and WATCHTOWER** as `f5-before-ldap`.

### 5A — Confirm the baseline

From **WATCHTOWER**, rerun the simple bind from Module 1D. It works. On DC01, **Event 2889** shows WATCHTOWER's IP and the account. In a real domain, that list is your to-do list.

### 5B — Require signing and channel binding

On DC01, in `GPO-Fortify-DC` (linked to Domain Controllers), under **Security Options**:

| Setting | Value |
|---|---|
| Domain controller: LDAP server signing requirements | **Require signing** |
| Domain controller: LDAP server channel binding token requirements | **When supported** |

(*When supported* enforces channel binding for clients that can do it and still allows ones that can't. *Always* is stricter, and is a later step in a real rollout.)

Also, on workstations and servers, in `GPO-Fortify-Members`:

| Setting | Value |
|---|---|
| Network security: LDAP client signing requirements | **Require signing** |

On DC01: `gpupdate /force`. Restart DC01 if the setting doesn't apply.

> ⚠ **Domain controllers are the center of everything.** Never apply this first on a production DC without auditing. You have a snapshot; use it if this goes wrong.

### 5C — Watch the legacy client break

From **WATCHTOWER**, repeat the simple bind from 5A. It should now fail with an error like:

```
ldap_bind: Strong(er) authentication required (8)
        additional info: 00002028: LdapErr: DSID-..., The server requires binds to turn on
        integrity checking if SSL\TLS are not already active on the connection
```

(Exact wording varies.) That's an old appliance, an hour after you enforced the setting.

Windows-native tools (`Get-ADUser`, Active Directory Users and Computers, other domain-joined machines) **still work**, because Windows negotiates signing automatically. **Only the legacy-style client broke.** That's why this setting passes your own testing and then fails in production.

### 5D — Fix it the right way: LDAPS

A client can satisfy the requirement by using **TLS** (LDAPS on port 636), which gives encryption *and* integrity. The DC needs a certificate. A real network uses an internal certificate authority (Active Directory Certificate Services); for this lab we'll create a self-signed one so you can see the mechanics.

> **Lab shortcut only.** A self-signed cert is acceptable in an isolated lab. In production, use a certificate from your CA and never tell clients to skip validation.

**On DC01:**

```powershell
$cert = New-SelfSignedCertificate -DnsName 'dc01.gielinor.local' -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(1)
Export-Certificate -Cert $cert -FilePath C:\dc01.cer | Out-Null
certutil -encode C:\dc01.cer C:\dc01.pem
type C:\dc01.pem
```

Wait a minute (or restart DC01) for the directory service to pick up the new certificate. Copy the text from `type C:\dc01.pem` (the block between `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`, inclusive).

**On WATCHTOWER:**

```bash
# Paste the certificate text into this file
nano ~/dc01.pem

# Let the client find the DC by the name on the certificate
echo "10.10.10.10 dc01.gielinor.local" | sudo tee -a /etc/hosts

# Check that port 636 answers
nc -zv dc01.gielinor.local 636

# Query over TLS, trusting the DC's certificate
LDAPTLS_CACERT=$HOME/dc01.pem ldapsearch -x -H ldaps://dc01.gielinor.local -D "t2-navi@gielinor.local" -W \
  -b "DC=gielinor,DC=local" "(sAMAccountName=t2-navi)" dn
```

✅ The query now succeeds **with signing required.** The legacy client works again, because it was moved to a protected connection.

If it fails: check the certificate was pasted completely, the hostname matches `dc01.gielinor.local`, and DC01 has had a minute to load the cert.

### 5E — Why not "Always" for channel binding?

You chose *When supported*. In the real world, you move to **Always** only after auditing shows no client lacks channel-binding support. Many LDAP libraries (including the one in `ldapsearch`) don't implement it. That's a real compatibility edge, and exactly why the setting has two levels.

### ❓ Questions for Module 5

1. Why did Windows-native tools keep working while `ldapsearch` broke?
2. Why is there no "exception list" for LDAP signing, when NTLM has one? What does that mean for rollout planning?
3. Write the Legacy Register entry for WATCHTOWER's LDAP use. What's your decision, and what's the owner's next step?

> 📸 Snapshot DC01 and WATCHTOWER as `f5-ldap-done`.

---

# Module 6 — The NTLM Reckoning

**Goal:** move to **NTLMv2-only**, then **restrict incoming NTLM on SRV01** and see exactly what breaks and why. This is the lab's centerpiece.

🛡 **NTLM** is the old challenge-response authentication that Windows falls back to when Kerberos isn't possible. Its problems:

- It can be **relayed**: an attacker who tricks a machine into authenticating to them can pass those credentials on to a real server.
- Captured responses can be **cracked offline** (NTLMv1 trivially, NTLMv2 slower but still).
- It doesn't prove the **server** is genuine.

Kerberos needs a **hostname**, **DNS**, a registered **SPN** and a **domain controller**. When any is missing, Windows falls back to NTLM *silently*. That's why NTLM is everywhere, and why it's hard to remove.

⚠ **Do not simply "disable NTLM".** The correct sequence is: **audit → fix what you can → restrict where it's safe → exceptions → expand.** You already audited in Module 2.

### What can break

| Thing | Why it uses NTLM | What to do |
|---|---|---|
| Connections **by IP address** | Kerberos can't use an IP | Use DNS names |
| Connections to **DNS aliases (CNAMEs)** | No matching SPN for the alias | Register the SPN, or use DFS Namespaces |
| **Linux/Unix and appliances** | Not configured for Kerberos | Configure Kerberos, or isolate |
| **Workgroup machines and local accounts** | No domain, no Kerberos | Keep NTLM there, and isolate |
| **Apps with a bad SPN** | Duplicate or missing SPNs | Fix the SPN |
| **External/old trusts** | Often NTLM | Keep exceptions |
| **MS-CHAPv2 (VPN, Wi-Fi)** | Built on the NT hash | Move to certificate-based auth |

> 📸 Snapshot all four as `f6-before-ntlm`.

### 6A — NTLMv2 only

This stops the weakest form (NTLMv1) and the oldest LM responses. In `GPO-Fortify-Members` (`OU=Realm`) **and** `GPO-Fortify-DC`:

**Security Options → Network security: LAN Manager authentication level** → **Send NTLMv2 response only. Refuse LM & NTLM**

Check with the audit: in Module 2's log, did anything use NTLMv1? On a DC, in **Security → Event 4624**, the *Detailed Authentication Information* section shows the **Package Name (NTLM only)** (`NTLM V1` or `NTLM V2`). Anything on `NTLM V1` is a legacy device you must deal with *before* this setting.

Apply (`gpupdate /force`; restart WKS01, SRV01, DC01) and re-test:

```powershell
dir \\srv01.gielinor.local\Keep
dir \\10.10.10.40\Keep
```

Both should still work, because modern Windows already uses NTLMv2.

From WATCHTOWER, `smbclient //10.10.10.40/Keep -U 'GIELINOR\t2-navi' -c 'ls'` should also still work (Samba uses NTLMv2).

### 6B — Restrict incoming NTLM on SRV01 (the server-level pilot)

You'll restrict NTLM on **one server first**. Create `GPO-Fortify-SRV01` and link it to **`OU=Servers,OU=Tier1,OU=Realm`** (SRV01's OU). Edit:

**Security Options**

| Setting | Value |
|---|---|
| Network security: Restrict NTLM: Incoming NTLM traffic | **Deny all domain accounts** |

On SRV01: `gpupdate /force`, then restart SRV01.

> **Why SRV01, not everything?** A single server is a *pilot*. If it breaks, the blast radius is one share.

### 6C — Feel it break

From **WKS01**:

```powershell
dir \\srv01.gielinor.local\Keep      # by NAME: Kerberos. Should still WORK
dir \\10.10.10.40\Keep               # by IP: NTLM. Should now FAIL
```

From **WATCHTOWER**:

```bash
smbclient //10.10.10.40/Keep -U 'GIELINOR\t2-navi' -c 'ls'     # NTLM only. Should now FAIL
```

The error text varies ("access denied", "logon failure", and similar). On **SRV01**, `Microsoft-Windows-NTLM/Operational` now records the **blocked** attempts.

What just happened:

- **WKS01 by name** still works, because it used **Kerberos**.
- **WKS01 by IP** and **WATCHTOWER** failed, because they could only use **NTLM**.

This is exactly what happens in a real company when an app has a hard-coded IP or a Linux box isn't Kerberos-aware.

### 6D — Decide: fix, isolate, or accept

For **each** thing that broke, choose.

**The by-IP connection (Windows).** The fix is easy: use the **name**. In a real company you'd find the script or shortcut and repoint it. ✅ Done.

**WATCHTOWER (the Linux box).** Your real options:

1. **Make it use Kerberos** (best). See the optional recipe below.
2. **Allow NTLM on a dedicated server** and fence it: put the NTLM-dependent file share on a *separate* server that stays unrestricted, while allowing only WATCHTOWER to reach it (host-firewall scoping, Module 8; segmentation, the Gatehouse lab).
3. **Retire the dependency.** Does it need to exist?
4. **Accept the risk, in writing.** Write down the owner, the reason and a review date.

> **Why no "exempt this one client" switch?** The *incoming* NTLM restriction is per **server**, not per client. There's no list that says "allow NTLM from only this machine." The exception lists work the other direction (remote-server exceptions for *outgoing* NTLM, and domain-level server exceptions). That's why isolation and placement matter so much.

**Optional recipe: Kerberos for WATCHTOWER** *(untested; treat as a stretch)*

```bash
sudo apt install -y krb5-user
# When asked: default realm GIELINOR.LOCAL, KDC and admin server dc01.gielinor.local
echo "10.10.10.10 dc01.gielinor.local" | sudo tee -a /etc/hosts
echo "10.10.10.40 srv01.gielinor.local" | sudo tee -a /etc/hosts
kinit t2-navi@GIELINOR.LOCAL
smbclient //srv01.gielinor.local/Keep -k -c 'ls'
```

Pitfalls: the **realm must be uppercase**; WATCHTOWER's **clock must be within about 5 minutes** of the domain; and you must use the **hostname**, never the IP.

### 6E — Enter it in your Legacy Register

Add WATCHTOWER-to-SRV01 and the by-IP shortcut. For each: what it needs, the decision, the owner, the review date.

### 6F — Going further (read, don't do)

A real rollout continues in steps, each preceded by auditing:

1. NTLMv2 only everywhere ✅ (6A)
2. Restrict **incoming** NTLM on selected servers ✅ (6B)
3. Restrict **outgoing** NTLM from clients to remote servers (with an exception list)
4. Restrict NTLM **at the domain controllers** ("NTLM authentication in this domain"), with a server-exception list
5. Eventually, disable NTLM broadly, as Microsoft is moving the platform to do

Each step needs its own audit and pilot.

### ❓ Questions for Module 6

1. Why does connecting by IP use NTLM while connecting by name uses Kerberos?
2. Why is "Deny all NTLM" on the whole domain a bad *first* move?
3. Your audit shows a Linux server, a scanner and an old app depend on NTLM. Order the options (replace, reconfigure, isolate, accept) for each, and justify.

> 📸 Snapshot all four as `f6-ntlm-done`.

---


# Module 7 — Harden the Tickets (Kerberos)

**Goal:** find where weak Kerberos encryption (**RC4**) is still in use, move service accounts to **AES**, and understand why **gMSA** accounts are the real fix for service-account passwords.

🛡 Kerberos is the protocol you want Windows to use. But it has its own soft spots:

- **RC4 tickets** are weaker than AES. Any user can request a service ticket for an account with an SPN, then try to crack its password **offline**. RC4 tickets crack far faster than AES ones. (This is the idea behind "Kerberoasting". You are only *measuring the exposure* here, not attacking.)
- **Service accounts with human-chosen passwords** are the usual target, because nobody rotates them.
- **Delegation** and **no-pre-auth** settings widen what a stolen identity can do.

⚠ **What can break**

| Setting | Breaks | In the real world |
|---|---|---|
| **Disallow RC4** | Accounts that have no AES keys (passwords not changed since the domain was very old), old keytabs from Linux/Unix services, old third-party Kerberos clients, some appliances | Test with one account at a time. A service account whose password was never reset after the domain reached its current level may have no AES keys until the password is reset |
| **Changing an account's password to get AES keys** | Every place that password is stored: services, scheduled tasks, app config files, connection strings | Find where the account is used **first**. This is the hidden cost of "just reset it" |
| **Moving to gMSA** | Software that can't use gMSA (some vendor apps want a typed-in password) | Many Microsoft services support gMSA. Many third-party ones don't |

> 📸 Snapshot DC01 and SRV01 as `f7-before-kerberos`.

### 7A — Audit: who still receives RC4 tickets?

On **DC01**, make sure Kerberos service-ticket auditing is on (it should be from Module 2; this confirms it):

```powershell
auditpol /get /subcategory:"Kerberos Service Ticket Operations"
```

It should show **Success and Failure**. If not:

```powershell
auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable
```

Generate a ticket for the service accounts' SPNs. On **WKS01**, signed in as `t2-navi`:

```powershell
klist purge
# Ask for tickets to the SPNs created in the Tiered Admin lab
klist get MSSQLSvc/srv01.gielinor.local:1433
klist get HTTP/srv01.gielinor.local
klist tickets
```

In the `klist tickets` output, look at **KerbTicket Encryption Type** for each. `AES-256-CTS-HMAC-SHA1-96` is good. `RSADSI RC4-HMAC(NT)` is the weak one.

On **DC01**, look at the event log:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4769} -MaxEvents 30 |
  ForEach-Object {
    $x = [xml]$_.ToXml()
    $d = @{}; $x.Event.EventData.Data | ForEach-Object { $d[$_.Name] = $_.'#text' }
    [pscustomobject]@{ Time=$_.TimeCreated; Service=$d.ServiceName; Client=$d.IpAddress; EncType=$d.TicketEncryptionType }
  } | Format-Table -AutoSize
```

`EncType` of **0x17** is RC4. **0x12** is AES-256. **0x11** is AES-128.

> This is a one-off look using a built-in cmdlet and a short pipeline. You can also open Event Viewer and read the same fields by hand.

### 7B — Check what each service account supports

```powershell
Get-ADUser -Filter 'ServicePrincipalName -like "*"' -Properties ServicePrincipalName, msDS-SupportedEncryptionTypes, PasswordLastSet |
  Select Name, ServicePrincipalName, 'msDS-SupportedEncryptionTypes', PasswordLastSet
```

How to read `msDS-SupportedEncryptionTypes`:

| Value | Meaning |
|---|---|
| *(blank)* or 0 | Not set, so the domain default applies, which in a lab often still allows RC4 |
| 4 | RC4 only |
| 8 | AES-128 |
| 16 | AES-256 |
| 24 | AES-128 and AES-256 |

### 7C — Move one service account to AES

Pick **`svc-web`**, the less critical one.

```powershell
Set-ADUser svc-web -KerberosEncryptionType AES128,AES256
```

Then **reset its password** so AES keys are generated (use a long random one, and note it in your report's "secrets" line, not in the repo):

```powershell
Set-ADAccountPassword svc-web -Reset -NewPassword (Read-Host -AsSecureString "New password")
```

On **WKS01**, repeat the `klist purge` and `klist get HTTP/srv01.gielinor.local`. It should now show an AES type.

> ⚠ **In real life** the password reset is the dangerous step. If `svc-web` ran a real service, that service now has a stale password and will fail to start or authenticate. You would update the service first (or at the same moment), during a window.

### 7D — Tell the domain which encryption types are allowed

Create a GPO in the **Group Policy Management** console linked to the Domain Controllers OU (use `GPO-Fortify-DC`) and set:

`Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options`

**Network security: Configure encryption types allowed for Kerberos** → tick **AES128_HMAC_SHA1** and **AES256_HMAC_SHA1** and **Future encryption types**; **leave RC4 unticked**. Do the same in `GPO-Fortify-Members` for members.

Run `gpupdate /force` on DC01, SRV01 and WKS01, reboot the members if needed, then re-test as in 7A.

> ⚠ **Pilot warning.** Applying "AES only" to the whole domain before auditing is a classic outage. Any account or device that can only do RC4 stops getting tickets. Check the 4769 events from Module 2 for **any `0x17` that isn't `svc-*` in your lab**, and treat each as a Legacy Register entry first.

### 7E — Two more checks

```powershell
# Accounts with pre-authentication turned off
Get-ADUser -Filter 'DoesNotRequirePreAuth -eq $true' | Select Name

# Computers (not DCs) trusted for unconstrained delegation
Get-ADComputer -Filter 'TrustedForDelegation -eq $true' | Select Name
```

Both should be empty (apart from the DC itself on the second). Anything else is a finding for your report.

### 7F — Read about gMSA (and use the one you built)

The Tiered Admin lab's stretch goal created **`gmsa-backup`**. If you built it, confirm it:

```powershell
Get-ADServiceAccount -Filter * | Select Name, Enabled
Get-KdsRootKey
```

A **group Managed Service Account** has a 240-character password that AD **rotates automatically** and that nobody knows. A service that can use one can't be Kerberoasted in any practical sense. If you didn't build it, read the Tiered Admin guide's Module 6 stretch and add it to your "later" list.

### ❓ Questions for Module 7

1. Why is an RC4 ticket for an account with a weak password a bigger risk than one with a long random password?
2. Why can resetting a service account's password cause an outage even though it "fixes" encryption?
3. Which of your service accounts could move to gMSA, and which couldn't? What would you do with the ones that can't?

> 📸 Snapshot as `f7-kerberos-done`.

---

# Module 8 — Stop the Quiet Walk

**Goal:** make it harder for one stolen local-admin password or one compromised machine to become a walk across the whole network, and turn on the logging that lets you *see* misuse of built-in tools.

🛡 "Living off the land" means abusing tools that are already on every Windows machine (remote admin, PowerShell, remote service control). They don't look like malware, so you control them with **policy, scoping and logging** rather than by deleting them.

This module has five small controls:

1. **Windows LAPS**: a unique, rotating local admin password per machine
2. **Deny network logon for local accounts**: a shared local admin password can't be used over the network
3. **Firewall scoping**: admin ports answer only to the admin machines
4. **PowerShell logging**: record what runs
5. **A few extra protections** (LSA protection, WDigest, attack-surface-reduction in audit mode)

⚠ **What can break**

| Control | Breaks | In the real world |
|---|---|---|
| **LAPS** | Scripts and tools that use a known shared local admin password; helpdesk runbooks | Plan how the helpdesk retrieves passwords, and who is allowed to |
| **Deny network logon for local accounts** | Vulnerability scanners using local accounts, backup agents, remote tools that sign in as `.\Administrator` | This one catches people. If you rely on local accounts remotely, use a domain service account instead |
| **Firewall scoping** | Any admin or management tool running from a machine that isn't in your list | Include your monitoring, backup and scanner IPs, or they go dark |
| **PowerShell logging** | Nothing functionally. It costs disk space and log volume | Forward the logs, or they only help after the fact |
| **LSA protection** | Unsigned or old security/authentication plug-ins, some old third-party credential providers and smart-card middleware | Audit first (see 8F) |
| **Attack-surface rules** | Management tools that use the same techniques as attackers (some deployment tools, remote-execution software) | Audit mode first, always |

> 📸 Snapshot all four as `f8-before-quietwalk`.

### 8A — Windows LAPS

**Windows LAPS** is built into current Windows and Windows Server (April 2023 updates and later). If your VMs are fully patched, you have it. Check on any member:

```powershell
Get-Command Get-LapsADPassword -ErrorAction SilentlyContinue
```

If nothing comes back, run Windows Update and retry before continuing.

**1. Extend the AD schema (once, on DC01, as a Schema/Enterprise admin):**

```powershell
Update-LapsADSchema
```

**2. Let computers write their own password.** Use the OUs from the Tiered Admin lab:

```powershell
Set-LapsADComputerSelfPermission -Identity "OU=Servers,OU=Tier1,OU=Realm,DC=gielinor,DC=local"
Set-LapsADComputerSelfPermission -Identity "OU=Workstations,OU=Tier2,OU=Realm,DC=gielinor,DC=local"
```

**3. Make a shared local admin to replace (the thing LAPS exists to fix).** On **SRV01** and **WKS01** create the same local admin with the same password, the way a lazy image would:

```powershell
$p = Read-Host -AsSecureString "Shared password"
New-LocalUser keepadmin -Password $p -PasswordNeverExpires
Add-LocalGroupMember -Group Administrators -Member keepadmin
```

**4. Create the policy.** In `GPO-Fortify-SRV01` and `GPO-Fortify-WKS`:

`Computer Configuration → Policies → Administrative Templates → System → LAPS`

- **Configure password backup directory** → *Active Directory*
- **Password Settings** → complexity: large letters + small letters + numbers + specials; length **20**; age **30** days
- **Name of administrator account to manage** → `keepadmin`
- **Post-authentication actions** → *Reset the password and log off*; grace period 8 hours

Run `gpupdate /force` on SRV01 and WKS01, then process the policy and retrieve:

```powershell
# On SRV01 or WKS01
Invoke-LapsPolicyProcessing
# On DC01
Get-LapsADPassword -Identity SRV01 -AsPlainText
Get-LapsADPassword -Identity WKS01 -AsPlainText
```

Each machine has a **different** password now, and the old shared one no longer works. ✅

> ⚠ **Real-world note.** Decide *who* may read these passwords (delegate it to a group, don't leave it to Domain Admins by default), and make sure the managed account exists on every machine. Pointing LAPS at an account that doesn't exist is a classic silent failure.

### 8B — Deny network logon for local accounts

In `GPO-Fortify-SRV01` and `GPO-Fortify-WKS`:

`Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → User Rights Assignment`

**Deny access to this computer from the network** → add the built-in group **Local account and member of Administrators group**.

`gpupdate /force`, then test from **WKS01** to **SRV01**:

```powershell
net use \\srv01.gielinor.local\C$ /user:SRV01\keepadmin
```

This should now fail ("logon failure: the user has not been granted the requested logon type"). A domain admin from your Tier 1 account still works.

> ⚠ **This one cuts both ways.** It also blocks **local-account scans** (for example, an authenticated Nessus scan using a local Administrator) and any tool that uses a local admin remotely. If you did the Vulnerability Management Challenge, this is the exact reason your scanner credentials should be a **domain service account** with the right rights.

Local console and Remote Desktop sign-ins by local admins are separate rights and are not blocked by this setting.

### 8C — Scope the admin firewall rules

The built-in rules for file sharing, remote service management and Remote Desktop default to "any address". In `GPO-Fortify-SRV01`:

`Computer Configuration → Policies → Administrative Templates → Network → Network Connections → Windows Defender Firewall → Domain Profile`

- **Windows Defender Firewall: Allow inbound file and printer sharing exception** → Enabled, allowed addresses: `10.10.10.10,10.10.10.20` (DC01 and WKS01)
- **Windows Defender Firewall: Allow inbound remote administration exception** → Enabled, same addresses
- **Windows Defender Firewall: Allow inbound Remote Desktop exceptions** → Enabled, same addresses

> The addresses come from the **Address Registry**. If you scan with VULN01 (`10.10.10.50`), add it. WATCHTOWER (`10.10.10.30`) is deliberately **not** on the list.

`gpupdate /force` on SRV01. From **WATCHTOWER**:

```bash
nc -zv 10.10.10.40 445
nc -zv 10.10.10.40 3389
```

Both should time out or be refused. From **WKS01**, `\\srv01.gielinor.local\Keep` still works. ✅

> ⚠ **Real-world note.** The usual outage is a forgotten monitoring server, backup server or jump host. Collect those IPs before you enforce, the same way you collected legacy dependencies in Module 2. If SRV01 does not work for the test, check you set the **Domain** profile (your VMs should be on it) and not only the Private or Public one.

### 8D — PowerShell logging

In `GPO-Fortify-Members`:

`Computer Configuration → Policies → Administrative Templates → Windows Components → Windows PowerShell`

- **Turn on PowerShell Script Block Logging** → Enabled
- **Turn on Module Logging** → Enabled; module names: `*`

`gpupdate /force` on a member, run something harmless (`Get-Process | Select -First 3`), then check:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational'; Id=4104} -MaxEvents 5 |
  Select TimeCreated, @{n='Script';e={$_.Message.Substring(0,[Math]::Min(120,$_.Message.Length))}}
```

You are looking at **Event 4104**, a record of what ran. Attackers who use PowerShell leave exactly this trail.

Also remove the old PowerShell v2 engine, which bypasses these logs:

```powershell
# Windows 11 client
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart
# Windows Server
Uninstall-WindowsFeature PowerShell-V2
```

(If the feature isn't present, that's good.)

> ⚠ **What it costs:** disk and log volume. In real life you would also raise the PowerShell log size and forward it. Very old scripts that require PowerShell v2 are the rare thing that breaks.

### 8E — Attack-surface-reduction (audit mode only)

Microsoft Defender's **attack surface reduction (ASR)** rules block techniques common in attacks. **Audit mode** logs what *would* have been blocked without blocking it. That is precisely the "audit first" habit of this lab.

In `GPO-Fortify-Members`:

`Computer Configuration → Policies → Administrative Templates → Windows Components → Microsoft Defender Antivirus → Microsoft Defender Exploit Guard → Attack Surface Reduction`

**Configure Attack Surface Reduction rules** → Enabled → *Show…* and add (value **2** = Audit):

| Value name | Rule | Value |
|---|---|---|
| `9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2` | Block credential stealing from the Windows local security authority subsystem | 2 |
| `d1e49aac-8f56-4280-b9ba-993a6d77406c` | Block process creations originating from PSExec and WMI commands | 2 |

> Rule IDs come from Microsoft's documentation. **Verify them against the current "Attack surface reduction rules reference" page** before relying on them. Microsoft occasionally changes details, and a wrong ID is silently ignored.

Check that Defender is running and the policy landed (on a member):

```powershell
Get-MpPreference | Select AttackSurfaceReductionRules_Ids, AttackSurfaceReductionRules_Actions
```

Events appear in `Applications and Services Logs → Microsoft → Windows → Windows Defender → Operational` as **1121** (blocked) or **1122** (audited). Run for a few days in a real environment, then decide.

> ⚠ **Known conflict:** the PsExec/WMI rule is incompatible with some management tools (ConfigMgr is the famous one), so never enforce it without auditing.

### 8F — Protect the credential store

**LSA protection** makes the LSASS process (which holds sign-in secrets) a *protected process*, so ordinary tools can't read its memory.

In `GPO-Fortify-Members` (or directly, for a quick test):

```powershell
# Check the current state
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -ErrorAction SilentlyContinue
```

To enable it, set `RunAsPPL` = `1` (DWORD) in that key via GPO preferences or:

```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -Value 1 -Type DWord
Restart-Computer
```

After the reboot, **check the System log** for events saying LSASS started as a protected process, and for any warnings about plug-ins that failed to load (Event 3065/3066 in `Microsoft-Windows-CodeIntegrity/Operational` would be those warnings; confirm the IDs in your build). A plug-in that can't load is your "legacy software" entry.

**WDigest** (an old method that cached passwords in reversible form) is off by default on modern Windows. Confirm nobody turned it back on:

```powershell
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name UseLogonCredential -ErrorAction SilentlyContinue
```

Missing or `0` is good. `1` is a finding.

**A note on Credential Guard.** Windows has a stronger feature, Credential Guard, which uses virtualization to isolate secrets. It needs **virtualization-based security**, which VirtualBox generally can't provide to its guests, so this lab doesn't cover it. On real, supported hardware it is one of the best protections available. Add it to your "next" list and look for it when you work with physical or Hyper-V machines.

### ❓ Questions for Module 8

1. Why does a shared local admin password turn one compromised machine into many?
2. What would break in your environment if you enforced "deny network logon for local accounts" tomorrow? Who uses local accounts remotely?
3. Why use audit mode for ASR rules, and how long would you run it on a real network?
4. Why does PowerShell logging matter even though it doesn't *prevent* anything?

> 📸 Snapshot as `f8-quietwalk-done`.

---

# Module 9 — The Inspection (Capstone)

**Goal:** prove what changed, finalize the Legacy Register, and write a realistic rollout plan.

🛡 In real work, the deliverable is not the settings. It is the **evidence, the exceptions and the plan** that let someone else approve and repeat them.

> 📸 Snapshot all four as `f9-before-inspection`.

### 9A — Re-run the baseline

Repeat every check from **Module 1** on DC01, SRV01 and WKS01, and fill in the "after" column of your report template. Where something *didn't* change, note why (a deliberate exception, a Legacy Register entry, or a decision to defer).

### 9B — Test that the things you need still work

Run a quick regression list. Everything below should still succeed:

- WKS01 `t2-navi` → `\\srv01.gielinor.local\Keep`
- WKS01 domain sign-in, `gpupdate /force`, no errors
- DC01 `dcdiag /q` (quiet output means healthy), and `repadmin /replsummary` if you have more than one DC
- WATCHTOWER Kerberos connection to SRV01 (6D) or your documented exception
- LDAPS query from WATCHTOWER (5C), or your documented exception

And these should now **fail** (that is the point):

- Connecting to SRV01 by IP from a Tier 2 workstation
- SMBv1 connection from WATCHTOWER
- Unsigned LDAP simple bind from WATCHTOWER
- Local `keepadmin` over the network to SRV01
- `nc -zv 10.10.10.40 445` from WATCHTOWER

### 9C — *(Optional)* Rescan with Nessus

If you built VULN01 in the Vulnerability Management Challenge, scan DC01, SRV01 and WKS01 again. Compare against your earlier scan. Findings about SMB signing, SMBv1, LLMNR/NetBIOS and weak authentication should drop. (Remember 8B: if your scan used a local account over the network, switch it to a domain service account.)

### 9D — Finalize the Legacy Register

Every dependency you found, with a row each:

| Thing | Needs | Decision (replace / reconfigure / isolate / accept) | Owner | Review by |
|---|---|---|---|---|

An "accept" with no owner and no review date is not a decision, it's a hope.

### 9E — Write the rollout plan

For **each** control you changed, write:

1. **Audit period** and what you looked for
2. **Pilot group** (the smallest, safest, most-informed ring)
3. **Success criteria** (what "no breakage" looks like)
4. **Exceptions** with an owner and an expiry
5. **Rollback** (which GPO setting or registry value reverts it, and who can do it)
6. **Communication** (who needs to be told, and when)

The report template has a table for this.

### ❓ Questions for Module 9

1. Which control had the most legacy dependencies, and why?
2. Which controls would you push first on a real network, and which last?
3. What did you accept, and what would make you revisit it?
4. What is the next thing on your "later" list?

> 📸 Final snapshot: `f9-fortified`.

---

🏁 **You finished.** You turned off a pile of risky legacy behavior *without* guessing: you measured, listed what depended on it, changed it in rings, and wrote the exceptions down.
