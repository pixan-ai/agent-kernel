# Privacy and data handling

What data an agent handles, where it lives, who else sees it, and how to delete it. agent-kernel is software you run yourself: the project and its maintainers receive none of your data.

## Where the data lives

Everything the agent keeps is on its own volume, `/data`, on the host you chose:

| What | Where |
|---|---|
| Conversations (what was said, what the agent did, tool results) | `/data/config/projects/…/*.jsonl`, Claude Code's own transcripts |
| Memory: the index and one file per day | `/data/workspace/MEMORY.md`, `/data/workspace/memory/` |
| What scheduled jobs sent | `/data/workspace/sent.jsonl` (the last 500) |
| Files people sent and files the agent made | `/data/config/channels/telegram/inbox/`, `/data/workspace/` |
| Settings: groups, super-users, fellow agents, jobs | `/data/settings`, `/data/cron/` |
| What was installed | `/data/tools.json`, `/data/tools/`, `/data/bin/` |
| The screen, as the terminal drew it | `/data/tui.log` (rewritten at every start) |
| Keys: the bot token's copy, the peer key, backup storage credentials | `/data/config/channels/telegram/.env`, `/data/ssh/` (mode 600) |

The host stores the volume: Railway, or your own server's disk.

## Who else sees it

| Who | What | Under whose terms |
|---|---|---|
| **Anthropic** | Everything the model reads: messages, files it opens, tool output, memory shown at start | Your own Claude account: the subscription's or the Console's terms and data policies ([Claude Code data usage](https://code.claude.com/docs/en/data-usage)) |
| **Telegram** | Every message to and from the bot, and files sent through it | Telegram's privacy policy |
| **Your host** | The volume, the logs, the variables (including keys) | Your Railway account, or whoever runs your server |
| **Backup storage**, if you set it up | An encrypted file only your private key opens | Your storage account ([BACKUP.md](BACKUP.md)) |
| **Fellow agents**, if you set up the peer view | Another agent's screen and recent conversation | Your own configuration ([PEERS.md](PEERS.md)) |
| **Members of the agent's groups** | What the agent writes in the group | Telegram |
| **Pixan and this project** | Nothing. The scripts send no telemetry and call no service of ours | — |

The log does not print keys or tokens. It does contain start-up information and, only if you turn on `SCREEN_MIRROR`, copies of the screen, which hold the conversation.

## What a group means for privacy

In a group, the agent reads every message (with Group Privacy off) and everything it reads goes to Anthropic like any other message. Its instructions keep what the owner said in private out of groups, but that is the model's judgment, not a lock. Add the agent only to groups whose members agree to it ([GROUPS.md](GROUPS.md)).

## How long it is kept

- Conversations and memory stay on the volume until you delete them. The nightly dream starts a new conversation each day; the old ones stay on disk.
- `sent.jsonl` keeps its last 500 deliveries; `tui.log` is rewritten at every start.
- Backups are kept 14 days by default (`BACKUP_KEEP_DAYS`).
- What Anthropic and Telegram keep is set by their policies and your account settings.

## Deleting it

- **One conversation or memory:** ask the agent ("forget that …"), or delete the files on the volume.
- **Everything the agent has:** delete its volume. On Railway, delete the volume in the service; on a server, `docker compose down -v`, which cannot be undone.
- **Backups:** delete the files in your storage.
- **Telegram:** delete the chats with the bot; delete the bot in @BotFather.
- **Anthropic:** follow your account's data controls.

## For companies

An agent that serves people other than its owner handles their messages: tell them, and check what your own rules require (consent, retention, where data may be stored). Use a Console API key in the company's name, so the data is under the company's agreement with Anthropic. The [fleet guide](FLEET.md) covers running several agents.
