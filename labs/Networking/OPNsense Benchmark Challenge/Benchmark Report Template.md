# OPNsense Benchmark Report

**Name:** &nbsp; **Date:** &nbsp; **Benchmark & version:** &nbsp; **Profile:** &nbsp; **OPNsense version:**

---

## 1. Summary (for a non-technical manager)

*Five sentences at most. What was checked, how many controls passed before and after, what you couldn't or wouldn't apply, and the one thing they should decide.*

## 2. Scope and method

- What you assessed (FW01, which profile) and what you left out, with reasons
- How you gathered evidence (UI, `config.xml`, shell)
- How you protected the configuration (snapshots, backups, redaction)

## 3. Before and after

| | Before | After |
|---|---|---|
| Pass | | |
| Fail | | |
| N/A | | |
| Deviations accepted | – | |

## 4. Change table (the centerpiece)

One row per change. Every change gets a reason.

| Control # | Before → After | Why: the attack or failure it reduces | Cost | How I verified it | How to undo |
|---|---|---|---|---|---|
| | | | | | |

## 5. Adapted and deviated controls

| Control # | Adapted or deviated? | What I did instead, or why I left it | Risk accepted | Compensating control |
|---|---|---|---|---|
| | | | | |

## 6. Proof the Realm still works

- Gatehouse test matrix **before** (paste or link)
- Gatehouse test matrix **after** (paste or link)
- Differences, and the reason for each

## 7. The diff

Link to the redacted diff of `fw01-before.xml` and `fw01-after.xml`. For each changed region, name the worksheet row it belongs to. List anything you could **not** trace and what you found out.

## 8. What the benchmark didn't cover

*Risks that remain after a perfect score. See the checklist's gap analysis.*

## 9. Ongoing work

*Which controls need regular attention (updates, log review, account review)? How often, and who owns it?*

## 10. Reflection

*Which control surprised you? Which one would you push back on if a manager demanded it? Why?*
