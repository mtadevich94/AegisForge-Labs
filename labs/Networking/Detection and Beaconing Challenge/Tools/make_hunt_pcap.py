"""Maintainer script: regenerates pcap/07-hunt.pcap ("A Quiet Night in the Realm").

    python3 make_hunt_pcap.py ../pcap

Needs scapy (pip install scapy). flowlib.py is a copy of the helper from the
Packet Watch lab's tools folder, kept here so this folder stands on its own.

What the capture contains (50 minutes, all fictional):
  * WKS01 browsing in bursts, the way a person does (irregular on purpose)
  * SRV01, DC01 and WKS01 checking a vendor telemetry service every ~5 minutes
  * SRV01 asking DC01 for the time every 64 seconds (very regular, harmless)
  * WKS01 polling a mail server every ~90 seconds with +/-15% jitter (regular-ish, harmless)
  * a few plaintext web requests to the intranet server (WATCHTOWER) and one cleartext login
  * three page loads that open 8 connections in under half a second (a busy page, not a scan)
  * ONE beacon: WKS01 calling home to api.forge-updates.example every ~60 seconds
    with +/-10% jitter and small, nearly constant request and response sizes
The point of the capture is that "regular" is not the same as "malicious".
"""
import sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flowlib
from flowlib import *

# Anything outside 10.10.10.0/24 is reached through the NAT gateway's MAC address.
_orig_mac = flowlib.mac
flowlib.mac = lambda ip: _orig_mac(ip) if ip.startswith("10.10.10.") else "52:54:00:12:35:00"
mac = flowlib.mac

random.seed(2026)
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
T0 = 1790020000.0
DURATION = 3000.0           # seconds
WKS, SRV, DC = "10.10.10.20", "10.10.10.40", "10.10.10.10"
BEACON_IP, BEACON_NAME = "203.0.113.77", "api.forge-updates.example"
TELEM_IP, TELEM_NAME = "198.51.100.40", "telemetry.update-service.example"
MAIL_IP, MAIL_NAME = "192.0.2.25", "imap.mail-host.example"

SITES = [
    ("www.professormesser.com", "104.21.34.88"), ("tryhackme.com", "172.67.27.10"),
    ("docs.opnsense.org", "203.0.113.10"), ("www.wireshark.org", "203.0.113.11"),
    ("learn.microsoft.com", "203.0.113.12"), ("github.com", "203.0.113.13"),
    ("www.cloudflare.com", "203.0.113.14"), ("attack.mitre.org", "203.0.113.15"),
    ("docs.suricata.io", "203.0.113.16"), ("www.reddit.com", "203.0.113.17"),
    ("en.wikipedia.org", "203.0.113.18"), ("news.ycombinator.com", "203.0.113.19"),
]

def enc(n): return b"\x17\x03\x03" + n.to_bytes(2, "big") + bytes(random.getrandbits(8) for _ in range(n))

def tls_hello(sni):
    rnd = bytes(random.getrandbits(8) for _ in range(32)); sid = bytes(random.getrandbits(8) for _ in range(32))
    ciphers = bytes.fromhex("130113021303c02bc02fc02cc030cca9cca8c013c014009c009d002f0035")
    sn = sni.encode()
    ext_sni = b"\x00\x00" + (len(sn)+5).to_bytes(2, "big") + (len(sn)+3).to_bytes(2, "big") + b"\x00" + len(sn).to_bytes(2, "big") + sn
    exts = (ext_sni + bytes.fromhex("000a00080006001d00170018") + bytes.fromhex("000b00020100")
            + bytes.fromhex("000d00140012040308040401050308050501080606010201")
            + bytes.fromhex("002b0005040304" "0303") + bytes.fromhex("0010000e000c02683208687474702f312e31"))
    body = b"\x03\x03" + rnd + bytes([32]) + sid + len(ciphers).to_bytes(2, "big") + ciphers + b"\x01\x00" + len(exts).to_bytes(2, "big") + exts
    hs = b"\x01" + len(body).to_bytes(3, "big") + body
    return b"\x16\x03\x01" + len(hs).to_bytes(2, "big") + hs, sid

def tls_server(sid):
    rnd = bytes(random.getrandbits(8) for _ in range(32))
    body = b"\x03\x03" + rnd + bytes([32]) + sid + b"\x13\x01\x00" + bytes.fromhex("002e002b0002030400330024001d0020") + bytes(random.getrandbits(8) for _ in range(32))
    hs = b"\x02" + len(body).to_bytes(3, "big") + body
    return b"\x16\x03\x03" + len(hs).to_bytes(2, "big") + hs + b"\x14\x03\x03\x00\x01\x01" + enc(1800)

cap = Capture(T0)
events = []   # (seconds_from_start, callable)

def at(t, fn): events.append((t, fn))

def https_visit(client, name, ip, req, resp, port=443, extra_records=0):
    dns_query(cap, client, DC, name, "A", ip, ttl=60)
    cap.clk.wait(random.uniform(0.01, 0.05))
    f = TCPFlow(cap, client, ip, port); f.handshake()
    ch, sid = tls_hello(name)
    f.send(True, ch); f.send(False, tls_server(sid))
    f.send(True, b"\x14\x03\x03\x00\x01\x01" + enc(53))
    f.send(True, enc(req), gap=0.02)
    f.send(False, enc(resp), gap=0.03)
    for _ in range(extra_records):
        f.send(True, enc(random.randint(120, 900)), gap=random.uniform(0.2, 1.5))
        f.send(False, enc(random.randint(400, 3000)), gap=0.05)
    f.close()

def ntp(client, server):
    sport = random.randint(49152, 65000)
    body = bytes([0x23]) + bytes(47)
    cap.add(Ether(src=mac(client), dst=mac(server)) / IP(src=client, dst=server) / UDP(sport=sport, dport=123) / Raw(body))
    cap.add(Ether(src=mac(server), dst=mac(client)) / IP(src=server, dst=client) / UDP(sport=123, dport=sport) / Raw(bytes([0x24]) + bytes(47)), random.uniform(0.0005, 0.003))

# ---- plaintext intranet traffic (WATCHTOWER, port 80) ----------------------------
WT = "10.10.10.30"
def http_req(method, path, body=""):
    h = f"{method} {path} HTTP/1.1\r\nHost: watchtower.gielinor.local\r\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/131.0\r\nAccept: text/html,*/*;q=0.8\r\n"
    if body: h += f"Content-Type: application/x-www-form-urlencoded\r\nContent-Length: {len(body)}\r\n"
    return (h + "\r\n" + body).encode()
def http_resp(status, body, extra=""):
    b = body.encode()
    return (f"HTTP/1.1 {status}\r\nServer: Werkzeug/3.0.4 Python/3.12.3\r\nContent-Type: text/html; charset=utf-8\r\n{extra}Content-Length: {len(b)}\r\nConnection: close\r\n\r\n").encode() + b
def intranet(method, path, body="", status="200 OK", reply="<h1>Wizard Tower Intranet</h1>", extra=""):
    dns_query(cap, WKS, DC, "watchtower.gielinor.local", "A", WT, ttl=300)
    f = TCPFlow(cap, WKS, WT, 80); cap.clk.wait(0.02); f.handshake()
    f.send(True, http_req(method, path, body)); f.send(False, http_resp(status, reply, extra)); f.close()

t = 60.0
while t < DURATION - 60:
    kind = random.choice(["GET /", "GET /files", "POST /search", "GET /dashboard"])
    m, path = kind.split(" ")
    body = "q=" + random.choice(["quest+board", "vault+inventory", "rota", "backup+schedule"]) if m == "POST" else ""
    at(t, lambda m=m, path=path, body=body: intranet(m, path, body))
    t += random.uniform(40, 260)
# one real person logging in over plaintext HTTP (a true finding for the cleartext-credentials rule)
at(1500.0, lambda: intranet("POST", "/login", "username=Navi&password=Hey-Listen%212026", "302 FOUND", "",
                            "Location: /dashboard\r\nSet-Cookie: session=eyJ1c2VyIjoiTmF2aSJ9; HttpOnly; Path=/\r\n"))

# ---- busy page loads: 8 connections in under half a second (NOT a scan) ----------
# A web page with lots of little files: the browser opens several connections at once.
def busy_page():
    dns_query(cap, WKS, DC, "watchtower.gielinor.local", "A", WT, ttl=300)
    base = cap.clk.t
    for i, path in enumerate(["/static/app.css", "/static/app.js", "/static/logo.png", "/static/font.woff2",
                              "/static/icons.svg", "/api/quests", "/api/notices", "/static/banner.jpg"]):
        cap.clk.t = base + 0.05 * i
        f = TCPFlow(cap, WKS, WT, 80); f.handshake()
        f.send(True, http_req("GET", path)); f.send(False, http_resp("200 OK", "x" * random.randint(200, 1500))); f.close()
for when in (700.0, 1850.0, 2500.0):
    at(when, busy_page)

# ---- browsing: bursts of page loads from WKS01 -------------------------------------
t = random.uniform(20, 60)
while t < DURATION - 60:
    for _ in range(random.randint(3, 6)):
        name, ip = random.choice(SITES)
        at(t, lambda name=name, ip=ip: https_visit(WKS, name, ip, random.randint(300, 900), random.randint(1500, 5000), extra_records=random.randint(0, 2)))
        t += random.uniform(1.0, 7.0)
    t += random.uniform(90, 360)

# ---- NTP: SRV01 -> DC01 every 64 s, essentially exact ----------------------------
t = 11.0
while t < DURATION:
    at(t + random.uniform(-0.05, 0.05), lambda: ntp(SRV, DC)); t += 64.0

# ---- vendor telemetry: three hosts, every ~5 minutes -------------------------------
for host, start in ((SRV, 95.0), (DC, 140.0), (WKS, 230.0)):
    t = start
    while t < DURATION:
        at(t, lambda host=host: https_visit(host, TELEM_NAME, TELEM_IP, random.randint(1100, 1300), random.randint(5000, 6500)))
        t += 300.0 + random.uniform(-4, 4)

# ---- mail polling: WKS01 every ~90 s, +/-15% jitter, very variable replies ----------
t = 33.0
while t < DURATION:
    at(t, lambda: https_visit(WKS, MAIL_NAME, MAIL_IP, random.randint(200, 420), random.randint(250, 3500), port=993))
    t += 90.0 * random.uniform(0.85, 1.15)

# ---- THE BEACON: WKS01 -> api.forge-updates.example, ~60 s +/-10%, tiny and steady --
t = 420.0
while t < DURATION - 5:
    at(t, lambda: https_visit(WKS, BEACON_NAME, BEACON_IP, random.randint(276, 284), random.randint(180, 196)))
    t += 60.0 * random.uniform(0.90, 1.10)

for t, fn in sorted(events, key=lambda e: e[0]):
    cap.clk.t = T0 + t
    fn()

os.makedirs(OUT, exist_ok=True)
cap.save(os.path.join(OUT, "07-hunt.pcap"))
print("wrote", os.path.join(OUT, "07-hunt.pcap"), len(cap.pkts), "packets")
