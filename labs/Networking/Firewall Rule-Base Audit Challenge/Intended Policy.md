# Intended Policy: what the Council approved

This is the written policy the Realm's firewall is **supposed** to enforce. It is the "design intent" an auditor is handed before touching a ruleset. Your job in the audit is to compare what the Ledger **does** with what this page says it **should** do.

The addresses are the same as the Gatehouse lab. If you built that lab, you already know these zones.

> **Version:** Council-approved policy v2. **Status:** current. Anything the Ledger allows that is not on this page is either a documented exception (there is exactly one) or a finding.

## The zones

| Zone | Interface | Network | Who lives there | Trust |
|---|---|---|---|---|
| **WAN** (the Wilderness) | `wan` | `10.10.10.0/24` (FW01 is `10.10.10.5`) | The outside world | None |
| **GARRISON** | `garrison` | `10.20.10.0/24` | Workstations. WKS01 is `10.20.10.100` | Medium |
| **MARKET** (DMZ) | `market` | `10.20.20.0/24` | WEB01 `10.20.20.10`, the public web server | Low. Assume it will be attacked |
| **CITADEL** (management) | `citadel` | `10.20.30.0/24` | ADM01 `10.20.30.10`, the admin host and log collector | High. Reachable by almost nothing |

Hosts that exist: FW01, WEB01, ADM01, WKS01. **There is no other server in the Realm.** If a rule names a host that is not on this page, ask why.

## The approved flows

Everything not on this list is **denied**.

| ID | From → To | Allowed | Notes |
|---|---|---|---|
| **P-01** | WAN → WEB01 | TCP 80, 443 | Published through FW01's address `10.10.10.5` |
| **P-02** | GARRISON → WAN | TCP 80, 443 | Web browsing |
| **P-03** | GARRISON → WEB01 | TCP 80, 443 | Workstations use the web server |
| **P-04** | WEB01 → WAN | TCP 80, 443 to the **approved package mirrors only** | Updates for the DMZ. Nothing else leaves the DMZ |
| **P-05** | ADM01 → WEB01 | TCP 22 | Administration flows **inward**, from Citadel to Market |
| **P-06** | ADM01 → WAN | TCP 80, 443 | Updates for the admin host |
| **P-07** | ADM01 → FW01 | TCP 22, 443 | The **only** way to manage the firewall |
| **P-08** | GARRISON, MARKET, CITADEL → FW01 | DNS (TCP/UDP 53), DHCP (garrison only), NTP | **All** DNS goes through the firewall's resolver. No zone talks to an outside resolver directly |
| **P-09** | GARRISON, MARKET, CITADEL → FW01 | ICMP echo, rate limited | Troubleshooting |

### The one approved exception

| ID | From → To | Allowed | Conditions |
|---|---|---|---|
| **EX-004** | WKS01 (`10.20.10.100`) → ADM01 | TCP 22 | The jump host. Must be **logged**. Reviewed each quarter |

### Required of every rule

1. It maps to one approved flow above, or it is a **documented** exception with an ID.
2. A **temporary** rule says who asked, why, and **when it expires**. An expired rule is removed, not forgotten.
3. A rule names the narrowest source, destination and port that does the job.
4. Management of the firewall comes from ADM01 and nowhere else.
5. The final deny is **logged**, so a blocked connection leaves evidence.

### Things this policy deliberately says nothing about

The Council wrote down what it knew. It did not write down every flow someone may have added since. When the Ledger allows something this page does not mention and you can't tell whether it is harmless, **that is a decision for you to make and defend**, not an automatic delete. Say what you decided and why.
