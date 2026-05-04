#!/usr/bin/env bash
# Drop this at /etc/letsencrypt/renewal-hooks/deploy/restart-sing-box.sh
# and chmod +x. Certbot exports RENEWED_LINEAGE pointing at the lineage
# directory it just renewed, e.g. /etc/letsencrypt/live/vpn.example.com.
#
# We restart sing-box only when the renewed lineage matches a domain
# whose cert sing-box loads (any name starting with "vpn." here; adjust
# the pattern to your own naming). This avoids restarting sing-box for
# unrelated certs that may live on the same host.

if [[ "${RENEWED_LINEAGE:-}" == */vpn.* ]]; then
    systemctl restart sing-box
fi
