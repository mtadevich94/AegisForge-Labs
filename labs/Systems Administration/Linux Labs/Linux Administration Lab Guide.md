# The Wrkstation Chronicles — RHEL 8 Practical Exam Lab
### Student Lab Guide

**Environment:** Rocky Linux 10, AlmaLinux 10, CentOS Stream 8, or RHEL 8 (minimal install)
**Setup:** Run `sudo bash setup_lab_environment.sh` once, then **snapshot the VM**.
**How to use this guide:** Work module by module. Each task tells you *what* to find or do — figure out the command yourself first, then check the Answer Key only if you're stuck or want to confirm.

---

## Access - Log into Linux
*Commands: SSH*
1. In Virtualbox, select your VM and press **START**
2. On your host device, open **Command Prompt** or **Powershell** and type 'ssh -p 2222 root@127.0.0.1'

---

## Module 1 — Getting Help & System Discovery
*Commands: man, help, info, whatis, which, whereis, apropos, locate, hostname, uname, date, file*

1. Find the manual page section number for `passwd` the *configuration file* (not the command).
2. Get a one-line description of `chage` using the "short description" lookup command.
3. Find the full path to the `grep` binary, and also every location on disk related to `grep` (binary, man pages, source).
4. Search the whatis database for every command whose description contains the word "partition." (You may need to build the database first.)
5. Locate every file on the system whose path contains `crontab` (build/update the locate database first if needed).
6. Print the system hostname, the kernel release version, and today's date in `YYYY-MM-DD` format, each with a single command.
7. Run `file` against `/opt/vault/shadowfiles/Nightshade` and against `/home/Zelda_Warden/star_charts.txt` — what type does each report?

---

## Module 2 — Filesystem Navigation & Manipulation
*Commands: ls, cd, pwd, mkdir, rmdir, rm, cp, mv, touch, cat, less, head, tail, ln, ls -lai*

1. **The Vault Puzzle:** Inside `/opt/vault/shadowfiles`, find the one file that has:
   - a name that is **exactly 10 characters long**
   - a size of **exactly 512 bytes**
   - permission mode **0640**

   Use a single `find` command with `-name`, `-size`, and `-perm`. Report the filename and its owner.
2. Show the inode number of that file, and the inode number of its parent directory.
3. Create a hard link from `/home/General_Graardor/Documents/warplans.txt` to `/home/student/warplans_copy.hl` (a second hardlink, in addition to the one setup already made). Prove with `ls -lai` that both point to the same inode.
4. Create a **symbolic** link instead, pointing to the same file, and show how `ls -la` displays it differently from a hard link.
5. Using `head` and `tail`, show only the first line and only the last line of `/home/Zelda_Warden/star_charts.txt` without opening it in an editor.
6. Page through `/etc/passwd` with `less`, then quit without making changes.
7. Practice cleanup: `mkdir` a scratch directory under `/tmp`, `touch` three files in it, `cp` one out to your home directory, `mv`/rename another, then `rm` the files and `rmdir` the now-empty directory.

---

## Module 3 — Permissions, Ownership & Groups
*Commands: chmod, umask, chown, newgrp, id*

1. Check your current `umask`. Create a new file and a new directory and record the default permissions each receives. Explain the math (base perms minus umask) in one sentence.
2. Change your umask to `027` for the current shell session, create another file, and show the difference in resulting permissions.
3. On `/home/student/warplans.hl`, set permissions so the owner has read/write, the group has read-only, and others have none — using **symbolic** mode (`u=`, `g=`, `o=`).
4. Now set the exact same permissions using **numeric/octal** mode, on a copy of the file, and confirm both files show identical `ls -l` permission strings.
5. Change the owner **and** group of `/home/student/warplans_copy.hl` to `Zelda_Warden` in a single `chown` command.
6. Show your own UID, GID, and all supplementary group memberships with one command.
7. If you belong to more than one group, use `newgrp` to switch your active primary group for the session, then confirm the change.

---

## Module 4 — Shell Environment, Variables & the Editor
*Commands: set, unset, env, export, echo, $SHELL, chsh, vim*

1. Print the value of `$SHELL` and also print the full list of currently exported environment variables.
2. Create a local shell variable `QUEST="find the crown"`, confirm it does **not** appear in `env` output, then `export` it and confirm it now does.
3. `unset` that variable and confirm it's gone from both `set` and `env`.
4. Check what your default login shell is set to in `/etc/passwd`, then use the correct command to change `student`'s shell to `/bin/sh` (you'll need `sudo`).
5. Open `/home/student/scripts/user_status.sh` in `vim`. Using vim, navigate to line 10, delete a line (`dd`), yank and paste a line (`yy` / `p`), search for the word `TODO` (`/TODO`), and save without quitting (`:w`) before finally saving and quitting (`:wq`).

---

## Module 5 — Text Processing, Filters, Regex & xargs
*Commands: grep (incl. -E), wc, sort, cut, tr, paste, xargs*

1. **Passwd/Shadow correlation:** Produce a file at `/home/student/userinfo.txt` containing, for every account whose shell is `/bin/sh`: username, home directory, shell, and full password hash field — using `paste` to join `/etc/passwd` and `/etc/shadow`, then `grep` and `cut` to filter and select fields.
2. Count how many lines are in `/etc/passwd` and how many words are in `/home/Zelda_Warden/star_charts.txt`.
3. **The Star Chart Puzzle:** Using an extended regex (`grep -E`) with bracket expressions and repetition operators, find the line(s) in `/home/Zelda_Warden/star_charts.txt` that match the pattern of **exactly four** dot-or-dash-separated groups of 1–3 digits (e.g. `NN.NN-NN.NN`), anchored so partial/longer matches don't count.
4. Sort `/etc/passwd` alphabetically by username, then sort it numerically by UID (3rd field) — show both commands.
5. Use `tr` to convert the contents of `/home/Zelda_Warden/star_charts.txt` to all uppercase, without modifying the original file.
6. Use `xargs` to `chmod 644` every file inside `/opt/vault/shadowfiles/` in one line, piping the file list from `find`.

---

## Module 6 — Process Control
*Commands: ps, ps -f, ps -p $$, lsof, jobs, fg, bg, kill, killall, systemctl*

1. Find the PID of the background process named `WizardTower` (started by the setup script) using `ps -ef` piped through `grep`.
2. Use `lsof` to show what that process has open, and separately inspect the same information via `/proc/<PID>/fd`.
3. Show the PID and parent PID of your **current shell** using `ps -p $$`.
4. Show a full-format listing (`ps -f`) of just your own processes.
5. **Job control (interactive — do this by hand, not scriptable):** run `sleep 300`, suspend it with `Ctrl+Z`, list it with `jobs`, resume it in the background with `bg`, bring it back to the foreground with `fg`, then stop it for good with `Ctrl+C`.
6. Kill the `WizardTower` process two ways: once by PID with `kill`, and (after restarting it) once by name with `killall`.
   - Restart it with: `nohup bash -c 'exec -a WizardTower sleep 100000' >/dev/null 2>&1 & disown`
7. Check the status of the `atd` service with `systemctl`, then stop it, confirm it's stopped, then start and enable it again.

---

## Module 7 — User, Group & Account Management
*Commands: useradd, usermod, userdel, groupadd, groupmod, groupdel, passwd, chage, su*

1. Create a new group called `rebels`.
2. Create a new user `Feyd` with a home directory, a comment field of "Harkonnen Heir," and add them to the `rebels` group as a supplementary group.
3. Rename the `rebels` group to `fremen` with `groupmod`.
4. Set/reset `Feyd`'s password with `passwd`.
5. Use `chage -l` to view `Feyd`'s password aging info, then set their account to expire 30 days from today.
6. Add `Feyd` to the `arrakis` group as an additional supplementary group with `usermod -aG` (verify their existing groups aren't removed).
7. Switch user to `Feyd` with `su - Feyd`, confirm with `id`, then exit back to your own session.
8. Delete `Feyd`, including their home directory, with `userdel`. Then delete the `fremen` group.

---

## Module 8 — Networking
*Commands: ifconfig, route, ping, ssh, netstat, showmount, mount, iptables*

1. Show all network interfaces and their IP addresses with `ifconfig`. Compare the output to the modern equivalent (`ip addr`) if you want, but answer using `ifconfig`.
2. Show the kernel routing table with the switch that displays destinations, gateways, and interfaces as **numeric addresses** rather than resolved network/host names — not the plain `route` command by itself.
3. `ping` `127.0.0.1` for a fixed count of 4 packets (don't let it run forever).
4. `ssh` into your own VM as the `student` user, connecting to the **numeric loopback address** (`127.0.0.1`) rather than the name `localhost`, and confirm you land in `/home/student`.
5. Show active listening ports and established connections using the switch combination that reports **numeric IP addresses and numeric port numbers** (not resolved hostnames or service names like `ssh`/`http`) — you may need `sudo`.
6. Use `showmount -e 127.0.0.1` to list the NFS exports being offered, then `mount` `127.0.0.1:/srv/nfs_share` to a new mount point under `/mnt`, and `cat` the welcome file inside it. Unmount when done.
7. **iptables investigation:** List the `OUTPUT` chain with line numbers (`iptables -nvL OUTPUT --line-numbers`), find the rule dropping traffic from source port `4444`, and remove it by line number with `iptables -D`.
8. Add a **new** rule that drops outbound traffic with source port `8080`.
9. Temporarily block **all** forwarded traffic on the `FORWARD` chain, confirm it's there, then remove it again so you don't lock yourself out of anything else.

---

## Module 9 — Logs, Login History & Auditing
*Commands: lastlog, last, lastb, who, w, auditctl, ausearch*

1. Show every account's last login time with `lastlog`.
2. Show currently logged-in users two ways: `who` and `w` — note what extra information `w` gives you.
3. **Failed login investigation:** Use `lastb` to list all failed login attempts, then sort and deduplicate by username to produce a count per user, ranked highest to lowest (`awk` + `sort` + `uniq -c` + `sort -nr`, same pattern as counting technique from prior labs).
4. From that same `lastb` output, determine which username had the **most** failed attempts and which had the **fewest**.
5. Determine the timestamp of the very **first** failed login attempt in the log, using full date/time and full name output flags.
6. Validate that `Bandit`'s one **successful** login actually happened, by filtering `last` output for that username.
7. Set an audit rule watching `/home/student/warplans.hl` for all read/write/execute access, tagged with a custom key, then confirm it's active with `auditctl -l`.
8. Trigger the rule (e.g. `cat /home/student/warplans.hl`), then use `ausearch` filtered by your custom key to find the resulting audit event.

---

## Module 10 — Scheduling & Automation
*Commands: crontab*

1. View any existing crontab for the `student` user.
2. Add a cron job (as `student`, or as root targeting `student` with `-u`) that runs every 2 minutes and appends the contents of `/home/General_Graardor/Documents/warplans.txt` to `/home/student/warplans.hl.bak` — mirroring the copy/append pattern used in the setup script's audit scenario.
3. Confirm the job is listed with `crontab -l`, wait for it to fire at least once, and verify the backup file grew.
4. Remove the cron job when you're done (`crontab -e` and delete the line, or `crontab -r` to wipe the whole table — know the difference between the two).

---

## Module 11 — Bash Scripting: if / elif / else
*File: `/home/student/scripts/user_status.sh`*

1. Complete the skeleton script so that running `./user_status.sh <username>` prints:
   - `No such user` if the account doesn't exist
   - `Locked` if the account exists but is password-locked
   - `Active` if the account exists and is unlocked

   You'll need `if [ ... ]; then ... elif [ ... ]; then ... else ... fi` syntax, and one of `id`, `passwd -S`, or `chage -l` to determine lock status.
2. Test it against `student` (should be Active), against `Vaultkeeper` if you disable their login another way, and against a made-up username (should be "No such user").

---

## Module 12 — Package Management & System Control
*Commands: yum, shutdown*

1. Search for a package called `tree` in the repos.
2. Install it, confirm it's installed, then run it against `/opt/vault`.
3. List installed packages and confirm `tree` appears; get info on the package with `yum info tree`.
4. Remove the package again.
5. Schedule a reboot 5 minutes from now with `shutdown -r +5 "lab test"`, confirm the pending shutdown message, then **cancel it** with `shutdown -c` before it fires.

---

## Wrap-up
By the end of this lab you should be able to, from memory, under exam time pressure:
- Locate any file by name pattern, size, and permission bits
- Correlate `/etc/passwd` and `/etc/shadow` data with `paste`/`cut`/`grep`
- Build and read extended regex patterns for structured text
- Investigate failed/successful logins and back it with an `auditctl`/`ausearch` trail
- Manage users, groups, permissions, processes, cron jobs, and firewall rules end-to-end

Good luck out there, Wrkstation Keeper.
