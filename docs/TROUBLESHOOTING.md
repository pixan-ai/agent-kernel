# Troubleshooting

What to do when something is wrong, by symptom. Most problems show in two places: the agent's **log**, and the **private notices** it sends its owner on Telegram. The log never prints a key or a token, so a log line is safe to share when you ask for help.

**Where the log is**

| Host | How to read it |
|---|---|
| Railway | The service → **Deployments** → the latest → **Deploy Logs** |
| Your own server | In the agent's folder: `docker compose logs --tail 100`, or `docker compose logs -f` to follow it |

**Where the agent's screen and conversation are**, on your own server: `docker compose exec --user 1001 agent screen.sh 60`, and `docker compose exec --user 1001 -e SSH_ORIGINAL_COMMAND=transcript agent peer.sh` for the recent conversation ([DEPLOY-LINUX.md](DEPLOY-LINUX.md#day-to-day)).

## The agent never starts

`start.sh` checks the credentials first and stops, saying why, before anything else runs. Look for the first error line in the log:

| The log says | What to do |
|---|---|
| `missing CLAUDE_KEY` | The variable is not set, or its name is misspelt. Set `CLAUDE_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`, or `ANTHROPIC_API_KEY`) |
| `CLAUDE_KEY does not look like a Claude key` | What was pasted is not the key, or has something in front of it (the `export …` line, quotes, a code the browser showed). Paste only the line that starts with `sk-ant-oat01-` (subscription) or `sk-ant-api03-` (Console) |
| `OWNER_TELEGRAM_ID must be your numeric Telegram id` | A @username or a typo. Use the number @userinfobot gives |
| `TELEGRAM_BOT_TOKEN does not look like a token from @BotFather` | Mistyped, or pasted with a space inside (common from a phone). Copy it again with @BotFather's copy button |
| `Telegram rejected TELEGRAM_BOT_TOKEN` | The token was revoked or belongs to no bot. Get a new one from @BotFather |
| `/data is not writable by uid …` | The container was started as another user. On Railway, delete `RAILWAY_RUN_UID` or set it to `0` |
| `warning: /data is not a volume` (and "⚠️ /data is not a volume" on Telegram) | Memory, settings and jobs are lost at every redeploy. Add a volume at `/data` |

A line `oauth token: N chars, starts with sk-ant-oat01-: yes` is good: the key was read. About 108 characters is normal for a subscription token; much shorter means it was cut when copied.

To check a key **before** deploying it, see [GETTING-STARTED.md](GETTING-STARTED.md#2-get-the-claude-credential-your-computer-3-minutes).

## The agent does not answer

"Typing…" and nothing, or no reaction at all. Go in this order; each step tells the causes apart:

1. **Which host is it on?** Make sure you are looking at the agent that owns this bot. Two programs with the same bot token (an old deployment, a test, another server) take turns with the messages: one gets a message, the other the next. Each agent needs its own bot.
2. **Did the message reach it?** Find the time of your message in the log, or in the conversation (`transcript`). If it is not there, the message never arrived:
   - a group the agent was not told to join (it drops those silently);
   - a group that became a supergroup and changed its id ([GROUPS.md](GROUPS.md));
   - a bot added to a group before its privacy mode was turned off;
   - an agent deleted while asleep, whose webhook is still set: a new agent with the same token hears nothing. Use a new bot, or delete the old agent while it is awake ([SLEEP.md](SLEEP.md)).
3. **Did it move after the message?** If the message is there and the agent answered on its screen but nothing reached you, it wrote in its terminal instead of sending. Since 1.2.0 it is sent back to send the answer, and if it still does not, the agent sends you what it wrote. On an older version, update.
4. **Nothing moved at all?** The process may be stuck. Restart it: on Railway, the deployment's **⋮** → **Restart**; on a server, `docker compose restart`. A stream of "⚠️ My Telegram channel was down… Restarting" is a bug to report.
5. **Credentials dead.** It is alive but every answer fails: the Claude key expired or was revoked, or the plan limit was reached. The log shows `401`, or you got "⚠️ Claude plan limit". Make a new key ([SECRETS.md](SECRETS.md)).
6. **It is on a long task.** "⏳ I received a message more than 10 minutes ago and have not finished with it" means it is busy or stuck: wait, or restart it.

If you still cannot tell, send one more message and copy the log lines from that minute.

## Telegram notices from the agent

| You received | Meaning | What to do |
|---|---|---|
| "⚠️ I received your message and have no answer to send" | A turn ended twice without sending anything | Write again; if it repeats, restart the agent |
| "⏳ I received a message more than 10 minutes ago…" | Busy on a long task, or stuck | Wait, or restart |
| "⚠️ My Telegram channel was down while Claude was running. Restarting…" | The watchdog restarted Claude | One is normal; many are a bug to report |
| "Back online. I was down from … to …" | The agent was down; jobs in between did not run | Check the host's status page; ask for any job you missed |
| "⚠️ Claude plan limit: … used" | The subscription is nearly used up; past 100% it stops answering until it resets | Several agents on one subscription share the limit; use a Console key for agents that serve others |
| "🔄 Versions changed" | Claude Code or the plugin changed at this start | If something broke right after, go back ([updates](GETTING-STARTED.md#updates-and-how-to-go-back)) |
| "⚙️ Setting changed: …" | A group, super-user, fellow agent or job changed | If you did not expect it, see who asked and undo it ([GETTING-STARTED.md](GETTING-STARTED.md#8-review-your-agents-every-week-required)) |

## Groups

| Symptom | Cause and fix |
|---|---|
| Silent in a group | The group is not on its list ("join the group -100…"), its privacy mode was on when it was added (turn it off in @BotFather, then remove the bot and add it again), or the group's id changed when it became a supergroup |
| Several agents answer a message meant for one | Names that differ by a letter, or a message that does not start with the name. Give each bot a distinct name and write to it with its @username ([GROUPS.md](GROUPS.md#several-agents-in-one-group)) |
| A job's answer came to you instead of the group | The agent is no longer in that group; tell it to join again |
| It does not read other bots | Bot-to-Bot communication is off for one of the bots, in @BotFather |

## Sleep (Railway)

| Symptom | Cause and fix |
|---|---|
| Never shows "Sleeping" | Serverless is off: the service's **Settings** → **Enable Serverless** → Deploy. It takes about 13 minutes after the last message with the template. An agent with scheduled jobs stays awake on purpose ([SLEEP.md](SLEEP.md)) |
| "⚠️ I am asleep, but the host keeps me running and billed" | The same: turn Serverless on |
| "⚠️ IDLE_SLEEP_MINUTES is set, but I cannot sleep: …" | The log says `not sleeping: …`: there is no public address, Telegram did not accept the webhook, or the address does not reach port 8080 |

## Your own server

| Symptom | Cause and fix |
|---|---|
| A variable added to `.env` has no effect | `docker compose restart` does not read `.env` again: run `docker compose up -d` |
| Memory and settings are gone | The volume was deleted (`docker compose down -v`). Restore a backup if you have one ([BACKUP.md](BACKUP.md)) |
| Two agents on the server cannot see each other | They need a shared Docker network declared in `compose.override.yml` ([PEERS.md](PEERS.md#two-agents-on-one-linux-server)) |
| Another Claude Code on the machine stopped working | The agent's key was set for the whole machine. Set it only in the agent's `.env` |

## Memory and files

| Symptom | Cause and fix |
|---|---|
| It does not remember something from yesterday | The nightly memory left it out. Ask "What do you remember about …?", and say "Remember that …" for what must stay ([MEMORY.md](MEMORY.md)) |
| It refuses to send a file | The file is outside its workspace; ask it to copy what you need there, if it is not a credential |

## Still stuck

Open an issue with the symptom, the host, the version (`🔄 Versions changed` message or `git log -1`) and the log lines around the time of the problem. Never paste a key, a token or the contents of `.env`. Security problems go through [SECURITY.md](../SECURITY.md), not an issue.
