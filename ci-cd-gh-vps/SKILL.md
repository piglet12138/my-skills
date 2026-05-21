---
name: ci-cd-gh-vps
description: "Full-automation CI/CD: GitHub Actions + Claude Code Action + local dev-watcher. Reader提 issue 评论 @claude → agent 改代码推 branch → auto-PR 自动开 PR + auto-merge → CI smoke → 合进 dev → 本地 watcher 拉到预览 → 人工 F5 验收 → ff-merge dev→main → deploy.yml 推 prod。包含 4 个工作流模板 + dev-watcher 脚本 + bootstrap 脚本（生成 SSH key + 列出 GH Secrets）。已在 piglet12138/claude-ai-harness 实战验证（一天 14 PR）。Use when: 给单人/小团队项目接通 issue → 自动改 → 自动测 → 自动合 → 一键上线 流水线。"
---

## v2（2026-05-22）—— 完整自动化版本

> 这是基于 [piglet12138/claude-ai-harness](https://github.com/piglet12138/claude-ai-harness) 实战迭代出的最新版本。包含 4 个 workflow 文件 + 本地 watcher，实现从 issue 提交到生产部署的全自动化（除人工 F5 验收外）。
>
> **完整说明**：[https://sg.yaoyuheng2001.me/posts/solo-cicd-claude-agent/](https://sg.yaoyuheng2001.me/posts/solo-cicd-claude-agent/)

### v2 工作流文件（4 个）

| 模板 | 触发 | 作用 |
|---|---|---|
| [templates/claude.yml.tmpl](templates/claude.yml.tmpl) | issue / PR 评论里有 `@claude` | checkout dev 分支，启动 Claude Code Action，agent 改完推 `claude/issue-N` 分支 |
| [templates/auto-pr.yml.tmpl](templates/auto-pr.yml.tmpl) | push 到 `claude/issue-**` 分支 | 自动 `gh pr create --base dev` + `gh pr merge --auto --merge` |
| [templates/ci.yml.tmpl](templates/ci.yml.tmpl) | PR 进 main 或 dev | `npm ci` → 语法检查 → 启 server 30s curl `/healthz` |
| [templates/deploy.yml.tmpl](templates/deploy.yml.tmpl) | push 到 main | SSH VPS → git pull → 必要时 npm ci → systemctl restart → 探公网 → 清理已合 `claude/issue-*` 分支 |

### 本地组件

- [scripts/dev-watcher.sh](scripts/dev-watcher.sh) —— 30 行 bash 循环。每 15s `git fetch origin dev`，发现 dev 前进就 ff-pull。后端文件变了 pkill+重启 node；静态文件变了浏览器 Ctrl+F5 即可。

### v2 用法（4 步）

1. **占位符替换**：在 4 个 `.tmpl` 文件里替换 `__OWNER__` / `__REPO__` / `__VPS_IP__` / `__INSTALL_DIR__` / `__SERVICE__` / `__PUBLIC_HOST__`
2. **bootstrap SSH key**：`bash scripts/bootstrap.sh --project <slug> --host <vps-ip> --user root` → 在 GH Secrets 里加 `<PROJECT>_HOST` / `<PROJECT>_USER` / `<PROJECT>_SSH_KEY`
3. **打开 GH Actions PR-create 权限**：
   ```bash
   gh api -X PUT repos/$OWNER/$REPO/actions/permissions/workflow \
     -f default_workflow_permissions=write \
     -F can_approve_pull_request_reviews=true
   gh api -X PATCH repos/$OWNER/$REPO -f allow_auto_merge=true -f allow_update_branch=true
   ```
4. **本地起 watcher**：`bash scripts/dev-watcher.sh`（建议挂 nohup 后台跑）

### 已知 gotchas（一定要看）

1. **YAML `run: |` 块里嵌多行 bash 字符串**会被 YAML 解析器当块结束符吞掉。用 `body=$(printf 'A %s B %s' "$a" "$b")` 单行 printf。
2. **GitHub Actions 默认不能创建 PR**，要 PATCH workflow permissions（见上面 step 3）。
3. **`strict: true` status check + `allow_update_branch: false`** 会让 auto-merge 永远 BLOCKED。必须打开 allow_update_branch。
4. **CSS 给彩色 emoji 加 `color`** 不生效（emoji 是多色 glyph），UI 改动必须人眼过一遍 —— CI 抓不到这类视觉 bug。
5. **VPS 上跑过 `nohup node server.mjs &`** 会留下占端口的野生进程，systemd 重启时 EADDRINUSE 静默失败。所有服务统一走 systemd，禁用 nohup。

---

## v1（legacy）—— 简单 CLI artifact deploy

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
