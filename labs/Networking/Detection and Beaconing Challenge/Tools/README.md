# Tools

| File | What it does |
|---|---|
| `pcap_to_tables.py` | Turns a capture into `conns.csv`, `dns.csv`, `tls.csv` for the hunt. `python3 pcap_to_tables.py <pcap> <outdir>` |
| `make_hunt_pcap.py` | Maintainer script. Regenerates `pcap/07-hunt.pcap` (seeded, so the output is identical every time). `python3 make_hunt_pcap.py ../pcap` |
| `flowlib.py` | Helper used by the generator. A copy of the Packet Watch lab's helper, kept here so this folder stands alone. |

You only need `pcap_to_tables.py` to do the challenge. The generator is here so you can see how the quiet night was built, and change it for the stretch goal.
