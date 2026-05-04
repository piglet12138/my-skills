# Troubleshooting

## Service Does Not Start

Validate the config first:

```bash
sudo sing-box check -c /etc/sing-box/config.json
sudo journalctl -u sing-box -n 100 --no-pager
```

Common causes:

- Invalid JSON after manual edits.
- Certificate path or key path does not exist.
- The configured port is already used by nginx or another service.
- The service user cannot read the certificate/key files.

## Client Cannot Connect

Check cloud firewall first:

```bash
ss -tulpn | rg '18443|36712|sing-box'
sudo tcpdump -ni any 'tcp port 18443 or udp port 36712'
```

If tcpdump sees no packet, the problem is outside sing-box: Azure NSG, local client network, wrong server address, or wrong port.

If packets arrive but the client fails:

- Confirm the VLESS UUID, Reality public key, short ID, flow, and SNI match the generated values.
- Confirm the Hysteria2 password and TLS server name match the generated config and certificate.
- Confirm the client is using TCP for VLESS Reality and UDP for Hysteria2.
- Confirm server time is sane with `timedatectl`.

## Client Egress IP Did Not Change

Run from the client through the proxy:

```bash
curl -4 https://api.ipify.org
```

Most common causes:

- The client app is connected but the test command is not routed through it.
- The client is in rule mode and the test URL is direct-routed.
- Another local VPN/proxy is taking precedence.
- The client imported an old profile pointing to the old VPS.

## OpenAI API Works but ChatGPT Login Fails

This is usually IP reputation, not proxy service health.

Signs:

- `api.openai.com/v1/models` returns `401` without a token.
- `auth.openai.com` or `chatgpt.com` returns `403`.
- Response headers include `cf-mitigated: challenge`.

Action:

- Use API key mode if the user's workflow only needs the OpenAI API.
- If OAuth/ChatGPT login is required, test a different egress IP.
- Do not spend time rotating UUIDs, Reality keys, or Hysteria2 passwords when the client egress IP is already the VPS IP and only auth/chatgpt is challenged.

## Port Conflicts

Check listeners:

```bash
ss -tulpn
```

Typical layout:

- nginx owns TCP `80` and `443`.
- sing-box owns TCP `18443`.
- sing-box owns UDP `36712`.
- sing-box Clash API stays on `127.0.0.1:9090`.

Move sing-box ports rather than sharing a port already owned by nginx unless the user intentionally builds a more advanced fronting setup.
