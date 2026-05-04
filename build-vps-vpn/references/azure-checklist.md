# Azure VPS Checklist

Use this when deploying or extending the sing-box egress on Azure.

## Minimum VM

- Ubuntu 22.04 LTS or 24.04 LTS.
- Static public IPv4 if users will keep long-lived client profiles.
- A network security group attached to the VM NIC or subnet.

## Network Security Group inbound rules

Allow inbound:

- TCP `22` from the administrator IP.
- TCP `18443` for VLESS Reality, or the selected Reality port.
- For Hysteria2:
  - **with port hopping**: a UDP **range** such as `20000-50000` (a single rule covering the whole hop range).
  - **without port hopping**: just the single UDP port chosen for `--hy2-port` (default `36712`).
- TCP `80` and `443` if using ACME certificate issuance or hosting the Clash YAML subscription on this VPS.

Outbound can usually remain the Azure default allow rule unless the user has hardened it.

## NSG form: exact field-by-field values

The Azure portal has two confusable port fields. The classic mistake is to swap them.

### TCP 18443 (VLESS Reality)

| Field | Value |
| --- | --- |
| Source | Any |
| Source port ranges | `*` |
| Destination | Any |
| Service | Custom |
| Destination port ranges | `18443` |
| Protocol | TCP |
| Action | Allow |
| Priority | 320 |
| Name | `allow-vless-reality` |

### UDP 20000-50000 (Hysteria2 with port hopping)

| Field | Value |
| --- | --- |
| Source | Any |
| Source port ranges | `*` |
| Destination | Any |
| Service | Custom |
| Destination port ranges | `20000-50000` |
| Protocol | UDP |
| Action | Allow |
| Priority | 321 |
| Name | `allow-hy2-porthop` |

Mantra: **source port is always `*`; destination port is the service port.** Putting the service port in "Source port ranges" silently blocks every real client because real clients use ephemeral source ports.

## Linux firewall

If `ufw` is active, add matching rules:

```bash
sudo ufw allow 18443/tcp
sudo ufw allow 20000:50000/udp
sudo ufw status verbose
```

When `iptables-persistent` is installed (required by [scripts/setup-hy2-porthop.sh](../scripts/setup-hy2-porthop.sh) for reboot survival), `apt` will remove `ufw` because the two stacks fight over packet ownership. On Azure the NSG already gates inbound traffic, so leaving `ufw` removed is fine unless you specifically want a second layer of host-local filtering.

## Certificate Notes

VLESS Reality does not need a local certificate. Hysteria2 does need a real cert and key unless the user picks another supported TLS mode.

For ACME issuance on the same VPS:

- If nginx is **not yet** serving anything on 80/443, `certbot certonly --standalone -d <domain>` is the simplest path.
- If nginx is **already** serving another site on 80/443, use `--webroot` instead of `--standalone` so the running site stays up. Add a one-off 80-only server block whose only `location` is `/.well-known/acme-challenge/` pointed at a webroot (see SKILL.md).
- After issuance, install [references/letsencrypt-deploy-hook.sh](letsencrypt-deploy-hook.sh) so sing-box restarts and picks up the renewed cert; otherwise it silently fails ~90 days later.

## Public IP reputation test

Before completing migration, test from the Azure VM itself:

```bash
curl -4 https://api.ipify.org
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/
curl -sS -D - -o /tmp/chatgpt.html https://chatgpt.com/
```

If `auth.openai.com` or `chatgpt.com` returns `cf-mitigated: challenge`, changing from the old VPS to this Azure IP did not solve the ChatGPT/OAuth login issue.

## Migration sequence

1. `install-sing-box.sh` then `generate-sing-box-config.sh`.
2. `setup-hy2-porthop.sh` for port hopping.
3. webroot certbot for the VPN domain (do NOT use `--standalone` if nginx already serves another site on 80/443).
4. Drop the renew deploy hook so sing-box restarts after each renewal.
5. `publish-clash-subscription.sh` to materialise the HTTPS YAML URL.
6. Open NSG rules above.
7. Import the URL in Clash Verge as a Remote profile.
8. Confirm the client egress IP is the Azure IP.
9. Test the target sites through the proxy.
10. Move the remaining users only after the test profile works.

## Azure-specific notes

- The Azure DHCP-pushed metadata DNS at `168.63.129.16` is the lowest-latency resolver from inside the VM and is useful for quick DNS sanity checks (`dig +short vpn.example.com @168.63.129.16`) when troubleshooting cert issuance.
- Azure NSG changes are eventually consistent and may take 10-30 seconds to be enforced after saving; do not panic if a fresh client cannot connect immediately after editing rules.
- The `eth0` egress interface name is the Azure default; `setup-hy2-porthop.sh` autodetects it via `ip route show default`. Pass `--egress-iface` only when the VM has been renamed or has multiple NICs.
- Keep the old server online until every client has imported the new profile.
