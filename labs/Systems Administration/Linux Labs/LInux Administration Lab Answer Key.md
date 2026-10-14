# The Wrkstation Chronicles — Answer Key
### Most-efficient commands, within the scope list, for every task in Lab_Guide.md

---

## Module 1 — Getting Help & System Discovery

1. `whatis passwd` (or `man -f passwd`) → shows `passwd (1)` and `passwd (5)`; section **5** is the config-file entry.
2. `whatis chage`
3. `which grep` → binary path. `whereis grep` → binary + man page + source, all at once.
4. `sudo mandb` (builds/updates the whatis DB) then `apropos partition`
5. `sudo updatedb` then `locate crontab`
6. `hostname` / `uname -r` / `date +%F`
7. `file /opt/vault/shadowfiles/Nightshade` → reports "data" (binary zero-fill). `file /home/Zelda_Warden/star_charts.txt` → "ASCII text".

---

## Module 2 — Filesystem Navigation & Manipulation

1. `find /opt/vault/shadowfiles -type f -name '??????????' -size 512c -perm 0640`
   → matches `Nightshade` (exactly 10 chars). Owner: `ls -l /opt/vault/shadowfiles/Nightshade` → `Vaultkeeper`.
2. `ls -lai /opt/vault/shadowfiles/Nightshade` (file inode) and `ls -lai /opt/vault/shadowfiles | head -1` region (parent dir `.` entry).
3. `sudo ln /home/General_Graardor/Documents/warplans.txt /home/student/warplans_copy.hl` then `ls -lai` on both — matching inode numbers prove same-file hardlink; link count column increments.
4. `sudo ln -s /home/General_Graardor/Documents/warplans.txt /home/student/warplans_sym.link` — `ls -la` shows `l` file-type bit and a differing (small) inode/size plus an `->` target arrow, unlike the hardlink.
5. `head -n 1 /home/Zelda_Warden/star_charts.txt` / `tail -n 1 /home/Zelda_Warden/star_charts.txt`
6. `less /etc/passwd` then `q` to quit.
7. `mkdir /tmp/scratch && touch /tmp/scratch/{a,b,c}.txt && cp /tmp/scratch/a.txt ~/ && mv /tmp/scratch/b.txt /tmp/scratch/b_renamed.txt && rm /tmp/scratch/* && rmdir /tmp/scratch`

---

## Module 3 — Permissions, Ownership & Groups

1. `umask` shows e.g. `0022`. New file → `644` (666-022), new dir → `755` (777-022). Files never get the execute bit from creation regardless of umask.
2. `umask 027` (session-scoped), new file now `640` instead of `644`.
3. `chmod u=rw,g=r,o= /home/student/warplans.hl`
4. `chmod 640 <copy>` — `ls -l` string identical to #3 (`-rw-r-----`).
5. `sudo chown Zelda_Warden:Zelda_Warden /home/student/warplans_copy.hl`
6. `id` (shows uid, gid, and all groups= in one line).
7. `newgrp arrakis` (or whichever group) — then `id` again shows the new *effective* primary gid; `exit` the subshell to return.

---

## Module 4 — Shell Environment, Variables & the Editor

1. `echo $SHELL` ; `env`
2. `QUEST="find the crown"` then `env | grep QUEST` → nothing. `export QUEST` then `env | grep QUEST` → now present.
3. `unset QUEST` — gone from both `set | grep QUEST` and `env | grep QUEST`.
4. `grep student /etc/passwd` (shows current shell field) then `sudo chsh -s /bin/sh student` (or `sudo usermod -s /bin/sh student`; `chsh` is the scope-listed command for this).
5. In vim: `:10` → go to line 10; `dd` deletes current line; `yy` then `p` yanks/pastes; `/TODO` searches forward; `:w` saves without exiting; `:wq` saves and exits.

---

## Module 5 — Text Processing, Filters, Regex & xargs

1.
   ```
   sudo paste /etc/passwd /etc/shadow -d : | grep '/bin/sh' | cut -d: -f1,6,7,9 > /home/student/userinfo.txt
   ```
   (Same technique as your original notes: paste joins the two colon-delimited files field-for-field, grep filters to `/bin/sh` accounts, cut pulls username/home/shell/hash.)
2. `wc -l /etc/passwd` ; `wc -w /home/Zelda_Warden/star_charts.txt`
3. `grep -E '^[0-9]{1,3}[.-][0-9]{1,3}[.-][0-9]{1,3}[.-][0-9]{1,3}$' /home/Zelda_Warden/star_charts.txt`
   → matches `42.07-19.3-6.88-31.5` only. (Anchoring both `^` and `$` excludes the 2-group lines, the malformed `19.3-5-2`, and the longer `...-extra` line.)
4. `sort /etc/passwd` (alphabetic by default, field 1). `sort -t: -k3 -n /etc/passwd` (numeric sort on field 3, the UID).
5. `tr '[:lower:]' '[:upper:]' < /home/Zelda_Warden/star_charts.txt` (reads and transforms without touching the source file, since output isn't redirected back onto it).
6. `find /opt/vault/shadowfiles -type f | xargs chmod 644`

---

## Module 6 — Process Control

1. `ps -ef | grep -i wizardtower`
2. `lsof -p <PID>` ; cross-check with `ls -l /proc/<PID>/fd`
3. `ps -p $$` → shows your shell's own PID (and via `ps -f -p $$`, the PPID too).
4. `ps -f` (defaults to your own processes; add `-u $(whoami)` to be explicit).
5. `sleep 300` → `Ctrl+Z` → `jobs` (shows `[1]+ Stopped`) → `bg` (resumes in background) → `fg` (brings back to foreground) → `Ctrl+C` to terminate.
6. `kill <PID>` (from `ps -ef | grep WizardTower`); after restarting, `killall WizardTower` (wait — note `sleep` is the real binary name under `exec -a`, so `killall` by the *displayed* name only works because we execed with a custom `argv[0]`; if your distro's `killall` matches on the real binary path instead, use `pkill -f WizardTower`).
7. `systemctl status atd` → `sudo systemctl stop atd` → `systemctl status atd` (inactive) → `sudo systemctl start atd && sudo systemctl enable atd`

---

## Module 7 — User, Group & Account Management

1. `sudo groupadd rebels`
2. `sudo useradd -m -c "Harkonnen Heir" -G rebels Feyd`
3. `sudo groupmod -n fremen rebels`
4. `sudo passwd Feyd`
5. `sudo chage -l Feyd` then `sudo chage -E $(date -d "+30 days" +%Y-%m-%d) Feyd`
6. `sudo usermod -aG arrakis Feyd` (the `-a` is critical — without it, `usermod -G` *replaces* all supplementary groups instead of appending).
7. `su - Feyd` then `id` then `exit`
8. `sudo userdel -r Feyd` then `sudo groupdel fremen`

---

## Module 8 — Networking

1. `ifconfig` (or `ifconfig -a` to include down interfaces) — `ifconfig` never resolves addresses to names in the first place, so no extra switch is needed here.
2. `route -n` — the `-n` switch is what forces numeric output; plain `route` will try to resolve destinations/gateways to hostnames via DNS, which is both slower and not what we want for exam purposes.
3. `ping -c 4 127.0.0.1`
4. `ssh student@127.0.0.1` then `pwd` to confirm `/home/student` — using the numeric loopback address instead of `localhost` also means later `last`/`lastb`/`who`/`w` log entries for this session will show `127.0.0.1` in the FROM/HOST column instead of the string `localhost`.
5. `sudo netstat -tulnp` — here `-n` gives numeric IP addresses and port numbers (no DNS/service-name lookups), `-t`/`-u` limit to TCP/UDP, `-l` shows listening sockets, and `-p` adds the owning PID/process.
6. `showmount -e 127.0.0.1` → lists `/srv/nfs_share`. `sudo mount -t nfs 127.0.0.1:/srv/nfs_share /mnt` (mkdir /mnt/point first if needed) → `cat /mnt/welcome.txt` → `sudo umount /mnt`
7. `sudo iptables -nvL OUTPUT --line-numbers` → find the line number next to `dpt:4444`/`spt:4444` DROP rule → `sudo iptables -D OUTPUT <line#>`
8. `sudo iptables -A OUTPUT -p tcp --sport 8080 -j DROP`
9. `sudo iptables -I FORWARD -j DROP` → `sudo iptables -nvL FORWARD` to confirm → `sudo iptables -D FORWARD 1` to remove it again.

---

## Module 9 — Logs, Login History & Auditing

1. `lastlog`
2. `who` (username, terminal, login time) vs `w` (adds idle time, CPU usage, and current running command per session).
3. `lastb | awk '{print $1}' | sort | uniq -c | sort -nr`
   → expected: **Bandit 9**, **Kerbe 6**, **DAME 3** (matching the counts the setup script generated — exact numbers will shift slightly if you re-ran the script or if `root` shows extra noise entries from console access).
4. Most: `Bandit`. Fewest: `DAME`.
5. `sudo lastb -F -w | tail` → earliest entry is at the bottom of chronological `lastb` output (most-recent-first ordering means the tail shows the oldest events).
6. `last -f /var/log/wtmp | grep -i Bandit` (or just `last | grep -i Bandit` if wtmp is the active log)
7. `sudo auditctl -a exit,always -F path=/home/student/warplans.hl -F perm=rwx -F key=WRKSTONE` then `sudo auditctl -l` to confirm.
8. `cat /home/student/warplans.hl` (triggers the read) then `sudo ausearch -k WRKSTONE`

---

## Module 10 — Scheduling & Automation

1. `crontab -l -u student` (as root) or `crontab -l` (as student)
2. `crontab -e -u student` → add:
   ```
   */2 * * * * cat /home/General_Graardor/Documents/warplans.txt >> /home/student/warplans.hl.bak
   ```
3. `crontab -l` to confirm; `ls -l /home/student/warplans.hl.bak` growing over successive 2-minute intervals confirms it fired.
4. `crontab -e` and delete just that line vs. `crontab -r` which wipes the **entire** crontab for that user — know which one you mean before you run it.

---

## Module 11 — Bash Scripting: if / elif / else

Completed `/home/student/scripts/user_status.sh`:
```bash
#!/usr/bin/env bash
USERNAME="$1"

if ! id "$USERNAME" >/dev/null 2>&1; then
  echo "No such user"
elif passwd -S "$USERNAME" 2>/dev/null | awk '{print $2}' | grep -q '^L$'; then
  echo "Locked"
else
  echo "Active"
fi
```
`passwd -S <user>` prints a status field where `L` = locked, `P`/`PS` = usable password, `NP` = no password set — the second field is what the `elif` checks.

---

## Module 12 — Package Management & System Control

1. `yum search tree` (or `dnf search tree`)
2. `sudo yum install -y tree` → `rpm -q tree` or `yum list installed tree` → `tree /opt/vault`
3. `yum list installed | grep tree` ; `yum info tree`
4. `sudo yum remove -y tree`
5. `sudo shutdown -r +5 "lab test"` → a wall broadcast message appears system-wide announcing the pending reboot → `sudo shutdown -c` cancels it before it executes.

---

## Notes for re-running the lab
- Failed-login counts in Module 9 are deterministic **per fresh run** of `setup_lab_environment.sh` (Bandit=9, Kerbe=6, DAME=3), but `/var/log/btmp` and `/var/log/wtmp` accumulate across runs unless you revert to your snapshot first — revert before re-testing that module for clean counts.
- The `iptables` rule-removal task (Module 8) is **destructive to itself** — the baseline `sport 4444` rule only exists once; revert to snapshot if you want to redo it.
- If your distro's `expect` package isn't available (minimal installs sometimes trim it), install from AppStream: `sudo dnf install -y expect` — it's in the base repos on Rocky/Alma/RHEL 8, no EPEL needed.
