# 0005. A supervisor built from host configuration

**Status:** Proposed (2026-11-25). Being measured on a lab server.

**Decision.** On a Linux server, one agent chosen by the owner (`ENABLE_SUPERVISOR`) can create the fleet's other agents and supervise them. The privilege it needs is granted by host configuration the owner installs once (a systemd template, a narrow SSH channel with a small root-owned wrapper and a `sudo` rule), not by new code in the agent. The supervisor does the rest by its instructions: it asks the owner to confirm a Telegram Managed Bots link, gets the new bot's token, writes the new agent's `.env` and asks for the start. The host fixes the owner and the Claude key, so a persuaded supervisor cannot create an agent for someone else.

**Why.** It keeps the promise of 0001 and 0002, and the owner's confirmation in Telegram stays the approval for every new agent.

**Cost.** The supervisor holds the manager bot's token, which can replace the token of every bot it created; one Claude key serves the fleet, so an agent cannot be revoked or measured on its own; Bot-to-Bot on by default can make agents talk in loops. Accepted by the owner. Not for Railway, where a link to the template is used instead.
