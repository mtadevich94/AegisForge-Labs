# Firewall Audit Concepts

Read this before the Ledger. The **[Audit Checklist](Audit%20Checklist.md)** tells you *what to check*. This page explains *what each thing is and why auditors care*, using a small made-up ruleset that is **not** the Ledger. Nothing here gives away the Ledger's answers. It shows you the shapes to look for.

---

## Why firewall rules need auditing at all

A firewall's rule base is never finished. Each request adds a rule: a contractor needs in, a test needs everything open, a vendor needs a port. Rules are added quickly and removed almost never, because **nobody is sure what will break.** Over the years the rule base stops matching what anyone intended. This is called **rule rot**.

A rule audit asks one question: **does the firewall still do what the organization approved?** To answer it you need two things: the approved intent (a written policy) and the actual rules. The gap between the two is the finding.

Audits are also a **requirement** in many places. PCI DSS, for example, requires network security controls to be reviewed on a regular schedule (check Requirement 1 in the current version for the exact interval and wording). NIST's firewall guidance (SP 800-41) covers rule-set review and change management too. If you work near regulated data, this is a job you will be asked to do.

## The toy ruleset

Every example below uses this one. Read it top to bottom. **The first rule that matches a packet decides what happens, and the rest are never looked at.**

```
policy drop                                   <- anything no rule matches is dropped
1  ct state established,related accept       <- replies to allowed connections
2  lan -> wan   any port              accept  <- "A: lan can go anywhere"
3  lan -> wan   tcp 443               accept  <- "B: lan web"
4  lan -> wan   tcp 23                drop    <- "C: no telnet"
5  dmz -> lan   from 10.9.9.5, tcp 445 accept <- "D: one dmz host to the file share"
6  dmz -> lan   tcp 445               accept  <- "E: any dmz host to the file share"
```

(The real nftables version passes `nft -c`. The Ledger is written the same way, so you can read both.)

---

## 1. First match wins

Firewalls check rules **in order** and stop at the first match. That single fact explains most audit findings, because it means a rule's *position* matters as much as its content. A rule can be perfectly written and do nothing, or do harm, only because of where it sits.

## 2. Default deny

**What:** the firewall's fallback is to drop anything no rule allows (`policy drop`). Everything permitted is permitted on purpose.

**Why:** the alternative, "allow everything not explicitly blocked", means you have to think of every bad thing in advance. You can't. Default deny turns the question around: only listed, approved traffic gets through.

**What goes wrong:** a default deny can be quietly cancelled by a broad accept near the end of the list. The policy says drop; a rule above it says "accept everything from here". Auditors check the policy **and** the last rules before it.

## 3. Least privilege (least access)

**What:** each rule allows the **narrowest** traffic that does the job: specific source, specific destination, specific port.

**Why:** an allowed path is a path an attacker can use if they take over the source. The narrower the path, the less they get. A rule that lets a whole network reach a whole network on any port is a trust relationship nobody decided to have.

**In the toy set:** rule **A** is the shape to notice. `lan -> wan`, any port. A web user needs 443, so why can the lan reach every port on every outside host? Compare it with rule **B**, which is least privilege for the same need.

**How to spot it:** a rule with no port, no address, or a wide range like a whole `/16` where one host would do. Ask: *what is the smallest rule that does this job?*

## 4. Shadowed rules

**What:** a rule that can **never run** because an earlier rule already matches all the traffic it was meant to handle.

**Why it matters:** a shadowed rule *looks* like protection on paper but protects nothing. Worse, it creates false confidence, because everyone assumes it is working.

**In the toy set:** rule **C** (block telnet) comes after rule **A** (allow everything, lan to wan). Telnet on tcp/23 matches A first and is accepted. C's drop is never reached. The block that was meant to override the allow sits **below** it. Rule **B** is shadowed too: A already covers everything B matches.

**Two kinds:**
- **Fully shadowed:** an earlier rule matches *everything* the later one does (rule **B**).
- **Partly shadowed:** the earlier rule covers *some* of it. These are harder to see and more dangerous.

**How to spot it:** pick a rule and read **upward**. Does an earlier rule match the same zones, and the same or broader address and port? If yes, the later rule is a candidate.

**The fix** depends on intent. Reorder (put the block above the allow), narrow the earlier rule, or delete the dead rule. It's never "just delete it", because the dead rule might be the one that *should* have been working.

## 5. Redundant and duplicate rules

**What:** a rule that does the same job as another.

**In the toy set:** rule **D** allows one dmz host to reach the file share. Rule **E**, just below, allows *any* dmz host to do the same. D is redundant, since E covers it, and the two together hide the fact that E is broader than anyone intended.

**Why it matters:** clutter makes the rule base hard to read, and the "narrow" rule gives a misleading picture of how much access is really granted.

## 6. "Any/any" and over-broad rules

**What:** rules that name no source, destination or port, or trust a whole zone.

**Why:** the zone model is only as strong as the rules between zones. "This zone is trusted, allow everything" means one compromised machine in it inherits access to everything the zone can reach. **Trust is earned per flow, not per zone.**

**Watch the admin ports in particular:** SSH (22), RDP (3389) and SMB (445) are the protocols attackers use to move sideways. Offering them to a whole network deserves a question.

## 7. Stale and temporary rules

**What:** rules added "for now" that are still there.

**Why:** a temporary rule is a hole punched for a reason that has since gone away. Look for comments like `TEMP`, a person's name, a date or a ticket number that has passed. Rules from a departed vendor or a finished project are the same.

**How to spot it:** read the **comment** and ask whether the reason still exists. Check the hit counters (next section) for rules nobody uses.

## 8. Hit counters: evidence, not verdicts

**What:** many firewalls count how often each rule matches.

**What it tells you:** a rule with **zero hits** over a long period is a candidate for removal. A rule with **huge hits** is carrying real traffic and needs more care.

**What it does not tell you:**
- **Zero hits can mean two opposite things:** nobody needs the rule (delete it), or an earlier rule is *stealing its traffic* (shadowing: fix the order). The counters look identical. You have to read the rules above it to know which.
- **Zero doesn't mean "safe to delete"** if the rule covers something rare: a quarterly job, a disaster-recovery path.
- **Read the header comment** to see what the counter counts. Counters often count only the first packet of a connection, which changes what a "hit" means.

## 9. Egress filtering (traffic leaving)

**What:** rules about what is allowed to go **out** of a zone, not just in.

**Why:** most organizations lock the door against things coming in and leave it open for things going out. But a compromised machine has to talk outward: to download tools, to reach its command server (see *What Is a Beacon?* in the Detection challenge), to send data away. An outbound rule that allows "any port to anywhere" gives an attacker all of that.

**How to spot it:** rules out to `wan` with no port, or ports far beyond what the zone needs (web and DNS, for most zones). Ask whether servers that should never browse the internet are allowed to.

## 10. Anti-spoofing

**What:** dropping packets that arrive from outside but claim an **inside** source address.

**Why:** if your rules trust inside addresses, an attacker can fake one. The firewall knows the packet came from the wrong side, so it can refuse. It is cheap to do and often missing.

## 11. The management plane (traffic *to* the firewall)

**What:** the rules for who may reach the firewall's own admin services (SSH, web interface).

**Why:** whoever reaches the management interface owns the firewall, and therefore every rule on it. This needs its own review, separate from the traffic *through* the firewall. A management port open to the outside is a critical finding almost anywhere.

## 12. Logging and accountability

**What:** whether blocks are logged, and whether every rule has a **comment** saying why it exists, who asked for it and when.

**Why:** a rule with no explanation can never be safely removed, so it never will be. And a block that isn't logged is an attack you will never see. Documentation is a control.

## 13. Intent versus reality

**What:** comparing what the firewall does against a **written policy**: the thing the organization actually approved.

**Why:** without a policy you can only find rules that look ugly, not rules that are wrong. A rule can look neat and violate policy, and a messy-looking rule can be exactly right. Read the policy first. This is why the Intended Policy comes with the Ledger.

**Policy silent?** Sometimes the policy doesn't cover a rule (a new service, an old exception). That is a finding of a different kind. It is not "wrong"; it is **undecided**. Your report asks someone to decide.

## 14. NAT and publishing consistency

**What:** NAT rewrites addresses; **forward** rules allow or block traffic. A published service needs both to agree.

**Why:** a NAT rule that sends outside traffic to an inside host, with a forward rule that also allows it, is an exposed service. If either part is left over after the service is retired, you have either a hole or a rule that does nothing. Check each NAT rule against the forward rule it needs.

---

## 15. Reputation, geography and threat-intelligence blocks (NGFW practice)

**What:** a traditional firewall decides on addresses and ports. A **next-generation firewall (NGFW)** can also decide on things like the application, the user, the content, the **country** an address belongs to (geo-IP), and whether an address or domain appears on a **reputation or threat-intelligence feed** of known-bad infrastructure. Vendors call these by different names (external dynamic lists, threat feeds, security intelligence), but the idea is the same: block what other people have already identified as hostile.

**Where they go: near the top.** The usual pattern puts a small set of high-confidence deny rules **above the broad allows**:

```
1  anti-spoofing and invalid packets          drop
2  established / related                      accept
3  protect the firewall's own management      (allow few, drop rest)
4  reputation and geography blocks            drop   <- known-bad, in and out
5  the explicit allows, by app / user / port  accept
6  default deny, logged                       drop
```

Vendors and teams differ on the details. Treat this as a pattern, not a law. The reasons for it:
- **Order is power.** An allow below a block can never let known-bad traffic through. An allow *above* it can. A block at the bottom of the list is the same mistake as the shadowed telnet rule in section 4.
- **A broad deny is safe.** Section 3 says to keep allows narrow. A deny that is too broad usually fails closed (traffic blocked), which is the safer direction, so a top-of-list deny can be wider than an allow could be.
- **It is cheap.** Dropping known-bad traffic early saves the deeper inspection, and keeps scans and brute-force noise out of your logs.
- **It works in both directions.** Inbound blocks cut scanning and brute force. **Outbound** blocks stop a compromised machine reaching a known command server (see *What Is a Beacon?* in the Detection challenge). Teams often do only inbound. Check outbound.
- **Geo can also be an allow-list.** For a published service used by customers in a few countries, you can *allow only those countries* instead of blocking bad ones.

**What it does not do.** These are filters that reduce noise and catch the commodity and the known. They do not stop a determined attacker:
- Geo-IP data is approximate and goes out of date.
- Attackers rent servers and VPNs in *allowed* countries. Cloud and CDN addresses change owners.
- A feed only knows what someone has already reported. New infrastructure is not on any list yet.
- IP lists are weak against names that move quickly. DNS and URL categories help there.

**What goes wrong in practice.** This is the part auditors care about:

| Risk | What happens | The control |
|---|---|---|
| **False positives** | A legitimate partner, a traveling employee, a SaaS provider on a shared cloud address is blocked, and someone opens an urgent ticket | Start in **log-only** mode. Review the hits. Then enforce. Keep a documented **exception list** *above* the block |
| **Stale feeds** | The feed stops updating and nobody notices, so the list is months out of date. Or the reverse: an address that was bad has changed hands and is now blocking a real service | Record the feed's source, **last update**, owner and review date. Alert on a failed update |
| **Shared addresses** | Blocking a cloud or CDN range takes out thousands of innocent sites | Prefer reputation sources that score individual addresses. Review large ranges by hand |
| **Poisoned or low-quality feeds** | A bad feed can block *you* | Use sources you trust, and put limits on what a feed can block (never your own ranges or required services) |
| **Defined, never enforced** | The list exists but no rule uses it | This is false assurance. It looks like a control and does nothing |

**How to audit it:**
- Is there a reputation or geo control at all? If the organization says it has one, find the rule that enforces it.
- Is it **above** the allows it needs to override?
- Does it apply **outbound** as well as inbound?
- Is the list **owned and current**? Where does it come from, and when did it last update?
- What do the **counters** show? Zero hits on a block that should be catching constant internet noise suggests the list is empty, stale or shadowed.
- Are the **exceptions** documented, with a reason and an owner?
- Is it **logged**, so a block leaves evidence?

**In this lab:** OPNsense and nftables have no vendor-managed feed built in, but you can build sets or aliases of addresses and use them in rules (OPNsense can also build address aliases from country lists; see its alias documentation for the details on your version). The Ledger contains one such set. Whether to enforce it, replace it or remove it is a decision for the Council. What an auditor can say for certain is whether it is doing anything.

## Putting it together

For each rule, an auditor asks, in this order:

1. **Why does it exist?** (Comment, policy, owner.)
2. **Is it still needed?** (Counters, age, who uses it.)
3. **Is it as narrow as it can be?** (Least privilege.)
4. **Does it actually run?** (Order and shadowing.)
5. **Does it match what was approved?** (Intended Policy.)
6. **If I removed it, what would break, and how would I know?** (Your test, before you change anything.)

Question 6 is what separates an audit from a cleanup. Findings come with **a safe way to fix them**.

## Check yourself

1. In the toy set, which rule would you move to make the telnet block actually work? What else would still be wrong with the set?
2. Why can't you tell from a zero-hit counter alone whether to delete a rule?
3. Rule **D** is narrower than rule **E**. Why is that not good news?
4. A rule is commented `TEMP - vendor debug - J. Smith`. List three questions you'd ask before removing it.
5. What is the difference between a rule that is *wrong* and a rule the policy is *silent* on?
6. Why is a broad deny at the top of a rule base acceptable when a broad allow is not?
7. A reputation feed stopped updating three months ago. What are the two ways that can hurt you?
