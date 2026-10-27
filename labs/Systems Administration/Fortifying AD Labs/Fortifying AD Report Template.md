# Fortifying AD: Report Template

Copy this file, rename it, and fill it in. Keep secrets (passwords, keys) out of it.

**Name / date:**
**Environment:** (VMs, versions, snapshot names)

## 1. Summary
Three or four sentences: what was exposed, what you changed, what you deliberately left, and the biggest risk that remains.

## 2. Baseline and result

| Area | Check | Before | After | Notes |
|---|---|---|---|---|
| SMB | SMBv1 present | | | |
| SMB | Signing required (server/client) | | | |
| Name resolution | LLMNR / NetBIOS / mDNS | | | |
| LDAP | Signing / channel binding | | | |
| NTLM | LmCompatibilityLevel | | | |
| NTLM | Restrictions applied | | | |
| Kerberos | RC4 tickets in 4769 | | | |
| Kerberos | No-pre-auth / unconstrained delegation | | | |
| Local admin | LAPS in place | | | |
| Local admin | Network logon denied for local accounts | | | |
| Firewall | Admin ports scoped | | | |
| Logging | PowerShell 4104 present | | | |
| Protection | LSA protection / WDigest | | | |
| Scanner (optional) | Nessus findings count | | | |

## 3. Legacy Register

| Thing | Needs | Decision (replace / reconfigure / isolate / accept) | Owner | Review by |
|---|---|---|---|---|
| | | | | |

## 4. Rollout plan (one row per control)

| Control | Audit period / what to look for | Pilot group | Success criteria | Exceptions (owner, expiry) | Rollback | Who to tell |
|---|---|---|---|---|---|---|
| | | | | | | |

## 5. What broke during the lab
What failed, how you found it, and how you recovered.

## 6. Risk I accepted and what I would do next
Include Credential Guard and anything else you couldn't do in this lab.
