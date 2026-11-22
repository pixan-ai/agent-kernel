# Deploy on Railway

Status: verified end to end on Railway (November 2026) with a Claude Max subscription token.

1. Create a project and a service from this repository. In the service's **Settings**: set **Dockerfile Path** to `Dockerfile` (this selects the Dockerfile builder) and **Restart Policy** to **Always**. Optional **Watch Paths**: `Dockerfile`, `bin/**`, `policy/**`, so documentation and CI changes do not restart the agent.
2. Add a **volume** mounted at `/data` (one volume per service).
3. Set variables in the Railway dashboard (never in the repository):
   - `CLAUDE_KEY`: your subscription token (from `claude setup-token`) or a Console API key (per use); its start says which.
   - `TELEGRAM_BOT_TOKEN`
   - `OWNER_TELEGRAM_ID`
   - optional: `TZ`, `ANTHROPIC_MODEL`
   - No `RAILWAY_RUN_UID`: Railway mounts the volume owned by root, and the image starts as root only to give `/data` to the `agent` user (uid 1001), then drops to it. If `RAILWAY_RUN_UID` makes it start as a user who cannot write `/data`, it stops with a message saying to delete that variable.
4. Deploy and message the bot.

Notes:

- This repository carries no `railway.json`: Railway deprecated Config as Code (it stops reading `railway.json` and `railway.toml` on 2026-12-01, and new services cannot use it). The service settings above are the configuration. `.railway/railway.ts` (Infrastructure as Code) is the official alternative for teams that manage several services.
- Railway bills per minute for CPU and memory. Long polling keeps a Serverless service awake, so Serverless on costs nothing for an always-on agent; the sleep (`IDLE_SLEEP_MINUTES`) needs it on ([SLEEP.md](SLEEP.md)). A template cannot turn it on: the agent tells its owner when it is off.
- `railway ssh` opens a shell as the image's user, which is root: the image starts as root to give `/data` to the agent (audit of 2026-11-21, L6; not yet confirmed with `railway ssh -- id`). Reading logs is fine. For anything else, first drop to the agent's user with `exec setpriv --reuid=1001 --regid=1001 --init-groups --no-new-privs env HOME=/home/agent bash`, and never run `claude` or a program from `/data/bin` or `/home/agent/.local/bin` as root: the agent can write those.
- Use a dedicated bot token. Do not reuse one that another process polls.
- Rotate a credential if it is ever pasted into a chat, a log or a screenshot ([SECRETS.md](SECRETS.md)).

## The one-click template

Published: **https://railway.com/deploy/pixan-agent**. It does steps 1 to 3 for whoever deploys: they only paste the three values. Inside an existing project, add it with **+ Create → Template** and search for `pixan-agent` (**GitHub Repo** would create a bare service without the form, the volume or the domain); a project created from the link gets a random name, which **Settings → General** changes. The settings are kept here so they can be checked against the code; to change them, edit the template in the Railway dashboard (workspace settings → **Templates**) and press **Apply**.

1. One service from the GitHub repository `pixan-ai/agent-kernel` (branch `main`).
2. In the service's **Settings**: Dockerfile Path `Dockerfile`, Restart Policy **Always**, Watch Paths `Dockerfile`, `bin/**`, `policy/**`. Icon `https://devicons.railway.com/i/telegram.svg`.
3. A **volume** mounted at `/data`, and in **Networking** an **HTTP Proxy** with port `8080` (Railway generates the domain at deploy; the sleep needs it).
4. **Variables**, in this order, each with its description (the composer's labels may differ from these words; the values must not). The Claude key is one required field, `CLAUDE_KEY`, whatever its kind: with two optional fields, Railway listed them out of sight, created neither when left empty, and let a subscription token land in the API key field, which left an agent mute (2026-11-22).

| Variable | Default | Description shown to the deployer |
|---|---|---|
| `CLAUDE_KEY` | none, required | Step 1 of 3. Your Claude key, either kind. For a personal agent on your Claude Pro or Max subscription: install Claude Code on your computer (code.claude.com/docs/en/setup), run `claude setup-token` and paste the token it prints (it starts with sk-ant-oat01-). For an agent that serves groups or clients, billed per use: console.anthropic.com → API Keys → Create Key (it starts with sk-ant-api03-). To switch later, replace it and redeploy. |
| `OWNER_TELEGRAM_ID` | none, required | Step 2 of 3. Your numeric Telegram id, not your @username: in Telegram open @userinfobot, press Start, and copy the number after "Id". Only you can talk to the agent at first. |
| `TELEGRAM_BOT_TOKEN` | none, required | Step 3 of 3. In Telegram open @BotFather, send /newbot, choose a name and a username ending in "bot", and copy the token with the copy button (it looks like 123456789:AAH…). Use a new bot that nothing else polls. |
| `IDLE_SLEEP_MINUTES` | `3`, optional | Minutes without messages before the agent sleeps and stops costing. Empty = always on |
| `TZ` | `America/Mexico_City`, required with that default | Your time zone, for scheduled jobs. |

5. Template: name `pixan-agent`, the same icon, description "Claude Code-based 24/7 personal agent on Telegram in one container.", category **AI/ML**, and the overview in [railway-template-overview.md](railway-template-overview.md).

Railway's limits, found while publishing on 2026-11-19: the description is 25 to 75 characters; the overview is at most 10,000 characters and must keep Railway's sections (`# Deploy and Host …`, `## About Hosting …`, `## Common Use Cases`, `## Dependencies for … Hosting` with `### Deployment Dependencies`, `## Why Deploy … on Railway?`; the CLI enforces the subsection, the dashboard does not), so the README cannot be the overview. In the dashboard, **Stage changes** only queues an edit: it is saved by **Apply**, which on a phone may be out of view. On a published template, Apply also updates the public page.

How it was made: the address comes from the name the template has when it is generated, and no setting changes it later, so the temporary project is named `pixan-agent` from the start. `railway templates create` turned that project into a draft (connecting the repository there starts one deploy, which fails without credentials; `railway down` stops it), `railway templates publish --category AI/ML --description … --readme-file docs/railway-template-overview.md` published it, and the name, icons, variable descriptions and overview were set in the dashboard. The temporary project is not needed afterwards: the template is a copy.
