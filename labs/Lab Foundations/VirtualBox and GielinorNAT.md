# VirtualBox and GielinorNAT

One-time host setup shared by every lab. If you've already done it for an earlier lab, skip to **Check your setup**.

> The AlmaLinux lab uses its own standalone NAT and port-forward (see the Linux Labs setup guide). Everything below is for the labs that share `GielinorNAT`.

## 1. What you need

| Item | Notes |
|---|---|
| A computer with **virtualization enabled** in BIOS/UEFI | Intel VT-x or AMD-V. If VirtualBox says "VT-x is disabled", enable it in firmware settings |
| **16 GB RAM** recommended | 8 GB works for one small lab at a time. See the budget table below |
| **150 GB** free disk | Fleet totals about 200 GB if you build everything; linked clones save a lot |
| **VirtualBox 7.x** and its Extension Pack | Download from virtualbox.org |

## 2. Install VirtualBox

1. Download and run the installer for your OS. Accept the defaults. On Windows, the installer briefly disconnects your network; that's normal.
2. Reboot if asked.
3. If you use Hyper-V, WSL2 or "Memory integrity" on Windows, VirtualBox may run slowly. It still works; expect it to be slower.

## 3. Create the shared network `GielinorNAT`

A **NAT Network** lets your VMs reach each other *and* the internet, while staying hidden from your real network.

**Using the GUI**

1. VirtualBox → **File → Tools → Network Manager** (older versions: Preferences → Network).
2. Open the **NAT Networks** tab and click **Create**.
3. Set **Name** `GielinorNAT`, **IPv4 Prefix** `10.10.10.0/24`.
4. **Untick Enable DHCP.** This is deliberate: every lab VM uses a static address from the **Address Registry**.
5. Apply.

**Using the command line** (same result)

```
VBoxManage natnetwork add --netname GielinorNAT --network 10.10.10.0/24 --enable --dhcp off
```

On Windows, run it in a terminal from `C:\Program Files\Oracle\VirtualBox\`. Check it with `VBoxManage list natnetworks`.

## 4. Internal networks

Internal networks (`realm-garrison`, `realm-market`, `realm-citadel`) need **no setup**. They come into existence the first time you pick the name in a VM's adapter settings. Spell them exactly, because names are case-sensitive.

## 5. Adapter settings that work everywhere

For every VM: **Settings → Network → Adapter → Attached to** `NAT Network`, **Name** `GielinorNAT` (or an internal network where the lab says so). Under Advanced, use **Intel PRO/1000 MT Desktop** unless the guide says otherwise.

## 6. Snapshots

Take one **before** anything risky. VM → **Snapshots** tab → **Take**. Use the names from the Lab Foundations README (`post-install-clean`, `<lab>-start`, `<NN>-before-<thing>`). Restoring a snapshot discards everything you did since. That's the point.

**Linked clones** (right-click VM → Clone → *Linked clone*) share the parent's disk and cost almost no space. Use one when a lab needs a VM in a different state, for example a copy of WKS01 for the Gatehouse. Don't delete the parent while a clone depends on it.

## 7. Start and stop order

Start in this order and wait for each to finish booting:

1. DC01 (everything else uses it for DNS in the flat realm)
2. SRV01
3. WKS01
4. WATCHTOWER

For the Gatehouse: FW01 first, then WEB01, ADM01, WKS01, WATCHTOWER.

Shut VMs down from inside the OS or with **Machine → ACPI Shutdown**. Avoid powering off hard; Windows especially dislikes it.

## 8. RAM budget

Add up the VMs you'll run **at the same time**, then leave 4 GB for your host.

| Lab | Running VMs | RAM |
|---|---|---|
| Linux Administration | Linux lab VM | 2 GB |
| Windows Administration | DC01 + WKS01 | 6–8 GB |
| Packet Watch | WKS01 + WATCHTOWER (+ DC01 optional) | 6–8 GB |
| Tiered Admin | DC01 + SRV01 + WKS01 | about 8 GB |
| The Gatehouse | FW01 + WEB01 + ADM01 + WKS01 + WATCHTOWER | about 10 GB |

Short of RAM? DC01 works at 2 GB, and Windows 11 at 4 GB is the practical floor.

## 9. Isolation rules

- **Never bridge** a lab VM to your real network.
- Don't add a second adapter that touches your home network.
- Lab passwords are throwaway. Never reuse a real one.

## Check your setup

```
VBoxManage list natnetworks
```

You should see `GielinorNAT`, network `10.10.10.0/24`, `DHCP Enabled: No`. Then open the first lab's **Requires** block and continue.
