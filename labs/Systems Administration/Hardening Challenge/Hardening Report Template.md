# Hardening Report: *<your name or handle>*

**Date:** 
**Machines hardened:** (for example: Linux lab VM, WKS01, WATCHTOWER, DC01)
**Snapshot used as the starting point:** `hardening-start`

> Don't include real passwords, real addresses from your home network, or anything you wouldn't post publicly. Describe it ("a weak shared password") instead of pasting it.

---

## 1. Baseline: what I found

For each machine, a short summary of the starting state, with the evidence you collected (command and output, trimmed to the interesting part).

### <Machine name>

| Area | What I found | Evidence |
|---|---|---|
| Accounts | | |
| Network exposure | | |
| Privileges | | |
| Firewall | | |
| Logging | | |

*(Repeat for each machine.)*

## 2. Prioritization: what I chose to fix first, and why

Rank your top findings by how damaging they would be and how easy they are to exploit. Two or three sentences is enough.

1. 
2. 
3. 

## 3. Changes

One row per change. Aim for the "why" in your own words.

| # | Machine | What I changed | Why | Evidence it worked (before → after) |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |

If a change broke something, write that down too, along with how you fixed it. It shows real understanding.

## 4. Layer B and C: beyond the lab

Which items from the "any machine" and "home network" sections did you check or change? What did you find on your real network, in general terms?

## 5. Residual risk: what I did *not* fix

List what's still weak, and why you left it (it breaks a lab, it needs a bigger change, it's low risk, you ran out of time). Rate each as low, medium or high.

| Item | Why I left it | Risk |
|---|---|---|
| | | |

## 6. What I'd do next

If you had another weekend, what would you do? (For example: key-only SSH everywhere, a central log server, or the Tiered Admin lab.)

## 7. What I learned

Three or four sentences. What surprised you? What was harder than expected?
