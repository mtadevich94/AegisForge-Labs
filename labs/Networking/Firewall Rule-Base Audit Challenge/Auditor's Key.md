# Auditor's Key

**Open this after you've written your own findings.** Auditing is a judgment skill. If you read this first, you'll learn what the answers were and not how to find them.

Handles refer to `# handle N` in `gatekeeper-ledger.nft`. Rules are listed by *handle*; their order in the file is the evaluation order. The reference clean-up is `gatekeeper-ledger-cleaned.nft`.

You don't need to match this list exactly. If you found something not listed, and can defend it, it's a good finding. The list below is what the Ledger was built to contain.

---

## Quick scorecard

| | Count |
|---|---|
| Rules in the Ledger (all chains, with handles) | 54 |
| Distinct findings planted | 26 |
| Rules with zero hits | 12 |
| Of those: dead because an earlier rule steals the traffic | 7 (41, 33, 60, 61, 71, 99, 212) |
| Of those: simply unused | 5 (42, 202, 96, 97, 98) |
| Rules in the reference clean-up | 24 (it *adds* anti-spoofing and rate limiting) |

## Findings

### Critical: fix first

| # | Handle(s) | Cat. | What's wrong | Why it matters | Fix |
|---|---|---|---|---|---|
| 1 | **102** | A, G, C | A "temporary migration window" rule accepts **everything from `10.20.0.0/16`**. Expired 2025-04-15. It sits directly above the default deny, so for internal sources there *is* no default deny | The whole policy is cancelled for every internal source. The 98,333 hits are real connections no approved rule covers | **Log first, then remove.** Keep the rule accepting but add `log prefix "mig-window "` so every connection through it is recorded. Read the log for a week, turn every real flow into an approved rule or a fix, then delete the rule |
| 2 | **90**, NAT **203** | K, G, F | RDP from `wan` straight to WKS01, published by NAT. "DELETE after 2024-12" | An admin protocol reachable from the outside. 5,531 new connections: that's brute-forcing | Remove both. If a contractor still needs it, give them a VPN to ADM01, not a published port |
| 3 | **16** | F, G | SSH to the firewall from **anywhere**. "Remove by 2025-02-01" | The firewall's own admin port is open to every zone including `wan`. 41,207 hits. It also makes the tight rule above it (**15**) meaningless | Remove. Only ADM01 (P-07) |
| 4 | **91**, NAT **204** | K, J | SSH to ADM01 from `wan`, published on port 2222 | The management zone has an outside entry point. A moved port is obscurity, not control | Remove both |

### High

| # | Handle(s) | Cat. | What's wrong | Why it matters | Fix |
|---|---|---|---|---|---|
| 5 | **17** | F | Firewall GUI (443) open from `wan` "for vendor support" | Same exposure as 3 | Remove. A vendor works through ADM01 or a temporary, expiring rule |
| 6 | **18** | F | SNMP from anywhere, community string `public` | A guessable shared secret and a read window into the device | Remove, or restrict to the monitoring host and move to SNMPv3 |
| 7 | **55** (shadows **60**, **61**) | C, B | Garrison → Market: *everything*, "while debugging" | Workstations can reach every port on the DMZ. The two correct rules below it (60 allow, 61 logged deny) can never run | Remove 55. Keep 60 (it's P-03). 61 becomes redundant once the final deny logs |
| 8 | **73** | J | WEB01 → Garrison, SMB (445) | A DMZ host starting connections into the inside. A compromised web server becomes a stepping stone. 12 hits means someone used it | Remove. Find who relied on it, and give them a push-from-inside alternative |
| 9 | **74** | J | WEB01 → ADM01 SSH, "for deploys" | **Wrong direction.** Administration flows inward (P-05). 3 hits | Remove. Deploys are pushed from ADM01 (rule 80) |
| 10 | **70** (shadows **71**) | E, B | The DMZ may reach the entire internet. The correct rule below it, **71** (repo mirrors only), has zero hits because 70 steals everything | No egress control on the most exposed zone: a free command-and-control channel | **Remove 70, keep 71.** The zero-hit rule is the *right* one |
| 11 | **67** | C, J | Garrison → the whole Citadel on 22, 445 and 3389 | Any workstation can reach any management host over admin protocols. Makes the logged exception EX-004 (**66**) pointless | Remove. Keep 66 (the one approved path) |
| 12 | **96**, **99** | G, C, H | Any-service accept from the old vendor network `198.51.100.0/24`, written twice (a literal and a set). Contract ended. Zero hits | A dormant any/any trust. Zero hits means nobody has tried yet, not that it's safe | Remove both and the set |

### Medium

| # | Handle(s) | Cat. | What's wrong | Why it matters | Fix |
|---|---|---|---|---|---|
| 13 | **82** | E, G | Citadel may reach the whole internet. "Expires 2025-03-01" | Expired, and the management zone is the last place that should have unrestricted egress. Rule **81** already does ADM01 updates | Remove 82 |
| 14 | **83** | J, C | Citadel → Garrison, everything | The policy says no flow from Citadel to Garrison. 22 hits means an admin uses it | Decide: remove, or define a narrow admin flow (a *decision*; see below) |
| 15 | **63**, **64** | E, J | DNS (TCP and UDP) to any resolver | Clients can bypass the firewall's resolver, so you can't log or block DNS. Also a classic exfiltration route | Remove. Everyone uses the firewall (P-08). Check the clients get the firewall as their DNS server via DHCP first |
| 16 | **65** | E | FTP, Telnet and SMTP leave the network. 312 hits | Cleartext credentials crossing the internet | Find who is using it *before* removing. The hits are your list of people to talk to |
| 17 | **19** | C, F | The firewall trusts the whole Citadel zone on all ports | "Trusted zone" is not a flow. It makes 15 redundant | Remove. 15 already covers ADM01 |
| 18 | **110** | I | The final `forward` deny isn't logged (the `input` one is) | Blocked connections leave no evidence. The Gatehouse lab's Module 5 is about exactly this | Add `log prefix "fw-fwd-drop "` |
| 19 | **33** | B | A block list for a scanner range sits **after** the allow it was meant to override. Zero hits, while the SOC says the scans continue | The control the SOC asked for does nothing | Either move it above rule 40, or remove it. Blocking one /24 from scanning a public web server is low value, so *removing it and noting why* is a defensible answer |
| 20 | *(missing)* | L | **No anti-spoofing.** Nothing drops `wan` packets claiming to come from `10.20.0.0/16` | Spoofed internal sources bypass any rule that trusts "internal" | Add a drop on `wan` with the internal range as source, in `input` and `forward` |

### Low

| # | Handle(s) | Cat. | What's wrong | Fix |
|---|---|---|---|---|
| 21 | **9** | L | ICMP echo from internal zones isn't rate-limited | Add a `limit rate` |
| 22 | **93** | C | Ping between any internal addresses | Remove, or restrict to ADM01. Not in the policy |
| 23 | **41** | H, B | Duplicate of 40 for port 80 only. Zero hits | Remove |
| 24 | **42**, NAT **202** | G, D, K | Staging site on port 8080 (CHG-0140). Zero hits on both. The allow rule and the NAT entry agree, so it *would* work if anything listened | Remove both |
| 25 | **97**, **98** | G, D | Rules for `10.20.20.50` ("old-web02"). That host isn't in the policy. Zero hits | Remove. If the address is ever reused, these rules open it |
| 26 | NAT **212**, set `bad_reputation` | H, G | A second masquerade rule that the first one already covers (zero hits). A set defined and never used | Remove both |

### Decisions: the policy is silent, and either answer is defensible

| Handle | Flow | Reasons to keep | Reasons to remove | What the reference does |
|---|---|---|---|---|
| **72** | WEB01 → ADM01, UDP 514 (logs) | 55,210 uses. Central logging is a good thing. It's narrow (one host, one port) | It's a DMZ → management flow, and the policy doesn't list it | **Keeps** it, documented as A-01. Rule: the flow is narrow and valuable, but it must be written down |
| **100** | Garrison → anywhere, NTP | Clocks need to be right. 1,022 uses | P-08 says time comes from the firewall | **Removes** it. NTP now goes to the firewall (P-08) |
| **83** | Citadel → Garrison, any | Admins sometimes need to reach workstations | The policy says no, and "any" is far too wide | **Removes** it. If the need is real, add a narrow flow to the policy |
| **81** | ADM01 updates | The policy covers it (P-06) | It names the zone, not the host | **Narrowed** to ADM01's address |

### Rules that are fine. Do not "fix" them

4, 5, 6 (baseline), 11, 12, 13 (resolver and DHCP), **15** (ADM01 manages FW01), **22** (logged default deny, `input`), **30**, **31**, **40**, **62**, **66** (the logged exception), **80**, **81** (but narrow it), NAT **201** and **211**. Hitting these as "findings" is a false positive. A good report says what it checked and found sound.

---

## Traps in the Ledger

| Trap | The lesson |
|---|---|
| **71 has zero hits and is the right rule** | Zero hits ≠ delete. Here the fix is to remove the rule *above* it |
| **16, 17, 18, 90, 91, 102 are busy rules** | Hit counts measure use, not legitimacy. Many of those hits are outside scanning and brute forcing |
| **Rule 15 looks like the control, but 16 undoes it** | Check every rule's neighbours, not just the rule itself |
| **42 and NAT 202 agree with each other** | Two rules that match each other aren't automatically right. Both can be stale |
| **99 duplicates 96 in a different notation** | The same rule written as a literal and as a set. A text search for the address finds only one |
| **61 is a good deny rule that never runs** | A correct rule can be a finding if it's unreachable |
| **Port 2222 → 22 (NAT 204)** | The translated port is what matters. A service on an odd port is still that service |

---

## A model change plan

Order by what an outsider can reach today, then what an insider can reach, then hygiene.

| Step | Change | Prove it worked | Prove nothing broke | Rollback |
|---|---|---|---|---|
| 0 | Back up the ruleset. Open a **second, independent** management session. Agree a change window | n/a | n/a | n/a |
| 1 | Remove 16, 17, 18, 90+NAT 203, 91+NAT 204 | From `wan`: SSH, GUI, SNMP, RDP and port 2222 all fail | From ADM01: SSH and the GUI still work (P-07). Web service (P-01) still works | Re-add the saved lines |
| 2 | Add anti-spoofing; log the final `forward` deny | A spoofed test packet is logged and dropped | Normal traffic unaffected | Remove the two lines |
| 3 | Add `log prefix "mig-window "` to 102 (it **still accepts**) and leave it that way for a week | The log fills with the flows nobody approved | Nothing is blocked yet, so nothing can break | Remove the `log` |
| 4 | Remove 96, 99, 97, 98, 42+NAT 202 and the unused objects | n/a (they had no hits) | Re-read the counters for the next week | Re-add |
| 5 | DMZ: remove 70, 73, 74; keep 71 | WEB01 can't reach arbitrary hosts, and can't start connections into other zones | `apt update` on WEB01 still works. ADM01 can still SSH in (80) | Re-add 70 temporarily |
| 6 | Garrison: remove 55, 67, 63+64, 100; investigate 65 first | Workstations can't reach the DMZ beyond 80/443, or the Citadel except WKS01 → ADM01 | Browsing and DNS work (DHCP gives the firewall as the resolver). Talk to the people in the 65 log before removing it | Re-add per rule |
| 7 | Citadel: remove 82, 83, 19; narrow 81 | ADM01 can only reach what P-05, P-06 and P-07 allow | Updates and administration still work | Re-add |
| 8 | Remove 102 for good, using what the log taught you | The final deny now catches the stray flows | Everything on the approved list still works. Chase any new log entries | Put the logging version of 102 back |
| 9 | Remove the duplicates and the unused set; add comments with a ticket, owner and expiry to everything that remains | A clean `nft -c` | n/a | n/a |

**Why log before removing 102.** Its 98,333 hits are real connections. Deleting it on day one would drop all of them at once. Logging first turns the hits into a list of what actually depends on the rule. (A bare `log` with no verdict would not keep traffic flowing: it logs and then falls through to the default deny. Keep the `accept`.)

## Before and after

| Measure | Before | After (reference) |
|---|---|---|
| Rules (all chains) | 54 | 24 |
| Accept rules that name no destination port (not counting replies and loopback) | 10 (9, 19, 55, 70, 82, 83, 93, 96, 99, 102) | 1 (rate-limited ICMP) |
| Zero-hit rules | 12 | n/a (new counters needed) |
| Admin services reachable from `wan` | 4 (firewall SSH, firewall GUI, RDP, ADM01 SSH) + SNMP | 0 |
| Expired temporary rules | 4 (16, 82, 90, 102) | 0 |
| Final deny logged in every chain | `input` only | both |
