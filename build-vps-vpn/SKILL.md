---
name: build-vps-vpn
description: "Build, migrate, or troubleshoot a VPS-based sing-box proxy egress using the same proxy pattern as this server: VLESS Reality on TCP 18443, optional Hysteria2 on UDP 36712, direct outbound, and a local Clash API on 127.0.0.1:9090. Use when Codex needs to deploy sing-box on Azure or another VPS, generate sanitized server configs, validate cloud firewall rules, prepare client connection parameters, or diagnose ChatGPT/OpenAI login access that depends on changing VPS egress IP."
---

# Build VPS Egress

Use this skill to reproduce the sing-box part of the current server without copying secrets. Keep it focused on userspace proxy egress, client connection parameters, cloud firewall rules, and egress-IP validation.

## First Checks

Before changing a server, collect:

```bash
id -u
uname -a
ip -br addr
ip route show default
systemctl list-unit-files --no-pager | rg -i 'sing-box|nginx|certbot'
ss -tulpn
```

On Azure or another cloud, confirm inbound security rules before debugging Linux:

- SSH TCP `22` from the admin IP.
- VLESS Reality TCP `18443`, or the selected Reality port.
- Hysteria2 UDP `36712`, or the selected Hysteria2 port.
- HTTP/HTTPS TCP `80` and `443` only if using ACME certificates or nginx on the same VPS.

Read [references/current-server-profile.md](references/current-server-profile.md) when matching this server's sing-box shape. Read [references/azure-checklist.md](references/azure-checklist.md) for Azure-specific deployment notes. Read [references/troubleshooting.md](references/troubleshooting.md) when the service starts but clients cannot connect or a target site still blocks login.

## Install sing-box

Use the upstream package or the distribution method already approved by the user. On a fresh Ubuntu/Debian VPS, a typical flow is:

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates openssl
```

Then install sing-box from the official project method suitable for the host. After installation, verify:

```bash
sing-box version
systemctl cat sing-box --no-pager
```

Do not overwrite an existing `/etc/sing-box/config.json` without backing it up.

## Generate Config

Use [scripts/generate-sing-box-config.sh](scripts/generate-sing-box-config.sh) to create a new config with fresh UUIDs, Reality keys, and optional Hysteria2 credentials. The generated output is secret-bearing and must stay on the server.

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

Use a temporary output path when testing:

```bash
sudo bash scripts/generate-sing-box-config.sh \
  --server-name www.microsoft.com \
  --handshake-server www.microsoft.com \
  --out /tmp/sing-box-test.json \
  --force
```

Then validate and start:

```bash
sudo sing-box check -c /etc/sing-box/config.json
sudo systemctl enable --now sing-box
sudo systemctl status sing-box --no-pager
```

## Client Parameters

For VLESS Reality, give the client:

- server public IP or domain
- TCP port, default `18443`
- UUID printed by the generator
- flow `xtls-rprx-vision`
- Reality public key printed by the generator
- Reality short ID printed by the generator
- SNI/server name used with `--server-name`

For Hysteria2, give the client:

- server public IP or domain
- UDP port, default `36712`
- password printed by the generator or passed with `--hy2-password`
- TLS server name matching the certificate
- ALPN `h3` if the client exposes it

Never commit client parameters that contain UUIDs, passwords, private keys, or generated Reality material.

## Validation

From the server:

```bash
curl -4 https://api.ipify.org
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/
```

Interpretation:

- `api.openai.com/v1/models` returning `401` means the API path is reachable and only lacks an API token.
- `auth.openai.com` or `chatgpt.com` returning `403` with `cf-mitigated: challenge` means the egress IP is still challenged at Cloudflare login, not that sing-box is broken.
- Google/GitHub success plus OpenAI login challenge usually means IP reputation, not a generic network outage.

From a client using the sing-box profile:

```bash
curl -4 https://api.ipify.org
```

The client public IP should match the VPS public IP when the client routes the request through the proxy.

## Safety Rules

- Never copy `/etc/sing-box/config.json`, `/etc/sing-box/.secrets`, generated UUIDs, Reality private keys, Hysteria2 passwords, or certificate private keys into Git.
- Prefer a new Azure public IP or a different provider when the current VPS egress is challenged by Cloudflare.
- Do not promise that Azure, AWS, or any data-center IP will pass ChatGPT/OAuth login; validate the new IP before moving users.
- Keep this skill focused on sing-box. If the user asks for kernel-level tunnel routing or device profiles, use a different skill or create a separate one.
