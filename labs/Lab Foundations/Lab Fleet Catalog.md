# Lab Fleet Catalog

Every VM in the AegisForge lab environment. For build steps and verify commands, open the VM's card in `VM Cards/`. For addresses and ranges, see **Address Registry.md**.

**Status key:** ✅ built by an existing lab · 🆕 built by the Network Segmentation lab · 🕓 reserved for a later lab (name and address held, no build card yet)

## The fleet

| VM | Status | OS | RAM | Disk | Network | Address | Card |
|---|---|---|---|---|---|---|---|
| **Linux lab VM** | ✅ | AlmaLinux 10 | 2 GB | 20 GB | NAT with port-forward (standalone) | `127.0.0.1:2222` from the host | [Linux lab VM](VM%20Cards/Linux%20lab%20VM.md) |
| **DC01** | ✅ | Windows Server 2022 | 4 GB (2 GB works) | 60 GB | `GielinorNAT` | `10.10.10.10` | [DC01](VM%20Cards/DC01.md) |
| **WKS01** | ✅ | Windows 11 Enterprise | 4 GB | 60 GB | `GielinorNAT` (or `realm-garrison` for the Gatehouse) | `10.10.10.20` / DHCP in the Gatehouse | [WKS01](VM%20Cards/WKS01.md) |
| **WATCHTOWER** | ✅ | Ubuntu Server 24.04 | 2 GB | 20 GB | `GielinorNAT` | `10.10.10.30` | [WATCHTOWER](VM%20Cards/WATCHTOWER.md) |
| **SRV01** | ✅ | Windows Server 2022 | 2 GB | 50 GB | `GielinorNAT` | `10.10.10.40` | [SRV01](VM%20Cards/SRV01.md) |
| **FW01** | 🆕 | OPNsense (FreeBSD) | 2 GB (4 GB with IDS) | 12 GB | WAN `GielinorNAT` + three internal networks | WAN `10.10.10.5`; `10.20.10.1` / `.20.1` / `.30.1` | [FW01](VM%20Cards/FW01.md) |
| **WEB01** | 🆕 | Ubuntu Server 24.04 | 1 GB | 10 GB | `realm-market` | `10.20.20.10` | [WEB01](VM%20Cards/WEB01.md) |
| **ADM01** | 🆕 | Ubuntu Server 24.04 | 1 GB | 10 GB | `realm-citadel` | `10.20.30.10` | [ADM01](VM%20Cards/ADM01.md) |
| **VULN01** | ✅ | Ubuntu Server 24.04 | 4 GB | 30 GB | `GielinorNAT` | `10.10.10.50` | [VULN01](VM%20Cards/VULN01.md) |
| **KALI01** | 🕓 | Kali Linux | TBD | TBD | TBD | reserved, see registry | [Reserved](VM%20Cards/Reserved.md) |
| **SIEM01** | 🕓 | TBD (Security Onion / Elastic stack) | TBD | TBD | TBD | reserved, see registry | [Reserved](VM%20Cards/Reserved.md) |
| **TARGET01** | 🕓 | TBD (deliberately vulnerable host) | TBD | TBD | TBD | reserved, see registry | [Reserved](VM%20Cards/Reserved.md) |

> RAM figures are what each lab guide uses. Adding them up for the labs you're running at the same time gives your host budget — see the table at the bottom of **VirtualBox and GielinorNAT.md**.

## Which labs need which VMs

✔ = required. ○ = optional or only for part of the lab.

| Lab | Linux lab VM | DC01 | WKS01 | WATCHTOWER | SRV01 | FW01 | WEB01 | ADM01 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Linux Administration** (Student) | ✔ | | | | | | | |
| **Windows Administration** (Student) | | ✔ | ✔ | | | | | |
| **Packet Watch / Wireshark** (Student, Network) | | ○ | ✔ | ✔ | | | | |
| **Hardening Challenge** (Student / Systems Administration) | ✔ | ○ | ✔ | ○ | | | | |
| **Vulnerability Management Challenge** (Systems Administration) | ✔ | ○ | ○ | ○ | ○ | | | |
| **Tiered Admin** (Systems Administration) | | ✔ | ✔ | | ✔ | | | |
| **Fortifying AD** (Systems Administration, Tiered Admin part 2) | | ✔ | ✔ | ✔ | ✔ | | | |
| **Network Segmentation / The Gatehouse** (Networking) | | | ✔ | ✔ | | ✔ | ✔ | ✔ |

**Reading the table:** WKS01 is the VM most labs share, so it has the most careful card. The Gatehouse needs WKS01 only in its *minimal* state, so someone who has never built Active Directory can still do it.

## Can these labs run at the same time?

Not all of them — they compete for RAM, and two of them need WKS01 on different networks. Run one lab's VMs at a time, and use the snapshot names in the README so you can switch cleanly. The WKS01 card explains how to switch it between the flat realm and the Gatehouse.

## Reserved for the Cybersecurity phase

These names and address ranges are **held** so later labs fit without renumbering anything. They have no build steps yet; the entries are a promise, not a design.

| Name | Intended role | Why it's reserved now |
|---|---|---|
| **KALI01** | Attacker workstation for controlled testing against your own lab | Offensive-practice labs will need an attacker in the lab network |
| **SIEM01** | Central log and detection platform (the Gatehouse's `ADM01` syslog receiver is the seed) | Detection labs will consume the logs your firewall and servers already produce |
| **TARGET01** | A deliberately vulnerable host to attack and defend | Gives attack/defend labs something safe to practice on |
| *(Cybersecurity-phase subnets)* | Segments such as a SOC network and an attack network | Held in the `10.30.0.0/16` block |

New VMs get added here, in the **Address Registry**, and as a card, *in the same change* as the lab that introduces them.
