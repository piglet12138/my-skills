#!/usr/bin/env bash
# Bootstrap a dedicated SSH keypair for GitHub Actions deploys, copy
# the public key to the target VPS, and print the GitHub Secrets you
# need to add manually.
#
# Usage:
#   bash scripts/bootstrap.sh --project claw --host 118.145.114.95 --user root
#
# Idempotent: if the key already exists, reuses it.  Will still attempt
# ssh-copy-id; that's idempotent too (skips already-installed keys).
set -eu

PROJECT=""
HOST=""
USER_ARG="root"
PORT="22"

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --host)    HOST="$2";    shift 2 ;;
    --user)    USER_ARG="$2"; shift 2 ;;
    --port)    PORT="$2";    shift 2 ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2 ;;
  esac
done

if [ -z "$PROJECT" ] || [ -z "$HOST" ]; then
  echo "usage: $0 --project <name> --host <ip-or-hostname> [--user root] [--port 22]" >&2
  exit 2
fi

KEY="$HOME/.ssh/gha_${PROJECT}_deploy"

if [ ! -f "$KEY" ]; then
  echo "==> generating ed25519 keypair at $KEY"
  ssh-keygen -t ed25519 -C "gha-${PROJECT}-deploy" -f "$KEY" -N ""
else
  echo "==> reusing existing key at $KEY"
fi

echo "==> installing public key on ${USER_ARG}@${HOST}:${PORT}"
ssh-copy-id -i "${KEY}.pub" -p "$PORT" "${USER_ARG}@${HOST}"

echo "==> verifying passwordless login"
if ssh -i "$KEY" -p "$PORT" -o BatchMode=yes -o ConnectTimeout=5 \
       "${USER_ARG}@${HOST}" "echo ok" >/dev/null 2>&1; then
  echo "    OK"
else
  echo "    FAILED — passwordless ssh did not work; check sshd config + key permissions" >&2
  exit 1
fi

PROJECT_UPPER=$(printf '%s' "$PROJECT" | tr '[:lower:]' '[:upper:]')

cat <<EOF

================================================================
SSH bootstrap complete.  Add these secrets at:
  https://github.com/<owner>/<repo>/settings/secrets/actions

  ${PROJECT_UPPER}_HOST       = ${HOST}
  ${PROJECT_UPPER}_USER       = ${USER_ARG}
  ${PROJECT_UPPER}_SSH_KEY    = <paste contents of ${KEY} below>

Copy private key to clipboard (Linux/WSL with X):
  cat ${KEY} | xclip -selection clipboard
Or print it (paste manually — DO NOT add trailing newline in GH form):

EOF

echo "---- BEGIN PRIVATE KEY (paste below into GH Secret) ----"
cat "$KEY"
echo "---- END PRIVATE KEY ----"

cat <<EOF

GH form tips:
- Paste the entire block INCLUDING -----BEGIN/END----- lines
- Do NOT press Enter after the final dashes — trailing whitespace is
  the #1 cause of "ssh: no key found" in appleboy/scp-action
- After saving, GH will mask the value; you cannot read it back

Next: copy the workflow templates from this skill into your repo
under .github/workflows/ and scripts/.  See SKILL.md for the
placeholder list.
EOF
