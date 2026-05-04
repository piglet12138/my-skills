# Azure VPS Checklist

Use this when deploying the sing-box egress service to Azure.

## Minimum VM

- Ubuntu 22.04 LTS or 24.04 LTS.
- Static public IPv4 if users will keep long-lived client profiles.
- A network security group attached to the VM NIC or subnet.

## Network Security Group

Allow inbound:

- TCP `22` from the administrator IP.
- TCP `18443` for VLESS Reality, or the selected Reality port.
- UDP `36712` for Hysteria2, or the selected Hysteria2 port.
- TCP `80` and `443` only if using ACME certificate issuance or nginx on this VPS.

Outbound can usually remain the Azure default allow rule unless the user has hardened it.

## Linux Firewall

If `ufw` is active, add matching rules:

```bash
sudo ufw allow 18443/tcp
sudo ufw allow 36712/udp
sudo ufw status verbose
```

Only open the ports actually in use.

## Certificate Notes

VLESS Reality does not need a local certificate. Hysteria2 does need certificate and key files unless the user chooses another supported TLS mode.

For an ACME certificate on the same VPS, make sure the domain resolves to the Azure public IP and open TCP `80` temporarily or permanently depending on the ACME method.

## Public IP Reputation Test

Before completing migration, test from the Azure VM itself:

```bash
curl -4 https://api.ipify.org
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/
curl -sS -D - -o /tmp/chatgpt.html https://chatgpt.com/
```

If `auth.openai.com` or `chatgpt.com` returns `cf-mitigated: challenge`, changing from the old VPS to this Azure IP did not solve the ChatGPT/OAuth login issue.

## Migration Sequence

1. Deploy sing-box and generate a fresh config.
2. Open only the selected Azure NSG ports.
3. Test from one client profile.
4. Confirm the client egress IP is the Azure IP.
5. Test the target sites through the proxy.
6. Move the remaining users only after the test profile works.

## Azure-Specific Notes

- Azure NSG changes can take a short time to apply; wait and re-test before editing sing-box.
- If the VM has multiple NICs, confirm outbound traffic uses the intended public IP.
- Keep the old server online until every client has imported the new profile.
