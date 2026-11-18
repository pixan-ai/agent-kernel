# Third-party software in the image

This project's own code (`bin/`, `policy/`, `tests/`) is Apache-2.0 (`LICENSE`). The `base` image also carries the software below, unmodified. Versions are in the `Dockerfile`, which Renovate keeps current. This file and `LICENSE` are in the image at `/usr/share/doc/agent-kernel/`. The full texts of the common licenses (GPL-2, GPL-3, LGPL-2.1, Apache-2.0 and others) are at `/usr/share/common-licenses/`.

Claude Code and the Telegram plugin are not part of the `base` image. Whoever runs an agent builds the `agent` target on their own host, which installs them under Anthropic's terms (docs/PRODUCT-IMAGE.md).

## GPL software, and where its source is

| What | Where in the image | License | Source of that exact version |
|---|---|---|---|
| Debian packages under the GPL: `pandoc` 3.1.11.1, `poppler-utils` 25.03.0, `git`, `bash`, `coreutils` and others | the usual Debian paths | GPL-2.0 or GPL-3.0 (each package's `/usr/share/doc/PACKAGE/copyright`) | https://sources.debian.org (Debian 13.7); exact versions with `dpkg -l` in the image, and every past version at https://snapshot.debian.org |

There is no FFmpeg in the image. Voice and video are an optional stack ([policy/stack.md](policy/stack.md)) that the agent downloads from their own projects when asked; this project does not distribute them.

## Other software

| What | License |
|---|---|
| The `oven/bun` base image: Bun 1.4.4 (bundles JavaScriptCore, LGPL-2.1) and Debian 13 | MIT, and each Debian package's license |
| Other Debian packages (`curl`, `jq`, `openssh`, `rclone`, `tini`, `age`, `python3`, `unzip`, `xz-utils` …) | Their own, in `/usr/share/doc/PACKAGE/copyright` |
| supercronic | MIT |
| uv | MIT or Apache-2.0 |
| Typst, with the fonts it embeds | Apache-2.0; the fonts under their own open licenses (SIL Open Font License 1.1 and similar) |
| Python packages in `/opt/tools/markitdown` (markitdown, python-docx, python-pptx, openpyxl, onnxruntime, numpy, pandas and their dependencies) | Each package's own, in its `*.dist-info` folder next to it (MIT, BSD or Apache-2.0) |
