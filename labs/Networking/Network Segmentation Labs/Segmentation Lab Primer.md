# The Gatehouse — Primer

*Read this once before the Environment Setup. It explains the ideas and the tools the lab uses, starting from what you already know as a network engineer.*

You already know subnets, routing, VLANs, and ACLs. This primer does three things:

1. Maps those skills onto **OPNsense**, the firewall used here, so its terms don't feel foreign.
2. Explains the **VirtualBox networking** that makes the lab's zones possible without any physical gear.
3. Gives you **just enough Linux and Windows** to follow the commands.

You do not need to memorize any of it. Keep it open as a reference — the guide links back here.

---

## 1. What a firewall really does

A **firewall** is a device that sits *between* networks and decides, packet by packet, what may cross. Everything else in this lab is detail around that one idea.

### Stateful versus stateless

An old-style router ACL is **stateless**: every packet is judged on its own, so you must write a rule for the request *and another for the reply*.

OPNsense is **stateful**. When a packet is allowed out, the firewall writes an entry into a **state table** (source, destination, ports, protocol, and a timer). Replies that match an entry are let back in automatically. You write rules only for the direction that **starts** the conversation.

> **Why this matters:** "Allow LAN to the internet on port 443" is one rule. You never write "allow the internet back to the LAN". And it means a rule is about *who may start a conversation*, which is exactly how you should think about segmentation.

Under the hood OPNsense uses **pf** (Packet Filter), the firewall from the FreeBSD/OpenBSD world. You'll occasionally see the name `pfctl` in the console. You do not need to learn pf syntax — OPNsense generates it from the rules you click together.

### A zone is just an interface

On big enterprise firewalls you define named **zones** and write zone-to-zone policy. OPNsense has **no zone object**. Instead:

- Every network segment is a separate **interface** (a physical port, a VLAN, a virtual NIC).
- You write the rules **on the interface where the traffic arrives**.

So in this lab "the Market zone" simply means "the interface the DMZ is plugged into, and the rules attached to it."

| You may know this… | In OPNsense it's… |
|---|---|
| Security zone (Palo Alto, FortiGate, ASA security-level) | An **interface** (with a friendly description such as `MARKET`) |
| Zone-to-zone policy | Rules on the **source** interface, with the destination written in the rule |
| Cisco ACL applied `in` on an interface | A rule on that interface, **direction: in** (this is what you use almost always) |
| ACL "permit/deny" | Action: **Pass / Block / Reject** |
| Object-group | An **alias** (a named list of hosts, networks, or ports) |
| "Self zone" / control-plane policy | The built-in destination **This Firewall** |
| Implicit deny at the end of the ACL | Same — and it **is** the behaviour here (with logging) |
| `permit any any` temporary rule | Same — and you will regret it, which is the first lesson of this lab |

### How rules are evaluated (the three rules of thumb)

1. **Rules are checked on the way in.** A packet entering the `GARRISON` interface is judged only by the rules on `GARRISON`.
2. **Top to bottom, first match wins.** (Almost every rule you create has *Quick* on, meaning "stop looking as soon as this matches".) **Order matters** — a broad `Block` placed above a narrow `Pass` will beat it, and vice versa.
3. **Nothing matched? Blocked.** The last, invisible rule is *default deny*. A new interface with no rules passes nothing.

### Block versus Reject

Both stop the traffic; they differ in what the sender sees.

| Action | What the sender sees | Real-world use |
|---|---|---|
| **Block** (drop) | *Nothing.* The packet vanishes; the client waits and retries until it times out. | Untrusted sides (internet, DMZ). Gives an attacker nothing, and slows scanners. |
| **Reject** | An instant TCP reset (or ICMP "unreachable"). | Trusted internal users, so a mistyped address fails fast instead of hanging. |

In this lab you will *see* the difference in a packet capture (Module 5).

### NAT, briefly

OPNsense does two kinds of address translation, and the lab uses both:

- **Destination NAT** (older name: **Port Forward**) — "traffic arriving at my WAN address on port 80 should really go to 10.20.20.10". This is how you publish a server.
- **Outbound NAT** (a form of **source NAT**) — "traffic leaving to the internet from the private zones should look like it comes from my WAN address". OPNsense sets this up **automatically**; you leave it alone.

**Important:** A NAT rule only *rewrites* an address. It does **not** permit the traffic. The matching **firewall rule** must also pass it. Forgetting that is the classic published-service-doesn't-work mistake.

### Other OPNsense words you'll meet

| Term | Plain meaning |
|---|---|
| **Alias** | A named list (hosts, networks, ports, even hostnames) you reuse in rules. Change it once, every rule updates. |
| **Anti-lockout rule** | An automatic, hidden rule that always lets the LAN reach the web GUI and SSH, so you can't accidentally block yourself. Module 6 turns it off — on purpose, carefully. |
| **State** | One live conversation tracked in memory (see above). |
| **Live View** | The real-time firewall log: every blocked (and optionally passed) packet, with the rule that decided. |
| **Unbound** | The DNS resolver built into OPNsense. It answers DNS for the zones and can block bad domains. |
| **Suricata** | The intrusion-detection engine OPNsense can run (Module 8). |
| **"Block private networks" / "Block bogon networks"** | WAN-interface checkboxes that drop traffic from private or unallocated addresses. Sensible on a real internet link. In this lab the "WAN" is itself a private network, so you turn **both off** (the guide reminds you). |
| **Apply changes** | OPNsense saves a change first and applies it second. After most edits a yellow **Apply changes** button appears — *the change is not live until you click it.* This catches everybody once. |

---

## 2. Why segment at all?

**Segmentation** means splitting a network into zones so that a break-in to one place doesn't become a break-in everywhere. The concepts you'll practice:

- **Blast radius** — how much an attacker can reach from the one machine they've compromised.
- **Lateral movement** — an attacker hopping from machine to machine, usually via ports that should never have been reachable.
- **Least privilege (for networks)** — each zone can reach *only* what it needs, on *only* the ports it needs.
- **Default deny** — start from "nothing is allowed" and add reasons, rather than start from "everything is allowed" and add exceptions.
- **Defense in depth** — the firewall isn't your only layer, but it's the layer that decides whether the *rest* even gets a chance to matter.
- **Egress control** — controlling what leaves is as important as what enters. Malware that can't phone home is largely harmless.

---

## 3. VirtualBox networking — how the zones exist without hardware

VirtualBox gives each virtual machine up to several virtual network cards ("adapters"). What matters is the **"Attached to"** setting of each adapter. These are the modes you'll use or hear about:

| Mode | What it does | Used in this lab? |
|---|---|---|
| **NAT** | Each VM gets its own private bubble with internet access. VMs **cannot** talk to each other. | No |
| **NAT Network** | Like NAT, but VMs that share the same *named* NAT Network **can** talk to each other, and all of them reach the internet. | **Yes — `GielinorNAT` is the WAN** |
| **Internal Network** | A private virtual switch, named by you (any text). VMs on the same name can talk to each other. **No internet, no host access, no DHCP.** | **Yes — one per zone** |
| **Host-only** | A private network shared with your PC (the host) only. | No |
| **Bridged** | Plugs the VM directly into your real LAN. | **Never use in this lab** |

The trick the lab relies on: an **Internal Network is just a virtual switch with a name you type.** You don't create it in advance — typing `realm-market` in two adapters puts both on the same switch. And because an internal network has *no router*, the only way one internal network can reach another is **through the VM that has a leg in both** — your firewall.

```
   [WEB01] ──── "realm-market" switch ────┐
   [WKS01] ──── "realm-garrison" switch ──┼──[ FW01 (4 adapters) ]──── "GielinorNAT" ──── internet
   [ADM01] ──── "realm-citadel" switch ───┘
```

That is the whole network: three virtual switches, one firewall, and the NAT Network as its upstream link.

**Adapter types.** Each adapter also has a *type*. We use **Intel PRO/1000 MT Desktop** everywhere — it is the most widely supported and works with FreeBSD (OPNsense), Ubuntu, and Windows 11 without extra drivers.

**Promiscuous mode** (an advanced adapter setting) lets a VM see traffic not addressed to it. You don't need it here.

**Snapshots.** VirtualBox can freeze a VM's state (disk and memory) so you can roll back. You'll take snapshots before risky steps. In VirtualBox: select the VM → *Snapshots* (top right) → *Take*. *Restore* returns you to that point. It is the single best safety net in this lab.

---

## 4. Just enough Linux (WEB01 and ADM01)

The two servers run **Ubuntu Server**, which has no desktop — you type commands at a text console. You do not need to be a Linux expert; these are the only commands the lab uses.

| Command | What it does |
|---|---|
| `sudo <command>` | Run one command with administrator rights. You'll be asked for your password the first time. |
| `ip a` (or `ip -br a`) | Show network interfaces and IP addresses. Like `ipconfig`. |
| `ping -c 3 10.20.20.1` | Send 3 pings. (Linux pings forever without `-c`; press **Ctrl+C** to stop.) |
| `ss -tlnp` | List **listening** TCP ports and which program owns them. `ss -lun` for UDP. |
| `curl -I http://10.20.20.10` | Fetch just the headers of a web page. Handy for "can I reach this?" Add `--max-time 5` to give up sooner. |
| `nslookup example.com 10.20.20.1` | Ask a specific DNS server for an address. |
| `dig @10.20.20.1 example.com` | Same, more detail. |
| `sudo tcpdump -ni any host 10.20.20.10` | Show live packets matching a host. **Ctrl+C** to stop. |
| `systemctl status nginx` | Is the web server running? `sudo systemctl restart nginx` restarts it. |
| `less <file>` | Read a file; **q** quits, **/word** searches. |
| `nano <file>` | A simple text editor. **Ctrl+O, Enter** saves; **Ctrl+X** exits. |
| `ssh user@10.20.30.10` | Open a remote shell on another machine. |

Other things worth knowing:

- **Paste into the console.** A VirtualBox VM console doesn't always accept the clipboard. Either type commands, or — easier — use `ssh` from WKS01's PowerShell, where copy/paste works normally.
- **netplan** is Ubuntu's network configuration. The setup script writes `/etc/netplan/60-gatehouse-lab.yaml` for you. You never edit it by hand in this lab.
- **Tab** completes commands and filenames. **Up arrow** recalls the previous command.

## 5. Just enough Windows (WKS01)

- **Run PowerShell as administrator:** Start → type `PowerShell` → right-click → *Run as administrator*.
- **Run a script you downloaded:** `powershell -ExecutionPolicy Bypass -File .\ScriptName.ps1`. (Windows blocks unsigned scripts by default; this flag allows it for one run.)
- **Check your address:** `ipconfig`. **Renew DHCP:** `ipconfig /release` then `ipconfig /renew`.
- **Test a port:** the lab's `Test-Segmentation.ps1` does this for you. By hand: `Test-NetConnection 10.20.20.10 -Port 80`. (Failures take about 20 seconds to give up — that is normal.)
- **Built-in SSH:** Windows 11 includes `ssh`, so `ssh user@10.20.30.10` works in PowerShell.
- **Wireshark** is already on WKS01 if you did the Packet Watch lab. You'll use it to watch *block* versus *reject* in Module 5.

---

## 6. A tour of the OPNsense interface

You'll manage the firewall in a web browser. Here is where things live.

**The console menu.** The firewall VM's own screen shows a numbered text menu. You use it for first-time setup and for **recovery if you lock yourself out**:

```
 0) Logout                         7) Ping host
 1) Assign interfaces              8) Shell
 2) Set interface IP address       9) pfTop
 3) Reset the root password       10) Firewall log
 4) Reset to factory defaults     11) Reload all services
 5) Power off system              12) Update from console
 6) Reboot system                 13) Restore from backup
```
*(The exact list varies a little by version, but options 1, 2, 3, 4, and 8 are there.)*

**The web GUI** has a menu down the left side and a **search box at the top**. The places you'll visit most:

| Task | Where |
|---|---|
| Rename an interface, set its IP | **Interfaces → *[interface name]*** |
| Create aliases | **Firewall → Aliases** |
| Write firewall rules | **Firewall → Rules** (pick the interface; see the note below) |
| Publish a server | **Firewall → NAT → Destination NAT** (older: *Port Forward*) |
| Settings that affect all firewall behavior | **Firewall → Settings → Advanced** |
| Watch the firewall log live | **Firewall → Log Files → Live View** |
| See live conversations (states) | **Firewall → Diagnostics → States** |
| Capture packets | **Interfaces → Diagnostics → Packet Capture** |
| DNS resolver, blocklists | **Services → Unbound DNS** |
| Where the GUI/SSH listen, timeouts | **System → Settings → Administration** |
| Remote logging | **System → Settings → Logging** |
| Intrusion detection | **Services → Intrusion Detection** |
| Back up / restore the configuration | **System → Configuration → Backups** |
| Find anything | The **search box** at the top |

> **Where the Rules screen is in different versions.** Older releases have one submenu per interface under *Firewall → Rules* (for example *Firewall → Rules → LAN*). Releases from 26.x have a single **Firewall → Rules** page with an **interface selector** at the top (and a "Rules [new]" entry during the transition in 26.1). In either layout the steps are the same: *pick the interface, then click the **+** (Add) button.* The guide writes this as **Firewall → Rules → *INTERFACE***.

**Two habits that save hours:**

1. **Save, then Apply.** Most edits need *Save* in the dialog, then the yellow **Apply changes** banner on the page. Make it a reflex.
2. **Describe every rule.** Put a short, human sentence in each rule's *Description*. Those descriptions show up in the log, which is how you'll figure out *why* something was blocked months from now.

---

## 7. Glossary

| Term | Meaning |
|---|---|
| **Alias** | Named list of hosts/networks/ports used in rules |
| **Blast radius** | What an attacker can reach after compromising one machine |
| **Block / Drop** | Silently discard a packet |
| **Bogon** | An address that should never appear on the internet (unallocated/reserved) |
| **C2 / command-and-control** | The "phone home" channel malware uses to receive orders |
| **Default deny** | Anything not explicitly allowed is blocked |
| **DMZ** | A semi-trusted zone for public-facing servers, isolated from the inside |
| **Egress** | Traffic **leaving** a zone/network |
| **Exfiltration** | Sneaking data out |
| **Ingress** | Traffic **entering** |
| **Internal Network (VirtualBox)** | A named, private virtual switch |
| **Jump host / bastion** | A hardened machine you must go *through* to reach the management zone |
| **Lateral movement** | Attacker moving from one internal machine to another |
| **Least privilege** | Allow only what's needed, nothing more |
| **Management plane** | The interfaces used to administer a device (GUI, SSH) |
| **NAT** | Rewriting source or destination addresses |
| **PAW** | Privileged Access Workstation — a locked-down admin PC |
| **pf** | The packet filter inside OPNsense/FreeBSD |
| **Reject** | Block *and* tell the sender (TCP reset / ICMP unreachable) |
| **Segmentation** | Splitting a network into zones with enforced rules between them |
| **State** | One tracked connection in the firewall's table |
| **Stateful firewall** | Remembers connections so replies don't need their own rules |
| **Syslog** | The standard way for devices to ship log messages to a central server |
| **Zone** | A group of systems with the same trust level (in OPNsense: an interface) |
| **Zero Trust** | Don't trust a connection because of *where* it comes from; verify it |

---

**Ready?** Continue to **Segmentation Lab Environment Setup.md**.
