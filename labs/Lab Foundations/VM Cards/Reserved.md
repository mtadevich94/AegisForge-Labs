# Reserved VMs

These names and ranges are held for the Cybersecurity phase. **There are no build steps yet**; this page exists so nothing else claims the names or addresses.

| VM | Intended role | Address block |
|---|---|---|
| **KALI01** | Attacker workstation, used only against your own lab | `10.30.0.0/16` |
| **SIEM01** | Central log collection and detection | `10.30.0.0/16` |
| **TARGET01** | Deliberately vulnerable host for attack and defend exercises | `10.30.0.0/16` |

When the lab that introduces a VM is written, its card replaces its row here and the **Lab Fleet Catalog** status changes from 🕓 to ✅.

Until then, don't build or name anything `KALI01`, `SIEM01` or `TARGET01`, and keep your own scratch VMs in `10.10.10.100`–`.254`.
