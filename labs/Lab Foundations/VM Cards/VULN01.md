# VULN01 — Vulnerability Scanner

| | |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS (check Tenable's current supported-platform list) |
| **Resources** | 4 GB RAM, 2 vCPU, 30 GB disk |
| **Network** | `GielinorNAT` |
| **Address** | `10.10.10.50/24`, gateway `10.10.10.1`, DNS `1.1.1.1` |
| **Role** | Runs Nessus Essentials (free, limited to 16 scanned addresses) |
| **Built by** | Vulnerability Management Challenge (Systems Administration) |

## Build

Follow the **Scanner Setup Guide** in `labs/Systems Administration/Vulnerability Management Challenge/`. In short: install Ubuntu Server with a static address, register for a free Nessus Essentials activation code, install the Nessus package, and let it compile its plugins.

## Ready when

- `ip -4 addr` shows `10.10.10.50`
- `systemctl is-active nessusd` returns `active`
- You can log in to `https://10.10.10.50:8834` and plugins have finished compiling

## Verify

```bash
ip -4 addr | grep 10.10.10.50 && systemctl is-active nessusd
```

## Snapshots

`post-install-clean`, `nessus-ready`.

## Notes

- Needs internet access to download Nessus and its plugins.
- Scan only machines you own.
- It's a heavier VM than most. Don't run it alongside the full fleet on a 16 GB PC.
