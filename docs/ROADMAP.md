# Roadmap

What is planned, what is being looked at, and what the project will not do. It changes as installations teach us; the [CHANGELOG](../CHANGELOG.md) says what was actually done.

## Planned

- **The supervisor, end to end:** verify on a real server that it creates an agent by itself from a chat request, and the update path for a fleet.
- **A way to give one fleet agent its own Claude key** without leaving the supervisor's flow.

## Being looked at

- A stronger isolation on servers whose Docker allows user namespaces (Claude Code's sandbox and environment scrub), with the seccomp profile it needs.
- Hosts other than Railway for the one-click path.
- ARM images (Raspberry Pi, Apple Silicon).

## Will not do

- Patch Claude Code or the Telegram plugin, or write a custom agent loop: the project runs the official tools as they are.
- Grow the agent beyond its budget of 247 lines of Bash without removing as much.
- Host agents for others, or sell plans, services or add-ons.
- Ask for a key in a chat, or keep anyone's keys.
