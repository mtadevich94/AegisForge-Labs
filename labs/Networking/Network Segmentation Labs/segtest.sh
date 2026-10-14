#!/usr/bin/env bash
# =============================================================================
# The Wrkstation Chronicles: The Gatehouse  --  segmentation test matrix (Linux)
# Lab version: 1.0.0
#
# Tries a list of TCP connections from THIS machine and compares what happened
# with what your firewall policy is SUPPOSED to allow. It only makes ordinary
# connection attempts (no exploits, no scanning of anything outside the lab list).
#
# Every target in the list has a service listening on purpose, so:
#   OPEN     = the connection completed          -> the firewall let it through
#   DROPPED  = silence until the timeout         -> the firewall silently discarded it  (rule action: Block)
#   REFUSED  = an instant "connection refused"   -> the firewall answered with a reset  (rule action: Reject)
#   NODNS    = the name could not be resolved
# "Denied" in the expectation column means DROPPED or REFUSED -- either way the
# connection did not happen.
#
# USAGE:
#   bash segtest.sh --profile flat                 # Module 1: the open field (everything should be OPEN)
#   bash segtest.sh --profile policy               # Modules 3-5: zone policy in force
#   bash segtest.sh --profile mgmt                 # after Module 6: management plane locked down
#   bash segtest.sh --profile hardened             # after Module 7: egress + DNS control too
#
# Options:
#   --profile  flat|policy|mgmt|hardened   which expectations to compare against (default: policy)
#   --role     web|adm|lan                 which machine this is (auto-detected from its IP)
#   --wks-ip   <ip>                        the Windows workstation's Garrison address (default 10.20.10.100)
#   --out-ip   <ip>                        the "outside" host, WATCHTOWER (default 10.10.10.30)
#   --timeout  <seconds>                   how long to wait before calling a connection DROPPED (default 3)
#   -h | --help
#
# Exit status: 0 = every row matched, 1 = at least one row did not.
# =============================================================================
set -u

PROFILE="policy"
ROLE=""
WKS_IP="10.20.10.100"
OUT_IP="10.10.10.30"
TIMEOUT=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --role)    ROLE="${2:-}"; shift 2 ;;
    --wks-ip)  WKS_IP="${2:-}"; shift 2 ;;
    --out-ip)  OUT_IP="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$PROFILE" in
  flat)     COL=5 ;;
  policy)   COL=6 ;;
  mgmt)     COL=7 ;;
  hardened) COL=8 ;;
  *) echo "--profile must be flat, policy, mgmt or hardened" >&2; exit 2 ;;
esac

# ---- work out which machine we are -------------------------------------------
if [[ -z "$ROLE" ]]; then
  MYIPS="$(hostname -I 2>/dev/null || true)"
  case " $MYIPS " in
    *" 10.20.20.10 "*) ROLE="web" ;;
    *" 10.20.30.10 "*) ROLE="adm" ;;
    *" 10.20.10."*)    ROLE="lan" ;;
    *) echo "Could not tell which zone this machine is in. Pass --role web|adm|lan." >&2; exit 2 ;;
  esac
fi
case "$ROLE" in web|adm|lan) : ;; *) echo "--role must be web, adm or lan" >&2; exit 2 ;; esac

# ---- the matrix ---------------------------------------------------------------
# role | what we are testing | target | port | flat | policy | mgmt | hardened
#   O = expect OPEN        D = expect DENIED (dropped or refused)
FW_G=10.20.10.1; FW_M=10.20.20.1; FW_C=10.20.30.1
WEB=10.20.20.10; ADM=10.20.30.10

MATRIX=$(cat <<EOF
web|Firewall DNS (its own Market address)|$FW_M|53|O|O|O|O
web|Firewall web GUI from the DMZ|$FW_M|443|O|D|D|D
web|ADM01 SSH (Citadel)|$ADM|22|O|D|D|D
web|ADM01 ops dashboard (Citadel)|$ADM|8080|O|D|D|D
web|Garrison workstation canary :8080|$WKS_IP|8080|O|D|D|D
web|WATCHTOWER web (outside host)|$OUT_IP|80|O|O|O|D
web|WATCHTOWER FTP (outside host)|$OUT_IP|21|O|D|D|D
web|WATCHTOWER :4444 (start a listener first)|$OUT_IP|4444|O|D|D|D
web|Public internet HTTPS (1.1.1.1)|1.1.1.1|443|O|O|O|D
web|Ubuntu package mirror :80|archive.ubuntu.com|80|O|O|O|O
web|Public DNS-over-TLS (1.1.1.1)|1.1.1.1|853|O|D|D|D
adm|Firewall web GUI from Citadel|$FW_C|443|O|O|O|O
adm|Firewall DNS|$FW_C|53|O|O|O|O
adm|WEB01 SSH (Market)|$WEB|22|O|O|O|O
adm|WEB01 admin panel :8080|$WEB|8080|O|O|O|O
adm|WEB01 public site :80|$WEB|80|O|D|D|D
adm|Garrison workstation canary :8080|$WKS_IP|8080|O|D|D|D
adm|WATCHTOWER web (outside host)|$OUT_IP|80|O|O|O|O
adm|WATCHTOWER FTP (outside host)|$OUT_IP|21|O|D|D|D
adm|Public internet HTTPS (1.1.1.1)|1.1.1.1|443|O|O|O|O
lan|Firewall DNS|$FW_G|53|O|O|O|O
lan|Firewall web GUI from the Garrison|$FW_G|443|O|O|D|D
lan|WEB01 public site :80|$WEB|80|O|O|O|O
lan|WEB01 public site :443|$WEB|443|O|O|O|O
lan|WEB01 SSH|$WEB|22|O|D|D|D
lan|WEB01 admin panel :8080|$WEB|8080|O|D|D|D
lan|ADM01 SSH (Citadel) - admin jump host|$ADM|22|O|D|O|O
lan|ADM01 ledger :80 (Citadel)|$ADM|80|O|D|D|D
lan|ADM01 ops dashboard :8080 (Citadel)|$ADM|8080|O|D|D|D
lan|WATCHTOWER web (outside host)|$OUT_IP|80|O|O|O|O
lan|WATCHTOWER FTP (outside host)|$OUT_IP|21|O|D|D|D
lan|WATCHTOWER SSH (outside host)|$OUT_IP|22|O|D|D|D
lan|Public internet HTTPS (1.1.1.1)|1.1.1.1|443|O|O|O|O
lan|Public DNS-over-TLS (1.1.1.1)|1.1.1.1|853|O|D|D|D
EOF
)

# ---- probe one TCP port ---------------------------------------------------------
is_ip() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

probe() {  # echoes OPEN / DROPPED / REFUSED / NODNS
  local host="$1" port="$2" rc
  if ! is_ip "$host" && ! getent hosts "$host" >/dev/null 2>&1; then
    echo "NODNS"; return
  fi
  timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/${host}/${port}" >/dev/null 2>&1
  rc=$?
  if   [[ $rc -eq 0   ]]; then echo "OPEN"
  elif [[ $rc -eq 124 ]]; then echo "DROPPED"
  else                         echo "REFUSED"
  fi
}

# ---- colours (only if stdout is a terminal) --------------------------------------
if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'; else G=""; R=""; Y=""; B=""; Z=""; fi

echo "${B}Segmentation test${Z}  role=${ROLE}  profile=${PROFILE}  timeout=${TIMEOUT}s  ($(date '+%F %T'))"
printf '%-46s %-20s %-6s %-9s %-9s %s\n' "TEST" "TARGET" "PORT" "EXPECT" "RESULT" "VERDICT"
printf '%s\n' "------------------------------------------------------------------------------------------------------"

pass=0; fail=0
while IFS='|' read -r r label host port c5 c6 c7 c8; do
  [[ "$r" == "$ROLE" ]] || continue
  case "$COL" in 5) exp="$c5" ;; 6) exp="$c6" ;; 7) exp="$c7" ;; 8) exp="$c8" ;; esac
  res="$(probe "$host" "$port")"
  if [[ "$exp" == "O" ]]; then want="OPEN"; else want="Denied"; fi
  verdict_ok=0
  if [[ "$exp" == "O" && "$res" == "OPEN" ]]; then verdict_ok=1; fi
  if [[ "$exp" == "D" && ( "$res" == "DROPPED" || "$res" == "REFUSED" ) ]]; then verdict_ok=1; fi
  if [[ $verdict_ok -eq 1 ]]; then v="${G}PASS${Z}"; pass=$((pass+1)); else v="${R}FAIL${Z}"; fail=$((fail+1)); fi
  printf '%-46s %-20s %-6s %-9s %-9s %b\n' "$label" "$host" "$port" "$want" "$res" "$v"
done <<< "$MATRIX"

echo
echo "${B}Result:${Z} ${pass} passed, ${fail} failed."
if [[ $fail -gt 0 ]]; then
  echo "${Y}Read the FAIL rows: 'expected Denied but OPEN' means a rule is too loose;${Z}"
  echo "${Y}'expected OPEN but DROPPED/REFUSED' means a rule is missing or in the wrong order.${Z}"
  echo "${Y}Tip: a ':4444' row only passes 'flat' if you started a listener on WATCHTOWER first.${Z}"
  exit 1
fi
exit 0
