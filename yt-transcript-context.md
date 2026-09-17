## Video transcript tooling

This sandbox has `yt-dlp`, `ffmpeg`/`ffprobe`, and a `vtt-to-text` command for
turning YouTube videos into clean plain text.

Prefer subtitles over transcription — they are faster, free, and need no model:

1. Fetch subtitles without downloading the video:

   ```sh
   yt-dlp --write-auto-subs --write-subs --sub-langs en --sub-format vtt \
     --skip-download -o '%(title)s.%(ext)s' "<URL>"
   ```

2. Convert the resulting `.vtt` to plain text:

   ```sh
   vtt-to-text "<title>.en.vtt"
   ```

   This strips the WEBVTT header, timestamps, and inline word-timing tags, and
   collapses YouTube's duplicated rolling-caption lines.

If a video has no usable subtitles, download the audio and transcribe it:

```sh
yt-dlp -x --audio-format m4a -o '%(title)s.%(ext)s' "<URL>"
```

`ffmpeg`/`ffprobe` are available for any resampling or format conversion your
transcription step needs.

Useful yt-dlp flags: `--list-subs` (see available caption tracks),
`--dump-json --skip-download` (metadata only), `-f` (format selection).

### The youtube-analyzer skill

A `youtube-analyzer` skill ships with these tools and drives the whole workflow
— routing a request to a quick chat answer, illustrated notes, or a
claim-by-claim fact-check. Its body is at
`/opt/yt-transcript/skills/agents/youtube-analyzer/SKILL.md`, linked into both
`~/.agents/skills/` and `~/.claude/skills/`. Read it from the prefix path when a
shared skills store is mounted over those directories.

The skill's helper scripts sit beside it and run on this kit's own interpreter,
so they work whether or not the workload has a `python3` of its own. Nothing in
this toolchain installs or upgrades anything: it all arrived in the image.
