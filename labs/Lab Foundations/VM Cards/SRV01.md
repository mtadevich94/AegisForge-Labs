# SRV01 — Member Server

| | |
|---|---|
| **OS** | Windows Server 2022 (evaluation ISO) |
| **Resources** | 2 GB RAM, 2 vCPU, 50 GB disk |
| **Network** | `GielinorNAT` |
| **Address** | `10.10.10.40/24`, gateway `10.10.10.1`, DNS `10.10.10.10` |
| **Role** | Domain member server (Tier 1) in the Tiered Admin lab |
| **Built by** | Tiered Admin lab (Systems Administration) |

## Requires

DC01 running and the domain `gielinor.local` built.

## Build

Follow the Tiered Admin lab's setup guide: install Server 2022, set the static address, join `gielinor.local`.

## Ready when

- `hostname` returns `SRV01`
- `(Get-WmiObject Win32_ComputerSystem).Domain` returns `gielinor.local`

## Verify

```powershell
hostname; (Get-CimInstance Win32_ComputerSystem).Domain
```

## Snapshots

`post-install-clean`, `tiered-start`.

## Used by

Tiered Admin. Not needed by the Gatehouse.
