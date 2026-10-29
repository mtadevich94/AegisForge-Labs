# Benchmark Checklist

Use this to **cross-reference your own work**. It lists the kinds of things a firewall benchmark checks, so you can tell whether you missed an area. It is **not** the benchmark: the numbered controls, exact values and audit steps are in the PDF. Each area says *what to check*, *why it matters* and *where to look*.

---

## The areas

### 1. Management access
- **What:** Which interfaces and addresses can reach the web UI and SSH, over what protocol, on which ports, with which certificate.
- **Why:** The management plane controls everything else. Whoever reaches it owns the firewall.
- **Where to look:** **System → Settings → Administration**. Compare with what Gatehouse Module 6 already did. Check the config for the web GUI and SSH sections.

### 2. Accounts and authentication
- **What:** Default and shared accounts, password strength, MFA availability, who has admin rights, API keys.
- **Why:** Stolen or guessed credentials are how most firewalls fall.
- **Where to look:** **System → Access**. Remember the lab's deliberately weak passwords: say what you'd do in production.

### 3. Services you don't need
- **What:** Every service that is enabled and listening.
- **Why:** Each running service is attack surface and something to patch.
- **Where to look:** The services list in the UI, and `sockstat -4 -l` or `netstat` on the FW01 shell. Compare the two.

### 4. Logging and time
- **What:** What is logged, where it goes, how long it is kept, and whether the clock is right.
- **Why:** You cannot investigate what you did not record, and logs with the wrong time cannot be lined up with anything else.
- **Where to look:** **System → Settings → Logging**, **Reporting**, and NTP settings. Module 8 sent syslog to ADM01. Does it still?

### 5. Updates and integrity
- **What:** Firmware version, update channel, and whether you know the system's state.
- **Why:** Known flaws in old versions are the first thing scanners look for.
- **Where to look:** **System → Firmware**. Note the version you're on before you change anything.

### 6. Network protections
- **What:** Anti-spoofing, handling of bogon and private addresses on the WAN side, IPv6, ICMP, and what the firewall does with traffic aimed at itself.
- **Why:** These stop whole families of cheap attacks before your rules are even consulted.
- **Where to look:** Each **Interface** page, and **Firewall → Settings**. The lab is IPv4-only: what does the benchmark say about unused IPv6?

### 7. Firewall policy hygiene
- **What:** Default-deny at the end, logging on blocks, no permanent "temporary" rules, comments on every rule.
- **Why:** This is where your Gatehouse work and the Rule-Base Audit meet the benchmark.
- **Where to look:** **Firewall → Rules** on every interface and the floating tab.

### 8. Backup and recovery
- **What:** A current configuration backup that is stored somewhere other than the firewall, and a known restore path.
- **Why:** A backup you have never restored is a hope.
- **Where to look:** **System → Configuration → Backups**. Test a restore on a snapshot copy.

---

## Quality checks for your report

- **Every change has a "why"** that names a real attack or failure, not "the benchmark says so".
- **Every change has a cost.** If you wrote "none", look again.
- **Every deviation names the risk accepted** and, if there is one, the compensating control.
- **Nothing in the diff is unexplained.**
- **The test matrix matches** the "before" run, or you can say exactly why it doesn't.

## Gap analysis (do this last)

- What does a hardened firewall still **not** protect you from? (A permitted flow used by an attacker, a compromised admin host, a bad rule you wrote.)
- Which controls here are **one-time** (set and forget) and which need **ongoing** attention (updates, log review, account review)?
- If you could add **one** control the benchmark doesn't have, what is it?
