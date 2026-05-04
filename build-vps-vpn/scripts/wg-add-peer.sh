#!/usr/bin/env bash
set -euo pipefail

NAME=""
ENDPOINT="${SERVER_ENDPOINT:-}"
ALLOWED_IPS="0.0.0.0/0"
DNS_SERVERS="1.1.1.1, 8.8.8.8"

usage() {
  printf 'Usage: sudo %s <peer-name> [--endpoint host-or-ip] [--allowed-ips "0.0.0.0/0"] [--dns "1.1.1.1, 8.8.8.8"]\n' "$0"
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
NAME="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --allowed-ips) ALLOWED_IPS="$2"; shift 2 ;;
    --dns) DNS_SERVERS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi
if [[ ! "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERROR: peer name must match [a-zA-Z0-9_-]+" >&2
  exit 1
fi

WG_CONF=/etc/wireguard/wg0.conf
CLIENTS_DIR=/etc/wireguard/clients
OUT_DIR=/root/wg-clients

if [[ ! -f "$WG_CONF" ]]; then
  echo "ERROR: $WG_CONF not found; install WireGuard first" >&2
  exit 1
fi
if [[ -f "$CLIENTS_DIR/${NAME}_private.key" ]]; then
  echo "ERROR: peer '$NAME' already exists" >&2
  exit 1
fi

install -d -m 700 "$CLIENTS_DIR" "$OUT_DIR"

SERVER_PUBLIC_KEY="$(cat /etc/wireguard/server_public.key)"
SERVER_PORT="$(awk -F'= *' '/^# PublicPort =/ {print $2; found=1} /^ListenPort/ && !found {print $2}' "$WG_CONF" | tail -n 1)"
if [[ -z "$SERVER_PORT" ]]; then
  SERVER_PORT="$(awk '/^ListenPort/ {print $3; exit}' "$WG_CONF")"
fi
if [[ -z "$ENDPOINT" ]]; then
  ENDPOINT="$(curl -fsS -m 5 https://api.ipify.org || true)"
fi
if [[ -z "$ENDPOINT" ]]; then
  echo "ERROR: could not detect endpoint; pass --endpoint <ip-or-domain>" >&2
  exit 1
fi

used_ips="$(grep -oE 'AllowedIPs = 10\.8\.0\.[0-9]+/32' "$WG_CONF" | sed -E 's/.*10\.8\.0\.([0-9]+).*/\1/' || true)"
next_ip=2
while echo "$used_ips" | grep -qw "$next_ip"; do
  next_ip=$((next_ip + 1))
done
if (( next_ip > 254 )); then
  echo "ERROR: no free IPs in 10.8.0.0/24" >&2
  exit 1
fi
CLIENT_VPN_IP="10.8.0.${next_ip}"

umask 077
wg genkey | tee "$CLIENTS_DIR/${NAME}_private.key" | wg pubkey > "$CLIENTS_DIR/${NAME}_public.key"
CLIENT_PRIVATE_KEY="$(cat "$CLIENTS_DIR/${NAME}_private.key")"
CLIENT_PUBLIC_KEY="$(cat "$CLIENTS_DIR/${NAME}_public.key")"

{
  echo ""
  echo "# === Peer: ${NAME} (${CLIENT_VPN_IP}) ==="
  echo "[Peer]"
  echo "PublicKey = ${CLIENT_PUBLIC_KEY}"
  echo "AllowedIPs = ${CLIENT_VPN_IP}/32"
} >> "$WG_CONF"

if systemctl is-active --quiet wg-quick@wg0; then
  wg syncconf wg0 <(wg-quick strip wg0)
fi

{
  echo "[Interface]"
  echo "PrivateKey = ${CLIENT_PRIVATE_KEY}"
  echo "Address = ${CLIENT_VPN_IP}/32"
  echo "DNS = ${DNS_SERVERS}"
  echo ""
  echo "[Peer]"
  echo "PublicKey = ${SERVER_PUBLIC_KEY}"
  echo "Endpoint = ${ENDPOINT}:${SERVER_PORT}"
  echo "AllowedIPs = ${ALLOWED_IPS}"
  echo "PersistentKeepalive = 25"
} > "$OUT_DIR/${NAME}.conf"
chmod 600 "$OUT_DIR/${NAME}.conf"

echo "Peer added: ${NAME}"
echo "VPN IP: ${CLIENT_VPN_IP}"
echo "Client config: ${OUT_DIR}/${NAME}.conf"
echo "Endpoint: ${ENDPOINT}:${SERVER_PORT}"
