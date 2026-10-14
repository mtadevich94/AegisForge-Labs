# Wireshark Labs — *The Wrkstation Chronicles: Packet Watch*

Learn to read network traffic the way a defender does. Eight story-driven modules take you from "what is a packet?" to writing a full incident report from a capture — using free tools, in a lab you can run on your own laptop.

Part of **Project AegisForge** → Student path → *Phase 2: Reading Network Traffic* → the **Packet Capture Investigation** project.

## What you'll learn

1. Capture live traffic and navigate Wireshark
2. Use display filters; read DNS, ICMP, and ARP
3. Understand TCP handshakes and conversations
4. Spot plaintext credentials and session cookies in HTTP
5. Understand why FTP is unsafe (and how its two connections work)
6. See what TLS hides — and what it still leaks
7. Detect a port scan from raw packets
8. **Capstone:** reconstruct a real-looking intrusion and write the incident report

## Pick your track

| Track | You need | Covers |
|---|---|---|
| **Pcap-only** (easiest) | Wireshark on any computer + the `pcaps/` folder | Modules 2–8 |
| **Full lab** | Two or three VirtualBox VMs: Ubuntu server + Windows 11 (+ optional DC01) | Everything, including capturing your own traffic |

> Prerequisites: basic command-line comfort (see the Phase 1 labs). If you've done the **Windows Labs** you already have most of the VMs.

## Files

| File | What it is |
|---|---|
| **Wireshark Lab Environment Setup.md** | Build the VMs, run the setup scripts, verify (start here for the full lab) |
| **Wireshark Lab Guide.md** | The lab itself — eight modules (start here for the pcap-only track) |
| **Wireshark Lab Answer Key.md** | Check your work *after* you've tried |
| `setup-watchtower-server.sh` | Ubuntu: installs the intentionally-insecure Watchtower (web portal, FTP, HTTPS) |
| `Setup-WiresharkLab-WKS01.ps1` | Windows 11: installs Wireshark, sets up `C:\GielinorWatch`, tests connectivity |
| `Invoke-GarrisonTraffic.ps1` | Windows 11: generates live traffic for you to capture |
| `pcaps/` | Six pre-built capture files used in Modules 2–8 |
| `tools/` | Maintainer scripts that regenerate the pcaps |
| `SHA256SUMS` | Checksums so you can verify downloads weren't altered |

## Safety — please read

- The Watchtower is **deliberately insecure** (cleartext logins, weak passwords). Run it **only** inside an isolated VM on a NAT Network. Never bridge it to your real network or expose it to the internet.
- Every script in this lab is short and readable. **Read a script before you run it with `sudo` or as Administrator.** That's good practice everywhere, not just here.
- The pcaps are synthetic (generated with Scapy) and contain only fictional hosts, names, and credentials. The only traffic the lab generates goes between your own VMs.
- Verify downloads: `sha256sum -c SHA256SUMS` (Linux) or `Get-FileHash <file>` (Windows) and compare to the value in `SHA256SUMS`.
- Everything here is for learning on systems you own. Don't point these techniques at networks you don't have written permission to test.

## Time & cost

About 4–6 hours across 8 modules. Free: Wireshark, VirtualBox, Ubuntu Server, and Windows evaluation ISOs.

## Versioning

Current: **v1.0.0**. Scripts and pcaps move together — if you pull updates, re-download both.

## Feedback

Found a typo, a broken step, or a better way to explain something? Open an issue on the repo. Part of the point of this project is that it gets better with every learner who finds a rough edge.
