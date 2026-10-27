# Legacy Field Guide: What Breaks When You Harden Windows Authentication

Read this **before Module 2** and keep it open. It explains what real networks are full of, why hardening breaks it, and what to do instead of simply "turning it off".

> **The one-sentence version:** weak protocols survive because *something* still needs them. Your job is to find that something, then decide to **replace it, reconfigure it, isolate it, or consciously accept the risk**. In that order of preference.

---

## 1. The big picture: why these protocols are still alive

| Protocol / setting | What it's for | Why it's weak | Why it won't die |
|---|---|---|---|
| **NTLM** (NTLMv1 / NTLMv2) | Authentication when Kerberos isn't possible | Can be relayed, captured and cracked offline; doesn't verify the *server* | Kerberos needs a hostname, a working DNS entry, a registered SPN and reachability to a domain controller. Take any of those away, and Windows quietly falls back to NTLM |
| **SMBv1** | Old file sharing | No modern protections; the protocol behind several major worm outbreaks | Old devices (printers, scanners, NAS, XP/2003-era systems, industrial gear) never got SMB2 |
| **SMB without signing** | File sharing without verifying packets | Allows relay and tampering | Signing costs some CPU; legacy clients may not support it |
| **LLMNR / NetBIOS name service / mDNS** | Finding hosts when DNS fails | Anyone on the network can answer, and the client will happily send credentials to them | Old apps and workgroup-era habits depend on single-label names |
| **LDAP without signing / simple bind in cleartext** | Applications querying the directory | Sniffable, relayable | Appliances and old apps were built to bind this way |
| **Kerberos RC4** | Older Kerberos encryption | Easy to crack offline (Kerberoasting) | Old service accounts, old keytabs, old third-party clients |
| **Shared local admin password** | Convenience | Steal it once, own every machine | Imaging and "we've always done it" |

**The pattern:** each weak setting is on by default or by habit, each has a safe replacement, and each has a few dependents that will break.

## 2. Who actually depends on these? (the usual suspects)

These are the things that show up in real audit logs. Not all exist in your lab, but all exist in the world.

### Devices and appliances

| Thing | Typical dependency | Symptom when you harden | Better answer |
|---|---|---|---|
| **Multifunction printers / scan-to-folder** | SMBv1 or NTLMv1, sometimes no signing, often a service account with an old password | "Scan to folder" silently stops working | Update firmware (many support SMBv2/3 now), or use scan-to-email/SFTP, or scan to a dedicated, isolated "landing" server |
| **NAS / storage appliances** | Old Samba, NTLM only, no Kerberos | Shares can't be reached; domain join breaks | Firmware upgrade; join the domain properly; replace |
| **Industrial / OT / manufacturing systems** | Windows XP/7/2008-era hosts, SMBv1, NTLMv1; can't be patched without vendor support | Production-line software stops talking to its file server | **Isolate on its own network segment** with a firewall allow-list; never expose to the user network; plan replacement |
| **Medical and lab equipment** | Vendor-locked old Windows | Same as above | Same: isolate, document, plan replacement |
| **Point-of-sale and kiosk systems** | Old Windows, local accounts, NTLM | Failures after policy | Isolate; modernize |
| **VPN, firewall and wireless appliances** | LDAP simple bind for user lookup; MS-CHAPv2 (which depends on the NT hash) for authentication | Logins fail after LDAP signing or NTLM changes | Switch to LDAPS/StartTLS, use certificate-based auth (EAP-TLS), upgrade |
| **Network monitoring / backup / vulnerability scanners** | Local admin accounts over SMB, NTLM | Scans and backups fail after "deny network logon for local accounts" | Use a dedicated domain service account with narrow rights |

### Software and scripts

| Thing | Typical dependency | Symptom | Better answer |
|---|---|---|---|
| **Linux/Unix hosts using Samba or `smbclient`** | NTLM; no Kerberos configured | Access denied after restricting NTLM | Configure Kerberos (`krb5`), or isolate and document |
| **Java / PHP / Python apps doing LDAP lookups** | LDAP simple bind on port 389 | "Strong authentication required" after LDAP signing | Move to LDAPS (636) or StartTLS; update the app's config |
| **Apps with hard-coded IP addresses** | Connecting to `\\10.x.x.x\share` | **Kerberos can't be used with an IP address**, so NTLM is used. Restricting NTLM breaks it | Re-point to the server's DNS name; fix the app |
| **File shares behind DNS aliases (CNAMEs)** | The alias has no matching SPN, so Kerberos fails and NTLM is used | Shares "work" until NTLM is restricted | Register the SPN for the alias, or use DFS Namespaces |
| **IIS / SQL apps on non-standard accounts** | Missing or duplicate SPNs push clients to NTLM | Intermittent auth failures after restricting NTLM | Fix the SPN (`setspn`), use the right service account |
| **Systems Center / endpoint tools** | Rely on WMI/PsExec-style remote execution | Break when you block those behaviors (for example, with an Attack Surface Reduction rule) | Test in audit mode first; use the vendor's documented exclusions |
| **Old scripts and scheduled tasks** | Local admin passwords, NTLM, cleartext LDAP | Break silently overnight | Find them in the audit; rewrite with service accounts |

### Trusts and domain-level things

| Thing | Dependency | Note |
|---|---|---|
| **External or older trusts** | Often use NTLM | Restricting NTLM domain-wide can break cross-domain access |
| **Mixed domain/forest functional levels** | Older levels may not give accounts AES Kerberos keys | Accounts whose passwords pre-date AES support may only have RC4 keys until the password is reset |
| **Workgroup or non-domain machines** | Local accounts; NTLM is the only option | They can't use Kerberos. Plan for them explicitly |
| **Mergers and acquisitions** | Someone else's legacy | Treat the acquired network as untrusted until audited |

## 3. The safe-change method (use it for everything)

```
   1. AUDIT        Turn on logging. Change nothing else.
   2. WAIT         Cover a full business cycle (including month-end and quarter-end jobs).
   3. INVENTORY    List everything that showed up. Write each down with an owner.
   4. DECIDE       For each: replace, reconfigure, isolate, or accept (with an expiry date).
   5. PILOT        Enforce on a test group (one OU, a few machines).
   6. EXCEPT       Create documented exceptions where needed. Each has an owner and an end date.
   7. ENFORCE      Roll out in waves, with a rollback plan ready.
   8. MONITOR      Keep the auditing on. New dependents appear all the time.
```

**Time matters.** A scan-to-folder job that runs once a month won't show up in a one-week audit. Real programs audit for weeks.

## 4. Your options for each dependency

In order of preference:

1. **Replace or upgrade it.** The best answer, and often the slowest.
2. **Reconfigure it.** Point the app at a DNS name instead of an IP, switch to LDAPS, turn on its Kerberos support.
3. **Isolate it.** Put it on its own network segment behind a firewall that allows *only* the specific servers it needs. (This is exactly what you built in the **Gatehouse** lab.) The weak protocol is still there, but it can no longer reach everything.
4. **Make a documented exception.** A narrow, owned, time-limited exception. Many NTLM and LDAP settings have exception lists.
5. **Accept the risk, in writing.** Name the owner, the reason and a review date. "We know and accept it" is defensible. "We never found out" is not.

## 5. What NOT to do

- **Don't set "Deny all NTLM" on the whole domain** as your first move. Start with auditing, then restrict at the server level.
- **Don't harden domain controllers first.** Everything depends on them. Pilot on a member server.
- **Don't skip auditing** because "we have no old stuff". You will be surprised.
- **Don't audit for a day and call it done.**
- **Don't apply every setting to everything at once.** If something breaks, you won't know which change did it.
- **Don't forget DNS.** Many of these changes assume DNS is clean (every host has an A record, names resolve consistently). Fix DNS first, or Windows falls back to NTLM and name-resolution tricks.
- **Don't treat an exception as permanent.** Put an end date on it.

## 6. Mixed environments: a quick mental model

When the network has old and new, think in **rings**:

```
 Ring 1: Domain controllers, admin workstations        → strictest settings
 Ring 2: Servers and managed workstations              → strict, with audited exceptions
 Ring 3: Legacy-dependent systems (isolated segment)   → weak protocols allowed,
                                                         but fenced off from Ring 1 and 2
```

You harden from the inside out, and you wall off whatever can't be hardened.

## 7. Questions to ask about any legacy system

- What does it *really* need? (Authentication, name lookup, file transfer?)
- Who owns it, and who can approve a change?
- Is there a vendor update? Is the vendor still alive?
- Can it be moved to a segment where it can only reach what it must?
- What happens to the business if it stops working for an hour? For a day?
- What's the exit plan?

## 8. Microsoft is moving too

Microsoft has publicly signaled that **NTLM is on its way out**, and recent Windows releases are tightening defaults (for example around SMB signing). That means some of what this lab asks you to do manually is increasingly becoming the default. It also means the legacy systems that can't keep up are becoming a **bigger risk**, not a smaller one. Check Microsoft's current guidance for your Windows versions before you plan a rollout.

---

*Use the Legacy Register in the **Report Template** to track every dependency you find.*
