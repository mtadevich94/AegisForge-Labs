# Answer Key

**Open this after you've written your own rules and finished your hunt.** If you read it first, you'll learn what the answers were and not how to find them.

You don't need to match this exactly. Different rules that catch the same things and stay quiet on the quiet night are just as good.

---

## Part 1. The reference rules

The file is `reference/night-watch-reference.rules`. Tested with Suricata 7.0.3, each capture replayed three times:

| Capture | Expected | What the reference rules did (3 runs) |
|---|---|---|
| `01-warmup`, `04-tls-contrast` | nothing | nothing |
| `02-http-login` | cleartext password in HTTP | 2a ×1 |
| `03-ftp-session` | cleartext password in FTP | 2b ×1 |
| `05-scan` | the scan | rule 1 ×1 |
| `06-incident` | scan, HTTP and FTP creds, brute force, DNS tunnel names, DNS rhythm | rule 1 ×1–2, 2a ×20, 2b ×3, rule 3 ×1, rule 4 ×3, rule 5 ×1 |
| `07-hunt` | the one cleartext login (2a), and the beacon's DNS lookups (5) | 2a ×1, rule 5 ×4–9, and occasionally a stray rule 1 |

### Things worth noticing

- **Rule 2a fires 20 times on `06`.** That is correct, because each of the 20 login attempts carries a cleartext password. It is also why rule 3 exists: twenty alerts hide the one story, which is "someone is guessing passwords". An analyst reads the one aggregated alert.
- **Rule 2a fires once on `07`, and that alert is right.** The quiet night contains one real cleartext login to the intranet server. A good report says "true positive: this is a finding about the network".
- **Rule 5 fires several times on `07`.** The beacon runs for fifty minutes and `type both` alerts once per window. Several alerts for one long-running beacon is the expected behavior. It only works because Part 2 told you the domain.
- **Rule 1 on `07`.** The capture has three bursts of 8 connections in under half a second (busy web pages). A threshold of 10 per second stays above them. Naive thresholds do not: count 5, 6 and 8 per second produced 4, 2 and 2 false alerts on `07`.

### The Suricata replay quirk (read this)

Thresholds are counted in time windows. When Suricata reads a file, the windows do not behave like strict sliding windows, so the **same capture can alert at different moments, or a different number of times, between runs.** On `06-incident` the scan alert sometimes fires at the 14-port scan (about 40 seconds in) and sometimes a little later at an unrelated FTP connection. On `07-hunt`, the scan rule fires zero or one times depending on the run.

We tried count 10 / 12 / 20 over 1 and 2 seconds. No setting was fully stable, because the instability is in how offline replay counts, not in the number. The reference rule uses **count 10 / 1 second** because it reliably catches the scan in `05` and `06` and almost always stays quiet on `07`.

What a good report does with this: run each threshold rule several times, report the range, and say that on live traffic you would watch it in alert-only mode for a week before trusting it. Noticing this is a better result than getting a lucky clean run.

---

## Part 2. The hunt

### The beacon

**`10.10.10.20` (WKS01) → `203.0.113.77:443`, name `api.forge-updates.example`.**

| Measure | Value |
|---|---|
| Connections in 50 minutes | 44 |
| Typical gap | about 60 seconds |
| Gap variation (CV) | 0.06, which is steady with a little deliberate jitter |
| Size variation (CV) | 0.006, with tiny, almost constant payloads |
| Internal machines calling it | 1 |
| Location | external |

It shares its parent domain, `forge-updates.example`, with the DNS beacon in `06-incident`. A watch-list entry for that parent domain would have caught both.

### The decoys

| Source → destination | Why it looks like a beacon | Why it isn't |
|---|---|---|
| `SRV01 → DC01:123` (NTP) | The steadiest thing in the capture: a gap CV of 0.001 and zero size variation, tied or beating everything | It is internal, it is a time sync, and it is on the right port. It is the machine telling the clock to behave. |
| `SRV01`, `DC01`, `WKS01 → 198.51.100.40:443` (`telemetry.update-service.example`) | Gap CV about 0.005–0.008, every 5 minutes | Three different internal machines call it. A command server isn't normally shared by every server. Vendor update checks are. (Still worth confirming it is a vendor you run.) |
| `WKS01 → 192.0.2.25:993` (`imap.mail-host.example`) | Polls about every 90 seconds, gap CV about 0.09 | It is a mail client, on the IMAP over TLS port, with bigger and more varied sizes (size CV about 0.38). |
| `WKS01 → 10.10.10.30:80` | Many connections | Internal, irregular, and sizes vary wildly. It is a person browsing the intranet. |
| Browsing bursts to `docs.opnsense.org`, `attack.mitre.org` | Many connections | Gaps are all over the place (CV 0.88–0.97). That is a human. |

### What the reference scorer does

`reference/beacon_score.py`, run with `conns.csv` and `tls.csv`:

```
score  source       destination       port conns  gap(s)  gapCV sizeCV srcs  name
 0.73  10.10.10.20  203.0.113.77       443    44    59.7  0.060  0.006    1  api.forge-updates.example
 0.18  10.10.10.40  198.51.100.40      443    10   298.3  0.005  0.092    3  telemetry.update-service.example
 ...
```

With `--rank regularity` (regularity alone), the beacon ranks **fifth**: NTP, then the three vendor-telemetry pairs, all beat it. This is the point of the challenge. A score is built from reasons you can explain, and each factor (size constancy, rarity, external) removes a decoy.

| Factor | What it removes |
|---|---|
| Size constancy | Mail polling (sizes vary) |
| Rarity (how many machines call it) | The vendor telemetry (three callers) |
| External | NTP (internal) |

### The deploy decision

A good answer:

- Add `forge-updates.example` (parent domain) to a **watch-list or DNS sinkhole**, as in the Gatehouse's Module 7.
- Put the TLS server name `api.forge-updates.example` in a rule as well, so you catch it when DNS is bypassed.
- **Don't auto-block `203.0.113.77` alone.** An IP can be shared or change, and the rule must not break the vendor telemetry next to it.
- **Isolate WKS01** and investigate it, because the beacon proves it is running something it shouldn't.

### The limits (what an attacker changes)

- **Jitter:** a beacon with ±50% jitter has a gap CV of about 0.3, which blends into browsing. The regularity measure weakens first.
- **Size padding:** random-length padding defeats size constancy.
- **Piggybacking on a popular destination** (a cloud storage service everyone uses) defeats rarity.
- **A different protocol or port** defeats the port-based rules. Encryption hides content but not timing, which is why the hunt is metadata-based.
- **Slow beacons** (once an hour or a day) won't show up in a fifty-minute capture at all.

### Warm-up: the DNS beacon in `06-incident`

Domain `forge-updates.example`, a TXT query every 30 seconds, ten times. The names look like `NN.<hex>.cdn-sync.forge-updates.example`: a sequence number, then 16 or more hex characters, which is the data. The lookups return NXDOMAIN, because the attacker's server only needs the question, not an answer.
