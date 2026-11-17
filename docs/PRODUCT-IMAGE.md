# Lab image and product image

Status: **decided by the owner (2026-11-10): one Dockerfile, two targets.** `base` has no Anthropic software and is the only target the release workflow may publish; `agent` (the default, what `docker build .` and Railway produce) adds Claude Code and the official plugin and is never published. This replaces the options below, kept for the record.

## Two images, two purposes

| | Lab image (today) | Product image (proposed) |
|---|---|---|
| Contains Claude Code | **Yes**, installed at build time | **No** |
| Who builds it | The owner, on their own host (Railway) | CI, published to a registry |
| May be published publicly | **No**: Claude Code is "All rights reserved", used under Anthropic's Commercial Terms | Yes |
| Purpose | Run the owner's own agent | What a customer downloads |

Build the agent: `docker build -t my-agent .` Build only the base: `docker build --target base .` The publish job stays locked (`PUBLISH_IMAGE`) until the owner turns it on; when it runs, it pushes `base` only, and CI checks that the pushed image contains no Claude Code.

## Why the product image has no Claude Code

Anthropic's documentation says a product that preinstalls Claude Code needs Commercial Terms, an unmodified binary, and each end user's own credentials. This project is open source and does not redistribute the binary at all.

## How the product image gets Claude Code

Option A (recommended): the entrypoint installs the **pinned** official release on first start into the volume (`/data`), using the customer's own network and credentials. The image stays free of the binary; the binary is unmodified and comes from Anthropic. Cost: first start needs outbound access to the official installer, and the entrypoint gains a few lines plus a checksum or version check.

Option B: the customer builds the image themselves from the same `Dockerfile` (`docker build`). No distribution, no extra code. Cost: no pull-and-run convenience, so no registry "seals" for that image.

Option C: publish a base image (OS, `bun`, `jq`, `setpriv`, policy, scripts) and let the customer's own `FROM` add Claude Code. Closest to A without runtime install, but needs the customer to build once.

## Decisions

1. **Decided (2026-11-10): option C.** The `base` target is what may be published; whoever runs an agent builds `agent` on top of it, which adds Claude Code on their own host.
2. **Decided: the base image carries the managed policy.** It holds no secrets.
3. **Half settled: the GPL binaries in the base image.** Two copies of FFmpeg are under the GPL: the static `ffmpeg` that `imageio-ffmpeg` 0.8.1 carries (GPLv3: `--enable-gpl --enable-version3`, with x264, x265 and xvid) and the libraries in the PyAV wheel that faster-whisper uses (with x264 and x265). Since the audit of 2026-11-17 the image carries `THIRD-PARTY.md` (each one, its licence and where the source of that exact build is) and `LICENSE` at `/usr/share/doc/pixan-kernel-spike/`, and the GPL texts are at `/usr/share/common-licenses/`. Still open before publishing: the links point to the upstream projects, so the source stays available only while they keep it. GPLv3 asks whoever publishes to make sure it does: keep a copy of those sources next to each published image, or give a written offer. The owner decides when turning publishing on.
4. **Open: whether to ask Anthropic in writing before publishing anything.** Publishing stays locked (`PUBLISH_IMAGE`) until the owner turns it on.

## Not decided here

This document does not change the lab deployment or any workflow.
