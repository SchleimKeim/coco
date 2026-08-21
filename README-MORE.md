# 🥥 coco — facts

## What
- Docker dev container, mounts `pwd` at same absolute path in-container
- Base: AlmaLinux 10
- Agents installed: Claude Code, Codex, Copilot, Cursor, Gemini

## Install
```
git clone https://github.com/mmdevl/coco.git ~/coco
~/coco/bin/coco --install
```

## Run
```
cd project
coco
```
- builds image (cached), starts container, drops into shell
- running in `$HOME` warns first (would mount whole home)

## Flags
- `--install` — add to PATH
- `--rebuild` — force image rebuild
- `--config` — re-pick agents for this project
- `--cleanup` — remove old/dangling coco images
- `--check-update` — check now, skip 24h cache
- `--no-update-check` — skip check this run
- `-V` — version
- `-h` — help

## Env vars
- `UID`, `GID`, `TZ`
- `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL` (optional)
- `XDEBUG_ENABLE` (optional)
- `COCO_NO_UPDATE_CHECK=1` — same as `--no-update-check`
- `COCO_UPDATE_REMOTE=<name>` — remote to check (default `origin`)

## Mount path — why
- project mounted at same absolute host path → tool caches (claude-mem, `.git` worktrees, LSP) stay valid both sides
- host paths unique → agent trust-lists don't confuse different projects
- container name still gets 6-char hash of full path (Docker needs unique names, limited chars)

## Coding agents
- first run: interactive checklist picks agents (0+), saved to `.coco/config` as `AGENTS=claude,codex,...`
- non-tty: falls back to numbered prompt
- all agent CLIs installed regardless; selection only controls which host config dirs get mounted
- config paths: `~/.claude`, `~/.codex`, `~/.config/gh-copilot`, `~/.cursor`, `~/.gemini`
- `~/.claude.json` NOT bind-mounted directly (breaks atomic writes); host symlinks it into `~/.claude/claude.json`, container entrypoint recreates matching symlink each start
- re-run picker: `coco --config`

## Persistent data
```
global (~/...):     .claude .codex .config/gh-copilot .cursor .gemini
project (pwd/.coco/...): cache/pip cache/npm cache/composer bash_history vim
```
- `.coco/` also holds `config`
- first run prompts to add `.coco` to `.gitignore`

## Build/rebuild
- version lives in `VERSION` file (semver, manual bump)
- images tagged `coco:latest` + `coco:<VERSION>`
- hash of Dockerfile + build context + UID/GID/TZ/HOME + VERSION → stored as `coco.hash` label
- rebuilds only if hash changed; `--rebuild` forces it
- missing `coco:<VERSION>` tag but matching hash → re-tags for free, no rebuild

## Update check
- runs on startup, before agent selection
- compares local `VERSION` vs highest `vX.Y.Z` git tag on remote
- cached 24h in `${XDG_CACHE_HOME:-~/.cache}/coco/update-check`
- silently skips if: no `VERSION`, not a git checkout, no matching remote, non-interactive, remote unreachable (backs off 1h), no tags yet
- on update found: prompts → `git pull --ff-only` → re-execs coco
- refuses on dirty worktree / detached HEAD

## Cleanup
- `coco --cleanup` removes: dangling `<none>` images (matched via `coco.hash` label), old `coco:<version>` tags
- never touches current `latest`/`<VERSION>`, never touches non-coco images, never force-removes in-use images
- confirms before removing

## Release
```
echo "0.2.0" > VERSION
bin/release            # commit VERSION, tag, push
bin/release --dry-run
bin/release --force    # skip semver-newer guard
```
- no-op if tag already exists
- refuses on detached HEAD or non-newer semver

## Shell / Vim
- bash: git completion, colored prompt, shows branch
- vim: syntax highlight, line numbers, incremental search

## Safety
- each coding agent's own first-run trust prompt still applies (e.g. Claude Code "Yes, I trust this folder")
- per-project mount path makes this fire correctly per project

## License
MIT — see [LICENSE](LICENSE)
