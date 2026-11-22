# Deploy and Host Pixan agent on Railway

Pixan agent is a Claude Code-based 24/7 personal agent on Telegram, in one container, using only official components: the Claude Code harness, the official Telegram channel plugin and a managed policy file. It has memory, scheduled jobs, groups and fellow agents, with less than 300 lines of Bash. Open source, Apache-2.0.

## About Hosting Pixan agent

Pixan agent runs as one service with a volume at `/data`, where it keeps its memory, settings, jobs and installed tools across restarts and redeploys. Railway builds the image from the repository's Dockerfile, which installs Claude Code with Anthropic's official installer during your own build. You paste three values (your Claude key, your Telegram id and a new Telegram bot token), deploy, and message your bot; the first build takes several minutes. The plugin answers `/start` with pairing instructions: ignore them, the owner needs no pairing. The service restarts on its own if the agent stops, and a watchdog tells you on Telegram if the channel dies or a message goes unanswered.

## Common Use Cases

- A personal assistant on Telegram that remembers: every night it consolidates the day into its memory.
- Scheduled jobs set by chat (reminders, daily summaries), delivered to you or to a group.
- A helper in your Telegram groups: members ask for ordinary work; you and the super-users you name run it.
- Reading and making documents: PDF, Word, Excel and PowerPoint.

## Dependencies for Pixan agent Hosting

- A new Telegram bot: talk to @BotFather, `/newbot`, and copy its token. Use a bot that nothing else polls.
- Your numeric Telegram id: ask @userinfobot.
- A Claude key, in one field whatever its kind: run `claude setup-token` on your computer for a personal agent on your Claude subscription, or create an Anthropic Console API key for an agent that serves groups or clients.

### Deployment Dependencies

- Source, docs and issues: https://github.com/pixan-ai/agent-kernel
- Step-by-step guide: https://github.com/pixan-ai/agent-kernel/blob/main/docs/GETTING-STARTED.md
- What it protects and what it does not: https://github.com/pixan-ai/agent-kernel/blob/main/docs/THREAT-MODEL.md

## Why Deploy Pixan agent on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Pixan agent on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

Railway tells you when the template has an update, tested by the project's CI, and you apply it when you choose; going back is one click with Railway's Rollback.
