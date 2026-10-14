# Lab Foundations

One shared lab environment for every AegisForge roadmap. Whichever path you start on — Student, Systems Administration, Networking — you build the *same* virtual machines, on the *same* virtual networks, so everything you build carries forward into the next lab and, eventually, into the Cybersecurity phase.

You don't have to do the roadmaps in order. You do have to have the VMs a lab needs. This folder is how you find out which ones, how to build the missing ones, and how to prove they're ready.

---

## How to jump in anywhere (the 5-step routine)

1. **Set up the host once.** Read **VirtualBox and GielinorNAT.md** (install VirtualBox, create the shared `GielinorNAT` network). Skip anything you've already done.
2. **Open the lab you want** and read its **Requires** block at the top of its README. It lists the VMs and the state each must be in.
3. **Look each VM up in `VM Cards/`.** Every card has: how to build it, the address it uses, the "ready when" state, and a one-line check that proves it.
4. **Build only what's missing.** Run each check on the VMs you already have. If a check passes, you're done with that VM.
5. **Snapshot before you start**, using the naming convention below, so you can always roll back.

When you finish a lab, its **Leaves behind** block tells you what state your VMs are in — and the next lab's **Requires** block tells you what it expects. If the two don't match, the lab's setup guide tells you how to bridge the gap.

---

## What's in this folder

| File | What it is |
|---|---|
| **VirtualBox and GielinorNAT.md** | One-time host setup: VirtualBox, the shared networks, snapshots, start/stop order, RAM budgets |
| **Lab Fleet Catalog.md** | Every VM in one table, which labs use it, and a lab-by-VM requirements matrix |
| **Address Registry.md** | Every network and IP address, plus the ranges reserved for future labs — so labs never collide |
| **VM Cards/** | One page per VM: build, ready-when state, verify command, snapshot name |

## The two "eras" of the lab network

| | Flat realm | Gatehouse realm |
|---|---|---|
| **Network** | `GielinorNAT` `10.10.10.0/24` (one flat NAT Network) | `10.20.0.0/16`, four zones behind the **FW01** firewall |
| **Used by** | Linux, Windows, Packet Watch, Tiered Admin | Network Segmentation (The Gatehouse), and later network labs |
| **Idea** | Everything on one network — easy to build, easy to learn on | The same hosts moved behind a firewall — segmented, monitored, defended |

The Gatehouse deliberately *starts* from the flat realm: its Module 1 is "what does the flat network cost you?", and its WAN side **is** `GielinorNAT`. So the two eras are one environment viewed before and after the firewall goes in.

## Conventions

### Snapshot names

| Name | When |
|---|---|
| `post-install-clean` | Right after the OS install, before any lab changes (used by the Windows guides) |
| `domain-joined-clean` | After the Windows domain setup (used by the Windows guides) |
| `00-flat-baseline` | Gatehouse: all VMs built, firewall rules still wide open |
| `<lab>-start` | Before each lab's first module (for example `tiered-start`, `gatehouse-start`) |
| `<NN>-before-<thing>` | Before a risky module step (the Gatehouse guides use these) |

### Requires / Leaves behind

Every lab README opens with this block, so you never have to guess:

```
Requires:     VM name — state it must be in  (link to its card)
Leaves behind: what your VMs look like when you finish
Reset:        the snapshot to restore for a clean redo
```

### Safety rules (apply to every lab, always)

- Lab VMs live **only** on VirtualBox NAT Networks and Internal Networks. **Never bridge a lab VM to your real network.**
- Lab VMs are *deliberately* weak. Don't reuse real passwords. Never expose them to the internet.
- Read every script before you run it with `sudo` or as Administrator.
- Evaluation Windows ISOs expire (Server 180 days, Windows 11 90 days). Rebuild from your snapshots when they do.

---

## Where each roadmap enters

| You're coming from… | Minimum fleet for your first lab | Then |
|---|---|---|
| **Student** (Phase 1–2) | The Linux lab VM; **WKS01** (minimal) and **WATCHTOWER** for Packet Watch | Windows labs add **DC01** and the domain |
| **Systems Administration** | **DC01**, **WKS01** (domain-joined) | Tiered Admin adds **SRV01** |
| **Networking** | **WKS01** (minimal), **WATCHTOWER**, then build **FW01, WEB01, ADM01** | Reuses them in every later network lab |
| **All three, into Cybersecurity** | Everything above, in whatever order | Cybersecurity-phase labs reuse the whole fleet (see reserved entries in the catalog) |

Because every card defines a *minimal* state (just installed, no domain) and a *full* state (domain-joined), a network engineer never has to build Active Directory to do a network lab, and a sysadmin never has to build a firewall to do a Windows lab.
