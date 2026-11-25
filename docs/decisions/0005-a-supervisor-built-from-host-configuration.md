# 0005. A supervisor built from host configuration

**Status:** Accepted (2026-11-25), after a lab on a Linux server. Built in `host/launchpad/`, explained in [FLEET.md](../FLEET.md).

**Decision.** On a Linux server, one agent chosen by the owner (`ENABLE_SUPERVISOR`) can create the fleet's other agents and supervise them. The privilege it needs is granted by host configuration the owner installs once (a systemd template, a narrow SSH channel with a small root-owned wrapper and a `sudo` rule, held to 100 lines apart from `bin/`), not by new code in the agent. The supervisor does the rest by its instructions: it asks the owner to confirm a Telegram Managed Bots link, gets the new bot's token, writes the new agent's `.env` and asks for the start. The host fixes the owner and the Claude key, so a persuaded supervisor cannot create an agent for someone else.

**Why.** It keeps the promise of 0001 and 0002, and the owner's confirmation in Telegram stays the approval for every new agent.

**Cost.** The supervisor holds the manager bot's token, which can replace the token of every bot it created; one Claude key serves the fleet, so an agent cannot be revoked or measured on its own; Bot-to-Bot on by default can make agents talk in loops. Accepted by the owner. Not for Railway, where a link to the template is used instead.

**What the lab measured (2026-11-25).** A forced command that puts the name in a shell line can be injected, so a wrapper treats it as data. Compose reads a `.env` from the project folder for interpolation, so the fleet uses a dedicated clone with an empty `.env` and root's `--env-file`. `environment:` wins over the agent's file. `AssertPathExists` fails a start without the agent's file; a `Condition` exits 0. `systemctl` reports success for a start that did not happen, so the exit code is what counts. Telegram's `managed_bot` update did not always arrive; the `managed_bot_created` message did.
