# Detection Lab Setup

Everything in this challenge runs on one Ubuntu machine reading capture files. [WATCHTOWER](../../Lab%20Foundations/VM%20Cards/WATCHTOWER.md) is the natural choice. Any Ubuntu 24.04 machine, VM or not, works.

## 1. Install the tools

```bash
sudo apt update
sudo apt install -y suricata tshark python3 python3-scapy
suricata --build-info | head -3        # confirm it runs
```

Answer **No** if tshark asks whether non-root users may capture; you only read files.

The rules in this lab were tested with **Suricata 7.0.3** and **tshark 4.2** on Ubuntu 24.04. Newer versions should work. If a rule you copy from the internet fails, check which Suricata version it was written for.

## 2. Get the files

Copy this folder to the machine (or clone the labs repo). You need `pcap/07-hunt.pcap`, `Tools/`, and the two Packet Watch captures `05-scan.pcap` and `06-incident.pcap` from `labs/Systems Administration/Wireshark Labs/pcap/`.

Verify the hunt capture against the checksums in this folder:

```bash
sha256sum -c SHA256SUMS
```

## 3. Replay a capture through Suricata

```bash
suricata -T -S my.rules -c /etc/suricata/suricata.yaml    # check the rules parse (fast)
mkdir -p out && rm -rf out/*
suricata -r 05-scan.pcap -S my.rules -l out -k none
cat out/fast.log
```

| Flag | Meaning |
|---|---|
| `-r file` | Read this capture instead of a network card |
| `-S my.rules` | Load **only** this rules file (so the lab's rules are not mixed with the default ruleset) |
| `-l out` | Write logs into `out/` |
| `-k none` | Don't verify checksums (the lab captures have none) |

Your alerts are in `out/fast.log`. Syntax errors are in `out/suricata.log`: look there first when a rule does nothing.

> **Known quirk: thresholds in offline replay.** Rules with `threshold` or `detection_filter` count events in a time window. When Suricata reads a file it does not behave exactly like a strict sliding window, and the same capture can alert at **slightly different moments, or a different number of times, from run to run**. On live traffic this is much steadier. For the challenge: judge your rules by whether they catch the attack and stay quiet on the quiet night, not by the exact timestamp or by getting precisely one alert. Run each test three times.

## 4. Turn a capture into tables (for the hunt)

```bash
python3 Tools/pcap_to_tables.py pcap/07-hunt.pcap tables
ls tables      # conns.csv  dns.csv  tls.csv
```

| File | Columns |
|---|---|
| `conns.csv` | `ts, proto, src, dst, dport, orig_bytes, resp_bytes, duration` |
| `dns.csv` | `ts, src, qname, qtype` (qtype is a number: `1` = A, `16` = TXT) |
| `tls.csv` | `ts, src, dst, sni` (the server name a client asked for) |

`ts` is seconds since the capture started. Open the CSVs in a spreadsheet, `pandas`, or plain Python.

For a head start, `python3 Tools/hunt_starter.py tables/conns.csv tables/tls.csv` prints every source→destination pair with its connection gaps. Scoring them is your job.

## 5. Zeek (optional, unverified)

Zeek produces logs very like the tables above (`conn.log`, `dns.log`, `ssl.log`), and it is what many teams hunt with. It is **not** part of the tested path for this challenge, and the commands below were **not** run when this lab was written. Treat them as a starting point.

```bash
# Zeek is not in Ubuntu's default repositories. See zeek.org for install steps for your version.
mkdir zeek-out && cd zeek-out
zeek -C -r ../pcap/07-hunt.pcap
zeek-cut ts id.orig_h id.resp_h id.resp_p orig_bytes resp_bytes duration < conn.log | head
```

If you do this, the reference scoring script reads any table with the `conns.csv` columns, so you can convert `conn.log` and reuse it.

## 6. Reset

```bash
rm -rf out tables
```
