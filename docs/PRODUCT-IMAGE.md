# Images: what is built and what is published

One Dockerfile, two targets:

| | `agent` (the default) | `base` |
|---|---|---|
| Contains Claude Code and the Telegram plugin | **Yes**, installed at build time | **No** |
| Who builds it | Whoever runs an agent, on their own host (`docker build .`, Railway) | CI |
| May be published | **No**: Claude Code is "All rights reserved", used under Anthropic's terms | Yes, to GitHub's registry and Docker Hub ([RELEASING.md](RELEASING.md)) |
| Purpose | Run an agent | A starting point anyone can pull; their own build adds Claude Code |

Build the agent: `docker build -t my-agent .` Build only the base: `docker build --target base .` The publish job runs when the repository variable `PUBLISH_IMAGE` is `true` (turned on 2026-11-19); when it runs, it pushes `base` only, and CI checks that the pushed image contains no Claude Code.

## Why the published image has no Claude Code

Anthropic's documentation says a product that preinstalls Claude Code needs Commercial Terms, an unmodified binary, and each end user's own credentials. This project is open source and does not redistribute the binary at all.

## Options that were considered

- **A.** The entrypoint installs the pinned official release on first start, into the volume. No binary in the image, but every first start needs the official installer and the entrypoint grows.
- **B.** Everyone builds the whole image from the `Dockerfile`. No distribution at all, and no pull-and-run.
- **C (chosen).** Publish a base image (OS, tools, policy, scripts) and let each user's own build add Claude Code. The `agent` target in the same `Dockerfile` is that build.

## Decisions

1. **Decided: option C.** The `base` target is what may be published; whoever runs an agent builds `agent` on top of it, which adds Claude Code on their own host.
2. **Decided: the base image carries the managed policy.** It holds no secrets.
3. **Decided (2026-11-18): no GPL FFmpeg in the image.** Voice and video, the only parts that carried it, moved to an optional stack ([policy/stack.md](../policy/stack.md)) that each agent downloads from the upstream projects when its owner or a super-user asks, so this project does not distribute them. What remains under the GPL is Debian's own packages (`pandoc`, `poppler-utils`, `git` …), whose exact sources Debian keeps for every version; `THIRD-PARTY.md` and `LICENSE` are in the image at `/usr/share/doc/agent-kernel/`, the GPL texts at `/usr/share/common-licenses/`.
4. **Decided (2026-11-19): the base image is published without asking Anthropic in writing.** It carries no Anthropic software (CI checks every pushed digest), and each user installs Claude Code on their own host with the official installer. It goes to GitHub's registry and to Docker Hub as `pixan/agent-kernel`; the repository variable `PUBLISH_IMAGE` is the switch.
