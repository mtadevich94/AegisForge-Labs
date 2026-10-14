# Address Registry

Every network and IP address used by AegisForge labs. **Check here before you assign an address**, and add new entries here in the same change as the lab that introduces them.

## Networks

| Network | Type in VirtualBox | Range | Used by |
|---|---|---|---|
| `GielinorNAT` | NAT Network, **DHCP disabled** | `10.10.10.0/24`, gateway `10.10.10.1` | Flat realm labs; the Gatehouse's WAN side |
| `realm-garrison` | Internal Network | `10.20.10.0/24` | Gatehouse: user LAN |
| `realm-market` | Internal Network | `10.20.20.0/24` | Gatehouse: web tier |
| `realm-citadel` | Internal Network | `10.20.30.0/24` | Gatehouse: management |
| *(reserved)* | TBD | `10.30.0.0/16` | Cybersecurity phase (SOC, attack networks) |

Internal network names are **case-sensitive**. `realm-garrison` and `Realm-Garrison` are two different networks.

`10.20.0.0/16` as a whole is called `NET_REALM` in the Gatehouse firewall aliases.

## `GielinorNAT` — 10.10.10.0/24

DHCP is off on purpose, so every VM gets a **static** address and nothing drifts between sessions.

| Address | Holder | Notes |
|---|---|---|
| `10.10.10.1` | VirtualBox gateway | Default gateway for every VM on this network |
| `10.10.10.5` | **FW01** WAN | Gatehouse only |
| `10.10.10.10` | **DC01** | Domain controller and DNS for `gielinor.local` |
| `10.10.10.20` | **WKS01** | Static in the flat realm; DNS points to DC01 |
| `10.10.10.30` | **WATCHTOWER** | Ubuntu host; the "outside" machine in the Gatehouse |
| `10.10.10.40` | **SRV01** | Tiered Admin member server |
| `10.10.10.50`–`.59` | *reserved* | Additional Linux hosts |
| `10.10.10.60`–`.99` | *reserved* | Future labs. **Do not assign `.66`** (below) |
| `10.10.10.66` | *do not assign* | Appears inside the Packet Watch pcaps as a suspicious host; reusing it would confuse the exercises |
| `10.10.10.100`–`.254` | free | Scratch VMs of your own |

## Gatehouse realm — 10.20.0.0/16

| Address | Holder |
|---|---|
| `10.20.10.1` | FW01, GARRISON interface |
| `10.20.10.100`–`.199` | DHCP pool served by FW01 (WKS01 gets an address here) |
| `10.20.20.1` | FW01, MARKET interface |
| `10.20.20.10` | **WEB01** |
| `10.20.30.1` | FW01, CITADEL interface |
| `10.20.30.10` | **ADM01** |

## Standalone

| VM | Network | Access |
|---|---|---|
| Linux lab VM (AlmaLinux) | VirtualBox default NAT, not on `GielinorNAT` | Host-only access through port-forward `127.0.0.1:2222` → guest port 22 |

## Reserved for the Cybersecurity phase

| Name | Intended address | Status |
|---|---|---|
| KALI01 | within `10.30.0.0/16` | Reserved, no build card |
| SIEM01 | within `10.30.0.0/16` | Reserved, no build card |
| TARGET01 | within `10.30.0.0/16` | Reserved, no build card |

Exact addresses are assigned when the lab that builds them is written. Nothing in `10.10.x.x` or `10.20.x.x` will be renumbered to make room.

## Rules

1. One address, one VM. Never reuse a registered address for something else.
2. Static addresses only on `GielinorNAT`. If a VM can't reach `10.10.10.1`, check this table first.
3. Adding a VM means adding a row here, a row in the **Lab Fleet Catalog**, and a card in `VM Cards/`.
