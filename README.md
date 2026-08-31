# codex-profile

Multi-account profile switching, a shared status line, and onboarding for the
[Codex CLI](https://github.com/openai/codex) — the Codex counterpart of
[claude-profiles](https://github.com/arturoburigo/claude-profiles).

```bash
codex p   # 👤 Personal
codex w   # 🏢 Work
codex     # whichever profile is marked default
```

## How it works

Everything rests on one lever: **`CODEX_HOME`**. Codex resolves all account
state relative to it, so pointing it at a different directory switches
accounts atomically.

```
CODEX_HOME=/tmp/empty codex login status  →  Not logged in
codex login status                        →  Logged in using ChatGPT
```

`install.sh` reads `profiles.d/*.conf` and regenerates a `codex()` shell
function in `~/.zshrc` and `~/.bashrc` that dispatches on the first argument.

## What is per-profile and what is shared

| | |
|---|---|
| **Per-profile** | `auth.json`, `history.jsonl`, `sessions/`, `logs_*.sqlite`, caches — isolated by `CODEX_HOME` |
| **Shared** | `config.toml` (MCP servers, hooks, model), `AGENTS.md`, `skills/` — symlinked from the base profile |
| **Per-profile override** | the syntax theme, applied as `-c tui.theme=…` at launch |

Sharing `config.toml` is what keeps MCP servers and skills identical across
accounts. It is symlinked rather than copied, which works because Codex writes
*through* the symlink instead of replacing it — verified with `codex mcp add`.

**One consequence worth knowing:** `config.toml` also holds the `[projects]`
trust levels Codex writes as you work, so a directory you trust in one profile
is trusted in all of them.

## The status line

Codex renders its status line from a **fixed catalog of built-in items**. There
is no free-text item and no shell-command item, so — unlike Claude Code, whose
statusline is an external program fed JSON on stdin — segments cannot be
computed. `shared/statusline.toml` picks the closest catalog items:

| Claude Code statusline segment | Codex item |
|---|---|
| `📁repo` | `project-name` |
| `branch` | `git-branch` |
| `*` dirty / `↑2↓1` ahead-behind | `branch-changes` (committed diff vs. default branch) |
| — | `pull-request-number` |
| `model · 🧠effort` | `model-with-reasoning` |
| — | `fast-mode` |
| `████░░░░ 40%` context bar | `context-remaining` (percentage only) |
| `limit 40% resets in 2h10m` | `five-hour-limit`, `weekly-limit` |
| `$0.42` session cost | `used-tokens` (`estimated-thread-cost` is Enterprise-only) |
| — | `permissions` |
| **profile label + color** | **no equivalent — see below** |
| vim mode, session duration, `+lines/-lines`, transcript file | no equivalent |

### Full catalog

`project-name`, `current-dir`, `run-state`, `activity`, `app-name`,
`thread-title`, `thread-id`, `git-branch`, `branch-changes`,
`pull-request-number`, `hostname`, `context-remaining`, `context-used`,
`context-window-size`, `five-hour-limit`, `weekly-limit`, `codex-version`,
`used-tokens`, `total-input-tokens`, `total-output-tokens`, `thread-credits`,
`estimated-thread-cost`, `model`, `model-with-reasoning`, `fast-mode`,
`task-progress`, `permissions`, `approval-mode`, `raw-output`,
`workspace-headline`.

`terminal_title` accepts the same catalog minus the status-line-only items
(`hostname`, `pull-request-number`, `branch-changes`, `permissions`,
`approval-mode`, `context-window-size`, `raw-output`, `workspace-headline`).
`codex doctor` validates whatever you put in `terminal_title` and prints the
normalized list.

You can also edit both interactively with `/statusline` inside Codex — but
`install.sh` rewrites them from `shared/statusline.toml` on its next run.

### The profile badge

Because no catalog item renders free text, the profile's label and color can't
live in the status line. Two stand-ins:

- a one-line **launch banner** in the profile color, printed by the shell
  function (only when stdout is a terminal, so it never pollutes a pipe);
- a per-profile **syntax theme** via `PROFILE_THEME`, which is the cue you
  actually notice while working.

## Install

```bash
git clone https://github.com/arturoburigo/codex-profile.git
cd codex-profile
./install.sh
exec $SHELL
```

Requires `awk` (and `git` for the clone above). See [ONBOARDING.md](ONBOARDING.md) for adding a
second account.

## Adding a profile

Ask the bundled `new-profile` skill ("create a new Codex profile") and it runs
the interview for you, or write `profiles.d/<name>.conf` by hand from
[`profiles.d/personal.conf.example`](profiles.d/personal.conf.example) and
re-run `./install.sh`.

## Safety

Every step is idempotent, and anything real that gets replaced is backed up
next to itself as `*.bak.<timestamp>` first — including `config.toml` and your
shell rc files.
