# Fortifying AD Labs — *The Wrkstation Chronicles: The Iron Gates*

Part 2 of the Tiered Admin lab. In **The Three Keeps** you separated *who* can log on *where*. Here you harden *how* they authenticate and *what the machines say to each other*.

Attackers inside a Windows network rarely need exotic malware. They use what Windows already ships: old authentication protocols (**NTLM**), file-sharing that doesn't check who it's talking to (**SMB without signing**), name lookups that answer anyone who shouts (**LLMNR, NetBIOS**), directory queries nobody verifies (**LDAP without signing**), and tickets that are easy to crack (**RC4 Kerberos, weak service-account passwords**). Nine guided modules close those doors, one at a time, **without breaking the keep**.

> **This lab is about restraint as much as hardening.** Every one of these settings can break something in a real company: a printer that scans to a folder, a backup agent, an old NAS, a line-of-business app that connects by IP address. You will learn to **audit first, find what depends on the weak setting, decide what to do about it, and only then enforce.** Turning things off blindly is how outages happen.

Part of **Project AegisForge** → **Systems Administrator path** → *Phase 1* → **Fortifying AD** (a follow-on to the Tiered Admin lab).

---

> **Requires:** [DC01](../../Lab%20Foundations/VM%20Cards/DC01.md), [SRV01](../../Lab%20Foundations/VM%20Cards/SRV01.md) and [WKS01](../../Lab%20Foundations/VM%20Cards/WKS01.md), domain-joined, with the **[Tiered Admin lab](../Tiered%20Admin%20Labs/README.md)** completed (at least through Module 6, snapshot `m6-hardened` or later). Plus [WATCHTOWER](../../Lab%20Foundations/VM%20Cards/WATCHTOWER.md), which plays the **"legacy device"** in this lab. Setup: [Lab Foundations](../../Lab%20Foundations/README.md).
> **Leaves behind:** a fortified `gielinor.local` domain, a set of documented exceptions (the **Legacy Register**), and a before/after report. Take `fortify-start` before Module 1.
> **Reset:** restore DC01, SRV01, WKS01 and WATCHTOWER to `fortify-start`.
> **Skipped Tiered Admin?** You can still run this on a plain domain. Wherever the guide names a tier account (`t1-zelda`, `t2-navi`), use any ordinary domain user and your own admin account.

## What you'll learn

1. **Read the room:** measure how exposed the domain is *before* changing anything
2. **Turn on the lanterns:** use auditing to find out who and what still depends on weak protocols
3. **Silence the whispers:** turn off LLMNR, NetBIOS and mDNS name-poisoning surfaces
4. **Lock the SMB gates:** remove SMBv1, require signing, and decide when encryption is worth it
5. **Fix LDAP:** require LDAP signing and channel binding, and watch a legacy client break
6. **The NTLM reckoning:** NTLMv2-only, then restrict incoming NTLM, and learn why you can't simply "turn NTLM off"
7. **Harden Kerberos:** move off RC4, protect service accounts, and see what Kerberoasting actually needs
8. **Stop easy lateral movement:** unique local admin passwords (LAPS), network-logon limits, host-firewall scoping, PowerShell logging, and Attack Surface Reduction in audit mode
9. **Capstone:** re-measure, compare, write the Legacy Register, and plan a real-world rollout

## How it's built

- **Guided, with minimal scripting.** Most changes are Group Policy settings you click through, so you learn where each one lives. Checks are short, read-only PowerShell one-liners you can read in a glance.
- **A "legacy device"** (WATCHTOWER, a Linux machine) plays the old scanner, NAS and Unix app that real networks are full of. Some modules deliberately break it so you feel the cost of a change before you meet it at work.
- **A Legacy Field Guide** explains *what breaks in the real world* and what to do about it. Read it before Module 2, and keep it open.
- **Snapshots between modules** so a lockout costs you minutes, not hours.

## Files

| File | What it is |
|---|---|
| **Fortifying AD Lab Environment Setup.md** | Small setup: snapshots, a test share, WATCHTOWER packages, GPO scaffolding |
| **Fortifying AD Legacy Field Guide.md** | Real-world compatibility: what depends on NTLM, SMB1, unsigned LDAP, RC4, and how to handle each |
| **Fortifying AD Lab Guide.md** | The nine modules |
| **Fortifying AD Lab Answer Key.md** | Expected results and a GPO settings cheat sheet |
| **Fortifying AD Lab Troubleshooting.md** | Recovering from a lockout, and common problems |
| **Fortifying AD Report Template.md** | Before/after report and the Legacy Register |

## Time and resources

About **8–10 hours**. Budget about 10 GB of RAM for DC01 (2 GB), SRV01 (2 GB), WKS01 (4 GB) and WATCHTOWER (2 GB), plus your host.

## Honest limits

- **Written from Microsoft's documentation, not yet run end to end.** Group Policy wording and menu locations shift between Windows builds. Where this guide's wording doesn't match your screen, search the policy name in the GPO editor and trust what you see.
- **Your lab is cleaner than real life.** Your VMs are all modern, so many hardening steps will break *nothing*. That's the trap. The Legacy Field Guide covers what would break elsewhere.
- **Defensive only.** This lab doesn't attack anything. You prove each fix with logs, built-in checks and (optionally) your Nessus scanner.
- **Credential Guard** is a strong protection against credential theft, but it needs virtualization-based security that VirtualBox guests generally can't provide, so it's a mention here, not an exercise.

*An isolated-lab warning:* some steps deliberately re-create insecure legacy settings (such as SMBv1) so you can watch them fail safely. Never do these on a real network.
