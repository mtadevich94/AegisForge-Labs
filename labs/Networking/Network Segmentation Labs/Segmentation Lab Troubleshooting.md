# The Gatehouse — Troubleshooting

Problems are listed roughly by how often they happen. Work **top-down inside each entry** — the first check fixes most cases.

**The three habits that prevent most problems**

1. After *every* firewall change: **Save, then Apply changes** (the yellow banner).
2. Start **FW01 first** and wait about a minute before starting the other VMs.
3. After *any* rule change, run the test matrix. A failing row points straight at the problem.

---

## Setup problems

### Nothing can reach the firewall (a VM can't ping `.1`)

The VM is almost certainly on the wrong virtual switch.

1. VirtualBox → the VM → **Settings → Network → Adapter 1** → **Attached to: Internal Network**, **Name** exactly: `realm-garrison`, `realm-market`, or `realm-citadel`. The names are **case-sensitive**: a typo silently creates a brand-new empty switch.
2. Confirm **Cable Connected** is ticked (*Advanced*).
3. On FW01, **Settings → Network**: adapters 2, 3, 4 must carry those same three names (in that order).
4. Confirm the VM's own address: `ip -br a` (Linux) or `ipconfig` (Windows).
5. Console option **7** (*Ping host*) on FW01 pings from the firewall; if the firewall can ping the host but not the reverse, check rules.

### FW01 has no WAN address

1. FW01 **Adapter 1** must be **NAT Network → `GielinorNAT`**.
2. `GielinorNAT` has DHCP **off**, so the WAN must be static: FW01 console option **2** → WAN → *DHCP: n* → address `10.10.10.5`, `24`, gateway `10.10.10.1`. Make sure no other VM uses `.5` (see the Address Registry).
3. Console option **11** (*Reload all services*), then re-check.
4. Still stuck? On FW01 **Interfaces → Diagnostics → Ping**, ping `10.10.10.1`.

### I can't open `https://10.20.10.1`

1. WKS01 must be on `realm-garrison` and have a `10.20.10.1xx` address (`ipconfig`). `169.254.x.x` means DHCP didn't answer.
2. Use **https**, not http.
3. Certificate warning? Expected (self-signed). *Advanced → Continue.*
4. From WKS01: `Test-NetConnection 10.20.10.1 -Port 443`. If it fails, check the FW01 console that LAN shows `10.20.10.1/24`.
5. After Module 6 you *can't* reach it from the Garrison — by design. Use the tunnel at `https://127.0.0.1:8443`.

### WKS01 gets `169.254.x.x` (no DHCP)

1. FW01 console should show the DHCP range for LAN. Check **Services → Dnsmasq DNS & DHCP**, **Kea DHCPv4** or **ISC DHCPv4** (the menu depends on your OPNsense version) — the **GARRISON** interface must have DHCP enabled with range `10.20.10.100–199`.
2. On WKS01: `ipconfig /release` then `ipconfig /renew`.
3. Temporary workaround: set a static address on WKS01 — `10.20.10.100 / 255.255.255.0`, gateway and DNS `10.20.10.1`.

### The OPNsense installer won't boot / loops back to the installer

- Booting the ISO again shows a `login:` prompt mentioning `installer`. Power off and remove the ISO: *Devices → Optical Drives → Remove disk from virtual drive*.
- Black screen after the boot menu: give FW01 at least 2 GB RAM and leave **EFI unticked**.
- Slow install: it can take several minutes in a VM. Give it time.

### Interface names aren't `em0`–`em3`

Names depend on the virtual adapter and OPNsense version (`igc0`, `vtnet0`, …). Use whatever the console lists, matched to the **MAC addresses** you wrote down. The *order* (Adapter 1 → WAN, 2 → GARRISON, 3 → MARKET, 4 → CITADEL) is what matters.

### The Ubuntu installer has no network

There's no DHCP in the Market or Citadel. In the installer's **Network connections** screen, edit IPv4 → **Manual** and enter the address, gateway and DNS from the setup table. If it still can't reach the mirror, check the temporary "flat realm" rule is on that zone's interface and **applied**.

### `setup-segmentation-host.sh` stops at a check

| Message | Fix |
|---|---|
| `Cannot ping 10.20.x.1` | Wrong internal-network name (see *Nothing can reach the firewall*) |
| `No internet through the firewall` | The temporary "flat realm" rule isn't there/applied, or DNS fails: `nslookup archive.ubuntu.com 10.20.x.1` |
| `This script targets Ubuntu/Debian` | Wrong OS image |
| netplan errors | Make sure no other file in `/etc/netplan` still defines the interface (the script moves them aside as `.bak`) |

If the script is **re-run after the lab's rules are in place** (Module 3 onward), its internet check will fail by design. Re-running isn't needed unless you rebuilt the VM: to do so, use `--no-static-ip` and temporarily restore the flat rule.

### The WKS01 canary isn't answering

1. In an elevated PowerShell: `Get-ScheduledTask GatehouseCanary | Get-ScheduledTaskInfo` — it should be running (*LastTaskResult* `267009` means "currently running").
2. `Start-ScheduledTask GatehouseCanary`, wait 3 seconds, then `Test-NetConnection 127.0.0.1 -Port 8080`.
3. Is port 8080 in use? `netstat -ano | findstr :8080`.
4. Windows Firewall: `Get-NetFirewallRule -DisplayName "Gatehouse lab - canary TCP 8080"`.
5. Reset: `.\Setup-SegmentationLab-WKS01.ps1 -Remove`, then run it again without `-Remove`.

### WKS01 won't sign in after moving networks

DC01 isn't reachable, so Windows uses cached credentials (slow but works). If the cached sign-in fails, use the local administrator account. To undo the move entirely, switch Adapter 1 back to `GielinorNAT`.

---

## Test and policy problems

### The matrix says FAIL

Read the verdict, then the pattern:

| You see | It means | Look for |
|---|---|---|
| *Expected Denied, got OPEN* | A rule is **too loose**, or a TEMP rule survived | A `TEMP flat realm` rule; a broad `any` rule above the Block; a missed **Apply** |
| *Expected OPEN, got DROPPED* | A rule is **missing** or in the **wrong order** | The Pass rule is below a Block that matches first; typo in an alias; wrong port |
| `NODNS` | The name didn't resolve | Rule for DNS to `This Firewall` (M1/C2/G1) missing or Unbound isn't running |
| Every row DROPPED | Rules not applied, or you can't reach the firewall at all | Apply changes; check the interface/network |
| `WATCHTOWER :4444` FAIL in `flat` | The listener isn't running | On WATCHTOWER: `python3 -m http.server 4444` |
| Every Garrison-canary row FAIL | `--wks-ip` is wrong | `ipconfig` on WKS01, pass the real address |

### The firewall seems to ignore my rule

- **Apply changes** was never clicked.
- The rule is on the **wrong interface** — rules apply to traffic *entering* that interface.
- A rule **above** it matches first (check order; Quick-match rules stop evaluation).
- The rule is **disabled** (greyed out).
- An **alias** has a typo or is empty. Check **Firewall → Aliases**; hover a rule's alias to see what it expands to.
- You wrote the rule in the right direction but on **Floating** instead of the interface.

### A published service doesn't work (Module 4)

1. The **WAN rule exists**: Firewall → Rules → WAN should list the pass rule(s). If not, edit the NAT rule and choose *Add associated filter rule*.
2. **Block private networks / Block bogon networks** on the WAN must be **unticked** (Interfaces → WAN) — WATCHTOWER is a private address.
3. You're targeting the right **WAN address** (`Interfaces → Overview`). It's the static `10.10.10.5` unless you changed it.
4. From inside the Garrison, browsing the WAN address often fails (**NAT reflection**) — that's expected; test from WATCHTOWER.
5. Is nginx up on WEB01? `sudo systemctl status nginx`, `sudo ss -tlnp | grep -E ':80|:443'`.

### `apt-get update` fails after Module 7

You're likely hitting the FQDN-alias caveat. On WEB01:

```bash
grep -rhE '^(URIs|deb)' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
```

Add **every** hostname it shows (plus `security.ubuntu.com`) to `H_UBUNTU_REPOS`, Apply, wait a minute, retry. Mirrors with many changing addresses are inherently awkward to allow-list by name — that's a lesson, not a bug.

### Name resolution fails everywhere

- Is **Unbound** running? **Services → Unbound DNS → Overview** (or the Dashboard's *Services* widget).
- Is the DNS rule present on that zone (M1, C2, G1)? It must say destination **This Firewall**, port 53, protocol **TCP/UDP**.
- Unbound's **Network Interfaces** (under *Services → Unbound DNS → General*) should include all internal interfaces — leaving it on *All* is fine.
- The firewall's own upstream DNS: **System → Settings → General** shows `1.1.1.1` / `9.9.9.9`.

### The Unbound blocklist doesn't block

- Did you click **Apply** after saving the blocklist?
- Your WKS01 may be caching the old answer: `ipconfig /flushdns`.
- Make sure WKS01's DNS server is `10.20.10.1`, not a public resolver (`ipconfig /all`).

---

## Management problems (Module 6)

### Locked out of the firewall

1. **Fastest:** restore FW01's `06-before-mgmt` snapshot.
2. **Console:** option **13** *(Restore from backup)* — pick the most recent configuration from before your change.
3. **Console:** option **2** to re-check each interface's address, then option **11** (*Reload all services*).
4. **Last resort:** option **4** (*Reset to factory defaults*) and redo Setup Steps 4b, 6, 7 and 8.

### The tunnel to the firewall GUI doesn't open

- `ssh -L 8443:10.20.30.1:443 gatekeeper@10.20.30.10` must stay running in its PowerShell window.
- Does the GARRISON jump-host rule sit **above G4** and is it **applied**?
- Does `Test-NetConnection 10.20.30.10 -Port 22` succeed from WKS01? If not, check `H_WKS01` is WKS01's *real* address.
- Browse to **`https://127.0.0.1:8443`**, not `localhost`.
- "Potential DNS Rebind" / referrer error: add `127.0.0.1` and `localhost` under **System → Settings → Administration → Alternate Hostnames** (do it while you still have access).
- The GUI **Listen Interfaces** must include **CITADEL** (the tunnel reaches the firewall's Citadel address).

### SSH to the firewall refuses my key

- The public key must be on the **user** (System → Access → Users) and the user needs a **login shell** (not `nologin`).
- Is **Secure Shell** enabled with **Listen Interfaces** including CITADEL?
- File permissions on ADM01: `chmod 700 ~/.ssh; chmod 600 ~/.ssh/id_ed25519`.
- Debug: `ssh -v gatekeeper-admin@10.20.30.1`.

---

## Module 8 problems

### No logs arrive on ADM01

1. On ADM01: `sudo ss -lun | grep :514` — you should see `0.0.0.0:514`. If not: `sudo systemctl restart rsyslog` and re-run `sudo bash setup-segmentation-host.sh --role adm --no-static-ip` (temporarily restore internet access, or just check `/etc/rsyslog.d/10-gatehouse-remote.conf` exists).
2. On FW01 the **Targets** entry must be **enabled** and show `10.20.30.10` port `514`, transport UDP4.
3. Generate an event (a failed GUI login, or a blocked probe) — idle firewalls don't log much.
4. Look in the right file: `/var/log/remote/<sender-IP>.log`; the firewall appears as `10.20.30.1`.
5. For WEB01, the rule above M4 must exist (UDP, `H_WEB01` → `H_ADM01`, 514).

### The IDS shows no alerts

- The service must be **running** (Services → Intrusion Detection → Administration). Interface = **MARKET**.
- The **emerging-scan** ruleset must be downloaded *and* enabled (create a Policy with action **Alert** if the rules show disabled).
- Run a larger scan: `sudo nmap -sS -p 1-1000 10.20.10.100` from WEB01.
- FW01 low on RAM? Give it 4 GB. A stopped service after a long **Download & Update** often means it ran out of memory.
- *Don't* enable IPS mode — VirtualBox adapters handle inline netmap inconsistently.

### FW01 is slow or the GUI times out

- Give FW01 more RAM (4 GB) and 2 CPUs.
- Close other busy VMs. A 16 GB host running five VMs plus a browser is near its limit.
- Check the Dashboard's *System Information*: swap use above a few percent means too little RAM.

---

## General tips

- **Snapshots are free.** Take one before each module; the guide tells you when.
- **Compare the configuration.** *System → Configuration → Backups → Download* before and after a module; diff the two XML files to see exactly what changed.
- **Use the search box** at the top of the OPNsense GUI when a menu name differs from the guide.
- **Time matters.** If log timestamps look wrong, check the firewall's timezone (*System → Settings → General*).
- **Still stuck?** Open an issue on the repo with: what you were doing, the module, the matrix output, and a screenshot of **Firewall → Log Files → Live View**.
