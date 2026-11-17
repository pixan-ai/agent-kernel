# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [Semantic Versioning](https://semver.org/) once the first release is tagged.

## [Unreleased]

### Fixed

- A job whose delivery Telegram refused (the bot removed from the group, a group renumbered) was recorded as sent and nobody was told. It is now sent first, recorded only if it went, and the owner is told otherwise.
- The agent could widen its own policy: a settings file of its own (`/data/config/settings.json`, `/data/workspace/.claude/settings.json`) could add hooks and `allow` rules, which Claude Code merges with the managed ones. The policy now sets `allowManagedHooksOnly` and `allowManagedPermissionRulesOnly`.
- A scheduled job or the dream started and ended the "message waiting" mark of the main conversation: a job's end of turn erased a real waiting message (no alert after ten minutes), and a long job raised a false one. Both hooks now skip the jobs' own sessions.

### Changed

- Documents, after the audit of 2026-11-17: which Claude credential to use (a subscription for a personal agent, an API key for an agent that serves groups or clients); the threat model now covers backups, fellow agents, super-users, memory, jobs, the doorbell and group privacy; the secrets left in the start environment are stated; amd64 only; no mention of any business.

## [0.1.0] - 2026-11-15

First tagged version. Lab / alpha: what was verified on a real host, and what was not, is at the end of each document under `docs/`.

### Added

- **Every agent makes Excel, Word, PowerPoint and PDF files** (decided 2026-11-15): `python-docs` runs Python with `openpyxl`, `python-docx` and `python-pptx`, and `typst` (pinned by version and checksum, about 40 MB) makes PDFs. CI makes each kind as the agent's user with no network and reads it back. Not through `pandoc --pdf-engine=typst`: the image's pandoc writes a template this Typst rejects.
- **Every agent hears voice notes and reads documents out of the box** (decided 2026-11-15; this reverses the 2026-11-12 decision to keep `ffmpeg` out of the image). The `base` image adds, pinned: `whisper-ctranslate2` with the Whisper `small` model baked in (voice to text, offline), `markitdown` (PDF, Word, Excel, PowerPoint, HTML and CSV to text) and a static `ffmpeg` (video frames). About 1.2 GB more. CI checks them as the agent's user with no network (`tests/media_test.sh`). The agent is told they are there, and how to download a Google Docs link that is shared publicly.
- Guide: what a group member who is not a super-user may ask for (since #74), and that voice notes and documents work with no setup.
- **Plan limits.** The status line keeps the figures Claude Code gives it (5-hour and weekly use of the subscription) and shows them on the agent's screen; the watchdog tells the owner once when one passes 80%. A scheduled job or a nightly dream stopped by a limit now tells the owner why: Claude gives that reason on standard output, which the job's failure notice left out, and a failed dream only went to the log.
- **Install lock** (`bin/install-lock.sh`): only the owner or a super-user can make the agent install packages, tools or skills. A `UserPromptSubmit` hook opens the lock for one turn when the Telegram message comes from a super-user. It reads the sender from the first line the plugin writes, and a turn with a second `<channel` tag gets no lock. A `PreToolUse` hook refuses installs (uv, pip, npm, bun, uvx, `claude plugin`/`mcp`, `/data/bin`, `/data/tools`, the skills folders) while the lock is closed. Jobs and the dream never get it. Each install is recorded in `/data/tools.json` and the owner is told. `start.sh` reinstalls the recorded package lines. Installs go to `/data/tools` and `/data/bin`, after the image's own commands in `PATH`. When a task needs a tool it lacks, the agent says which and why, and installs it if a super-user asked; the managed instructions carry a pinned recipe for `ffmpeg` without root (`imageio-ffmpeg==0.8.1`, linked into `/data/bin`). A guardrail, not a sandbox: see docs/THREAT-MODEL.md.
- Docs: self-improvement is decided, not built yet. Only a super-user can ask an agent to install skills or tools; the install runs at once and the owner is notified afterwards (same as settings); it applies to that agent unless a super-user asks to replicate it. Python 3 will be added to the image. See [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md).
- `docs/LEARNINGS.md`: what long-running agents taught us, in earlier fleets and here, with where each rule is applied. From it: the memory shown at session start ends with `[end of MEMORY.md]`, so a cut is noticed; the dream logs the index size before and after and keeps a pointer into the daily files; CI runs every tool as the agent's own user.
- **Daily dream** (`bin/dream.sh`, `docs/MEMORY.md`): once a day what was said is consolidated into `/data/workspace/MEMORY.md` and the next conversation starts clean, so a session no longer grows for ever. The memory is shown to the agent at every session start. A failed dream leaves the conversation as it was. `docs/MEMORY.md` also describes the daily council: every agent of a team reporting in one Telegram group.
- Opt-in sleep (`IDLE_SLEEP_MINUTES`): Claude stops after a quiet period and a Telegram webhook wakes the agent; the official plugin still receives the message by polling. On Railway with Serverless an idle agent used no memory, and answered 2 to 3 s after a message. See docs/SLEEP.md.
- Unanswered-message alert: a message whose turn has not ended after ten minutes is reported to the owner, once.
- docs/GETTING-STARTED.md: installation for a first-time user, and what to tell the agent afterwards.
- Backup and restore: a nightly backup of memory, conversations, workspace, settings and jobs, encrypted with age inside the container and sent with rclone (Google Drive by default, Cloudflare R2 as an alternative); restore onto an empty volume by setting the private key. See docs/BACKUP.md.
- Watchdog: when Claude runs but the Telegram plugin's process is gone (two checks, five minutes apart), the owner is told and Claude restarts with the conversation.
- The agent knows its own Telegram bot name and id from the first message: the start-up check keeps Telegram's answer and the SessionStart hook states it (seen on Railway: an agent in a group did not know it was being addressed).
- Settings by chat: the agent adds groups, senders and fellow agents itself (`config.sh`), applies them at once and tells the owner every time. A fellow agent can set another's groups over the peer channel. See docs/SETTINGS.md.
- Peer view: `transcript` (the recent conversation of a fellow agent) and names from `PEERS` instead of addresses.
- Telegram groups: `TELEGRAM_GROUP_IDS` and `TELEGRAM_GROUP_SENDERS`; no mention needed in a listed group. See docs/GROUPS.md.
- Peer view (opt-in): a fellow agent holding a listed key can read this agent's screen, status and denials over SSH with a forced command; nothing else. See docs/PEERS.md.
- `procps` in the image: the seeded daily recycle uses `pkill`.
- Scheduled jobs that survive restarts: a crontab on the volume run by Supercronic (pinned), `job.sh` (a prompt in its own Claude session, answer sent to the owner and kept in `sent.md`, alert on failure or timeout), a downtime notice at start, and a daily recycle at 04:00. Claude Code's in-session scheduler is disabled. See docs/CRON.md.
- The agent gets a `CLAUDE.md` in its workspace stating its limits (denied prompts, no credentials, connectors disabled, only `/data` persists). Copied once; the owner can edit the copy.
- Claude Code on Telegram in one container: the official harness in a `script` pty, the official Telegram channel plugin, a root-owned managed policy.
- Credential: a Claude subscription token (`CLAUDE_CODE_OAUTH_TOKEN`) or an API key (`ANTHROPIC_API_KEY`).
- Railway support: volume ownership handled by the entrypoint (`RAILWAY_RUN_UID=0`), screen mirror to the service log (opt-in, see Changed).
- Policy: `denyInsteadOfPrompting` so an unattended agent never waits for a person; deny rules and an auto-mode rule against leaking credentials; hooks that audit and alert the owner on Telegram.
- Acceptance tests for the entrypoint, the diagnostic tools, the policy and the documentation, run in CI inside the built image.
- Documentation: findings, architecture, Railway deployment, threat model, secrets, repository settings.
- Supply chain: every action pinned to a commit SHA (and a test that keeps it so), CodeQL for the workflows, OpenSSF Scorecard, a report-only Trivy scan, and a release workflow that publishes with an SBOM, SLSA provenance, a keyless cosign signature and a GitHub attestation. See [docs/RELEASING.md](docs/RELEASING.md).
- Image: tools for skills in the `base` target: Python 3, `uv`/`uvx` (Astral, pinned by version and checksum), `poppler-utils`, `pandoc`, `unzip` (`tzdata` was already there). CI runs each one as the agent's user. About 300 MB more. `ffmpeg` is left out (about 450 MB more); agents install it when needed. See [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md#what-the-image-contains).

### Changed

- **Groups: anyone may ask for work** (decided 2026-11-15). Seen on a live agent: a group member who was not a super-user asked it to transcribe a voice note and it refused, because its instructions forbade running commands for anyone but the owner and the super-users. Any member may now ask for ordinary work; installing, settings, jobs, fellow agents and private information stay reserved. This widens what a member can make the agent run (`docs/THREAT-MODEL.md`).
- Wording, before v0.1.0: the agent's instructions say "your owner or a super-user" where both may ask (joining a group, looking at a fellow agent, letting two bots talk) and "whoever wrote to you" for the reply language; README and the Dockerfile no longer call the restart policy "the watchdog" now that `watchdog.sh` exists; `PRODUCT-IMAGE.md` records which decisions are taken and which is open; `FINDINGS.md` and `CRON.md` lose two stale statements.
- Docs: stale claims fixed before v0.1.0. Peers can also set groups and super-users; the owner allowlist is private only; installs are locked even in groups; `deny` rules cover file tools only; Serverless only with the opt-in sleep; publishing builds `base` only; the secrets inventory now includes the peer and backup keys.
- **Groups are open.** In a group the agent was told to join it now reads and can answer every member, people and bots, instead of only the owner and listed ids. `TELEGRAM_GROUP_SENDERS` and `config.sh sender` are removed. The agent is told its owner's id at every session start and that only the owner gives instructions; in groups that is an instruction, not a lock (see `docs/GROUPS.md`). Super-users (`config.sh admin ID`) may also give instructions in the groups; the owner or any super-user names them, on this agent or on a fellow agent.
- CI fails when the publishable base image has a fixable CRITICAL vulnerability (Trivy). The agent image, which adds Claude Code and the plugin, stays report-only.
- The agent is shown its recent job deliveries with every message (a `UserPromptSubmit` hook over `sent.jsonl`), instead of being asked to read a file it could skip. `sent.md` is replaced by `sent.jsonl`, written one line at a time.
- Jobs can deliver to a group the agent is in (`config.sh job … GROUP_ID`); the job's session is told it only writes the message; a job's stderr no longer reaches Telegram except in its failure notice to the owner (seen on Railway: a job for a group ended as an error message in private).
- `tini` is PID 1 (SIGTERM reaches the entrypoint); the bot token is removed from the environment before Claude and the scheduler start; a missing `TELEGRAM_BOT_TOKEN` or `OWNER_TELEGRAM_ID` fails at once; `mem_limit` in compose; the start log no longer prints a `whitespace:` field that could only say "no"; tests share `tests/lib.sh`.
- **Security:** scheduled jobs can only be `job.sh NAME` (a prompt run inside Claude under the policy). The agent adds them with `config.sh job`, which tells the owner; any other line in the cron files never runs. The daily recycle moved to the image (`bin/system.cron`), so the agent cannot remove it and updates reach existing volumes.
- `access.json` is replaced atomically.
- Policy: bypass-permissions mode is disabled (`disableBypassPermissionsMode`), and the setting that pre-accepted its warning (`skipDangerousModePermissionPrompt`) is gone.
- Removed `railway.json` (Railway stops reading it on 2026-12-01); the service settings in docs/DEPLOY-RAILWAY.md are the configuration.
- Alert hooks use `notify.sh`: the bot token no longer appears on a command line.
- The audit log records one short line per event instead of the whole event, and keeps its last 10000 lines (it grew without limit and duplicated the transcript).
- Group instructions: a message from the owner to the group in general is answered (seen on Railway: both agents stayed silent on a plain "Hola").
- `config.sh` answers with a confirmation and the resulting groups and senders, so an agent that changes a fellow agent's settings can verify it (seen on Railway: the change worked but returned nothing).
- `access.json` is rebuilt from the variables at every start (it was written only once): changing the owner or the groups is a variable change and a redeploy.
- A restart continues the last conversation (`--continue`). If Claude dies within a minute while continuing, the next start opens a fresh session. A 60-second brake slows crash loops.
- Fix: the Telegram plugin ran from the image's build path (its registry files hold absolute paths), outside the policy's protection, and a newer image could not replace the copy on the volume. Every start now copies the plugin to the volume and points its registry there.
- Fix: the agent could not see photos or files sent on Telegram. They land in the plugin's inbox, outside the workspace, and the first read was denied. The inbox is now an additional working directory (still not writable by the agent).
- The agent's instructions moved to the managed location (`/etc/claude-code/CLAUDE.md`): root-owned, updated with every image, not editable by the agent. The copy seeded earlier in `/data/workspace` is no longer written.
- The Dockerfile has two targets: `base` (no Anthropic software, the only publishable one) and `agent` (default; adds Claude Code and the plugin). The release workflow pushes `base` only and CI verifies it contains no Claude Code.
- Docs: the security level is stated per host (**Railway: soft floor only**) in README and SECURITY.md, with the namespace check for hosts that can do better.
- The base image is pinned by digest; a test fails on an unpinned `FROM`.
- Start-up asks Telegram (`getMe`) once and fails fast on HTTP 401 (revoked or mistyped bot token) instead of leaving the bot mute. A network error does not stop the start.
- **Privacy:** the screen mirror to the service log is now off by default. It contains the owner's conversation, and service logs are visible to anyone with project access. Set `SCREEN_MIRROR=<seconds>` to turn it on while debugging.

### Fixed

- A dream whose Claude ended well without writing anything still started a clean conversation, losing the day with no notice. The dream now counts only if the day's file was written after it started; otherwise the conversation continues, the dream is tried again and the owner is told.
- **Install lock, audit of 2026-11-15** (#67–#76). #68 had narrowed the lock to a list of leading commands, so `/bin/cp`, `command cp`, `cd /data/bin && curl`, a Python `shutil.copy`, `sed -i` and a glob such as `/data/b[i]n` wrote there again. From the shell, any command that names `/data/bin`, `/data/tools` or the skills folders is now refused while the lock is closed, except running what is installed there (with its variables) and reading it; the 🧰 notice still fires only for a package manager or a plain write. Writing `/data/settings`, `/data/cron/jobs` or `/data/cron/prompts` by hand is refused to everyone (`echo "admin 999" >> /data/settings` made a super-user with no notice), and `config.sh admin` or `peer.sh … admin` needs the owner or a super-user. Quotes, escapes and globs no longer hide the lock file or the record. The replay at start takes a line only if every word is a package name, so a forged record cannot install from a URL, an index, a path or `--from`. A dream that keeps failing tells the owner once a day, not at every start or wake. The agent is told to edit its notes with the file tools.
- Guide: a table row broken by #76, the watchdog line in README, the release workflow's comment (the published target has no Claude Code), and "all pinned" in the Dockerfile.
- `screen.sh` returned the agent's screen one word per line: Claude Code places words with cursor-column moves, which were read as new lines. Seen on a live agent; checked against a real Claude Code screen.
- An install the agent chained with other commands on one line (`uv pip install … 2>&1 | tail; cd … && python …`) was recorded but never reinstalled at start, because only a line that was nothing but the install was replayed. Each part of the line is now taken on its own; only the installs are replayed. Seen on a live agent.
- Install lock, seen on a live agent: any command that named `/data/bin` or `/data/tools` counted as an install. With the lock closed the agent could not run an installed tool by its path, list the folder, or write a note that mentioned it; with it open, checking a tool's version was recorded and announced to the owner as an install. The lock now refuses package managers and **writes** into those folders (copy, link, move, download, redirect), not reading or running what is there. The agent may read `/data/tools.json` with the Read tool, which the permissions denied.
- A dream that failed logged no reason: Claude writes it on standard output, which was thrown away. Seen on Railway, where every dream since 2026-11-12 failed with an empty message. The log now carries it.
- A `MEMORY.md` longer than what is shown at session start was cut in silence. The agent is now told it is missing the end and must shorten it; the dream keeps the index under 150 lines and 15000 characters.
- The Telegram reply tool is pre-approved, so nothing reviewed the files it attaches, and its `files` parameter takes any path. A `PreToolUse` hook now refuses attachments from outside `/data/workspace`, `/tmp` and the Telegram inbox (keys, credentials, conversations), also through `..` or a link.
- A job kept posting to a group after `config.sh drop GROUP`, and delivered to whatever its `.to` file said. `job.sh` now checks at delivery time that the destination is a group the agent is in; otherwise the owner gets it.
- The dream reads text that any member of a group may have written, and ran with every tool. It now has only `Read`, `Edit` and `Write`: no shell, no network.
- An agent went to sleep even when Telegram refused the webhook, and then never heard a message. It now stays awake and says so in the log.
- The entrypoint now exits with status 1 and says so when Claude exits (it used to exit with 141).
- The entrypoint fails fast, naming the missing variable, when no Claude credential is set.
- A token copied from a phone with line breaks is cleaned before use.
