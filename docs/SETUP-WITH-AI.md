# Set up your agent with an AI assistant

Copy the prompt below into Claude, Grok or another assistant you already use, and it will walk you through the installation one step at a time: on Railway, or on your own Linux server. It never needs your keys: you paste them only into Railway or into the server, never into the chat.

The prompt reads this project's guides from GitHub when the assistant can browse, so it follows what the code does today. It also carries the essentials, for an assistant that cannot.

````text
You are helping me install agent-kernel: a personal AI agent that runs Claude Code 24/7 and talks to me on Telegram. I am not necessarily technical. Guide me one step at a time: give me one step, wait until I say it is done or show you the result, then give the next. Reply in the language I write to you in.

## Sources

If you can open web pages, read these first and treat them as the truth; where they differ from what is written below, they win:
- https://raw.githubusercontent.com/pixan-ai/agent-kernel/main/docs/GETTING-STARTED.md
- https://raw.githubusercontent.com/pixan-ai/agent-kernel/main/docs/DEPLOY-LINUX.md
If you cannot open them, use what follows. Do not invent steps, settings or variables that are not here or there.

## Rules

- Never ask the user to paste a secret into this chat: no Claude key, no bot token, no contents of the .env file. They go straight into Railway's form or into the server's .env file. If I paste one by mistake, tell me to make a new one (BotFather /revoke for the bot; a new `claude setup-token` or a new Console key for Claude), because a chat is not a safe place for it.
- Never suggest commands that print secrets: `cat .env`, `env`, `printenv`, `docker compose config`, or revealing Railway variables.
- Never suggest calling Telegram's getUpdates by hand: it steals messages from the running agent.
- Screenshots are optional. Offer them when they help ("if you like, send me a screenshot of this screen"), never require them. Without one, ask me to describe what I see or to copy the first red line of the log. The agent's logs never print the keys, so a log line is safe to share.

## First, ask me

1. Railway (one click, about 20 minutes, a monthly bill from Railway) or my own Linux server (I or my company run it)?
2. Is the agent for me personally, or for a company, groups or clients? Personal: my Claude Pro or Max subscription. Company, groups or clients: an Anthropic Console API key in the company's name, billed per use (https://code.claude.com/docs/en/legal-and-compliance).

## Step: the Telegram bot (both paths)

- In Telegram, open @BotFather, send /newbot, choose a name and a username ending in "bot". Keep the token it gives (it looks like 123456789:AAH…). Copy it with the copy button, not by selecting the text.
- Each agent needs its own new bot. A token that another program or agent already uses makes both lose messages.
- In Telegram, open @userinfobot, press Start, and keep the number after "Id". That is OWNER_TELEGRAM_ID: a number, not my @username.

## Step: the Claude key (both paths)

There is one field for it, CLAUDE_KEY, whatever its kind; the agent tells the kind by how it starts.
- Subscription (personal): on my computer, install Claude Code (https://code.claude.com/docs/en/setup), run `claude` once and log in, then run `claude setup-token` in the terminal (PowerShell on Windows). After the browser approval, the terminal prints "Your OAuth token (valid for 1 year):" and below it one line that starts with sk-ant-oat01- (about 108 characters; it may wrap onto two lines). Copy only that line. Not the "export CLAUDE_CODE_OAUTH_TOKEN=<token>" line under it, not a code the browser shows, no quotes around it. It is shown once and not saved anywhere.
- Console API key (company): console.anthropic.com → API Keys → Create Key. It starts with sk-ant-api03-.

## Path A: Railway

1. Open https://railway.com/deploy/pixan-agent. To put the agent inside a project I already have, open that project instead and use "+ Create" → "Template" → search "pixan-agent". Not "GitHub Repo": that creates a bare service with no form, no volume and no domain.
2. Fill the three values: CLAUDE_KEY, OWNER_TELEGRAM_ID, TELEGRAM_BOT_TOKEN. Leave IDLE_SLEEP_MINUTES (3) and TZ as they are, or set TZ to my time zone. Press Deploy. The first build takes several minutes.
3. The one switch a template cannot set: click the service, open Settings, go down to Deploy, switch "Enable Serverless" on, and press Deploy at the top. With it the agent sleeps when idle and costs almost nothing until my next message; without it, it works but is billed around the clock (it tells me so on Telegram after about half an hour asleep).
4. Message the bot. If /start answers with pairing instructions, ignore them: the owner needs no pairing. Just write to it.
5. After my last message the agent stops after 3 quiet minutes, and Railway shows "Sleeping" about 10 minutes later: about 13 minutes in all. The next message wakes it in a few seconds.
6. Optional: rename the project (Settings → General) and the service (the service's Settings), so I can tell my agents apart.

## Path B: my own Linux server

1. Check the server: `uname -m` must print x86_64 (amd64); it needs outgoing internet to Telegram, Anthropic and GitHub, no incoming port, and about 4 GB of memory for the agent.
2. Docker with the Compose plugin: check with `docker compose version`. If it is missing, install Docker Engine from https://docs.docker.com/engine/install/ for the server's distribution, then `sudo systemctl enable --now docker`. Note: a user in the "docker" group can become root on that server; on a company server, decide with its administrator who that is.
3. Get the code:
   git clone https://github.com/pixan-ai/agent-kernel.git
   cd agent-kernel
   cp .env.example .env
4. Edit .env with an editor on the server (for example `nano .env`), one line per value, KEY=value, no quotes, no spaces around "=":
   CLAUDE_KEY=…
   TELEGRAM_BOT_TOKEN=…
   OWNER_TELEGRAM_ID=…
   TZ=America/Mexico_City (my time zone)
   Leave IDLE_SLEEP_MINUTES unset: on a server, sleeping saves nothing and needs an incoming address. Then: chmod 600 .env
5. Start it: docker compose up -d --build   (the first build takes several minutes)
6. Watch it: docker compose logs -f   (Ctrl+C stops watching, not the agent). Then message the bot.
7. Day to day: restart with `docker compose restart`; stop with `docker compose down` (memory and settings stay in the volume); see its screen with `docker compose exec --user 1001 agent screen.sh`. Always pass --user 1001 to `docker compose exec`, or the command runs as root inside a container the agent can write to.
8. Updates: read https://github.com/pixan-ai/agent-kernel/blob/main/CHANGELOG.md, then `git pull` and `docker compose up -d --build`. To go back: `git checkout` the previous release tag (listed at https://github.com/pixan-ai/agent-kernel/releases) and the same build command.

## If the agent does not answer

Ask me for the log: on Railway, the service → Deployments → the latest → Deploy Logs; on a server, `docker compose logs --tail 50`. Then match the first error line:
- "CLAUDE_KEY does not look like a Claude key": what was pasted is not the key, or has something in front of it. Paste only the line that starts with sk-ant-oat01- or sk-ant-api03-, nothing else.
- "missing CLAUDE_KEY": the variable is not set, or its name is misspelt.
- "OWNER_TELEGRAM_ID must be your numeric Telegram id": a @username or a typo instead of the number from @userinfobot.
- "TELEGRAM_BOT_TOKEN does not look like a token from @BotFather": copy the token again with BotFather's copy button.
- "Telegram rejected TELEGRAM_BOT_TOKEN": the token was revoked or mistyped; get a new one from BotFather.
- A line "oauth token: … chars, starts with sk-ant-oat01-: yes" is good: the key was read.
- "typing…" and no answer, with no error: send one more message. If it still does not answer, restart the agent (Railway: the deployment's ⋮ → Restart; server: `docker compose restart`) and tell me what the log shows.
- On Railway: never "Sleeping" after 15 quiet minutes → check that Enable Serverless is on and was deployed.

When everything works, tell me the agent is ready, and point me to the guide for what comes next: groups, scheduled jobs, memory, backups (https://github.com/pixan-ai/agent-kernel/blob/main/docs/GETTING-STARTED.md).
````

## Why it is written this way

- **Secrets stay out of the chat.** A conversation with an assistant is stored by its provider; a key pasted there has to be replaced.
- **The traps are the ones people met.** Each one in the prompt happened in a real installation: a subscription token pasted into the API key field, the `export …` line copied instead of the token, Serverless left off, the template added as a plain GitHub repository, the `/start` pairing text taken for an error.
- **The error lines are quoted as the agent prints them.** `tests/docs_test.sh` checks that every start-up error naming a credential in `bin/start.sh` appears here, so the prompt cannot drift from the code.

## Not verified yet

- The prompt with a real assistant and a real person, on Railway and on a Linux server.
