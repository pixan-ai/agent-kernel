# Business model canvas

agent-kernel is a non-commercial open-source project (Apache-2.0). This canvas describes how it creates value and sustains itself, not how it makes money: it sells nothing. The product itself is described in [PRODUCT.md](PRODUCT.md).

## Customer segments

- **Individuals** who want their own AI agent on Telegram, on their own Claude subscription.
- **Small teams and companies** that want a few agents, one per person or role, on their own host and Claude API key.
- **Builders and learners** who study agents and want a small, readable, verifiable reference.

## Value propositions

- An agent that is always on, in the chat app people already use, with memory, schedules, groups and fellow agents.
- Built only from official components: every improvement Anthropic makes to Claude Code reaches it with no extra work.
- Small enough to read and audit: 247 lines of Bash and instructions in Markdown.
- Owned by its user: their key, their bot, their host, their data.
- Honest: a published threat model, what is verified and what is not, signed images.

## Channels

- The GitHub repository and its documentation.
- The project's website, with a machine-readable summary for AI assistants (`llms.txt`).
- A one-click Railway template, and container images on GitHub and Docker Hub.
- A setup prompt for the user's own AI assistant.
- Word of mouth from people running agents.

## Customer relationships

- Self-service: guides, troubleshooting and a setup prompt; no account to create.
- Community: issues and pull requests on GitHub; private vulnerability reports through the security policy.
- Transparency: a changelog that says why each change was made.

## Revenue streams

None. The project sells no services, plans, add-ons or support, and takes no fees. Users pay their own providers (Claude, their host) directly. Donations, if ever accepted, would only sustain the project's work.

## Key resources

- The maintainer's time and the lessons from earlier agent fleets.
- Anthropic's official Claude Code and Telegram plugin.
- The test suite and continuous integration that hold every claim.
- Public infrastructure for open source: GitHub, GitHub Actions, container registries, OpenSSF.

## Key activities

- Keeping the agent working with each new Claude Code release.
- Fixing what real installations reveal, with a test for every change.
- Writing and maintaining the documentation and the threat model.
- Publishing signed, verifiable releases.

## Key partners

- **Anthropic:** Claude Code, the Telegram plugin, the models.
- **Telegram:** the Bot API.
- **Hosts:** Railway (template), Docker (images).
- **Open-source projects** the image uses (listed in `THIRD-PARTY.md`).
- **OpenSSF:** Best Practices and Scorecard.

## Cost structure

- The maintainer's time.
- The project's own test agents and infrastructure, paid by the maintainer.
- No cost is passed to users beyond their own providers.
