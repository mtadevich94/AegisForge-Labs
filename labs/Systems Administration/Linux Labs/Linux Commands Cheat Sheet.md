# Linux Commands Cheat Sheet

The commands you'll use in the [Linux Administration Lab Guide](Linux%20Administration%20Lab%20Guide.md), grouped by task. For pattern matching, see the [Regex & grep Cheat Sheet](Linux%20Regex%20and%20grep%20Cheat%20Sheet.md).

> **Reading the examples:** anything in `<angle brackets>` is a blank for you to fill in. Lines starting with `#` are comments, not commands. Log in as `student` and put `sudo` in front of anything that needs root.

---

## 1. Users and accounts

```bash
sudo useradd -G operators alice        # new user, added to the SUPPLEMENTARY group "operators"
sudo passwd alice                      # set or change a password
sudo passwd -l alice                   # lock the account
sudo passwd -u alice                   # unlock it
sudo userdel -r alice                  # delete the user AND their home directory

sudo grep -E '^student:' /etc/passwd /etc/shadow      # one user's passwd and shadow entries
sudo grep -e alice -e bob /etc/shadow                 # check several accounts at once
```

**Reading `/etc/shadow`:** the second field is the password hash. A hash that starts with `!` means the account is **locked**. A `*` or `!!` means no password has been set, so password logins don't work.

**Pick out fields from `/etc/passwd`:**

```bash
cut -d : -f 1,6,7 /etc/passwd             # username, home directory, shell
cut -d : -f 1,6,7 /etc/passwd | tr : -    # same, with ":" swapped for "-"
```

---

## 2. Permissions and umask

```bash
umask                  # show the default permission mask (numbers)
umask -S               # the same thing in plain language
chmod 0644 file        # set exact permissions (octal)
chmod g+s dir          # add the SGID bit (new files inherit the group)
```

---

## 3. find: search by name, size or permission

```bash
find <path> -size 421c -perm 0421 -ls                    # exact size (bytes) + exact permissions
find <path> -type f -name '??????????????' -size 333c    # file name of exactly 14 characters
```

| Flag | Meaning |
|---|---|
| `-type f` / `-type d` | files only / directories only |
| `-name 'pattern'` | match the name. `?` = exactly one character, `*` = any number. |
| `-size 421c` | exactly 421 **bytes** (`c` = bytes). `+421c` = bigger than, `-421c` = smaller than. |
| `-perm 0421` | permissions match **exactly**. `-perm -0421` = at least these bits set. |
| `-ls` | print results like `ls -l` |

Count the `?` marks. One `?` per character in the file name you're hunting.

---

## 4. Listing several things at once (brace expansion)

```bash
ls -l /etc/{hosts,passwd,fstab}        # three different files
ls -l /etc/host{s,name}                # shared start: expands to /etc/hosts and /etc/hostname
```

---

## 5. Processes and open files

```bash
sudo lsof <file>                       # which process has this file open?
ps -f -p <PID>                         # details for one process
ps -f --ppid <PID>                     # CHILD processes of that PID
sudo lsof -p <PID>                     # every file that process has open
sudo lsof -R -p <PID>                  # same, plus a PPID (parent) column
sudo ls -la /proc/<PID>/fd             # file descriptors the process holds
sudo ls -la /proc/<PID>/fd/<N>         # where one descriptor points
```

> `lsof -R` adds the **parent PID** column. It does *not* mean "recursive".

Add `2>/dev/null` at the end of any command to hide the "permission denied" noise.

---

## 6. File type and timestamps

```bash
file <path>                            # what is this file? ("UTF-8 Unicode text" = plain text)
ls -la <path>                          # long listing: permissions, owner, size, modified time
sudo touch -r <reference> <target>     # copy the modified time from one file onto another
```

---

## 7. Login history

```bash
sudo last -f /var/log/wtmp | grep -n -i oct          # logins in a given month
sudo last -w -f /var/log/wtmp | grep -i oct | grep -e ' 08:'    # narrow to an hour
lastlog                                              # most recent login for every account
```

---

## 8. Cron: scheduled jobs

```bash
crontab -l                             # your own crontab
sudo crontab -l -u <user>              # another user's crontab
sudo ls -la /var/spool/cron/           # which users have a crontab at all
sudo sh -c 'cat /var/spool/cron/*'     # read ALL crontabs at once
```

> Use `sudo sh -c '...'` for that last one. Only root can open `/var/spool/cron`, and a plain `sudo cat /var/spool/cron/*` lets *your* shell expand the `*` first, which fails. On Ubuntu the folder is `/var/spool/cron/crontabs/`.

**Cron timing:** `minute  hour  day-of-month  month  day-of-week  command`

```
*/2 * * * *     command     # every 2 minutes
0 * * * *       command     # top of every hour
0 18 * * 6,0    command     # 18:00 on Saturday and Sunday
30 4 1 * *      command     # 04:30 on the 1st of each month
```

(Day-of-week: `0` or `7` = Sunday, `1` = Monday … `6` = Saturday.)

`crontab -e` edits your table. `crontab -r` **deletes the whole table**, so be sure.

**Spot the bad job.** When you review someone else's crontab, look for jobs that destroy or disrupt: `rm -rf /tmp/*`, `/sbin/shutdown -h now`, or anything downloading and running a script.

---

## 9. Firewall (iptables)

```bash
sudo iptables -nvL OUTPUT              # one chain, numeric, verbose
sudo iptables -L -n                    # all chains, numeric (no slow DNS lookups)
sudo iptables -L -n --line-numbers     # number the rules (needed for -D and -I)

sudo iptables -A INPUT -p tcp -m multiport --dports 72,43 -j DROP   # block several ports
sudo iptables -A OUTPUT -p tcp -d <IP> -j ACCEPT                    # allow traffic to a host
sudo iptables -A INPUT -p icmp -s <IP> -j ACCEPT                    # allow ping from a host
sudo iptables -A INPUT -p tcp -s <IP> -j ACCEPT                     # allow TCP from a host
sudo iptables -P INPUT DROP                                         # default policy: drop
```

Things to remember:

- With `-m multiport`, the flag is **`--dports`** (plural) and takes a comma-separated list. Plain `--dport` takes one port.
- Rules are checked **top to bottom**. `-A` adds to the bottom, `-I INPUT 1` inserts at the top.
- **Working over SSH?** Add your own ACCEPT rule *before* you set `-P INPUT DROP`. Drop first, and you lock yourself out of the VM. If that happens, use the VM's console window.
- Rules are lost on reboot unless you save them: `sudo service iptables save` (needs `iptables-services`).

---

## 10. Network shares (NFS)

```bash
ping -c 3 <IP>                         # is the server reachable?  (-c 3 = stop after 3)
showmount -e <IP>                      # list the shares the server exports
sudo mount <IP>:/share /mnt/share      # mount a share at a local folder (create the folder first)
ls -la /mnt/share                      # confirm the contents appeared
sudo umount /mnt/share                 # disconnect when finished
```

---

## 11. Bash scripting

**Check whether a folder exists, and act on the answer**

```bash
#!/bin/bash
testdir=/home/student/practice/scripting/test

if [[ -d $testdir ]]; then
  touch "$testdir/$(date +%y-%m-%d)"
  date +%H:%M:%S >> "$testdir/$(date +%y-%m-%d)"
else
  mkdir -p "$testdir"
fi

exit
```

**Check who is logged in, and branch**

```bash
#!/bin/bash
if [ "$USER" = "student" ]; then
  echo "You are logged in as student"
  echo "The current time is: $(date +%H:%M:%S)"
else
  echo "You are not logged in as student"
fi
exit
```

**To run a script:** save it as `myscript.sh`, then `chmod +x myscript.sh`, then `./myscript.sh`.

The first script creates the folder on its first run and writes the timestamp file on the second, so run it twice to see both branches.

**Common mistakes**

- **Spaces matter** inside `[ ]`. `[ "$USER" = "student" ]` works. `["$USER"="student"]` doesn't.
- **Quote your variables** (`"$USER"`). Unquoted, an empty value breaks the test.
- `[[ ]]` is bash's more forgiving version of `[ ]`. Either works for the lab.
- A missing closing quote on an `echo` string, or a missing `fi`, gives you a confusing error on the *last* line of the script.
- `exit` at the end is optional, but it makes a script finish cleanly.

---

## 12. Quick system information

```bash
uname -r                               # kernel version
echo $PATH                             # where the shell looks for commands
ip addr show <interface>               # one network interface's details
ifconfig <interface>                   # older command for the same (needs the net-tools package)
```

Not sure of the interface name? Run `ip -br addr` to list them all.
