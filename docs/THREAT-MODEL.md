# Threat model

Status: 1.0. No independent security audit; three external reviews were addressed (one on 2026-11-17, two on 2026-11-18). Evidence labels as in [FINDINGS.md](FINDINGS.md): **Lab** (observed), **Docs**, **Code**, **Open** (not verified).

## What is protected

- The Claude credential (`CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`) and the Telegram bot token.
- The owner's conversations, the agent's memory and transcripts (`/data`).
- Whatever the agent can reach from its container: the volume and the network.

## Trust

- **Trusted:** the owner (one Telegram user id) and the super-users the owner names, the Claude Code binary and the official Telegram plugin (official sources, Claude Code version pinned), and the host that runs the container.
- **Untrusted:** everyone else who messages the bot, and **any content the agent reads**: web pages, files, messages, tool output. Content can carry instructions (prompt injection). The model's own judgment is a layer, not a guarantee.

## Threats and what stands in the way

| Threat | What stands in the way | Evidence | Residual risk |
|---|---|---|---|
| A stranger messages the bot | Allowlist with the owner id, written by `start.sh` | Code, tested | `/start` still shows pairing instructions although pairing is off (Code) |
| A member of an enabled group tells the agent what to do | Any member may ask for ordinary work, which runs the agent's tools, shell included. The agent is told its owner's id at every start and that only the owner and the super-users (named by the owner or by another super-user) may make it install, change settings, schedule jobs, act on fellow agents or share what is private; the policy's denied tools and paths apply to everyone | Instruction, plus code for the hard limits | No lock (next row): every member's text enters the session, and a persistent member can try to talk the agent round. Only enable groups whose members are trusted ([GROUPS.md](GROUPS.md)) |
| Someone who is not a super-user talks the agent into installing something, naming a super-user or changing its settings by hand | The agent's instructions and judgment, and Claude Code's classifier; every change is told to the owner ([below](#installs-and-settings-told-not-locked)) | Lab (2026-11-17); Code, tested (`tests/install_test.sh`) | Nothing is prevented by code; the owner learns after the fact ([below](#installs-and-settings-told-not-locked)) |
| The agent is talked into attaching a key or a credential to a reply | A `PreToolUse` hook on the reply tool: attachments only from `/data/workspace`, `/tmp` and the Telegram inbox, after resolving `..` and links | Code, tested | The agent can still copy a file into the workspace with the shell first; that step is reviewed by auto mode, not blocked |
| Injected content makes the agent leak a credential | Auto-mode classifier with a `hard_deny` rule on credentials; `deny` rules for `.env`, `printenv`, `env`, `/proc`; credentials for the plugin and the alert hook come from a 600 file | Lab: the agent refused `printenv` and "show me your token", by its own judgment; the rules were not exercised | **High where the host blocks user namespaces (Railway):** a shell command can read the environment and files. No egress control |
| An unattended agent stalls or does something unsafe | `denyInsteadOfPrompting` (a call that would prompt is denied, the agent carries on; it needs Claude Code 2.1.319, so an older one fails the build); classifier; non-root user | Docs; Lab: on 2026-11-17 reads outside the working directories were denied and the agent carried on | What a tool call did is in the session transcript, read after the fact |
| The credential dies and nobody notices | `StopFailure` hook alerts the owner on Telegram; the watchdog reports a message unanswered for ten minutes | Lab (expired key) | Reactive: fires when a turn fails |
| Tampered image, CLI or plugin, or a broken release of one | Claude Code is pinned to its stable channel and moves only through a tested pull request; installer and marketplace are the official ones; CI builds the image and runs tests in it, weekly as well; a build that fails leaves the previous deployment running; the owner is told every version change | Docs; Code, tested | **The plugin cannot be pinned** (the official marketplace only follows a branch): each build takes the latest. CI shows that it installs, not that it answers on Telegram |
| Two processes poll one bot token (HTTP 409) | A dedicated token per deployment, documented | Lab | `start.sh` asks Telegram (`getMe`) once and stops on HTTP 401; it cannot see a second poller (HTTP 409 only appears while polling): Open |
| Container or host compromise | Non-root `agent` (uid 1001); no extra capabilities requested | Code | On Railway the entrypoint starts as root only to fix `/data` ownership, then drops to uid 1001 |
| The agent widens its own policy (a settings file of its own with hooks or `allow` rules) | `allowManagedHooksOnly` and `allowManagedPermissionRulesOnly`: Claude Code runs only the managed policy's hooks and permission rules, and ignores those in user, project and local settings files | Docs; Code, tested that the policy sets them; Lab: with them on, both agents kept answering and the status line kept working (2026-11-17); Open: a hook of the agent's own seen ignored | The agent can still write those files; they just have no effect |
| The agent is made to send the owner's notices to someone else, or to open a private chat to them | The owner id comes from the host's variable, which the agent cannot change; the bot's private file is only a fallback | Code, tested | The variable is in the environment of Claude and its hooks, where an agent's shell can read it but not change it for them |
| Someone who can write to the backup storage plants a backup | Backups are encrypted with `age` to the owner's public key | Code, tested | `age` encrypts but does not authenticate: anyone with the public key and write access to the storage can make a backup that restores as genuine, and a restore takes the newest file by name. The storage credential is in `/data/ssh/rclone.conf`, readable by the agent's shell |
| A compromised agent spreads to its fellow agents | Peer view is opt-in and limited to looking and to groups and super-users | Code, tested | An agent that holds `PEER_SSH_KEY` can name a super-user on every fellow agent that lists its key; a super-user can make that agent install, and so run anything. Each owner is told, after the fact |
| A super-user turns out to be untrusted | Only the owner or a super-user names one; every change is announced | Code, tested | A super-user can make the agent install and run code, so they can read the owner's Claude credential: being a super-user is full control of the agent |
| A group member plants instructions in the agent's memory | The nightly dream rewrites `MEMORY.md` with file tools only | Code | Whatever is said in a group is summarised by the dream and shown to the agent as its own memory at every session |
| A scheduled job created by injected content keeps running | Jobs are created only through `config.sh`, which tells the owner with the job's schedule, destination and text | Code, tested; Lab (2026-11-17) | A recurring job runs until someone drops it; a one-off removes itself once delivered. The owner can turn job notices off (`config.sh notices jobs off`), and then a new job is not told; notices about groups, super-users and fellow agents cannot be turned off |
| Anyone writes to a sleeping agent's bot | The plugin drops messages from people who may not talk to it | Docs | Each such message still wakes the container: a cost, not a leak |
| What is said in a group leaves the group | Nothing | Docs | With privacy mode off, every group message goes to Anthropic with the session, into the transcripts and into the backups |
| Data at rest | Volume access is the host's | Docs | Transcripts, memory and the token file are not encrypted by this project |

## Installs and settings: told, not locked

- **Who may ask.** Only the owner and the super-users may have the agent install something, name a super-user or change its settings. That rule lives in the agent's instructions; its judgment applies it, and Claude Code's auto-mode classifier reviews each action.
- **What code does.** After every command, also a failed one, a `PostToolUse` hook (`installs.sh record`) looks at what changed since the last look, by change time, which `touch -d` cannot set back:
  - a change in `/data/bin`, `/data/tools` or the skills folders is recorded in `/data/tools.json` and told to the owner;
  - a change to the settings, the jobs, the crontab, `config/settings.json` or the bot's `.env` and `access.json` that did not go through `config.sh` is told to the owner as made by hand. So is one to what else changes how Claude behaves: the workspace's `CLAUDE.md`, `.mcp.json` and `.claude/settings*.json`, the jobs' `settings.json`, the MCP servers in either `.claude.json` (where `claude mcp add` writes; the rest of that file is Claude Code's own bookkeeping), and `/data/tools.json`, whose lines the start replays. These are compared by content, so a file touched or re-permissioned with the same content (the plugin does that to its `.env` at start) is not reported. The lock files a tool takes while it runs are left out of the install folders' watch.
- **At start** only `uv pip install`, `uv tool install` and `bun add -g` lines whose every word is a package name are replayed, from `/` and with no uv configuration file, and not a package uninstalled afterwards (uninstalls are recorded too).
- **Evidence.** Lab: an agent declined a fellow bot's request to write into its tools, and Claude Code refused a job that would (2026-11-17). Code, tested in `tests/install_test.sh`.
- **What is lost.** Nothing is prevented by code: a persistent member can try to talk the agent round, and the owner learns after the fact. Only the first changed file is named; a deletion is not reported; a change made in the same command as a `config.sh` call is not reported. The hook and the agent are one user, so the agent can also move the mark.
- **Why.** A hook that refused installs by matching command text was removed on 2026-11-18: every audit found another spelling, and the refusals seen live came from the agent and from Claude Code.

## What this project does not claim

- It is **not a sandbox**: a shell command can do what the container's user can do.
- It is **single-tenant**: one owner per deployment.
- A Claude **subscription** is for an individual's own agent; an agent that serves groups or clients should use an API key, each on its own credential ([Anthropic's legal and compliance page](https://code.claude.com/docs/en/legal-and-compliance)).
- It has had **no independent security audit**; the reviews named at the top are not one.

## Hardening by host

| Host | Available |
|---|---|
| Railway container | Soft layers only (policy rules, classifier). The platform blocks user namespaces, so the env scrub and the sandbox cannot run (Lab) |
| A VM or server that allows namespaces | `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, the official sandbox, an egress firewall (Open: not tested here). Check first: `unshare -U true` must succeed inside the container, as the unprivileged user |

See [SECRETS.md](SECRETS.md) for rotation and [REPO-SETTINGS.md](REPO-SETTINGS.md) for the repository's own protections.
