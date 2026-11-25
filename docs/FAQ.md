# Frequently asked questions

## Getting started

**Do I need to know how to program?**
No. On Railway it is one click and three values. If you get stuck, [SETUP-WITH-AI.md](SETUP-WITH-AI.md) is a prompt that has your own Claude or Grok walk you through it.

**Which Claude key do I use?**
For your own agent, a token from your Claude Pro or Max subscription (`claude setup-token`). For an agent that serves groups, clients or a company, a Console API key, billed per use. Both go in the same field, `CLAUDE_KEY` ([GETTING-STARTED.md](GETTING-STARTED.md)).

**`/start` asked me to pair. Do I have to?**
No. That text comes from the official Telegram plugin and cannot be changed here. The owner needs no pairing: just write to the bot.

**Can I use the same bot for two agents?**
No. Two programs with one bot token take turns with the messages, and both miss some. Create one bot per agent.

**Does it run on a Raspberry Pi or a Mac with Apple Silicon?**
Not yet: the image is built for 64-bit Intel and AMD (`linux/amd64`).

## Cost

**How much does it cost?**
The software is free. You pay your own providers: your Claude plan or API usage, and your host. On Railway, with Serverless on, an idle agent costs very little ([SLEEP.md](SLEEP.md)).

**Why does Railway never show "Sleeping"?**
Serverless is off (turn it on in the service's settings), or the agent has scheduled jobs, which keep it awake on purpose so they run. It takes about 13 minutes after the last message with the template.

## Using it

**Does it remember what I told it?**
Within a day, yes. Every night it writes what matters into its memory and starts a new conversation. For something that must stay, say "remember that …" ([MEMORY.md](MEMORY.md)).

**Can it read Gmail, Calendar or Drive?**
Not through claude.ai's connectors: they are off in this deployment. A tool for a service can be installed by the owner or a super-user, with its key set on the host, never in the chat.

**Can it send messages on its own?**
Yes, with scheduled jobs ("every day at 8 send me …"), to you or to a group it is in ([CRON.md](CRON.md)).

**Can it be in a group with other agents?**
Yes. Give each bot a distinct name, address one with its @username, and turn on Bot-to-Bot only where agents must read each other ([GROUPS.md](GROUPS.md)).

**Can the agents see each other?**
If you set it up: the peer view lets one agent look at another's screen and recent conversation ([PEERS.md](PEERS.md)).

**Which model does it use?**
Claude Code's default for your account, unless you set `ANTHROPIC_MODEL` on the host. The advisor model is set to Opus by the policy.

## Safety

**Is it safe?**
It is official Claude Code with a strict policy, and it tells you about every change to its tools and settings. It is not a sandbox: a persuaded agent can do what its container's user can do. Read [THREAT-MODEL.md](THREAT-MODEL.md), and do the weekly review the guide requires.

**Who can give it instructions?**
You, and the super-users you name. Everyone else in its groups can ask for ordinary work, not for installs, settings or private information. This rests on its instructions and judgment, and you are told of every change.

**Where is my data?**
On the agent's own volume, at your host; what the model reads goes to Anthropic under your account. Nothing goes to this project ([PRIVACY.md](PRIVACY.md)).

**I pasted a key in a chat. What now?**
Replace it: a new token from @BotFather (`/revoke`), a new `claude setup-token` or a new Console key, then set it on the host ([SECRETS.md](SECRETS.md)).

## The project

**Is this made by Anthropic?**
No. It is an independent open-source project that runs Anthropic's official Claude Code and Telegram plugin, unmodified.

**Why only 247 lines?**
So that anyone can read and audit what was added to the official tools. A test holds the number ([CODE.md](CODE.md)).

**How do I update?**
Railway: redeploy on the new version. Your own server: `git pull` and `docker compose up -d --build` ([GETTING-STARTED.md](GETTING-STARTED.md#updates-and-how-to-go-back)).

**Something is wrong.**
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
