# 🥥 coco — Coding Container Suite

A reusable, Docker-based development environment for daily software development:

* terminal-first (vim, git, coding agents, python, pip, php, composer, npm, ...)
* close to the production environment (AlmaLinux 9)
* easy to maintain and extend

`coco` is a generic development workstation, not tied to any specific project. Run it in any project directory:

```bash
cd /path/to/a/project
coco
```

A Docker container is built (once, then cached), started with `pwd` bind-mounted in, and dropped into an interactive shell. (Running it in `$HOME` itself triggers a warning first — that would mount your entire home directory.)

## Installation

```bash
git clone <this repo> ~/coco
```

On first run, if `coco` isn't already on `PATH`, it prompts to append to `~/.bashrc`:

```bash
echo 'export PATH="...:$PATH"' >> ~/.bashrc
```

Only after confirmation.

## Requirements

Docker (or a compatible CLI, e.g. Podman aliased to `docker`), reachable and running.

## Usage

```
usage: coco [options]

  --rebuild           force a rebuild of the coco image
  --config            re-run coding-agent selection for this project
  --cleanup           remove old and dangling coco images (never the current one)
  --check-update      check for a new coco release now, ignoring the 24h cache
  --no-update-check   skip the periodic update check for this run
  -V, --version       print coco's version and exit
  -h, --help          show this help and exit

environment:
  COCO_NO_UPDATE_CHECK=1     same as --no-update-check
  COCO_UPDATE_REMOTE=<name>  git remote to check for releases (default: origin)
```

## Base image

AlmaLinux 9.

## Container tools

git vim less curl wget jq rsync unzip zip tar make gcc which screen htop strace lsof mysql sqlite3 python3 pip3 venv php-cli php-ldap php-mysqlnd php-xdebug phpunit composer ldapsearch

* **xdebug**: installed but disabled by default (`xdebug.mode=off`). Enable per-run via `XDEBUG_ENABLE=1` env var, entrypoint flips the ini setting before launching the shell.

## User

A normal user (`coco`), with passwordless sudo. UID/GID are auto-detected from the invoking host user (`id -u` / `id -g`) and passed as build/run args. The user owns the mounted project directory.

## Mount path

The project is mounted at the *same absolute path inside the container as on the host* (e.g. `/Users/alice/work/foo`), not a fixed `/code` or a basename-derived path. This is the same reasoning as `$HOME` above (see Coding agents): any tool that caches an absolute in-container path — claude-mem keys its memory store by `basename(git rev-parse --show-toplevel)`, `.git` worktree configs, LSP caches — stays valid on both sides of the mount this way, and a matching path can't drift out of sync the way a derived one could.

Host paths are inherently unique, which also solves Claude Code / other agents' trust-list falsely treating different projects as "the same" trusted path — no basename or hash needed on the mount path itself for that.

A 6-char hash of the full host path is still used for `CONTAINER_NAME` (`coco-<basename>-<hash6>`), since Docker requires container names to be unique and doesn't accept arbitrary path characters in one.

## Coding agents

Not limited to Claude Code. On first run in a project, `coco` prompts you to select which coding agent(s) to enable (0, 1, or more), via a plain numbered checklist (space-separated input, e.g. "1 3 4") — no `whiptail`/`dialog` dependency. Selection is saved to `.coco/config`:

```
AGENTS=claude,codex,gemini
```

Supported agents and their host config paths:

| Agent | Config path(s) |
|---|---|
| Claude Code | `~/.claude` (only — see note below) |
| OpenAI Codex CLI | `~/.codex` |
| GitHub Copilot CLI | `~/.config/gh-copilot` |
| Cursor CLI (cursor-agent) | `~/.cursor` |
| Gemini CLI | `~/.gemini` |

All agent CLIs are installed in the image regardless of selection (a single shared image stays simple, and agents are small installs). Selection only controls:

* which host config paths get checked/mounted
* for each selected agent, if its host config path doesn't exist, `coco` prompts to create it before mounting

Note on `~/.claude.json`: it is *not* bind-mounted directly, even though Claude Code keeps it next to `~/.claude` on the host. Bind-mounting a single file breaks Claude Code's atomic config writes (temp file + `rename()`): the temp file lands on the container's own filesystem while the target is on the host-mounted one, so the cross-filesystem `rename()` fails (`EXDEV`) and falls back to a non-atomic write that can be read mid-write, corrupting the JSON. Fix: on the host, `~/.claude.json` is a symlink into `~/.claude/claude.json` (the real file lives inside the mounted directory); the container's entrypoint recreates the matching in-container symlink (`~/.claude.json` → `.claude/claude.json`) on every start, so the temp file and its rename target always share the same filesystem.

Re-run selection any time with `coco --config` (overwrites `.coco/config`).

The config file format is plain `KEY=value` (bash-sourceable) — no JSON/YAML parser dependency.

## Persistent data

```
# globally --> mapped to $HOME/...
~/.claude, ~/.codex, ~/.config/gh-copilot, ~/.cursor, ~/.gemini   (whichever agents selected; see note on ~/.claude.json above)
# project based --> mapped to `pwd`/.coco/...
~/.cache/pip
~/.cache/npm
~/.cache/composer
~/.bash_history
~/.vim
```

`.coco/` also holds `config` (agent selection, see above). On first run, if `.coco` isn't in the project's `.gitignore`, `coco` prompts to add it.

## Image build / rebuild strategy

`coco`'s own version lives in a plain-text `VERSION` file at the repo root (semver, bumped by hand). Images are tagged both `coco:latest` and `coco:<VERSION>`.

`coco` computes a hash of the Dockerfile + build context files + UID/GID/TZ/HOME + `VERSION`, and stores it as a label (`coco.hash`) on the built image, alongside a `coco.version` label. On each run, it compares the current hash against the image label and rebuilds only if changed. Folding `VERSION` into the hash means a version bump alone forces a rebuild (a release is by definition a different artifact) without needing a second, separate gate condition — it's cheap when the Dockerfile itself is unchanged, since every layer is still cache-hit. `coco --rebuild` forces a rebuild manually regardless of the hash.

If `coco:<VERSION>` is ever missing while `coco:latest` still matches the current hash, `coco` re-tags it for free on the next run rather than rebuilding. No registry.

## Update check

On startup (after the docker preflight, before agent selection), `coco` checks whether a newer release is available: it compares the local `VERSION` against the highest `vX.Y.Z` tag from `git ls-remote --tags origin` (configurable via `COCO_UPDATE_REMOTE`). Checked at most once per 24h, cached in `${XDG_CACHE_HOME:-$HOME/.cache}/coco/update-check`; `coco --check-update` forces an immediate check, `coco --no-update-check` / `COCO_NO_UPDATE_CHECK=1` skips it for the run.

The check silently no-ops (no output, no prompt) when: `coco` has no `VERSION`; it isn't run from a git checkout or the checkout has no matching remote; it's not an interactive terminal; the remote is unreachable (a network failure backs off for 1h instead of the usual 24h); or the remote has no tags yet. On finding a newer release, it prompts to update; on confirmation it runs `git pull --ff-only <remote> <branch>` against the same remote that was checked (refusing on a dirty worktree or detached HEAD) and re-execs `coco` so the build gate above picks up the pulled changes.

## Cleanup

`coco --cleanup` removes old coco images: dangling (`<none>`) layers left behind by prior builds (identified via the `coco.hash` label, since dangling images have no repository to match by name) and any `coco:<version>` tag older than the current `VERSION`. It never removes the current `coco:latest` / `coco:<VERSION>` image, never touches non-coco images, and never force-removes (an image still referenced by a container is skipped and reported, not force-deleted). It lists what will be removed and asks for confirmation first.

## Releasing

`bin/release` cuts a release from the `VERSION` file: bump `VERSION`, then run it.

```bash
echo "0.2.0" > VERSION
bin/release           # commits VERSION (refuses if anything else is dirty), tags v0.2.0, pushes both
bin/release --dry-run  # preview the commands without running them
bin/release --force    # skip the "VERSION must be newer than the highest existing tag" guard
```

No-ops if `v<VERSION>` is already tagged. Refuses on a detached HEAD or if `VERSION` isn't a newer semver than the highest existing `vX.Y.Z` tag (typo/regression guard).

## Shell

bash, with git completion, colored prompt & current git branch.

## Vim

A reasonable default configuration: syntax highlighting, line numbers, incremental search.

## Environment variables

`UID`, `GID`, `TZ`, and optionally `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `XDEBUG_ENABLE`.

## Safety check

When starting a coding agent for the first time in a project, its normal first-run trust/consent prompt still applies (e.g. Claude Code's "Yes, I trust this folder"). The per-project mount path (see above) ensures this triggers correctly per project instead of being suppressed by a shared/identical path.

## License

MIT — see [LICENSE](LICENSE).
