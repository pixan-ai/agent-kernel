# Roadmap

What is planned, what is being looked at, and what the project will not do. It changes as installations teach us; the [CHANGELOG](../CHANGELOG.md) says what was actually done.

## Planned

- **A supervisor agent for fleets on a Linux server.** One agent, chosen by the owner with `ENABLE_SUPERVISOR`, creates the fleet's other agents (bot included, through Telegram's Managed Bots) and supervises them. It is built from host configuration (a systemd template and a narrow channel the owner sets up) and instructions, with no new code in the agent. Being measured on a lab server.
- **A fleet guide** for teams and companies: installation, the supervisor, keys, groups, the weekly review and privacy.

## Being looked at

- A stronger isolation on servers whose Docker allows user namespaces (Claude Code's sandbox and environment scrub), with the seccomp profile it needs.
- Hosts other than Railway for the one-click path.
- ARM images (Raspberry Pi, Apple Silicon).

## Will not do

- Patch Claude Code or the Telegram plugin, or write a custom agent loop: the project runs the official tools as they are.
- Grow the agent beyond its budget of 247 lines of Bash without removing as much.
- Host agents for others, or sell plans, services or add-ons.
- Ask for a key in a chat, or keep anyone's keys.
