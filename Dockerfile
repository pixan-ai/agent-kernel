# Two targets. `base`: everything this project owns, with no Anthropic software; the only one that may be published.
# `agent` (the default): base + Claude Code + the official Telegram channel plugin; built by whoever runs it, never published.
# No tmux, no supervisor: `script` provides the pty, and the host restarts the container when claude exits (watchdog.sh covers a dead channel).
FROM oven/bun:1-debian@sha256:93d5032fe06d163427822dc1598f420363759bb18155c9cc90eb1be05a64a19e AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Unpinned apt packages on purpose: pinned Debian versions vanish from the mirror; Dependabot bumps the base image.
# Second line: tools for skills (python3: documents and APIs; poppler-utils: PDFs; pandoc: Word and Markdown; unzip: archives).
# tzdata is already in the base image.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates git jq procps openssh-server openssh-client tini rclone age \
    python3 poppler-utils pandoc unzip \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 1001 agent && mkdir -p /data /opt/seed /run/sshd && chown agent:agent /data /opt/seed

# Supercronic runs the scheduled jobs (docs/CRON.md). Pinned by version and checksum.
ARG SUPERCRONIC_VERSION=v0.2.51 SUPERCRONIC_SHA256=cc232108374e8e2b537045f2d5eaa1229f619db314c3ba6a14d38b35dc0aa123
RUN curl -fsSL -o /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
 && echo "${SUPERCRONIC_SHA256}  /usr/local/bin/supercronic" | sha256sum -c - && chmod 755 /usr/local/bin/supercronic

# uv (Astral) installs Python packages and tools quickly and in isolation. Pinned by version and checksum.
ARG UV_VERSION=0.13.8 UV_SHA256=5acfd9177cfecf0bf87578f059728215ccc884388988f55f7a65041b57387d91
RUN curl -fsSL -o /tmp/uv.tgz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
 && echo "${UV_SHA256}  /tmp/uv.tgz" | sha256sum -c - && tar -xzf /tmp/uv.tgz -C /usr/local/bin --strip-components=1 --no-same-owner && rm /tmp/uv.tgz

# Every agent hears voice notes and reads documents out of the box (decided 2026-11-15; this reverses "no ffmpeg in the image").
# One environment, all pinned: whisper-ctranslate2 (voice to text), markitdown (PDF, Word, Excel, PowerPoint to text) and the static
# ffmpeg that imageio-ffmpeg carries (video frames). The Whisper model is baked in, pinned by revision: nothing is downloaded at use.
ARG WHISPER_CT2=0.5.9 MARKITDOWN=0.1.9 IMAGEIO_FFMPEG=0.8.1 WHISPER_MODEL_REV=536b0662742c02347bc0e980a01041f333bce120
RUN UV_TOOL_DIR=/opt/tools UV_TOOL_BIN_DIR=/usr/local/bin uv tool install --no-cache --python /usr/bin/python3 "whisper-ctranslate2==${WHISPER_CT2}" \
      --with "markitdown[pdf,docx,pptx,xlsx,xls]==${MARKITDOWN}" --with "imageio-ffmpeg==${IMAGEIO_FFMPEG}" --with-executables-from markitdown \
 && P=/opt/tools/whisper-ctranslate2/bin/python \
 && ln -s "$($P -c 'import imageio_ffmpeg as m; print(m.get_ffmpeg_exe())')" /usr/local/bin/ffmpeg \
 && $P -c "from huggingface_hub import snapshot_download as d; d('Systran/faster-whisper-small', revision='${WHISPER_MODEL_REV}', local_dir='/opt/models/whisper-small')" \
 && rm -rf /opt/models/whisper-small/.cache

# Managed policy: owned by root, not editable by the agent, highest precedence in Claude Code.
COPY policy/ /etc/claude-code/
COPY --chmod=755 bin/ /usr/local/bin/

USER 1001
ENV DISABLE_AUTOUPDATER=1 CLAUDE_CONFIG_DIR=/data/config TELEGRAM_STATE_DIR=/data/config/channels/telegram CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false CLAUDE_CODE_DISABLE_CRON=1
# What a super-user has the agent install (bin/install-lock.sh) lives on the volume, and comes after the image's own commands in PATH.
ENV PATH="${PATH}:/data/bin" VIRTUAL_ENV=/data/tools/venv UV_TOOL_DIR=/data/tools/uv UV_TOOL_BIN_DIR=/data/bin UV_LINK_MODE=copy \
    BUN_INSTALL_GLOBAL_DIR=/data/tools/bun BUN_INSTALL_BIN=/data/bin
WORKDIR /data/workspace
# tini is PID 1: it forwards SIGTERM (bash as PID 1 ignores it, so the host had to kill the container) and reaps orphans.
ENTRYPOINT ["tini", "-g", "--", "/usr/local/bin/start.sh"]

FROM base AS agent
ARG CLAUDE_CODE_VERSION=2.1.319
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}" \
 && /home/agent/.local/bin/claude --version
ENV PATH="/home/agent/.local/bin:${PATH}"

# The official plugin is baked into /opt/seed/config; start.sh copies it to the volume at every start.
RUN export CLAUDE_CONFIG_DIR=/opt/seed/config && mkdir -p "$CLAUDE_CONFIG_DIR" \
 && claude plugin marketplace add anthropics/claude-plugins-official \
 && claude plugin install telegram@claude-plugins-official \
 && for d in /opt/seed/config/plugins/cache/claude-plugins-official/telegram/*/; do bun install --cwd "$d"; done
