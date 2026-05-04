#!/usr/bin/env bash
# Install sing-box from the official Sagernet APT repository.
# Idempotent: safe to re-run; exits 0 if already installed.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

if command -v sing-box >/dev/null 2>&1; then
  echo "sing-box already installed: $(sing-box version | head -1)"
  exit 0
fi

apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg

install -d -m 755 /usr/share/keyrings
curl -fsSL https://sing-box.app/gpg.key \
  | gpg --dearmor -o /usr/share/keyrings/sagernet.gpg

echo "deb [signed-by=/usr/share/keyrings/sagernet.gpg] https://deb.sagernet.org/ * *" \
  > /etc/apt/sources.list.d/sagernet.list

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y sing-box

sing-box version
