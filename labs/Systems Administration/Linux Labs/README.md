# Linux Labs — *The Wrkstation Chronicles: Linux Administration*

Learn the Linux command line the way you'd be tested on it: find files by size and permission, read logs, manage users, schedule jobs, write firewall rules and script small decisions. Twelve story-driven modules on a single AlmaLinux VM, with a setup script that builds the whole puzzle world for you.

Part of **Project AegisForge** → **Student path** → *Phase 1*.

> **Requires:** the [Linux lab VM](../../Lab%20Foundations/VM%20Cards/Linux%20lab%20VM.md) (AlmaLinux 10, minimal install). It is a standalone VM on VirtualBox's default NAT with an SSH port-forward, so it does **not** need `GielinorNAT` or any other lab VM. Setup: [Lab Foundations](../../Lab%20Foundations/README.md).
> **Leaves behind:** a Linux VM with the lab's characters (users and groups), puzzle files, a loopback NFS export and a baseline firewall rule. Root SSH login is turned **off**, and you work as `student` from then on. Take `linux-start` after the setup script finishes.
> **Reset:** restore the VM to `linux-start` to redo any module. To start completely over, restore `post-install-clean` and run the setup script again.
> **Don't have the VM yet?** Start with the [AlmaLinux VirtualBox Setup Guide](AlmaLinux%20VirtualBox%20Setup%20Guide.md).

## What you'll learn

1. Get help and discover what a system is (`man`, `whatis`, `apropos`)
2. Navigate, copy, move and manage files and directories
3. Read and change permissions, ownership and groups
4. Work with the shell environment, variables and a text editor
5. Process text with `grep -E`, `cut`, `sort`, `tr`, `paste` and `xargs`, including regular expressions
6. Control processes (`ps`, `lsof`, `kill`)
7. Manage users, groups and accounts
8. Inspect networking, firewall rules and NFS shares
9. Investigate logs, login history and audit trails
10. Schedule jobs with `cron`
11. Script decisions in Bash with `if` / `elif` / `else`
12. Manage packages and system services

## You'll need

- VirtualBox on a Windows host (the setup guide covers installing it)
- About 2 GB of RAM and 20 GB of disk for the VM
- Comfort opening a terminal on your own computer. No Linux experience is assumed.

## Files

| File | What it is |
|---|---|
| **AlmaLinux VirtualBox Setup Guide.md** | Build the VM: download the ISO, install, set up the SSH port-forward, take a snapshot (start here) |
| `Linux Administration Lab Setup Bash Script.txt` | Run once as `root` on the fresh VM. It builds the lab world. **Read it before you run it.** |
| **Linux Administration Lab Guide.md** | The lab itself: twelve modules |
| **Linux Commands Cheat Sheet.md** | Commands grouped by task. Keep it open. |
| **Linux Regex and grep Cheat Sheet.md** | Patterns and worked examples for Module 5 |
| **Linux Administration Lab Answer Key.md** | Check your work *after* you've tried |

## Safety — please read

- **Isolated lab VM only.** The setup script creates accounts with a published lab password (`ChangeMe123!`) and plants deliberately odd permissions and firewall rules. Never run it on a machine you care about.
- **Read the script before you run it as `root`.** It is plain text and commented.
- Keep the VM on VirtualBox **NAT**. Never bridge it to your real network.
- The lab asks you to change firewall rules. If you work over SSH, add your own ACCEPT rule *before* you set a default DROP, or you'll lock yourself out. The VM's console window always works as a way back in.
- Everything here is for learning on systems you own.

## Time & cost

Free: VirtualBox and AlmaLinux.

## Next

- **[Hardening Challenge](../Hardening%20Challenge/README.md)** — defend this VM, then your home network.
- **[Windows Labs](../Windows%20Labs/README.md)** — the same skills on Windows, with CMD and PowerShell side by side.

## Feedback

Found a typo, a broken command, or a better way to explain a step? Open an issue on the repo.
