---
name: build-vps-vpn
description: "Build, migrate, or troubleshoot a VPS-based personal/team VPN using the same pattern as this server: WireGuard on wg0 with IPv4 forwarding, scoped iptables MASQUERADE for 10.8.0.0/24, optional UDP public-port redirect such as 51820 to 443, and optional sing-box VLESS Reality plus Hysteria2. Use when Codex needs to deploy a VPN on Azure or another VPS, add/remove WireGuard peers, prepare client configs, validate cloud firewall rules, or diagnose ChatGPT/OpenAI login access that depends on changing VPS egress IP."
---

# Build VPS VPN

Use this skill to reproduce a clean VPS VPN like the current server without copying secrets. Prefer WireGuard for the VPN layer; add sing-box only when the user also wants proxy protocols such as VLESS Reality or Hysteria2.

## First Checks

Before changing a server, collect:

```bash
id -u
uname -a
ip -br addr
ip route show default
systemctl list-unit-files --no-pager | rg -i 'wg-quick|wireguard|sing-box'
ss -tulpn
```

On Azure or another cloud, confirm inbound security rules before debugging Linux:

- SSH TCP `22` from the admin IP.
- WireGuard UDP public port, normally `51820`, or UDP `443` if clients connect directly to `443`.
- Optional sing-box VLESS TCP `18443`.
- Optional Hysteria2 UDP public range or port, matching the generated config.

Read [references/current-server-profile.md](references/current-server-profile.md) when matching this server's exact pattern. Read [references/azure-checklist.md](references/azure-checklist.md) for Azure-specific deployment notes. Read [references/troubleshooting.md](references/troubleshooting.md) when traffic connects but does not route or a site still blocks login.

## WireGuard Install

Use [scripts/install-wireguard-vps.sh](scripts/install-wireguard-vps.sh) on a fresh Ubuntu/Debian VPS. It refuses to overwrite `/etc/wireguard/wg0.conf`.

Default profile:

```bash
sudo bash scripts/install-wireguard-vps.sh
```

This creates:

- `wg0` address `10.8.0.1/24`
- WireGuard listen port `443/udp`
- public client port `51820/udp`, redirected to local `443/udp`
- scoped NAT: `10.8.0.0/24` out through the default interface
- persistent IPv4 forwarding

Use direct UDP `443` instead of redirecting from `51820`:

```bash
sudo bash scripts/install-wireguard-vps.sh --listen-port 443 --public-port 443
```

Use a standard WireGuard port:

```bash
sudo bash scripts/install-wireguard-vps.sh --listen-port 51820 --public-port 51820
```

After install:

```bash
sudo systemctl status wg-quick@wg0 --no-pager
sudo wg show
sudo iptables-save | rg '10\.8\.0\.0/24|51820|wg0'
```

## Add Peers

Use one peer per person or device. Never reuse a client config across devices; WireGuard will handshake, but endpoint roaming causes connection races.

```bash
sudo bash scripts/wg-add-peer.sh alice --endpoint SERVER_PUBLIC_IP_OR_DOMAIN
```

The script appends one `[Peer]` block to `/etc/wireguard/wg0.conf`, hot-reloads `wg0` when active, and writes `/root/wg-clients/alice.conf`.

For full tunnel clients:

```bash
sudo bash scripts/wg-add-peer.sh alice --endpoint SERVER_IP --allowed-ips '0.0.0.0/0'
```

For split tunnel, pass the exact target CIDRs:

```bash
sudo bash scripts/wg-add-peer.sh alice --endpoint SERVER_IP --allowed-ips 'CIDR1, CIDR2, SERVER_IP/32'
```

The generated `.conf` contains the peer private key. Do not commit it, paste it into group chats, or store it in the skill repository.

## Optional sing-box

Only add sing-box when the user asks for VLESS Reality, Hysteria2, proxy clients, or non-WireGuard transport. Use [scripts/generate-sing-box-config.sh](scripts/generate-sing-box-config.sh) to create a secret-bearing local config; do not commit the generated output.

VLESS Reality only:

```bash
sudo bash scripts/generate-sing-box-config.sh \
  --server-name www.microsoft.com \
  --handshake-server www.microsoft.com
```

VLESS Reality plus Hysteria2:

```bash
sudo bash scripts/generate-sing-box-config.sh \
  --server-name www.microsoft.com \
  --handshake-server www.microsoft.com \
  --hy2-cert /etc/letsencrypt/live/example.com/fullchain.pem \
  --hy2-key /etc/letsencrypt/live/example.com/privkey.pem
```

Then verify:

```bash
sudo sing-box check -c /etc/sing-box/config.json
sudo systemctl enable --now sing-box
sudo systemctl status sing-box --no-pager
```

## Validation

From the server:

```bash
curl -4 https://api.ipify.org
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/
```

Interpretation:

- `api.openai.com/v1/models` returning `401` means the API path is reachable and only lacks an API token.
- `auth.openai.com` or `chatgpt.com` returning `403` with `cf-mitigated: challenge` means the egress IP is still challenged at Cloudflare login, not that WireGuard is broken.
- Google/GitHub success plus OpenAI login challenge usually means IP reputation, not a generic proxy outage.

From a client connected to WireGuard:

```bash
curl -4 https://api.ipify.org
ping -c 3 10.8.0.1
wg show
```

The client public IP should match the VPS public IP. If it does not, inspect the client's `AllowedIPs` first.

## Safety Rules

- Never copy `/etc/wireguard/*.key`, `/etc/wireguard/clients/*_private.key`, `/root/wg-clients/*.conf`, `/etc/sing-box/.secrets`, or generated sing-box configs into Git.
- Prefer a new Azure public IP or a different provider when the current VPS egress is challenged by Cloudflare.
- Do not promise that Azure, AWS, or any data-center IP will pass ChatGPT/OAuth login; validate the new IP before migrating users.
- Keep NAT scoped to the VPN subnet. Avoid broad host-wide masquerade rules because Docker and other local services may already own NAT chains.
