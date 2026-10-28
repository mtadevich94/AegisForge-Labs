# Detection & Beaconing Challenge: *The Wrkstation Chronicles: The Night Watch*

The Gatehouse is built, the walls are up, and the Gatekeeper has gone to bed. Something still has to **stay awake**. The Night Watch doesn't stop every intruder. It notices what the walls let through: a noisy scan at the gate, a password shouted across the courtyard, and, the hard one, a **messenger who slips out every minute on the minute** and never says anything loud enough to be heard.

In this challenge you do both halves of network detection: **write rules** that catch known-bad patterns, then **hunt** through a night of ordinary traffic for the one connection that is quietly phoning home.

This is an **open-ended challenge**, not a step-by-step lab. The **[Detection Checklist](Detection%20Checklist.md)** is your cross-reference and the **[Report Template](Detection%20Report%20Template.md)** is what you hand in.

Part of **Project AegisForge** → **Network Engineer path** → *Phase 2: Monitoring, Detection & Response* → the **Write and Test Detection Rules** and **Hunt for Beaconing in Network Metadata** projects.

---

> **Requires:** [WATCHTOWER](../../Lab%20Foundations/VM%20Cards/WATCHTOWER.md) (or any Ubuntu 24.04 machine) with Suricata and tshark installed (see the **[Detection Lab Setup](Detection%20Lab%20Setup.md)**). The captures in this folder and in the Packet Watch lab. *Recommended first:* [Packet Watch](../../Systems%20Administration/Wireshark%20Labs/README.md), whose `05-scan` and `06-incident` captures are used here, and the [Gatehouse](../Network%20Segmentation%20Labs/README.md) Module 8, where Suricata first appears.
> **Leaves behind:** a rules file, a hunt script or notebook, and a written report. Nothing on the lab fleet is changed. Everything runs against capture files.
> **Reset:** delete your `out/` folders and re-copy the pcaps. Nothing to restore.

## Why captures, not live traffic?

Reading a capture file is the safest and most repeatable way to learn detection. You can replay the same night a hundred times, change a rule, and see exactly what changed. It is also how real analysts work after an incident. Nothing here sends traffic anywhere.

## Before you start

1. **Everything in the captures is fictional.** The `example` domains and the documentation address ranges (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`) are reserved for examples and will not resolve on the real internet.
2. **Don't run the lab's malware-looking names against real DNS.** There is no malware here, but it's a good habit.
3. **Replay in a scratch folder.** Suricata writes logs wherever you point `-l`. Use a new folder per run.
4. **A rule that catches the attack is half the job.** The other half is proving it stays quiet on traffic that is *not* an attack. The challenge hands you a capture built to test exactly that.

## The challenge, in two parts

### Part 1. Write five rules

Using the Packet Watch captures `05-scan.pcap` and `06-incident.pcap`, write Suricata rules that detect:

1. a **port scan** (one source, many fresh connections, very fast)
2. **cleartext credentials**, in an HTTP form post *and* in an FTP login
3. a **web login brute force** (many login attempts from one source), alerting once and not twenty times
4. a **DNS name that carries data** (a long encoded label in a hostname)
5. a **repeated lookup of one suspicious domain** (a beacon's rhythm in DNS)

Then run all five against `07-hunt.pcap`, a quiet night where nothing should shout. Every alert you get there is a **false positive** you need to explain or fix. Tuning a rule until it is quiet *and* still catches the attack is the real skill.

### Part 2. Hunt the beacon

`pcap/07-hunt.pcap` is fifty minutes of ordinary Realm traffic with **one** machine calling home to a command server. It also contains traffic that is just as regular and completely harmless. A hunt that only looks for "regular" will drown.

1. Turn the capture into **tables** (connections, DNS, TLS names) with `Tools/pcap_to_tables.py`.
2. **Explore it** the way an analyst would: who talks to whom, how often, how much?
3. Write your own scoring script (a spreadsheet works too) that ranks source→destination pairs by how beacon-like they are.
4. Name the beacon, say **why** it is the beacon and **why the decoys are not**, and write the detection rule you would deploy.

The DNS beacon in `06-incident.pcap` is your warm-up: 10 lookups, 30 seconds apart. Find it by hand first.

## What counts as done

There's no score. A solid submission has:

- **Five rules** in one file, each with a comment saying what it catches and what it could wrongly catch
- **Test evidence** for each rule: what it did on the attack capture and on `07-hunt.pcap`
- **At least one rule you tuned** after a false positive, with before and after
- A **hunt** that names the beacon destination, shows the numbers behind the call, and explains the **decoys** (at least three) and why each is benign
- A **detection rule or watch-list entry** you would deploy for the beacon, plus what you would *not* block automatically
- A **limits section**: what an attacker could change to slip past your rules and your hunt
- A **one-paragraph summary** a non-technical manager could act on

Put the report in your **Public Learning Log** repo. Everything here is fictional, but don't paste real addresses or logs from your own network.

## Stuck?

- Re-read the checklist item's **Why**.
- `suricata -r file.pcap -S my.rules -l out -k none` then `cat out/fast.log`. If a rule never fires, check `out/suricata.log` for a syntax error first.
- A rule that alerts on everything is as useless as one that alerts on nothing. Count your alerts.
- Can't see the beacon? Sort by *how steady the gaps are*, then ask which of the steady ones talks to a place only one machine ever calls.

## Stretch goals

- Run the same rules against traffic you capture from the **Gatehouse** (Module 8's Suricata) and watch what your rules find on a live segment.
- Add **jitter** to the generator (`Tools/make_hunt_pcap.py`) and see how far your hunt degrades. Then decide what to change.
- Re-do the hunt in **Zeek** logs (optional, see the setup guide).
- Write a rule that fires on the beacon's **TLS server name** and compare it with the DNS version.

---

*A note on safety:* detection rules only read traffic. Never point an inline blocking rule at a production network until you have watched it run in alert-only mode for a while.
