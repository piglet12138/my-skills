# Azure VPS Checklist

Use this when deploying the VPN to Azure.

## Minimum VM

- Ubuntu 22.04 LTS or 24.04 LTS.
- Static public IPv4 if users will keep long-lived client configs.
- A network security group attached to the VM NIC or subnet.

## Network Security Group

Allow inbound:

- TCP `22` from the administrator IP.
- UDP `51820` from the users, if using the current-server-compatible public WireGuard port.
- UDP `443` from the users, if clients connect directly to `443`.
- TCP `18443` if enabling VLESS Reality.
- UDP `36712` or the selected Hysteria2 port if enabling Hysteria2.

Outbound can usually remain the Azure default allow rule unless the user has hardened it.

## Linux Firewall

If `ufw` is active, add matching rules:

```bash
sudo ufw allow 51820/udp
sudo ufw allow 443/udp
sudo ufw allow 18443/tcp
sudo ufw allow 36712/udp
sudo ufw status verbose
```

Only open the ports actually in use.

## Public IP Reputation Test

Before completing migration, test from the Azure VM itself:

```bash
curl -4 https://api.ipify.org
curl -sS -D - -o /dev/null https://api.openai.com/v1/models
curl -sS -D - -o /tmp/auth.html https://auth.openai.com/
curl -sS -D - -o /tmp/chatgpt.html https://chatgpt.com/
```

If `auth.openai.com` or `chatgpt.com` returns `cf-mitigated: challenge`, changing from DigitalOcean to this Azure IP did not solve the ChatGPT/OAuth login issue.

## Migration Sequence

1. Deploy WireGuard with `install-wireguard-vps.sh`.
2. Add one test peer only.
3. Connect from a client and confirm the client egress IP is the Azure IP.
4. Test the target sites through the VPN.
5. Add the remaining peers only after the test peer works.
6. Keep the old server online until every client has imported the new config.

## Azure-Specific Notes

- Azure NSG changes can take a short time to apply; wait and re-test before editing WireGuard.
- The VM's private interface name may be `eth0`, `ens160`, or similar. The install script auto-detects the default egress interface; override with `--egress-iface` only when auto-detection is wrong.
- If the VM has both public and private NICs, NAT must use the interface with the default route to the internet.
