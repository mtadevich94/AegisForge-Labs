# The Wrkstation Chronicles: Packet Watch

*A hands-on Wireshark lab — part of Project AegisForge's Student path (Phase 2: Reading Network Traffic).*

---

## The story so far

The Vaultkeeper built the **Watchtower** — an intranet server that hands out quests, stores the guild's payroll, and shares files over FTP. He was proud of it. He was also in a hurry.

You've just been promoted to **Watch Captain**. Your job: learn to read what travels across the wire, because the Watchtower has been behaving strangely, and the only witness is the network itself.

By the end of this lab you will be able to read a packet capture the way a defender does: spotting plaintext secrets, telling normal from suspicious, and writing up what happened.

**Time:** about 4–6 hours total (plan 30–45 minutes per module).
**Cost:** free.

---

## Before you start

You need:

- Wireshark (installed by the setup script — see **Wireshark Lab Environment Setup.md**)
- The six pcaps in `C:\GielinorWatch\pcaps\` (or the `pcaps` folder from the repo)
- *Optional:* the two live VMs (`WATCHTOWER` + `WKS01`) for the "capture it yourself" steps

**How to work:** open the pcap named in each module, answer the questions in a notes file (use a text file or a markdown file in your Public Learning Log repo), and only then check the **Answer Key**. If you get stuck, the hints at the bottom of each module are there to be used — nobody is grading you.

> **Rule of the Watch:** Find the evidence before you explain it. Every answer should point at a specific packet or field.

### Wireshark cheat sheet (keep this open)

| Want to… | Do this |
|---|---|
| Open a pcap | `File → Open` |
| Show only some packets | Type a **display filter** in the green bar, press Enter |
| Add a field as a column | Click a packet, right-click the field in the middle pane → *Apply as Column* |
| See a whole conversation | Right-click a packet → *Follow → TCP Stream* (or *HTTP Stream*) |
| Summary stats | `Statistics → Conversations / Endpoints / Protocol Hierarchy / I/O Graphs` |
| Find text in packets | `Edit → Find Packet` → *String* → *Packet bytes* |
| Time since the first packet | `View → Time Display Format → Seconds Since Beginning of Capture` |
| Pull a file out of a capture | `File → Export Objects → HTTP…` (or the protocol you need) |

Useful display filters you'll use again and again:

```
ip.addr == 10.10.10.30            either side is this IP
ip.src == 10.10.10.20             only packets FROM this IP
tcp.port == 80                    either TCP port is 80
dns                               only DNS
http.request.method == "POST"     HTTP POST requests
tcp.flags.syn == 1 && tcp.flags.ack == 0     a connection attempt (SYN)
!(arp || icmp)                    hide ARP and ping noise
```

> **Display filter ≠ capture filter.** A *capture* filter (set before you start recording) decides what Wireshark *keeps*. A *display* filter (the green bar) only decides what you *see* from what's already recorded. Beginners almost always want display filters.

### Cast of the lab

| Host | IP | Who |
|---|---|---|
| WKS01 | `10.10.10.20` | You — the Watch Captain's workstation |
| WATCHTOWER | `10.10.10.30` | The Vaultkeeper's intranet / FTP server |
| DC01 | `10.10.10.10` | Guild directory + DNS server |
| ??? | `10.10.10.66` | A stranger. You'll meet them later. |

---

## Module 1 — The Wire Is Talking (first capture)

**Pcap:** *your own capture* (or `01-warmup.pcap` if you're on the pcap-only track)

**Mission:** Capture live traffic and learn the three panes of Wireshark.

### Steps

1. On WKS01, open Wireshark. On the welcome screen, find the Ethernet interface whose sparkline is moving and **double-click it** to start capturing.
2. In an elevated or normal PowerShell:

   ```powershell
   cd C:\GielinorWatch
   .\Invoke-GarrisonTraffic.ps1 -Module Warmup
   ```

3. Switch back to Wireshark and click the red **Stop** square.
4. Save the capture: `File → Save As…` → `C:\GielinorWatch\captures\m1-warmup.pcapng`.

### Questions

1. What are Wireshark's three main panes called, and what does each show?
2. How many packets did you capture? How many of them are yours (to/from `10.10.10.20`)?
3. Open `Statistics → Protocol Hierarchy`. List every protocol you captured. Which one has the most packets?
4. Which protocols in your list did you *expect* given the commands the script ran — and which surprised you?

*Pcap-only track:* answer 1–4 using `01-warmup.pcap` instead.

<details><summary>Hint</summary>
The top pane is the packet list; click one packet and the other two panes fill in. If your capture is huge, the interface was probably noisy — apply the display filter <code>ip.addr == 10.10.10.30</code>.
</details>

---

## Module 2 — Ask the Directory (filters and DNS)

**Pcap:** `01-warmup.pcap`

**Mission:** Learn display filters by interrogating the Directory (DNS).

### Questions

1. Apply the filter `dns`. How many packets match? Which IP address is the DNS server?
2. What IP address does `watchtower.gielinor.local` resolve to?
3. One lookup **failed**. Which hostname was it, and how does DNS tell the client it failed? (Look at the *Flags* section of the response.)
4. Find the **reverse lookup** (PTR). What IP address was being looked up, and what name came back?
5. Add `dns.time` as a column (expand the DNS section of a response → right-click *Time* → *Apply as Column*). Which lookup was slowest? Which was fastest?
6. The client asked for an `AAAA` record for `www.professormesser.com`. What is an AAAA record, and what answer did it get?
7. Filter for ping traffic (`icmp`). Compare the **TTL** of the requests (from WKS01) with the TTL of the replies (from Watchtower). They differ — why might that be? *(Hint: operating systems start the TTL counter at different default values.)*
8. Write a filter that shows **only** traffic between WKS01 and the DNS server. Then write one that shows everything **except** DNS and ARP.

<details><summary>Hint</summary>
Real answers come in the <i>response</i> packets (filter: <code>dns.flags.response == 1</code>). Look at <i>Flags → Reply code</i>.
</details>

---

## Module 3 — Handshakes and Conversations (TCP)

**Pcap:** `02-http-login.pcap`

**Mission:** Understand how TCP connections start, run, and end.

### Questions

1. Find the first **SYN** packet (use `tcp.flags.syn == 1 && tcp.flags.ack == 0`). What is its frame number, and what source port did the client choose?
2. Find the full **three-way handshake** for that connection. Write down the three packets' TCP flags in order.
3. In the SYN packet's TCP *Options*, find the **MSS** and **window scale** values. What do they mean in plain language?
4. Open `Statistics → Conversations → TCP`. How many TCP conversations are in this capture? Which one carried the most data?
5. Pick the first TCP conversation and right-click → *Follow → TCP Stream*. What colours does Wireshark use for client and server data? Roughly how many packets did that connection use end to end?
6. How does the first connection **end**? Which flag(s) do you see, and who sends them first?
7. Change the time display to *Seconds Since Previous Displayed Packet*. Find the biggest gap between two packets on the first connection. What was the human doing during that time?

<details><summary>Hint</summary>
For Q7 think about what a person does between loading a login page and pressing the Enter button.
</details>

---

## Module 4 — The Postcard (plaintext HTTP)

**Pcap:** `02-http-login.pcap`

**Mission:** Prove, with evidence, why plain HTTP logins are dangerous.

*Live version (optional):* start a capture on WKS01, run `.\Invoke-GarrisonTraffic.ps1 -Module WebLogin`, stop, and repeat the questions on your own capture.

### Questions

1. Filter `http.request`. List every request with its method and URL.
2. Find the **login** request (a `POST`). What are the **username and password** that were sent? Show *two different ways* to find them (hint: *Follow → HTTP Stream*; the packet details pane under *HTML Form URL Encoded*).
3. Find the server's response to the login. What HTTP status code did it send, and where did it redirect the browser?
4. Find the `Set-Cookie` header. What is it for? Why is stealing this value almost as bad as stealing the password?
5. Look at the page the server sent **before** login (the response to `GET /login`). Is there anything interesting *hidden in the HTML source*? What does it tell you about the Vaultkeeper?
6. What `User-Agent` does the client report? What does that tell an observer about the sender?
7. Using `File → Export Objects → HTTP`, how many objects can you extract? Name them.
8. Write 3–4 sentences, as if to a non-technical manager, explaining what an attacker on the same network could do with this capture and what single change would stop it.

<details><summary>Hint</summary>
Form data is URL-encoded, so special characters appear as <code>%21</code> and similar. A <code>%21</code> is just <code>!</code>.
</details>

---

## Module 5 — The Vaultkeeper's Ledger (plaintext FTP)

**Pcap:** `03-ftp-session.pcap`

**Mission:** FTP is older than most students. Find out why defenders hate it.

*Live version (optional):* capture while running `.\Invoke-GarrisonTraffic.ps1 -Module Ftp`.

### Questions

1. Filter `ftp`. List every **command** the client sent in order.
2. What **username and password** were used to log in? Which packets contain them?
3. FTP uses *two* connections. Open `Statistics → Conversations → TCP`. List the TCP connections: which port is the **control** channel, and what are the ports of the **data** channels?
4. Find the response to the `PASV` command (`227 Entering Passive Mode (...)`). Decode the last two numbers into the real port number. *(Hint: `p1 × 256 + p2`.)* Does it match a port from Q3?
5. What **files** are in the directory? (Follow the stream of the first data connection.)
6. Follow the stream of the **second data connection**. What is inside the file that was downloaded? There's a flag in the format `FORGE{...}` — find it.
7. What **version** of FTP server software does the banner reveal?
8. Compare Module 4 and Module 5. Name two things both protocols have in common that make them unsafe on a network you don't trust.

<details><summary>Hint</summary>
Data connections only exist <i>during</i> a file transfer, so they'll be short. In the Conversations window, sort by start time.
</details>

---

## Module 6 — The Sealed Letter (TLS)

**Pcap:** `04-tls-contrast.pcap`

**Mission:** See what encryption hides — and what it doesn't.

*Live version (optional):* capture while running `.\Invoke-GarrisonTraffic.ps1 -Module Tls`.

This capture contains the **same login** as Module 4, but over HTTPS (port 443).

### Questions

1. Filter `tls.handshake.type == 1` (Client Hello). How many are there? To which hosts?
2. In the Client Hello, find the **Server Name Indication (SNI)**. What is it? Why does the client send it *in the clear* before encryption starts?
3. Which **TLS version** was negotiated with Watchtower? (Check the Server Hello's *supported_versions* extension.)
4. Use `Edit → Find Packet` → *String* → *Packet bytes* and search for the password you found in Module 4 (`Hey-Listen`). What happens? What does that prove?
5. Can you still read the HTTP method or URL of the login? What *does* an eavesdropper still learn from this capture? List at least four things (think: who, when, how much, how often).
6. If you built the live lab, browse to `https://watchtower.gielinor.local/` and your browser will warn about the certificate. Why? *(Click through the warning and inspect the certificate — who issued it? On the pcap-only track, reason it out: what does a browser need to trust a certificate?)* Is encryption still happening despite the warning?
7. In one paragraph: "HTTPS protected the password but not the…" — complete the sentence and defend it.

<details><summary>Hint</summary>
TLS 1.3 encrypts almost the entire handshake after the Server Hello — that is why you see "Application Data" records where a certificate would have been in older versions.
</details>

---

## Module 7 — Footsteps at the Gate (spotting a port scan)

**Pcap:** `05-scan.pcap`

**Mission:** Someone is knocking on every door. Prove it, find out who, and learn what they found.

*Live stretch (optional):* from WKS01 run `.\Invoke-GarrisonTraffic.ps1 -Module Sweep` while capturing, then compare your capture to the pcap. A full-connect sweep looks different from a stealth SYN scan — can you say how?

### Questions

1. Without applying any filter, open `Statistics → Endpoints → IPv4`. Two hosts dominate the traffic — one is Watchtower. Who is the other, and is it a host you'd expect to be talking to Watchtower 1,000+ times in a few seconds?
2. Filter `tcp.flags.syn == 1 && tcp.flags.ack == 0 && ip.src == <that IP>`. **How many SYN packets** did that host send? How many *different* destination ports?
3. Are the ports being probed in order (1, 2, 3…) or randomised? Show how you know.
4. What **source port** does every probe use? What **TCP window size**? Why are those values a fingerprint of an automated tool (and not a browser)?
5. Closed ports reply with `RST, ACK`. Open ports reply with `SYN, ACK`. Use the filter `tcp.flags.syn == 1 && tcp.flags.ack == 1 && ip.src == 10.10.10.30` to list the **open ports** on Watchtower. What service does each one probably run?
6. After a port replied `SYN, ACK`, what did the scanner send back? Why? *(This is what makes it a "half-open" or "SYN" scan.)*
7. How long (in seconds) did the entire scan take?
8. Before the scan began, what **ARP** exchange happened, and what does it tell you about where the scanner is? *(Hint: ARP only works inside one local network.)*
9. Open `Statistics → I/O Graphs`. Add a second graph line with the filter `tcp.flags.syn == 1 && tcp.flags.ack == 0`. Describe the shape of the traffic. Would a human-driven web browser ever look like this?
10. List three real-world signals a defender could alert on to catch this scan automatically.

<details><summary>Hint</summary>
The scan is so fast that the I/O graph looks like a single spike. Zoom in on the first few seconds.
</details>

---

## Module 8 — The Night of the Stranger (capstone investigation)

**Pcap:** `06-incident.pcap`

**Mission:** Something happened to the Watchtower. This capture holds a whole intrusion: reconnaissance, a break-in, theft, and a phone-home. Reconstruct it and write the incident report.

This is the module that proves you can do the job. Take your time. The earlier modules gave you every skill you need.

### Part A — Find the story

1. Who is the attacker? What is their IP address, and how do you know?
2. **Recon.** What ports did the attacker probe? At what time (seconds from start) did the recon begin and end?
3. **Brute force.** The attacker then tried to log in to the portal over and over. Which **username** was targeted? How many **login attempts** were made? How many failed, and how does the server signal failure vs. success?
4. What was the **password** that eventually worked? At what time was the successful login?
5. What tool was used to do the guessing? How can you tell from the traffic? *(One header gives it away.)*
6. After the successful portal login, which pages did the attacker visit — and what information did they learn from them?
7. **FTP.** The attacker then went after the FTP service. How many login attempts? What credentials failed? What credentials worked? *(Think about how they might have guessed the last one.)*
8. What **file** did the attacker download? Reconstruct it from the capture and list its contents. Why is this a serious problem?
9. **The phone-home.** After the theft, the Watchtower itself started making odd DNS requests. What **domain** is it asking about? What **record type**? How often (give the interval in seconds)? How many such queries were there?
10. The subdomain labels look like gibberish — they are **hexadecimal**. Decode them (in order) and read the hidden message.
11. Who **sent** those DNS queries — the attacker's machine or the Watchtower? Why is that significant?

### Part B — Write the report

Write a one-page **incident report** in the format below. Put it in your Public Learning Log repo — this is portfolio material.

```markdown
# Incident Report: Watchtower Intrusion
**Analyst:** <you>        **Capture:** 06-incident.pcap        **Date analysed:** <date>

## Summary
Two or three sentences a non-technical reader can follow: what happened, what was lost.

## Timeline (seconds from capture start)
| Time | Event | Evidence (filter / frame) |
|---|---|---|
| ... | ... | ... |

## Indicators of Compromise (IOCs)
- Attacker IP: ...
- Tool user-agent: ...
- Compromised accounts: ...
- Suspicious domain: ...

## Impact
What data was exposed, and what is now untrusted?

## Recommendations
At least three concrete fixes, in priority order.
```

### Part C — Stretch goals

- Use `File → Export Objects` or *Follow Stream* to save the stolen file and open it in a spreadsheet.
- Build a **colouring rule** (`View → Coloring Rules`) that highlights failed logins in red and the successful login in green.
- Write a one-line `tshark` command that prints the timestamp and subdomain of every DNS beacon:

  ```powershell
  & "C:\Program Files\Wireshark\tshark.exe" -r C:\GielinorWatch\pcaps\06-incident.pcap -Y "dns.qry.type == 16 && dns.flags.response == 0" -T fields -e frame.time_relative -e dns.qry.name
  ```

<details><summary>Hint 1 — where to start</summary>
Start with <code>Statistics → Conversations → IPv4</code> sorted by packets. The odd one out is your attacker.
</details>

<details><summary>Hint 2 — brute force</summary>
Filter <code>http.request.method == "POST"</code> and add <code>urlencoded-form.value</code> as a column. Then filter on <code>http.response.code</code> to separate 401s from the one success.
</details>

<details><summary>Hint 3 — beacon</summary>
Filter <code>dns.qry.type == 16</code> (TXT). The subdomains start with a counter (<code>00</code>, <code>01</code>…) followed by hex. Hex <code>46 4f 52 47 45</code> is ASCII for <code>FORGE</code>.
</details>

---

## What you can now put on your résumé (and in your portfolio)

- Captured and analysed live traffic with Wireshark
- Used display filters, conversations, and I/O graphs to triage network data
- Identified plaintext credential exposure over HTTP and FTP
- Explained what TLS protects and what it leaves visible
- Detected port scanning and credential brute-forcing from raw packets
- Wrote an incident report with a timeline and IOCs from packet evidence

**Next up in the path:** harden your Linux lab VM (see the Linux Labs), then book your Security+ readiness check.
