# Code manual

How every piece of agent-kernel works: each script in `bin/`, step by step, and each file of the policy. Read it next to the code; the scripts' own comments say why each line is there. For the big picture first, see [ARCHITECTURE.md](ARCHITECTURE.md); for what is protected and what is not, [THREAT-MODEL.md](THREAT-MODEL.md).

## The budget

The scripts in `bin/` are the only code the project writes. Their lines of code (comments and blank lines not counted) are held to **247** by `tests/docs_test.sh`, which also checks that this table is right:

| Script | Lines | Role |
|---|---|---|
| `bin/start.sh` | 52 | Starts the agent and keeps it running |
| `bin/installs.sh` | 40 | Records installs and hand changes, tells the owner, reinstalls at start |
| `bin/config.sh` | 32 | Settings the agent changes when asked |
| `bin/doorbell.sh` | 26 | Sleep: waits for Telegram to announce a message |
| `bin/peer.sh` | 24 | What fellow agents may do over SSH |
| `bin/dream.sh` | 20 | The daily memory |
| `bin/job.sh` | 14 | Runs one scheduled job |
| `bin/backup.sh` | 13 | Encrypted backup and restore |
| `bin/unsent.sh` | 10 | Makes sure the owner's private message gets an answer |
| `bin/watchdog.sh` | 10 | Three checks every five minutes |
| `bin/notify.sh` | 5 | Sends one Telegram message |
| `bin/screen.sh` | 1 | Shows the agent's screen as text |

Two files in `bin/` are not Bash and are not counted: `bin/system.cron` (three schedule lines) and `bin/doorbell.js` (a 12-line listener run by Bun while the agent sleeps). Both are explained below.

Everything else is official: Claude Code, its Telegram plugin, and standard tools (`script`, `jq`, `curl`, `supercronic`, `rclone`, `age`, `sshd`).

## How the pieces fit

```
host starts the container ─► tini ─► start.sh (root) ─► start.sh (uid 1001)
                                         │
     checks credentials, prepares /data, applies settings, starts supercronic and the heartbeat
                                         │
                      loop: dream.sh ─► [asleep: doorbell.sh] ─► claude in `script` ─► (exits) ─► loop or exit
                                         │
   Claude Code reads the managed policy: its hooks call unsent.sh, installs.sh, notify.sh; the agent runs config.sh, peer.sh
   supercronic runs system.cron and the agent's jobs: watchdog.sh, backup.sh, job.sh, and the 4:00 recycle
```

## The scripts

### `bin/start.sh`

The container's main process (after `tini`). It runs twice: first as root, then as the agent's user.

1. **Check the credentials, before anything else.** The bot token and the owner id must be set. Spaces and line breaks around them and around `CLAUDE_KEY` are trimmed (`trim`). `CLAUDE_KEY` is read by its prefix: `sk-ant-oat` becomes `CLAUDE_CODE_OAUTH_TOKEN`, `sk-ant-api` becomes `ANTHROPIC_API_KEY`; anything else stops the start. The owner id must be a number and the bot token must have the token's shape. Without a Claude credential the start stops: Claude would sit on a login screen nobody sees.
2. **As root, only what needs root.** Hosts mount volumes owned by root, so `/data` and `/data/workspace` are given to uid 1001 (`chown -h`: no symlink followed). Then `setpriv` drops to uid 1001 for good (`--no-new-privs`) and runs the script again. While root, `PATH` is the system's only, so nothing the agent can write is ever run as root.
3. **Check `/data` can be written**, and log the length and prefix of the subscription token (never the token).
4. **Private keys to `/data/ssh`**, mode 600: the backup storage credentials and the key for looking at fellow agents.
5. **Restore** the newest backup if the volume is empty and a backup key is set.
6. **Prepare Claude's configuration** on the volume: copy the seed from the image without overwriting, and copy the Telegram plugin fresh from the image at every start (its registry files carry the build path, rewritten to the volume).
7. **Settings and access:** on the first start only, seed `/data/settings` with the groups in `TELEGRAM_GROUP_IDS`; write the plugin's private `.env` (bot token and owner); run `config.sh apply`, which builds the plugin's access list and the crontab.
8. **Tell the owner** when Claude Code or the plugin changed version since the last start, and when `/data` is not a volume.
9. **Ask Telegram once** (`getMe`): a clear 401 stops the start, since a revoked token would leave the bot mute. The token goes through stdin, so it never shows in a process list. The answer also gives the agent its own bot name.
10. **Remove the secrets from the environment** Claude will inherit: the bot token, the backup keys, the peer key.
11. **Pre-accept** onboarding, the API key and trust for the workspace in `.claude.json`: nobody is at the screen to click.
12. **Optional pieces:** the screen mirror to the log (`SCREEN_MIRROR`), the SSH server for fellow agents (`PEER_PUBLIC_KEYS`), trimming the record of job deliveries to 500.
13. **Jobs and heartbeat:** if the last heartbeat is older than five minutes, tell the owner which time was missed; then start the heartbeat (`/data/cron/alive`, every 30 seconds), `supercronic`, and `installs.sh replay` in the background.
14. **The loop.** Each turn: `dream.sh` (once a day); if asleep, `doorbell.sh` waits for a message; then Claude starts in `script` (the terminal), continuing the last conversation unless the dream started a new one, with the Telegram channel. With sleep on, a background check stops Claude after `IDLE_SLEEP_MINUTES` without new conversation, and the loop goes round. Without sleep, when Claude exits, the script exits and the host restarts the container. A Claude that dies within a minute makes the next start open a fresh conversation and wait a minute, so a broken session does not loop.

Tests: `tests/start_test.sh`, `tests/sleep_test.sh`.

### `bin/unsent.sh`

Makes sure a private message from the owner always gets an answer on Telegram. Three hooks call it:

- `in` (a message arrives): if the prompt's first line is the plugin's tag for the owner's private chat, it sets a mark. Groups are not marked.
- `out` (a Telegram tool sent something): it clears the mark.
- `stop` (the turn ends) with the mark still there: the first time, it sends Claude back with "send it with the reply tool"; if the turn ends again without sending, it sends the owner what Claude wrote the first time.

A job or the dream, which run with their own configuration directory, are never held back. Test: `tests/unsent_test.sh`.

### `bin/watchdog.sh`

Run every five minutes by `supercronic`. It only observes, tells the owner and restarts; it never types into the session.

1. A message that came in more than ten minutes ago and whose turn has not ended: tell the owner once.
2. The plan's limits, from the figures the status line keeps: tell the owner once when one passes 80%.
3. Claude running but the Telegram plugin's process gone, seen twice in a row: tell the owner and restart Claude.

Test: `tests/cron_test.sh`.

### `bin/notify.sh`

Sends one Telegram message, to the owner or to a given chat. The token comes from the plugin's private file and goes to `curl` through stdin; the owner comes from the host's variable when there is one, because the file can be written from the agent's shell and the variable cannot.

### `bin/config.sh`

The settings the agent changes when asked: groups, super-users, fellow agents, jobs and the job notices. One change at a time (a lock).

- **Validates** each value: ids are numbers, names are letters, digits, `-` and `_`, a job's schedule must be one that can happen (checked with `supercronic -test`), and a job can only deliver to the owner or a group the agent is in.
- **Writes** `/data/settings` and `/data/cron/jobs` through temporary files.
- **Rebuilds the crontab** from the image's jobs plus the agent's, keeping only well-formed `job.sh` lines: anything else written into the file never runs.
- **Rebuilds the plugin's access list**: the owner in private plus every listed group, open to all its members.
- **Tells the owner** of every change ("⚙️ Setting changed", marked when a fellow agent made it), except job notices if the owner turned them off.

The owner, tokens and keys cannot be set here. Test: `tests/config_test.sh`.

### `bin/job.sh`

Runs one scheduled job: a separate, one-shot Claude (`claude -p`) with its own configuration directory, so a second Telegram plugin never starts. It writes only the message; the script delivers it with `notify.sh`, to the owner or the job's group if the agent is still in it, records it in `sent.jsonl` (the main agent is shown its recent deliveries), and removes a one-off job once delivered. A failure or timeout is told to the owner. Test: `tests/cron_test.sh`.

### `bin/dream.sh`

The daily memory. At most once every 20 hours, and only if something was said: a separate Claude with file tools only reads the conversations since the last dream (messages and replies, no tool results) and rewrites `MEMORY.md` and a daily file. The dream counts as done only if the daily file was written; then the next start opens a clean conversation. A failure changes nothing, and is told once a day. Test: `tests/dream_test.sh`.

### `bin/doorbell.sh` and `bin/doorbell.js`

Sleep (opt-in). `doorbell.sh` runs while Claude is stopped:

1. Needs a public address, or it cannot sleep: it says why on Telegram, once per start.
2. Makes a backup if the last one is older than 20 hours (a suspended container runs no nightly backup).
3. Registers a Telegram webhook to this service, with a secret.
4. With scheduled jobs, keeps the container awake with one request every four minutes, so the jobs still run.
5. Starts `doorbell.js` (Bun) and checks once, through the public address, that its own listener answers, using a code made new for each sleep; otherwise it removes the webhook and stays awake.
6. Without jobs, watches the clock: if 30 minutes pass without the jump a suspension leaves, the host is not suspending it (Serverless is off), and the owner is told.
7. When a message is waiting, removes the webhook and returns, so `start.sh` starts Claude, and the plugin collects the message.

`doorbell.js` answers Telegram's call that carries the secret with 503, so Telegram keeps the message for the plugin, and exits; anything else gets 403 with the sleep's code. Test: `tests/sleep_test.sh`.

### `bin/peer.sh`

What fellow agents may do (opt-in):

- `serve`: an SSH server on port 2222 that accepts only the listed public keys and runs one fixed command per connection (`ForceCommand`): no shell, no terminal, no forwarding.
- `look HOST [WHAT]`: look at a fellow agent, by address or by a name the agent was told.
- For each connection: `screen`, `status`, `transcript` (the last 40 messages), or `group|admin|drop ID`, which go through the other agent's own `config.sh`, so its owner is told. Anything else is refused.

Test: `tests/peer_test.sh`.

### `bin/installs.sh`

Keeps the record of what the agent installs, and tells the owner; who may ask for an install is the agent's judgment under its instructions.

- `record` (after every command or file edit): a change in the install folders is recorded in `/data/tools.json` and told ("🧰 Installed"); an uninstall is read from the command; a change made by hand, not through `config.sh`, to the settings, jobs, the bot's files, the workspace's Claude settings or MCP servers is told too.
- `replay` (at start): makes the Python environment and reinstalls the recorded packages, only commands whose every word is a package name, and not those uninstalled later.
- `mark` (from `config.sh`): its own change was told, so take the state as it is now.

Test: `tests/install_test.sh`.

### `bin/backup.sh`

Opt-in. Packs `/data` (without what each start rebuilds, and without keys), encrypts it with `age` inside the container, and sends it with `rclone` to the owner's storage; keeps 14 days. `restore` brings the newest back. A failure is told to the owner. Test: `tests/backup_test.sh`.

### `bin/screen.sh`

One line: turns the terminal recording in `/data/tui.log` into readable text and prints its last lines. Used by the screen mirror, `peer.sh screen` and the owner on a server. Test: `tests/tools_test.sh`.

### `bin/system.cron`

The jobs every agent runs, from the image: the 4:00 recycle (Claude restarts, dreams and starts clean), `watchdog.sh` every five minutes, and the 3:30 backup. `config.sh` appends the agent's own jobs below them.

## Host configuration for a fleet

`host/launchpad/` is optional and runs on the owner's Linux server, not in the agent: it lets a supervisor agent start new agents (see [FLEET.md](FLEET.md)). It is configuration for standard tools (OpenSSH, sudo, systemd, Docker Compose) plus one small wrapper, held to **100 lines** by `tests/launchpad_test.sh`, counted apart from `bin/`.

### `host/launchpad/agent-launchpad-start`

The only command the supervisor's key may run. The requested name arrives in `SSH_ORIGINAL_COMMAND`; it is treated as data: only lowercase letters, digits and `-`, starting with a letter, 2 to 31 characters. Then it asks `sudo` to start exactly `agent-launchpad@NAME.service`.

### `host/launchpad/sudoers`

The second fence: the `launchpad` user may run `systemctl start` on a well-formed `agent-launchpad@NAME.service`, with an anchored regular expression, and nothing else: not stop, restart, another unit or several units.

### `host/launchpad/sshd_config.conf` and `host/launchpad/authorized_keys`

The `launchpad` user's keys are in a root-owned file it cannot change. The one key, the supervisor's, is accepted only from Docker's networks (`from=`), with no terminal or forwarding (`restrict`), and only to run the wrapper (`command=`).

### `host/launchpad/agent-launchpad@.service`

The systemd template that starts agent NAME. `AssertPathExists` makes the start fail when the agent's file is missing; a `Condition` would exit 0 and look like a start. Compose interpolates only from root's `fixed.env` (`--env-file`), in a dedicated clone with an empty `.env`: a running agent's folder would give the new agent that agent's `.env`. Stopping keeps the volume.

### `host/launchpad/compose.launchpad.yml`

Added to the repo's `compose.yml` for every fleet agent. The agent's own file, written by the supervisor, gives its bot token; `environment:` wins over it, so the owner, the Claude key, Claude's flags and the fleet's peer keys are always the host's. Each agent joins the fleet network with its name as alias, and gets its own volume from its project name.

### `host/launchpad/fixed.env.example`

What every fleet agent gets from the host: the owner, one Claude key for the fleet, the time zone, and the fleet's peer keys.

### `host/launchpad/supervisor.override.yml`

Copied into the supervisor's folder as `compose.override.yml`: it turns on `ENABLE_SUPERVISOR`, mounts the fleet folder at `/fleet`, and lets the supervisor reach the host's SSH (`host-gateway`). Only the supervisor gets these.

## The policy

`policy/` is copied to `/etc/claude-code/`, owned by root: the agent cannot change it, and Claude Code gives it the highest precedence.

### `policy/managed-settings.json`

- **Permissions.** Anything that would need an approval is denied instead (nobody is at the screen). Allowed without asking: the Telegram tools and reading `/data/tools.json`. Denied: reading `.env` files, the Claude credentials file, the keys in `/data/ssh` and `/proc`; `printenv`, `env` and any shell command naming `/proc/…/environ`; editing the policy, the plugins, the bot's files, the settings and the keys.
- **Hooks:**

| Event | What runs | For |
|---|---|---|
| `SessionStart` | the date, the bot's own name, the memory | the agent knows the time, who it is and what it remembers |
| `UserPromptSubmit` | recent job deliveries; the pending mark; `unsent.sh in` | context, the 10-minute watch, the answer guarantee |
| `PreToolUse` (reply) | a check of attached files | the reply tool can only attach files from the workspace and the inbox |
| `PostToolUse` (file and shell tools) | `installs.sh record` | installs and hand changes are recorded and told |
| `PostToolUse` (Telegram tools) | `unsent.sh out` | an answer was sent |
| `PostToolUseFailure` | `installs.sh record` | a failed command can still have installed something |
| `Stop` | clear the pending mark; `unsent.sh stop` | the turn ended |
| `StopFailure` (credential or billing errors) | `notify.sh` | the owner learns why the agent stopped |

- **Other settings:** only managed hooks and permission rules apply (`allowManagedHooksOnly`, `allowManagedPermissionRulesOnly`); claude.ai connectors are off; channels are on; the advisor model; the auto-mode classifier's extra rule against leaking credentials; and a status line that keeps the plan's figures for the watchdog.

Test: `tests/policy_test.sh`.

### `policy/CLAUDE.md`

The agent's managed instructions, in sections: limits it cannot change (denials, credentials, read-only config, no connectors, only `/data` survives), memory, scheduled jobs, fellow agents (including its own address), settings it changes itself, installing skills and tools, groups (who to answer, the silence rule, talking is not authority, super-users, no bot loops), and how to answer (always with the reply tool, in the writer's language, saying what it checked). Each rule that matters is held by a test in `tests/policy_test.sh`.

### `policy/stack.md`

The optional stack: how the agent installs voice and video tools when asked, pinned by version. CI runs every block of it (`tests/stack_test.sh`).

## Around the scripts

- **`Dockerfile`:** two targets. `base` (published): Bun's Debian image pinned by digest, the tools pinned by version and checksum, the policy and the scripts, `tini` as entrypoint. `agent` (built by each user): adds Claude Code with Anthropic's installer at a pinned version and the Telegram plugin, and loads MCP tools upfront (`ENABLE_TOOL_SEARCH=false`). See [PRODUCT-IMAGE.md](PRODUCT-IMAGE.md).
- **`compose.yml`:** one service, the variables from `.env`, a named volume at `/data`, restart unless stopped, a memory cap.
- **`tests/`:** one acceptance test per script, run inside the image in CI, plus `docs_test.sh` (the docs match the code) and `workflows_test.sh`. See [CONTRIBUTING.md](../CONTRIBUTING.md).
