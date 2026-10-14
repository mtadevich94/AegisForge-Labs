# The Three Keeps — Answer Key

> Try each module first. Answers are terse on purpose. Where a result depends on your VMs (timestamps, event counts), the key says what to look for rather than the exact value.
> Domain `gielinor.local` · DC01 `10.10.10.10` · WKS01 `10.10.10.20` · SRV01 `10.10.10.40`.

---

## Module 1 — The Realm Is Flat

**1A.**
1. Domain Admins: `Administrator`, `Vaultkeeper`, `General_Graardor`, `Zelda_Warden`, `Navi`, `svc-backup` (plus any account you added in earlier labs, e.g. `student` if you made it a DA). Enterprise Admins: `Administrator`, `Vaultkeeper`. Schema Admins: `Administrator`, `Vaultkeeper`.
2. People doing everyday work: Vaultkeeper, General_Graardor, Zelda_Warden, Navi. Service account: `svc-backup`.
3. **Schema Admins** — only needed during a schema change (e.g. Exchange or LAPS schema extension). Best practice: empty, add temporarily, remove. (The built-in `Administrator` is a default member; removing it is optional hardening.)

**1B.**
4. `svc-backup` (`MSSQLSvc/srv01.gielinor.local:1433`) and `svc-web` (`HTTP/srv01.gielinor.local`). `svc-backup` is the privileged one (Domain Admin).
5. Any domain user can request a service ticket for an SPN; it's encrypted with the service account's password-derived key, so an attacker can take it offline and guess the password (**Kerberoasting**). A Domain Admin service account with a never-expiring, human-chosen password turns "any user" into "Domain Admin" if the guess succeeds.

**1C–1D.** What you should see:
- WKS01 (Tier 2): 4624 type **3** (network) from `Invoke-LazyAdminDay` for General_Graardor, Zelda_Warden, Navi, Vaultkeeper; type **10** for General_Graardor (your RDP); type **4** (batch) for **Navi** (`VillageInventoryCheck`).
- SRV01 (Tier 1): type **3** for the same accounts; type **4** (batch) for **svc-backup** (`KeepNightlyBackup`).
- 4672 (special privileges) for each of those privileged logons.

6. *Example exposure table (yours may add rows):*

   | Account | Machine (tier) | Types | Credential recoverable there? |
   |---|---|---|---|
   | General_Graardor | WKS01 (2) | 3, 10 | **Yes** for type 10 (RDP session leaves credential material in memory while the session exists / until logoff and reboot-level cleanup) |
   | Navi | WKS01 (2) | 3, **4** | **Yes** — the task's stored password lives in LSA secrets on WKS01 |
   | Zelda_Warden / Vaultkeeper | WKS01, SRV01 | 3 | Generally **no** (network logon doesn't leave a reusable password) — but 4672 shows admin power is being exercised on lower tiers |
   | svc-backup | SRV01 (1) | **4** | **Yes** — stored in LSA secrets; Domain Admin credential on a Tier 1 box |

7. **Leave reusable credentials:** interactive (2), RDP (10), unlock (7), batch (4, stored secret), service (5, stored secret), cached interactive (11). **Do not (normally):** network (3). (Caveat: network logons *with delegation enabled* can forward the credential.)
8. A stored task password means that machine holds a Domain Admin secret — **WKS01 and SRV01 are effectively Tier 0** until it's removed. Anyone who is local admin/SYSTEM on them can extract it.
9. The **Navi / `VillageInventoryCheck`** row (stored Domain Admin secret on the compromised Tier 2 machine) — or any type-10 DA session. Local admin on WKS01 → read stored secret → Domain Admin.

---

## Module 2 — Draw the Map

**2A.**

| Item | Tier | Why |
|---|---|---|
| DC01 | **0** | Holds the directory and every secret |
| SRV01 | **1** | Member server, application workload |
| WKS01 | **2** | User device |
| `Domain Admins` | **0** | Controls Tier 0 |
| Backup server holding DC backups | **0** | Restoring/reading a DC backup = owning the domain |
| Hypervisor hosting DC01 | **0** | Host admin can read/clone the DC disk |
| GPO linked to domain root | **0** | Changes every machine, including DCs |
| GPO linked to Workstations OU | **2** (managed by T2 or T1 per design) | Affects only workstations |
| `svc-backup` (as it is today) | **0** (by privilege) — which is the problem | Its *power* is Tier 0 but it runs on Tier 1 |
| CA issuing smartcard certs | **0** | Can mint credentials for anyone |
| Vaultkeeper's laptop | **0** (a PAW) if used for `t0-` | The device that holds Tier 0 sessions is Tier 0 |
| Help desk ticketing server | **1** (often) | Application; hold sensitive data but not identity control |

**2B.** Vaultkeeper → `t0-vaultkeeper` (T0). Zelda_Warden → `t1-zelda` (T1). General_Graardor → `t1-graardor` (T1, optional second server admin). Navi → `t2-navi` (T2). Princess_Irulan → **no admin account** (executive; high-value phishing target, never privileged).

**2C.** Rules table:

| Admin ↓ / Machine → | Tier 0 (DC) | Tier 1 (server) | Tier 2 (workstation) |
|---|---|---|---|
| T0 admin | **Allowed** | **Denied** | **Denied** |
| T1 admin | **Denied** | **Allowed** | **Denied** |
| T2 admin | **Denied** | **Denied** | **Allowed** |

Enforced by: User Rights Assignment "Deny …" on the target's GPO (logon), local admin membership via GPP (administration), and AD ACLs/delegation (control).

1. Defence in depth: a T2 admin on a DC is a lateral-movement and credential-exposure risk, and "cannot do much" can change when a DC misconfiguration appears.
2. A single account used at several tiers leaves its credential at the *lowest* tier it ever touched. Separate accounts mean a Tier 2 theft yields only a Tier 2 credential.
3. Domain `Administrator`: Tier 0 break-glass for DCs, kept but monitored and not used daily. Local `Administrator`: per-machine break-glass if policy locks everything out; should have a unique, rotating password (LAPS).
4. One audited choke point for Tier 0 membership (alert on changes to `T0-Admins` and `Domain Admins`), easy offboarding, and explicit deny lists that refer to the tier group.

---

## Module 3 — Build the Keeps

Expected structure (`Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Realm,$dn" | Sort DistinguishedName`):

```
Realm
├─ Staging
├─ Tier0
│  ├─ Admins        (t0-vaultkeeper)
│  └─ Groups        (T0-Admins)
├─ Tier1
│  ├─ Admins        (t1-zelda)
│  ├─ Groups        (T1-Admins)
│  ├─ Servers       (SRV01)
│  └─ Service Accounts (svc-backup, svc-web)
└─ Tier2
   ├─ Admins        (t2-navi)
   ├─ Groups        (T2-Admins)
   ├─ Workstations  (WKS01)
   └─ Users         (Bandit, Kerbe, DAME, Princess_Irulan, Navi, Zelda_Warden, General_Graardor, Vaultkeeper)
```

`Test-TieredAdminLab.ps1 -Module 3` should print all PASS.

1. If you remove the old privileges first you may lock out the people who must keep the realm running, and you have nothing to switch to. Build → verify → cut over.
2. Changes to *who has Tier 0* are changes to one group's membership (`T0-Admins`), so a single event ID (4728/4732 on that group) tells you.
3. The everyday account is the one that browses the web and reads email; if it is Domain Admin, every phishing click is a Domain Admin phishing click. The `t0-` account is pointless if the everyday one is still privileged.
4. DCs are Tier 0 compute; the Domain Controllers OU and its default GPO already serve as the container. Add a `Tier0\Servers` OU later for PKI/Entra Connect/etc.

---

## Module 4 — Delegation, Not Membership

4A. `dsacls $ou | Select-String 'T2-Admins'` shows three ACEs for T2-Admins: *Reset Password* on user objects, *Read/Write pwdLastSet*, *Read/Write lockoutTime* (all "Descendant User objects").

4C. The first command succeeds. The second returns **Insufficient access rights** (access denied):
1. `t0-vaultkeeper` is in `Tier0\Admins`, outside the OU where `T2-Admins` has rights; delegation is inherited only down the tree it was applied to.
2. A delegation's scope **is** the security boundary: a help desk with Reset Password on the whole domain can reset a Domain Admin's password and then log on as them.
3. They could add themselves to `T1-Admins` and gain Tier 1. Group membership of tier groups must be controlled only by the tier above (T0).
4. Reset password → log on as that admin → Tier 0. Password reset is a path to privilege.

---

## Module 5 — Lock the Doors

**5B.** GPO contents (User Rights Assignment, all five "Deny" rights):

| GPO | Groups on deny lists |
|---|---|
| Tier2-Workstation-Restrictions | `GIELINOR\T0-Admins`, `GIELINOR\T1-Admins`, `GIELINOR\Domain Admins`, `GIELINOR\Enterprise Admins`, `GIELINOR\Schema Admins` |
| Tier1-Server-Restrictions | `GIELINOR\T0-Admins`, `GIELINOR\T2-Admins`, `GIELINOR\Domain Admins`, `GIELINOR\Enterprise Admins`, `GIELINOR\Schema Admins` |
| Tier0-DC-Logon-Restrictions | `GIELINOR\T1-Admins`, `GIELINOR\T2-Admins` |

The five rights: *Deny access to this computer from the network* (`SeDenyNetworkLogonRight`), *Deny log on as a batch job* (`SeDenyBatchLogonRight`), *Deny log on as a service* (`SeDenyServiceLogonRight`), *Deny log on locally* (`SeDenyInteractiveLogonRight`), *Deny log on through Remote Desktop Services* (`SeDenyRemoteInteractiveLogonRight`).

**5C.** GPP *Local Group* in the Tier2 GPO: Action **Update**, `Administrators (built-in)`: **Add** `GIELINOR\T2-Admins`, **Remove** `GIELINOR\Domain Admins`. Tier1 GPO the same with `T1-Admins`.

**5D.** `secedit` shows `SeDenyNetworkLogonRight = *S-1-5-21-…-<RID>` entries; each SID maps to a group (`(Get-ADGroup T0-Admins).SID.Value`).

**5E.** Expected matrix:

| Account | DC01 (T0) | SRV01 (T1) | WKS01 (T2) |
|---|---|---|---|
| `t0-vaultkeeper` | **OK** | Denied | Denied |
| `t1-zelda` | Denied | **OK** | Denied |
| `t2-navi` | Denied | Denied | **OK** |
| `Administrator` (domain, DA) | **OK** | Denied | Denied |
| `General_Graardor` (still DA) | OK (still DA) | Denied | Denied |

Messages: RDP → *"The sign-in method you're trying to use isn't allowed."* Remoting (`Invoke-Command`/`Enter-PSSession`) → *"Access is denied"*, or a WinRM authentication/connection failure. For a DC target the deny comes from the Tier 0 GPO (`T1-Admins`, `T2-Admins`).

> Remember to run `gpupdate /force` on the DC and members; a stale policy is the usual reason a cell is wrong.

**5F.** Both tasks fail: `Last Result` is non-zero (batch logon denied), and Event 4625 shows **Status `0xC000006D`, SubStatus `0xC000015B`** ("user not granted the requested logon type").
1. Common surprises: the built-in domain `Administrator` and the old Domain Admins are **denied** on SRV01/WKS01 even though they are "all-powerful"; `t2-navi` can't get onto SRV01 or DC01; `t1-zelda` can't get onto WKS01.
2. The failure is the model working. The bigger design problem: **`KeepNightlyBackup`** — a Tier 0 *privilege* (Domain Admin) running as a *Tier 1 service*; the nightly job needs to be redesigned, not exempted.
3. They can still change GPOs, reset passwords, add themselves to any group, and log on to DCs from DC01. The deny rights protect where the credential *travels*, not what the credential can *do*. That's why the privileges are removed in Module 6.
4. The domain `Administrator` is also a Domain Admin and is denied on Tier 1/2. Each machine's **local** `Administrator` is the way back in. Compensating controls: Windows LAPS (unique rotating password), logging/alerting on any use, disabled where unneeded, kept in a sealed procedure.

---

## Module 6 — Clear the Throne Room

6A. After removal: `Get-ADGroupMember 'Domain Admins'` shows **`Administrator`** and **`T0-Admins`** (which contains `t0-vaultkeeper`). `Enterprise Admins`: `Administrator`. `Schema Admins`: `Administrator`.

6B. Before cleanup `Get-ADUser -Filter 'adminCount -eq 1'` lists the former admins (and the real admins). After cleanup only genuine admins remain (`Administrator`, `krbtgt`, `t0-vaultkeeper` indirectly through DA nesting once SDProp runs). Navi's everyday account regains inherited permissions, so `t2-navi`'s password-reset delegation works on it again.

6C. `KeepNightlyBackup` runs with `Last Result 0x0` after `svc-backup` is in local `Backup Operators` on SRV01. `VillageInventoryCheck` is deleted — it never needed a Domain Admin identity.

6D. By FQDN: works (Kerberos). By IP: **fails** — Protected Users cannot use NTLM, and an IP address forces NTLM (Kerberos needs a service principal name). Typical error: authentication/"logon failure"; for PowerShell remoting by IP also WinRM TrustedHosts refusal.

6E. `Get-ADUserResultantPasswordPolicy -Identity t0-vaultkeeper` returns `PSO-Tier-Admins` (min length 16, 60-day max age, 24 history, lockout 5/30 min).

6F. (gMSA) `Test-ADServiceAccount gmsa-backup` on SRV01 returns `True` after `Install-ADServiceAccount`.

**Questions.**
1. 6A removes what a stolen credential could *do*; Module 5 limited where credentials *go*. Removing privilege alone leaves them exposed on lower tiers; denying alone leaves a god-account that's still useful from DC01.
2. Separate accounts only help if they never cross; the deny rights *enforce* it, even for mistakes and scripts.
3. `adminCount=1` marks an object as protected by AdminSDHolder: its ACL is replaced and inheritance is disabled hourly. After leaving a protected group the flag stays, so delegated permissions (Reset Password) don't apply to it.
4. No NTLM (IP-based access, many legacy apps fail), no cached credentials (can't sign in off-network), no delegation (some multi-hop scenarios fail), Kerberos tickets expire after 4 hours. OK for people who sign in to DCs; not for service accounts, which need long-lived logons and often NTLM/delegation.
5. A human can't leak or reuse a password they never see; AD rotates it, so a stolen copy stops working and offline cracking is infeasible (the managed password is a 240-byte random value).

---

## Module 7 — Watch the Gates

7A. Expect 4625 rows: `LogonType` 3/4/10, `Status 0xC000006D`, `SubStatus 0xC000015B`, account = the tier-crossing account, `SourceIP` = DC01 for remoting/RDP tests.

7B. Nothing for `t0-*` since the controls went in. A `t0-` **4624** on a lower tier would mean either the deny right is missing/stale or the account used a path the deny rights don't cover — treat as a high-priority incident; the credential is exposed on that machine.

7C. `t0-vaultkeeper`'s TGT requests (4768) should come from DC01/Tier 0 hosts. If you tested from a different machine, you'll see that IP — note it honestly in your report.

7D. 4728 shows `Group = Domain Admins`, `Member = CN=Bandit,…`, `ChangedBy = <who made the change>`.
1. Tier 0 groups: 4728 (global), 4732 (local), 4756 (universal), plus 4729/4733/4757 for removals; also 5136 for directory object changes if DS Access auditing is on.
2. 4624 where `TargetUserName` starts `t0-` and `Computer` is not in the Tier 0 list.
3. 4625 with `SubStatus = 0xC000015B` for `t0-*`/`t1-*`.

**Questions.**
1. The 4728 on Domain Admins (attempted privilege escalation, no credential reuse needed). The 0xC000015B is a *prevented* event — worth a daily review; page only when it is repeated or from an unexpected source.
2. A success tells you only what you already allowed. A failure is a signal that something tried to cross a boundary — misconfiguration, a script, or an attacker.
3. Anything an attacker with local admin can clear (the Security log), logs that never left the host, and activity before auditing was enabled. Forward to a collector / SIEM.

---

## Module 8 — The Warlord's Path

**8A expected observations**
1. WKS01 local Administrators: local `Administrator`, `GIELINOR\T2-Admins`. SRV01 refuses `t2-navi` (Tier 2 → Tier 1), which is correct; with `t1-zelda`: local `Administrator`, `GIELINOR\T1-Admins`. `Domain Admins` is **not** present on either.
2. Kerberoastable: `svc-backup` and `svc-web`. `svc-backup` is no longer privileged, but still has an SPN and a never-expiring password → move to gMSA (6F).
3. `adminCount = 1`: only genuine Tier 0 identities (`Administrator`, `krbtgt`, the T0 members once SDProp runs).
4. Tasks: `KeepNightlyBackup` as `svc-backup` (now least-privilege); no Domain Admin identity stored on either machine.
5. Scorecard: all PASS (a few SKIPs are fine if you skipped stretch items).

**8B. After-table (example)**

| Account | Machine | Result now |
|---|---|---|
| General_Graardor / Navi / Zelda_Warden / Vaultkeeper (everyday) | WKS01, SRV01 | Standard users; no admin; remote logon rejected or unprivileged |
| `t0-vaultkeeper` | WKS01, SRV01 | Denied at logon (4625/0xC000015B) |
| `t1-zelda` | WKS01 | Denied; SRV01 allowed |
| `t2-navi` | SRV01 | Denied; WKS01 allowed |
| `svc-backup` | SRV01 | Batch logon only; local Backup Operators; not privileged in AD |

**Shortest attack path, before:** Bandit/WKS01 foothold → local admin → read stored Domain Admin secret for Navi's task or capture a General_Graardor RDP session → Domain Admin → DC01.
**After:** foothold → local admin on WKS01 yields only Tier 2 credentials (`t2-navi`, standard users). No path to Tier 1/0 without a *new* vulnerability (misconfiguration, unpatched flaw, a human doing something forbidden).

**8C. Residual risk (any four):** local `Administrator` password reuse across machines (LAPS); backups and hypervisor are Tier 0 and not covered here; no PAWs for the `t0-` account; Domain Admins can still change GPOs/links and un-nest groups; no Credential Guard; no monitoring beyond Security-log queries; `svc-backup` still Kerberoastable until it's a gMSA; user-level phishing is untouched; lab password is shared and published.

**Recommended order:** (1) forward Security logs off-host and alert on Tier 0 group changes; (2) PAW for Tier 0 admins; (3) Windows LAPS; (4) gMSAs / managed identities for all service accounts; (5) Credential Guard + authentication policy silos; (6) Entra ID privileged access (PIM, break-glass) for cloud.

---

## Scorecard reference

`Test-TieredAdminLab.ps1` (no parameters) — all of these should be **PASS** when you finish: tier sub-OUs, asset OUs, tier groups, three admin accounts + membership, `T0-Admins` nested in `Domain Admins`, computers in correct OUs, `T2-Admins` delegation, three GPOs linked, deny rights on all three, `Domain Admins` denied on T1/T2, local-admin GPP present, `t0-vaultkeeper` in Protected Users and marked non-delegable, `PSO-Tier-Admins` (≥16) applied to all three groups, daily accounts removed from Domain Admins, Schema Admins cleaned, no orphaned `adminCount`, `svc-backup` not privileged, logon/group-change auditing enabled.

*Lab version 1.0.0.*
