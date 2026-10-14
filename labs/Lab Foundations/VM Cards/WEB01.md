# WEB01 — Web Server (MARKET)

| | |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS |
| **Resources** | 1 GB RAM, 1 vCPU, 10 GB disk |
| **Network** | `realm-market` |
| **Address** | `10.20.20.10/24`, gateway `10.20.20.1` (FW01) |
| **Role** | The exposed web tier; also where the attack simulator runs |
| **Built by** | Network Segmentation lab |

## Build

Follow the Gatehouse Environment Setup. Install Ubuntu Server, then run `setup-segmentation-host.sh --role web` from the lab folder.

## Ready when

- `ip -4 addr` shows `10.20.20.10`
- `curl -s localhost` returns the nginx page
- `ping -c1 10.20.20.1` succeeds (the firewall)

## Verify

```bash
ip -4 addr | grep 10.20.20.10 && curl -sI localhost | head -1
```

## Snapshots

`post-install-clean`, `gatehouse-start`.
