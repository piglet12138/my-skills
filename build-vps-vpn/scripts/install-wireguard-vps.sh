#!/usr/bin/env bash
set -euo pipefail

LISTEN_PORT=443
PUBLIC_PORT=51820
NETWORK_CIDR="10.8.0.0/24"
SERVER_VPN_IP="10.8.0.1"
EGRESS_IFACE=""

usage() {
  printf 'Usage: sudo %s [--listen-port 443] [--public-port 51820] [--network 10.8.0.0/24] [--server-vpn-ip 10.8.0.1] [--egress-iface eth0]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --listen-port) LISTEN_PORT="$2"; shift 2 ;;
    --public-port) PUBLIC_PORT="$2"; shift 2 ;;
    --network) NETWORK_CIDR="$2"; shift 2 ;;
    --server-vpn-ip) SERVER_VPN_IP="$2"; shift 2 ;;
    --egress-iface) EGRESS_IFACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

if [[ -f /etc/wireguard/wg0.conf ]]; then
  echo "ERROR: /etc/wireguard/wg0.conf already exists; refusing to overwrite" >&2
  exit 1
fi

if [[ "$NETWORK_CIDR" != */* ]]; then
  echo "ERROR: --network must be CIDR, for example 10.8.0.0/24" >&2
  exit 1
fi
NETMASK="${NETWORK_CIDR##*/}"

if [[ -z "$EGRESS_IFACE" ]]; then
  EGRESS_IFACE="$(ip route show default | awk '/^default/ {print $5; exit}')"
fi
if [[ -z "$EGRESS_IFACE" ]]; then
  echo "ERROR: could not detect default egress interface" >&2
  exit 1
fi

echo "[1/7] Installing WireGuard packages"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard wireguard-tools iptables curl >/dev/null

echo "[2/7] Backing up current firewall rules"
mkdir -p /root/wg-backup
iptables-save > "/root/wg-backup/iptables-before-wg-$(date +%Y%m%d-%H%M%S).rules"
ip6tables-save > "/root/wg-backup/ip6tables-before-wg-$(date +%Y%m%d-%H%M%S).rules" || true

echo "[3/7] Generating server keypair"
install -d -m 700 /etc/wireguard /etc/wireguard/clients /root/wg-clients
umask 077
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
SERVER_PRIVATE_KEY="$(cat /etc/wireguard/server_private.key)"
SERVER_PUBLIC_KEY="$(cat /etc/wireguard/server_public.key)"

echo "[4/7] Writing /etc/wireguard/wg0.conf"
{
  echo "[Interface]"
  echo "Address = ${SERVER_VPN_IP}/${NETMASK}"
  echo "ListenPort = ${LISTEN_PORT}"
  echo "PrivateKey = ${SERVER_PRIVATE_KEY}"
  echo "# PublicPort = ${PUBLIC_PORT}"
  echo ""
  echo "PostUp = iptables -C FORWARD -i %i -j ACCEPT 2>/dev/null || iptables -A FORWARD -i %i -j ACCEPT"
  echo "PostUp = iptables -C FORWARD -o %i -j ACCEPT 2>/dev/null || iptables -A FORWARD -o %i -j ACCEPT"
  echo "PostUp = iptables -t nat -C POSTROUTING -s ${NETWORK_CIDR} -o ${EGRESS_IFACE} -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s ${NETWORK_CIDR} -o ${EGRESS_IFACE} -j MASQUERADE"
  if [[ "$PUBLIC_PORT" != "$LISTEN_PORT" ]]; then
    echo "PostUp = iptables -t nat -C PREROUTING -i ${EGRESS_IFACE} -p udp --dport ${PUBLIC_PORT} -j REDIRECT --to-ports ${LISTEN_PORT} 2>/dev/null || iptables -t nat -A PREROUTING -i ${EGRESS_IFACE} -p udp --dport ${PUBLIC_PORT} -j REDIRECT --to-ports ${LISTEN_PORT}"
  fi
  echo "PostDown = iptables -D FORWARD -i %i -j ACCEPT 2>/dev/null || true"
  echo "PostDown = iptables -D FORWARD -o %i -j ACCEPT 2>/dev/null || true"
  echo "PostDown = iptables -t nat -D POSTROUTING -s ${NETWORK_CIDR} -o ${EGRESS_IFACE} -j MASQUERADE 2>/dev/null || true"
  if [[ "$PUBLIC_PORT" != "$LISTEN_PORT" ]]; then
    echo "PostDown = iptables -t nat -D PREROUTING -i ${EGRESS_IFACE} -p udp --dport ${PUBLIC_PORT} -j REDIRECT --to-ports ${LISTEN_PORT} 2>/dev/null || true"
  fi
} > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

echo "[5/7] Enabling IPv4 forwarding"
printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-wireguard-vpn.conf
sysctl --system >/dev/null

echo "[6/7] Starting wg-quick@wg0"
systemctl enable wg-quick@wg0 >/dev/null
systemctl start wg-quick@wg0

echo "[7/7] Verifying"
wg show wg0
echo ""
echo "Server public key: ${SERVER_PUBLIC_KEY}"
echo "WireGuard listens locally on UDP ${LISTEN_PORT}"
echo "Clients should connect to public UDP ${PUBLIC_PORT}"
echo "VPN subnet: ${NETWORK_CIDR}"
echo "Egress interface: ${EGRESS_IFACE}"
