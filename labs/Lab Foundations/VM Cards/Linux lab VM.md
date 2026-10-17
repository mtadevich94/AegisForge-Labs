# Linux lab VM — AlmaLinux

| | |
|---|---|
| **OS** | AlmaLinux 8.10 |
| **Resources** | 2 GB RAM, 1–2 vCPU, 20 GB disk |
| **Network** | VirtualBox default **NAT** (standalone, not on `GielinorNAT`) |
| **Access** | Port-forward: host `127.0.0.1:2222` → guest port 22 |
| **Built by** | Linux Administration lab (Student) |

## Build

Follow the AlmaLinux VirtualBox setup guide in `labs/Systems Administration/Linux Labs/`. It covers the ISO, the NAT port-forward and first SSH login.

## Ready when

You can run this from your host and get a login prompt:

```
ssh -p 2222 <your-user>@127.0.0.1
```

## Snapshots

`post-install-clean`, then `<lab>-start`.

## Notes

By default this VM is independent of the rest of the fleet and needs no addresses from the registry.

**Optional: reachable from the fleet.** The Vulnerability Management Challenge needs VULN01 to reach this VM. Add **Adapter 2** attached to NAT Network `GielinorNAT` and give that interface a static `10.10.10.51/24` with **no gateway** (so Adapter 1 stays the default route and the `2222` port-forward keeps working). The Scanner Setup Guide has the exact steps.
