# Rule-Base Audit Challenge: *The Wrkstation Chronicles: The Gatekeeper's Ledger*

Years have passed since the Gatehouse was raised. The Gatekeeper moved on, and every week since, someone has asked for "just one more gate". A contractor needed in. A debugging session needed everything open. A vendor came and went. Each request became a rule. Nobody ever took one out.

The Council has called you in as an **auditor**. Before the next review they want to know one thing: **does the Realm's firewall still do what the Council approved, or has it quietly become something else?**

You have two things: the **[Intended Policy](Intended%20Policy.md)** (what the firewall should do) and **[the Ledger](gatekeeper-ledger.nft)** (what it actually does: 54 rules, 91 days of hit counters). Your job is to find every place they disagree, decide what to do about each one, and prove your fixes don't break what the Realm needs.

This is an **open-ended challenge**, not a step-by-step lab. You decide the order, you defend your decisions. The **[Audit Checklist](Audit%20Checklist.md)** is your cross-reference and the **[Report Template](Audit%20Report%20Template.md)** is what you hand in.

Part of **Project AegisForge** → **Network Engineer path** → *Phase 1: Secure Network Design & Hardening* → the **Firewall Rule-Base Audit** project.

---

> **Requires:** no VMs. A text editor and the files in this folder. *Optional:* any Linux machine with `nftables` installed (for example [WATCHTOWER](../../Lab%20Foundations/VM%20Cards/WATCHTOWER.md)) to syntax-check your clean-up. *Recommended first:* the [Gatehouse lab](../Network%20Segmentation%20Labs/README.md), so the zones and addresses are familiar.
> **Leaves behind:** a written audit report and a cleaned ruleset. Nothing is installed or changed on any VM.
> **Reset:** download `gatekeeper-ledger.nft` again.

## New to rule-base audits?

Read **[Firewall Audit Concepts](Firewall%20Audit%20Concepts.md)** first. It explains, with a small made-up ruleset, what first-match ordering, default deny, least privilege, shadowed rules, hit counters and egress control are, and why auditors care about each. The Checklist then tells you what to look for.

## Why nftables, when the Gatehouse uses OPNsense?

OPNsense is built on `pf`, and a `pf` ruleset can't be checked or read without OPNsense running. **nftables** is the Linux firewall language. It is plain text, free, readable top to bottom, and `nft -c` can check a file without loading it. The audit skills are the same on any firewall: shadowed rules, any/any rules, dead rules and missing egress control look identical on pf, iptables, Cisco ASA, Palo Alto or a cloud security group. If you can audit this, you can audit those.

You don't need to know nftables. Every rule is one line, and the **[Audit Checklist](Audit%20Checklist.md)** shows how to read them.

## Before you start

1. **Read the Intended Policy first**, all of it, before opening the Ledger. An auditor who has not read the policy can only find rules that look ugly, not rules that are wrong.
2. **Work on a copy.** Keep `gatekeeper-ledger.nft` untouched. Put your clean-up in a new file.
3. **Never load this ruleset onto a machine you are connected to over the network.** It is a teaching file. The `nft -c` flag only *checks* the syntax. Do not run `nft -f` without the `-c`.
4. **Counters are evidence, not verdicts.** Read the header comment in the Ledger about what a counter counts. A rule with zero hits and a rule with a million hits can both be wrong.

## The challenge, in six steps

### 1. Read the policy

Learn the zones, the approved flows (P-01 to P-09), the one exception (EX-004), and the five rules every rule must follow. Draw the zone-to-zone picture on paper if it helps. This is what "correct" means for the rest of the challenge.

### 2. Inventory the Ledger

Before judging anything, count and group. How many rules are there? How many per chain? Which zone pair does each one control? Which approved flow (or exception) does each one serve? Rules that serve none are your first list of suspects.

### 3. Hunt

Work through the Checklist. For every suspect, write down the **handle**, what's wrong, and the **evidence** (the line, the counter, the policy it breaks). Look for rules that are shadowed, too broad, dead, stale, duplicated, unlogged or missing. Also look for what is *absent*: a good auditor reports controls that should exist and don't.

### 4. Plan: order by risk and say how you'd test each step

Not every finding is equally urgent, and you must not fix them all at once on a live firewall. Order your fixes from "an outsider can reach an admin service" down to "a duplicate rule wastes a line". For each step, say **what you'll change, how you'll prove it worked, how you'll prove nothing broke, and how you'd roll back**.

### 5. Fix: write the clean ruleset

Write your cleaned version in a new file. Check it with `nft -c -f your-file.nft`. Every rule you keep should map to an approved flow or an exception, carry a comment saying so, and be as narrow as it can be. For rules you can't classify, decide, and write down why.

### 6. Report

Use the **[Report Template](Audit%20Report%20Template.md)**: findings, change plan, a before-and-after table, and the risk you chose to leave. Finish with a one-paragraph summary a non-technical Council member could act on.

## What counts as done

There is no score. As a guide, a solid submission has:

- An **inventory** of the Ledger grouped by chain and zone pair
- **At least 15 distinct findings** across **at least six** of the checklist's categories, each with the handle, the evidence and the policy it breaks
- A **change plan** ordered by risk, with a test and a rollback for every step
- A **cleaned ruleset** that passes `nft -c`, with every rule mapped to an approved flow, an exception, or a documented decision
- A **before-and-after table** (rule count, any-source rules, zero-hit rules, externally reachable admin services)
- At least **two "decision" items** where the policy is silent and you explain what you chose and why
- **Residual risk**: what you left in, and why

Put the report in your **Public Learning Log** repo. A cleaned ruleset and a clear audit report is exactly the artifact an interviewer wants to read.

## Stuck?

- Re-read the Checklist item's **Why**. The purpose usually points to the finding.
- A rule is **shadowed** when an earlier rule matches everything it matches. Read the file top to bottom and ask of each rule: *could any packet ever get this far?*
- `nft -c -f file` tells you when you've written something that doesn't parse. Looking up the syntax in the nftables wiki is fine. That is the job.
- Not sure whether to delete a rule? Ask what would break, who would notice, and how you'd find out *before* you delete it.

## Stretch goals

- **Prove a shadow.** Pick one rule you say is shadowed and write the one-line argument for why no packet can ever reach it.
- **Rebuild it in OPNsense.** Take your cleaned policy and implement it in the Gatehouse. Run `segtest.sh` or `Test-Segmentation.ps1` against it and see what your policy blocks that the Gatehouse's own does not (or the reverse).
- **Audit your own firewall.** Export the rules from your home router or a VM firewall and run the same checklist on it. Do this carefully and don't post real addresses.
- **Write the checker.** Write a small script that reads the Ledger and lists zero-hit rules and rules with no comment. This leads straight into the *Network-as-Code Compliance Checker* project in Phase 3.

## Files

| File | What it is |
|---|---|
| **Intended Policy.md** | What the Council approved. Read this first |
| `gatekeeper-ledger.nft` | The Ledger: the ruleset to audit, with 91 days of hit counters |
| **Firewall Audit Concepts.md** | What each audit idea is and why it matters, with a small worked example that is not the Ledger |
| **Audit Checklist.md** | Categories of problems, with what to check, why it matters and where to look |
| **Audit Report Template.md** | What you hand in |
| **Auditor's Key.md** | The planted findings, the traps, and a model change plan. Open it only *after* you've written your own |
| `gatekeeper-ledger-cleaned.nft` | One defensible clean-up. Open it only *after* you've written your own |
| `SHA256SUMS` | Checksums so you can verify the files weren't altered |

## Versioning

Current: **v1.0.0**.

---

*A note on safety:* this is a read-and-reason challenge. Audit rulesets you own or have written permission to review. Never test firewall changes on a machine you are connected to over the network without an out-of-band way back in.
