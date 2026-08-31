---
name: new-profile
description: Interactively creates a new Codex account profile — asks for a name, a short command, an optional emoji, an optional hex color and an optional theme, then generates profiles.d/<name>.conf and re-runs install.sh. Trigger on requests like "create a new Codex profile", "add another Codex account", "guide me through setting up a profile", "I need a second account configured" — in any language, since intent matters more than exact wording.
---

# Create a new Codex account profile

This repo supports multiple named account profiles (e.g. `codex w`, `codex p`),
each backed by its own `CODEX_HOME` — which is what isolates `auth.json`,
history and sessions — while `config.toml`, `AGENTS.md` and `skills/` stay
shared across all of them. Adding a profile is a short interview.

## Interview

Ask ONE question at a time, in this exact order. Don't move to the next
question until the current one is answered.

### 1. Profile name
"What name do you want for this account?"
- Normalize: lowercase, spaces become hyphens.
- Reject if `profiles.d/<name>.conf` already exists — ask for a different name.

### 2. Command
"What short command should open this account? (`codex <that>`)"
- If they have no preference, suggest the first letter of the name.
- Recommend a single letter, and reject anything that collides with a real
  `codex` subcommand (`exec`, `review`, `login`, `logout`, `mcp`, `plugin`,
  `app`, `apply`, `resume`, `fork`, `cloud`, `doctor`, `debug`, `sandbox`,
  `update`, `completion`, `queue`, `archive`, `delete`, `unarchive`,
  `features`, `agents`, `help`) — the shell function dispatches on `$1`, so a
  colliding name would shadow that subcommand.

### 3. Emoji (optional)
"Want an emoji to identify this account on the launch banner? You can skip this."
- If skipped, the label is just the plain name.

### 4. Color (optional)
"Want to give this account a specific hex color, or should I pick one that's
not already in use?"
- Accept the hex with or without a leading `#`.
- If they have no preference, pick the next unused color from the default
  palette below.

Default palette, in order — skip any hex already used by another profile:
`FF8700`, `005FD7`, `00AF5F`, `D75FD7`, `5FD7FF`, `D70000`.

### 5. Theme (optional)
"Want a different Codex syntax theme for this account? It's the strongest
visual cue, since the status line itself can't show the profile."
- Offer to leave it empty to inherit the shared theme from `config.toml`.

## After collecting the answers

1. Write `profiles.d/<name>.conf`:
   ```bash
   PROFILE_NAME="<name>"
   PROFILE_COMMAND="<command>"
   PROFILE_CODEX_HOME="$HOME/.codex-<name>"
   PROFILE_LABEL="<emoji> <Name>"   # or just "<Name>" if no emoji was given
   PROFILE_COLOR="<hex, no leading #>"
   PROFILE_IS_DEFAULT=false
   PROFILE_THEME="<theme or empty>"
   PROFILE_EXTRA_CODEX_FLAGS=""
   ```
2. Run `install.sh` from the repo root.
3. Tell them to open a new shell, then run `codex <command>` and
   `codex <command> login` — a fresh `CODEX_HOME` starts logged out, so the
   new profile needs its own login before it can be used.

Never set `PROFILE_IS_DEFAULT=true` on a new profile without the user
explicitly asking to change which account plain `codex` (no argument) opens —
that reassignment affects their existing default account.
