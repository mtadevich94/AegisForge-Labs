# Firewall Rule-Base Audit: *<your name or handle>*

**Date:** 
**Ruleset audited:** `gatekeeper-ledger.nft` (exported 2026-09-30, 54 rules, 91 days of counters)
**Measured against:** Intended Policy v2
**Cleaned ruleset:** `<your filename>.nft`, checked with `nft -c`

> Describe what you found; don't paste anything you wouldn't post publicly. If you audit a real firewall for the stretch goal, replace real addresses with placeholders.

---

## 1. Summary for the Council

Five sentences, no jargon. How far has the firewall drifted from the approved policy? What are the two or three things that must be fixed first? What happens if they aren't?

## 2. Scope and method

What did you review, in what order, and with what tools? What did you *not* review (for example the `output` chain, or the contents of OPNsense)?

## 3. Inventory

| Chain | Rules | Serving an approved flow (P-xx / EX-xx) | Serving nothing approved |
|---|---|---|---|
| `input` | | | |
| `forward` | | | |
| NAT | | | |
| **Total** | | | |

Which zone pair has the most rules? Which has the most trouble?

## 4. Findings

One row per finding. Order by severity.

| # | Handle(s) | Category (A–L) | Severity | What's wrong | Evidence | Policy it breaks |
|---|---|---|---|---|---|---|
| 1 | | | Critical / High / Medium / Low | | the line, the counter | P-xx or rule 1–5 |
| 2 | | | | | | |

### Zero-hit rules

For each rule with zero hits: *shadowed, unused, or rarely needed*? What do you recommend, and why?

| Handle | Why zero | Recommendation |
|---|---|---|
| | | |

### Busy rules that are wrong

A high hit count doesn't make a rule right. Which busy rules did you flag, and what do their hits tell you?

### Decisions

Flows the policy doesn't mention. What did you decide for each, and why? Which would you ask the owner about?

| Handle | Flow | Decision (keep / remove / document) | Reason |
|---|---|---|---|
| | | | |

### What is missing

Controls that should exist and don't.

## 5. Change plan

Order by risk. You may not change everything at once on a live firewall, so for each step give a test and a way back.

| Step | Change | How I'll prove it worked | How I'll prove nothing broke | Rollback |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |

What would you do *before* step 1 (backups, out-of-band access, a change window)? Which step needs a "log first, then remove" period, and why?

## 6. Before and after

| Measure | Before | After |
|---|---|---|
| Rules (all chains) | 54 | |
| Accept rules that name no destination port (not counting replies and loopback) | | |
| Zero-hit rules | 12 | |
| Admin services reachable from `wan` | | |
| Expired temporary rules | | |
| Rules without a policy ID or comment | | |
| Is the final deny logged in every chain? | | |

## 7. Residual risk

What did you leave, and why? Rate each as low, medium or high.

| Item | Why I left it | Risk |
|---|---|---|
| | | |

## 8. What I'd do next

If you had another week: a recurring audit, expiry dates enforced by a script, config in Git with review, or the Gatehouse rebuilt to match your policy?

## 9. What I learned

Three or four sentences. What surprised you? What looked bad but was fine, or looked fine but wasn't?
