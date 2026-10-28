"""Tiny helper to hand-craft realistic TCP/UDP flows with scapy."""
import random, struct, os
from scapy.all import Ether, IP, TCP, UDP, ICMP, ARP, DNS, DNSQR, DNSRR, Raw, wrpcap

random.seed(1337)
MAC = {
    "10.10.10.20": "08:00:27:aa:20:20",  # WKS01
    "10.10.10.30": "08:00:27:bb:30:30",  # watchtower (Ubuntu server)
    "10.10.10.10": "08:00:27:cc:10:10",  # DC01 / DNS
    "10.10.10.66": "08:00:27:de:ad:66",  # intruder
    "10.10.10.1":  "52:54:00:12:35:00",  # NAT gateway
}
def mac(ip): return MAC.get(ip, "52:54:00:12:35:%02x" % (__import__("zlib").crc32(ip.encode()) & 0xff))

class Clock:
    def __init__(self, start): self.t = start
    def tick(self, lo=0.0004, hi=0.004):
        self.t += random.uniform(lo, hi); return self.t
    def wait(self, s): self.t += s

class Capture:
    def __init__(self, start=1790000000.0):
        self.pkts = []; self.clk = Clock(start)
    def add(self, p, dt=None):
        p.time = self.clk.tick() if dt is None else (self.clk.t + dt)
        if dt is not None: self.clk.t = p.time
        self.pkts.append(p); return p
    def save(self, path):
        self.pkts.sort(key=lambda p: p.time)
        wrpcap(path, self.pkts)

class TCPFlow:
    MSS = 1400
    def __init__(self, cap, cip, sip, sport, cport=None, win=64240):
        self.cap, self.cip, self.sip, self.sport = cap, cip, sip, sport
        self.cport = cport or random.randint(49152, 65000)
        self.cseq = random.randint(1000, 2**31); self.sseq = random.randint(1000, 2**31)
        self.win = win; self.ipid = random.randint(1, 60000)
    def _pkt(self, from_client, flags, payload=b"", dt=None, extra_opts=None):
        if from_client:
            s, d, sp, dp, seq, ack = self.cip, self.sip, self.cport, self.sport, self.cseq, self.sseq
        else:
            s, d, sp, dp, seq, ack = self.sip, self.cip, self.sport, self.cport, self.sseq, self.cseq
        self.ipid = (self.ipid + 1) & 0xffff
        tcp = TCP(sport=sp, dport=dp, flags=flags, seq=seq, ack=ack if 'A' in flags else 0, window=self.win)
        if extra_opts: tcp.options = extra_opts
        p = Ether(src=mac(s), dst=mac(d)) / IP(src=s, dst=d, id=self.ipid, ttl=128 if s.endswith('.20') else 64) / tcp
        if payload: p = p / Raw(payload)
        self.cap.add(p, dt)
        n = len(payload) + (1 if 'S' in flags or 'F' in flags else 0)
        if from_client: self.cseq = (self.cseq + n) & 0xffffffff
        else: self.sseq = (self.sseq + n) & 0xffffffff
    def handshake(self):
        opts = [('MSS', 1460), ('SAckOK', b''), ('WScale', 8)]
        self._pkt(True, 'S', extra_opts=opts)
        self._pkt(False, 'SA', extra_opts=opts, dt=random.uniform(0.0005, 0.002))
        self._pkt(True, 'A')
    def send(self, from_client, data, gap=0.003):
        data = data if isinstance(data, bytes) else data.encode()
        first = True
        for i in range(0, len(data), self.MSS):
            chunk = data[i:i+self.MSS]; last = i + self.MSS >= len(data)
            self._pkt(from_client, 'PA' if last else 'A', chunk, dt=gap if first else None); first = False
        self._pkt(not from_client, 'A')
    def close(self, client_first=True):
        self._pkt(client_first, 'FA'); self._pkt(not client_first, 'FA'); self._pkt(client_first, 'A')
    def reset(self, from_client=True): self._pkt(from_client, 'RA')

def dns_query(cap, cip, dip, name, qtype='A', answer=None, rcode=0, sport=None, ttl=300, dt=None):
    sport = sport or random.randint(49152, 65000); txid = random.randint(1, 65535)
    qt = {'A': 1, 'AAAA': 28, 'TXT': 16, 'CNAME': 5, 'PTR': 12}[qtype]
    q = Ether(src=mac(cip), dst=mac(dip)) / IP(src=cip, dst=dip) / UDP(sport=sport, dport=53) / \
        DNS(id=txid, rd=1, qd=DNSQR(qname=name, qtype=qt))
    cap.add(q, dt)
    an = None
    if answer is not None and rcode == 0:
        an = DNSRR(rrname=name, type=qt, ttl=ttl, rdata=answer)
    r = Ether(src=mac(dip), dst=mac(cip)) / IP(src=dip, dst=cip) / UDP(sport=53, dport=sport) / \
        DNS(id=txid, qr=1, rd=1, ra=1, rcode=rcode, qd=DNSQR(qname=name, qtype=qt), an=an, ancount=1 if an else 0)
    cap.add(r, random.uniform(0.004, 0.03))

def ping(cap, src, dst, n=4, dt=None):
    ident = random.randint(1, 60000)
    for i in range(n):
        req = Ether(src=mac(src), dst=mac(dst)) / IP(src=src, dst=dst, ttl=128) / ICMP(type=8, id=ident, seq=i+1) / Raw(b"abcdefghijklmnopqrstuvwabcdefghi")
        cap.add(req, dt if i == 0 else 1.0)
        rep = Ether(src=mac(dst), dst=mac(src)) / IP(src=dst, dst=src, ttl=64) / ICMP(type=0, id=ident, seq=i+1) / Raw(b"abcdefghijklmnopqrstuvwabcdefghi")
        cap.add(rep, random.uniform(0.0004, 0.0012))

def arp_pair(cap, asker, target, dt=None):
    req = Ether(src=mac(asker), dst="ff:ff:ff:ff:ff:ff") / ARP(op=1, hwsrc=mac(asker), psrc=asker, hwdst="00:00:00:00:00:00", pdst=target)
    cap.add(req, dt)
    rep = Ether(src=mac(target), dst=mac(asker)) / ARP(op=2, hwsrc=mac(target), psrc=target, hwdst=mac(asker), pdst=asker)
    cap.add(rep)
