# Troubleshooting smoke failures

Failures cluster into a few archetypes.  Match the symptom to one of
the patterns below — each has a fixed debug order that's faster than
poking at the CLI under `NODE_DEBUG`.

## Symptom: smoke exits in *exactly* N seconds

If the failure timestamp is `start + N` for some round N (30, 60, 180),
the cause is **almost never "things are slow"**.  It's something with
an N-second retry budget being exhausted.  The two classics:

1. **Authentication retry loop.**  The runtime got 401 from the API,
   retried with exponential backoff, and the outer `timeout N` killed
   it before the SDK gave up.  Local manual runs succeed in <10s
   because the operator typed the key correctly; CI fails because the
   secret was pasted wrong.
2. **Connect timeout to wrong address.**  The runtime is trying
   `localhost` (IPv6 `::1`) but the listener only binds `127.0.0.1`.
   `connect()` waits the kernel TCP timeout, then maybe tries IPv4.
   Different node versions / undici versions vary.

**Debug order (fixed):**

1. Print the secret's length and first 6 characters from the workflow:
   ```bash
   KEY_LEN=${#SMOKE_KEY_CLEAN}
   echo "DEBUG: key length=$KEY_LEN, prefix=${SMOKE_KEY_CLEAN:0:6}, expected=51, expected prefix=sk-..."
   ```
   If length differs by 1–3, you have trailing whitespace.  Even after
   `tr -d '[:space:]'` if it differs significantly, you pasted a
   different key.
2. Direct `curl` test on the VPS using the same key:
   ```bash
   curl -s -m 10 -w '\nhttp=%{http_code}\n' \
       -H "Authorization: Bearer $KEY" \
       -H "Content-Type: application/json" \
       -d '{"model":"...","max_tokens":16,"messages":[{"role":"user","content":"hi"}]}' \
       http://127.0.0.1:3000/v1/messages
   ```
   - `http=200` → key is fine, runtime has the bug
   - `http=401` → key in secret is wrong; recreate the secret
   - `http=000` → cannot reach upstream (tunnel down, port wrong, firewall)
3. **Only after 1 + 2 are clean**, add `NODE_DEBUG=net` or `strace`
   inside the runtime to see what it's actually doing.

The first iteration of this skill spent 90 minutes debugging step 3
before doing steps 1 and 2.  Don't.

## Symptom: `ssh: no key found` in `appleboy/scp-action`

The `VOLC_SSH_KEY` (or your equivalent) secret was pasted incorrectly.
Classic causes:

- Pasted the `.pub` file (public key) instead of the private key.
- Pasted only the base64 body, missing the `-----BEGIN OPENSSH
  PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----` framing
  lines.
- Missing trailing newline after the END line.  Go's SSH library
  requires the PEM to end in `\n`.
- Pasted from a clipboard tool that mangled long lines (some Windows
  RDP clipboards do this).

Fix: re-cat the private key on the source host and re-paste:

```bash
cat ~/.ssh/gha_PROJECT_deploy
```

Select from the first `-----BEGIN` character through to the newline
after `-----END-----`.  Update the secret.  No commit needed — secrets
are read fresh per job; `gh run rerun <id> --failed` is enough.

## Symptom: smoke passes locally but hangs in CI (no auth error)

You verified step 1+2 above — key is correct, curl returns 200.  But
the runtime CLI still hangs in CI.

Differences worth checking:

- **TTY**: CI ssh has no controlling terminal.  Some CLIs do
  `isatty()` checks and behave differently.  Add `</dev/null` to the
  invocation if not already there.
- **`sudo -u <user> bash -c '...'` quoting**: if the inner command
  has dollar-vars they may be expanded too early or not at all.  Use
  `env VAR=value` form to be explicit:
  ```bash
  sudo -u runtime_user env KEY="$KEY" bash -c 'cd dir && bash script.sh'
  ```
- **Reverse SSH tunnel saturation**: if the CLI fetches via a tunnel
  back to your dev machine, and the GH runner's ssh session and the
  CLI both saturate the same tunnel, things slow down.  Rare; usually
  a sign you should move the upstream onto the VPS itself.

## Symptom: `appleboy/ssh-action` hangs but native ssh works

Empirically observed: `appleboy/ssh-action` adds a docker wrapper
around the SSH client that has subtle stdin/TTY differences from
plain `ssh`.  This was *not* the root cause of the original 60s hang
(that was the 401 retry loop) but it's a real source of CI/local
divergence.

**Fix**: use native `ssh` in a `run` step.  The template
[ci-smoke.yml.tmpl](../templates/ci-smoke.yml.tmpl) does this for the
smoke step.  Keep `appleboy/scp-action` for the file upload — it works
fine and saves writing a tar+scp loop yourself.

## Symptom: `Repository not found` on first push

Two possible causes:

1. The repo really doesn't exist at that URL.  Check the exact
   `<owner>/<name>`.
2. The repo is private and the credential chain can't auth — GitHub
   returns 404 to unauth'd clients to avoid info leak.  Set up the
   credential helper (`gh auth login` then `gh auth setup-git`).

## Symptom: `refusing to allow an OAuth App to create or update workflow`

The GH OAuth token scope is missing `workflow`.  Default `gh auth
login` only requests `gist, read:org, repo`.  Refresh:

```bash
gh auth refresh -h github.com -s workflow
```

This triggers another device-code flow.

## Symptom: `@claude` workflow runs but action errors `unsupported input 'allowed_tools'`

The `anthropics/claude-code-action@v1` schema changed.  `allowed_tools`
is no longer a top-level input; it goes inside `claude_args`:

```yaml
# old (deprecated):
allowed_tools: "Bash,Read,Edit,Glob,Grep,Write"

# new:
claude_args: --allowed-tools "Bash,Read,Edit,Glob,Grep,Write"
```

The template ships with the new form.

## Symptom: `Couldn't install GitHub App: Command 'gh' not found` from `/install-github-app`

The `claude /install-github-app` command shells out to `gh` and needs
it on the host machine's PATH.  If you installed `gh` only inside WSL,
the Windows CC process can't see it.

Fix:
- Windows: `winget install GitHub.cli`, then **restart CC** (PATH is
  cached at process start).
- macOS: `brew install gh`.
- Linux native: `apt install gh` or download static binary.

Then `gh auth login` on the host before retrying `/install-github-app`.

## When in doubt: the pre-flight curl is your friend

The skill's `ci-smoke.yml.tmpl` runs a `curl` against the API endpoint
*before* invoking the runtime CLI.  This is not redundant — it's a
fail-fast diagnostic that turns "60-second mystery hang" into
"3-second clear 401".  Don't remove it.
