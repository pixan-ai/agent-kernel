# Learnings

What long-running agents taught us, here and in the fleets that came before this project. Each entry: what happened, the rule we took from it, and where this repository applies it, or why it does not. Add to it whenever something costs more than an hour.

Numbers marked *measured* come from real agents, not estimates.

## Memory

**A cap on lines is a cap on the wrong axis.** What cuts a memory file on its way into the context is characters. An earlier fleet *measured* two independent limits, characters and about 200 lines; which one binds depends on line width, crossing near 124 characters per line. There is also no single character threshold: one agent was cut at 24,974 characters while another loaded 24,994.
Rule: budget characters as well as lines, and never certify a size by a constant.
Here: the dream is told 150 lines and 15,000 characters; the start hook shows at most 20,000.

**Truncation is silent.** A memory cut on the way in looks complete to the agent reading it. One agent was cut six times in three days and never noticed (*measured*).
Rule: detect a cut by comparison, not by a threshold: the end of what is on disk against the end of what arrived. It survives the harness changing its limits or its warnings.
Here: the start hook closes the memory with the line `[end of MEMORY.md]`; the managed instructions tell the agent that a memory without that line was cut, to read the file itself and to tell the owner (`tests/policy_test.sh`).

**A summary can drop entries.** The nightly dream is a model rewriting an index.
Rule: count before and after, so a loss is visible.
Here: the start log says `dream: memory consolidated (MEMORY.md 42 -> 38 lines)`.

**Files nobody is pointed to are a graveyard.** The metric that matters is not "entries in the index" but "notes reachable from some pointer, out of notes on disk". An agent with 462 notes had all 462 reachable because its index said what the cold files answer and how to search them; without that line the files exist, nobody opens them, and the agent says "I don't know" with the answer on disk (*measured*).
Rule: the index carries an explicit way into the cold store, and whatever rewrites the index must keep it.
Here: the managed instructions, which no model rewrites, tell the agent to `grep` the daily files before saying it does not know; the dream is told to keep such a line in `MEMORY.md` too.

**"Remember that …" grows the index between dreams, unobserved.** Whoever writes does not see the budget.
Rule: enforce a budget where the write happens, not in a prompt.
Here: **not applied.** The dream rewrites the index every night, so growth is bounded to one day, and the end mark exposes a cut at the next start. A check on every write would be more code than that risk justifies today. Revisit if an agent is ever cut in practice.

**Two memories are one too many.** Claude Code has its own memory index, cut at 200 lines or 25 KB. An agent that writes to both has neither whole.
Here: the instructions name one file. Claude Code's own memory is not switched off: we could not confirm the setting for it.

## Watchers

**A watcher that types into the session fabricates orders.** Two watchdogs captured the terminal, saw text in the input line and re-sent it with Enter to "unstick" the agent. The text was the harness's predicted input, not a message. They produced 46 false orders across six agents in 90 minutes, some with real outbound effects (*measured*).
Rule: watchers observe and signal. They never write into a session.
Here: `watchdog.sh` tells the owner and restarts Claude; `doorbell.sh` never reads a message. Nothing in this repository writes to the session's input.

- **A watcher can go on watching something that stopped mattering.** A credential check that reads the file on disk keeps reporting green after an environment variable became what authenticates: its green says nothing and its red is a false alarm. When what authenticates moves, the check moves with it.

## Tools and capability

**A tool the agent's user cannot reach just vanishes.** In a path that user cannot traverse, a tool fails as "command not found", with no other sign.
Rule: verify by running the tool as that user, not by checking that the file exists.
Here: CI runs every tool the scripts call as uid 1001.

**Prove a capability by executing it.** One agent claimed it could read PDFs because its documentation said so; the library was missing. Another declared a gap unclosable for lack of OCR while it could read the images directly. "Cannot" is the stronger claim and deserves more proof.
Here: every document ends with what was verified where, and what was not.

**A flag can eat the prompt.** `claude -p --tools "Read,Edit" "do this"` takes "do this" as a third tool name: the run starts with no instructions and exits 0. Found only by running a real Claude.
Here: the prompt goes first, `--tools` last, and a test pins the order.

**An error is not always on the error stream.** `claude -p` reports "Not logged in" or a limit on standard output and exits 1. Our dream discarded standard output and kept only the error stream, so it failed for two days saying nothing.
Rule: when a tool fails, keep everything it said.

**A guard that matches a path matches every use of it.** The install lock refused any command naming the install folders, so it also blocked using what had been installed, and announced a version check as an install. Found in the first hour on a live agent.
Rule: guard the action (writing there, running an installer), not the mention.

**A stub that accepts anything proves nothing.** A test passed while the code deleted the bot token before using it, because the stub never looked at the token.
Rule: a stub must demand what the real thing demands.

**`grep -q` in a pipeline kills the writer.** It stops reading at the first match; with `pipefail`, a correct hook then fails once its output grows. Seen in our own tests.

## Telegram

- **Two Claude processes on one bot directory silence the bot**: the second plugin takes the poller from the first. Jobs and the dream run with their own config directory.
- **A bot does not know its own name** unless told. In a group it stayed silent when addressed. The start hook now tells it.
- **A bot added before privacy mode was disabled hears nothing** in that group until it is removed and added again.
- **A group that becomes a supergroup changes its id.** The old id fails without an error.
- **A job's session has no Telegram.** Asked to "send" something, it reports failure. It is told to write only the message; the script delivers it.
- **A reply tool that takes file paths is an exfiltration path** when it is pre-approved. A hook limits where attachments come from.
- **An answer written in the terminal is an answer to nobody.** A new agent received "Hola" twice, showed "typing…", wrote a correct answer on its own screen in under a second, and sent nothing (*measured*, 2026-11-22: two turns that ended normally, text only, no tool call). Cause: Claude Code defers MCP tools by default (tool search), so in every new session the model must search for the reply tool before it can use it. The healthy session next to it made two searches before its first reply; the failed one answered at once and never saw the tool. The plugin's instructions and its tool names reached the session only after a first tool call. Nothing failed to load, and no log said anything: the agent was alive, the message came in, the turn ended. An agent that sleeps when idle starts a new session at every wake, so it meets this first message many times a day.
  Rule: what an agent needs in order to be heard must be in front of it from the first message, not behind a search it may not make.
  Here: the image sets `ENABLE_TOOL_SEARCH=false`, which loads MCP tools upfront, and the managed instructions say that an answer exists only when it is sent with the reply tool. That removes the search; it does not remove the second way to the same silence, below.
- **A rule is not a mechanism.** A model that has the reply tool in front of it can still answer in the terminal, most of all a message that feels trivial ("Hola", "still here?"). Other fleets *measured* it: five turns in a row, with the rule written in the agent's own instructions and the agent reasoning that a greeting did not need the tool; two hours of silence for the owner. Every watcher stayed green, because every watcher measured that the agent was alive, and it was: the message came in, the transcript moved, the turn ended. The agent's own account ("I answered every message") was wrong too. Upstream has the same reports and no fix (anthropics/claude-code#88932, #59742).
  Rule: what must always happen is checked where it can be seen from outside the model, here "a message came in, did anything go out"; and when the model does not do it, the system does.
  Here: `bin/unsent.sh`, called by three hooks. A message from the owner's private chat sets a mark, a Telegram tool that has sent clears it, and a turn that ends with the mark still there is sent back once to use the reply tool; if it ends again without sending, the owner gets what it wrote the first time, sent by the script. Run in a real Claude Code session with a test channel (2026-11-23): with the reply tool denied, the turn was sent back, Claude looked for the tool, could not send, and the answer was delivered; with the tool allowed, and for a group message left unanswered, nothing happened. Limits: only the owner's private chat (in a group, silence is often right); a mark, not a count (one reply clears several messages); a first "working on it" clears it for that turn.

## Hosting

- **A suspended container runs nothing**: no jobs, no nightly dream, no backup. An agent with jobs is kept awake; one without dreams and backs up when it goes to sleep.
- **Cost is memory, not CPU.** Idle agents cost almost as much as busy ones until they are stopped (*measured*: an agent asleep used a quarter of the memory of one always on).
- **A session that never ends gets more expensive with every message.** The dream ends it once a day.
- **A pasted credential can arrive truncated.** The start log prints its length and prefix, never its value.
- **An agent out of quota fails without a word.** For two days the nightly dream failed with nothing in the log, most likely on a used-up subscription that several agents share. Now the owner is warned at 80% and told the reason when a job or a dream is stopped.
- **An environment token beats a login and does not fall back to it.** *Measured*, four cells: no key is `Not logged in`, a good `CLAUDE_CODE_OAUTH_TOKEN` alone answers, a bad one alone gives `401` — and a bad one beside a healthy `.credentials.json` still gives `401`. Only the fourth cell decides, and it means the variable is a single point of failure wherever it is set. Set host-wide, it moves every Claude Code on that machine onto it at its next restart.
- **A subscription token says nothing about itself.** Not which account issued it, not when it expires. What you need to know later has to be written down when it is made.
- **A sleep that cannot be woken is worse than no sleep.** If the wake-up call cannot be registered, the agent stays awake.

## Method

- **A test that did not fail first is not a test.** Each one here was run against the old code and seen to fail before the change was written.
- **Instructions are not locks.** Where the two differ, the documents say which one protects what (`THREAT-MODEL.md`).
- **Fewer lines.** A suggestion that adds a mechanism is weighed against the risk it removes; several audit proposals were answered with one line, or with none. The scripts have a budget, 247 lines of code, and a test holds it. The number was first met by joining short statements, not by removing a function (2026-11-23: 277 to 247, every test unchanged): a budget kept by packing lines is kept in name only, so the next lines are to come from functions that go.
