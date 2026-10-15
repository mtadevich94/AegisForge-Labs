# AegisForge Labs

Hands-on labs that pair with the [Project AegisForge](https://projectaegisforge.com) roadmaps. Each lab gives you instructions and, usually, a script that sets up a VM, so you practice a skill instead of just reading about it.

All labs share **one virtual environment**: the same VMs on the same virtual networks. You can start on any roadmap, and what you build carries forward into the next lab and, later, the Cybersecurity phase.

## Start here

**New to the labs, or jumping in on a later roadmap?** Open [Lab Foundations](labs/Lab%20Foundations/README.md). It tells you which VMs a lab needs, how to build the ones you're missing, and how to check each one is ready.

## How to use these labs

1. Clone this repo (or download the folder for the lab you want).
2. Open the lab's own `README.md`. Its **Requires** block lists the VMs it needs and their state.
3. Build any missing VMs from the [VM cards](labs/Lab%20Foundations/VM%20Cards/) and snapshot before you begin.
4. **Read every script before you run it.** Each one is plain text in this repo. Know what it will do before you execute it.
5. When you finish, follow the lab's cleanup steps.

## Lab index

| Roadmap | Lab | Topic | Difficulty | Est. time |
|---|---|---|---|---|
| Foundations | [Lab Foundations](labs/Lab%20Foundations/README.md) | Shared VMs, networks, addresses, build cards | Start here | 1–2 hours |
| Systems Administration | [Linux Labs](labs/Systems%20Administration/Linux%20Labs) | Navigating and searching the Linux filesystem | Beginner | 30–45 min |
| Systems Administration | [Windows Labs](labs/Systems%20Administration/Windows%20Labs) | Navigating and searching Windows; building the domain | Beginner | 30–45 min |
| Systems Administration | [Wireshark Labs (Packet Watch)](labs/Systems%20Administration/Wireshark%20Labs) | Investigating network traffic with Wireshark | Beginner | 4–6 hours |
| Systems Administration | [Hardening Challenge](labs/Systems%20Administration/Hardening%20Challenge) | Open-ended: harden your lab VMs with a checklist, then your home network | Beginner–Intermediate | 4–8 hours |
| Systems Administration | [Tiered Admin Labs](labs/Systems%20Administration/Tiered%20Admin%20Labs) | Tiering an Active Directory domain | Intermediate | 6–8 hours |
| Networking | [Network Segmentation Labs (The Gatehouse)](labs/Networking/Network%20Segmentation%20Labs) | Four-zone OPNsense firewall design, testing and monitoring | Intermediate | 8–12 hours |
| Cybersecurity | *Coming later* | Reserved | | |

## Safety notice

These labs run inside disposable VMs, not on a machine you care about.

- Review each script yourself before running it.
- Keep lab VMs on VirtualBox NAT Networks and Internal Networks. **Never bridge them to your real network.**
- Lab VMs are deliberately weak. Don't reuse real passwords or expose them to the internet.
- They are for learning, not for production, and shouldn't be pointed at anything sensitive.

## Contributing

Found a bug, or want to suggest a lab? Open an issue using the templates in `.github/`. Pull requests are welcome; see the PR template.
