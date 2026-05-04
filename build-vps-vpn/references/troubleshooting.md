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
sudo tcpdump -ni any 'tcp port 18443 or udp portrange 20000-50000'
```

If tcpdump sees no packet, the problem is outside sing-box: Azure NSG, local client network, wrong server address, or wrong port.

If packets arrive but the client fails:

- Confirm the VLESS UUID, Reality public key, short ID, flow, and SNI match the generated values.
- Confirm the Hysteria2 password and TLS server name match the generated config and certificate.
- Confirm the client is using TCP for VLESS Reality and UDP for Hysteria2.
- Confirm server time is sane with `timedatectl`.

## Hysteria2 Port Hopping Not Surviving Reboot

Symptom: clients work right after `setup-hy2-porthop.sh`, but stop after a reboot.

Diagnose:

```bash
sudo iptables -t nat -L PREROUTING -n -v
sudo systemctl status netfilter-persistent
ls -la /etc/iptables/
```

Expected:

- `PREROUTING` shows a `DNAT` rule with `udp dpts:20000:50000 to::36712`.
- `netfilter-persistent.service` is `enabled`.
- `/etc/iptables/rules.v4` and `rules.v6` exist and contain the DNAT line.

Fix path if missing: re-run `sudo bash scripts/setup-hy2-porthop.sh ...`. The script is idempotent; rerunning will not duplicate rules.

## Hysteria2 Connects but Throughput is Poor

- Confirm BBR is on the host: `sysctl net.ipv4.tcp_congestion_control` should print `bbr`. If not, set:
  ```
  echo 'net.core.default_qdisc=fq'           | sudo tee  /etc/sysctl.d/99-bbr.conf
  echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.d/99-bbr.conf
  sudo sysctl --system
  ```
- Confirm the client is actually hopping ports: capture briefly with `sudo tcpdump -ni eth0 'udp and (dst portrange 20000-50000)'`. If only one port is observed, the client config is missing the `ports:` field for the Hysteria2 node.
- Confirm conntrack is not saturated on tiny VMs (<1 GB RAM):
  ```
  sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max
  ```
  Raise `nf_conntrack_max` if needed.

## Subscription URL: SSL verify fails

Symptom: `curl https://<domain>/<token>.yaml` returns "no alternative certificate subject name matches target host name".

Most common causes:

- The vhost configured for the subscription points to the wrong cert path. Inspect with:
  ```
  echo Q | openssl s_client -connect 127.0.0.1:443 -servername <domain> 2>/dev/null \
    | openssl x509 -noout -subject -ext subjectAltName
  ```
  If the SAN does not include the requested domain, fix the vhost's `ssl_certificate` and `ssl_certificate_key` lines to point at `/etc/letsencrypt/live/<domain>/`.
- A reload race: `nginx -s reload` is async; if you `curl` immediately afterwards from the same script, you may hit the old worker. Sleep 1 second between reload and curl, or use `nginx -t && systemctl reload nginx` and retry once.

## Subscription URL: 404 on /<token>.yaml

- Path strictness: the vhost only matches `^/[a-f0-9]{32}\.yaml$`. Hand-typed URLs that include capital letters or wrong-length tokens 404 by design.
- File ownership: `/var/www/sub/<token>.yaml` must be world-readable (`chmod 644`); nginx workers run as `www-data` and silently 404 when they cannot read the file.
- If you suspect a server-block mismatch (request hitting the wrong vhost), confirm with `curl -v -H "Host: <domain>" https://127.0.0.1/<token>.yaml -k` and read the cert subject in the response.

## certbot --nginx vs --webroot

If the host already runs a production nginx site on `:80` and `:443`, prefer `--webroot`. `--standalone` will refuse or stop nginx. `--nginx` will rewrite the existing site config to inject `ssl_*` directives, which is intrusive and easy to miss in code review.

## sing-box Silently Fails ~90 Days After Install

Cause: cert renewed but sing-box still holds the old TLS material in memory. Fix by installing the deploy hook from `references/letsencrypt-deploy-hook.sh` at `/etc/letsencrypt/renewal-hooks/deploy/restart-sing-box.sh` (`chmod +x`). Verify it runs by:

```bash
sudo certbot renew --dry-run
journalctl -u sing-box --since "5 minutes ago"
```

The journal should show a fresh sing-box start during the dry-run.

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

Typical layout on a host that also runs an HTTPS app and the Clash subscription:

- nginx owns TCP `80` and `443` (multiple SNIs via separate server blocks).
- sing-box owns TCP `18443`.
- sing-box owns UDP `36712` (with iptables DNAT redirecting `20000-50000` into it).
- sing-box Clash API stays on `127.0.0.1:9090`.

Move sing-box ports rather than sharing a port already owned by nginx unless the user intentionally builds a more advanced fronting setup.
