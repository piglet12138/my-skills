# Current Server Profile

Use this profile when the user says "base it on the current server" and wants to reproduce the sing-box service shape on a new VPS.

## Observed sing-box Design

- Public provider/IP type: data-center VPS egress.
- Service: `sing-box.service`.
- VLESS Reality inbound on TCP `18443`.
- Hysteria2 inbound on UDP `36712`.
- Direct outbound.
- Clash API bound to `127.0.0.1:9090`.
- Hysteria2 uses TLS certificate and key paths from the host.

Do not copy `/etc/sing-box/config.json` from this server into a repository; it contains UUIDs, private keys, certificate paths, and passwords.

## Expected Port Shape

```bash
ss -tulpn | rg '18443|36712|9090|sing-box'
```

Expected:

- `sing-box` listens on TCP `18443`.
- `sing-box` listens on UDP `36712`.
- `sing-box` exposes Clash API only on `127.0.0.1:9090`.

## OpenAI Login Diagnostic Context

This current data-center egress reaches `api.openai.com` but may get Cloudflare managed challenge on `chatgpt.com` and `auth.openai.com`. That means the proxy can be technically healthy while the egress IP is still unsuitable for ChatGPT/OAuth login.

When migrating to Azure, validate the Azure public IP before moving users:

```bash
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/
curl -sS -D - -o /tmp/chatgpt.html https://chatgpt.com/
```

`401` from the API is normal without a token. `403` plus `cf-mitigated: challenge` on auth/chatgpt means the new egress still has the login problem.
