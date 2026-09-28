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

The toolchain is **prebuilt**: it arrives in the kit's layers rather than being
installed while the sandbox comes up. Nothing is fetched at create, so there are
no setup hooks to wait for or to fail, and the kit asks for no egress to PyPI or
to a distribution mirror. It also never touches the workload's Python — `yt-dlp`
and the converter run on an interpreter this kit carries, in its own prefix under
`/opt/yt-transcript`. See [How it works](#how-it-works).

## Companion agent skill

The kit includes a standalone `youtube-analyzer` skill at the agent-neutral
path `~/.agents/skills/youtube-analyzer/`. Docker Sandboxes exposes this shared
location to compatible agents such as Codex and Antigravity. A small Claude
compatibility shim points to the same implementation, so there is one analysis
workflow regardless of agent. The skill uses the tools this kit provides but
never installs or upgrades them. Ask your agent to summarize or analyze a YouTube
URL to get self-contained, illustrated notes with a timestamped walkthrough, key
moments, and useful video frames. Ask it to fact-check or verify the video to get
a claim-by-claim report grounded in primary sources. The skill keeps transcript
evidence, interpretation, and external verification separate.

## Quick start

The transcript kit is a mixin: name the v3 workload to run, then add the
published mixin with `--kit`.

```bash
sbx run docker.io/docker/sbx-kit-shell:1.0.0 \
  --name yt-shell \
  --kit docker.io/olegselajev241/yt-transcript-sbx-kit:1.0.0 \
  .
```

The positional argument is a **workload kit**, and that is a change from the
earlier version of this kit. A composition needs exactly one `kind: workload`
kit; the built-in agent names (`claude`, `codex`, and the rest listed by
`sbx run --help`) are not kits, so naming one alongside this mixin is refused
with `no workload kit in the set`. Any published v3 workload kit works as the
base — swap the reference above for the agent you want.

To run Antigravity with the transcript tools, compose the Agy workload with this
mixin:

```bash
sbx run docker.io/olegselajev241/agy-sbx-kit:1.0.0 \
  --name agy-youtube \
  --kit docker.io/olegselajev241/yt-transcript-sbx-kit:1.0.0 \
  .
```

Or make the composition explicit as a shell workload plus two mixins:

```bash
sbx run docker.io/docker/sbx-kit-shell:1.0.0 \
  --name agy-youtube-shell \
  --kit docker.io/olegselajev241/agy-sbx-kit-mixin:1.0.0 \
  --kit docker.io/olegselajev241/yt-transcript-sbx-kit:1.0.0 \
  .
```

Then run `agy` inside the shell.

Each `--name` creates a persistent sandbox. Reattach without supplying the
workload or kits again:

```bash
sbx run --name yt-shell
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

The kit is a v3 descriptor (`yt-transcript.yaml`) plus an ordinary Dockerfile
(`yt-transcript.dockerfile`) that builds its content. There are no install hooks:
the descriptor declares no lifecycle capability at all, because by the time a
sandbox starts there is nothing left to install.

Everything lives in one prefix, `/opt/yt-transcript`:

| Path | What |
| --- | --- |
| `python/` | CPython 3.13, this kit's alone |
| `python/.../site-packages/` | `yt-dlp` 2026.8.19 and its pinned dependencies |
| `bin/` | static `ffmpeg` and `ffprobe` 9.0, and `vtt-to-text` |
| `skills/` | the `youtube-analyzer` body, and the Claude shim |
| `share/licences/` | ffmpeg's licence, since an image is a distribution |

Outside that prefix the overlay writes only symlinks: `yt-dlp`, `ffmpeg`,
`ffprobe` and `vtt-to-text` in `/usr/local/bin`, and one in each of
`~/.agents/skills/` and `~/.claude/skills/` pointing at the skill in the prefix.

Three things follow from that shape, and they are the reason for it:

- **The workload's Python is untouched.** The old `pip install
  --break-system-packages` worked, but it changed the environment's Python to add
  a tool. `yt-dlp`, `vtt-to-text` and the skill's scripts run on the interpreter
  in the prefix — their shebangs name it — so the kit also composes onto a
  workload that has no `python3` at all.
- **`ffmpeg` is static.** `apt-get install ffmpeg` would drop around ninety
  shared objects into `/usr/lib` on a filesystem this kit does not own, and tie
  the kit to one distribution's library versions. The build takes the LGPL
  variant: it drops the x264/x265 encoders this workflow never uses, and keeps
  the artifact out of GPL. `licenses:` in the descriptor reports everything that
  ships.
- **Everything is pinned.** Each binary is fetched by immutable URL and checked
  against a `sha256` recorded in the Dockerfile; the Python closure is pinned by
  yt-dlp's own `default` and `pin` extras (see `requirements.txt`). A rebuild
  either produces the same closure or fails.

The usage notes above still reach the agent's memory file (e.g. `CLAUDE.md`),
now as the `agent-context@1` capability with the body in
`yt-transcript-context.md`.

### Building it

The descriptor's `# syntax=` line dispatches the kit frontend, so a build is an
ordinary `docker buildx build` and the result is an ordinary image:

```bash
docker buildx build . -f yt-transcript.yaml -t docker.io/me/sbx-kit-yt-transcript:1.0.0
```

The build tests what it ships before it finishes: both converters against a
rolling-caption fixture, a synthesised clip transcoded and read back with
`ffprobe`, audio extraction, frame capture through `extract_frames.sh`, and
`embed_images.py` inlining the result. Pushed to a registry, the image is what
`--kit` can name instead of this repository.

## Network policy

The kit allowlists only what the workflow needs:

| Purpose | Domains |
| --- | --- |
| YouTube pages + metadata | `www.youtube.com`, `youtube.com`, `m.youtube.com` |
| Media streams | `*.googlevideo.com` |
| Thumbnails / artwork | `i.ytimg.com`, `ytimg.com`, `yt3.ggpht.com` |
| YouTube / Google Data APIs | `www.googleapis.com`, `googleapis.com` |

That is the whole list now. The seven entries the old version needed for tool
installation — `pypi.org`, `files.pythonhosted.org`, and the Debian and Ubuntu
mirrors — are gone rather than moved to an install phase: a supply chain that ran
at build time cannot be reached from the running agent, so it does not have to be
granted to it.

If you need to reach other sites (a different video host, your own services),
fork the kit and extend the `network-policy@1` allow list in
`yt-transcript.yaml`.

## Smoke test

```bash
sbx exec yt-shell -- sh -lc 'yt-dlp --version && ffmpeg -version | head -1 && vtt-to-text 2>&1 | head -1'
```

You should see a yt-dlp version, an ffmpeg banner, and the `vtt-to-text` usage line.

## Local clone

If you clone this repo, `run.sh` launches the shell workload kit with the local
kit path. Pass the workspace as its first argument:

```bash
./run.sh .
```

Use a different workload by setting `SBX_WORKLOAD` to any published v3 workload
kit:

```bash
SBX_WORKLOAD=docker.io/olegselajev241/agy-sbx-kit:1.0.0 ./run.sh .
```

`sbx` builds the kit directory on demand and keys the result by source hash, so
editing the descriptor or the Dockerfile and re-running rebuilds only what
changed.

## License

Apache 2.0. See [LICENSE](LICENSE).
