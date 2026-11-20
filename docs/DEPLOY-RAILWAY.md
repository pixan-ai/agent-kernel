# Deploy on Railway

Status: verified end to end on Railway (November 2026) with a Claude Max subscription token.

1. Create a project and a service from this repository. In the service's **Settings**: set **Dockerfile Path** to `Dockerfile` (this selects the Dockerfile builder) and **Restart Policy** to **Always**. Optional **Watch Paths**: `Dockerfile`, `bin/**`, `policy/**`, so documentation and CI changes do not restart the agent.
2. Add a **volume** mounted at `/data` (one volume per service).
3. Set variables in the Railway dashboard (never in the repository):
   - `CLAUDE_CODE_OAUTH_TOKEN` (subscription, from `claude setup-token`) **or** `ANTHROPIC_API_KEY` (Console, per use). Not both: the API key wins.
   - `TELEGRAM_BOT_TOKEN`
   - `OWNER_TELEGRAM_ID`
   - optional: `TZ`, `ANTHROPIC_MODEL`
   - No `RAILWAY_RUN_UID`: Railway mounts the volume owned by root, and the image starts as root only to give `/data` to the `agent` user (uid 1001), then drops to it. A non-zero `RAILWAY_RUN_UID` stops the start with a message saying to delete it.
4. Deploy and message the bot.

Notes:

- This repository carries no `railway.json`: Railway deprecated Config as Code (it stops reading `railway.json` and `railway.toml` on 2026-12-01, and new services cannot use it). The service settings above are the configuration. `.railway/railway.ts` (Infrastructure as Code) is the official alternative for teams that manage several services.
- Railway bills per minute for CPU and memory. Long polling keeps a Serverless service awake, so leave Serverless off, unless you use the opt-in sleep (`IDLE_SLEEP_MINUTES`), which needs it on ([SLEEP.md](SLEEP.md)).
- Use a dedicated bot token. Do not reuse one that another process polls.
- Rotate a credential if it is ever pasted into a chat, a log or a screenshot ([SECRETS.md](SECRETS.md)).

## The one-click template

Published: **https://railway.com/deploy/pixan-agent**. It does steps 1 to 3 for whoever deploys: they only paste the three values. The settings are kept here so they can be checked against the code; to change them, edit the template in the Railway dashboard (workspace settings → **Templates**) and press **Apply**.

1. One service from the GitHub repository `pixan-ai/agent-kernel` (branch `main`).
2. In the service's **Settings**: Dockerfile Path `Dockerfile`, Restart Policy **Always**, Watch Paths `Dockerfile`, `bin/**`, `policy/**`. Icon `https://devicons.railway.com/i/telegram.svg`.
3. A **volume** mounted at `/data`.
4. **Variables**: the two Telegram values required and the two Claude credentials optional (one of them is needed: the agent does not start without either and says so in its log), none with a default, and each with its description (the composer's labels may differ from these words; the values must not):

| Variable | Default | Description shown to the deployer |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | none, required | Your bot's token from @BotFather. Use a new bot that nothing else polls. |
| `OWNER_TELEGRAM_ID` | none, required | Your numeric Telegram id (ask @userinfobot). Only you can talk to the agent at first. |
| `CLAUDE_CODE_OAUTH_TOKEN` | none, optional | Set this OR ANTHROPIC_API_KEY. From `claude setup-token`, for a personal agent on your Claude subscription. |
| `ANTHROPIC_API_KEY` | none, optional | Set this OR CLAUDE_CODE_OAUTH_TOKEN. An Anthropic Console API key, billed per use: for an agent that serves groups or clients. Wins if both are set. |
| `TZ` | `America/Mexico_City` | Your time zone, for scheduled jobs. |

5. Template: name `pixan-agent`, the same icon, description "Claude Code-based 24/7 personal agent on Telegram in one container.", category **AI/ML**, and the overview in [railway-template-overview.md](railway-template-overview.md).

Railway's limits, found while publishing on 2026-11-19: the description is 25 to 75 characters; the overview is at most 10,000 characters and must keep Railway's sections (`# Deploy and Host …`, `## About Hosting …`, `## Common Use Cases`, `## Dependencies for … Hosting` with `### Deployment Dependencies`, `## Why Deploy … on Railway?`; the CLI enforces the subsection, the dashboard does not), so the README cannot be the overview. In the dashboard, **Stage changes** only queues an edit: it is saved by **Apply**, which on a phone may be out of view. On a published template, Apply also updates the public page.

How it was made: the address comes from the name the template has when it is generated, and no setting changes it later, so the temporary project is named `pixan-agent` from the start. `railway templates create` turned that project into a draft (connecting the repository there starts one deploy, which fails without credentials; `railway down` stops it), `railway templates publish --category AI/ML --description … --readme-file docs/railway-template-overview.md` published it, and the name, icons, variable descriptions and overview were set in the dashboard. The temporary project is not needed afterwards: the template is a copy.
