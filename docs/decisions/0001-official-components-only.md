# 0001. Only official components

**Status:** Accepted (November 2026).

**Decision.** The agent is Anthropic's Claude Code with Anthropic's official Telegram plugin, unmodified, installed with Anthropic's installer during each user's own build. The project adds scripts and Markdown instructions around them, nothing inside them.

**Why.** Every improvement Anthropic makes reaches the agent with no work from us, and a user can trust the core the same way they trust Claude Code. A patched plugin or a custom agent loop would be ours to secure and keep up forever.

**Cost.** What the official tools do not offer is out of reach or needs a workaround: for example, the plugin's `/start` pairing text cannot be changed, and an answer the model writes in its terminal has to be caught by a hook.
