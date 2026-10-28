# Lab Account Standard

Every VM in the fleet has the same two things: an **everyday account** you do the lab work with, and a clearly named **admin path** for installing, running setup scripts and getting back in when a lab locks you out. This page is the single source of truth. If a lab guide, script or VM card disagrees with it, this page wins and the disagreement is a bug. Please report it.

## Rules

1. Each VM has one named admin path and, where the lab needs one, one named everyday account. Nothing else is assumed.
2. Lab passwords are throwaway and published. Never reuse a real password, and never put a lab VM on your real network.
3. Where a table says **you choose**, pick a password at install and write it down. No lab depends on its value.
4. Setup scripts create the accounts a lab needs. Guides say which account to be signed in as at each step.
5. A new VM or lab adds a row to this page in the same change.

## Linux and appliance VMs

| VM | Admin path | Everyday account | Created by |
|---|---|---|---|
| **Linux lab VM** (AlmaLinux 10) | `root` for the first login and the setup script only. Root SSH is turned **off** by the script. Afterwards use `sudo`. | `student` / `ChangeMe123!`, in the `wheel` group so `sudo` works | `root` password: you choose at install. `student`: the lab's setup script |
| **WATCHTOWER** (Ubuntu 24.04) | `sudo` | `analyst` (you choose the password) | Ubuntu installer |
| **VULN01** (Ubuntu 24.04) | `sudo` | `analyst` (you choose the password). Nessus has its own admin login, made in its setup wizard | Ubuntu installer; Nessus wizard |
| **WEB01**, **ADM01** (Ubuntu 24.04) | `sudo` | `gatekeeper` (you choose the password) | Ubuntu installer |
| **FW01** (OPNsense) | `root` (password you choose at install); `gatekeeper-admin` is added in Gatehouse Module 6 | none | OPNsense installer; Gatehouse Module 6 |

## Windows VMs

| VM | Admin path | Everyday account | Created by |
|---|---|---|---|
| **DC01** (Server 2022) | `Administrator`, with the password you choose at install. It becomes `GIELINOR\Administrator` after promotion and keeps that password | `GIELINOR\student` / `ChangeMe123!` | Windows ISO Setup; Domain Setup Guide step 4 |
| **SRV01** (Server 2022) | local `Administrator` (you choose the password); `GIELINOR\Administrator` once joined | `GIELINOR\student` | Tiered Admin Environment Setup |
| **WKS01** (Windows 11) | `labadmin`, the local administrator you create at install (you choose the password). It is also the break-glass account if a policy locks you out | `GIELINOR\student`, a **standard user**, only in the domain-joined state | Windows ISO Setup step 4; Domain Setup Guide step 4 |

Windows 11's built-in `Administrator` account is disabled by default and stays that way. `labadmin` takes its place.

To get an elevated prompt on WKS01, sign in as `.\labadmin` (at the sign-in screen choose **Other user**), then right-click Start and choose **Terminal (Admin)**.

## Lab passwords

| Password | Used for |
|---|---|
| `ChangeMe123!` | Linux lab accounts, Windows Garrison local users, and `GIELINOR\student` |
| `Gielinor!Lab#2026` | Tiered Admin's cast and service accounts. This is the default of `-LabPassword`, which must be 16+ characters |
| one you type | The `t0-`, `t1-` and `t2-` admin accounts (Tiered Admin Module 3 asks for it) |
| `Ph0enix-Ash#42` | The WATCHTOWER FTP account `vaultkeeper`, deliberately weak for Packet Watch |

## Names that look alike

- The cast names (`General_Graardor`, `Zelda_Warden`, `Navi` and so on) exist twice on a domain-joined WKS01: as **local** accounts made by the Windows Garrison setup script, and as **domain** accounts made by Tiered Admin. Type `.\Navi` (or `WKS01\Navi`) for the local one and `GIELINOR\Navi` for the domain one. A bare `Navi` at the sign-in screen resolves to the local account first. The passwords differ (`ChangeMe123!` local, the Tiered lab password for domain), which is a quick tell for which one you hit.
- `student` is a **Linux** account and a **domain** account. There is no local `student` on WKS01.
