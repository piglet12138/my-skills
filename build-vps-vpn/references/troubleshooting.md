# Troubleshooting

## Client Cannot Handshake

Check cloud firewall first:

```bash
sudo tcpdump -ni any udp port 51820 or udp port 443
sudo wg show
```

If tcpdump sees no packet, the problem is outside WireGuard: cloud firewall, local client network, wrong endpoint, or wrong port.

If packets arrive but `wg show` has no latest handshake:

- Confirm the client uses the server public key, not private key.
- Confirm the server has the client's public key.
- Confirm the client endpoint points to the public port, not necessarily the server's local listen port.
- Confirm server time is sane with `timedatectl`.

## Handshake Works but No Internet

Check forwarding and NAT:

```bash
sysctl net.ipv4.ip_forward
iptables-save | rg 'FORWARD|POSTROUTING|10\.8\.0\.0/24|wg0'
ip route show default
```

Expected:

- `net.ipv4.ip_forward = 1`
- `FORWARD` accepts `wg0` in and out
- `POSTROUTING` masquerades `10.8.0.0/24` through the default egress interface

On the client, check that `AllowedIPs` includes the target destination. Full tunnel uses `0.0.0.0/0`; split tunnel must include every target CIDR.

## Client Egress IP Did Not Change

Run from the client:

```bash
wg show
curl -4 https://api.ipify.org
ip route
```

Most common causes:

- Client `AllowedIPs` is split-tunnel and does not include the IP being tested.
- Another local VPN/proxy is overriding routes.
- The client imported an old config pointing to the old VPS.

## OpenAI API Works but ChatGPT Login Fails

This is usually IP reputation, not VPN routing.

Signs:

- `api.openai.com/v1/models` returns `401` without a token.
- `auth.openai.com` or `chatgpt.com` returns `403`.
- Response headers include `cf-mitigated: challenge`.

Action:

- Use API key mode if the user's workflow only needs the OpenAI API.
- If OAuth/ChatGPT login is required, test a different egress IP.
- Do not spend time changing WireGuard keys or NAT rules when the client egress IP is already the VPS IP and only auth/chatgpt is challenged.

## Docker Breakage After VPN Install

The VPN NAT must stay scoped:

```bash
iptables -t nat -S POSTROUTING | rg '10\.8\.0\.0/24|172\.'
```

Avoid replacing Docker's own NAT rules or adding broad `! -o wg0 -j MASQUERADE` rules. The expected VPN rule only matches `-s 10.8.0.0/24`.
