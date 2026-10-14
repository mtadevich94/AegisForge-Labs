#!/usr/bin/env bash
# =============================================================================
# The Wrkstation Chronicles: The Gatehouse  --  Linux host setup (WEB01 / ADM01)
# Lab version: 1.0.0
#
# Turns a fresh Ubuntu Server 22.04 / 24.04 VM into one of the two Linux hosts
# used by the Network Segmentation lab:
#
#   --role web   "Market" web server  (DMZ / Marketplace zone)   10.20.20.10
#                  nginx :80  public site
#                  nginx :443 public site (self-signed certificate)
#                  nginx :8080 "admin panel"  <- must NEVER be reachable from the internet
#                  OpenSSH :22
#
#   --role adm   "Citadel" admin host (MGMT / Citadel zone)      10.20.30.10
#                  nginx :80   internal ledger
#                  nginx :8080 "ops dashboard"
#                  rsyslog UDP :514  (central log receiver - used in Module 8)
#                  OpenSSH :22
#
# Every service answers on purpose, so the test scripts can tell the difference
# between "the firewall blocked me" (timeout) and "nothing was listening".
#
# !! ISOLATED LAB VM ONLY !!  Keep these VMs on the VirtualBox *internal networks*
#    named in the Environment Setup guide. Do not bridge them onto a real network.
#
# USAGE (inside the Ubuntu VM, as root):
#   sudo bash setup-segmentation-host.sh --role web
#   sudo bash setup-segmentation-host.sh --role adm
#   sudo bash setup-segmentation-host.sh --role web --no-static-ip   # keep the IP you already have
#
# Safe to re-run (idempotent).
# Prerequisite: the OPNsense firewall (FW01) must already be running with the
# temporary "flat realm" rules from the Environment Setup guide, because this
# script downloads packages through it.
# =============================================================================
set -euo pipefail

ROLE=""
STATIC_IP=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      [[ $# -ge 2 ]] || { echo "--role needs a value: web or adm" >&2; exit 2; }
      ROLE="$2"; shift 2 ;;
    --no-static-ip) STATIC_IP=0; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$ROLE" in
  web) HOST_NAME="web01"; HOST_IP="10.20.20.10"; GW="10.20.20.1"; ZONE="Market (DMZ)" ;;
  adm) HOST_NAME="adm01"; HOST_IP="10.20.30.10"; GW="10.20.30.1"; ZONE="Citadel (MGMT)" ;;
  *)   echo "Please choose a role:  --role web   or   --role adm" >&2; exit 2 ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root:  sudo bash $0 --role ${ROLE}" >&2
  exit 1
fi

if ! grep -qiE 'ubuntu|debian' /etc/os-release; then
  echo "This script targets Ubuntu/Debian. Detected: $(. /etc/os-release; echo "$PRETTY_NAME")" >&2
  exit 1
fi

say() { printf '\n\033[1;36m[gatehouse:%s]\033[0m %s\n' "$ROLE" "$*"; }

# ---------------------------------------------------------------- hostname
say "Setting hostname to ${HOST_NAME}..."
hostnamectl set-hostname "$HOST_NAME" || true
if ! grep -q "$HOST_NAME" /etc/hosts; then
  echo "127.0.1.1 ${HOST_NAME}" >> /etc/hosts
fi

# ---------------------------------------------------------------- static IP (netplan)
if [[ $STATIC_IP -eq 1 ]]; then
  say "Configuring static IP ${HOST_IP}/24 via gateway ${GW} (netplan)..."
  IFACE="$(ip -o link show | awk -F': ' '$2!="lo"{print $2; exit}')"
  if [[ -z "${IFACE}" ]]; then
    echo "Could not find a network interface." >&2; exit 1
  fi
  NP=/etc/netplan/60-gatehouse-lab.yaml
  cat > "$NP" <<NETPLAN
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: false
      dhcp6: false
      addresses: [${HOST_IP}/24]
      routes:
        - to: default
          via: ${GW}
      nameservers:
        addresses: [${GW}]
NETPLAN
  chmod 600 "$NP"
  # Any other netplan file that also configures this NIC would conflict. Move it aside (kept as .bak).
  for f in /etc/netplan/*.yaml; do
    [[ "$f" == "$NP" ]] && continue
    mv -n "$f" "$f.bak"
  done
  netplan apply
  sleep 3
  say "Static IP applied on ${IFACE}."
fi

# ---------------------------------------------------------------- connectivity pre-check
say "Checking that the firewall (${GW}) answers..."
if ! ping -c 2 -W 2 "$GW" >/dev/null 2>&1; then
  echo "  !! Cannot ping ${GW}. Is FW01 running, and is this VM's adapter on the right internal network?" >&2
  echo "     See 'Segmentation Lab Troubleshooting.md' -> 'Nothing can reach the firewall'." >&2
  exit 1
fi
echo "  ok: ${GW} is reachable"

say "Checking internet access through the firewall (needed for apt)..."
if ! curl -s -o /dev/null --max-time 8 https://archive.ubuntu.com/ ; then
  echo "  !! No internet through the firewall. The temporary 'flat realm' rules from the Setup guide" >&2
  echo "     (Step 7) must be in place on this VM's interface, and DNS must resolve." >&2
  echo "     Try:  nslookup archive.ubuntu.com ${GW}" >&2
  exit 1
fi
echo "  ok: internet reachable"

# ---------------------------------------------------------------- packages
say "Installing packages (apt)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
PKGS=(nginx openssh-server curl nmap tcpdump dnsutils netcat-openbsd openssl rsyslog)
apt-get install -y -qq "${PKGS[@]}" >/dev/null

# ---------------------------------------------------------------- web content + nginx
say "Building web content and nginx sites..."
rm -f /etc/nginx/sites-enabled/default

if [[ "$ROLE" == "web" ]]; then
  install -d /var/www/market /var/www/market-admin /etc/gatehouse
  cat > /var/www/market/index.html <<'HTML'
<!doctype html><html><head><title>The Marketplace</title></head>
<body style="font-family:sans-serif;max-width:40em;margin:3em auto">
<h1>The Marketplace</h1>
<p>Welcome, traveller. This is the <b>public</b> storefront of the Realm. Anyone may browse.</p>
<p><i>Served by web01 in the Market (DMZ) zone.</i></p>
</body></html>
HTML
  cat > /var/www/market-admin/index.html <<'HTML'
<!doctype html><html><head><title>Marketplace Admin</title></head>
<body style="font-family:sans-serif;max-width:40em;margin:3em auto">
<h1>Marketplace Admin Panel</h1>
<p>Merchant ledgers, price edits, and stall assignments.</p>
<p><b>This panel must only be reachable from the Citadel (management) zone.</b></p>
<p>FORGE{admin_panel_was_reachable_from_the_wrong_zone}</p>
</body></html>
HTML

  if [[ ! -f /etc/gatehouse/web01.key ]]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
      -keyout /etc/gatehouse/web01.key -out /etc/gatehouse/web01.crt \
      -subj "/CN=market.gielinor.local/O=The Realm/OU=Marketplace" >/dev/null 2>&1
    chmod 600 /etc/gatehouse/web01.key
  fi

  cat > /etc/nginx/conf.d/realm.conf <<'NGINX'
# Public storefront - plain HTTP
server {
    listen 80 default_server;
    server_name _;
    root /var/www/market;
    index index.html;
}
# Public storefront - HTTPS (self-signed, lab only)
server {
    listen 443 ssl default_server;
    server_name _;
    ssl_certificate     /etc/gatehouse/web01.crt;
    ssl_certificate_key /etc/gatehouse/web01.key;
    root /var/www/market;
    index index.html;
}
# "Admin panel" - the thing the firewall must keep away from the world
server {
    listen 8080 default_server;
    server_name _;
    root /var/www/market-admin;
    index index.html;
}
NGINX
else
  install -d /var/www/citadel /var/www/citadel-ops
  cat > /var/www/citadel/index.html <<'HTML'
<!doctype html><html><head><title>Citadel Ledger</title></head>
<body style="font-family:sans-serif;max-width:40em;margin:3em auto">
<h1>The Citadel Ledger</h1>
<p>Internal records for the Realm's administrators.</p>
<p>FORGE{the_citadel_was_reachable_from_the_wrong_zone}</p>
</body></html>
HTML
  cat > /var/www/citadel-ops/index.html <<'HTML'
<!doctype html><html><head><title>Ops Dashboard</title></head>
<body style="font-family:sans-serif;max-width:40em;margin:3em auto">
<h1>Ops Dashboard</h1>
<p>Firewall health, patch status, and the guard rota. Management zone only.</p>
</body></html>
HTML
  cat > /etc/nginx/conf.d/realm.conf <<'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/citadel;
    index index.html;
}
server {
    listen 8080 default_server;
    server_name _;
    root /var/www/citadel-ops;
    index index.html;
}
NGINX
fi

nginx -t >/dev/null
systemctl enable --now nginx >/dev/null 2>&1
systemctl restart nginx

# ---------------------------------------------------------------- SSH
systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1 || true

# ---------------------------------------------------------------- central log receiver (ADM01 only)
if [[ "$ROLE" == "adm" ]]; then
  say "Configuring rsyslog to receive logs on UDP 514 (one file per sender IP)..."
  install -d -o syslog -g adm -m 0750 /var/log/remote
  cat > /etc/rsyslog.d/10-gatehouse-remote.conf <<'RSYSLOG'
# Receive syslog from the lab's firewall and servers over UDP 514.
module(load="imudp")
input(type="imudp" port="514")

# One file per sending IP, e.g. /var/log/remote/10.20.30.1.log
template(name="GatehousePerSender" type="string" string="/var/log/remote/%fromhost-ip%.log")

# Anything that did not come from this machine is written to its own file and
# then dropped, so it does not also fill this server's own /var/log/syslog.
if ($fromhost-ip != '127.0.0.1') then {
    action(type="omfile" dynaFile="GatehousePerSender" fileOwner="syslog" fileGroup="adm" fileCreateMode="0640")
    stop
}
RSYSLOG
  systemctl enable rsyslog >/dev/null 2>&1
  systemctl restart rsyslog
fi

# ---------------------------------------------------------------- host firewall (only if ufw is already active)
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  say "ufw is active -- opening lab ports..."
  ufw allow 22/tcp >/dev/null; ufw allow 80/tcp >/dev/null; ufw allow 8080/tcp >/dev/null
  [[ "$ROLE" == "web" ]] && ufw allow 443/tcp >/dev/null
  [[ "$ROLE" == "adm" ]] && ufw allow 514/udp >/dev/null
fi

# ---------------------------------------------------------------- self-test
say "Self-test..."
sleep 2
ok=1
check_port() {
  local port="$1" label="$2"
  if (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null; then
    printf '  %-26s :%s  listening\n' "$label" "$port"
  else
    printf '  %-26s :%s  NOT answering\n' "$label" "$port"; ok=0
  fi
}
check_port 22 "SSH"
check_port 80 "HTTP"
check_port 8080 "HTTP (admin/ops)"
if [[ "$ROLE" == "web" ]]; then
  check_port 443 "HTTPS"
else
  if ss -lun 2>/dev/null | grep -q ':514 '; then
    echo "  syslog receiver            :514 listening (UDP)"
  else
    echo "  syslog receiver            :514 NOT listening"; ok=0
  fi
fi

echo
if [[ $ok -eq 1 ]]; then
  echo "${HOST_NAME} is ready in the ${ZONE} zone."
else
  echo "Something did not start. Check:  systemctl status nginx ssh rsyslog"
fi
echo "  Hostname:    ${HOST_NAME}"
echo "  IP address:  $(hostname -I | awk '{print $1}')   (lab expects ${HOST_IP})"
echo "  Gateway:     ${GW}   (the firewall)"
echo "  Next step:   return to the Environment Setup guide."
