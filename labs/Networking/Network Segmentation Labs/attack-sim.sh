#!/usr/bin/env bash
# =============================================================================
# The Wrkstation Chronicles: The Gatehouse  --  "assume breach" simulator
# Lab version: 1.0.0
#
# Run this on WEB01 AFTER pretending the public web server has been taken over
# by a raider. It does what a real intruder's first ten minutes look like, using
# only plain connection attempts -- no exploits, no payloads, nothing leaves the lab:
#
#   Step 1  Look around     - try common ports on the Garrison workstation, Citadel host, and the firewall
#   Step 2  Reach for admin - try to open the firewall's web GUI and the Citadel's SSH
#   Step 3  Phone home      - try to call back to an "attacker server" (WATCHTOWER) on port 4444
#   Step 4  Sneak data out  - send DNS questions straight to a public resolver, bypassing the firewall's DNS
#   Step 5  (optional)      - a real nmap scan, so your IDS has something to notice
#
# The point is not to "win". The point is to see exactly how far a compromised
# DMZ server gets -- before your rules (Module 1) and after them (Modules 3-8).
#
# USAGE (on WEB01):
#   bash attack-sim.sh                    # steps 1-4
#   sudo bash attack-sim.sh --nmap        # also step 5 (needs root for a SYN scan)
#   bash attack-sim.sh --wks-ip 10.20.10.101 --out-ip 10.10.10.30
#
# BEFORE step 3 will show OPEN, start a listener on WATCHTOWER:
#   python3 -m http.server 4444        (leave it running; Ctrl+C to stop)
#
# !! ISOLATED LAB ONLY. Only ever point this at the lab's own addresses. !!
# =============================================================================
set -u

WKS_IP="10.20.10.100"
OUT_IP="10.10.10.30"
DO_NMAP=0
TIMEOUT=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wks-ip)  WKS_IP="${2:-}"; shift 2 ;;
    --out-ip)  OUT_IP="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --nmap)    DO_NMAP=1; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# Safety: refuse to run anywhere but the lab's DMZ web server.
if ! hostname -I 2>/dev/null | grep -qw '10.20.20.10'; then
  echo "This script is meant to run on WEB01 (10.20.20.10) only. Refusing to run elsewhere." >&2
  exit 1
fi

LOG="/tmp/attack-sim-$(date +%Y%m%d-%H%M%S).txt"
if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; B=$'\033[1m'; Z=$'\033[0m'; else G=""; R=""; B=""; Z=""; fi

opened=()
blocked=()

try_tcp() {  # label host port
  local label="$1" host="$2" port="$3" rc res
  timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/${host}/${port}" >/dev/null 2>&1
  rc=$?
  if   [[ $rc -eq 0   ]]; then res="OPEN";    opened+=("${label} (${host}:${port})")
  elif [[ $rc -eq 124 ]]; then res="DROPPED"; blocked+=("${label} (${host}:${port})")
  else                         res="REFUSED"; blocked+=("${label} (${host}:${port})")
  fi
  if [[ "$res" == "OPEN" ]]; then col="$R"; else col="$G"; fi
  printf '  %-34s %-16s %-6s %b%s%b\n' "$label" "$host" "$port" "$col" "$res" "$Z"
}

{
echo "${B}== Raider on WEB01: $(date '+%F %T') ==${Z}"

echo
echo "${B}Step 1: look around${Z}  (red OPEN = the raider can see it)"
for p in 22 80 445 3389 8080; do try_tcp "Garrison workstation" "$WKS_IP" "$p"; done
for p in 22 80 8080;          do try_tcp "Citadel ADM01"        "10.20.30.10" "$p"; done
for p in 22 80 443;           do try_tcp "Garrison gateway"     "10.20.10.1" "$p"; done

echo
echo "${B}Step 2: reach for the keys${Z}"
try_tcp "Firewall web GUI (Market side)"  "10.20.20.1" 443
try_tcp "Firewall web GUI (Citadel side)" "10.20.30.1" 443
try_tcp "Firewall web GUI (Garrison side)" "10.20.10.1" 443
try_tcp "Citadel SSH"                     "10.20.30.10" 22

echo
echo "${B}Step 3: phone home to the attacker's server${Z}"
try_tcp "C2 callback"                     "$OUT_IP" 4444
try_tcp "Exfil over HTTPS to attacker"    "$OUT_IP" 443
try_tcp "Exfil over FTP to attacker"      "$OUT_IP" 21

echo
echo "${B}Step 4: sneak data out over DNS (straight to a public resolver)${Z}"
if command -v dig >/dev/null 2>&1; then
  ans="$(dig +time=2 +tries=1 +short @8.8.8.8 raider-beacon.example.com TXT 2>&1 || true)"
  if echo "$ans" | grep -qiE 'timed out|no servers|unreachable|refused'; then
    printf '  %-34s %-16s %-6s %b%s%b\n' "DNS query to public resolver" "8.8.8.8" "53" "$G" "BLOCKED" "$Z"
    blocked+=("DNS to public resolver (8.8.8.8:53)")
  else
    printf '  %-34s %-16s %-6s %b%s%b\n' "DNS query to public resolver" "8.8.8.8" "53" "$R" "ANSWERED" "$Z"
    opened+=("DNS to public resolver (8.8.8.8:53)")
  fi
else
  echo "  dig is not installed (sudo apt-get install -y dnsutils) - skipping"
fi

if [[ $DO_NMAP -eq 1 ]]; then
  echo
  echo "${B}Step 5: nmap SYN scan (gives your IDS something to notice)${Z}"
  if ! command -v nmap >/dev/null 2>&1; then
    echo "  nmap not installed (sudo apt-get install -y nmap) - skipping"
  elif [[ $EUID -ne 0 ]]; then
    echo "  A SYN scan needs root. Re-run:  sudo bash attack-sim.sh --nmap"
  else
    nmap -Pn -sS -T4 --max-retries 1 --host-timeout 40s -p 21,22,23,25,53,80,110,135,139,443,445,3306,3389,5900,8080 \
         "$WKS_IP" 10.20.30.10 10.20.10.1 10.20.30.1 2>&1 | sed 's/^/  /'
  fi
fi

echo
echo "${B}== What the raider got ==${Z}"
if [[ ${#opened[@]} -eq 0 ]]; then
  echo "  ${G}Nothing. Every attempt was stopped.${Z}"
else
  echo "  ${R}${#opened[@]} attempt(s) succeeded:${Z}"
  for x in "${opened[@]}"; do echo "    - $x"; done
fi
echo "  ${#blocked[@]} attempt(s) were stopped."
echo
echo "Now go find each one in the firewall log (Firewall > Log Files > Live View) and, from Module 8, in your IDS alerts."
echo "Saved to: $LOG"
} 2>&1 | tee "$LOG"
