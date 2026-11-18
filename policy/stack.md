# Optional stack

Tools that are not in the image, ready for the agent to install when the owner or a super-user asks. Each recipe is pinned, and
CI runs every `sh` block of this file, in order, as the agent's user (`tests/stack_test.sh`). What it installs lives on the volume
(`/data/tools`, `/data/bin`), is recorded in `/data/tools.json` and is put back at start if it went missing.

Why not in the image: both carry FFmpeg built under the GPL. Downloaded by the agent from their own projects, for its own use, they
are not distributed by this project.

## Voice notes and audio

Whisper `small` through `whisper-ctranslate2`, offline once installed. The first install downloads about 700 MB (the model is 480 MB of it).

```sh
uv tool install whisper-ctranslate2==0.5.9
/data/tools/uv/whisper-ctranslate2/bin/python -c "from huggingface_hub import snapshot_download as d; d('Systran/faster-whisper-small', revision='536b0662742c02347bc0e980a01041f333bce120', local_dir='/data/tools/models/whisper-small')"
```

Use: `whisper-ctranslate2 --model_directory /data/tools/models/whisper-small --compute_type int8 --output_dir /tmp FILE` (add `--language es` when you know it). It reads Telegram's `.oga` voice notes directly.

## Video

`ffmpeg`, the static build that `imageio-ffmpeg` carries: video frames, cuts, conversions.

```sh
uv pip install imageio-ffmpeg==0.8.1
ln -sf "$(/data/tools/venv/bin/python -c 'import imageio_ffmpeg as m; print(m.get_ffmpeg_exe())')" /data/bin/ffmpeg
```

Use: `ffmpeg -i FILE …`, for example one frame: `ffmpeg -i video.mp4 -frames:v 1 /tmp/frame.png`.
