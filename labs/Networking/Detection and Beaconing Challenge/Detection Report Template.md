# Detection & Beaconing Report

**Analyst:** &nbsp; **Date:** &nbsp; **Suricata version:** &nbsp; **Captures used:** `05-scan`, `06-incident`, `07-hunt`

---

## 1. Summary (for a non-technical manager)

*Five sentences at most: what you built, what you found, and what you recommend. No jargon.*

## 2. Part 1: Rules

Paste your rules file, or link to it. Then fill one row per rule.

| # | What it detects | Fires on `05` / `06` | Fires on `07` | False positives on `07` and why | Tuned? (what changed) |
|---|---|---|---|---|---|
| 1 Scan | | | | | |
| 2a HTTP creds | | | | | |
| 2b FTP creds | | | | | |
| 3 Brute force | | | | | |
| 4 DNS data | | | | | |
| 5 DNS rhythm | | | | | |

**Tuning story (pick one rule):** the rule before, the false positive or miss, the change, the rule after, the new result.

**Run-to-run variation:** did any threshold rule alert a different number of times on repeat runs? What does that mean for how you'd trust it?

## 3. Part 2: The hunt

### Approach
*What did you look at first? What did you compute? Tool used (spreadsheet, Python, other).*

### The beacon

| Source | Destination | Port | Name (DNS / TLS) | Connections | Typical gap (s) | Gap variation | Size variation |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

**Why this is the beacon:** *the numbers, in your words.*

### The decoys

| Source → destination | Why it looks like a beacon | Why it isn't (or why you're not sure) |
|---|---|---|
| | | |
| | | |
| | | |

### Warm-up: the DNS beacon in `06-incident`
*Destination domain, interval, how many lookups, and one thing about the names that gave it away.*

## 4. What I would deploy

- **Detection rule or watch-list entry** (paste it):
- **Would I block it automatically?** Yes or no, and the cost of being wrong.
- **First thing I'd do on a real machine showing this** (isolate? image? ask the user?):

## 5. Limits

- How an attacker could slip past each rule:
- How an attacker could slip past the hunt:
- What this capture could not show me:

## 6. Reflection

*What surprised you? What did the score miss that a human noticed?*
