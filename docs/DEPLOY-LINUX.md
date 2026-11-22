# Deploy on your own Linux server

The same repository runs on any Linux server with Docker, for example a company's own machine or VM. Nothing is published to it from outside: the server builds the image itself, and Claude Code is installed during that build with Anthropic's official installer.

## What the server needs

- Linux on **amd64** (x86-64), with Docker and the Compose plugin. Docker should start at boot: `sudo systemctl enable --now docker`.
- **Outgoing** internet to Telegram, Anthropic and GitHub. **No incoming port**: the agent asks Telegram for messages; nothing connects to it. (The optional sleep and the peer view do need an incoming address; leave them off here.)
- About 4 GB of memory for the agent (the cap in `compose.yml`, `MEM_LIMIT`) and disk for its volume.

## Install

```bash
git clone https://github.com/pixan-ai/agent-kernel.git
cd agent-kernel
cp .env.example .env    # then fill in the credentials below
docker compose up -d --build
```

In `.env`:

| Variable | Value |
|---|---|
| `TELEGRAM_BOT_TOKEN` | A new bot from @BotFather that nothing else polls |
| `OWNER_TELEGRAM_ID` | The owner's numeric Telegram id (ask @userinfobot) |
| `CLAUDE_KEY` | For a company agent: a Console API key (`sk-ant-api03-…`) in the company's name, with its own billing. A subscription token (`sk-ant-oat01-…`) is for one person's own agent ([which credential](https://code.claude.com/docs/en/legal-and-compliance)) |
| `TZ` | The time zone for scheduled jobs, e.g. `America/Mexico_City` |

`.env` holds secrets: keep it readable only by the administrator (`chmod 600 .env`) and out of any shared folder. The first build takes several minutes; then message the bot.

## Day to day

| To | Run, in the `agent-kernel` folder |
|---|---|
| See what it is doing | `docker compose logs -f` |
| See its screen | `docker compose exec --user 1001 agent screen.sh` |
| Restart it | `docker compose restart` |
| Stop it | `docker compose down` (the volume, with its memory and settings, stays) |

Always pass `--user 1001` to `docker compose exec`: the image starts as root (only to hand the volume to the agent), so without it the command runs as root, inside a container the agent can write to.

If the agent stops, Docker starts it again (`restart: unless-stopped`), also after the server reboots.

## Updates, and going back

On Railway a new version can reach the agent by itself ([updates](GETTING-STARTED.md#updates-and-how-to-go-back)); here whoever looks after the server applies it, after reading the [changelog](../CHANGELOG.md):

```bash
git pull
docker compose up -d --build
```

The owner gets a "🔄 Versions changed" message when it starts. To go back: `git checkout v1.0.0` (or the previous release tag) and the same `docker compose up -d --build`; for Claude Code alone, set `CLAUDE_CODE_VERSION` in `.env` to the previous version (2.1.319 or later) and rebuild.

## Backups

The same nightly encrypted backup as on Railway, to storage the company controls: [BACKUP.md](BACKUP.md). Set its variables in `.env`. Rehearse a restore onto an empty volume before relying on it.

## Stronger isolation (not tested yet)

Railway does not allow the user namespaces that Claude Code's sandbox and `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` need, so there the agent relies on the policy and the classifier only ([threat model](THREAT-MODEL.md#hardening-by-host)). A server of your own may allow them. Check first, as the agent's user:

```bash
docker compose exec --user 1001 agent unshare -U true && echo "namespaces: yes"
```

Docker's default security profile may refuse this; changing it is a decision for the server's administrator. Turning the sandbox on and measuring that it works is not done or documented here yet: until it is, treat the agent on a server exactly as on Railway (see the threat model).
