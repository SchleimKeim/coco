# 🥥 coco

Secure your coding environment with this **co**ding **co**ntainer suite – 🥥 **coco** – that mounts `pwd` at same absolute path in-container, with a lot of tools and coding agents. The current base container is **AlmaLinux 10** with the following coding agents installed: **Claude Code, Codex, Copilot, Cursor, Gemini**.

## Requirements

Docker or compatible CLI (Podman aliased ok).

## Install

```bash
$ git clone https://github.com/mmdevl/coco.git ~/coco
$ ~/coco/bin/coco --install   # adds ~/coco/bin to PATH
```

## Usage

```bash
$ cd ~/test-project
$ coco                        # build (cached) + shell
Add .coco/ to .gitignore? [Y/n]
(up/down move, space toggle, enter confirm)
> [x] claude
  [ ] codex
  ...

coco@🥥:~/test-project$ claude
```

## Persistent data

```bash
# global, depeding on the selected coding agent
~/.claude ~/.codex ~/.config/gh-copilot ~/.cursor ~/.gemini
# per project
pwd/.coco/{cache/pip,cache/npm,cache/composer,bash_history,vim}
```
## Config

Per project: `.coco/config`.

## License

MIT — see [LICENSE](LICENSE).

---

[Read more](README-MORE.md) about 🥥 **coco**.
