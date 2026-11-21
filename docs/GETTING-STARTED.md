# Getting started: from nothing to an agent that answers

For someone who has never run this. About 20 minutes. You need a Telegram account and a Claude subscription (or an Anthropic API key).

After the installation everything else is done **by talking to the agent**: adding groups, scheduling jobs, pointing it at fellow agents. You come back to the host only to change a credential (and, on Railway, once to [let updates reach the agent by themselves](#updates-and-how-to-go-back)).

## 1. Create the bot (Telegram, 3 minutes)

1. Talk to [@BotFather](https://t.me/BotFather), send `/newbot`, choose a name and a username. Keep the **token** it gives you.
2. Each agent needs **its own bot**. Never reuse a token that another program is using.
3. Find your numeric Telegram id: talk to [@userinfobot](https://t.me/userinfobot). Keep the **id**.

## 2. Get the Claude credential (your computer, 3 minutes)

Which one: a **subscription for a personal agent**, the one you talk to yourself; an **API key for an agent that serves groups or clients**. Anthropic's terms assume ordinary, individual use of a subscription, and ask products and services to use API keys ([legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)). An agent set up for someone else runs on that person's own credential, in their own host account; nobody else keeps or bills it.

- **Subscription (personal agent):** install Claude Code, run `claude` once and log in, then run `claude setup-token` in the terminal (not inside Claude). Keep the token that starts with `sk-ant-oat01-`.
- **API key (groups, clients):** create one in the [Anthropic console](https://console.anthropic.com/). Billed per use.

Copy the value with a copy button, not by selecting text: a truncated token gives a bot that shows "typing…" and never answers.

## 3. Deploy

### Railway (the quick way)

**One click:** [deploy the pixan-agent template](https://railway.com/deploy/pixan-agent), paste the three values from steps 1 and 2, and message your bot when the build finishes (several minutes). It sets up everything below for you. To do it by hand instead:

1. New project → deploy from this repository.
2. Service **Settings**: Dockerfile Path `Dockerfile`, Restart Policy **Always**.
3. Add a **volume** mounted at `/data`.
4. **Variables**:

| Variable | Value |
|---|---|
| `TELEGRAM_BOT_TOKEN` | from step 1 |
| `OWNER_TELEGRAM_ID` | from step 1 |
| `CLAUDE_CODE_OAUTH_TOKEN` | from step 2 (or `ANTHROPIC_API_KEY`, not both) |
| `TZ` | your time zone, e.g. `America/Mexico_City` |

5. Press **Deploy** (variables stay pending until you do).

Details and notes: [DEPLOY-RAILWAY.md](DEPLOY-RAILWAY.md). Cost: an agent that is always on uses about 0.3 to 0.7 GB of memory, billed by the minute. 

**Optional: sleep when idle.** Off by default: the agent is always on. To pay only while it works, add the variable `IDLE_SLEEP_MINUTES` (for example `10`) and give the service a public address; the agent then stops after that many quiet minutes and wakes on the next message, a few seconds later. Remove the variable to go back to always on. Steps and limits: [SLEEP.md](SLEEP.md).

### Your own server or computer (Docker)

```bash
git clone https://github.com/pixan-ai/agent-kernel && cd agent-kernel
cp .env.example .env    # fill in the same values as above
docker compose up -d --build
```

A fixed-price server suits several agents better than per-minute billing, and a host that allows user namespaces can add the hard isolation that Railway cannot ([THREAT-MODEL.md](THREAT-MODEL.md)).

## 4. Check that it works

1. The start log shows `oauth token: N chars, starts with sk-ant-oat01-: yes`. N is about 108; a much smaller number means a truncated token.
2. Send the bot "Hola". It answers within a few seconds.
3. Ask "What is your name and id?" ("¿Cómo te llamas y cuál es tu id?"): it knows its own bot name.

`/start` shows pairing instructions from the plugin. Ignore them: in private only the owner is allowed, and no pairing is needed.

## 5. What to tell the agent next

Write to the agent in any language: it answers in the one it is written to. Each example is in English, with the Spanish its first users say in parentheses.

| You say | What happens | More |
|---|---|---|
| "Send me a summary of … every day at 8" ("mándame cada día a las 8 un resumen de …") | It schedules a job; you get a notice | [CRON.md](CRON.md) |
| "Join the group -100…" ("únete al grupo -100…") | It reads and answers everyone in that group, people and bots, no mention needed | [GROUPS.md](GROUPS.md) |
| "Your fellow agent X is at …" / "What is X doing?" ("tu compañero X está en …" / "¿qué está haciendo X?") | It remembers a fellow agent and can look at its screen | [PEERS.md](PEERS.md) |
| "Remember that …" / "What do you remember about …?" ("recuerda que …" / "¿qué recuerdas de …?") | It keeps it in its memory. Every night it consolidates the day and starts a clean conversation | [MEMORY.md](MEMORY.md) |
| "Every day at 9, post yesterday's highlights in the group -100…" ("cada día a las 9 publica en el grupo -100… lo más relevante de ayer") | The daily council: every agent of a team reports in one group, and they read each other | [MEMORY.md](MEMORY.md#the-daily-council) |
| A PDF, a Word, Excel or PowerPoint file | It reads it, with no setup: every agent can from the start | [What the image contains](#what-the-image-contains) |
| "Learn to listen to voice notes" / "learn to work with video" ("aprende a escuchar notas de voz" / "aprende a trabajar con video") | It installs voice or video once, from the optional stack; then it transcribes voice notes or works with videos | [The optional stack](#the-optional-stack-voice-and-video) |
| "Hazme un Excel / Word / PowerPoint / PDF con …" | It makes the file and sends it to you | [What the image contains](#what-the-image-contains) |
| "Haz super-usuario a 123456789" | That person can also give it instructions in its groups | [GROUPS.md](GROUPS.md) |
| "Send me the file …" ("mándame el archivo …") | It attaches files from its workspace, or ones it received. It cannot attach keys, credentials or its configuration | [THREAT-MODEL.md](THREAT-MODEL.md) |
| "Anota en tu CLAUDE.md que …" | Its own lasting instructions (name, role, tone) | |

Every change it makes to its own settings is confirmed to you in private ([SETTINGS.md](SETTINGS.md)).

## 6. What to expect day to day

- **Every night at 4:00** the agent restarts, consolidates the day into its memory and begins a new conversation. It is away for a minute or two. The next day it knows what it kept, not the literal wording of yesterday.
- **When the Claude plan runs low** you get one notice at 80% of the 5-hour or the weekly limit, and the reason if a job or the nightly memory is stopped by it. With an API key there are no such figures and no notice.
- **Every change to its settings** (a group, a super-user, a job, a fellow agent) reaches you as a private notice, whoever asked for it.
- **If you turned on the optional sleep** ([SLEEP.md](SLEEP.md)), the first message after a quiet period takes a few seconds longer.
- **In groups** it answers when addressed or when a message is for everyone, and stays silent otherwise. Anyone there may ask it for ordinary work (transcribe, read a document, search, summarise); only you and the super-users can make it install something, change its settings, schedule jobs, act on other agents or share what is private.

## 7. Before you rely on it

- **Backups:** off until you set them up. [BACKUP.md](BACKUP.md).
- **What it can and cannot protect:** [SECURITY.md](../SECURITY.md) and [THREAT-MODEL.md](THREAT-MODEL.md). On Railway the protection is policy and judgment, not a sandbox.
- **Rotating a credential:** [SECRETS.md](SECRETS.md).
- **Review the changes regularly.** Whoever owns the agents should look, every week or so, at what each one installed and at changes to its groups and super-users: the private notices, and "What have you installed?" ("¿qué tienes instalado?") and "What settings do you have?" ("¿qué ajustes tienes?". The agents decide by judgment and tell you what they did; the review is what turns those notices into control.
- **Use supergroups from the start.** Telegram turns a plain group into a supergroup on its own when you change its administrators or some of its settings, and the group gets a new id (`-100…`): the agent stops hearing it until it is told the new one. Create the group as a supergroup (or change one setting that converts it, such as making the history visible to new members) before adding the agent, and tell the agent the `-100…` id ([GROUPS.md](GROUPS.md)).

## Everything you can configure

Three places, and nothing else. What is not listed here is fixed on purpose (the 4:00 recycle, the limits of the policy, the size of the logs).

### On the host: variables

Set once, at installation. Changing one restarts the agent.

| Variable | Default | What it does | More |
|---|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | required, or the next | Claude subscription token | step 2 |
| `ANTHROPIC_API_KEY` | | Console API key instead of the subscription; wins if both are set | step 2 |
| `TELEGRAM_BOT_TOKEN` | required | This agent's own bot | step 1 |
| `OWNER_TELEGRAM_ID` | required | The owner: the only private chat, and who gets every notice | step 1 |
| `TZ` | `UTC` | Time zone for jobs, the nightly recycle and the dates the agent sees | [CRON.md](CRON.md) |
| `ANTHROPIC_MODEL` | Claude's default | Pin the model | |
| `CLAUDE_CODE_VERSION` | the stable channel, never below 2.1.319 | Go back to a previous Claude Code (2.1.319 or later); read when the image is built, so redeploy | [Updates](#updates-and-how-to-go-back) |
| `CLAUDE_FLAGS` | empty | Extra flags for `claude`. The advisor is already on for every agent (`advisorModel: opus` in the policy); `--advisor MODEL` here picks another one for this agent | |
| `TELEGRAM_GROUP_IDS` | empty | Groups to join at the first start (the same as telling the agent); read only while `/data/settings` does not exist yet | [GROUPS.md](GROUPS.md) |
| `IDLE_SLEEP_MINUTES` | empty = always on | Sleep after this many quiet minutes | [SLEEP.md](SLEEP.md) |
| `DOORBELL_URL` | `https://` + `RAILWAY_PUBLIC_DOMAIN` | Public address Telegram calls to wake a sleeping agent. Needed outside Railway | [SLEEP.md](SLEEP.md) |
| `RAILWAY_PUBLIC_DOMAIN` | set by Railway | Not yours to set: Railway provides it when the service has a public domain | [SLEEP.md](SLEEP.md) |
| `PORT` | `8080` | Port the wake-up listener uses | [SLEEP.md](SLEEP.md) |
| `BACKUP_REMOTE` | empty = no backups | Where the nightly encrypted backup goes | [BACKUP.md](BACKUP.md) |
| `BACKUP_AGE_RECIPIENT` | | Public key the backups are encrypted to | [BACKUP.md](BACKUP.md) |
| `RCLONE_CONF` | | Credentials for the backup storage (secret) | [BACKUP.md](BACKUP.md) |
| `BACKUP_KEEP_DAYS` | `14` | Days of backups kept | [BACKUP.md](BACKUP.md) |
| `BACKUP_AGE_KEY` | | Only to restore onto an empty volume; remove it afterwards | [BACKUP.md](BACKUP.md) |
| `PEER_PUBLIC_KEYS` | empty = nobody | Keys of the fellow agents allowed to look at this one and set its groups and super-users | [PEERS.md](PEERS.md) |
| `PEER_SSH_KEY` | | Key this agent uses to look at others | [PEERS.md](PEERS.md) |
| `PEERS` | empty | Fellow agents by name, `Name=host` separated by spaces (the same as telling the agent) | [PEERS.md](PEERS.md) |
| `SCREEN_MIRROR` | empty = off | Seconds between copies of the agent's screen to the host log. Shows conversations to whoever reads the log | [THREAT-MODEL.md](THREAT-MODEL.md) |
| `JOB_TIMEOUT` | `900` | Seconds a scheduled job or the nightly dream may take | [CRON.md](CRON.md) |
| `MEM_LIMIT` | `4g` | Memory cap, with Docker Compose only | |

### By talking to the agent

Applied at once, kept on the volume, and confirmed to the owner in private. The owner or a super-user asks.

| Setting | Say | Undo |
|---|---|---|
| A group to take part in | "Join the group -100…" ("únete al grupo -100…") | "Leave the group -100…" ("sal del grupo -100…") |
| A super-user | "Make 123456789 a super-user" ("haz super-usuario a 123456789") | "Remove 123456789" ("quita a 123456789") |
| A fellow agent, by name | "Your fellow agent Junior is at agent2.railway.internal" ("tu compañero Junior está en …") | "Forget Junior" ("olvida a Junior") |
| A scheduled job, to you or to a group | "Every day at 8 send me …" ("cada día a las 8 mándame …") | "Remove the job …" ("quita la tarea …") |
| The notices about jobs | "Don't tell me about jobs" ("no me avises de las tareas") | "Tell me about jobs" ("avísame de las tareas") |
| Something to remember | "Remember that …" ("recuerda que …") | "Forget that …" ("olvida que …") |

"What settings do you have?" ("¿qué ajustes tienes?") lists them ([SETTINGS.md](SETTINGS.md)).

## Who can ask the agent for what

In plain words, for whoever runs an agent.

**The owner** is you: the Telegram account in `OWNER_TELEGRAM_ID`. Only you can talk to the agent in private.

**Super-users** are people you trust to run the agent with you. You name them by telling the agent "Make 123456789 a super-user" ("haz super-usuario a 123456789"); a super-user can name others. They give instructions in the groups the agent is in.

**Everyone else in a group** can ask for ordinary work: answer a question, transcribe a voice note, read a document, search, summarise, make a file.

**Only you and the super-users** can make the agent:

- install a package, a tool or a skill ("install …", "learn to …");
- change its settings: groups, super-users, fellow agents;
- schedule jobs;
- look at or change a fellow agent;
- share anything from your private chats, its memory or its files.

When someone else asks for one of these, the agent says that you or a super-user has to ask. This rests on its instructions and its judgment, not on code that tries to guess commands: a rule like that is always one spelling short, while Claude reads the request itself. What code does guarantee is that **you hear about every change**: anything installed, and any change to its settings, jobs or bot files that did not go through its settings command, reaches you in private ([THREAT-MODEL.md](THREAT-MODEL.md)).

**To have something installed**, just ask for the task ("turn this video into a GIF"): if the agent lacks a tool it says which one and why, and installs it if you are the owner or a super-user. Documents and office files need nothing: every agent has them. Voice and video need one install, below.

**What you are told, and why nothing is blocked by pattern.** Installed tools live in two folders on the agent's disk; every change there is recorded and told to you. Its settings and jobs are meant to change only through its own settings command, which always tells you; a change made any other way is told to you too, marked "by hand". Until 2026-11-18 a hook also tried to refuse installs by matching commands. Every audit found another way to write the same thing, while the refusals that mattered in practice came from the agent itself and from Claude Code's own checks, so it was removed: the agent decides, you see what it did.

**What you receive in private**, whoever made the change:

| Notice | When |
|---|---|
| ⚙️ Setting changed: … | A group, super-user or fellow agent was added or removed (always), or a job (unless you said "Don't tell me about jobs"); for a job, with its schedule, destination and text. A one-off reminder that was delivered removes itself without a notice |
| 🧰 Installed: … / 🧰 Removed: … | Something changed where tools live, or was uninstalled, with the command that did it |
| ⚠️ … was changed by hand, not through config.sh | Its settings, jobs or bot files, the workspace's Claude settings, `CLAUDE.md` or MCP servers (also one added with `claude mcp add`), the jobs' Claude settings, or the record of installs changed without its settings command |
| ⚠️ Claude plan limit: … used | The 5-hour or weekly limit passed 80% |
| ⚠️ Tonight's memory consolidation failed | The nightly memory failed (at most once a day) |
| ⚠️ Scheduled job … failed | A job failed, with the reason |
| ⚠️ Scheduled job … could not be delivered | Telegram refused the delivery (the bot was removed from the group, or the group changed id) |
| Back online. I was down from … | The agent was down for more than five minutes; jobs due meanwhile did not run |
| My Telegram channel was down … Restarting | The watchdog found the Telegram plugin gone and restarted Claude |
| ⚠️ Tonight's backup failed | The nightly backup could not be sent (only when backups are on) |
| ⏳ I received a message more than 10 minutes ago … | A message is still unanswered |

## Self-improvement: installing skills and tools

**Who.** Only the owner or a super-user ([SETTINGS.md](SETTINGS.md)) can ask the agent to install something. The owner counts as one more super-user. The agent declines anyone else, by its instructions; whatever it installs, you are told.

**How to ask.** Write to the agent on Telegram, in private or in a group it is in:

| Say | It runs | Lands in |
|---|---|---|
| "Get elevenlabs" / "install qrcode" ("baja elevenlabs" / "instala qrcode") | `uv pip install elevenlabs` | `/data/tools/venv` (run with `/data/tools/venv/bin/python`) |
| "Install the ruff tool" ("instala la herramienta ruff") | `uv tool install ruff` | `/data/bin`, on the agent's `PATH` |
| "Learn to make a PowerPoint" ("aprende a hacer un PowerPoint") | writes a skill | `/data/workspace/.claude/skills/` |

It runs at once, with no approval step. You do not need to know the tool's name: when a task needs one the agent lacks ("make a chart", "read this QR code"), it says which tool and why. If you are a super-user, it installs it then and there. If you are not, it says that a super-user can ask for it. It never installs system packages (`apt`); those need a pull request to the image.

**What the owner sees.** A private Telegram message after every install: "🧰 Installed: COMMAND". Every install is also a line in `/data/tools.json` (when, the tool, the command). Ask "What have you installed?" to see the list.

**Only that agent.** An install applies to the agent that ran it. To have it on other agents, the super-user asks each of them; there is no fleet-wide install.

**Google Docs.** A document shared by link is downloaded through its export address; a private one needs the Google connector, which this deployment does not enable.

**After a restart or a new image.** Everything lives on the volume, so it stays. At every start, `start.sh` makes the Python environment if it is missing and reinstalls the recorded `uv pip install`, `uv tool install` and `bun add -g` lines, except what was uninstalled afterwards (uninstalls are recorded too). A line that fails is logged and the start goes on. Other kinds of commands are never replayed.

**API keys never go through chat.** If a tool needs one (ElevenLabs does), the owner sets it as a host variable.

**What it is.** A record and a notice, not a sandbox: the agent's judgment decides, and you see the result. Its limits are in [THREAT-MODEL.md](THREAT-MODEL.md). System packages (`apt`) still only arrive through a pull request to the image ([What the image contains](#what-the-image-contains)).

### Files on the volume

| File | What it is | Who writes it |
|---|---|---|
| `/data/workspace/CLAUDE.md` | This agent's own lasting instructions: name, role, tone | The agent, when you ask ("note in your CLAUDE.md that …") |
| `/data/workspace/MEMORY.md` | What it remembers | The agent, and the nightly dream ([MEMORY.md](MEMORY.md)) |

The rules common to every agent (`/etc/claude-code/`) come with the image and cannot be changed from inside.

## What the image contains

The image is built for 64-bit Intel and AMD (`linux/amd64`); ARM servers and Apple Silicon Macs are not supported.

Every agent gets these, ready for its skills:

| Tool | Made by | For |
|---|---|---|
| Python 3 (`python3`) | Python Software Foundation | Most skills: PowerPoint, Excel, PDFs, charts, ElevenLabs and other APIs |
| `uv`, `uvx` | Astral | Installing Python packages and tools, fast and isolated (pinned by version and checksum) |
| `pdftotext` and the rest of `poppler-utils` | Poppler (freedesktop.org) | Reading PDFs |
| `pandoc` | John MacFarlane and contributors | Quick Word, Markdown and HTML from text |
| `python-docs`: Python with `openpyxl`, `python-docx`, `python-pptx` | Open-source projects of those names | Making Excel, Word and PowerPoint files with layout |
| `typst` | Typst GmbH | Making PDFs, with its own fonts, no LaTeX |
| `markitdown` | Microsoft | PDF, Word, Excel, PowerPoint, HTML and CSV to text |
| `unzip` | Info-ZIP | Opening zip files and skill packages |
| Time zones (`tzdata`) | IANA | Jobs and logs in the `TZ` you set; already in the Debian base |

Also there: Bun (JavaScript and TypeScript), `git`, `jq`, `curl`, `rclone`, `age`, `supercronic`; Claude Code only in the agent image, never in the published `base` ([PRODUCT-IMAGE.md](PRODUCT-IMAGE.md)). Other Python packages are not in the image: they are installed per agent.

## The optional stack: voice and video

Not in the image, because both carry FFmpeg under the GPL; downloaded by each agent from their own projects, they are not distributed by this project. When you or a super-user ask ("learn to listen to voice notes", "learn to work with video"), the agent installs them exactly as [`policy/stack.md`](../policy/stack.md) says, with pinned versions; CI runs those recipes as written.

| Part | What it is | First install |
|---|---|---|
| Voice notes and audio | Whisper `small` (`whisper-ctranslate2`), offline once installed. The first voice note from you or a super-user installs it, then gets its answer | A few minutes; about 700 MB |
| Video | `ffmpeg`, the static build `imageio-ffmpeg` carries | Under a minute |

Like any install, it lives on the volume: it survives restarts, redeploys and new images, is told to you, and is put back at start if it ever went missing. Only deleting the volume removes it.

## Updates, and how to go back

Everything updates on its own once it is set up (below); nothing is left behind. What changes is tested before an agent gets it, and going back is one step.

| Part | How it updates | How to go back |
|---|---|---|
| **Claude Code** | Its **stable channel**: a release about a week old that skips the ones with major regressions (Anthropic's [setup page](https://code.claude.com/docs/en/setup)). Renovate opens a pull request when it moves; CI builds the image, checks that Claude Code installs and runs, and runs every test; only then is it merged and the host builds it. **Never below 2.1.319**: the policy needs it (an older Claude Code would ignore the setting that keeps an unattended agent from waiting on a prompt), so while the channel is behind, the agent stays on 2.1.319 | On the host, set `CLAUDE_CODE_VERSION` to the previous version (for example `2.1.322`) and redeploy. A version below 2.1.319 fails the build, and the host keeps the deployment it had. Remove the variable to follow the channel again |
| **Telegram plugin** | Every build takes its latest version (the official marketplace cannot be pinned). If it does not install, the build fails and the host keeps the previous deployment; CI also tries it every week | The host's rollback to the previous deployment (on Railway: the deployment's **Rollback**) |
| **Tools in the image** (uv, Typst, markitdown, the base image…) | Renovate pull requests, tested by CI, merged when green | Revert that pull request |

**Who does the updating: Renovate.** [Renovate](https://docs.renovatebot.com) is a free GitHub app that watches every version this project pins (Claude Code, uv, Typst, supercronic, the Python packages, the base image, the CI actions, the optional stack). When one moves, it opens a pull request with the new version, and its checksum where there is one; CI builds the image and runs every test; Renovate merges it only if all of that is green. Its settings are in [`renovate.json`](../renovate.json). A pull request that fails stays open, and nothing reaches the agents.

- **On Railway, one more step makes it reach the agent by itself.** Railway deploys a commit on its own only when the GitHub user who pushed it has a Railway account; a commit that Renovate merges waits on the service's page under "Deploy this commit from an external contributor?" until someone clicks **Deploy**. To skip that, let GitHub deploy it after CI passes ([`deploy.yml`](../.github/workflows/deploy.yml)), once:
  1. Railway → your project → **Settings → Tokens** → create a token for the environment (usually `production`).
  2. GitHub → this repository (or your copy) → **Settings → Secrets and variables → Actions**: a secret `RAILWAY_TOKEN` with that token, and a variable `RAILWAY_SERVICE_IDS` with the id of each agent's service, separated by spaces (the id is in the service's address: `…/service/<id>`).
  3. Check it once: **Actions → Deploy to Railway → Run workflow**, and the agents redeploy without asking.

  Without these, the workflow does nothing, and each update waits for your click. Someone who deployed from the one-click template gets a notice from Railway when there is an update and chooses when to apply it; Railway does not let a template apply updates by itself.
- **On your own server**, whoever looks after it applies updates ([DEPLOY-LINUX.md](DEPLOY-LINUX.md#updates-and-going-back)).
- **If you deploy from your own copy (fork) of this repository**, install Renovate on it as well ([github.com/apps/renovate](https://github.com/apps/renovate), "only select repositories"), or your copy stays on the versions of the day you copied it.
- **What CI can and cannot tell.** It proves that a new Claude Code installs and runs and that a new plugin installs, and every tool is used for real in the tests; it cannot prove that the agent answers on Telegram, which needs a live bot. That is what the notice below, and going back in one step, are for.

After every change you get a private notice: "🔄 Versions changed: Claude Code 2.1.322, Telegram plugin 0.0.7 → Claude Code 2.1.325, Telegram plugin 0.0.8". If the agent misbehaves after one, that notice tells you what to go back to.

## If something is wrong

| Symptom | Likely cause |
|---|---|
| "typing…" and no answer | Claude credential truncated or expired (see the start log) |
| No reaction at all | Wrong bot token, or variables not deployed. The log says `Telegram rejected TELEGRAM_BOT_TOKEN` for a bad token |
| Silent in a group | The bot was added before privacy mode was disabled, or the group id changed when it became a supergroup ([GROUPS.md](GROUPS.md)) |
| It does not remember something from yesterday | The nightly memory left it out. Ask "What do you remember about …?", and say "Remember that …" for what must stay ([MEMORY.md](MEMORY.md)) |
| A job's answer came to you instead of the group | The agent is no longer in that group; tell it to join again |
| It refuses to send a file | The file is outside its workspace; ask it to copy what you need there, if it is not a credential |
| It never sleeps although sleep is on | The log says `not sleeping: Telegram did not accept the webhook`: the public address is missing or wrong ([SLEEP.md](SLEEP.md)) |
| "⚠️ Claude plan limit: weekly 86% used" | The subscription is nearly used up; past 100% the agent stops answering until it resets. Several agents on one subscription share the limit |
| "My Telegram channel was down … Restarting" | The watchdog saw the plugin gone and restarted Claude; one message is normal, a stream of them is a bug to report |
| Something broke right after "🔄 Versions changed" | Go back to the previous version ([Updates, and how to go back](#updates-and-how-to-go-back)) and tell the project |
