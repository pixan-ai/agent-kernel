# Third-party software in the image

This project's own code (`bin/`, `policy/`, `tests/`) is Apache-2.0 (`LICENSE`). The `base` image also carries the software below, unmodified. This file and `LICENSE` are in the image at `/usr/share/doc/agent-kernel/`. The full texts of the common licences (GPL-2, GPL-3, LGPL-2.1, Apache-2.0 and others) are at `/usr/share/common-licenses/`.

Claude Code and the Telegram plugin are not part of the `base` image. Whoever runs an agent builds the `agent` target on their own host, which installs them under Anthropic's terms (docs/PRODUCT-IMAGE.md).

## GPL binaries, and where their source is

| What | Where in the image | Licence | Source of that exact build |
|---|---|---|---|
| `ffmpeg` static binary carried by imageio-ffmpeg 0.8.1: FFmpeg `n9.0.2-17-g2a571b6068-20260930`, configured with `--enable-gpl --enable-version3` and libx264, libx265, libxvid among others (`ffmpeg -version` prints the whole list) | `/opt/tools/whisper-ctranslate2/lib/python3*/site-packages/imageio_ffmpeg/binaries/`, linked as `/usr/local/bin/ffmpeg` | GPL-3.0-or-later | FFmpeg commit `2a571b6068` at https://git.ffmpeg.org/ffmpeg.git. The build scripts, and the versions of every library linked in, are at https://github.com/BtbN/FFmpeg-Builds |
| FFmpeg libraries bundled in the PyAV 18.1.0 wheel (`av.libs/`, used by faster-whisper to decode audio), including libx264 and libx265 | `/opt/tools/whisper-ctranslate2/lib/python3*/site-packages/av.libs/` | GPL-2.0-or-later as a whole (libx264, libx265); PyAV itself is BSD-3-Clause | The build scripts and versions are at https://github.com/PyAV-Org/pyav-ffmpeg; PyAV's source is at https://github.com/PyAV-Org/PyAV/tree/v18.1.0 |
| Debian packages under the GPL: `pandoc` 3.1.11.1, `poppler-utils` 25.03.0, `git`, `bash`, `coreutils` and others | the usual Debian paths | GPL-2.0 or GPL-3.0 (each package's `/usr/share/doc/PACKAGE/copyright`) | https://sources.debian.org (Debian 13.7); exact versions with `dpkg -l` in the image, and every past version at https://snapshot.debian.org |

## Other software

| What | Licence |
|---|---|
| The `oven/bun` base image: Bun 1.4.4 (bundles JavaScriptCore, LGPL-2.1) and Debian 13 | MIT, and each Debian package's licence |
| Other Debian packages (`curl`, `jq`, `openssh`, `rclone`, `tini`, `age`, `python3`, `unzip`, `xz-utils` …) | Their own, in `/usr/share/doc/PACKAGE/copyright` |
| supercronic 0.2.51 | MIT |
| uv 0.13.8 | MIT or Apache-2.0 |
| Typst 0.15.1, with the fonts it embeds | Apache-2.0; the fonts under their own open licences (SIL Open Font License 1.1 and similar) |
| Python packages in `/opt/tools/whisper-ctranslate2` (whisper-ctranslate2, faster-whisper, CTranslate2, markitdown, python-docx, python-pptx, openpyxl, onnxruntime, numpy and their dependencies) | Each package's own, in its `*.dist-info` folder next to it (MIT, BSD or Apache-2.0, except the FFmpeg parts above) |
| Whisper `small` model weights (`Systran/faster-whisper-small`), in `/opt/models/whisper-small` | MIT |
