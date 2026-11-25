# 0002. A budget of 247 lines

**Status:** Accepted (2026-11-23). Replaces "less than 300 lines".

**Decision.** The agent's own Bash, the scripts in `bin/`, stays within 247 lines of code (comments and blank lines not counted). A test holds it. A change that needs a line gives one back, first by removing what is no longer needed.

**Why.** Small enough for anyone to read and audit what was added to the official tools. A cap forces the question "is this needed?" before every line.

**Cost.** Some features wait until room is made. Code that runs outside the agent (for example, host configuration for a fleet) is counted and declared separately, never hidden from the count.
