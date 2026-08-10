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

## Companion agent skill

The kit includes a standalone `youtube-analyzer` skill at the agent-neutral
path `~/.agents/skills/youtube-analyzer/`. Docker Sandboxes exposes this shared
location to compatible agents such as Codex and Antigravity. A small Claude
compatibility shim points to the same implementation, so there is one analysis
workflow regardless of agent. The skill uses the tools this kit provides but
never installs or upgrades them. Ask your agent to use it for a YouTube URL when
you want a timestamped transcript, structural breakdown, hook analysis, key
moments, or a reusable script formula. It labels transcript evidence separately
from interpretation and can add a primary-source fact-check when requested.

## Quick start

The transcript kit is a mixin: name the agent to run, then add this kit with
`--kit`. Choose one of these examples.

`claude`, `codex`, and the other names listed by `sbx run --help` are built-in
agents, so they are positional arguments—not kit references. A `--kit` flag
adds a declarative layer such as this toolchain or a custom agent kit. Do not
write `--kit claude` or `--kit codex`.

### Claude

```bash
sbx run --name yt-claude \
  --kit git+https://github.com/shelajev/yt-transcript-sbx-kit.git \
  claude .
```

### Codex

```bash
sbx run --name yt-codex \
  --kit git+https://github.com/shelajev/yt-transcript-sbx-kit.git \
  codex .
```

### Antigravity

```bash
sbx run --name yt-antigravity \
  --kit git+https://github.com/shelajev/agy-sbx-kit.git \
  --kit git+https://github.com/shelajev/yt-transcript-sbx-kit.git \
  agy .
```

Antigravity asks you to complete its Google OAuth flow on first use; see the
[Antigravity kit](https://github.com/shelajev/agy-sbx-kit) for that flow.

Each `--name` creates a persistent sandbox. Reattach without supplying an agent
or kits again:

```bash
sbx run --name yt-codex
```

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
  - `apt-get update`, then `apt-get install -y ffmpeg` — installs `ffmpeg` and
    `ffprobe` in separate setup steps so both complete reliably.
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
| Tool install (ffmpeg via apt) | `deb.debian.org`, `security.debian.org`, `archive.ubuntu.com`, `security.ubuntu.com`, `ports.ubuntu.com` |

If you need to reach other sites (a different video host, your own services),
fork the kit and extend `network.allowedDomains` in `spec.yaml`.

## Smoke test

```bash
sbx exec yt-claude -- sh -lc 'yt-dlp --version && ffmpeg -version | head -1 && vtt-to-text 2>&1 | head -1'
```

You should see a yt-dlp version, an ffmpeg banner, and the `vtt-to-text` usage line.

## Local clone

If you clone this repo, `run.sh` launches Claude with the local kit path. Pass
the workspace as its first argument:

```bash
./run.sh .
```

Use a different built-in agent by setting `SBX_AGENT`:

```bash
SBX_AGENT=codex ./run.sh .
```

## License

Apache 2.0. See [LICENSE](LICENSE).
