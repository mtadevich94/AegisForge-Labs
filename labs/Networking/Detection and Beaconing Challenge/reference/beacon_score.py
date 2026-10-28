#!/usr/bin/env python3
"""REFERENCE ANSWER: score connection pairs by how beacon-like they look.

Open this only after you have written your own hunt script.

    python3 beacon_score.py conns.csv [tls.csv] [--rank regularity|full] [--include-internal]

Input is the conns.csv (and optionally tls.csv) made by Tools/pcap_to_tables.py,
or any table with the same columns (for example one made from Zeek's conn.log).

Every score is a number between 0 and 1 built from things you can explain:

  regularity   how steady the gaps between connections are (low coefficient of variation = steady)
  constancy    how similar the bytes sent and received are from one connection to the next
  rarity       1 / how many internal hosts talk to that destination (a destination only one host
               calls is stranger than one everyone calls)
  external     0 if the destination is a private (RFC1918) address, else 1

  --rank regularity   score = regularity only. This is the naive version: watch what rises to the top.
  --rank full         score = regularity x constancy x rarity x external   (default)

It is a triage tool, not a verdict. It tells you where to look first.
"""
import csv, ipaddress, statistics, sys
from collections import defaultdict, Counter

# "Internal" means the three RFC 1918 private ranges. (Python's is_private would also
# count the documentation ranges this lab uses for fictional internet hosts.)
INTERNAL = [ipaddress.ip_network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")]
def is_internal(ip):
    a = ipaddress.ip_address(ip)
    return any(a in n for n in INTERNAL)

def cv(values):
    m = statistics.mean(values)
    return statistics.pstdev(values) / m if m else 0.0

def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    rank = "full"
    if "--rank" in argv:
        rank = argv[argv.index("--rank") + 1]; args.remove(rank)
    include_internal = "--include-internal" in argv
    conns_path = args[0]
    tls_path = args[1] if len(args) > 1 else None

    rows = list(csv.DictReader(open(conns_path)))
    names = {}
    if tls_path:
        by_dst = defaultdict(Counter)
        for r in csv.DictReader(open(tls_path)):
            by_dst[r["dst"]][r["sni"]] += 1
        names = {d: c.most_common(1)[0][0] for d, c in by_dst.items()}

    sources_per_dst = defaultdict(set)
    pairs = defaultdict(list)
    for r in rows:
        sources_per_dst[r["dst"]].add(r["src"])
        pairs[(r["src"], r["dst"], r["dport"], r["proto"])].append(r)

    out = []
    for (src, dst, dport, proto), rs in pairs.items():
        if len(rs) < 6:
            continue
        ts = sorted(float(r["ts"]) for r in rs)
        gaps = [b - a for a, b in zip(ts, ts[1:])]
        mean_gap = statistics.mean(gaps)
        cv_gap = cv(gaps)
        regularity = max(0.0, 1.0 - cv_gap / 0.25)
        cv_bytes = cv([float(r["orig_bytes"]) for r in rs]) + cv([float(r["resp_bytes"]) for r in rs])
        constancy = max(0.0, 1.0 - cv_bytes / 0.2)
        rarity = 1.0 / len(sources_per_dst[dst])
        external = 0.0 if is_internal(dst) and not include_internal else 1.0
        score = regularity if rank == "regularity" else regularity * constancy * rarity * external
        out.append((score, src, dst, dport, proto, len(rs), mean_gap, cv_gap, cv_bytes,
                    len(sources_per_dst[dst]), names.get(dst, "")))

    out.sort(reverse=True)
    print(f"{'score':>5}  {'source':<12} {'destination':<16} {'port':>5} {'conns':>5} {'gap(s)':>7} {'gapCV':>6} {'sizeCV':>6} {'srcs':>4}  name")
    for s, src, dst, dport, proto, n, g, cvg, cvb, srcs, name in out[:12]:
        print(f"{s:5.2f}  {src:<12} {dst:<16} {dport:>5} {n:5d} {g:7.1f} {cvg:6.3f} {cvb:6.3f} {srcs:4d}  {name}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
