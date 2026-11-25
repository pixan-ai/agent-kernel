# Product manual

What agent-kernel is, why it exists, who it is for, and every feature explained. For installing it, see [GETTING-STARTED.md](GETTING-STARTED.md); for running a fleet of agents, [FLEET.md](FLEET.md); for how it works inside, [ARCHITECTURE.md](ARCHITECTURE.md).

## In one paragraph

agent-kernel is a personal AI agent that lives in Telegram and works 24 hours a day. You write to it like to a person; it answers, reads what you send, makes documents, searches, remembers, runs tasks on a schedule, takes part in groups and keeps an eye on its fellow agents. It is official Claude Code, Anthropic's coding agent, with Anthropic's official Telegram plugin and a policy file, in one container. What this project adds is small on purpose: **247 lines of Bash** and a set of instructions in Markdown. Apache-2.0, free, run on your own accounts.

## Why it exists

Claude Code can already receive Telegram messages through Channels, but only inside a live, interactive session on someone's computer. Making that session an agent that is always on usually means one of two things:

- **A custom agent built on an SDK:** thousands of lines of your own code to write, secure and keep up to date with every model and tool change.
- **A terminal multiplexer and a supervisor:** fragile glue that breaks silently.

agent-kernel takes a third path: run the official tools as they are, in a container, and add only what they lack to be an agent that stays up by itself: a terminal for the session, a few hooks, a watchdog, scheduled jobs, memory and sleep. Every improvement Anthropic makes to Claude Code reaches the agent with no work from us.

**The promise:** "This is official Claude Code with its official Telegram plugin. We only added a few lines of Bash and rules in Markdown." Anything that would break that promise is out of scope: no patched plugin, no custom agent loop, no hidden service.

## Who it is for

| | Who | What they get |
|---|---|---|
| **Individuals** | Professionals and technical people who want their own assistant on their phone, on their own Claude subscription | One agent, installed in about 20 minutes on Railway or their own server, with a prompt that lets their own AI assistant guide them |
| **Teams and companies** | Small teams that want several agents, each for a person or a role, that see each other and report in a shared group | A fleet on their own server or Railway account, with a Console API key and a weekly human review |
| **Builders and learners** | People who study or build agents | A small, readable reference: the whole agent layer fits in 247 lines, with every decision and lesson written down |

It is **not** for: anyone who needs a hard sandbox around the agent (see the [threat model](THREAT-MODEL.md)), multi-tenant hosting of strangers' agents, or regulated workloads that need an audited product.

## What makes it different

- **Only official components.** Claude Code and the Telegram plugin are Anthropic's, installed with Anthropic's installer during your own build. The published image carries no Anthropic software.
- **Small enough to read.** 247 lines of Bash, held by a test. Behaviour lives in Markdown you can read and change.
- **Yours.** Your Claude key, your bot, your host, your data on your volume. Nothing goes through Pixan.
- **Honest about its limits.** A published threat model, a list of what is verified and what is not, and the lessons from earlier fleets.
- **Verifiable.** Signed images with an SBOM and provenance, an OpenSSF Best Practices badge (passing), an OpenSSF Scorecard, and a test for every change.

## Features

### Talking to it on Telegram

The agent receives every private message from its owner and answers with Telegram's own tools: text, replies, reactions, edited messages and files. It reads photos, documents and voice notes you send. A private message from the owner always gets an answer on Telegram: if a turn ends without one, the agent is sent back once to send it, and if it still does not, what it wrote is sent for it. Details: [GETTING-STARTED.md](GETTING-STARTED.md), and why: [LEARNINGS.md](LEARNINGS.md).

### Memory: the daily dream

A conversation that never ends gets more expensive with every message. Once a day the agent "dreams": a separate, short Claude reads the day's conversation and writes what matters into `MEMORY.md` and a daily file; the next conversation starts clean and reads that memory. Tell it "remember that …" for anything that must stay. Details: [MEMORY.md](MEMORY.md).

### Scheduled jobs

"Send me a summary of … every day at 8": the agent schedules the job itself, in the owner's time zone, and the answer reaches the owner or a group. Jobs survive restarts and updates because they live on the volume; one-off reminders remove themselves once delivered. The agent remembers what its jobs sent, so you can ask about it. Details: [CRON.md](CRON.md).

### Groups and super-users

Told to join a Telegram group, the agent reads and answers everyone there, people and bots, without needing a mention, and stays silent when a message is for someone else. Super-users, named by the owner, can give it instructions in its groups; everyone else can ask for ordinary work. Details: [GROUPS.md](GROUPS.md).

### Settings by chat

Groups, super-users, fellow agents and jobs are set by telling the agent; it applies the change at once and sends the owner a private notice every time, whoever asked. Details: [SETTINGS.md](SETTINGS.md).

### Fellow agents

Agents can look at each other: the screen, the status and the recent conversation of a fellow agent, and set its groups and super-users, over SSH with a forced command. It is opt-in and works on Railway's private network or a shared Docker network on your server. Details: [PEERS.md](PEERS.md).

### Documents and tools

Every agent can read PDF, Word, Excel, PowerPoint and HTML, and make Excel, Word, PowerPoint and PDF files. The owner or a super-user can have it install more: Python packages, command-line tools and Claude skills, kept on the volume and reinstalled after an update. The owner is told of every install. Voice notes and video are an optional stack the agent installs on first use. Details: [GETTING-STARTED.md](GETTING-STARTED.md#self-improvement-installing-skills-and-tools).

### Sleep when idle

An agent always listening to Telegram looks busy to its host and is billed around the clock. With sleep on, it stops after a few quiet minutes and asks Telegram to wake it with the next message; on Railway with Serverless, it then costs almost nothing until someone writes, and wakes in a few seconds. Details: [SLEEP.md](SLEEP.md).

### Watching itself

A watchdog restarts Claude if the Telegram channel dies while Claude keeps running, tells the owner when a message waits more than ten minutes, and warns before the Claude plan limit runs out. After a downtime, the owner is told what did not run. When Claude Code or the plugin changes version, the owner is told, with how to go back.

### Backups

Opt-in. Every night the memory, conversations, workspace, settings and jobs are packed, encrypted inside the container, and sent to storage the owner controls (Google Drive, Cloudflare R2 and others). An empty volume restores the latest backup at start. Details: [BACKUP.md](BACKUP.md).

### Installing it

One click on Railway with a template, or Docker Compose on any amd64 Linux server. A prompt for your own AI assistant walks a newcomer through either path without ever asking for a key in the chat. Details: [SETUP-WITH-AI.md](SETUP-WITH-AI.md), [DEPLOY-RAILWAY.md](DEPLOY-RAILWAY.md), [DEPLOY-LINUX.md](DEPLOY-LINUX.md).

### Fleets and a supervisor

On a Linux server, one agent chosen by the owner can create the fleet's other agents when asked: the owner confirms a new bot in Telegram, and the supervisor gets its token, starts it and supervises it. The server fixes each new agent's owner and Claude key, and only lets the supervisor start agents, not stop them. It is built from host configuration and instructions, with no new code in the agent. Details: [FLEET.md](FLEET.md).

### Security

A root-owned managed policy that the agent cannot change, deny rules for credentials, Claude Code's permission classifier, hooks that tell the owner about every change to the agent's tools and settings, and a container that drops to an unprivileged user. It is not a sandbox, and the documentation says exactly where the protection is code and where it is the model's judgment. A weekly human review is required. Details: [THREAT-MODEL.md](THREAT-MODEL.md), [SECURITY.md](../SECURITY.md).

## What it costs to run

The software is free. The person running it pays their own providers directly:

- **Claude:** a Pro or Max subscription for a personal agent, or a Console API key billed per use for an agent that serves groups or clients ([which one](https://code.claude.com/docs/en/legal-and-compliance)).
- **Host:** Railway bills by use (an agent that sleeps costs very little while idle); your own server costs what it already costs.
- **Telegram:** free.

## What is next

- More hosts for the one-click path, and ARM images. See the [roadmap](ROADMAP.md).
- See the [CHANGELOG](../CHANGELOG.md) for what changed and why.

The business model canvas is in [BUSINESS-MODEL-CANVAS.md](BUSINESS-MODEL-CANVAS.md).
