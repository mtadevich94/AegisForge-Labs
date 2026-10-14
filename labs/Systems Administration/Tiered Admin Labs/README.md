# Tiered Admin Labs — *The Wrkstation Chronicles: The Three Keeps*

Split an Active Directory domain into **Tier 0 / Tier 1 / Tier 2**, lock down where privileged credentials can be used, remove the privilege sprawl, and prove it works. Eight story-driven modules, built on the same `gielinor.local` domain as the Windows Garrison and Packet Watch labs.

Part of **Project AegisForge** → **Sysadmin path** → security hardening for people who already run Windows.

> **Requires:** [DC01](../../Lab%20Foundations/VM%20Cards/DC01.md) and [WKS01](../../Lab%20Foundations/VM%20Cards/WKS01.md) in their **domain-joined** state (`domain-joined-clean`); [SRV01](../../Lab%20Foundations/VM%20Cards/SRV01.md) (built in this lab); the shared `GielinorNAT` network ([setup](../../Lab%20Foundations/VirtualBox%20and%20GielinorNAT.md)).
> **Leaves behind:** a tiered `gielinor.local` domain (OUs, tier groups, admin accounts, logon-restriction GPOs). Take `tiered-start` before Module 1 so you can redo the lab.
> **Reset:** restore DC01, WKS01 and SRV01 to `tiered-start`.
> **Don't have the domain yet?** See [Lab Foundations](../../Lab%20Foundations/README.md) and the Windows Labs.

## What you'll learn

1. Assess a "flat" domain: who is a Domain Admin, where do they log on, what credentials are left behind
2. Design a tier model on paper before touching AD
3. Build the OU / group / dedicated-admin-account structure
4. Delegate narrowly (help desk resets passwords in one OU — nothing more)
5. Enforce logon restrictions with GPO user-rights assignments and per-tier local administrators
6. Remove legacy privilege (Domain Admin sprawl, AdminSDHolder residue, over-privileged service accounts) and protect Tier 0 identities (Protected Users, non-delegable accounts, fine-grained password policy)
7. Verify the model and detect violations from Windows Security events
8. **Capstone:** a before/after assessment report with residual-risk analysis

## You'll need

- The Windows lab environment from the **Windows Labs** (DC01 + WKS01 on `GielinorNAT`, domain `gielinor.local`)
- One additional VM: **SRV01** (Windows Server 2022 evaluation)
- About 8 GB of RAM for the three VMs, and 6–8 hours

Basic Windows administration and Active Directory experience is assumed. New to AD? Finish the Windows Garrison lab first.

## Files

| File | What it is |
|---|---|
| **Tiered Admin Lab Environment Setup.md** | Build SRV01, run the setup scripts, verify (start here) |
| **Tiered Admin Lab Guide.md** | The lab — eight modules |
| **Tiered Admin Lab Answer Key.md** | Check your work *after* you've tried |
| `Setup-TieredAdminLab-DC01.ps1` | DC01: builds the deliberately flat, insecure starting realm (supports `-Reset`) |
| `Setup-TieredAdminLab-Member.ps1` | SRV01 / WKS01: static IP, RDP + WinRM + remote event logs, auditing, legacy scheduled tasks |
| `Invoke-LazyAdminDay.ps1` | Generates the Module 1 evidence (privileged accounts logging on everywhere) |
| `Get-TierLogons.ps1` | Turns raw logon events into readable tables |
| `Test-TieredAdminLab.ps1` | Read-only scorecard — tells you which controls are in place |
| `SHA256SUMS` | Checksums so you can verify the scripts weren't altered |

## Safety — please read

- **Isolated lab VMs only.** The baseline is intentionally insecure (Domain-Admin service account, everyday accounts as Domain Admins, one shared published lab password). Never run these scripts in a real domain or on a network you don't own.
- **Read every script before running it as Administrator.** They're short and commented.
- `Test-TieredAdminLab.ps1` and `Get-TierLogons.ps1` only *read*. The setup scripts make changes; `Setup-TieredAdminLab-DC01.ps1 -Reset` removes the lab's tier objects.
- **Snapshot before Module 5.** Logon-restriction policies can lock you out of a VM if you mistype a group; the guide tells you how to recover.
- Verify downloads: `Get-FileHash <file>` (Windows) and compare with `SHA256SUMS`.
- This is a *defensive* lab: the capstone has you read your own domain the way an attacker would, not attack it.

## Time & cost

Free: VirtualBox, Windows Server and Windows 11 evaluation ISOs (180- and 90-day).

## Versioning

Current: **v1.0.0**. Scripts, guide and answer key move together.

## Feedback

Found a rough edge or a better way to explain a step? Open an issue on the repo.
