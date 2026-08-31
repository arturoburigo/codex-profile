---
name: setup
description: First-run setup for a fresh clone of codex-profile — interviews the user about their accounts and what those accounts should share, writes profiles.d/*.conf and share.conf, seeds AGENTS.md, then runs install.sh. Trigger on "set up codex-profile", "configure my Codex profiles", "I just cloned this, what now", "onboard me", or any first-time configuration request, in any language. Use `new-profile` instead when a working setup already exists and only one more account is being added.
---

# Set up codex-profile

The repo ships no personal configuration — a clone has no profiles, no
`AGENTS.md` and no sharing choices. This skill produces all of it from an
interview, so nothing has to be edited by hand.

Run everything from the repo root (the directory containing `install.sh`).

## Before asking anything

Check what is already there, so the interview doesn't ask about a machine that
is already configured:

```bash
ls profiles.d/*.conf 2>/dev/null
ls ~/.codex/AGENTS.md ~/.codex/auth.json 2>/dev/null
codex login status
```

If `profiles.d/*.conf` already exists, say so and ask whether to reconfigure
from scratch or just add one account — the latter is the `new-profile` skill,
not this one.

## Interview

Ask ONE question at a time. Don't move on until the current one is answered.

### 1. How many accounts
"How many Codex accounts do you want to switch between?"
- One account is a valid answer: they still get the status line and the
  banner, just without a second profile.

### 2. For each account, in turn
Ask these together for one account before moving to the next:
- **Name** — lowercase, spaces become hyphens.
- **Command letter** — `codex <letter>`. Suggest the first letter of the name.
  Reject anything colliding with a real `codex` subcommand (`exec`, `review`,
  `login`, `logout`, `mcp`, `plugin`, `app`, `apply`, `resume`, `fork`,
  `cloud`, `doctor`, `debug`, `sandbox`, `update`, `completion`, `queue`,
  `archive`, `delete`, `unarchive`, `features`, `agents`, `help`).
- **Emoji** (optional) — shown on the launch banner.
- **Color** (optional) — hex, with or without `#`. If they don't care, take the
  next unused one from `FF8700`, `005FD7`, `00AF5F`, `D75FD7`, `5FD7FF`,
  `D70000`.
- **Theme** (optional) — the strongest per-profile cue, since the status line
  itself cannot show which account is active. Empty inherits the shared theme.

### 3. Which account is the default
"Which of these should plain `codex` (no argument) open?"
- That one gets `PROFILE_IS_DEFAULT=true` and `PROFILE_CODEX_HOME="$HOME/.codex"`,
  because it inherits the account already logged in on this machine.
- Every other account gets `PROFILE_CODEX_HOME="$HOME/.codex-<name>"`.

### 4. What the accounts share
Ask as one question with four yes/no parts, defaulting to yes:
- **MCP servers, hooks and model** (`config.toml`) — also means project trust
  levels are common: a directory trusted in one account is trusted in all.
- **Skills** (`skills/`)
- **Instructions** (`AGENTS.md`)
- **Conversation history** (`history.jsonl` + `state_*.sqlite`) — the up-arrow
  recall and `codex resume`. Every account sees every conversation. Safe with
  several profiles running at once.

Never shared, and worth saying out loud so nobody expects otherwise:
`auth.json`, `logs_*.sqlite`, `memories_*.sqlite` and caches.

### 5. Instructions file
Check whether `~/.codex/AGENTS.md` already exists as a real file:
- **It exists** — ask whether to keep it as-is (this repo will leave it alone)
  or adopt it (move it to `shared/AGENTS.md` so every profile shares it).
- **It doesn't** — say that `shared/AGENTS.md` will be seeded from
  `shared/AGENTS.md.example`, which they can edit afterwards.

## Writing the answers

1. One `profiles.d/<name>.conf` per account:
   ```bash
   PROFILE_NAME="<name>"
   PROFILE_COMMAND="<letter>"
   PROFILE_CODEX_HOME="$HOME/.codex"        # or $HOME/.codex-<name>
   PROFILE_LABEL="<emoji> <Name>"           # or just "<Name>"
   PROFILE_COLOR="<hex, no leading #>"
   PROFILE_IS_DEFAULT=false                 # true for exactly one
   PROFILE_THEME="<theme or empty>"
   PROFILE_EXTRA_CODEX_FLAGS=""
   ```
2. `share.conf` from the answers to question 4 — write it even when everything
   is `true`, so the choices are recorded rather than implicit.
3. If they chose to adopt an existing `AGENTS.md`, move it before installing:
   `mv ~/.codex/AGENTS.md shared/AGENTS.md`
4. Run `./install.sh` and show its output.

## After installing

Tell them, in this order:
1. `exec $SHELL` — the current shell has no `codex()` function yet.
2. `codex <letter> login` for every account **except** the default one. A fresh
   `CODEX_HOME` starts logged out; this is the one step that can't be
   automated.
3. Verify with `codex <letter> login status` per account — different answers
   per profile is the proof the accounts are actually separate.

Exactly one profile may be the default. If the user asks to change which
account plain `codex` opens later, that reassignment moves which directory is
treated as the base — flag it rather than doing it silently.
