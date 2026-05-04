---
name: build-vps-vpn
description: "Build, migrate, or troubleshoot a VPS-based sing-box proxy egress using the same proxy pattern as this server: VLESS Reality on TCP 18443, optional Hysteria2 on UDP 36712 (with iptables UDP-range port hopping for anti-QoS), direct outbound, and a local Clash API on 127.0.0.1:9090. Includes an idempotent sing-box installer, Let's Encrypt webroot issuance that coexists with an in-use nginx, an HTTPS Clash YAML subscription host with token-gated path, and a deploy-hook that auto-restarts sing-box after cert renewal. Use when Codex needs to deploy or extend sing-box on Azure or another VPS, generate Clash Verge subscription URLs, set up Hysteria2 port hopping, validate cloud firewall rules, prepare client connection parameters, or diagnose ChatGPT/OpenAI login access dependent on egress IP."
---

# Build VPS Egress

Use this skill to reproduce the sing-box egress on the current server without copying secrets. End state: a single HTTPS Clash YAML subscription URL that Clash Verge / Mihomo imports as one profile carrying both VLESS Reality (TCP fallback) and Hysteria2 (UDP, port-hopped) nodes.

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
- Hysteria2: a UDP **range** like `20000-50000` when port hopping is enabled, or the single UDP port chosen for `--hy2-port` when not.
- TCP `80` and `443` if using ACME certificate issuance or hosting the Clash YAML subscription on this VPS.

Read [references/current-server-profile.md](references/current-server-profile.md) when matching this server's sing-box shape. Read [references/azure-checklist.md](references/azure-checklist.md) for Azure NSG-specific deployment notes including the exact field-by-field NSG form values. Read [references/troubleshooting.md](references/troubleshooting.md) when the service starts but clients cannot connect, port hopping does not survive a reboot, or a target site still blocks login.

## Install sing-box

Use [scripts/install-sing-box.sh](scripts/install-sing-box.sh) on a fresh Ubuntu/Debian VPS. It pulls from the official Sagernet APT repository and is idempotent (no-op if `sing-box` is already on PATH).

```bash
sudo bash scripts/install-sing-box.sh
```

After installation, verify:

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

VLESS Reality plus Hysteria2 (cert obtained in the next section):

```bash
sudo bash scripts/generate-sing-box-config.sh \
  --server-name www.microsoft.com \
  --handshake-server www.microsoft.com \
  --hy2-cert /etc/letsencrypt/live/<your-domain>/fullchain.pem \
  --hy2-key  /etc/letsencrypt/live/<your-domain>/privkey.pem
```

Use a temporary output path when testing:

```bash
sudo bash scripts/generate-sing-box-config.sh \
  --server-name www.microsoft.com \
  --handshake-server www.microsoft.com \
  --out /tmp/sing-box-test.json \
  --force
```

The generator prints the four credentials needed by clients:

- `Client uuid` (VLESS UUID)
- `Reality public key` (Reality public key)
- `Reality short_id`
- `Hysteria2 password`

Save them; the publish script in the last section consumes them.

Then:

```bash
sudo sing-box check -c /etc/sing-box/config.json
sudo systemctl enable --now sing-box
sudo systemctl status sing-box --no-pager
```

## Hysteria2 Port Hopping

ISPs commonly throttle long-lived single-port UDP flows. Hysteria2 supports random per-packet port selection. Server side: DNAT a UDP port range into the single Hysteria2 listen port.

```bash
sudo bash scripts/setup-hy2-porthop.sh --hy2-port 36712 --range 20000-50000
```

This adds an `iptables -t nat PREROUTING ... DNAT --to-destination :36712` for both v4 and v6, persists with `iptables-persistent`, and survives reboots. `apt` will remove `ufw` when installing `iptables-persistent`; on Azure the NSG already gates traffic so this is normally fine.

Cloud firewall: allow inbound UDP for the **whole range** (e.g. `20000-50000`). The single-port `36712` rule is no longer enough.

## Issue Cert without Disturbing nginx

Hysteria2 needs a real TLS cert. If the VPS already runs an nginx site on 80/443 (for example a web app the user has shipped), `certbot --standalone` would stop it. Use webroot instead:

```bash
DOMAIN=vpn.example.com
sudo install -d /var/www/letsencrypt
sudo tee /etc/nginx/sites-available/acme-$DOMAIN >/dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/letsencrypt; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF
sudo ln -sf /etc/nginx/sites-available/acme-$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

sudo certbot certonly \
  --webroot -w /var/www/letsencrypt -d $DOMAIN \
  --non-interactive --agree-tos --register-unsafely-without-email \
  --keep-until-expiring
```

Drop [references/letsencrypt-deploy-hook.sh](references/letsencrypt-deploy-hook.sh) at `/etc/letsencrypt/renewal-hooks/deploy/restart-sing-box.sh` (`chmod +x`) so sing-box reloads its TLS material after each renewal — without it, sing-box keeps holding the old cert in memory until the next manual restart and silently fails ~90 days later.

## Publish Clash YAML Subscription

```bash
sudo bash scripts/publish-clash-subscription.sh \
  --domain vpn.example.com \
  --server-ip <PUBLIC_IP> \
  --vless-uuid <FROM_GENERATE_OUTPUT> \
  --vless-port 18443 \
  --reality-pubkey <FROM_GENERATE_OUTPUT> \
  --reality-shortid <FROM_GENERATE_OUTPUT> \
  --handshake-server www.microsoft.com \
  --hy2-port 36712 \
  --hy2-ports 20000-50000 \
  --hy2-password <FROM_GENERATE_OUTPUT>
```

The script:

- generates a random 32-hex token (or reuses `/etc/sing-box/sub_token` so the subscription URL is stable across reruns),
- writes `/var/www/sub/<token>.yaml` with both nodes plus `PROXY` (select) and `AUTO` (url-test) groups,
- adds an nginx vhost on the VPN domain that serves only `^/[a-f0-9]{32}\.yaml$` and 404s everything else,
- prints the subscription URL: `https://<domain>/<token>.yaml`.

Import that URL in Clash Verge as a Remote profile.

## Validation

From the server:

```bash
curl -4 https://api.ipify.org
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/

# port-hopping NAT counter increases under client traffic
sudo iptables -t nat -L PREROUTING -n -v
# subscription returns 200 and the cert verifies
curl -sS -o /dev/null -w '%{http_code} ssl=%{ssl_verify_result}\n' \
  https://<domain>/<token>.yaml
# the SNI on 443 returns the right cert
echo Q | openssl s_client -connect 127.0.0.1:443 -servername <domain> 2>/dev/null \
  | openssl x509 -noout -subject -ext subjectAltName
```

Interpretation:

- `api.openai.com/v1/models` returning `401` means the API path is reachable and only lacks an API token.
- `auth.openai.com` or `chatgpt.com` returning `403` with `cf-mitigated: challenge` means the egress IP is still challenged at Cloudflare login, not that sing-box is broken.
- Google/GitHub success plus OpenAI login challenge usually means IP reputation, not a generic proxy outage.

## Safety Rules

- Never copy `/etc/sing-box/.secrets`, the generated `/etc/sing-box/config.json`, the published Clash YAML at `/var/www/sub/<token>.yaml`, or the random token at `/etc/sing-box/sub_token` into Git.
- Prefer a new Azure public IP or a different provider when the current VPS egress is challenged by Cloudflare.
- Do not promise that Azure, AWS, or any data-center IP will pass ChatGPT/OAuth login; validate the new IP before migrating users.
- When opening UDP `20000-50000` on the cloud firewall, do not also open all UDP ports as a "shortcut"; the wider rule defeats the value of a tight NAT mapping and exposes anything else listening on UDP.
- Keep the old server online until every client has imported the new subscription; rotating the path token revokes old clients silently.
