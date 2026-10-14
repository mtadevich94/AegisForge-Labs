# The Gatehouse — Answer Key

**Try each module first.** The questions are about *understanding*, so your own wording matters more than matching mine. Use this to check your reasoning and to compare your rule base with a known-good one.

> Counts below (for example "14 of 19") depend on which services are running in your lab and can vary by one or two. What matters is the *pattern*.

---

## Module 1 — Walk the Open Field

**Expected `attack-sim.sh` result in the flat realm** (19 attempts):

| Step | Attempt | Result |
|---|---|---|
| 1 | Garrison workstation `:8080` | **OPEN** (the canary) |
| 1 | Garrison workstation `:22 :80 :445 :3389` | stopped — but by *Windows Defender Firewall* on WKS01, not by OPNsense (nothing is listening, or Windows drops it) |
| 1 | Citadel ADM01 `:22 :80 :8080` | **OPEN** ×3 |
| 1 | Garrison gateway `:80 :443` | **OPEN** ×2 (the firewall's web GUI; port 80 redirects to HTTPS). `:22` is stopped — SSH on the firewall is switched off by default. |
| 2 | Firewall web GUI on all three interfaces (`10.20.20.1`, `10.20.30.1`, `10.20.10.1` `:443`) | **OPEN** ×3 (the GUI listens everywhere by default) |
| 2 | Citadel SSH | **OPEN** |
| 3 | C2 callback `:4444` | **OPEN** (needs the WATCHTOWER listener) |
| 3 | Exfil over HTTPS `:443` and FTP `:21` to WATCHTOWER | **OPEN** ×2 |
| 4 | DNS straight to `8.8.8.8` | **ANSWERED** |

So roughly **14 of 19** attempts succeed. *Which succeed is the point:* the raider can see the Garrison, the Citadel, and the firewall's own GUI, and can call home.

**The three flags**

| From | Flag |
|---|---|
| Citadel ledger (`http://10.20.30.10/`) | `FORGE{the_citadel_was_reachable_from_the_wrong_zone}` |
| Garrison canary (`http://<WKS01>:8080/`) | `FORGE{the_garrison_was_reachable_from_the_wrong_zone}` |
| Market admin panel (`http://10.20.20.10:8080/`) | `FORGE{admin_panel_was_reachable_from_the_wrong_zone}` |

**Check yourself**

1. About 14, all in the table above: ADM01's three services, the Garrison canary, the firewall's web GUI (on each of its three interface addresses, plus ports 80/443 on the Garrison gateway), Citadel SSH, the three outbound channels (C2, HTTPS, FTP), and public DNS.
2. A public web server answers requests from visitors. It has no legitimate reason to *start* a connection to a workstation, an admin host, or any firewall interface. The only plausible outbound needs are package updates and (later) shipping logs. Everything else in the "OPEN" list is an attacker's gain.
3. Almost nothing. The flat-realm rules are *Pass* rules with logging off, and the firewall only logs **blocked** traffic by default (plus whatever a rule is told to log). A successful intrusion path leaves **no firewall record at all** unless you ask for one — attackers rely on this.
4. Any service in any zone is a single hop from the Marketplace server: *a compromise of WEB01 is a compromise of the Garrison, the Citadel, and (via its GUI) the firewall.* Something like that, in your own words.

---

## Module 2 — Draw the Walls

### Part A — trust ranking (most → least trusted)

1. **Citadel** (administrators hold the keys; fewest hosts; almost nothing should reach it)
2. **Garrison** (users; moderately trusted but exposed to phishing and mistakes)
3. **Market** (public-facing; assume it will be attacked)
4. **Wilderness / Internet** (untrusted)

(The Garrison-versus-Citadel order is the usual debate. What matters is that the Citadel is *above* the Garrison and the Market is *below* both.)

### Part C — recommended matrix (rows = source, columns = destination)

| From ↓ / To → | **Garrison** | **Market** | **Citadel** | **Firewall itself** | **Internet** |
|---|---|---|---|---|---|
| **Garrison** | n/a | **WEB01 only**, TCP 80/443 | **Deny** *(one logged exception for the admin PC → ADM01 SSH, added in Module 6)* | DNS (53), ping *(GUI via anti-lockout until Module 6)* | Web 80/443; NTP 123/UDP |
| **Market** | **Deny** | n/a | **Deny** *(one logged exception for WEB01 → ADM01 syslog UDP 514, added in Module 8)* | DNS (53), ping | WEB01 only: web 80/443 *(narrowed to package mirrors in Module 7)* |
| **Citadel** | **Deny** | ADM01 → WEB01, TCP **22** and **8080** only | n/a | GUI 443, SSH 22, DNS 53, ping | Web 80/443; NTP |
| **Internet** | **Deny** | **WEB01 only**, TCP 80/443 *(Module 4, via destination NAT)* | **Deny** | **Deny** | n/a |

Key properties of a good answer: the **Market has no way "in"** (the only row of Deny→Garrison/Citadel is the one that matters most); **admin traffic is initiated by the admin zone**; the **only** inbound path from the internet is one host and two ports.

### Check yourself

1. The Market (DMZ). Because it is exposed to the internet and runs software that anyone can send input to, it must be assumed compromisable — so it may reach almost nothing, and nothing important.
2. Because *who starts the conversation* decides who can attack whom. If the admin host initiates, a compromised server cannot open a connection to the admin host. If the *server* could initiate to the admin zone, an attacker on the server would have a ready-made path into management.
3. It lets you write "anywhere inside the realm" as one object: used in the *Block* rules (M4, C7, G4) and, inverted, in "anywhere *not* inside the realm" for internet-bound rules (M3, C5, C6, G5, G6).
4. Compare each Allow cell with a Part B row. Common over-allows: Garrison → Citadel (no business need — the jump host exception comes later), Market → Garrison, and "all ports" where a few would do.

**Aliases check** — the Aliases page should list all twelve, enabled. Typical mistakes: a hyphen in a name (`NET-REALM`) or a space; port aliases with ports separated by a comma rather than on separate lines; forgetting **Apply**.

---

## Module 3 — Raise the Walls

### Final rule base after Module 3 (top → bottom)

**MARKET**

| # | Action | Source → Destination : Port | Log |
|---|---|---|---|
| M1 | Pass | `NET_MARKET` → This Firewall : 53 (TCP/UDP) | – |
| M2 | Pass | `NET_MARKET` → This Firewall (ICMP echo) | – |
| M3 | Pass | `H_WEB01` → *not* `NET_REALM` : `P_WEB` | – |
| M4 | **Block** | `NET_MARKET` → `NET_REALM` : any | ✔ |

**CITADEL**

| # | Action | Source → Destination : Port | Log |
|---|---|---|---|
| C1 | Pass | `NET_CITADEL` → This Firewall : `P_FW_ADMIN` (22, 443) | – |
| C2 | Pass | `NET_CITADEL` → This Firewall : 53 | – |
| C3 | Pass | `NET_CITADEL` → any (ICMP echo) | – |
| C4 | Pass | `H_ADM01` → `H_WEB01` : `P_ADMIN_ACCESS` (22, 8080) | – |
| C5 | Pass | `NET_CITADEL` → *not* `NET_REALM` : `P_WEB` | – |
| C6 | Pass | `NET_CITADEL` → *not* `NET_REALM` : 123/UDP | – |
| C7 | **Block** | `NET_CITADEL` → `NET_REALM` : any | ✔ |

**GARRISON**

| # | Action | Source → Destination : Port | Log |
|---|---|---|---|
| G1 | Pass | `NET_GARRISON` → This Firewall : 53 | – |
| G2 | Pass | `NET_GARRISON` → any (ICMP echo) | – |
| G3 | Pass | `NET_GARRISON` → `H_WEB01` : `P_WEB` | – |
| G4 | **Block** | `NET_GARRISON` → `NET_REALM` : any | ✔ |
| G5 | Pass | `NET_GARRISON` → *not* `NET_REALM` : `P_WEB` | – |
| G6 | Pass | `NET_GARRISON` → *not* `NET_REALM` : 123/UDP | – |

*(Module 6 inserts the jump-host rule between G3 and G4. Module 7 changes M3's destination. Module 8 inserts the logging rule above M4.)*

### Expected `policy` matrix

All rows PASS. For reference, the expected *results* are: from **WEB01**, only DNS to the firewall, WATCHTOWER web `:80`, internet HTTPS `:443` and the Ubuntu mirror are OPEN; everything else is DROPPED. From **ADM01**, firewall GUI/DNS, WEB01 `:22`/`:8080`, WATCHTOWER web and internet HTTPS are OPEN. From **WKS01**, firewall DNS and GUI, WEB01 `:80`/`:443`, WATCHTOWER web and internet HTTPS are OPEN.

After Module 3, `attack-sim.sh` should show **1 success** — *Exfil over HTTPS to attacker (WATCHTOWER :443)*. M3 still lets WEB01 reach *any* outside web server. That's the loose end Module 7 closes. (If you see more than one, a rule is too loose.)

### Common failures

| Symptom | Cause |
|---|---|
| WEB01 → ADM01 still OPEN | The `TEMP flat realm` rule on MARKET or CITADEL wasn't deleted, or Apply wasn't clicked |
| Everything from WKS01 DROPPED, including the firewall DNS | You deleted the default-allow rules before adding G1–G6 and the new rules aren't applied |
| WKS01 can't reach WEB01 `:80` | G4 is *above* G3 (see Part E) |
| `Ubuntu package mirror` row fails | M3's *Invert* is missing, or DNS (M1) isn't passing |
| `WATCHTOWER :4444` FAIL in `flat` mode | The `python3 -m http.server 4444` listener isn't running on WATCHTOWER |

### Check yourself

1. Because the realm is a block (`10.20.0.0/16`), one rule covers every internal host, including ones you add later. Listing hosts would need updating forever and would leave new hosts un-blocked by accident.
2. It hits the implicit **default deny** at the end and is dropped (and recorded in the log as the default-deny rule).
3. `any` would allow WEB01 to reach inside the realm too — M3 would pass traffic to ADM01 and WKS01 *before* M4 could block it. *Invert* ("not the realm") expresses "the outside only".
4. Intentional. The default deny *would* block it, but G4 is explicit documentation of intent, and — more usefully — *logging* G4 gives you a named, searchable record ("Users may not roam the realm") of every attempt, where the default-deny log line is anonymous.
5. **Need 6** — the public reaching the Marketplace. Module 4 adds it.

---

## Module 4 — Open the Gate

**Expected results**

- `curl -sI http://10.10.10.5/ | head -1` → `HTTP/1.1 200 OK`
- The ports probe: `22 closed/filtered`, `8080 closed/filtered`
- nginx's access log client address: **`10.10.10.30`**
- States: a line like `10.10.10.30:xxxxx → 10.10.10.5:80 (10.20.20.10:80)` — the parenthesised address is the translation.

**Check yourself**

1. The **destination NAT rule** (rewrites the destination) and the **WAN filter rule** (permits the traffic). The *filter rule* permits; NAT only translates.
2. Only 80 and 443 were published. A packet to 10.10.10.5:8080 matches no NAT rule and no WAN pass rule, so it hits the default deny. (nginx is listening — but it never sees the packet.)
3. `10.10.10.30`, WATCHTOWER's real address. Inbound destination NAT doesn't change the source. As a defender that means your web logs, rate limits and blocklists use real client addresses.
4. Anyone on the internet can then attack SSH on the DMZ server directly, and a successful break-in has the Module 1 blast radius all over again. The right answer is "use the jump host / VPN, not a public port".

*"Associated filter rule" missing?* If the WAN page has no rule for WEB01, edit the NAT rule and set **Filter rule association** to *Add associated filter rule* (or write the WAN pass rule yourself: TCP, source any, destination `H_WEB01`, ports `P_WEB`).

---

## Module 5 — Prove the Walls

### Part B — the log line

A blocked Garrison→Citadel probe looks like: interface `GARRISON`, source `10.20.10.x`, destination `10.20.30.10`, port `22`, action `block`, label *Users may not roam the realm*. The (i) icon shows the rule. A **default-deny** line carries a generic label instead — one reason to write good descriptions and to log your blocks.

### Part C — the state

`tcp  10.20.30.10:xxxxx → 10.20.20.10:22  ESTABLISHED:ESTABLISHED` (source, destination, state). It exists because C4 allowed the first packet; reply packets match the state, so no reverse rule is needed.

### Part D — Block versus Reject

| | Block (drop) | Reject |
|---|---|---|
| What Wireshark shows | The first SYN, then **retransmitted SYNs** (typically a few, spaced out roughly 1 s, 2 s, ...) and **no reply** | **One** SYN, then an immediate **RST, ACK** |
| Time to failure | Several seconds (`Test-NetConnection` can take ~20 s to report) | Instant |
| What a user sees | A hang, then a timeout | An immediate "connection refused" |
| What an attacker learns | Nothing — can't tell "filtered" from "no such host" | That a firewall (or closed port) answered |

*Block* is the right default toward untrusted sides; *Reject* is friendlier for internal users who mistype an address.

### Part F — the "too loose" experiment

Adding `Pass any NET_MARKET → any` above M4 makes every "expected Denied" row from WEB01 fail with *OPEN* (the Citadel, the Garrison canary, FTP and 4444, and so on). Deleting it restores all PASS.

### Check yourself

1. The *rule* that made the decision, the *interface* it was seen on, and a timestamp. The client only learns "failed".
2. Block: multiple SYNs, silence, long wait. Reject: one SYN, one RST, instant. A user sees a *hang* versus *"connection refused"*.
3. Block gives a scanner no information and slows it; the DMZ and WAN are where scanners live. Internal users benefit from fast failure, and the Garrison is lower-risk.
4. The IDS sits where it can see packets as they arrive (before the rule base discards them), so it can alert on traffic the firewall *blocked* — a different, complementary layer.

---

## Module 6 — Guard the Gatehouse

### What changes

| Setting | Before | After |
|---|---|---|
| Web GUI listen interfaces | all | **CITADEL** only |
| Anti-lockout | on | **disabled** |
| New rule | – | GARRISON, above G4: Pass TCP `H_WKS01` → `H_ADM01` : 22, **logged** |
| Secure Shell | off | on, **CITADEL** only, no root login, no password login |
| New account | – | `gatekeeper-admin`, in **admins**, key-only |

Rule order on GARRISON is now: **G1, G2, G3, (jump host), G4, G5, G6**.

### Expected `mgmt` differences from `policy`

| Row | `policy` | `mgmt` |
|---|---|---|
| From WKS01: *Firewall web GUI from the Garrison* | OPEN | **Denied** |
| From WKS01: *ADM01 SSH (Citadel) - admin jump host* | Denied | **OPEN** |

Everything else is identical.

### Check yourself

1. The hidden anti-lockout rule always lets the Garrison reach the GUI and SSH, so a rule mistake can't lock you out. It also *keeps the Garrison able to reach the firewall* — exactly what Module 6 forbids. Disable it only after you've proven another path works (the tunnel), or you cut your own branch.
2. One narrow, logged, monitored door instead of every admin PC being a path to the firewall. You harden and watch one machine, not many. Combined with key-only SSH and the management zone, an attacker needs to compromise the jump host *as well*.
3. They'd first have to compromise the admin workstation (`H_WKS01`) specifically, then authenticate to the jump host (ADM01), then authenticate to the firewall — with the whole chain logged. Other Garrison machines can't even reach ADM01.
4. Passwords can be guessed or reused; keys are long and can't be brute-forced over the network. Root is the one account name every attacker knows exists, so never allow it to log in directly: use a named account and elevate afterward (and the log shows *who* did what).

*Can't find your way back after a mistake?* See **Recovery** at the end of Module 6, and **Troubleshooting → "Locked out of the firewall"**.

---

## Module 7 — Close the Roads

### Expected outcomes

| Test | Result |
|---|---|
| `sudo apt-get update` on WEB01 | succeeds (or, rarely, needs a mirror added to the alias) |
| `curl -sI --max-time 5 https://example.com` on WEB01 | **fails** (timeout) |
| WEB01 → WATCHTOWER `:4444` | **blocked** |
| `nslookup example.com` on WKS01 | answers |
| `nslookup example.org` on WKS01 | blocked (0.0.0.0 / NXDOMAIN) |
| `nslookup example.org 8.8.8.8` on WKS01 | **times out** |
| `attack-sim.sh` on WEB01 | **0 successes** |

### Expected `hardened` differences from `mgmt`

Only from **WEB01**: *WATCHTOWER web `:80`* and *Public internet HTTPS `:443`* change from OPEN to **Denied**. (The Ubuntu mirror row stays OPEN.)

### Check yourself

1. Because inbound controls decide who can *get in*, but outbound controls decide whether a compromise can *do anything*: malware that can't reach its controller, download tools, or send data out is largely stuck. Egress is also where compromised *internal* machines reveal themselves.
2. A web server's genuine need is its repositories; "anything on 80/443" lets an attacker use any website as a command channel. With hostname aliases, the firewall resolves names to addresses periodically — mirrors with many changing addresses can occasionally be missed, causing intermittent failures (or a stale allow if an address is reused).
3. `nslookup example.org 8.8.8.8` was stopped by the **default-deny rule base** (G1 only allows DNS to *This Firewall*). `nslookup example.org` was stopped by the **Unbound blocklist**.
4. Examples: **DNS** to the firewall's own resolver (DNS tunnelling to an attacker-controlled domain, which the resolver will happily relay); the **logging hole** (UDP 514 to ADM01, abusing a trusted path); **HTTPS to an allowed repository** (large uploads disguised as updates, if you can find a writable one); and **the Garrison and Citadel** — which still reach arbitrary internet web servers. (WEB01 itself is now limited to the mirrors.)

---

## Module 8 — The Siege

### Part A — logging

`/var/log/remote/10.20.30.1.log` holds the firewall's messages; filter-log lines are comma-separated records that include the rule number, interface, action (`block`/`pass`), protocol, and the source/destination addresses and ports. `/var/log/remote/10.20.20.10.log` holds WEB01's messages.

**The logging hole's risk.** A compromised WEB01 can now send UDP to ADM01:514. Impact: it could flood the collector, or try to exploit the syslog service. Mitigations: UDP 514 is a one-way fire-and-forget channel; use TLS-wrapped syslog or an agent pull; rate-limit; keep ADM01's receiver hardened and monitored. It's a deliberate, narrow, **documented** exception — exactly the kind that belongs in the "residual risk" section of a report.

### Part B — the IDS

Expect alerts whose signatures start `ET SCAN` (for example an *nmap SYN scan* signature), source `10.20.20.10`, destinations including `10.20.10.1`, `10.20.30.10`, and `10.20.30.1`. Those are TCP SYN scans from a DMZ host to internal addresses — which the firewall *blocked*. The IDS recorded the *attempt*.

### Part C — expected evidence table (hardened state)

| Raider action | Outcome | Rule that stopped it |
|---|---|---|
| Garrison workstation `:22 :80 :445 :3389 :8080` | blocked | **M4** — *A compromised DMZ host must not reach inside* |
| Citadel `:22 :80 :8080` | blocked | **M4** |
| Garrison gateway `:80 :443 :22` | blocked | **M4** |
| Firewall GUI via Market / Citadel / Garrison addresses | blocked | **M4** |
| Citadel SSH | blocked | **M4** |
| C2 `:4444`, HTTPS `:443`, FTP `:21` to WATCHTOWER | blocked | **default deny** (M3 now allows only the package mirrors) |
| DNS to `8.8.8.8` | blocked | **default deny** (only the firewall's DNS is allowed — M1) |
| nmap scan | blocked, **and alerted** | **M4** (+ IDS `ET SCAN` alerts) |

Note that the *intended* rule isn't always M4: traffic to non-realm destinations that the rules don't allow falls through to **default deny**, whose log line has no custom description. That's why some teams add an explicit final *Block + Log* rule per interface.

### What a smarter raider might do next (Part C, step 6)

Any two of: **DNS tunnelling** through the firewall's resolver; **abusing the syslog hole** to flood or exploit ADM01; **slow data theft over HTTPS** to a mirror or CDN that's allowed; **waiting for the FQDN alias to resolve a shared hosting IP**; **moving "sideways" inside the Market** (traffic within a zone never crosses the firewall); **attacking WEB01's own services** (the firewall can't see inside an allowed HTTP request).

### Report — what a good "residual risk" section contains

At least four items such as: Garrison→Citadel jump-host exception; WEB01→ADM01 logging exception; DNS tunnelling/DoH; FQDN-alias fragility; **single firewall** (a failure takes the whole realm offline); **intra-zone traffic is uninspected**; UDP and IPv6 aren't covered by the tests; the IDS only **alerts**; self-signed certificates; shared lab passwords. For each: *likelihood × impact* and a mitigation.

### Check yourself

1. The **firewall log** told you *exactly which rule* decided and gave exact addresses and ports, but only for traffic that crossed a rule; the **IDS** told you the *behaviour* (a scan) and recognised a pattern across many packets. The firewall missed the *meaning*; the IDS missed *which of your rules* was responsible and didn't stop anything.
2. A compromised system's first move is to cover its tracks. Logs held elsewhere — in a more-trusted zone the attacker can't reach — survive the machine they describe, and let you reconstruct what happened even after the source was wiped.
3. Examples: the jump-host exception becoming a proper PAW; real certificates; TLS syslog; a pair of firewalls (HA); no shared passwords; IPS mode; narrowing Garrison egress through a proxy; per-host rules rather than per-subnet. *Why accepted:* cost/complexity in a single-host lab; the goal was to learn the control, not run production.
4. "A firewall enforces *where* and *which port*; an IDS watches *what the traffic is doing*. Attacks use allowed ports — the firewall passes them, and only detection will notice."

---

## Part E — the audit exercise

| # | What's wrong | Fix |
|---|---|---|
| **R1** | `Pass any → any` on the **WAN** exposes everything behind it; "temp" with no expiry becomes permanent; no logging | Delete it. Replace with the *specific* vendor host, port and a documented end date; log it. Use a VPN rather than open inbound access. |
| **R2** | The DMZ may reach **anything** on any protocol — the Module 1 blast radius. "Web updates" is described but the rule permits far more | Replace with `H_WEB01` → package mirrors on 80/443, then a logged *Block* to the realm (Modules 3 and 7) |
| **R3** | The Garrison can reach the *entire* Citadel on **all** TCP ports for "finance needs it" — vague business reason, no host or port scoping | Identify the *exact* host and port finance uses, allow only that, log it, and give it an owner and review date |
| **R4** | The **admin panel** (8080) is published to the entire internet "for a contractor" — an admin interface on the public side | Remove. Give the contractor a VPN or the jump-host path, with their own account and an expiry |
| **R5** | The management zone may reach anything, from anywhere (`any → any`), with a blank description — nobody knows why it exists | Delete; build scoped rules (C1–C7 style). **Every rule needs a description.** |
| **R6** | The **block is below the pass** — rules are first-match, so the block can never fire; users can reach the Citadel | Move the block *above* the broad pass (or narrow the pass), and add logging |
| **R7** | `UDP any → any:53` from the DMZ lets it use **any resolver**, defeating the firewall's DNS control and enabling DNS exfiltration/tunnelling | Allow DNS **only** to `This Firewall` |
| **R8** | Logging is off on blocks (no evidence of attacks) and **25 disabled, undocumented rules** are clutter that hides real ones and may be re-enabled by mistake | Turn on logging for blocks, delete dead rules (keep a config backup), require descriptions, and review the rule base on a schedule |

A strong answer to the whole table notices a pattern: **vague scope** (any/any), **no owner or expiry**, **no description**, **wrong order**, and **no logging** — the same five failure modes behind most real-world firewall findings.

---

## Final state — quick reference

**Rule counts at the end:** MARKET 5 (M1, M2, M3 *repos only*, the logging rule, M4), CITADEL 7, GARRISON 7 (including the jump-host rule). WAN: two automatic pass rules created by the destination-NAT entries.

**Expected `hardened` matrix:** all PASS on WEB01, ADM01 and WKS01.
**Expected `attack-sim.sh`:** 0 of 19 succeed, with nmap alerts in the IDS.
