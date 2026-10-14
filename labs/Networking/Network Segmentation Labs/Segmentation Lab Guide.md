# The Wrkstation Chronicles: The Gatehouse

*A hands-on network segmentation lab — part of Project AegisForge's Network Engineer path (Phase 1: Secure Network Design & Hardening).*

---

## The story so far

For years the Realm ran on one big open field. The market stalls, the garrison barracks, and the Citadel where the administrators keep the keys all stood on the same flat ground, with nothing between them. Then a raider walked in through the front stall — the public web server — and strolled straight up to the Citadel gates.

You've been appointed **Gatekeeper**. Your charter: raise walls between the zones, open exactly the gates that must be open, hide the gatehouse's own keys, and keep watch. At the end you put on the raider's boots and try to climb your own walls.

**Time:** about 8–10 hours (45–75 minutes per module).
**Cost:** free.

---

## Before you start

Complete **Segmentation Lab Environment Setup.md**. You should have:

- **FW01** (OPNsense) with four interfaces: WAN, **GARRISON**, **MARKET**, **CITADEL**
- **WKS01** (Windows 11) in the Garrison, **WEB01** (Ubuntu) in the Market, **ADM01** (Ubuntu) in the Citadel, and **WATCHTOWER** on the WAN side
- The temporary "flat realm" rules in place, and the `00-flat-baseline` snapshots taken

New to firewalls, VirtualBox networking, or Linux? Keep **Segmentation Lab Primer.md** open in another tab. This guide links to it.

**How to work:** keep a notes file (a text file or a markdown file in your Public Learning Log repo). Answer each module's questions *in your own words* before you open the **Answer Key**. Each module ends with a **Checkpoint** — a concrete thing you can show to prove it works.

> **Rule of the Gatehouse:** *Prove it.* A firewall rule you haven't tested is a hope, not a control. Every module ends by testing what you built.

### Cast of the lab

| Host | Zone | Address | Who |
|---|---|---|---|
| **FW01** | all four | `10.20.10.1` / `10.20.20.1` / `10.20.30.1` / WAN `10.10.10.5` | The Gatehouse — you |
| **WKS01** | GARRISON | DHCP, normally `10.20.10.100` | The Garrison's workstation |
| **WEB01** | MARKET | `10.20.20.10` | The public Marketplace server |
| **ADM01** | CITADEL | `10.20.30.10` | The administrators' hall and the log keeper |
| **WATCHTOWER** | WAN | `10.10.10.30` | The outside world (and, later, the raider's server) |

### Your three test tools

The lab ships a **test matrix** you'll run constantly. It makes plain connection attempts and compares the result to what your policy *should* allow:

| Where | Command |
|---|---|
| **WEB01 / ADM01** (Linux) | `bash segtest.sh --profile policy --wks-ip 10.20.10.100` |
| **WKS01** (PowerShell) | `.\Test-Segmentation.ps1 -Profile policy` |

Four **profiles** match four stages of the lab: `flat` (Module 1), `policy` (Modules 3–5), `mgmt` (after Module 6), `hardened` (after Module 7). A row is **OPEN** if the connection worked, **DROPPED** if it timed out (a *Block* rule), **REFUSED** if it was reset instantly (a *Reject* rule).

If your WKS01 isn't `10.20.10.100`, find its address with `ipconfig` and pass it with `--wks-ip`.

The scripts live in the lab folder on each machine (the folder you cloned on WEB01/ADM01 in Setup; the extracted ZIP folder on WKS01). Everywhere below, `cd` there first.

### Rule-writing cheat sheet

You'll create dozens of rules. The dialog (Firewall → Rules → *INTERFACE* → **+ Add**) has these fields:

| Field | Meaning | Typical value in this lab |
|---|---|---|
| **Action** | What to do on a match | `Pass`, `Block`, or `Reject` |
| **Quick** | Stop evaluating more rules once this one matches | Leave ticked (the default) |
| **Interface** | Where the traffic *arrives* | The zone you're editing |
| **Direction** | Traffic entering the interface | `in` — always, in this lab |
| **TCP/IP version** | | `IPv4` |
| **Protocol** | | `TCP`, `UDP`, `TCP/UDP`, `ICMP`, or `any` |
| **Source** | Who starts the conversation | A zone alias such as `NET_GARRISON` |
| **Invert** (next to Source/Destination) | "Anything *except* this" | Used for "not inside the realm" |
| **Destination** | Where it's going | An alias, a host, or `This Firewall` |
| **Destination port range** | Which port(s) | An alias such as `P_WEB`, or a service name |
| **Log** | Write matches to the firewall log | Tick on every `Block`/`Reject` |
| **Description** | Your note to your future self | **Always fill this in** |

After **Save**, always click **Apply changes**. Nothing is live until you do.

---

# Module 1 — Walk the Open Field

**Story:** Before building a wall, learn what the raider already knows. You'll play the intruder on the compromised Marketplace server and see how far the flat realm lets you walk.

**Mission:** Demonstrate the blast radius of one compromised DMZ server, and record it as your "before" evidence.

**You'll learn:** blast radius · lateral movement · why "allow any" rules hide attacks.

### Steps

1. **Snapshot.** Take a snapshot of **FW01** named `01-flat` (VirtualBox → FW01 → *Snapshots* → *Take*).

2. **Find WKS01's address.** On WKS01, run `ipconfig` and note the `10.20.10.x` address (normally `.100`).

3. **Start the "attacker's server".** On **WATCHTOWER**, open a second listener on port 4444, pretending to be the raider's command post:

   ```bash
   python3 -m http.server 4444
   ```

   Leave it running (Ctrl+C stops it later).

4. **Become the raider.** On **WEB01**, in the lab folder, run the simulator:

   ```bash
   cd "AegisForge-Labs/labs/Networking/Network Segmentation Labs"
   bash attack-sim.sh --wks-ip 10.20.10.100
   ```

   It tries to look around, reach for admin interfaces, phone home, and sneak data out. **Red OPEN lines are things the raider can reach.** The script saves a copy in `/tmp/attack-sim-*.txt` — keep it as evidence.

5. **Run the test matrix in `flat` mode** from all three machines:

   ```bash
   bash segtest.sh --profile flat --wks-ip 10.20.10.100     # on WEB01
   bash segtest.sh --profile flat --wks-ip 10.20.10.100     # on ADM01
   ```
   ```powershell
   .\Test-Segmentation.ps1 -Profile flat                 # on WKS01
   ```

   Everything should be **OPEN** (a PASS in `flat` mode means the realm really is wide open). The `:4444` row passes only if your WATCHTOWER listener is running.

6. **Collect the three trophies.** Each zone holds a flag that proves you reached it from where you shouldn't:

   | From | Run | Flag you should read |
   |---|---|---|
   | WEB01 (the raider) | `curl -s http://10.20.30.10/` | the **Citadel** flag |
   | WEB01 (the raider) | `curl -s http://10.20.10.100:8080/` *(use WKS01's address)* | the **Garrison** flag |
   | WKS01 (a "user") | `curl.exe -s http://10.20.20.10:8080/` | the **Market admin panel** flag |

7. **Check what the firewall noticed.** Open **Firewall → Log Files → Live View** and look for entries from the last few minutes.

### Check yourself

1. How many of the raider's attempts succeeded? List them.
2. Of those, which connections would a *legitimate* public web server ever need to make?
3. What did the firewall's log show about the raider's activity? Why?
4. In one sentence: what is the "blast radius" of the Marketplace server right now?

<details>
<summary>Hints</summary>

- For question 3, remember the rule's *action*. A **Pass** rule with logging off writes nothing — an attacker's successful movement is invisible. Compare with a **Block** rule that has logging on.
- For question 2, think about what a web server does: it *answers* requests; it does not normally *start* conversations with workstations, admin hosts or firewall interfaces.
</details>

### Checkpoint

- A saved `attack-sim` output where the raider reached the Garrison, the Citadel, the firewall GUI, and the "attacker's server".
- The three flags copied into your notes.
- A one-sentence blast-radius statement.

---

# Module 2 — Draw the Walls (design before you click)

**Story:** A wall built without a plan blocks the baker's cart and lets the raider through the side door. Before touching a rule, decide who needs to talk to whom — and why.

**Mission:** Produce a **zone trust model** and a **flow matrix** on paper, then create the **aliases** you'll use to write the rules.

**You'll learn:** zone design · least privilege · documented business reasons for each flow · aliases.

### Part A — Define the trust levels

Rank the four zones from *most* to *least* trusted, and write one sentence on why. Use the story: who can hurt the realm most if compromised? Who holds the keys?

### Part B — List the legitimate flows

Network security starts with *what must work*. Here is the realm's list of real needs. Everything not on it is, by default, forbidden.

| # | Need | From | To |
|---|---|---|---|
| 1 | Users browse the public Marketplace | Garrison | WEB01 on 80/443 |
| 2 | Users browse the wider web | Garrison | Internet on 80/443 |
| 3 | Everything resolves names | all zones | The firewall's DNS (53) |
| 4 | Clocks stay right | Garrison, Citadel | Internet NTP (UDP 123) |
| 5 | The web server fetches updates | WEB01 | Internet on 80/443 |
| 6 | The public reaches the Marketplace | Internet | WEB01 on 80/443 |
| 7 | Admins maintain the web server | ADM01 | WEB01 on SSH (22) and the admin panel (8080) |
| 8 | Admins manage the firewall | Citadel | Firewall on 443 (GUI) and 22 (SSH) |
| 9 | The admin host can fetch updates | ADM01 | Internet on 80/443 |
| 10 | Anyone can ping for troubleshooting | Garrison, Citadel, DMZ → firewall | ICMP echo |

### Part C — Fill in the matrix

On paper, copy this grid and fill each cell with **Allow** (and which ports) or **Deny**. *Rows are the source, columns the destination.* Where would you put "no, never"?

| From ↓ / To → | **Garrison** | **Market** | **Citadel** | **Firewall itself** | **Internet** |
|---|---|---|---|---|---|
| **Garrison** | n/a (same subnet) | ? | ? | ? | ? |
| **Market** | ? | n/a | ? | ? | ? |
| **Citadel** | ? | ? | n/a | ? | ? |
| **Internet** | ? | ? | ? | ? | n/a |

Rules for yourself:

- **Default is Deny.** Only add an Allow when it matches a row in Part B.
- Prefer a **specific host and port** over a whole network.
- *Who* starts the conversation matters. Market may *answer* the Garrison; that doesn't mean Market may *start* talking to the Garrison.

Compare your matrix with the recommended one in the **Answer Key** only after you've filled it in.

### Part D — Create the aliases in OPNsense

An **alias** is a named list. Writing rules with `NET_CITADEL` instead of `10.20.30.0/24` makes them readable, and one change to an alias fixes every rule that uses it.

1. On WKS01, open **`https://10.20.10.1`** and log in as `root`.
2. **Firewall → Aliases**. Click **+** (Add) and create each alias in this table. For each: tick **Enabled**, enter the **Name**, pick the **Type**, put the **Content** (one entry per line), add a **Description**, then **Save**.

| Name | Type | Content | Description |
|---|---|---|---|
| `NET_GARRISON` | Network(s) | `10.20.10.0/24` | Garrison zone |
| `NET_MARKET` | Network(s) | `10.20.20.0/24` | Market (DMZ) zone |
| `NET_CITADEL` | Network(s) | `10.20.30.0/24` | Citadel (management) zone |
| `NET_REALM` | Network(s) | `10.20.0.0/16` | Everything inside the realm |
| `H_WEB01` | Host(s) | `10.20.20.10` | The public web server |
| `H_ADM01` | Host(s) | `10.20.30.10` | The admin host / log collector |
| `P_WEB` | Port(s) | `80` and `443` | Web |
| `P_SSH` | Port(s) | `22` | SSH |
| `P_FW_ADMIN` | Port(s) | `22` and `443` | Firewall management ports |
| `P_ADMIN_ACCESS` | Port(s) | `22` and `8080` | Server administration |
| `P_DNS` | Port(s) | `53` | DNS |
| `P_NTP` | Port(s) | `123` | Time sync |

3. Click **Apply** (top right of the Aliases page).

> **Alias naming rules:** letters, numbers and underscores only, starting with a letter — no spaces or hyphens. The `NET_`/`H_`/`P_` prefixes are just a habit that makes rules scan quickly: *network*, *host*, *port*.

### Check yourself

1. Which zone is the *least* trusted, and what does that mean for how much it may reach?
2. Rows 7 and 8 both involve "admins". Why is it better that the admin host initiates those, rather than the servers?
3. Why define `NET_REALM` as `10.20.0.0/16`, and what do you think you'll use it for?
4. Looking at your matrix, are there any cells you'd mark *Allow* that aren't backed by a Part B row? Remove them.

### Checkpoint

- Your filled-in matrix and one sentence per cell you marked Allow.
- **Firewall → Aliases** showing all twelve aliases, enabled.

---

# Module 3 — Raise the Walls (the rule base)

**Story:** The plan is drawn. Now stone by stone: replace the three "allow any" gates with narrow, labelled doors.

**Mission:** Replace the flat realm with a **default-deny rule base** on each zone, test it, and learn why **rule order** matters.

**You'll learn:** writing OPNsense rules · using aliases and `This Firewall` · rule order and first-match · logging blocks.

### Before you start

- **Snapshot FW01** as `03-before-rules`.
- **Don't worry about locking yourself out.** OPNsense has an automatic **anti-lockout rule** that always allows the Garrison to reach the firewall's GUI (443) and SSH (22). You can delete the "allow any" rules and still log in. (Module 6 turns that safety net off on purpose.)

### How to read the rule tables below

Each row is one rule, top to bottom. If a field isn't listed, leave the default. **Invert** means "anything except".

### Part A — MARKET (the DMZ) — build the smallest zone first

**Firewall → Rules → MARKET.** Delete the `TEMP flat realm` rule (trash icon), then add these four rules **in this order**:

| # | Action | Protocol | Source | Destination | Dest. port | Log | Description |
|---|---|---|---|---|---|---|---|
| M1 | Pass | TCP/UDP | `NET_MARKET` | `This Firewall` | `P_DNS` | – | DMZ asks the gatehouse for DNS |
| M2 | Pass | ICMP (Echo Request) | `NET_MARKET` | `This Firewall` | – | – | DMZ may ping the gatehouse |
| M3 | Pass | TCP | `H_WEB01` | `NET_REALM` **Invert** | `P_WEB` | – | WEB01 may reach the outside web (updates) |
| M4 | **Block** | any | `NET_MARKET` | `NET_REALM` | any | **✔** | A compromised DMZ host must not reach inside |

Read M3 aloud: *"Pass TCP from WEB01 to anything that is **not** inside the realm, on web ports."* And M4: *"Block anything from the Market to anything inside the realm."* Anything not matched by M1–M4 falls through to the invisible default deny.

**Save → Apply changes.**

### Part B — CITADEL (management)

**Firewall → Rules → CITADEL.** Delete the `TEMP flat realm` rule, then add:

| # | Action | Protocol | Source | Destination | Dest. port | Log | Description |
|---|---|---|---|---|---|---|---|
| C1 | Pass | TCP | `NET_CITADEL` | `This Firewall` | `P_FW_ADMIN` | – | Admins manage the gatehouse |
| C2 | Pass | TCP/UDP | `NET_CITADEL` | `This Firewall` | `P_DNS` | – | Citadel asks the gatehouse for DNS |
| C3 | Pass | ICMP (Echo Request) | `NET_CITADEL` | any | – | – | Ops may ping to troubleshoot |
| C4 | Pass | TCP | `H_ADM01` | `H_WEB01` | `P_ADMIN_ACCESS` | – | Admin host maintains WEB01 |
| C5 | Pass | TCP | `NET_CITADEL` | `NET_REALM` **Invert** | `P_WEB` | – | Admin host fetches updates |
| C6 | Pass | UDP | `NET_CITADEL` | `NET_REALM` **Invert** | `P_NTP` | – | Clock sync |
| C7 | **Block** | any | `NET_CITADEL` | `NET_REALM` | any | **✔** | Management zone may not roam the realm |

**Save → Apply changes.**

### Part C — GARRISON (the users)

**Firewall → Rules → GARRISON.** *First add* the new rules below, *then* delete the two "Default allow LAN to any" rules. (Add first, delete last — you keep working access while you build.)

| # | Action | Protocol | Source | Destination | Dest. port | Log | Description |
|---|---|---|---|---|---|---|---|
| G1 | Pass | TCP/UDP | `NET_GARRISON` | `This Firewall` | `P_DNS` | – | Users ask the gatehouse for DNS |
| G2 | Pass | ICMP (Echo Request) | `NET_GARRISON` | any | – | – | Users may ping |
| G3 | Pass | TCP | `NET_GARRISON` | `H_WEB01` | `P_WEB` | – | Users visit the Marketplace |
| G4 | **Block** | any | `NET_GARRISON` | `NET_REALM` | any | **✔** | Users may not roam the realm |
| G5 | Pass | TCP | `NET_GARRISON` | `NET_REALM` **Invert** | `P_WEB` | – | Users browse the wider web |
| G6 | Pass | UDP | `NET_GARRISON` | `NET_REALM` **Invert** | `P_NTP` | – | Windows time sync |

**Save → Apply changes**, then delete both **Default allow LAN to any** rules (IPv4 and IPv6) and apply again.

> **Why the order matters, here:** G3 sits *above* G4. G3 says "Garrison may reach WEB01 on web ports". G4 says "Garrison may not reach *anything* inside the realm" — and WEB01 *is* inside the realm. If G4 were first, it would swallow G3 and users could no longer browse the Marketplace. Rules are first-match-wins.

### Part D — Test it

Run the matrix with the `policy` profile from all three machines:

```bash
bash segtest.sh --profile policy --wks-ip 10.20.10.100     # WEB01, then ADM01
```
```powershell
.\Test-Segmentation.ps1 -Profile policy                 # WKS01
```

Every row should **PASS**. Then re-run the raider: `bash attack-sim.sh --wks-ip 10.20.10.100` on WEB01 — most lines should now be green.

**If rows FAIL**, read the verdict column: *"expected Denied but OPEN"* means a rule is too loose or a TEMP rule survived; *"expected OPEN but DROPPED"* means a rule is missing or in the wrong order. Compare field by field with the tables above.

### Part E — The order experiment

1. On **GARRISON**, drag rule **G4** *above* **G3** (use the move/drag handle) and **Apply**.
2. On WKS01 run `Test-NetConnection 10.20.20.10 -Port 80`. It now **fails**. Check **Firewall → Log Files → Live View** and find the block.
3. Drag **G4** back *below* **G3** and **Apply**. Re-test; it works again.

### Check yourself

1. Why did we write M4 as "Block to `NET_REALM`" rather than listing every internal host?
2. What happens to a packet that matches **none** of M1–M4?
3. Rule M3 uses *Invert*. What would be wrong with using destination `any` instead?
4. The Garrison has no rule allowing it to reach the Citadel at all. Is that a rule you forgot, or intentional? What does G4's logging add if the default deny would block it anyway?
5. Which of Part B's business needs (Module 2) is **not** satisfied by the rules so far?

### Checkpoint

- `Segmentation test` output showing **all PASS** at `policy` from WEB01, ADM01, and WKS01.
- A screenshot of **Firewall → Rules → MARKET** showing the four rules, in order, with descriptions.
- Your answer to "why does G3 have to be above G4?"

---

# Module 4 — Open the Gate (publish one service safely)

**Story:** The Marketplace exists to be visited. Travellers from the Wilderness must reach the front stall — and *only* the front stall. One gate, guarded.

**Mission:** Publish WEB01's public site (ports 80 and 443) to the WAN with **destination NAT** and its matching rule, and prove that nothing else is reachable.

**You'll learn:** destination NAT · the NAT-rule-plus-filter-rule pair · publishing the minimum · source addresses surviving inbound NAT.

### How publishing works (read this first)

From the outside, WEB01 has no address — its `10.20.20.10` exists only inside. Visitors aim at the **firewall's WAN address**. Two things must then happen:

1. **Destination NAT:** *"traffic arriving on my WAN address, TCP port 80, should be rewritten to go to 10.20.20.10, port 80."*
2. **A filter rule on the WAN:** *"yes, traffic to 10.20.20.10 port 80 is allowed in."*

NAT only **rewrites**; it never permits. OPNsense can create the filter rule for you when you tick **Add associated filter rule** — which is the default, and what we'll use. If the NAT rule exists but the filter rule doesn't, the site is silently unreachable.

### Steps

1. **Snapshot FW01** as `04-before-publish`.
2. The firewall's **WAN address** is the static `10.10.10.5` you set in setup (it also shows on the FW01 console menu and under **Interfaces → Overview**). Call it `WAN_IP`; in the commands below, replace `WAN_IP` with `10.10.10.5`.
3. **Firewall → NAT → Destination NAT** (older releases: **Port Forward**). Click **+ Add**:

| Field | Value |
|---|---|
| Interface | `WAN` |
| TCP/IP Version | `IPv4` |
| Protocol | `TCP` |
| Source | `any` |
| Destination | `WAN address` |
| Destination port range | `HTTP` to `HTTP` (80 to 80) |
| Redirect target IP | `H_WEB01` (the alias; or type `10.20.20.10`) |
| Redirect target port | `HTTP` |
| Description | `Publish WEB01 web (HTTP)` |
| Filter rule association | `Add associated filter rule` |

   **Save.** Repeat for **HTTPS** (443 → 443, description `Publish WEB01 web (HTTPS)`). Then **Apply changes**.

4. **Look at what OPNsense created.** **Firewall → Rules → WAN**: you should see two *Pass* rules (one per port) from `any` to `10.20.20.10` (written either as an alias or a literal IP), with the NAT descriptions. *You did not write those by hand* — the "associated filter rule" did. (You may see them shown in an "automatic" or "NAT" group, depending on version.)

5. **Test it from the outside.** On **WATCHTOWER**:

   ```bash
   curl -sI http://WAN_IP/ | head -1            # HTTP/1.1 200 OK
   curl -sk https://WAN_IP/ | grep -i marketplace
   ```

   (Replace `WAN_IP`.) You should see the Marketplace page.

6. **Prove nothing else is exposed.** Still on WATCHTOWER, probe the unpublished ports. These should **time out** (silence = the default deny on the WAN):

   ```bash
   for p in 22 8080; do
     timeout 3 bash -c "exec 3<>/dev/tcp/WAN_IP/$p" 2>/dev/null && echo "$p OPEN" || echo "$p closed/filtered"
   done
   ```

   Port **8080** is the web server's admin panel. It's alive on WEB01 — and it is **not** reachable from the Wilderness, because you published only 80 and 443. *That* is the whole point of the Market zone.

7. **See the conversation.** On WATCHTOWER run `curl -s http://WAN_IP/ >/dev/null` in a loop (`while true; do curl -s -o /dev/null http://WAN_IP/; sleep 1; done`) and, on FW01, open **Firewall → Diagnostics → States**. Filter on `10.20.20.10`. You'll see the state with *both* addresses: the one WATCHTOWER used (the WAN address) and the one the firewall rewrote to (WEB01).
8. **Check the source address WEB01 sees.** On WEB01:

   ```bash
   sudo tail -n 3 /var/log/nginx/access.log
   ```

   The client address in each line is **`10.10.10.30`** — WATCHTOWER's real address. Inbound NAT rewrote the *destination* only; WEB01 sees who is really calling. That matters for logging, rate limiting and incident response.

### Check yourself

1. Which two firewall objects make a published service work, and which one does the *permitting*?
2. Why did port 8080 fail from WATCHTOWER even though nginx on WEB01 is listening on it?
3. What source address did WEB01 log, and why is that good for you as a defender?
4. If someone later "just publishes 22 so I can SSH in from home", what are you giving up? (Think about the blast radius from Module 1.)

### Checkpoint

- `curl` from WATCHTOWER returning the Marketplace page through the WAN address.
- The probe of 22/8080 showing *closed/filtered*.
- The State table line showing the translation.

---

# Module 5 — Prove the Walls (evidence, not hope)

**Story:** A wall that has never been tested is a rumour. The Watch Captain wants proof — what was allowed, what was refused, and exactly *how* it was refused.

**Mission:** Verify the policy three independent ways — the test matrix, the firewall's own log and state table, and packet captures — and *see* the difference between Block and Reject.

**You'll learn:** reading the live firewall log · tying a log line to a rule · the state table · capturing on the firewall · Block vs Reject on the wire.

### Part A — The test matrix, once more, from everywhere

Run `policy` mode again from **WEB01, ADM01 and WKS01**, now that Module 4's NAT exists. Save the outputs. They should all PASS.

### Part B — Find your own blocked probe in the log

1. On **FW01 → Firewall → Log Files → Live View**. Optionally filter (the filter fields at the top) so the *Action* is `block`.
2. On WKS01 (PowerShell) deliberately trip a rule:

   ```powershell
   Test-NetConnection 10.20.30.10 -Port 22     # the Garrison trying to reach the Citadel
   ```
3. A new line appears: time, **interface** (`GARRISON`), **source** (WKS01), **destination** (`10.20.30.10`), **port 22**, **action** `block`. Click the **info (i)** icon on the line: it shows the **rule that decided** — your description `Users may not roam the realm`. *This is why we write descriptions.*
4. Do the same from WEB01: `curl --max-time 3 http://10.20.30.10/` — find the `MARKET` / `A compromised DMZ host must not reach inside` line.

### Part C — The state table

1. From **ADM01**, open an SSH session to WEB01 (allowed by rule C4) and **leave it open**:

   ```bash
   ssh gatekeeper@10.20.20.10
   ```
2. On FW01 → **Firewall → Diagnostics → States**, filter on `10.20.20.10`. Find the **TCP** state, `ESTABLISHED:ESTABLISHED`, from `10.20.30.10` to `10.20.20.10:22`. That entry is why replies flow back without a rule: it was created when ADM01's first packet was allowed.
3. Close the SSH session (`exit`), refresh States, and watch the entry age out.

> **Console alternative:** FW01 console → option **8** (Shell) → `pfctl -ss | grep 10.20.20.10`. Type `exit` to leave the shell.

### Part D — Block vs Reject, on the wire

1. On **WKS01**, open **Wireshark** (from the Packet Watch lab) and start capturing on the Ethernet interface. Set a display filter: `ip.addr == 10.20.30.10 && tcp.port == 22`.
2. Run `Test-NetConnection 10.20.30.10 -Port 22`. In Wireshark you'll see **repeated SYN packets, spaced further apart, and no reply at all** — that is a *Block* (drop). The client keeps retrying until it gives up. Note how many SYNs and the gaps between them (*View → Time Display Format → Seconds Since Previous Displayed Packet*).
3. On FW01 → **Firewall → Rules → GARRISON**, edit rule **G4** and change **Action** to **Reject**. Save, **Apply**.
4. Clear Wireshark, run the same `Test-NetConnection` again. Now you see **one SYN, immediately answered by `RST, ACK`** — the connection fails *instantly*.
5. **Change G4 back to Block**, Save, Apply. (Block is the right default for untrusted sides; Reject is a kindness for internal users — you decide per zone.)

### Part E — Capture on the firewall itself

1. FW01 → **Interfaces → Diagnostics → Packet Capture**. Interface: `GARRISON`. *Host Address:* `10.20.30.10`. *Count:* `100`. Click **Start**.
2. Repeat the blocked probe from WKS01.
3. Click **Stop**, then **Download capture** and open the `.pcap` in Wireshark on WKS01. You'll see the same SYNs — arriving at the firewall's Garrison interface and getting nowhere. *The capture shows the packet arriving even though it never leaves: a firewall decides after it receives.* (Module 8's IDS relies on exactly that.)

### Part F — The "too loose" experiment

Defenders test the *bad* case too, so a failed test tells them something:

1. On **MARKET**, add a rule *above* M4: **Pass**, protocol `any`, source `NET_MARKET`, destination `any`, description `OOPS - too broad`. Apply.
2. Run `bash segtest.sh --profile policy` on WEB01. Several rows now **FAIL** with *"expected Denied but OPEN"*. That is what a mistake looks like in the matrix.
3. Delete the `OOPS` rule, Apply, and confirm it's back to all PASS.

**Habit to keep:** after *any* rule change, run the matrix. A test that passes before and after proves you changed nothing you didn't mean to.

### Check yourself

1. What did the **Live View** line for your blocked probe tell you that the client's *"TcpTestSucceeded: False"* did not?
2. How did the Block and Reject captures differ — packet count, timing, and what the client would *show a user*?
3. Why is *Block* the better default for the DMZ and WAN, and *Reject* acceptable for the Garrison?
4. In Part E, the capture saw the blocked packets. What does that imply about where an IDS sees traffic compared to where the firewall enforces?

### Checkpoint

- Matrix outputs from the three machines (all PASS).
- A screenshot of the Live View showing a blocked line *with the rule description*.
- Two Wireshark screenshots: Block (silence) and Reject (instant RST).

---

# Module 6 — Guard the Gatehouse (harden the firewall itself)

**Story:** The walls are strong — but the gatehouse's own front door still opens to anyone in the Garrison. Whoever controls the firewall controls the realm. Move the keys into the Citadel.

**Mission:** Make the firewall's **management plane** (web GUI and SSH) reachable **only from the Citadel**, reach it through a **jump host**, and add basic device hardening.

**You'll learn:** the management plane as an attack surface · the anti-lockout rule · jump hosts / SSH tunnelling · restricting listen interfaces · config backups.

> ⚠️ **This is the module most likely to lock you out.** Take the snapshot. Do the steps *in order*. Do not disable anything until the step that says to. A recovery recipe is at the end.

### Why this matters

Right now any workstation in the Garrison can open `https://10.20.10.1` and try passwords against the firewall. A compromised user PC then becomes a *firewall* compromise. Real networks give management access only to a dedicated, hardened admin network — the **management plane** is separated from the **data plane** (user traffic).

### Part A — Prepare

1. **Snapshot FW01** as `06-before-mgmt`. (Also snapshot ADM01 if you like.)
2. **Back up the configuration**: **System → Configuration → Backups → Download configuration**. Keep the XML file. If everything goes wrong you can restore from the console (see *Recovery*).

### Part B — Build the jump-host path first

The Citadel is where admins *should* be, but ADM01 has no desktop to run a browser. So we use the standard real-world solution: from your workstation, **SSH to the jump host (ADM01)** and **tunnel** your browser through it to the firewall's GUI. Only ADM01 — not the whole Garrison — gets that one door.

1. **Create an alias** (Firewall → Aliases): `H_WKS01` — Host(s) — `10.20.10.100` — *Garrison admin workstation*. Apply.
   (If WKS01's address isn't `.100`, use its real address.)
2. **Add a rule on GARRISON**, placed **above G4** (above the block): 

| Action | Protocol | Source | Destination | Dest. port | Log | Description |
|---|---|---|---|---|---|---|
| Pass | TCP | `H_WKS01` | `H_ADM01` | `P_SSH` | ✔ | Admin workstation SSHs to the jump host |

   Apply. This is a deliberate, narrow hole in the "Garrison can't reach the Citadel" wall — **one host, one port, logged** — which is how well-run networks do it.
3. **From WKS01** (PowerShell), open the tunnel — it forwards your local port 8443 to the firewall's GUI *as seen from ADM01*:

   ```powershell
   ssh -L 8443:10.20.30.1:443 gatekeeper@10.20.30.10
   ```

   Answer `yes` to the host-key question the first time, then enter ADM01's password. **Leave this window open** — closing it closes the tunnel.
4. In a browser on WKS01 open **`https://127.0.0.1:8443`** (accept the certificate warning) and log in. You are now managing the firewall *from the Citadel's point of view*.

> **"Potential DNS Rebind attack detected" or a referrer error?** OPNsense refuses to answer requests whose address it doesn't recognise. Use `127.0.0.1` rather than `localhost`. If it still complains, go to **System → Settings → Administration** and add `127.0.0.1` / `localhost` to **Alternate Hostnames** (do this *now*, while you can still reach the GUI the old way), and try again.

**Do not continue until you can log in through the tunnel.**

### Part C — Lock the doors

1. **System → Settings → Administration → Web GUI**: set **Listen Interfaces** to **CITADEL** only. **Save.** (The GUI restarts. Your direct session from the Garrison drops; the tunnel session should still work — refresh the page at `https://127.0.0.1:8443`.)
2. **Firewall → Settings → Advanced** → tick **Disable anti-lockout**. **Save**, **Apply**. (That hidden rule was the thing allowing the *Garrison* in. With it gone, only rule C1 lets anyone reach the GUI — and C1 is Citadel-only.)
3. **Verify the lock.** From WKS01, try to browse straight to `https://10.20.10.1`. It should now **time out** and the attempt should show in **Firewall → Log Files → Live View** as a block by `Users may not roam the realm`.
4. Confirm you *can* still manage the firewall through the tunnel.

### Part D — SSH and accounts (recommended)

1. On **ADM01**, make an SSH key (press Enter for the defaults; a passphrase is good practice):

   ```bash
   ssh-keygen -t ed25519
   cat ~/.ssh/id_ed25519.pub
   ```
2. In the GUI: **System → Access → Users → +**. Create a user named `gatekeeper-admin`, a strong password, add it to the **admins** group, set **Login shell** to `/bin/sh` (the default can't log in), and paste the **public key** into the *Authorized keys* field. **Save.**
3. **System → Settings → Administration → Secure Shell**: tick **Enable Secure Shell**, set **Listen Interfaces** to `CITADEL`, **untick** *Permit root user login*, and **untick** *Permit password login*. **Save.**
4. From ADM01 test it: `ssh gatekeeper-admin@10.20.30.1`. You should get a shell with **no password prompt**.
5. Try the same from WEB01 — it should fail (the firewall won't even answer: WEB01 is in the Market).

> **Menu names drift.** If you can't find a field, use the search box at the top of the GUI.

### Part E — A few more cheap wins

- **System → Settings → Administration → Session Timeout:** set something short (for example 15 minutes) so an unattended browser tab logs itself out.
- **System → Settings → General:** confirm the hostname/domain and that the **timezone** is right (accurate time matters for logs).
- **Interfaces → [each]:** confirm *IPv6 Configuration Type* is `None` (this lab is IPv4-only).
- **Take a fresh configuration backup** (as in Part A). Name it with the date.

### Part F — Verify

Run the **`mgmt`** profile:

```bash
bash segtest.sh --profile mgmt --wks-ip 10.20.10.100        # WEB01, then ADM01
```
```powershell
.\Test-Segmentation.ps1 -Profile mgmt                    # WKS01
```

The two rows that change from `policy` to `mgmt`: from WKS01 the **firewall web GUI** is now *Denied*, and **ADM01 SSH** is now *Open* (the single jump-host rule). Everything else is unchanged and should PASS.

### Recovery — if you locked yourself out

1. **Restore the snapshot** `06-before-mgmt` on FW01 (fastest), **or**
2. On the FW01 **console**, choose option **13** *(Restore from backup)* and pick a previous configuration, **or**
3. Console option **2** (*Set interface IP address*) to re-check addresses, and option **11** (*Reload all services*), **or**
4. Console option **3** to reset the root password if you forgot it.

### Check yourself

1. What exactly did the anti-lockout rule do, and why must you disable it *only after* the tunnel works?
2. Why is a jump host better than letting every admin PC reach the firewall directly?
3. What would an attacker who compromised WKS01 need to do *now* to reach the firewall's GUI?
4. Why turn off both password login and root login for SSH?

### Checkpoint

- `https://10.20.10.1` timing out from WKS01, with the matching block in the log.
- The GUI working through the tunnel at `https://127.0.0.1:8443`.
- `Test-Segmentation.ps1 -Profile mgmt` (and the Linux tests) all PASS.
- A saved configuration backup.

---

# Module 7 — Close the Roads (egress and DNS control)

**Story:** The raider can't walk in any more — but he can still shout out. A compromised Marketplace server that can call any server on the internet can be told what to do, and can smuggle the realm's secrets out. The roads leaving the realm must be watched as closely as the ones entering.

**Mission:** Tighten what WEB01 may fetch (an **allow-list**), stop command-and-control callbacks, and block bad domains at the DNS resolver.

**You'll learn:** egress filtering · FQDN aliases and their caveats · DNS as a control point · what your IDS and firewall *can't* see (DoH).

### Why egress matters more than people think

Almost all malware needs to **call home** — to get instructions (command and control), to download more tools, or to send stolen data out. Inbound rules rarely stop a determined attacker; **outbound rules often stop the damage.** Right now WEB01 may reach *any* web server on the internet (rule M3). A web server needs far less than that — it needs its package repositories, and little else.

### Part A — Snapshot and baseline

1. **Snapshot FW01** as `07-before-egress`.
2. On **WEB01** run `bash segtest.sh --profile mgmt --wks-ip 10.20.10.100` (all PASS). Keep this as your *before*.
3. Make sure WATCHTOWER's :4444 listener is running (Module 1, step 3).

### Part B — An allow-list of repositories

1. Find which hosts WEB01 uses for updates: on WEB01
   ```bash
   grep -rhE '^(URIs|deb)' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
   ```
   You'll see hostnames such as `archive.ubuntu.com` and `security.ubuntu.com` (yours may differ — use what *your* output shows).
2. **Firewall → Aliases → +**: name `H_UBUNTU_REPOS`, type **Host(s)**, content: one hostname per line (`archive.ubuntu.com`, `security.ubuntu.com`, plus any others you found). Description `Ubuntu package mirrors`. Save, Apply.

   > **A hostname alias is resolved by the firewall into IP addresses** and refreshed on a timer. That's powerful and fragile: big mirrors sit behind many changing addresses, so a rule built on a hostname can occasionally miss one. It's a good **teaching** control and an acceptable lab control; for production you'd more likely use a proxy that filters by name.
3. **Firewall → Rules → MARKET.** Edit **M3**: change **Destination** from `NET_REALM` (invert) to **`H_UBUNTU_REPOS`** (no invert), keep port `P_WEB`, and change the description to `WEB01 may reach the package mirrors only`. Save, Apply.
4. **Test from WEB01:**
   ```bash
   sudo apt-get update                     # works — the repositories are allowed
   curl -sI --max-time 5 https://example.com   # fails — not on the list
   ```
   If `apt-get update` partly fails, you've met the FQDN-alias caveat: add the extra hostnames it complained about to the alias, or wait a few minutes for the alias to refresh and retry.

### Part C — Stop the callback

1. On **WEB01**, with WATCHTOWER's :4444 listener running:
   ```bash
   timeout 3 bash -c 'exec 3<>/dev/tcp/10.10.10.30/4444' && echo "C2 REACHED" || echo "C2 blocked"
   ```
   You should see **C2 blocked**. Before this module, the same line printed *C2 REACHED*. Find the block in **Live View**.
2. Run `bash attack-sim.sh --wks-ip 10.20.10.100` again and compare to Module 1.

### Part D — DNS as a control point

DNS is where almost every connection starts. The firewall's built-in resolver (**Unbound**) can refuse to answer for bad domains.

1. **Services → Unbound DNS → Blocklist** (a tab on the Unbound page). Tick **Enable**.
2. Choose a *Type of DNSBL* — a published blocklist — if you like (pick one small list). More important for this exercise, add a **custom blocked domain**: `example.org` in the field for custom domains to block (the label reads something like *Blocklist Domains*). **Save**, then **Apply**.
3. **Test from WKS01:**
   ```powershell
   nslookup example.com        # answers normally
   nslookup example.org        # blocked: 0.0.0.0, an empty answer, or NXDOMAIN
   ```
4. To *see* queries, enable query logging (**Services → Unbound DNS → Log**, tick *Log queries*) and look at **Reporting → Unbound DNS** or the **Log File** tab.

### Part E — What about DNS to someone else's resolver?

On WKS01, try to bypass the firewall's DNS:

```powershell
nslookup example.org 8.8.8.8
```

It **times out**. Why? The Garrison's rules (G1) allow DNS **only to `This Firewall`**. Anything else on port 53 falls through to the default deny. *The default-deny rule base is already doing DNS egress control.* (The raider's DNS exfiltration test, Module 1 step 4, was blocked by the same logic.)

> **Optional — transparent redirect.** Some devices (cameras, TVs) hard-code a public resolver and fail when it's blocked. A **destination NAT rule on GARRISON** (*Firewall → NAT → Destination NAT*: source `NET_GARRISON`, destination *invert* `GARRISON address`, ports 53, redirect to `127.0.0.1` port 53) quietly sends such queries to your resolver instead. It's a kindness and a control: they get answers — *your* answers, blocklist included.

### Part F — Know the limits

- **DNS over HTTPS (DoH)** carries DNS inside ordinary HTTPS (port 443). Our Garrison *does* allow web on 443, so a browser configured for DoH to a public resolver would bypass your blocklist. Mitigations: block known DoH resolver addresses, deploy browser policy, or inspect TLS.
- **DNS over TLS (port 853)** is already denied by the default-deny.
- **QUIC** (HTTP/3 over UDP 443) isn't allowed either; browsers quietly fall back to TCP.

### Part G — Verify

Run the **`hardened`** profile everywhere:

```bash
bash segtest.sh --profile hardened --wks-ip 10.20.10.100       # WEB01, then ADM01
```
```powershell
.\Test-Segmentation.ps1 -Profile hardened                   # WKS01
```

Expected differences from `mgmt`: from WEB01, **WATCHTOWER web** and **public internet HTTPS** now fail. (Garrison and Citadel are unchanged.) The `Ubuntu package mirror` row should still PASS — if it flickers, revisit the FQDN-alias caveat.

### Check yourself

1. Why is controlling **outbound** traffic at least as valuable as controlling inbound?
2. Why does M3 now name *destinations* rather than *"anything outside the realm"*? What could go wrong with a hostname alias?
3. Which two controls stopped `nslookup example.org 8.8.8.8`, and which stopped `nslookup example.org`?
4. Name two ways an attacker could still get data out of the Market after this module. (Hint: what's still allowed from the Garrison and Citadel? What *is* still allowed from WEB01?)

### Checkpoint

- `apt-get update` working on WEB01 while `curl https://example.com` fails.
- A *C2 blocked* result and the matching Live View entry.
- `nslookup example.org` blocked and `example.com` answering on WKS01.
- The `hardened` matrix, all PASS.

---

# Module 8 — The Siege (watch, detect, and test your own walls)

**Story:** Walls hold until someone finds the weak stone. The Watch Captain posts lookouts: every blocked step is written in the ledger, the Market has a sentry who shouts at suspicious scouts, and then — to be sure — you send a raider at your own defences.

**Mission:** Ship logs to a central collector, run an **intrusion detection system** (IDS) on the DMZ, then run an **assume-breach exercise** against your finished design and write the assessment report.

**You'll learn:** central logging (syslog) · IDS versus firewall · why *seeing* is as important as *blocking* · evidence-driven reporting · reviewing a rule base for flaws.

### Part A — Central logging to the Citadel

Logs stored only on the firewall disappear if the firewall is wiped — which is the first thing a careful intruder tries. So ship them to the log keeper, ADM01.

1. **Snapshot FW01** as `08-before-logging`.
2. On **FW01 → System → Settings → Logging → Targets** (older releases call this tab **Remote**). Click **+ Add**:

| Field | Value |
|---|---|
| Transport | `UDP (IPv4)` |
| Applications | the firewall's filter log (`filter` / `filterlog`) and `audit` — or leave empty to send everything |
| Levels | `Info` and above (or leave all) |
| Hostname / IP | `10.20.30.10` |
| Port | `514` |
| Description | `Ship logs to ADM01` |

   **Save**, then **Apply**.
3. **Watch them arrive.** On **ADM01**:

   ```bash
   sudo tail -f /var/log/remote/10.20.30.1.log
   ```

   Lines scroll as the firewall logs. (`10.20.30.1` is the firewall's Citadel address, which is the sender ADM01 sees.) Trip a block from WKS01 (`Test-NetConnection 10.20.30.10 -Port 8080`) and watch a `block` line for it appear within seconds. **Ctrl+C** to stop.

   > *Nothing arriving?* The firewall's own traffic needs no rule to leave. Check ADM01 is listening (`sudo ss -lun | grep :514`) and that the Targets entry is **Enabled** and applied.
4. **Ship WEB01's own logs too — with a deliberately narrow hole.** WEB01 is in the Market; the Market may not reach the Citadel. A *logging* flow is a legitimate exception, but it should be exactly one host, one port, one protocol:
   - **Firewall → Rules → MARKET**, add a rule **above M4**: **Pass**, protocol `UDP`, source `H_WEB01`, destination `H_ADM01`, destination port `514`, **Log ✔**, description `WEB01 ships logs to the collector`. Apply.
   - On **WEB01**:
     ```bash
     echo '*.* @10.20.30.10:514' | sudo tee /etc/rsyslog.d/90-forward.conf
     sudo systemctl restart rsyslog
     logger -t gatehouse "hello from web01"
     ```
   - On **ADM01**: `sudo tail /var/log/remote/10.20.20.10.log` shows your message.

   > **Think like an attacker:** a compromised WEB01 can now send UDP to exactly one place. Is that a risk worth the benefit? (The answer key discusses it.)

### Part B — An intrusion detection sentry

A firewall decides on **addresses and ports**. An **IDS** (Intrusion Detection System) reads packets for **suspicious behaviour** and raises an alert. OPNsense includes **Suricata**. We'll run it in **IDS mode** (alert, don't block) on the Market interface, where the compromised server lives.

> **RAM check:** Suricata with the full rule set wants more than 2 GB. We'll enable only the scan rules, which is fine at 2 GB; if FW01 becomes sluggish, give it 4 GB (power off, *Settings → System*).

1. **Snapshot FW01** as `08-before-ids`.
2. **Services → Intrusion Detection → Administration → Settings** tab:
   - **Enabled:** ✔
   - **IPS mode:** **un**ticked — IDS only. (IPS mode blocks inline, but depends on special network-driver support that VirtualBox adapters handle inconsistently; for learning, detection is what matters.)
   - **Promiscuous mode:** unticked
   - **Interfaces:** `MARKET`
   - **Home networks:** the realm — the default private ranges are fine
   - **Save**
3. **Download** tab: find the **ET open / emerging-scan** ruleset, tick it, click **Enable selected**, then **Download & Update Rules**. Wait for it to finish.
4. Back on the **Settings** tab click **Apply** to start the service. On the **Rules** tab, the scan rules should show as enabled. *(If they show disabled, create a rule on the **Policy** tab: select the `emerging-scan` ruleset, set the action to `Alert`, Save and Apply.)*
5. **Generate something to detect.** On **WEB01**, run the raider with its optional **nmap** step (a standard TCP SYN scan):

   ```bash
   sudo bash attack-sim.sh --nmap --wks-ip 10.20.10.100
   ```
6. **Services → Intrusion Detection → Administration → Alerts** tab → click **Refresh**. You should see one or more alerts whose signatures begin **`ET SCAN`**, with source `10.20.20.10` and the scanned hosts as destinations.

   > **No alerts?** Give it a minute and refresh. Confirm the **MARKET** interface is selected and the service is running (the Settings tab shows its status). If the scan signatures in your downloaded ruleset differ from what your nmap sends, scan more ports: `sudo nmap -sS -p 1-1000 10.20.10.100`.

**Why can the IDS see attempts the firewall *blocked*?** Because the sentry reads the packets arriving on the Market interface *before* the firewall's rules turn them away (you saw the same effect in Module 5, Part E). A blocked scan is still *information*: someone inside the DMZ is behaving like an attacker.

### Part C — The assume-breach exercise (capstone)

Assume the raider has full control of WEB01. Test the finished design.

1. **Reset to the finished state.** Confirm `hardened` mode passes everywhere (Module 7 Part G). Fix anything that fails before you start — a fire drill on a broken wall tells you nothing.
2. On WATCHTOWER make sure the :4444 listener is running.
3. On **WEB01** run the raider and **save the output**:
   ```bash
   sudo bash attack-sim.sh --nmap --wks-ip 10.20.10.100 | tee ~/raider-final.txt
   ```
4. **Hunt for the evidence of each step.** Complete a table with one row per raider action — for example *Garrison workstation 8080*, *Citadel SSH*, *firewall GUI on three interfaces*, *C2 callback*, *DNS to 8.8.8.8*, *nmap scan*:

   | Raider action | Outcome | Rule that stopped it | Firewall log line | Seen on ADM01 syslog? | IDS alert? |
   |---|---|---|---|---|---|

   Where to look: **Live View** for the rule description; **ADM01**: `sudo grep 10.20.20.10 /var/log/remote/10.20.30.1.log | grep -i block | head`; **Alerts** for the IDS.
5. **Check you haven't broken the business.** The point of a firewall isn't to stop *everything* — it's to stop the *wrong* things:
   - From WATCHTOWER: `curl -sI http://WAN_IP/` still returns the Marketplace.
   - From WKS01: the public site loads, other websites load, and `nslookup example.com` works.
   - From ADM01: `ssh gatekeeper@10.20.20.10` works and `sudo apt-get update` works.
6. **Write down what a *smart* raider would try next.** Pick two techniques your design does not stop and say *why* (hint: what traffic *is* allowed from WEB01 — and to where? What could a raider do with DNS to the firewall, or with the logging hole in Part A?).

### Part D — The assessment report

Write a short report (1–2 pages, in your Public Learning Log repo). Use this skeleton:

```
# Network Segmentation Assessment — The Realm

## 1. Summary
Two or three sentences: what the network looked like, what you changed, what the result is.

## 2. Scope and method
Zones, hosts, tools used (test matrix, raider simulator, firewall log, IDS).

## 3. Before and after
Table: the Module 1 attack-sim results versus the Module 8 results.
Include counts: attempts / succeeded before / succeeded after.

## 4. The policy
The zone-to-zone matrix, final rule base per zone (one line per rule with its business reason).

## 5. Evidence
The evidence table from Part C. A short paragraph on what the IDS added that the firewall alone did not.

## 6. Residual risk
At least four. Examples to consider: the Garrison→Citadel jump-host hole;
the WEB01→ADM01 logging hole; DoH; FQDN aliases; a single firewall (one failure = no network);
traffic *within* a zone never crosses the firewall; UDP and IPv6 untested; IDS only alerts.
For each: likelihood, impact, and what you'd do about it.

## 7. Recommendations
Ranked, with effort estimates.
```

### Part E — Audit someone else's rule base (paper exercise)

You're shown these rules from a "real" firewall. For each, say what is wrong and how you'd fix it. (Think: scope, order, logging, hygiene.)

| # | Interface | Action | Protocol | Source | Destination | Port | Log | Description |
|---|---|---|---|---|---|---|---|---|
| R1 | WAN | Pass | any | any | any | any | – | `vendor access temp` |
| R2 | MARKET | Pass | any | `NET_MARKET` | any | any | – | `web updates` |
| R3 | GARRISON | Pass | TCP | `NET_GARRISON` | `NET_CITADEL` | 1–65535 | – | `finance needs it` |
| R4 | WAN | Pass | TCP | any | `10.20.20.10` | 8080 | – | `admin panel for contractor` |
| R5 | CITADEL | Pass | any | any | any | any | – | *(blank)* |
| R6 | GARRISON | Pass | any | `NET_GARRISON` | any | any | – | `users` — *then, below it:* Block `NET_GARRISON` → `NET_CITADEL` |
| R7 | MARKET | Pass | UDP | any | any | 53 | – | `DNS` |
| R8 | *(all)* | Block | – | – | – | – | **off** on every block | *25 disabled rules, none with descriptions* |

Compare with the **Answer Key** when done.

### Check yourself

1. Which gave you *more* information about the raider — the firewall log or the IDS alert? What did each *miss*?
2. Why is logging to a **different** machine in a **different** zone more valuable than logging locally?
3. Name one thing in your own final design that you'd change in production, and why you accepted it in a lab.
4. A colleague says "we have a firewall, so we don't need an IDS." Write a two-sentence reply.

### Checkpoint

- Firewall logs arriving on ADM01 (a line you caused yourself).
- At least one `ET SCAN` alert from the IDS.
- Your raider output saved from before (Module 1) and after (Part C).
- The completed assessment report and your audit notes for R1–R8.

---

# Wrapping up

You started with a flat network where one compromised web server reached everything. You finish with four defended zones, a default-deny rule base with a business reason for every rule, one carefully published service, a management plane reachable only through a jump host, controlled egress and DNS, central logging, a sentry on the DMZ, and an assessment report that backs it all up with evidence.

### Where to go next in the Network Engineer path

- **Layer 2 Attack & Defense Lab** — the zones are only as strong as the switches beneath them (ARP spoofing, rogue DHCP, VLAN hopping).
- **Harden a device to a benchmark** and **Firewall rule-base audit** — apply the Part E mindset to a configuration file.
- **Write and test detection rules** — replay the *Packet Watch* pcaps against your IDS and write your own signatures.
- **Zero Trust Access Lab** — replace "where you are" with "who you are".

### Optional extension — real VLANs

OPNsense supports 802.1Q VLANs on a single interface (*Interfaces → Other Types → VLAN*), so the three zones could share one trunk instead of three adapters. It's how most real firewalls are cabled. In VirtualBox the trunk plumbing is fiddly, so it's left as an extension for those who want it.

### Cleaning up

| I want to… | Do this |
|---|---|
| Put WKS01 back on the flat realm | Run `Setup-SegmentationLab-WKS01.ps1 -Remove` (optional), then restore its fixed address with the commands below, shut down, and set *Settings → Network → Adapter 1 → NAT Network → `GielinorNAT`*. If you used the `WKS01-gatehouse` clone, simply delete the clone; the original was never touched. |
| Reclaim disk and RAM | Delete FW01, WEB01 and ADM01 (and their disks). WATCHTOWER and WKS01 are unaffected. |
| Start the lab over | Restore every VM to its `00-flat-baseline` snapshot. |

Restore the flat-realm address (only if you changed the original WKS01 rather than a clone):

```powershell
$if="Ethernet"
Set-NetIPInterface -InterfaceAlias $if -Dhcp Disabled
New-NetIPAddress -InterfaceAlias $if -IPAddress 10.10.10.20 -PrefixLength 24 -DefaultGateway 10.10.10.1
Set-DnsClientServerAddress -InterfaceAlias $if -ServerAddresses 10.10.10.10
```

> **Don't "restore" WKS01 to `pre-gatehouse-lab` just to put it back on `GielinorNAT`** — that also discards anything else you changed on WKS01 since. Switching the adapter and the address back is enough.

---

*Found a rough edge, or a better way to explain a step? Open an issue on the repo.*
