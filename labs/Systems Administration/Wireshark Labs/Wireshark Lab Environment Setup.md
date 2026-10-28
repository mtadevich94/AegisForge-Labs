# Packet Watch — Environment Setup

You need two virtual machines on the same virtual network:

| VM | Role | OS | IP address |
|----|------|----|------------|
| **WATCHTOWER** | The server you capture traffic *to* | Ubuntu Server 24.04 LTS (22.04 works too) | `10.10.10.30` |
| **WKS01** | Your analyst workstation (runs Wireshark) | Windows 11 Enterprise (the VM from the Windows Garrison lab) | `10.10.10.20` |
| **DC01** *(optional but recommended)* | DNS server so name lookups appear on the wire | Windows Server 2022 | `10.10.10.10` |

> **No time or RAM for three VMs?** You can still do almost the whole lab with **just the pcap files** — see *"Pcap-only track"* at the bottom. Modules 2–8 are written around the provided pcaps, so the live VMs are a bonus that lets you capture your own traffic.

> ⚠️ **Isolated lab only.** Watchtower runs a plaintext login, plaintext FTP, and weak passwords on purpose. Keep it on the `GielinorNAT` NAT Network. Never bridge it onto your home/work network and never expose it to the internet.

---

## Step 0 — Reuse what you already have

If you finished the **Windows Garrison** lab you already have `DC01`, `WKS01`, and the VirtualBox NAT Network **`GielinorNAT`** (`10.10.10.0/24`). Make sure both are powered on and WKS01 is domain-joined (or at least on that network). You only need to add the Ubuntu VM.

If your DC01 / WKS01 addresses are different from the table above, that's fine — the **pcaps** always use the addresses above; your **live captures** will show your own addresses. Just substitute as you go.

---

## Step 1 — Build the Ubuntu VM (WATCHTOWER)

1. Download **Ubuntu Server 24.04 LTS** (the ISO, not the desktop image) from <https://ubuntu.com/download/server>.
2. VirtualBox → **New**:
   - Name: `WATCHTOWER`, Type: Linux, Version: Ubuntu (64-bit)
   - Memory: **2048 MB**, CPUs: **1–2**, Disk: **20 GB**
   - Tick **Skip Unattended Installation**
3. VM **Settings → Network → Adapter 1**: *Attached to* **NAT Network**, *Name* **`GielinorNAT`**.
4. Start the VM and install Ubuntu Server with the defaults. When asked:
   - Your name/server name: `watchtower`
   - Create a user named `analyst` (the fleet standard) with a password you will remember
   - Tick **Install OpenSSH server** (gives Module 7 a port 22 to find)
   - Skip all optional "featured snaps"
5. Reboot, log in at the console.

## Step 2 — Run the Watchtower setup script

1. Get the lab files onto the VM. The easiest way (the VM is on a NAT Network with internet access):

   ```bash
   sudo apt-get update && sudo apt-get install -y git
   git clone https://github.com/mtadevich94/Windows-and-Linux-Labs.git
   cd "Windows-and-Linux-Labs/labs/Wireshark Labs"
   ```

2. Review the script (always read a script before you run it with `sudo`):

   ```bash
   less setup-watchtower-server.sh
   ```

3. Run it. `--static-ip` sets `10.10.10.30/24` for you:

   ```bash
   sudo bash setup-watchtower-server.sh --static-ip
   ```

4. The script finishes with a self-test. You want to see `HTTP / -> 200`, `HTTPS / -> 200`, and `FTP :21 open`.

5. **Take a snapshot** of the VM now (`Machine → Take Snapshot`, name it `watchtower-ready`).

## Step 3 — Give WKS01 a DNS name for Watchtower (on DC01 - see the [Windows Lab Domain Set Up Guide](https://github.com/mtadevich94/Windows-and-Linux-Labs/blob/main/labs/Windows%20Labs/Windows%20Domain%20Setup%20Guide.md))

So that DNS lookups show up in your captures, add a real DNS record on DC01. In an elevated PowerShell on **DC01**:

```powershell
Add-DnsServerResourceRecordA -Name watchtower -ZoneName gielinor.local -IPv4Address 10.10.10.30
```

Check it from WKS01:

```powershell
Resolve-DnsName watchtower.gielinor.local
```

> Don't use the Windows `hosts` file as a shortcut. A hosts-file lookup never touches the network, so there'd be nothing to capture in Module 2.

## Step 4 — Set up WKS01 (see the [Windows Lab Domain Set Up Guide](https://github.com/mtadevich94/Windows-and-Linux-Labs/blob/main/labs/Windows%20Labs/Windows%20Domain%20Setup%20Guide.md))

1. Copy the `Wireshark Labs` folder to WKS01 (clone the repo there, or download the ZIP from GitHub and extract it).
2. Open **PowerShell as Administrator** in that folder and run:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\Setup-WiresharkLab-WKS01.ps1
   ```

3. The script installs Wireshark (via `winget`), creates `C:\GielinorWatch\`, copies in the pcaps and the traffic generator, and checks it can reach Watchtower.
4. If the script says Wireshark did not install: download it from <https://www.wireshark.org/download.html>, accept the defaults, **keep "Npcap" ticked**, then re-run the script.
5. **Snapshot WKS01** (`packet-watch-ready`).

## Step 5 — Verification checklist

On **WKS01**:

- [ ] `Resolve-DnsName watchtower.gielinor.local` returns `10.10.10.30`
- [ ] `Test-Connection 10.10.10.30` succeeds
- [ ] `http://watchtower.gielinor.local/` shows the **Wizard Tower Intranet** login page in a browser
- [ ] `C:\GielinorWatch\pcaps\` contains six `.pcap` files
- [ ] Wireshark opens and lists a network interface that shows a live activity graph

All five ticked? Start with **Module 1** in the Lab Guide.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| WKS01 can't ping `10.10.10.30` | Both VMs must use **NAT Network → `GielinorNAT`** (not plain NAT). On Watchtower run `ip -4 addr` and confirm `10.10.10.30/24`. Windows Firewall allows ping on the private profile only — if needed: `Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Enabled True` |
| Name resolves but web page won't load | On Watchtower: `systemctl status wizardtower-http`. Re-run the setup script — it is safe to re-run. |
| No interface in Wireshark / "no interfaces found" | Npcap isn't installed. Re-run the Wireshark installer and tick Npcap. Then restart Wireshark as normal user. |
| Wireshark shows only your own traffic, never Watchtower's | You picked the wrong interface (e.g. a loopback). Choose the Ethernet adapter whose graph moves when you browse to the portal. |
| FTP step in the traffic script fails | Passive ports 40000–40200 must be open (the setup script does this if `ufw` is on). Check with `sudo systemctl status vsftpd`. |
| Ubuntu has no IP on `GielinorNAT` | The NAT Network's DHCP is on by default; if you used `--static-ip` and typed a wrong address, run `sudo netplan try` and fix `/etc/netplan/60-gielinor-lab.yaml`. |

---

## Pcap-only track (no VMs)

Just want to learn Wireshark? Install Wireshark on any computer (<https://www.wireshark.org/download.html>), download the `pcaps` folder from this repo, and work through **Modules 2–8** using the numbered pcap each module names. Skip the "capture it yourself" steps. The answers are identical.

---

## Resetting

- **Watchtower:** revert to the `watchtower-ready` snapshot, or re-run `sudo bash setup-watchtower-server.sh`.
- **WKS01:** delete `C:\GielinorWatch\captures\*` and revert to `packet-watch-ready`.
