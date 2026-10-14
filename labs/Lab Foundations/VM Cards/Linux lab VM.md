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

This VM is independent of the rest of the fleet. It needs no addresses from the registry and doesn't conflict with anything.
