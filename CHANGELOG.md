# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- An agent could show "typing…" and never answer: it wrote the answer in its own terminal and sent nothing (seen live on a new agent, 2026-11-22). Claude Code defers MCP tools by default, so in each new session the model had to search for the Telegram reply tool before its first answer; a session that did not search never saw it. The image now sets `ENABLE_TOOL_SEARCH=false`, which loads the tools upfront, and the managed instructions say that an answer exists only when it is sent with the reply tool.
- A model that has the reply tool can still answer a message in its terminal, a greeting most of all, and no watcher noticed: the agent was alive and the turn ended. A private message from the owner now always gets an answer on Telegram: a turn that ends without sending is sent back once to use the reply tool, and if it ends again without sending, the agent sends what Claude wrote (`bin/unsent.sh`, three hooks). Groups are left alone: there, silence is often right.
- A subscription token pasted into the API key field left an agent mute, waiting for an organization's policy (seen live, 2026-11-22). The Claude key is now one field, `CLAUDE_KEY`, whatever its kind: the agent tells by its start (`sk-ant-oat01-` subscription, `sk-ant-api03-` Console) and stops, saying so, on anything else. `CLAUDE_CODE_OAUTH_TOKEN` and `ANTHROPIC_API_KEY` still work; `CLAUDE_KEY` wins over them.
- Sleep (audit of 2026-11-21, L3): the check that the public address reaches this agent accepted any 403, so something else in front of it (a CDN, another service) could pass it and the agent would sleep for ever. The listener now answers with a code made new for each sleep, and the agent checks that code.
- **Security** (audit of 2026-11-21, L6, L8): `railway ssh` opens a root shell in the agent's container; DEPLOY-RAILWAY.md and the threat model now say so and how to drop to the agent's user first. CI checks that every folder on `PATH` before the agent's own is root's alone and that none of the system's comes after them (a `PATH` like `/usr/bin:/data/bin:/usr/local/bin` passed before), and the docs check covers every spelling of `docker exec` and `railway ssh`.
- **Security** (audit of 2026-11-21, L1, L2): `deploy.yml` could be run by hand from any branch, deploying untested code, and that branch could read the Railway token. The token now lives in a GitHub environment, `railway`, that only `main` may use, and nothing from the repository is checked out. Two deploys no longer run at once (a second one waits), and a service that fails to deploy fails the run instead of being hidden by the next one. Whoever set up the token moves it into that environment (GETTING-STARTED.md).
- A bot token with a space inside (pasted from a phone) survived the trim, and the bot went mute with no error. `start.sh` now stops saying the token does not look like one from @BotFather, without printing it (audit of 2026-11-21, L7).
- Sleep: an agent that could not sleep (no public address, a webhook Telegram refused, an address that does not reach it) only said so in the log, so it stayed awake and billed without anyone knowing (seen 2026-11-21). It now also tells the owner on Telegram, with the reason, once per start.
- Sleep: with Serverless off the host keeps a sleeping agent running and billed, and the agent cannot read that setting. Asleep for 30 minutes without the clock jump a suspension leaves, and with no scheduled jobs, it now tells the owner to turn Serverless on, once per start.

### Added

- `docs/SETUP-WITH-AI.md`: a prompt to paste into Claude, Grok or another assistant, which walks a newcomer through the installation on Railway or on their own Linux server, one step at a time, never asking for a key in the chat. It carries the traps people met this week and quotes the agent's start-up errors; a docs test keeps those quotes in step with `bin/start.sh`.

### Changed

- In a group, a message that starts with another agent's name or @username is not answered by the others, also when the names differ by one letter, and a wrong answer is not followed by an apology: being silent is the answer. Three agents in one group had answered a message for one of them, then two apologised (seen live, 2026-11-24). It is still an instruction, not a mechanism; GROUPS.md says what helps: names that cannot be confused, the @username, and one agent as the voice for messages to everyone.
- Asked for its address, for a fellow agent, an agent now gives its Railway private address (`RAILWAY_PRIVATE_DOMAIN`). Two agents of one project had given an IP and a container id, which change at every deploy, or said they did not know (seen live, 2026-11-24). PEERS.md and the guide say where to find the address and how to ask for it.
- The guide says how long until Railway shows Sleeping: the agent's `IDLE_SLEEP_MINUTES`, then about 10 minutes of Railway's own; about 13 minutes with the template.
- The one click a Railway template cannot do, switching Serverless on, is now a numbered step in the guide and is said on the template's page and in the description of `IDLE_SLEEP_MINUTES`. A fourth way to have the template set it was tried and does not work (docs/SLEEP.md).
- The scripts now have a budget: 247 lines of code, held by a test (it was "less than 300"). They went from 277 to 247 with no change in behaviour: statements were joined, no function was removed, and every test passes unchanged.
- The Railway template asks for three values in order, each saying where to get it: `CLAUDE_KEY`, the owner's id, the bot token. Railway had listed the optional Claude fields out of sight.
- CONTRIBUTING.md: a pull request's title says what changes for whoever runs an agent, since hosts show it; audit codes go in the description.
- RELEASING.md says that a release also moves the image's `latest` tag (not for a pre-release).
- The Railway template sleeps when idle: it sets `IDLE_SLEEP_MINUTES` to 3 and a public domain on port 8080. Serverless, the one switch a template cannot set, is turned on by whoever deploys; the guide says so.
- README shows the OpenSSF Best Practices badge ("passing", project 16964, 2026-11-20) and status 1.1; RELEASING.md describes publishing a release from the GitHub web page, as 1.0.0 and 1.1.0 were.

## [1.1.0] - 2026-11-21

### Fixed

- **Security** (audit of 2026-11-21, A3): an administrator's `docker compose exec` runs as root, and the agent's own bin folder came first on `PATH`, so a program the agent planted there could run as root. The agent's folders now come last on `PATH`, and the guide always uses `--user 1001`. A space inside the owner id is no longer removed but reported as a typo (L4); the guide no longer says updates reach every host on their own (L5).
- The guide said `TZ` defaults to UTC without saying that the Railway template sets `America/Mexico_City` (audit of 2026-11-21, B3).
- Sleep (audit of 2026-11-21, M3): Telegram accepts a webhook to an address that does not reach the agent, such as a domain pointed at the wrong port; the agent then slept for ever and no one was told. Before sleeping it now calls itself through that address, and if its own listener does not answer it removes the webhook, stays awake and says so in the log.
- A mistyped owner id (a username, or a line break pasted with it) left the bot mute with no error; a deployment without a volume lost its memory, settings and jobs at every redeploy without a word. `start.sh` now removes whitespace from the owner id and the bot token, stops on an owner id that is not a number saying what to use, and warns the owner when `/data` is not a volume (audit of 2026-11-21, M1, M2). The guide says how each kind of installation receives updates.
- **Security** (audit of 2026-11-21, A1, A2, B5): an agent could make the next start, which runs as root, act on what it had planted. A symlink at `/data/workspace` handed its target (for example the managed policy) to the agent, and a program in its own bin folder, first on `PATH`, ran as root. While root, `start.sh` now uses only the system's programs (fixed `PATH`; `tini` and `start.sh` by absolute path, `#!/bin/bash`), changes ownership without following symlinks, and drops to uid 1001 with no new privileges. CI starts the image's real entrypoint and checks the published `base` image stays non-root (B4).
- An agent deployed without `RAILWAY_RUN_UID=0` crashed at start with only "Permission denied" (seen on the template's first live test, 2026-11-20). The image now starts as root, gives the volume to the agent's user and drops to it before anything else, so no variable is needed; started as another user, it stops and says what to change.

### Added

- Updates reach a Railway agent by themselves (decided 2026-11-21): Railway holds a commit merged by Renovate for approval, so `.github/workflows/deploy.yml` deploys it after CI passes, with a project token set as a repository secret. Without the token it does nothing. The guide no longer says updates reach the host on their own without this step (audit of 2026-11-21, M4).
- `docs/DEPLOY-LINUX.md`: running an agent on a company's own Linux server with Docker (install, day-to-day commands, updates and going back, backups), and the stronger isolation such a server may allow, marked as not tested yet.
- A one-click Railway template, `pixan-agent` (https://railway.com/deploy/pixan-agent): the service, the volume and the variables with their descriptions, so a deployer only pastes three values. Its overview lives in `docs/railway-template-overview.md`; `docs/DEPLOY-RAILWAY.md` records its settings, Railway's limits and how it was made.

### Changed

- `SECURITY.md` links the private reporting form, the releases and Anthropic's disclosure policy, and no longer speaks of releases to come. The Dockerfile says why the official installer is not pinned by hash.
- The project describes itself as a "Claude Code-based 24/7 personal agent on Telegram", the same in the README, the GitHub description, the Railway template and Docker Hub.
- The base image is published (decided 2026-11-19): to GitHub's registry and to Docker Hub as `pixan/agent-kernel`, without asking Anthropic in writing, since it carries no Anthropic software (docs/PRODUCT-IMAGE.md).

## [1.0.0] - 2026-11-19

First stable release. The detailed history of how it got here is in [docs/history/CHANGELOG-before-1.0.md](docs/history/CHANGELOG-before-1.0.md).

### What an agent does

- **Claude Code, official and unmodified, on Telegram 24/7** in one container: the official Telegram channel plugin and a managed policy, with less than 300 lines of Bash.
- **Talks to its owner in private, and to groups**: in a group every member may ask for ordinary work; the owner and the super-users they name by chat run the agent.
- **Remembers**: every night a dream consolidates the day into `MEMORY.md` and a dated file, and the next conversation starts clean.
- **Scheduled jobs by chat**, delivered in private or to a group; one-off reminders remove themselves; job notices can be turned off.
- **Documents out of the box**: reads PDF, Word, Excel, PowerPoint, HTML and CSV; makes Excel, Word, PowerPoint and PDF files. **Voice notes and video** from an optional stack, installed the first time the owner sends one.
- **Installs tools and skills** when the owner or a super-user asks, and keeps them across restarts.
- **Fellow agents**: a read-only view of each other over SSH, and groups and super-users set across agents.
- **Runs unattended**: optional sleep when idle, nightly encrypted backups, and a watchdog for a dead channel, an unanswered message and plan limits.

### How it stays safe

- The managed policy is the only one (`allowManagedHooksOnly`, `allowManagedPermissionRulesOnly`); nothing waits for a prompt (`denyInsteadOfPrompting`, which needs Claude Code 2.1.319 or later: an older one fails the build); auto mode refuses to leak credentials; the advisor is on.
- The owner is told of the changes the [threat model](docs/THREAT-MODEL.md#installs-and-settings-told-not-locked) lists: settings, installs, version changes, and changes made by hand to the files that steer the agent (its settings and jobs, the workspace's Claude settings, `CLAUDE.md` and MCP servers, the install record). What is not seen, such as a deletion, is listed there too. Notices follow the owner id set on the host.
- The agent decides by its instructions and judgment; code does not guess commands. What that leaves open is written in the [threat model](docs/THREAT-MODEL.md), with evidence labels.
- Three external reviews (one on 2026-11-17, two on 2026-11-18) were addressed before this release.

### How it stays current

- Claude Code follows its stable channel, never below 2.1.319. Renovate updates every pinned version by pull request, merged only when CI is green; going back is `CLAUDE_CODE_VERSION` on the host.
- The owner is told at start when Claude Code or the plugin changed version.
- The publishable `base` image carries no Anthropic software, ships `THIRD-PARTY.md`, and is checked, scanned, signed and attested before its version tags are published (publishing is locked until the owner turns it on).

### Where it runs

- Railway (the reference deployment) and Docker on any amd64 host.
