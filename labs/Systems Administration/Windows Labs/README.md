# Windows Labs — *The Wrkstation Chronicles: Windows Garrison*

Learn to find things, fix things and read the evidence on a Windows machine, using both the old Command Prompt and PowerShell. You'll build the shared `gielinor.local` domain first, then work through twelve story-driven modules on a domain-joined Windows 11 workstation.

Part of **Project AegisForge** → **Student path** → *Phase 1*.

> **Requires:** [DC01](../../Lab%20Foundations/VM%20Cards/DC01.md) (Windows Server 2022) and [WKS01](../../Lab%20Foundations/VM%20Cards/WKS01.md) (Windows 11 Enterprise) in their **domain-joined** state (`domain-joined-clean`), on the shared `GielinorNAT` network ([setup](../../Lab%20Foundations/VirtualBox%20and%20GielinorNAT.md)). The two build guides below create both.
> **Leaves behind:** the `gielinor.local` domain, plus on WKS01 the lab's local characters, puzzle files under `C:\GielinorArchive`, a shared folder and process-creation auditing. Take `windows-start` after the setup script finishes.
> **Reset:** restore WKS01 to `windows-start` to redo any module. The lab only changes WKS01, so DC01 and the domain stay as they are.
> **Don't have the VMs yet?** Follow the Files list below in order, or see [Lab Foundations](../../Lab%20Foundations/README.md).

## What you'll learn

1. Navigate and search with CMD's `dir` switches and PowerShell's `Get-ChildItem`
2. Create, copy, move and delete files and folders from both shells
3. Dig deeper with PowerShell discovery and filtering
4. Fix an ownership or permissions lockout with `takeown` and `icacls`
5. Find and read **Alternate Data Streams**, where Windows can hide data inside a file
6. Discover processes and filter them
7. Map a process back to the service or scheduled task behind it
8. Manage local users, groups and shares
9. Enumerate network connections and routes
10. Build and remove scheduled tasks
11. Pull a targeted audit trail out of the Security event log
12. **Capstone:** write the same small piece of logic in both PowerShell and batch

## You'll need

- VirtualBox, with about 150 GB of free disk and 16 GB of RAM to run both VMs comfortably (8 GB works if you run one at a time)
- Free Windows evaluation ISOs (Windows Server 2022 and Windows 11 Enterprise); the build guide shows where to get them
- No prior Windows administration experience is assumed

## Files

Work through these in this order.

| File | What it is |
|---|---|
| **Windows ISO Setup.md** | Download the ISOs and install the blank DC01 and WKS01 VMs (start here) |
| **Windows Domain Setup Guide.md** | Promote DC01 to a domain controller and join WKS01 to `gielinor.local` |
| `Windows Lab Setup Script.ps1` | Run once as `.\labadmin` on WKS01. It builds the lab world. **Read it before you run it.** |
| **Windows Administration Lab Guide.md** | The lab itself: twelve modules |
| **CMD vs PowerShell Cheat Sheet.md** | Every CMD command in the lab next to its PowerShell equivalent. Keep it open. |
| **Windows Administration Lab Answer Key.md** | Check your work *after* you've tried |

## Safety — please read

- **Isolated lab VMs only.** The setup script creates local accounts with the published lab password (`ChangeMe123!`), shares a folder and turns on extra auditing. Never run it on a machine you care about or on a real domain.
- **Read the script before you run it as Administrator.** It is plain text and commented.
- Keep the VMs on the `GielinorNAT` NAT Network. Never bridge them to your real network.
- The alternate data streams the lab plants are inert text, not real malware.
- Everything here is for learning on systems you own.

## Time & cost

Free: VirtualBox and the Windows Server and Windows 11 evaluation ISOs (180- and 90-day).

## Next

- **[Wireshark Labs](../Wireshark%20Labs/README.md)** — reuse WKS01 to read network traffic.
- **[Tiered Admin Labs](../Tiered%20Admin%20Labs/README.md)** — split the domain you just built into Tier 0, 1 and 2.
- **[Hardening Challenge](../Hardening%20Challenge/README.md)** — defend your lab machines.
- **[Linux Labs](../Linux%20Labs/README.md)** — the same skills on Linux.

## Feedback

Found a typo, a broken command, or a better way to explain a step? Open an issue on the repo.
