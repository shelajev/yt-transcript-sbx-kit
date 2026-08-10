# YouTube Transcript Toolkit — Sandbox Kit

A Docker Sandboxes **mixin** kit that gives an agent everything it needs to turn
YouTube videos into clean, plain text:

- **`yt-dlp`** — download videos, audio, and subtitle tracks.
- **`ffmpeg`** / **`ffprobe`** — audio extraction and media post-processing.
- **`vtt-to-text`** — convert WebVTT subtitles into clean plain text (strips the
  header, timestamps, and inline word-timing tags; collapses YouTube's
  duplicated rolling-caption lines).

It also appends short usage guidance to the agent's memory file so the agent
knows the tools are there and how to use them.

Because it is a mixin, you layer it onto whichever agent kit you run.

## Quick start

```bash
sbx run \
  --kit git+https://github.com/shelajev/yt-transcript-sbx-kit.git \
  --kit claude \
  yt-transcript .
```

The first `--kit` adds the toolchain; the second is the agent you want to run
(swap `claude` for any agent kit).

## What it does

The recommended flow prefers subtitles over transcription — they are faster,
free, and need no model:

```bash
# 1. Fetch subtitles only (no video download)
yt-dlp --write-auto-subs --write-subs --sub-langs en --sub-format vtt \
  --skip-download -o '%(title)s.%(ext)s' "<URL>"

# 2. Clean the VTT into plain text -> "<title>.en.txt"
vtt-to-text "<title>.en.vtt"
```

If a video has no usable subtitles, download the audio and transcribe it with
your tool of choice:

```bash
yt-dlp -x --audio-format m4a -o '%(title)s.%(ext)s' "<URL>"
```

Handy `yt-dlp` flags: `--list-subs` (see available caption tracks),
`--dump-json --skip-download` (metadata only), `-f` (format selection).

## How it works

- **Install (once at sandbox creation):**
  - `apt-get install -y ffmpeg` — installs `ffmpeg` and `ffprobe`.
  - `pip install --upgrade --break-system-packages yt-dlp` — installs `yt-dlp`
    on the sandbox's shared executable path. The flag is required by the
    Debian/Python base image's PEP 668 protection; it affects only the isolated
    sandbox.
  - `chmod +x ~/.local/bin/vtt-to-text` — the converter shipped in this kit.
- **Files:** `files/home/.local/bin/vtt-to-text` is copied into the sandbox home
  directory so it lands on PATH.
- **Agent context:** the usage notes above are appended to the agent's memory
  file (e.g. `CLAUDE.md`) via `agentContext`.

## Network policy

The kit allowlists only what the workflow needs:

| Purpose | Domains |
| --- | --- |
| YouTube pages + metadata | `www.youtube.com`, `youtube.com`, `m.youtube.com` |
| Media streams | `*.googlevideo.com` |
| Thumbnails / artwork | `i.ytimg.com`, `ytimg.com`, `yt3.ggpht.com` |
| YouTube / Google Data APIs | `www.googleapis.com`, `googleapis.com` |
| Tool install (yt-dlp) | `pypi.org`, `files.pythonhosted.org` |
| Tool install (ffmpeg via apt) | `deb.debian.org`, `security.debian.org`, `archive.ubuntu.com`, `security.ubuntu.com` |

If you need to reach other sites (a different video host, your own services),
fork the kit and extend `network.allowedDomains` in `spec.yaml`.

## Smoke test

```bash
sbx exec yt-transcript -- sh -lc 'yt-dlp --version && ffmpeg -version | head -1 && vtt-to-text 2>&1 | head -1'
```

You should see a yt-dlp version, an ffmpeg banner, and the `vtt-to-text` usage line.

## Local clone

If you clone this repo, `run.sh` launches a sandbox using the local kit path
(layered onto the `claude` agent kit by default):

```bash
./run.sh yt-transcript
```

Pass any sandbox name as the first argument:

```bash
./run.sh my-sandbox
```

## License

Apache 2.0. See [LICENSE](LICENSE).
