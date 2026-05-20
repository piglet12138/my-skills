---
name: ci-cd-gh-vps
description: "Set up a GitHub Actions CI/CD pipeline that builds a Node/Bun project, deploys the artifact to a remote VPS via SSH, runs a smoke test as the real end-user, and wires up an `@claude` agent loop for issue-driven iteration. Includes ready-to-paste workflow YAML, a parametrized smoke script, and a bootstrap helper that generates a dedicated SSH keypair + prints the exact GitHub Secrets to add. Use when: bootstrapping a new repo that needs push → build → remote deploy → real-user verification → autonomous bug-fix on `@claude` mention; replicating the pattern used in piglet12138/claw; debugging a stalled smoke job that ends in exactly N seconds (suggests retry budget, not slowness); auditing GH Secret hygiene (trailing newlines, wrong key pasted)."
---

# GH Actions CI/CD with VPS Smoke + @claude Agent

End state: every push triggers `bun run build` on a GitHub-hosted runner, scps the artifact (`dist/cli.mjs` or similar) to your VPS, runs a smoke test from the VPS-side perspective (the "real user"), and posts a failure summary back to the PR. A separate workflow lets you mention `@claude` in any issue/PR to spawn an autonomous Claude Code session that reads the issue, edits the code, and opens a PR — all without API key costs if you have a Claude Pro/Max subscription.

This skill assumes:
- The project is a Node.js or Bun bundle that produces a single artifact file (e.g. `dist/cli.mjs`).
- The deploy target is a Linux VPS reachable via SSH (we configure key-based auth).
- The "real user" test is a CLI invocation that should exit 0 and print a known string.

If your project is a web service / Docker image / multi-binary, adapt the upload step accordingly — the pattern stays the same.

## Decision points (ask the user before generating)

Before copying templates, surface these so the YAML doesn't ship with placeholders:

1. **Repo full name** (e.g. `piglet12138/claw`) — used in templates only as a comment.
2. **Build command** (default `bun run build`; falls back to `npm run build`).
3. **Artifact paths** to scp (default `dist/cli.mjs` + smoke script).
4. **Remote install dir** on VPS (default `/opt/<project>/`).
5. **Remote SSH user** — `root` is convenient since the smoke step needs to chown to an unprivileged user; if the project's CLI refuses to run as root (Claude Code is a good example), the smoke `ssh` script will `sudo -u <runtime_user>`.
6. **Runtime user on VPS** — the unprivileged account the CLI runs as (default `app` or matches project name).
7. **Upstream URL the smoke uses** — usually `http://127.0.0.1:3000` if the VPS is fronting an API server; **use `127.0.0.1` not `localhost`** to avoid IPv6 `::1` happy-eyeballs stalls when the listener only binds IPv4.
8. **Whether the VPS reaches its backend via reverse SSH tunnel** — common pattern when the backend lives on the developer's machine. If yes, the smoke script must gracefully exit 0 (with a `::warning::`) when the tunnel is down, otherwise off-hours pushes fail spuriously.

## Bootstrap: SSH key + Secrets list

Use [scripts/bootstrap.sh](scripts/bootstrap.sh) on the developer's machine (WSL or Linux). It:

1. Generates a dedicated ed25519 keypair at `~/.ssh/gha_<project>_deploy` (no passphrase — GH Actions can't enter one).
2. `ssh-copy-id`s the public key to the VPS (one-time password prompt).
3. Prints the exact list of GitHub Secrets to add, including the private key content piped through `tr -d '\r'` to strip Windows line endings.

```bash
bash scripts/bootstrap.sh --project claw --host 118.145.114.95 --user root
```

After running, manually add these secrets at `https://github.com/<repo>/settings/secrets/actions`:

| Secret | Value |
|---|---|
| `VOLC_HOST` (rename for your project) | VPS IP |
| `VOLC_USER` | SSH login user (often `root`) |
| `VOLC_SSH_KEY` | private key content (full block, including `BEGIN`/`END`, no trailing whitespace) |
| `SMOKE_ANTHROPIC_API_KEY` | the upstream API key the smoke test passes to your CLI |
| `CLAUDE_CODE_OAUTH_TOKEN` | (for `@claude` agent only) auto-written by `claude /install-github-app` |

## Templates: copy & customize

Three files go into the consumer repo:

- [templates/ci-smoke.yml.tmpl](templates/ci-smoke.yml.tmpl) → `.github/workflows/ci-smoke.yml`
- [templates/ci-smoke.sh.tmpl](templates/ci-smoke.sh.tmpl) → `scripts/ci-smoke.sh`
- [templates/claude.yml.tmpl](templates/claude.yml.tmpl) → `.github/workflows/claude.yml`

After copying, search-replace these placeholders:
- `__PROJECT__` → your project name (e.g. `claw`)
- `__INSTALL_DIR__` → `/opt/claw` (or similar)
- `__RUNTIME_USER__` → `claw` (or your unprivileged user)
- `__ARTIFACT__` → `dist/cli.mjs` (or your bundle path)
- `__BUILD_CMD__` → `bun run build` (or `npm run build`)

The smoke YAML uses **native `ssh`** in a `run` step rather than `appleboy/ssh-action`. The native path has identical observability to debugging from your own terminal, which matters when smoke fails in CI but passes locally — there's no extra docker indirection to blame.

## @claude agent workflow (separate)

`claude.yml.tmpl` listens for `@claude` mentions in:
- Issue comments
- PR review comments
- New issue bodies
- PR review submissions

When triggered, it spawns `anthropics/claude-code-action@v1`, which uses `CLAUDE_CODE_OAUTH_TOKEN` from your Pro/Max subscription (no per-token billing). The agent has `contents: write + pull-requests: write` — it can open PRs but **cannot merge to main** unless you remove branch protection (don't).

Generate the OAuth token via:

```bash
# In local Claude Code, point at the target repo:
claude /install-github-app
```

This walks through Anthropic's OAuth flow and writes `CLAUDE_CODE_OAUTH_TOKEN` to the repo's secrets automatically. Requires `gh` CLI installed on the host machine first (`winget install GitHub.cli` on Windows, or `apt install gh` on Linux).

## Verification

After all files are in place and secrets are set:

```bash
# Trigger via push (auto)
git add scripts/ci-smoke.sh .github/workflows/
git commit -m "ci: add Volc smoke pipeline + @claude agent"
git push

# Watch the run
gh run list --repo <repo> --limit 3
gh run watch <run-id> --repo <repo>

# Test agent loop
gh issue create --repo <repo> --title "agent smoke" --body "@claude reply with hi"
# bot should comment within ~30s
```

The first run is the slowest because it cold-loads everything. Expect ~1–2 min for build + scp + smoke once primed.

## When smoke fails — debug in this order

Read [references/troubleshooting.md](references/troubleshooting.md) when smoke fails. The general principle: **a smoke that fails at exactly N seconds is rarely "things are slow" — it's something with an N-second retry budget**. The debug order is always:

1. **Credentials reach the runtime intact** — print length + prefix in the workflow (mask the rest). GH Secrets sometimes carry trailing whitespace from the paste; always `tr -d '[:space:]'` before passing to the runtime.
2. **Credentials work outside the runtime** — direct `curl` from the VPS against the API endpoint with the same key. If 401, the secret value is bad; fix the secret. If 200, the runtime is the problem.
3. **Only then debug the runtime** — `NODE_DEBUG=net`, `--trace-warnings`, `strace`, etc.

Don't loop on step 3 without first doing 1 and 2. This skill exists partly because that loop wasted 90 minutes on its first build.

## Files in this skill

- [SKILL.md](SKILL.md) — this file
- [scripts/bootstrap.sh](scripts/bootstrap.sh) — generates SSH key, copies to VPS, prints secret list
- [templates/ci-smoke.yml.tmpl](templates/ci-smoke.yml.tmpl) — build + scp + ssh smoke workflow
- [templates/ci-smoke.sh.tmpl](templates/ci-smoke.sh.tmpl) — parametrized smoke runner (reachability check + per-model test)
- [templates/claude.yml.tmpl](templates/claude.yml.tmpl) — `@claude` agent dispatch
- [references/troubleshooting.md](references/troubleshooting.md) — what 60s-exact failures, IPv6 stalls, and "wrong key in secret" look like in real logs
