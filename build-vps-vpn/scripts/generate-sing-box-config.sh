#!/usr/bin/env bash
set -euo pipefail

SERVER_NAME=""
HANDSHAKE_SERVER=""
VLESS_PORT=18443
HY2_PORT=36712
HY2_CERT=""
HY2_KEY=""
HY2_PASSWORD=""
OUT=/etc/sing-box/config.json
FORCE=0

usage() {
  printf 'Usage: sudo %s --server-name www.example.com --handshake-server www.example.com [--vless-port 18443] [--hy2-port 36712 --hy2-cert fullchain.pem --hy2-key privkey.pem] [--force]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-name) SERVER_NAME="$2"; shift 2 ;;
    --handshake-server) HANDSHAKE_SERVER="$2"; shift 2 ;;
    --vless-port) VLESS_PORT="$2"; shift 2 ;;
    --hy2-port) HY2_PORT="$2"; shift 2 ;;
    --hy2-cert) HY2_CERT="$2"; shift 2 ;;
    --hy2-key) HY2_KEY="$2"; shift 2 ;;
    --hy2-password) HY2_PASSWORD="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi
if ! command -v sing-box >/dev/null 2>&1; then
  echo "ERROR: sing-box is not installed" >&2
  exit 1
fi
if [[ -z "$SERVER_NAME" || -z "$HANDSHAKE_SERVER" ]]; then
  echo "ERROR: --server-name and --handshake-server are required" >&2
  exit 1
fi
if [[ -f "$OUT" && "$FORCE" != 1 ]]; then
  echo "ERROR: $OUT already exists; pass --force to overwrite" >&2
  exit 1
fi

install -d -m 700 "$(dirname "$OUT")" /etc/sing-box
UUID="$(sing-box generate uuid)"
KEYPAIR="$(sing-box generate reality-keypair)"
PRIVATE_KEY="$(printf '%s\n' "$KEYPAIR" | awk -F': ' '/PrivateKey/ {print $2}')"
PUBLIC_KEY="$(printf '%s\n' "$KEYPAIR" | awk -F': ' '/PublicKey/ {print $2}')"
SHORT_ID="$(openssl rand -hex 8)"
if [[ -z "$HY2_PASSWORD" ]]; then
  HY2_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
fi

tmp="$(mktemp)"
{
  echo '{'
  echo '  "log": { "level": "warn", "timestamp": true },'
  echo '  "inbounds": ['
  echo '    {'
  echo '      "type": "vless",'
  echo '      "tag": "vless-reality-in",'
  echo '      "listen": "::",'
  echo "      \"listen_port\": ${VLESS_PORT},"
  echo '      "users": ['
  echo "        { \"uuid\": \"${UUID}\", \"flow\": \"xtls-rprx-vision\" }"
  echo '      ],'
  echo '      "tls": {'
  echo '        "enabled": true,'
  echo "        \"server_name\": \"${SERVER_NAME}\","
  echo '        "reality": {'
  echo '          "enabled": true,'
  echo "          \"handshake\": { \"server\": \"${HANDSHAKE_SERVER}\", \"server_port\": 443 },"
  echo "          \"private_key\": \"${PRIVATE_KEY}\","
  echo "          \"short_id\": [\"${SHORT_ID}\"]"
  echo '        }'
  echo '      }'
  echo '    }'
  if [[ -n "$HY2_CERT" || -n "$HY2_KEY" ]]; then
    if [[ -z "$HY2_CERT" || -z "$HY2_KEY" ]]; then
      echo "ERROR: pass both --hy2-cert and --hy2-key" >&2
      rm -f "$tmp"
      exit 1
    fi
    echo '    ,{'
    echo '      "type": "hysteria2",'
    echo '      "tag": "hysteria2-in",'
    echo '      "listen": "::",'
    echo "      \"listen_port\": ${HY2_PORT},"
    echo "      \"users\": [ { \"name\": \"default\", \"password\": \"${HY2_PASSWORD}\" } ],"
    echo '      "masquerade": "https://www.bing.com",'
    echo '      "tls": {'
    echo '        "enabled": true,'
    echo '        "alpn": ["h3"],'
    echo "        \"certificate_path\": \"${HY2_CERT}\","
    echo "        \"key_path\": \"${HY2_KEY}\""
    echo '      }'
    echo '    }'
  fi
  echo '  ],'
  echo '  "outbounds": [ { "type": "direct", "tag": "direct" } ],'
  echo '  "experimental": {'
  echo '    "clash_api": { "external_controller": "127.0.0.1:9090", "secret": "", "default_mode": "rule" },'
  echo '    "cache_file": { "enabled": true, "path": "cache.db" }'
  echo '  }'
  echo '}'
} > "$tmp"

sing-box check -c "$tmp"
install -m 600 "$tmp" "$OUT"
rm -f "$tmp"

echo "Wrote $OUT"
echo "VLESS Reality port: ${VLESS_PORT}"
echo "Client uuid: ${UUID}"
echo "Reality public key for clients: ${PUBLIC_KEY}"
echo "Reality short_id: ${SHORT_ID}"
if [[ -n "$HY2_CERT" ]]; then
  echo "Hysteria2 port: ${HY2_PORT}"
  echo "Hysteria2 password: ${HY2_PASSWORD}"
fi
