# Hardening Checklist

Use this to **cross-reference your own work**. It's a list of recommendations, not a sequence of steps. For each item you'll find *what* to check, *why* it matters, and a hint for *how to verify* it. The hints show you where to look, not what to type to fix it.

**How to use it:** do your baseline first (see the [README](README.md)), then tick items off as you fix and verify them. Skip what doesn't apply. Note what you skipped and why.

The list has three layers:

- **Layer A — Your AegisForge lab.** Specific to the machines you built in the Student path: the AlmaLinux VM, Windows (WKS01 and DC01), and WATCHTOWER.
- **Layer B — Any machine.** Good practice for any computer, server or VM, anywhere.
- **Layer C — Your home network and accounts.** The part nobody tests until something goes wrong.

> **Before you change anything on a VM:** snapshot it, and keep a second session open when you touch SSH or firewall settings.

---

## Layer A1 — The Linux lab VM (AlmaLinux)

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Accounts:** does every account on the VM need to exist and be able to log in? | Every account is a way in. Unused accounts are free footholds. | `getent passwd`, then look at the shell column. `sudo passwd -S <user>`, `lastlog` |
| ☐ | **Passwords:** are any accounts sharing the same starter password? Do any never expire? | One guessed password then opens every account that shares it. | `sudo chage -l <user>`. Think about how the lab *created* these accounts. |
| ☐ | **Least privilege with sudo:** who can use `sudo`, and what *exactly* can they run? | Full `sudo` is root. Most people need one or two commands, not everything. | `sudo -l -U <user>`, `getent group wheel`, `/etc/sudoers` and `/etc/sudoers.d/` (edit only with `visudo`) |
| ☐ | **SSH configuration:** is root login blocked? Are passwords allowed? How many tries does an attacker get? | SSH is the front door and the first thing scanned on the internet. | `sudo sshd -T \| grep -Ei 'permitrootlogin\|passwordauthentication\|maxauthtries\|allowusers'`. Compare what's *actually* enforced to what the lab guides say. |
| ☐ | **SSH keys instead of passwords:** can you log in with a key, and then turn password logins off? | A key can't be guessed or sprayed. A password can. | `ssh-keygen -t ed25519`, `ssh-copy-id`. **Test the key login in a second session before disabling passwords.** |
| ☐ | **Firewall: which tool is in charge?** AlmaLinux ships with **firewalld**. The lab setup script also installs and enables **iptables-services** (called `iptables-nft-services` on newer releases). | Two firewall managers can silently contradict each other. You need to know which one is really enforcing your rules. | `systemctl is-active firewalld iptables`, `sudo firewall-cmd --state`, `sudo iptables -S` |
| ☐ | **Firewall policy:** is it default-deny inbound, with only what's needed allowed? | Anything not explicitly allowed should be blocked. | `sudo firewall-cmd --get-active-zones`, `sudo firewall-cmd --list-all`. Remove any service in your zone you don't use. Use `--permanent`, then `--reload`. |
| ☐ | **What's listening?** Can you account for every open port? | A service you forgot about is still exposed. | `sudo ss -tulpn` |
| ☐ | **NFS and other services:** is anything running that your lab no longer needs? | Fewer services means fewer ways in. | `sudo exportfs -v`, `systemctl list-unit-files --state=enabled`. Some of these exist for earlier labs; decide when to turn them off. |
| ☐ | **SELinux:** is it still enforcing? | It limits what a compromised service can do. Switching it off is the most common bad "fix". | `getenforce`, `sestatus`. If something breaks, read the denial in the audit log instead of disabling SELinux. |
| ☐ | **File permissions:** any world-writable files or unexpected SUID programs? | A file anyone can modify, or a program that runs as root for anyone, is a privilege escalation path. | `find / -xdev -type f -perm -0002 2>/dev/null`, `find / -xdev -type f -perm -4000 2>/dev/null` |
| ☐ | **Patching:** is the system up to date? Can it update itself? | Most compromises use bugs that already have a fix. | `sudo dnf check-update`, `sudo dnf upgrade`. Look into `dnf-automatic` |
| ☐ | **Logging:** would you *notice* a failed or suspicious login? | You can't respond to what you can't see. | `sudo journalctl -u sshd`, `sudo lastb`, `systemctl status auditd` |

## Layer A2 — Ubuntu VM: WATCHTOWER *(if you did Packet Watch)*

This machine is **deliberately** weak: plaintext FTP, a web portal with its own credentials, and no firewall policy. Harden a **linked clone**, or finish Packet Watch first.

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Firewall with ufw:** default deny inbound, allow only what's needed | The Ubuntu counterpart of firewalld, and the simplest way to turn "everything is reachable" into "only what I chose is reachable" | `sudo ufw status verbose`. **Allow SSH *before* you enable it**, or you cut your own session. |
| ☐ | **Plaintext services:** which protocols send credentials in the clear? What could replace them? | Anything on the wire in plaintext is readable by anyone on the path. You saw this yourself in Wireshark. | `sudo ss -tulpn`. Which of these have an encrypted alternative that's already installed? |
| ☐ | **Credential reuse:** is any password used in more than one place? Where are secrets stored? | One leaked secret should never open a second door. | Read the machine's own notes and files like an attacker would. |
| ☐ | **Exposure:** do the services listen on every interface? Do they need to? | A service bound to all interfaces is reachable from every network the machine touches. | `sudo ss -tulpn` and look at the local-address column. |
| ☐ | **Prove it:** repeat the Packet Watch capture. Can you still read the credentials? | A control you haven't tested is a hope, not a control. | Capture, filter, and look for what used to be visible. |

## Layer A3 — Windows (WKS01, and DC01 if you built it)

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Local accounts:** which exist, which are enabled, which are administrators? | An extra admin account is an extra way to take over the machine. | `Get-LocalUser \| ft Name,Enabled,PasswordExpires,PasswordLastSet`, `Get-LocalGroupMember Administrators` |
| ☐ | **Passwords:** shared starter passwords? "Never expires"? | Same risk as Linux: one guess opens many accounts. | The same `Get-LocalUser` output, plus `net accounts` for the password and lockout policy |
| ☐ | **Built-in accounts:** are the built-in `Administrator` and `Guest` accounts disabled? | They're the first names an attacker tries. | `Get-LocalUser Administrator,Guest` |
| ☐ | **Network shares:** what is shared, and who can read it? | A share open to "Everyone" is open to anything that can reach the machine. | `Get-SmbShare`, `Get-SmbShareAccess -Name <share>` |
| ☐ | **SMB hardening:** is the old SMBv1 protocol off? Is signing required? | SMBv1 has a long history of serious vulnerabilities. | `Get-SmbServerConfiguration \| select EnableSMB1Protocol,RequireSecuritySignature` |
| ☐ | **Scheduled tasks:** what runs automatically, and with what privileges? | A task running as SYSTEM or with highest rights is a favorite persistence spot. | `Get-ScheduledTask \| ? { $_.Principal.RunLevel -eq 'Highest' }`. Look at what each one actually *runs*. |
| ☐ | **Windows Firewall:** on for every profile? Default-deny inbound? Anything open that shouldn't be? | The host firewall is your last line of defense on the machine itself. | `Get-NetFirewallProfile \| ft Name,Enabled,DefaultInboundAction`, `Get-NetFirewallRule -Enabled True -Direction Inbound` |
| ☐ | **What's listening?** Can you account for every port? | Same logic as Linux. | `Get-NetTCPConnection -State Listen \| sort LocalPort` |
| ☐ | **Auditing:** is anything logging logons, account changes and process creation? | You need records to investigate anything. | `auditpol /get /category:*`. The lab enabled one category. What else would you want when investigating? |
| ☐ | **Antivirus and updates:** is Defender on and current? Is Windows patched? | The cheapest controls you have are the ones already built in. | `Get-MpComputerStatus \| select AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated` |
| ☐ | **UAC:** is User Account Control on? | It stops a normal program quietly using admin rights. | `(Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).EnableLUA` |
| ☐ | **Domain accounts** *(if DC01 is built)*: who is in **Domain Admins**? Is the domain password policy sensible? | Domain Admin controls everything in the domain. Keep that group tiny. | `Get-ADGroupMember "Domain Admins"`, `Get-ADDefaultDomainPasswordPolicy`. Going deeper here? The **Tiered Admin** lab is the next step. |

---

## Layer B — Any machine, anywhere

These apply to any computer, server, VM or cloud instance. The free **CIS Benchmarks** (cisecurity.org) give a detailed, checkable version of almost everything here for specific operating systems.

| ☐ | Check | Why it matters |
|:-:|---|---|
| ☐ | **Patch:** operating system and applications, with a way to know when you fall behind | Known, fixed bugs are how most attacks succeed. |
| ☐ | **Least privilege:** people and services get only what they need, nothing more | A stolen low-privilege account is a nuisance. A stolen admin account is a disaster. |
| ☐ | **Strong, unique authentication:** a password manager, and **MFA** wherever it's offered | Reused passwords turn one breach into every breach. |
| ☐ | **Remove what you don't use:** software, services, accounts, open ports | Every extra thing is something that can be attacked or misconfigured. |
| ☐ | **Default-deny network policy:** host firewall on, only needed ports open | Decide what's allowed. Don't just try to block what's bad. |
| ☐ | **Encrypt storage and traffic:** full-disk encryption on laptops, TLS/SSH instead of plaintext | A lost laptop and a sniffed network are both ordinary events. |
| ☐ | **Logging you'd actually read:** logins, privilege use, changes. Know where the logs live | If you'd never look, it isn't a control. |
| ☐ | **Backups, *and a tested restore*:** keep at least one copy that is offline or separate | A backup you haven't restored is a guess. Ransomware also targets backups it can reach. |
| ☐ | **Keep time in sync** | Log timestamps are useless for investigations if clocks disagree. |
| ☐ | **No secrets in code or repos:** passwords, keys and tokens stay out of scripts and Git | Public repos are scraped continuously. Notice that the *lab* scripts contain starter passwords on purpose. Yours never should. |
| ☐ | **Know what you have:** a short inventory of devices, accounts and services | You can't defend, or even recognize, what you haven't listed. |
| ☐ | **Document it:** what you changed and why | Future-you and your teammates need it. It's also the habit this challenge is really teaching. |

## Layer C — Your home network and accounts

Everything here applies to **your actual home**. Be careful: a wrong change can take your own internet down, so write down the old setting before you change it.

| ☐ | Check | Why it matters | Where to look |
|:-:|---|---|---|
| ☐ | **Router admin login:** is the default password changed? | Default router credentials are public knowledge. | Your router's admin page (often on your gateway address) |
| ☐ | **Router firmware:** current? Can it auto-update? | Router bugs are widely and automatically exploited. | The router's admin or update page |
| ☐ | **Remote administration:** is the router's admin page reachable from the internet? | It should only be reachable from inside your home. | Router settings: "remote management" or "remote access". Turn it off. |
| ☐ | **Wi-Fi security:** WPA3, or WPA2 with AES. A long passphrase. WPS off. | WPS has well-known weaknesses, and weak passphrases can be cracked offline. | Router wireless settings |
| ☐ | **UPnP:** is it needed? | UPnP lets devices on your network open holes to the internet on their own. | Router settings. Turn it off unless something truly needs it. |
| ☐ | **Guest and IoT network:** do visitors and smart devices share a network with your computers? | Cheap smart devices are rarely patched. Keep them away from your laptops. | Router "guest network" feature |
| ☐ | **Port forwards:** is anything exposed to the internet that you don't remember adding? | An old forward is an open door. | Router "port forwarding" or "virtual server" page |
| ☐ | **Device inventory:** can you name every device on your network? | An unknown device might be a neighbor, or a compromised gadget. | Router's connected-devices list |
| ☐ | **Your lab is isolated:** are all lab VMs on NAT or Internal networks, **never bridged**? | A deliberately weak VM must not sit on your real network. | VirtualBox → each VM → Settings → Network. Look for "Bridged Adapter". |
| ☐ | **Accounts:** password manager, MFA on email and banking first, unique passwords | Your email account can reset almost everything else. | Your email provider's security page. Check whether your address appears in known breaches at *haveibeenpwned.com*. |
| ☐ | **Backups:** your important files in more than one place | One fire, theft or ransomware event shouldn't end your photos and documents. | Whatever you use today. Then test a restore. |

---

### One last thing

No machine is ever "fully hardened". The goal is to **raise the cost of attacking you** and to **notice when something goes wrong**, then to know what risk remains. Your report's last section, *what I didn't fix*, matters as much as the changes you made.
