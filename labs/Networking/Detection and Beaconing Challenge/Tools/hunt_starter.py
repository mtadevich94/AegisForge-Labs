#!/usr/bin/env python3
"""STARTER for the hunt. It loads the tables and shows you the raw material.
It does NOT score anything. That part is yours.

    python3 hunt_starter.py conns.csv [dns.csv] [tls.csv]

For every source -> destination:port pair it prints how many connections there were
and the gaps (in seconds) between consecutive ones. Pairs are sorted by connection count.

Your job: turn "here are some gaps" into "here is how steady they are" (hint: standard
deviation divided by the mean), then add the other things the checklist asks about
(size, how many machines call the destination, whether it is internal) and decide what
to rank first. Put your scoring in your own file, for example hunt.py.
"""
import csv, sys
from collections import defaultdict

def read(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))

conns = read(sys.argv[1])
names = {}
for path in sys.argv[2:]:
    for r in read(path):
        # tls.csv has dst + sni; dns.csv has qname only. We map what we can.
        if "sni" in r and r["sni"]:
            names[r["dst"]] = r["sni"]

pairs = defaultdict(list)
for r in conns:
    pairs[(r["src"], r["dst"], r["dport"])].append(float(r["ts"]))

print(f"{'source':<14}{'destination':<17}{'port':<6}{'conns':>5}  gaps (first 6, seconds)   name")
for key, times in sorted(pairs.items(), key=lambda kv: -len(kv[1]))[:20]:
    times.sort()
    gaps = [round(b - a, 1) for a, b in zip(times, times[1:])]
    print(f"{key[0]:<14}{key[1]:<17}{key[2]:<6}{len(times):>5}  {str(gaps[:6]):<26}{names.get(key[1], '')}")
