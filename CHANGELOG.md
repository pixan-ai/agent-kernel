# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
