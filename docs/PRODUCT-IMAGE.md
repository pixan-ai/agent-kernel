# Images: what is built and what is published

One Dockerfile, two targets:

| | `agent` (the default) | `base` |
|---|---|---|
| Contains Claude Code and the Telegram plugin | **Yes**, installed at build time | **No** |
| Who builds it | Whoever runs an agent, on their own host (`docker build .`, Railway) | CI |
| May be published | **No**: Claude Code is "All rights reserved", used under Anthropic's terms | Yes, to GitHub's registry and Docker Hub ([RELEASING.md](RELEASING.md)) |
| Purpose | Run an agent | A starting point anyone can pull; their own build adds Claude Code |

Build the agent: `docker build -t my-agent .` Build only the base: `docker build --target base .` The publish job stays locked (`PUBLISH_IMAGE`) until the owner turns it on; when it runs, it pushes `base` only, and CI checks that the pushed image contains no Claude Code.

## Why the published image has no Claude Code

Anthropic's documentation says a product that preinstalls Claude Code needs Commercial Terms, an unmodified binary, and each end user's own credentials. This project is open source and does not redistribute the binary at all.

## Options that were considered

- **A.** The entrypoint installs the pinned official release on first start, into the volume. No binary in the image, but every first start needs the official installer and the entrypoint grows.
- **B.** Everyone builds the whole image from the `Dockerfile`. No distribution at all, and no pull-and-run.
- **C (chosen).** Publish a base image (OS, tools, policy, scripts) and let each user's own build add Claude Code. The `agent` target in the same `Dockerfile` is that build.

## Decisions

1. **Decided: option C.** The `base` target is what may be published; whoever runs an agent builds `agent` on top of it, which adds Claude Code on their own host.
2. **Decided: the base image carries the managed policy.** It holds no secrets.
3. **Half settled: the GPL binaries in the base image.** Two copies of FFmpeg are under the GPL: the static `ffmpeg` that `imageio-ffmpeg` 0.8.1 carries (GPLv3: `--enable-gpl --enable-version3`, with x264, x265 and xvid) and the libraries in the PyAV wheel that faster-whisper uses (with x264 and x265). The image carries `THIRD-PARTY.md` (each one, its licence and where the source of that exact build is) and `LICENSE` at `/usr/share/doc/agent-kernel/`, and the GPL texts are at `/usr/share/common-licenses/`. Still open before publishing: the links point to the upstream projects, so the source stays available only while they keep it. GPLv3 asks whoever publishes to make sure it does: keep a copy of those sources next to each published image, or give a written offer. The owner decides when turning publishing on.
4. **Open: whether to ask Anthropic in writing before publishing anything.** Publishing stays locked (`PUBLISH_IMAGE`) until the owner turns it on.
