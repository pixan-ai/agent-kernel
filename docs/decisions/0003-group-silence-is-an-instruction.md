# 0003. In groups, who answers is an instruction

**Status:** Accepted (2026-11-25).

**Decision.** Whether an agent answers a group message is decided by its instructions: a message that starts with another agent's name or @username gets nothing, not even an apology. No hook filters messages.

**Why.** The plugin's message carries no reply-to field, so a mechanism could only read how the text starts, and dropping a message would make the agent lose the thread of the group. Another long-running fleet uses a written rule too.

**Cost.** A rule is not a mechanism: the model will sometimes answer anyway (three agents did, live, before the rule was sharpened). The guide asks for names that cannot be confused, the @username, and one agent as the voice for messages to everyone.
