# Two targets. `base`: everything this project owns, with no Anthropic software; the only one that may be published.
# `agent` (the default): base + Claude Code + the official Telegram channel plugin; built by whoever runs it, never published.
# No tmux, no supervisor: `script` provides the pty, and the host restarts the container when claude exits (watchdog.sh covers a dead channel).
FROM oven/bun:1-debian@sha256:93d5032fe06d163427822dc1598f420363759bb18155c9cc90eb1be05a64a19e AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Unpinned apt packages on purpose: pinned Debian versions vanish from the mirror; Renovate bumps the base image.
# Second line: tools for skills (python3: documents and APIs; poppler-utils: PDFs; pandoc: Word and Markdown; unzip: archives).
# tzdata is already in the base image.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates git jq procps openssh-server openssh-client tini rclone age xz-utils \
    python3 poppler-utils pandoc unzip \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 1001 agent && mkdir -p /data /opt/seed /run/sshd && chown agent:agent /data /opt/seed

# Supercronic runs the scheduled jobs (docs/CRON.md). Pinned by version and checksum.
# renovate: datasource=github-release-attachments depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.51
ARG SUPERCRONIC_SHA256=cc232108374e8e2b537045f2d5eaa1229f619db314c3ba6a14d38b35dc0aa123
RUN curl -fsSL -o /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
 && echo "${SUPERCRONIC_SHA256}  /usr/local/bin/supercronic" | sha256sum -c - && chmod 755 /usr/local/bin/supercronic

# uv (Astral) installs Python packages and tools quickly and in isolation. Pinned by version and checksum.
# renovate: datasource=github-release-attachments depName=astral-sh/uv
ARG UV_VERSION=0.13.9
ARG UV_SHA256=a7fbaff2b9a271d85c1bdb540941090fd1ce011797b4abeb48e4dcd39c2471d5
RUN curl -fsSL -o /tmp/uv.tgz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
 && echo "${UV_SHA256}  /tmp/uv.tgz" | sha256sum -c - && tar -xzf /tmp/uv.tgz -C /usr/local/bin --strip-components=1 --no-same-owner && rm /tmp/uv.tgz

# Every agent reads documents and makes them, out of the box. One environment, the packages named here pinned (their dependencies are
# resolved at build time): markitdown (PDF, Word, Excel, PowerPoint to text), python-docx, python-pptx and openpyxl (making them; run
# with `python-docs`). Voice and video are not in the image (their FFmpeg is GPL): the agent installs them when asked (policy/stack.md).
# renovate: datasource=pypi depName=markitdown
ARG MARKITDOWN=0.1.9
# renovate: datasource=pypi depName=python-docx
ARG PYTHON_DOCX=1.2.0
# renovate: datasource=pypi depName=python-pptx
ARG PYTHON_PPTX=1.0.2
# renovate: datasource=pypi depName=openpyxl
ARG OPENPYXL=3.1.5
RUN UV_TOOL_DIR=/opt/tools UV_TOOL_BIN_DIR=/usr/local/bin uv tool install --no-cache --python /usr/bin/python3 "markitdown[pdf,docx,pptx,xlsx,xls]==${MARKITDOWN}" \
      --with "python-docx==${PYTHON_DOCX}" --with "python-pptx==${PYTHON_PPTX}" --with "openpyxl==${OPENPYXL}" \
 && printf '#!/bin/sh\nexec %s "$@"\n' /opt/tools/markitdown/bin/python > /usr/local/bin/python-docs && chmod 755 /usr/local/bin/python-docs

# Typst makes PDFs (`typst compile`), with its own fonts: one binary, no LaTeX. Pinned by version and checksum.
# renovate: datasource=github-release-attachments depName=typst/typst
ARG TYPST_VERSION=v0.15.1
ARG TYPST_SHA256=a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c
RUN curl -fsSL -o /tmp/typst.tar.xz "https://github.com/typst/typst/releases/download/${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" \
 && echo "${TYPST_SHA256}  /tmp/typst.tar.xz" | sha256sum -c - && tar -xJf /tmp/typst.tar.xz -C /usr/local/bin --strip-components=1 --no-same-owner --wildcards '*/typst' && rm /tmp/typst.tar.xz

# What the image carries and under which licences (the GPL binaries and where their source is).
COPY LICENSE THIRD-PARTY.md /usr/share/doc/agent-kernel/
# Managed policy: owned by root, not editable by the agent, highest precedence in Claude Code.
COPY policy/ /etc/claude-code/
COPY --chmod=755 bin/ /usr/local/bin/

USER 1001
ENV LANG=C.UTF-8 DISABLE_AUTOUPDATER=1 CLAUDE_CONFIG_DIR=/data/config TELEGRAM_STATE_DIR=/data/config/channels/telegram CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false CLAUDE_CODE_DISABLE_CRON=1
# What the agent installs (bin/installs.sh) lives on the volume, and comes after the image's own commands in PATH.
ENV PATH="${PATH}:/data/bin" VIRTUAL_ENV=/data/tools/venv UV_TOOL_DIR=/data/tools/uv UV_TOOL_BIN_DIR=/data/bin UV_LINK_MODE=copy \
    BUN_INSTALL_GLOBAL_DIR=/data/tools/bun BUN_INSTALL_BIN=/data/bin
WORKDIR /data/workspace
# tini is PID 1: it forwards SIGTERM (bash as PID 1 ignores it, so the host had to kill the container) and reaps orphans.
ENTRYPOINT ["tini", "-g", "--", "/usr/local/bin/start.sh"]

FROM base AS agent
# Claude Code's stable channel (about a week old, skipping releases with major regressions): Renovate opens a pull request when it
# moves, CI builds and tests it, and only then does a host get it. To go back, set CLAUDE_CODE_VERSION on the host and redeploy.
# Floor 2.1.319: the policy's denyInsteadOfPrompting needs it, and an older Claude Code ignores it, so an unattended agent could wait
# on a prompt. An older version fails the build (the host keeps its previous deployment). Until the stable channel reaches the
# floor, the version stays at 2.1.319: Renovate only proposes newer versions.
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.319
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}" \
 && v=$(/home/agent/.local/bin/claude --version | cut -d' ' -f1) && echo "Claude Code $v" \
 && { [ "$(printf '%s\n' 2.1.319 "$v" | sort -V | head -1)" = 2.1.319 ] || { echo "Claude Code $v is older than 2.1.319, which the policy needs" >&2; exit 1; }; }
ENV PATH="/home/agent/.local/bin:${PATH}"

# The official plugin is baked into /opt/seed/config; start.sh copies it to the volume at every start. The official marketplace only
# follows its main branch (a commit cannot be pinned), so each build takes the latest plugin: a plugin that does not install fails
# the build, and the host keeps the previous deployment.
RUN export CLAUDE_CONFIG_DIR=/opt/seed/config && mkdir -p "$CLAUDE_CONFIG_DIR" \
 && claude plugin marketplace add anthropics/claude-plugins-official \
 && claude plugin install telegram@claude-plugins-official \
 && for d in /opt/seed/config/plugins/cache/claude-plugins-official/telegram/*/; do bun install --cwd "$d"; done
# Updates come only with a new image, built and tested first: neither the auto-updater nor `claude update` may change a running agent
# (set after the install, which this would also refuse).
ENV DISABLE_UPDATES=1
