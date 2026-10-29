# Detection Checklist

Use this to **cross-reference your own work**. It lists things to look for, not a sequence of steps. Each item says *what to check*, *why it matters*, and *where to look*. The hints show you where to look. They don't hand you the rule.

---

## Part 1. Rules

### 1. The scan
- **What:** An alert when one source opens many new connections in a very short time.
- **Why:** A scan is the first thing most attackers do. It is loud, so it is cheap to catch, *if* you don't also flag a busy web page.
- **Where to look:** TCP flags. A new connection begins with a SYN and no ACK. Look at Suricata's `flags` keyword and its `threshold` (track by source, count, seconds).
- **Test:** `05-scan.pcap` should alert. `07-hunt.pcap` contains three page loads that open 8 connections in under half a second. Does yours stay quiet?

### 2. Cleartext credentials
- **What:** Alerts for a password sent in the clear in (a) an HTTP form post and (b) an FTP login.
- **Why:** Cleartext logins are both a finding about *your* network (something is not encrypted) and a gift to anyone who can see the traffic.
- **Where to look:** Suricata's `http.method`, `http.request_body`, and the FTP `PASS` command. Packet Watch labs `02` and `03` show you what the traffic looks like.
- **Test:** `06-incident.pcap` has both. `07-hunt.pcap` contains one real cleartext login to the intranet server: that alert is *correct*, not a false positive. Say so in your report.

### 3. Brute force
- **What:** One alert when a single source posts to the login page many times.
- **Why:** Twenty alerts for one attack bury the real signal. Aggregating by source is what makes an alert usable.
- **Where to look:** `threshold` with `type both` or `type limit`; `http.uri`.
- **Test:** `06-incident.pcap` has 20 login attempts. Count your alerts.

### 4. Data in a DNS name
- **What:** An alert on a hostname with a long run of encoded characters.
- **Why:** DNS is allowed almost everywhere, so attackers hide data in it. A normal hostname is words. A tunnel's hostname is encoded data.
- **Where to look:** `dns.query` with a `pcre`. Hex digits are `[0-9a-f]`. How long is "too long" for a real hostname?
- **Test:** `06-incident.pcap` should alert. `07-hunt.pcap` must not.

### 5. The rhythm in DNS
- **What:** An alert when the same client keeps asking for the same suspicious domain.
- **Why:** One lookup is nothing. The same rare name every 30 seconds is a rhythm.
- **Where to look:** `dns.query` with `content`, and a threshold on count and seconds.
- **Test:** It will only be as good as the domain you put in it, and you'll only know that domain after Part 2. Note that in your report.

### 6. Tuning
- **What:** At least one rule you changed after a false positive.
- **Why:** Untuned rules get switched off by a tired analyst at 3 a.m.
- **Where to look:** The rule's `msg` should say what it caught; your comment should say what it could catch by mistake. Keep `my-v1.rules` and its output, so the before is on record (see the **[Suricata Rule Primer](Suricata%20Rule%20Primer.md)**).

---

## Part 2. The hunt

*New to the idea of a beacon? Read **[What Is a Beacon?](What%20Is%20a%20Beacon.md)** first.*

### 7. Look before you score
- **What:** Count connections per destination, per source, and per hour; list the top DNS names; list every TLS server name.
- **Why:** You can't score what you haven't looked at. Most hunts are won by someone who noticed a thing the score didn't.
- **Where to look:** `conns.csv`, `dns.csv`, `tls.csv`. A spreadsheet pivot table is enough.

### 8. Regularity
- **What:** For each source→destination pair, the gaps between consecutive connections, and how much they vary.
- **Why:** Software on a timer is steadier than a person. A *low coefficient of variation* (standard deviation divided by the mean) means steady.
- **Where to look:** Sort connections by time, subtract each from the next. Remember a good beacon adds a little **jitter** on purpose.

### 9. Size
- **What:** How alike the bytes sent and received are from one connection to the next.
- **Why:** A check-in with a tiny, nearly constant payload looks different from a person loading pages.

### 10. Rarity and direction
- **What:** How many different internal machines talk to this destination, and whether it is inside your network at all.
- **Why:** Everyone in the company talking to one vendor is normal. One machine talking to an address nobody else touches is not.

### 11. Decoys
- **What:** For every pair that scored well on regularity, say why it is or isn't a threat.
- **Why:** Time servers, update checkers and mail clients are all regular. "Regular" is a lead, not a verdict.
- **Where to look:** Who else talks to it? Does it have a name that makes sense? Is it internal? Does it match a service you actually run?

### 12. The call
- **What:** Name the beacon, with numbers, and decide what you would do about it.
- **Why:** An analyst's job ends in a decision. Blocking a destination has a cost; isolating a machine has a bigger one.
- **Where to look:** Check the DNS and TLS names for the destination. A rule on the TLS server name (`tls.sni`) works even when the client never uses DNS. What does the Gatehouse's Module 7 (egress and DNS control) let you do about it?

---

## Gap analysis (do this last)

- What would the attacker change to dodge your **rules**? (Port, encoding, domain, timing.)
- What would the attacker change to dodge your **hunt**? (Jitter, size padding, riding a popular destination, a different protocol.)
- What traffic did you **not see at all**? (Encrypted payloads, traffic on another segment, anything before the capture started.)
