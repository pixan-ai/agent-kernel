# Architecture

## Components

| Piece | Role | Source |
|---|---|---|
| Claude Code (pinned by `CLAUDE_CODE_VERSION`) | The agent harness | Anthropic, official installer |
| `telegram@claude-plugins-official` | Channel: pushes messages into the session, exposes `reply`, `react`, `edit_message`, `download_attachment` | Anthropic, Apache-2.0 |
| `script` | Provides the pty that interactive Claude needs | util-linux |
| `bin/start.sh` | Seeds config, writes the allowlist, pre-accepts onboarding, starts claude | this repo |
| `policy/managed-settings.json`, `policy/CLAUDE.md` | Permissions, hooks, channel enablement; what the agent is told about its limits | this repo |
| `bin/*` | Scheduled jobs, the daily memory, the opt-in sleep, backups, the peer view, the install lock, the watchdog | this repo ([README](../README.md#repository-layout)) |
| Supercronic | The clock for scheduled jobs | aptible, pinned by checksum |

## Why interactive mode in a pty

Channel events are delivered to a live interactive session. In `-p` mode an idle process does not start a turn when an event arrives. The smallest thing that gives Claude a terminal without a person is a pty, and `script` is already in the base image. `tail -f /dev/null` keeps stdin open.

## State

One volume at `/data`:

- `/data/config`: Claude config, plugin, transcripts, Telegram `access.json`
- `/data/workspace`: the agent's working directory: its own `CLAUDE.md`, `MEMORY.md`, daily memory files, what it makes
- `/data/settings`, `/data/cron`: settings and scheduled jobs, changed only through `config.sh`
- `/data/tools`, `/data/bin`, `/data/tools.json`: what the owner or a super-user had installed, and the record of it
- `/data/ssh`: private keys (peer view, backup storage), mode 600
- `/data/tui.log`: raw screen log (read it with `bin/screen.sh`)

## Failure handling

- `claude` exits: the container exits with status 1 and restarts.
- Credential error: the `StopFailure` hook sends a Telegram alert to the owner.
- A message unanswered after ten minutes, a plan limit past 80%, or the Telegram plugin gone while Claude runs: `watchdog.sh` tells the owner (and restarts Claude for the plugin).
- Down for more than five minutes: the next start tells the owner from when to when. Anything else: `bin/screen.sh`.

## Permission profiles

Claude Code offers three, with no code: strict (`dontAsk`), human in the loop (manual mode, answered with the plugin's Telegram buttons) and automatic (the classifier). This project runs automatic, and the policy's `denyInsteadOfPrompting` turns any remaining prompt into a refusal, so an agent nobody watches never waits. Human in the loop needs that setting removed from the policy and a manual mode in `CLAUDE_FLAGS`.
