# Current Server Profile

Use this profile when the user says "base it on the current server" or wants to reproduce the same VPN design on a new VPS.

## Observed Design

- Public provider/IP type: DigitalOcean Singapore data-center egress.
- Primary VPN interface: `wg0`.
- WireGuard VPN subnet: `10.8.0.0/24`.
- Server WireGuard address: `10.8.0.1/24`.
- Local WireGuard listen port: UDP `443`.
- Compatibility redirect: inbound UDP `51820` on `eth0` redirects to UDP `443`.
- Client public endpoint port: usually `51820` unless using direct `443`.
- IPv4 forwarding: enabled.
- IPv6 forwarding: disabled.
- NAT: only source `10.8.0.0/24` out `eth0` is masqueraded.
- Docker is present, so keep VPN NAT scoped and avoid broad NAT rewrites.

## WireGuard Rule Shape

Expected firewall rules:

```bash
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 51820 -j REDIRECT --to-ports 443
```

Use `nft list ruleset` or `iptables-save` to confirm because the host may use iptables-nft.

## sing-box Shape

The server also has `sing-box.service` enabled. The sanitized structure is:

- VLESS Reality inbound on TCP `18443`.
- Hysteria2 inbound on UDP `36712`.
- Direct outbound.
- Clash API bound to `127.0.0.1:9090`.

Do not copy `/etc/sing-box/config.json` from this server into a repository; it contains UUIDs, private keys, certificates, and passwords.

## OpenAI Login Diagnostic Context

This current DigitalOcean egress reaches `api.openai.com` but gets Cloudflare managed challenge on `chatgpt.com` and `auth.openai.com`. That means the VPN can be technically healthy while the egress IP is still unsuitable for ChatGPT/OAuth login.

When migrating to Azure, validate the Azure public IP before moving users:

```bash
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/
curl -sS -D - -o /tmp/chatgpt.html https://chatgpt.com/
```

`401` from the API is normal without a token. `403` plus `cf-mitigated: challenge` on auth/chatgpt means the new egress still has the login problem.
