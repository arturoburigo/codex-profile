# Onboarding

Setting this up on a new machine, or adding a second account on one that
already has Codex configured.

## 1. Clone and install

```bash
git clone https://github.com/arturoburigo/codex-profile.git ~/workspace/codex-profile
cd ~/workspace/codex-profile
./install.sh
exec $SHELL
```

`profiles.d/` is gitignored, so a fresh clone has no profiles. `install.sh`
seeds a single `personal.conf` pointing at `~/.codex` — the account you already
use — so nothing changes about how you work until you add a second one.

At this point `codex` still opens the same account it always did, now with the
shared status line applied and a banner on top.

## 2. Add a second account

Ask the `new-profile` skill inside Codex:

> create a new Codex profile for work

It interviews you (name, command letter, emoji, color, theme), writes
`profiles.d/work.conf` and re-runs `install.sh`.

By hand instead:

```bash
cp profiles.d/personal.conf.example profiles.d/work.conf
$EDITOR profiles.d/work.conf     # set NAME, COMMAND, CODEX_HOME, LABEL, COLOR
./install.sh
exec $SHELL
```

## 3. Log the new account in

A fresh `CODEX_HOME` starts logged out — that is the whole point, and it is
also the one manual step that can't be automated:

```bash
codex w login
```

Verify the two accounts are actually separate:

```bash
codex w login status   # the new account
codex p login status   # the original one
```

## 4. Check what got shared

```bash
ls -l ~/.codex-work/     # config.toml, AGENTS.md, skills → symlinks into ~/.codex
codex doctor             # confirms the title items Codex parsed
```

If `~/.codex-work/config.toml` is a symlink, MCP servers and skills are shared.
If it is a real file, the mirroring step didn't run — re-run `./install.sh`.

## Undoing it

```bash
# remove the generated shell function
$EDITOR ~/.zshrc     # delete the block between the codex-profile markers

# restore any file install.sh replaced
ls ~/.codex/*.bak.*
```

Profile directories other than `~/.codex` are safe to delete outright — they
only contain that account's own credentials and history.
