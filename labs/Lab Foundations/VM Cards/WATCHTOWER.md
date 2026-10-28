# WATCHTOWER — Ubuntu Analysis / Outside Host

| | |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS |
| **Resources** | 2 GB RAM, 1–2 vCPU, 20 GB disk |
| **Network** | `GielinorNAT` |
| **Address** | `10.10.10.30/24`, gateway `10.10.10.1` |
| **Role** | Capture and analysis host in Packet Watch; the "outside" machine in the Gatehouse |
| **Built by** | Packet Watch lab (Wireshark Labs) |
| **Accounts** | `analyst` (created at install, has `sudo`). See [Lab Account Standard](../Lab%20Account%20Standard.md). |

## Build

Follow the Packet Watch environment setup in `labs/Systems Administration/Wireshark Labs/`. In short: install Ubuntu Server, enable OpenSSH, set a static address with netplan, install the tools the lab lists.

## Ready when

- `ip -4 addr` shows `10.10.10.30`
- `ping -c1 10.10.10.1` succeeds
- You can SSH in from your host or another VM

## Verify

```bash
ip -4 addr show | grep 10.10.10.30 && ping -c1 10.10.10.1
```

## Snapshots

`post-install-clean`, then `<lab>-start`.

## Used by

Packet Watch, the Gatehouse (as the outside attacker/observer), the Detection & Beaconing Challenge (as the Suricata replay host) and, optionally, the Firewall Rule-Base Audit Challenge (to syntax-check with `nft -c`).
