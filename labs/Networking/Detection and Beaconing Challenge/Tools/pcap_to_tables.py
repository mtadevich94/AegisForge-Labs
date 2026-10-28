#!/usr/bin/env python3
"""Turn a pcap into three small CSV tables: the metadata a defender hunts in.

    python3 pcap_to_tables.py ../pcap/07-hunt.pcap  out-folder

Writes:
    conns.csv  ts,proto,src,dst,dport,orig_bytes,resp_bytes,duration   (one row per connection, DNS excluded)
    dns.csv    ts,src,qname,qtype                                      (one row per DNS query)
    tls.csv    ts,src,dst,sni                                          (one row per TLS ClientHello)

This is the same idea as Zeek's conn.log, dns.log and ssl.log, built with
tshark so that you can hunt without installing Zeek. If you have Zeek, you can
produce the same columns from its logs (see "Detection Lab Setup.md").

This script only reshapes data. It does not decide what is suspicious.
Needs: tshark (the command-line half of Wireshark) and Python 3.
"""
import csv, os, subprocess, sys

FIELDS = ["frame.time_epoch", "ip.src", "ip.dst", "tcp.stream", "udp.stream",
          "tcp.dstport", "udp.dstport", "udp.srcport", "tcp.len", "udp.length",
          "tcp.flags.syn", "tcp.flags.ack",
          "dns.qry.name", "dns.qry.type", "dns.flags.response",
          "tls.handshake.extensions_server_name"]

def main(pcap, outdir):
    os.makedirs(outdir, exist_ok=True)
    cmd = ["tshark", "-r", pcap, "-Y", "ip", "-T", "fields", "-E", "separator=\t"]
    for f in FIELDS:
        cmd += ["-e", f]
    raw = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.splitlines()

    streams = {}      # ("tcp"|"udp", stream id) -> dict
    dns_rows, tls_rows = [], []
    for line in raw:
        c = (line.split("\t") + [""] * len(FIELDS))[:len(FIELDS)]
        ts, src, dst, tcps, udps, tdp, udp_dp, udp_sp, tlen, ulen, syn, ack, qn, qt, isresp, sni = c
        ts = float(ts)
        if qn and isresp.lower() not in ("1", "true"):   # queries only, not responses
            dns_rows.append((ts, src, qn.split(",")[0], qt.split(",")[0]))
        if sni:
            tls_rows.append((ts, src, dst, sni.split(",")[0]))
        if tcps:
            key, proto, dport, payload = ("tcp", tcps), "tcp", tdp, int(tlen or 0)
        elif udps and "53" not in (udp_dp, udp_sp):   # DNS has its own table
            key, proto, dport, payload = ("udp", udps), "udp", udp_dp, max(int(ulen or 8) - 8, 0)
        else:
            continue
        s = streams.get(key)
        if s is None:
            s = streams[key] = dict(ts=ts, last=ts, proto=proto, src=src, dst=dst, dport=dport, ob=0, rb=0)
            # for TCP, the originator is whoever sent the SYN; the first packet seen is that SYN in our captures
        s["last"] = ts
        if src == s["src"]:
            s["ob"] += payload
        else:
            s["rb"] += payload

    with open(os.path.join(outdir, "conns.csv"), "w", newline="") as fh:
        w = csv.writer(fh); w.writerow(["ts", "proto", "src", "dst", "dport", "orig_bytes", "resp_bytes", "duration"])
        for s in sorted(streams.values(), key=lambda s: s["ts"]):
            w.writerow([f'{s["ts"]:.3f}', s["proto"], s["src"], s["dst"], s["dport"], s["ob"], s["rb"], f'{s["last"] - s["ts"]:.3f}'])
    with open(os.path.join(outdir, "dns.csv"), "w", newline="") as fh:
        w = csv.writer(fh); w.writerow(["ts", "src", "qname", "qtype"])
        for r in dns_rows: w.writerow([f"{r[0]:.3f}", *r[1:]])
    with open(os.path.join(outdir, "tls.csv"), "w", newline="") as fh:
        w = csv.writer(fh); w.writerow(["ts", "src", "dst", "sni"])
        for r in tls_rows: w.writerow([f"{r[0]:.3f}", *r[1:]])
    print(f"wrote conns.csv ({len(streams)} connections), dns.csv ({len(dns_rows)} queries), tls.csv ({len(tls_rows)} hellos) to {outdir}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
