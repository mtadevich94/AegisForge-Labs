# OPNsense Benchmark Challenge: *The Wrkstation Chronicles: The Royal Inspection*

The Gatehouse stands, the zones hold, and the Gatekeeper is proud of the wall. Then a letter arrives from the Council: **an Inspector is coming, and she carries the Standard.**

The Standard is a published checklist, the **CIS Benchmark for OPNsense**, written by practitioners who have seen the same mistakes many times. It doesn't care that your firewall *works*. It asks whether it is **hardened**: whether the admin interface, the accounts, the services, the logging and the update habits would hold up if someone hostile got close.

In this challenge you **pull the firewall's real configuration, measure it against the Standard, and write a new configuration that meets it.** For every change you make, you write down **why**. The change is the easy part. The explanation is the skill.

This is an **open-ended challenge**, not a step-by-step lab. The **[Benchmark Checklist](Benchmark%20Checklist.md)** is your cross-reference and the **[Report Template](Benchmark%20Report%20Template.md)** is what you hand in.

Part of **Project AegisForge** → **Network Engineer path** → *Phase 1: Secure Network Design & Hardening* → the **Harden a Device to a Benchmark** project.

---

> **Requires:** [FW01](../../Lab%20Foundations/VM%20Cards/FW01.md) with the **completed Gatehouse policy** (all eight modules of the [Gatehouse lab](../Network%20Segmentation%20Labs/README.md)), plus [WKS01](../../Lab%20Foundations/VM%20Cards/WKS01.md) (minimal, on `realm-garrison`), [WEB01](../../Lab%20Foundations/VM%20Cards/WEB01.md) and [ADM01](../../Lab%20Foundations/VM%20Cards/ADM01.md) so you can prove the Realm still works afterwards. A free CIS account to download the benchmark PDF.
> **Leaves behind:** a hardened FW01 configuration, a scored worksheet, a written report with a reason for every change. Nothing is installed outside the lab.
> **Reset:** restore every VM to `benchmark-start` (you create this snapshot in step 0). **Note:** the Gatehouse's own reset is `00-flat-baseline`, which is *before* the policy was built. Don't use it here.

## The benchmark

**[CIS OPNsense Benchmark](https://www.cisecurity.org/benchmark/opnsense)** (version 1.0.0 when this lab was written). The PDF is free after you register.

This repository does **not** reproduce the benchmark text. It belongs to CIS, and you should read the real thing: the numbering, the profiles, the rationale and the audit steps are all part of the learning. Always check the version on the page, and confirm the controls match the OPNsense release your FW01 runs.

## Why "write a new config" and not "click through the checklist"?

A real firewall change goes through review: someone has to see **what is changing and why** before it reaches production. So you will finish with:

1. the **before** configuration,
2. the **after** configuration,
3. a **diff** between them, and
4. a **reason for every line of the diff**.

If you can't explain a change, you shouldn't make it. If a control would break the Realm, you don't have to apply it. You have to **say so and defend the deviation**. That is what a real exception looks like.

## Before you start

1. **Snapshot everything as `benchmark-start`** (FW01, WKS01, WEB01, ADM01) *before* you touch anything. Hardening a firewall is one of the easiest ways to lock yourself out of it.
2. **Know your way back.** The Gatehouse's management-hardening module shows how to restore a configuration from the FW01 console. Re-read it first.
3. **Treat the configuration file like a secret.** `config.xml` holds password hashes, API keys, pre-shared keys and certificates' private keys. It must **never** go into a public repository unredacted. Your report contains a *redacted* copy and the diff only.
4. **Change in small batches.** Apply a handful of controls, test, back up the configuration, then do the next batch. Never fifty changes and then wonder which one broke DNS.
5. **Lab constraints are real.** This is a one-person lab, not a production firewall. Some controls (central authentication, off-box log storage, hardware-specific settings) can't be met as written. Plan what you'll do instead.

## The challenge

### 0. Snapshot, then pull the evidence

- Take the `benchmark-start` snapshots.
- Download the benchmark PDF and read the **introduction and profile definitions** before the controls.
- Export FW01's configuration (**System → Configuration → Backups**). Save it as `fw01-before.xml`. Note the OPNsense version (**System → Firmware** or the dashboard).
- Run the Gatehouse **test matrix** once, from everywhere, and save the output. This is your proof of "the Realm works" and you will run it again at the end.

### 1. Assess: where do you stand today?

For every control in the benchmark profile you chose, record: **Pass, Fail, Not applicable, or Can't tell**, plus the **evidence** (a screenshot, a setting, or a line from `config.xml`). Do this *before* you change anything. Use the **[Benchmark Worksheet](Benchmark%20Worksheet.md)**.

Reading the configuration file for evidence is faster and more repeatable than clicking, and it is a skill worth having. You are not expected to master the XML. You are expected to find the section that matches the setting.

### 2. Decide: apply, adapt, or defend a deviation

For each Fail, choose one:

- **Apply** it as written.
- **Adapt** it: meet the intent a different way, and say how.
- **Deviate**: leave it, and write why. A good deviation names the risk you are accepting and the compensating control, if any.

Don't just apply every control. Some depend on things the lab doesn't have, and some conflict with Gatehouse rules (for instance, a management restriction that would cut off the jump-host path you built in Module 6). Work out which before you change anything.

### 3. Build: the new configuration

Make the changes in OPNsense, in small batches, and export a backup after each batch. At the end, save the final export as `fw01-after.xml`.

*Stretch:* instead of clicking, edit a **copy** of `fw01-before.xml` and restore it onto a snapshot-restored FW01. This works, but the file structure can change between OPNsense versions, so check the benchmark and the version of OPNsense before you try it, and keep the snapshot handy.

### 4. Prove it: the Realm still works, and the numbers improved

- Run the Gatehouse **test matrix** again. It must match the "before" run, except where you deliberately changed something (and you can say why).
- Re-score the worksheet with fresh evidence.
- Produce the **diff**: `fc fw01-before.xml fw01-after.xml` on Windows or `diff -u` on Linux. Every changed region of the diff must trace back to a worksheet row.
- Make sure each change is *explained*. Anything in the diff you can't trace is a mistake or a side effect. Find out which.

### 5. Report

Use the **[Report Template](Benchmark%20Report%20Template.md)**. The centerpiece is the **change table**, one row per change, with its reason.

## Why every change needs a reason

A control without an explanation is cargo cult security. For each change, your report answers five short questions:

| Question | Why it matters |
|---|---|
| **What was the setting before, and after?** | So a reviewer can see the change without opening the file. |
| **What attack or failure does this make harder?** | This is the "why". Name the real thing: a stolen password, a sniffed login, a missed alert, an unpatched flaw. |
| **What does it cost?** | Every control costs something: convenience, a lost feature, a harder recovery. Naming it shows you thought. |
| **How did you check it worked?** | A control you didn't verify is only a belief. |
| **How do you undo it?** | Firewall changes that can't be reversed are the ones that cause outages. |

## What counts as done

There's no score. A solid submission has:

- A **worksheet** covering every control in your chosen profile, with evidence
- **Before and after** pass counts
- A **change table** with a reason, a cost and a check for **every** change
- At least **three adapted or deviated controls** with a defended reason
- **Proof the Realm still works**: the test matrix before and after
- A **redacted** after-config and the diff, with secrets removed
- A short **"what the benchmark didn't cover"** section (see the checklist's gap analysis)
- A **one-page summary** a non-technical manager could act on

Put the report in your **Public Learning Log** repo. Redact secrets, internal hostnames and anything you wouldn't post publicly.

## Stuck?

- Re-read the checklist item's **Why**.
- Locked out of the web interface? Use the FW01 **console** (option 13 restores a backup). If that fails, restore the `benchmark-start` snapshot. You lose time, not data.
- A test that passed before now fails? Undo your last batch, and change one thing at a time.
- Not sure a control applies? "Not applicable, because …" is a valid answer if the *because* is real.

## Stretch goals

- Re-run the **[Firewall Rule-Base Audit](../Firewall%20Rule-Base%20Audit%20Challenge/README.md)** thinking on FW01's real rules (export them, then check them against your Intended Policy).
- Write a small script that checks a few settings straight from `config.xml` and prints Pass or Fail, so the assessment repeats itself.
- Schedule a recurring configuration backup, then diff two weeks of backups to see **drift**.
- Compare this benchmark with another vendor's hardening guide. Which controls appear in both?

---

*A note on safety:* hardening can lock you out of your own firewall. Keep snapshots, keep console access, and never apply a change you can't explain.
