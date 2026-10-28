# ADM01 — Admin Host (CITADEL)

| | |
|---|---|
| **OS** | Ubuntu Server 24.04 LTS |
| **Resources** | 1 GB RAM, 1 vCPU, 10 GB disk |
| **Network** | `realm-citadel` |
| **Address** | `10.20.30.10/24`, gateway `10.20.30.1` (FW01) |
| **Role** | Management jump host; receives firewall syslog on UDP 514 |
| **Built by** | Network Segmentation lab |
| **Accounts** | `gatekeeper` (created at install, has `sudo`). See [Lab Account Standard](../Lab%20Account%20Standard.md). |

## Build

Follow the Gatehouse Environment Setup. Install Ubuntu Server, then run `setup-segmentation-host.sh --role adm`.

## Ready when

- `ip -4 addr` shows `10.20.30.10`
- `ping -c1 10.20.30.1` succeeds
- rsyslog is listening on UDP 514: `ss -ulnp | grep 514`

## Verify

```bash
ip -4 addr | grep 10.20.30.10 && ss -uln | grep :514
```

## Snapshots

`post-install-clean`, `gatehouse-start`.

## Future

ADM01's syslog receiver is the seed of the reserved **SIEM01** in the Cybersecurity phase.
