# Hardening Challenge — *The Wrkstation Chronicles: Holding the Keep*

You've built the lab. Now defend it.

The Gatekeeper left in a hurry. The keep's machines still run on the settings they were built with: shared starter passwords, services nobody remembers starting, and rules nobody wrote down. **Make them defensible, and prove it.**

This is an **open-ended challenge**, not a step-by-step lab. There is no single right order and no answer key to copy. You decide what matters most, you make the changes, and you show your evidence. The **[Hardening Checklist](Hardening%20Checklist.md)** is your cross-reference: recommendations to measure your work against, from your own lab machines up to your home network.

Part of **Project AegisForge** → **Student path** → *Phase 2: Level Up* → the **Home Lab Hardening** project.

---

> **Requires:** [Linux lab VM](../../Lab%20Foundations/VM%20Cards/Linux%20lab%20VM.md) (AlmaLinux, with the Linux Administration lab's setup script already run); [WKS01](../../Lab%20Foundations/VM%20Cards/WKS01.md) (from the Windows Labs). Optional but recommended: [WATCHTOWER](../../Lab%20Foundations/VM%20Cards/WATCHTOWER.md) (from Packet Watch) and [DC01](../../Lab%20Foundations/VM%20Cards/DC01.md). Setup: [Lab Foundations](../../Lab%20Foundations/README.md).
> **Leaves behind:** hardened lab VMs that are *still usable*, plus a written report. Some earlier labs deliberately rely on weak settings, so finish those first (see "Order of operations" below).
> **Reset:** restore each VM to `hardening-start`.

## Before you start

1. **Finish the labs you want to keep doing.** The Linux, Windows and Packet Watch labs depend on weak settings (shared passwords, plaintext FTP, an open share). Hardening breaks them on purpose. If you haven't done them yet, do them first, or work on a **linked clone** (right-click the VM → Clone → *Linked clone*) and harden the clone.
2. **Snapshot every VM** you'll touch and name it `hardening-start`. You *will* lock yourself out of something. That's part of learning, and the snapshot makes it cheap.
3. **Use a second login session** when you change SSH or firewall settings. Keep your working session open, test the change from a new one, and only then close the old one.
4. **Keep the VMs isolated.** NAT Network and Internal Network only. Never bridge a lab VM to your real network.

## The challenge, in four steps

### 1. Baseline: find out what's wrong *before* you touch anything

Record the starting state of each machine: who can log in, what's listening on the network, what runs with elevated privileges, what the firewall does, what gets logged. Don't fix anything yet. Your "before" notes are half of your finished report.

### 2. Plan: choose what matters

You won't fix everything, and nobody does. Rank what you found by **how bad it would be** if an attacker used it, and **how easy it is for them**. Pick your changes. Write one sentence on why you picked those first.

### 3. Harden, one change at a time

Make a change. Test that the machine still works. Test that the change *did* what you intended. Then move on. Changing five things at once means you can't tell which one broke SSH.

### 4. Prove it and write it up

For each change, show evidence: a command's output before and after, a failed login that now fails, a port that no longer answers. Use the **[Report Template](Hardening%20Report%20Template.md)**. Finish with what you **didn't** fix and what risk that leaves. Honest residual risk is what a hiring manager actually wants to read.

## What counts as done

There's no score. As a guide, a solid submission has:

- A **baseline** for every machine you hardened
- At least **4 verified changes on Linux** and **4 on Windows**, each with before/after evidence
- Changes on **at least two** of the checklist's three layers (your lab, any machine, your home network)
- A **residual risk** section
- Your own words for the "why" of each change, not copied from the checklist

Then put the report in your **Public Learning Log** repo. Don't include real passwords, real IP addresses from your home network, or anything you wouldn't post publicly.

## Order of operations (a suggestion, not a rule)

Most people have the best results by starting with **accounts and access** (who can log in, with what), then **network exposure** (what's listening, what the firewall allows), then **logging** (so you'd notice a problem), then **patching and everything else**. Access and exposure are where real attackers usually start.

## Stuck?

- Re-read the checklist item's **Why**. The purpose usually points to the fix.
- `man <command>` and Microsoft Learn are fine. Looking things up is the job.
- If a change breaks the VM, restore the snapshot and try again. That isn't failing, it's iterating.

## Stretch goals

- Run a security audit tool such as **Lynis** (Linux) and compare its findings to yours.
- Re-run the Wireshark capture from Packet Watch to **prove** the plaintext credentials are no longer visible.
- Pick two checklist items from Layer C and apply them to your actual home network. This is the one most people never get around to.

---

*A note on safety:* everything in this challenge applies to machines **you own**. Only scan and test your own lab and your own network.
