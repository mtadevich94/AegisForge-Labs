# Audit Checklist

Use this to **cross-reference your own work**. It is a list of things to look for, not a sequence of steps. Each category says *what to check*, *why it matters*, and *where to look*. The hints show you where to look. They don't tell you which lines are wrong.

**How to use it:** read the [Intended Policy](Intended%20Policy.md) first, then work down the categories. Note the **handle** of every suspect rule. Skip what doesn't apply, and say so in your report.

---

## How to read a rule

Every rule is one line, read left to right: **match** the packet, **count** it, then give a **verdict**.

```
iifname "garrison" oifname "wan" tcp dport { 80, 443 } counter packets 1920331 bytes 115219860 accept comment "web browsing" # handle 62
└──── where it came from / is going ───┘ └─ protocol & port ─┘ └────── the hit counter ──────┘ └verdict┘ └─ the note ─┘ └ permanent ID ┘
```

| Word | Meaning |
|---|---|
| `iifname` / `oifname` | The zone the packet arrives from / leaves to |
| `ip saddr` / `ip daddr` | Source / destination address. No `saddr` or `daddr` means **any** |
| `tcp dport` / `udp dport` | Destination port. No port means **any port** |
| `accept` / `drop` | Let it through / silently discard it |
| `log prefix "..."` | Write a log line before the verdict |
| `ct state established,related` | A **reply** to a connection that is already allowed |
| `policy drop` | The chain's default: anything no rule matched is dropped |
| `# handle N` | The rule's permanent ID. It is **not** its position |

**Three chains matter.** `input` = traffic *to* the firewall itself. `forward` = traffic *through* the firewall between zones. The NAT table rewrites addresses before or after that. Rules are checked **top to bottom, and the first match wins.**

## Handy commands

On Linux (or WSL, or Git Bash):

```bash
grep -n '# handle' gatekeeper-ledger.nft                       # every rule with its line number (= its order within a chain)
grep 'counter packets 0 ' gatekeeper-ledger.nft                # rules that never matched in 91 days
grep '# handle' gatekeeper-ledger.nft | grep -v dport | grep accept   # accept rules that name no port at all (any port)
awk '/counter packets/ {match($0,/packets [0-9]+/); p=substr($0,RSTART+8,RLENGTH-8); match($0,/# handle [0-9]+/); h=substr($0,RSTART+9,RLENGTH-9); print p, h}' gatekeeper-ledger.nft | sort -rn | head
                                                                # busiest rules first: "packets handle"
nft -c -f gatekeeper-ledger.nft                                # check the syntax only; changes nothing
```

On Windows PowerShell:

```powershell
Select-String -Path .\gatekeeper-ledger.nft -Pattern 'counter packets 0 '
Select-String -Path .\gatekeeper-ledger.nft -Pattern '# handle' | Select-Object LineNumber, Line
```

---

## A. Default posture

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Is the default really "deny"?** Look at each chain's `policy`, *and* at the last rules before it | A `policy drop` can be quietly cancelled by a broad `accept` just above it | The `policy` on each chain; every rule near the bottom of `forward` |
| ☐ | **Do replies and broken packets get handled first?** | Without an `established` rule at the top, every reply needs its own rule. Without an `invalid` drop, malformed packets reach your rules | The first two rules of each chain |

## B. Order and shadowing

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Shadowed rules:** is there a rule that an earlier, broader rule makes unreachable? | A shadowed rule *looks* like protection but never runs. A block placed *after* the allow it was meant to override does nothing | Pick a rule, then read upward: does an earlier rule match everything this one matches? |
| ☐ | **Allow-then-deny order:** are any deny rules below an allow that covers the same traffic? | First match wins. A block list has to come *before* the allow | Rules with the same `iifname`/`oifname` pair, in file order |
| ☐ | **Zero hits caused by shadowing vs. zero hits caused by nobody using it** | They look identical in the counters and need opposite fixes. One means "fix the order", the other means "remove the rule" | Cross-check each zero-hit rule against the rules above it |

## C. Rules that are too broad

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Any source, any destination, any port:** rules that name no address or no port | Least privilege means the narrowest rule that does the job | Rules with only `iifname`/`oifname`; rules with a `/16` or `/24` where one host would do |
| ☐ | **Whole-zone trust:** "this zone is trusted, allow everything" | Trust is earned per flow, not per zone. One compromised host inherits all of it | Rules that match a zone with no port |
| ☐ | **Admin protocols to many hosts:** SSH, RDP and SMB offered to a whole network | Remote-admin ports are the ones attackers use to move around | Port numbers 22, 445, 3389 |

## D. Hit counters

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Rules with zero hits.** Why zero? Shadowed, unused, or rarely-needed? | Zero hits is a question, not an answer. Delete blindly and you remove the rule that was supposed to be doing the job | The `grep` for `packets 0` above |
| ☐ | **The busiest rules.** Are they the ones you'd expect? | A rule with a huge count is *used*, not *right*. Attackers use bad rules too | The `awk` command above |
| ☐ | **What do the hits on a bad rule tell you?** | A broad rule's hits are a list of real connections the approved policy never covered. That is your work list before you remove it | The catch-all rules near the bottom |
| ☐ | **Seasonal or emergency rules** | A rule for disaster recovery or a quarterly job may show zero for 91 days and still be needed | Ask the owner, or the comment |

## E. Egress (traffic leaving a zone)

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Can the DMZ reach the whole internet?** | A compromised public server that can call home to anywhere is a command-and-control channel. Servers should reach only what they need | Rules from `market` to `wan` |
| ☐ | **Can management reach the whole internet?** | Same risk, from the most trusted zone | Rules from `citadel` to `wan` |
| ☐ | **Cleartext protocols leaving the network** (FTP, Telnet, SMTP) | Credentials and data cross the internet readable | Ports 21, 23, 25 |
| ☐ | **DNS:** can clients use any resolver? | If everything must use the firewall's resolver you can log, filter and block it. Direct DNS to the internet bypasses all of that | Port 53 in `forward`, versus the policy |

## F. The management plane (the `input` chain)

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Who can manage the firewall?** Compare with the policy | The firewall guards everything. Whoever controls it controls the Realm | `input` rules with SSH (22), the GUI (443), or SNMP (161) |
| ☐ | **Management open to the outside?** | The internet scans for these ports constantly | Any `input` rule that names no source, or `wan` |
| ☐ | **Monitoring protocols:** SNMP versions and community strings | SNMP v1/v2c send a shared secret in the clear. A guessable community string is a read (or write) window into the device | UDP 161 |
| ☐ | **Rules that make a stricter rule meaningless** | A tight "only ADM01" rule means nothing if a looser one sits just below it | Compare neighbouring `input` rules for the same port |

## G. Stale and temporary rules

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Expired "TEMP" rules.** Compare the date in the comment with the export date (2026-09-30) | A temporary rule with no expiry check becomes a permanent hole. Dates in the past are findings | `comment` text |
| ☐ | **Ended contracts and departed people** | Access given to a vendor or contractor must end when they do | Words like vendor, contractor, old |
| ☐ | **Hosts that don't exist.** Compare every address with the policy's host list | A rule for a decommissioned host becomes a hole if the address is reused | Addresses that appear nowhere in the policy |
| ☐ | **Unused objects:** sets or definitions nothing refers to | They mislead the next reader into thinking something is being enforced | `set` blocks, then search for each name |

## H. Duplicates and redundancy

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **The same rule written twice,** or once as a literal and once as a set | Rule bases bloat and nobody dares delete anything | Compare matches line by line, including the NAT table |
| ☐ | **Rules that are subsets of earlier rules** | They add noise and hide real mistakes | Port 80 after `{ 80, 443 }` |

## I. Logging and accountability

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Is the final deny logged?** In every chain? | Denied connections are your evidence of probing and of misconfiguration. No log means no evidence | The last rule of each chain |
| ☐ | **Are exceptions logged?** | The policy demands it for EX-004 | The rule for that exception |
| ☐ | **Does every rule say who asked and why?** | A rule with no owner can never be removed safely | `comment` text |

## J. Intent vs. reality

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Map every rule to a flow ID** (P-01 to P-09, EX-004) | Rules that map to nothing are suspects. Flows that map to no rule may be broken | Your inventory from step 2 |
| ☐ | **Direction:** does traffic flow the way the policy says? | "Administration flows *inward*" is a rule. A DMZ host initiating into the management zone breaks the trust model | `iifname`/`oifname` order |
| ☐ | **DMZ isolation:** can the DMZ start connections into the inside? | A compromised DMZ host must not be a stepping stone | Rules from `market` to `garrison` or `citadel` |
| ☐ | **The policy is silent:** a flow looks harmless but isn't approved | You decide, then document it. Neither "delete everything not listed" nor "leave it" is automatically right | Flows with a plausible purpose and no flow ID |

## K. NAT and publishing

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Every published port needs a matching allow rule, and the reverse** | A NAT entry with no allow rule is dead. An allow rule with no NAT entry is dead. Both are clutter, and either can become live later | `table ip realm_nat` against `forward` |
| ☐ | **What did the NAT table publish?** Compare with P-01 | NAT rules expose services to the outside. Admin services should never appear here | The `dnat to` lines |
| ☐ | **Port numbers can hide a service.** Port 2222 → 22 is still SSH | Moving a port is obscurity, not protection | Destination port vs. translated port |

## L. What is missing

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Anti-spoofing:** does the firewall drop outside packets that claim to come from inside? | Spoofed internal addresses bypass rules that trust internal sources | A rule on `wan` with your internal ranges as the source |
| ☐ | **Rate limiting:** is anything unbounded that could be flooded? | ICMP and other cheap protocols can be used to degrade the firewall | The `icmp` rules |
| ☐ | **A change record:** ticket, owner, expiry on every non-baseline rule | Without it the next audit repeats this one | Comments |
| ☐ | **Anything else a hardened firewall has that this one lacks** | The best findings are the ones the ruleset can't show you | Your own experience |

---

*Remember:* you are auditing a ruleset, not blaming the people who wrote it. Every one of these rules once had a reason. Your job is to find which reasons have expired.
