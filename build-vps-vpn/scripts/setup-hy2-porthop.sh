#!/usr/bin/env bash
# Set up Hysteria2 port hopping: DNAT a UDP port range to the single
# Hysteria2 listen port on both v4 and v6, persist with iptables-persistent.
# Re-runnable; will not duplicate rules.
set -euo pipefail

HY2_PORT=36712
RANGE_START=20000
RANGE_END=50000
EGRESS=""

usage() {
  cat <<HLP
Usage: sudo $0 [--hy2-port 36712] [--range 20000-50000] [--egress-iface eth0]
HLP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hy2-port) HY2_PORT="$2"; shift 2 ;;
    --range)
      RANGE_START="${2%-*}"
      RANGE_END="${2#*-}"
      shift 2 ;;
    --egress-iface) EGRESS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

if [[ -z "$EGRESS" ]]; then
  EGRESS=$(ip route show default | awk '/^default/{print $5;exit}')
fi
if [[ -z "$EGRESS" ]]; then
  echo "ERROR: cannot detect default egress interface; pass --egress-iface" >&2
  exit 1
fi

if [[ "$RANGE_START" -ge "$RANGE_END" ]]; then
  echo "ERROR: --range must be START-END with START < END" >&2
  exit 1
fi
if [[ "$HY2_PORT" -ge "$RANGE_START" && "$HY2_PORT" -le "$RANGE_END" ]]; then
  : # listen port inside hop range is fine; DNAT applies regardless
fi

echo "[1/3] ensure iptables-persistent"
if ! dpkg -l | grep -q '^ii\s\+netfilter-persistent'; then
  echo iptables-persistent iptables-persistent/autosave_v4 boolean false | debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean false | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iptables-persistent netfilter-persistent
fi

echo "[2/3] add NAT DNAT rules (idempotent)"
for fam in iptables ip6tables; do
  if "$fam" -t nat -C PREROUTING -i "$EGRESS" -p udp \
        --dport "${RANGE_START}:${RANGE_END}" \
        -j DNAT --to-destination ":${HY2_PORT}" 2>/dev/null; then
    echo "  $fam: rule already present"
  else
    "$fam" -t nat -A PREROUTING -i "$EGRESS" -p udp \
        --dport "${RANGE_START}:${RANGE_END}" \
        -j DNAT --to-destination ":${HY2_PORT}"
    echo "  $fam: rule added"
  fi
done

echo "[3/3] persist via netfilter-persistent"
netfilter-persistent save
systemctl enable netfilter-persistent >/dev/null

echo
iptables  -t nat -L PREROUTING -n -v | head -10
echo
ip6tables -t nat -L PREROUTING -n -v | head -10

cat <<NEXT

Done.

Cloud firewall: allow inbound UDP ${RANGE_START}-${RANGE_END} on the security group attached to this VM.
Hysteria2 listen port (no longer needs to be opened by itself if the range covers it): ${HY2_PORT}

NEXT
