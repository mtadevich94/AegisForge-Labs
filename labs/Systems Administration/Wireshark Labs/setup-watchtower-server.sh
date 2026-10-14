#!/usr/bin/env bash
# =============================================================================
# The Wrkstation Chronicles: Packet Watch  --  WATCHTOWER server setup
# Lab version: 1.0.0
#
# Turns a fresh Ubuntu Server 22.04 / 24.04 VM into "Watchtower": a deliberately
# insecure intranet host that the Wireshark lab captures traffic against.
#
#   * Wizard Tower Intranet portal  - HTTP  :80   (plaintext login, on purpose)
#   * Wizard Tower Intranet portal  - HTTPS :443  (self-signed cert, for contrast)
#   * vsftpd FTP server             - :21 + passive 40000-40200 (plaintext, on purpose)
#   * OpenSSH                       - :22  (already there; just something for a scanner to find)
#
# !! ISOLATED LAB VM ONLY !!  This box has weak passwords and cleartext protocols
#    by design. Keep the VM on the host-only / NAT Network adapter. Never bridge
#    it onto your home or work network and never expose it to the internet.
#
# USAGE (inside the Ubuntu VM):
#   sudo bash setup-watchtower-server.sh                 # install everything
#   sudo bash setup-watchtower-server.sh --static-ip     # ...and also set 10.10.10.30/24 via netplan
#   sudo bash setup-watchtower-server.sh --reset         # re-run safely; rebuilds app + FTP files
#
# Safe to re-run (idempotent).
# =============================================================================
set -euo pipefail

STATIC_IP=0
for arg in "$@"; do
  case "$arg" in
    --static-ip) STATIC_IP=1 ;;
    --reset)     : ;;   # every run already rebuilds app + files; flag kept for readability
    -h|--help)   sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root:  sudo bash $0" >&2
  exit 1
fi

if ! grep -qiE 'ubuntu|debian' /etc/os-release; then
  echo "This script targets Ubuntu/Debian. Detected: $(. /etc/os-release; echo "$PRETTY_NAME")" >&2
  exit 1
fi

SERVER_IP="10.10.10.30"
APP_DIR="/opt/wizardtower"
CERT_DIR="/etc/wizardtower"
FTP_USER="vaultkeeper"
FTP_PASS='Ph0enix-Ash#42'

say() { printf '\n\033[1;33m[watchtower]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------- packages
say "Installing packages (apt)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq vsftpd python3 python3-flask openssl curl net-tools tcpdump >/dev/null

# ---------------------------------------------------------------- hostname / optional static IP
hostnamectl set-hostname watchtower || true
if ! grep -q 'watchtower' /etc/hosts; then
  echo "127.0.1.1 watchtower" >> /etc/hosts
fi

if [[ $STATIC_IP -eq 1 ]]; then
  say "Configuring static IP ${SERVER_IP}/24 with netplan..."
  IFACE="$(ip -o -4 route show to default | awk '{print $5; exit}')"
  if [[ -z "${IFACE}" ]]; then
    IFACE="$(ip -o link show | awk -F': ' '$2!="lo"{print $2; exit}')"
  fi
  cat > /etc/netplan/60-gielinor-lab.yaml <<NETPLAN
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: false
      addresses: [${SERVER_IP}/24]
      routes:
        - to: default
          via: 10.10.10.1
      nameservers:
        addresses: [10.10.10.10, 10.10.10.1]
NETPLAN
  chmod 600 /etc/netplan/60-gielinor-lab.yaml
  # Other netplan files that also configure this NIC would conflict; move them aside (kept as .bak).
  for f in /etc/netplan/*.yaml; do
    [[ "$f" == "/etc/netplan/60-gielinor-lab.yaml" ]] && continue
    mv -n "$f" "$f.bak"
  done
  netplan apply
  say "Static IP applied on ${IFACE}. If you lose SSH, reconnect to ${SERVER_IP}."
fi

# ---------------------------------------------------------------- FTP user + files
say "Creating FTP account '${FTP_USER}' and vault files..."
if ! id "$FTP_USER" >/dev/null 2>&1; then
  useradd -m -s /usr/sbin/nologin "$FTP_USER"
fi
echo "${FTP_USER}:${FTP_PASS}" | chpasswd
grep -qx '/usr/sbin/nologin' /etc/shells || echo '/usr/sbin/nologin' >> /etc/shells

printf "Vaultkeeper's notes -- DO NOT SHARE\r\nThe portal admin account reuses the FTP password.\r\nBackup rotation: Fridays at 02:00.\r\nFORGE{plaintext_is_a_postcard}\r\n" \
  > "/home/${FTP_USER}/vault-notes.txt"
cat > "/home/${FTP_USER}/payroll-vault.csv" <<'CSV'
id,adventurer,rank,stipend
1,Navi,Fairy,4200
2,Zelda_Warden,Warden,9100
3,General_Graardor,General,8800
4,Princess_Irulan,Royal,12000
5,Bandit,Scout,3100
6,Kerbe,Hound,3700
7,DAME,Overseer,10400
CSV
sed -i 's/$/\r/' "/home/${FTP_USER}/payroll-vault.csv" 2>/dev/null || true
chown "${FTP_USER}:${FTP_USER}" "/home/${FTP_USER}/"*.txt "/home/${FTP_USER}/"*.csv
chmod 644 "/home/${FTP_USER}/"*.txt "/home/${FTP_USER}/"*.csv
chmod 755 "/home/${FTP_USER}"

cat > /etc/vsftpd.conf <<'VSFTPD'
# Packet Watch lab config: plain FTP on purpose (no TLS) so students can read it in Wireshark.
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=NO
local_umask=022
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40200
VSFTPD
systemctl enable vsftpd >/dev/null 2>&1
systemctl restart vsftpd

# ---------------------------------------------------------------- web portal
say "Building the Wizard Tower Intranet portal..."
id wizard >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin wizard
mkdir -p "$APP_DIR" "$CERT_DIR"

cat > "$APP_DIR/app.py" <<'PYAPP'
"""Wizard Tower Intranet -- intentionally simple, intentionally insecure lab portal."""
import os, ssl
from flask import Flask, request, redirect, session, make_response

app = Flask(__name__)
app.secret_key = "gielinor-lab-not-a-secret"   # lab only

USERS = {
    "Navi": "Hey-Listen!2026",
    "Zelda_Warden": "Triforce#2026",   # weak on purpose (capstone brute-force target)
}

PAGE = "<!doctype html><html><head><title>Wizard Tower Intranet</title></head><body>{}</body></html>"
LOGIN = """<h1>Wizard Tower Intranet</h1><p>Authorized adventurers only.</p>
<form method="POST" action="/login"><input name="username"><input name="password" type="password"><button>Enter</button></form>
<!-- TODO: remove legacy HTTP login before the Vaultkeeper finds out -->"""

@app.get("/")
def index():
    return PAGE.format(LOGIN)

@app.get("/login")
def login_form():
    return PAGE.format(LOGIN)

@app.post("/login")
def login():
    u, p = request.form.get("username", ""), request.form.get("password", "")
    if USERS.get(u) == p and p:
        session["user"] = u
        app.logger.info("LOGIN OK   user=%s from=%s", u, request.remote_addr)
        return redirect("/dashboard")
    app.logger.warning("LOGIN FAIL user=%s from=%s", u, request.remote_addr)
    return make_response(PAGE.format("<p>Invalid credentials</p>"), 401)

@app.get("/dashboard")
def dashboard():
    if "user" not in session:
        return redirect("/login")
    return PAGE.format("<h1>Welcome back, {}</h1><ul><li>Quest board</li><li>Vault inventory</li>"
                       '<li><a href="/files">Shared files (FTP)</a></li></ul>'.format(session["user"]))

@app.get("/files")
def files():
    if "user" not in session:
        return redirect("/login")
    return PAGE.format("<h1>Shared files</h1><p>FTP host: watchtower.gielinor.local &mdash; account: vaultkeeper "
                       "(password in vault-notes.txt, ask Navi)</p>")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "80"))
    cert, key = os.environ.get("TLS_CERT"), os.environ.get("TLS_KEY")
    ctx = (cert, key) if cert and key else None
    app.run(host="0.0.0.0", port=port, ssl_context=ctx, threaded=True)
PYAPP
chown -R wizard:wizard "$APP_DIR"

if [[ ! -f "$CERT_DIR/watchtower.crt" ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
    -keyout "$CERT_DIR/watchtower.key" -out "$CERT_DIR/watchtower.crt" \
    -subj "/CN=watchtower.gielinor.local" \
    -addext "subjectAltName=DNS:watchtower.gielinor.local,IP:${SERVER_IP}" >/dev/null 2>&1
fi
chown root:wizard "$CERT_DIR/watchtower.key" "$CERT_DIR/watchtower.crt"
chmod 640 "$CERT_DIR/watchtower.key"
chmod 644 "$CERT_DIR/watchtower.crt"

for svc in http https; do
  if [[ $svc == http ]]; then PORT=80;  TLS_LINES=""; else
    PORT=443
    TLS_LINES="Environment=TLS_CERT=$CERT_DIR/watchtower.crt
Environment=TLS_KEY=$CERT_DIR/watchtower.key"
  fi
  cat > "/etc/systemd/system/wizardtower-${svc}.service" <<UNIT
[Unit]
Description=Wizard Tower Intranet (${svc^^}) - Packet Watch lab
After=network-online.target
Wants=network-online.target

[Service]
User=wizard
Group=wizard
Environment=PORT=${PORT}
${TLS_LINES}
ExecStart=/usr/bin/python3 ${APP_DIR}/app.py
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
done
systemctl daemon-reload
systemctl enable --now wizardtower-http wizardtower-https >/dev/null 2>&1
systemctl restart wizardtower-http wizardtower-https

# ---------------------------------------------------------------- firewall (only if ufw is already active)
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  say "ufw is active -- opening lab ports..."
  ufw allow 21/tcp >/dev/null; ufw allow 22/tcp >/dev/null; ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null; ufw allow 40000:40200/tcp >/dev/null
fi

# ---------------------------------------------------------------- self-test
say "Self-test..."
sleep 2
ok=1
curl -s -o /dev/null -w "  HTTP  / -> %{http_code}\n" http://127.0.0.1/ || ok=0
curl -sk -o /dev/null -w "  HTTPS / -> %{http_code}\n" https://127.0.0.1/ || ok=0
if (exec 3<>/dev/tcp/127.0.0.1/21) 2>/dev/null; then echo "  FTP   :21 open"; else echo "  FTP   :21 NOT answering"; ok=0; fi
if (exec 3<>/dev/tcp/127.0.0.1/22) 2>/dev/null; then echo "  SSH   :22 open"; else echo "  SSH   :22 not listening (install openssh-server if you want it)"; fi

echo
if [[ $ok -eq 1 ]]; then
  echo "Watchtower is ready."
else
  echo "Something did not start. Check:  systemctl status wizardtower-http vsftpd"
fi
echo "  Server IP:   $(hostname -I | awk '{print $1}')   (lab expects ${SERVER_IP})"
echo "  Next step:   add a DNS record on DC01 so WKS01 can resolve watchtower.gielinor.local"
