# Deploy on Railway

Status: verified end to end on Railway (November 2026) with a Claude Max subscription token.

1. Create a project and a service from this repository. In the service's **Settings**: set **Dockerfile Path** to `Dockerfile` (this selects the Dockerfile builder) and **Restart Policy** to **Always**. Optional **Watch Paths**: `Dockerfile`, `bin/**`, `policy/**`, so documentation and CI changes do not restart the agent.
2. Add a **volume** mounted at `/data` (one volume per service).
3. Set variables in the Railway dashboard (never in the repository):
   - `CLAUDE_CODE_OAUTH_TOKEN` (subscription, from `claude setup-token`) **or** `ANTHROPIC_API_KEY` (Console, per use). Not both: the API key wins.
   - `TELEGRAM_BOT_TOKEN`
   - `OWNER_TELEGRAM_ID`
   - optional: `TZ`, `ANTHROPIC_MODEL`
   - `RAILWAY_RUN_UID=0`: Railway volumes are owned by root. The entrypoint only fixes `/data` ownership as root, then drops to the `agent` user (uid 1001).
4. Deploy and message the bot.

Notes:

- This repository carries no `railway.json`: Railway deprecated Config as Code (it stops reading `railway.json` and `railway.toml` on 2026-12-01, and new services cannot use it). The service settings above are the configuration. `.railway/railway.ts` (Infrastructure as Code) is the official alternative for teams that manage several services.
- Railway bills per minute for CPU and memory. Long polling keeps a Serverless service awake, so leave Serverless off, unless you use the opt-in sleep (`IDLE_SLEEP_MINUTES`), which needs it on ([SLEEP.md](SLEEP.md)).
- Use a dedicated bot token. Do not reuse one that another process polls.
- Rotate a credential if it is ever pasted into a chat, a log or a screenshot ([SECRETS.md](SECRETS.md)).

## The one-click template

A Railway template does steps 1 to 3 for whoever deploys: they only paste the three values. The owner of this repository creates and publishes it from the Railway dashboard; the settings to enter are these, kept here so they can be checked against the code.

1. Railway dashboard → workspace settings → **Templates** → **New Template** (Railway's docs: "Create a Template", starting from scratch), and add a service from the GitHub repository `pixan-ai/pixan-kernel-spike` (branch `main`).
2. In the service's **Settings**: Dockerfile Path `Dockerfile`, Restart Policy **Always**, Watch Paths `Dockerfile`, `bin/**`, `policy/**`.
3. Add a **volume** mounted at `/data`.
4. **Variables**: the three credentials with no default, so the deployer is asked for them, and each with its description (the composer's labels may differ from these words; the values must not):

| Variable | Default | Description shown to the deployer |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | none, required | Your bot's token from @BotFather. Use a new bot that nothing else polls. |
| `OWNER_TELEGRAM_ID` | none, required | Your numeric Telegram id (ask @userinfobot). Only you can talk to the agent at first. |
| `CLAUDE_CODE_OAUTH_TOKEN` | none, required | From `claude setup-token`, for a personal agent on your subscription. For an agent that serves groups or clients, delete this and set `ANTHROPIC_API_KEY` instead (see the guide). |
| `RAILWAY_RUN_UID` | `0` | Leave as is: the volume is owned by root; the agent fixes it and runs as an unprivileged user. |
| `TZ` | `America/Mexico_City` | Your time zone, for scheduled jobs. |

5. Template name `Pixan agent`, description "A personal Claude Code agent on Telegram, with memory, scheduled jobs and voice notes", and the README as the overview. **Publish**.
6. Deploy it once into a new project with real values and send the bot a message. Then add the template's link to the guide (docs/GETTING-STARTED.md, "Railway (the quick way)").
