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

The repo ships no personal configuration, so `install.sh` seeds the minimum
that makes `codex` work: one profile pointing at `~/.codex` — the account you
already use — and `shared/AGENTS.md` from its template. If you already had an
`~/.codex/AGENTS.md`, it is left untouched and the repo simply doesn't manage
it.

At this point `codex` opens the same account it always did, now with the
shared status line and a banner on top. This step also links `shared/skills/`
into `~/.codex/skills`, which is what makes the next step possible.

## 2. Let the interview configure it

Open Codex and run:

```
/setup
```

It asks how many accounts you want, what each is named, which one plain
`codex` should open, and what the accounts should share — then writes
`profiles.d/*.conf` and `share.conf` and re-runs `install.sh` for you.

Prefer to do it by hand:

```bash
cp profiles.d/personal.conf.example profiles.d/work.conf
$EDITOR profiles.d/work.conf     # set NAME, COMMAND, CODEX_HOME, LABEL, COLOR
cp share.conf.example share.conf # optional: opt out of sharing something
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
