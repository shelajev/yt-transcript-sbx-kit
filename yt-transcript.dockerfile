# syntax=docker/dockerfile:1
#
# spec.yaml installed this toolchain at sandbox create: two apt-get hooks
# for ffmpeg, a pip install for yt-dlp, and a chmod for the converter this
# kit ships. This builds the same toolchain into the layers instead, with
# an ordinary Dockerfile and no package manager in the result.
#
# Everything lands in one private prefix, /opt/yt-transcript, holding its
# own CPython, its own ffmpeg, and the Python packages yt-dlp needs. A
# mixin lands on a filesystem it did not build, so what it writes outside
# its own prefix is what it takes responsibility for: four symlinks in
# /usr/local/bin and one in each agent's skills directory, and nothing
# else.
#
# The pins below are the version authority. Every artifact is fetched by
# an immutable URL and checked against a digest recorded here, so a
# rebuild either produces the same closure or fails. A bump is editing
# these lines and the `provides` entries in yt-transcript.yaml that report
# what they resolve to.
ARG PYTHON_RELEASE=20260901
ARG PYTHON_VERSION=3.13.15
ARG PYTHON_SHA256_amd64=8a689a077337bea6d1c4bc0b7df1d52fcaa28f5f67e50df8bf417c1e3f9d8874
ARG PYTHON_SHA256_arm64=01ce0ce9189feaead3298abf10d4efe998c55a489b3d5d38ca4f83dda7e7977e

# BtbN publishes ffmpeg's release branches beside master; this is the 9.0
# branch, LGPL variant. The GPL variant adds x264/x265 — encoders this
# workflow never reaches for — and would make the whole artifact GPL,
# which for a kit somebody publishes is a licence decision and not a build
# flag. The build id is part of the URL, so the pin is exact.
ARG FFMPEG_TAG=autobuild-2026-09-17-13-19
ARG FFMPEG_BUILD=n9.0.1-69-g3e11912860
ARG FFMPEG_SHA256_amd64=b6520fe6fad06415653e972cff30b90558dd08b4a871059866af5fc6ffe5fc52
ARG FFMPEG_SHA256_arm64=5e5b3d01f3229e36c459ffb2ae6484717afc52cd59eacf1601abbc70315e8d66

# The prefix, named once. It ends up in the shebangs of the scripts this
# kit ships, so it is a path in the published artifact and not just a
# build detail.
ARG PREFIX=/opt/yt-transcript

# This stage runs on the target platform rather than the builder's: pip
# resolves wheels for the interpreter in front of it, and two of yt-dlp's
# dependencies are C extensions, so a cross-platform build runs the
# install under emulation instead of guessing a wheel tag.
FROM dhi.io/debian-base:trixie-dev AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/*

# A private interpreter, not the workload's.
#
# The v2 install hook was `pip install --break-system-packages yt-dlp`:
# PEP 668 marks a distribution's Python as externally managed, and that
# flag says "install anyway". It works, and it is also the kit reaching
# into a part of the workload it does not own — a tool the sandbox is
# supposed to gain becomes a change to the environment's Python. A mixin
# cannot know which Python a workload carries, or whether it carries one
# at all, so this kit brings its own and leaves the workload's alone.
#
# python-build-standalone is a relocatable CPython that runs from whatever
# prefix it is unpacked into. The prefix here is the prefix at run time,
# because an overlay lands at the paths it was built at, so nothing needs
# relocating and no wrapper has to fix up a path.
ARG TARGETARCH
ARG PREFIX
ARG PYTHON_RELEASE
ARG PYTHON_VERSION
ARG PYTHON_SHA256_amd64
ARG PYTHON_SHA256_arm64
RUN <<'EOF'
set -eu
case "$TARGETARCH" in
  amd64) triple=x86_64-unknown-linux-gnu;  sha=$PYTHON_SHA256_amd64 ;;
  arm64) triple=aarch64-unknown-linux-gnu; sha=$PYTHON_SHA256_arm64 ;;
  # The kit publishes for linux/amd64 and linux/arm64, and says so by
  # failing here rather than by producing an overlay with no binaries in
  # it. glibc is the other half of that statement: these builds link
  # against it, so a musl workload is out of scope.
  *) echo "yt-transcript: no CPython build is pinned for $TARGETARCH" >&2; exit 1 ;;
esac
file="cpython-${PYTHON_VERSION}+${PYTHON_RELEASE}-${triple}-install_only_stripped.tar.gz"
curl -fsSL -o /tmp/python.tar.gz \
  "https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_RELEASE}/${file}"
printf '%s  %s\n' "$sha" /tmp/python.tar.gz | sha256sum -c -
install -d "$PREFIX"
# The tarball unpacks as python/, which is the name this prefix uses.
tar -xzf /tmp/python.tar.gz -C "$PREFIX"
rm -f /tmp/python.tar.gz
"$PREFIX/python/bin/python3" -VV
EOF

# ffmpeg and ffprobe as static binaries.
#
# The v2 install hook was `apt-get install ffmpeg`, which on a workload
# filesystem means ~90 shared objects under /usr/lib that this kit would
# then own, and a kit tied to one distribution's library versions. Static
# binaries in the prefix cost size — which a media toolchain spends anyway
# — and buy landing on any glibc workload without touching a directory the
# base manages.
ARG FFMPEG_TAG
ARG FFMPEG_BUILD
ARG FFMPEG_SHA256_amd64
ARG FFMPEG_SHA256_arm64
RUN <<'EOF'
set -eu
case "$TARGETARCH" in
  amd64) slug=linux64;    sha=$FFMPEG_SHA256_amd64 ;;
  arm64) slug=linuxarm64; sha=$FFMPEG_SHA256_arm64 ;;
  *) echo "yt-transcript: no ffmpeg build is pinned for $TARGETARCH" >&2; exit 1 ;;
esac
file="ffmpeg-${FFMPEG_BUILD}-${slug}-lgpl-9.0.tar.xz"
curl -fsSL -o /tmp/ffmpeg.tar.xz \
  "https://github.com/BtbN/FFmpeg-Builds/releases/download/${FFMPEG_TAG}/${file}"
printf '%s  %s\n' "$sha" /tmp/ffmpeg.tar.xz | sha256sum -c -
install -d /tmp/ffmpeg "$PREFIX/bin" "$PREFIX/share/licences"
tar -xJf /tmp/ffmpeg.tar.xz --strip-components=1 -C /tmp/ffmpeg
# ffplay is in the tarball and stays out of the overlay: a sandbox has no
# display, so it is weight with nothing to do.
install -m 0755 /tmp/ffmpeg/bin/ffmpeg /tmp/ffmpeg/bin/ffprobe "$PREFIX/bin/"
# An image is a distribution, and the LGPL asks that its licence travel
# with the binary.
install -m 0644 /tmp/ffmpeg/LICENSE.txt "$PREFIX/share/licences/ffmpeg-LICENSE.txt"
rm -rf /tmp/ffmpeg /tmp/ffmpeg.tar.xz
"$PREFIX/bin/ffmpeg" -hide_banner -version | head -1
EOF

# yt-dlp and its closure, into the private interpreter's own site-packages.
# No virtualenv: a venv isolates one project from an interpreter shared
# with others, and this interpreter has exactly one tenant, so the venv
# would be a second name for the same directory with an extra absolute
# path baked into pyvenv.cfg.
COPY requirements.txt /tmp/requirements.txt
RUN "$PREFIX/python/bin/python3" -m pip install \
      --no-cache-dir --no-warn-script-location -r /tmp/requirements.txt \
 && rm -f /tmp/requirements.txt \
 && "$PREFIX/python/bin/python3" -m pip list --format=freeze

# This kit's own content, from where it already lives. `files/home/...` is
# the tree v2 copied into the sandbox home, and it stays put: the paths
# these files end up at are the symlinks near the end of this recipe, not
# wherever the build context keeps them.
COPY files/home/.agents/skills/youtube-analyzer /src/skills/agents/youtube-analyzer
COPY files/home/.claude/skills/youtube-analyzer /src/skills/claude/youtube-analyzer
COPY files/home/.local/bin/vtt-to-text /src/bin/vtt-to-text

# Two things that tree needs, and nothing more.
#
# First, the shebangs. Those scripts say `#!/usr/bin/env python3`, which
# resolves against PATH — the workload's Python if it has one, and nothing
# if it does not. Rewriting them to this kit's interpreter is what lets
# them run on a base with no Python at all. The alternative — putting this
# interpreter on PATH as `python3` — would shadow the workload's Python
# for everything in the sandbox, which is the change this kit exists to
# avoid.
#
# Second, the modes. v2 needed an install hook to `chmod +x` the
# converter because its file delivery did not carry one; COPY does, so the
# hook is gone and `install -m` only states what the artifact must have.
RUN <<'EOF'
set -eu
for script in /src/bin/vtt-to-text \
              /src/skills/agents/youtube-analyzer/scripts/compact_vtt.py \
              /src/skills/agents/youtube-analyzer/scripts/embed_images.py; do
  sed -i "1s|^#!.*python3$|#!$PREFIX/python/bin/python3|" "$script"
  head -1 "$script" | grep -qx "#!$PREFIX/python/bin/python3" || {
    echo "yt-transcript: $script does not name the kit's interpreter" >&2
    exit 1
  }
done
install -m 0755 /src/bin/vtt-to-text "$PREFIX/bin/vtt-to-text"
# The skill's body lives in the prefix, keeping the two directories the v2
# kit shipped it to: the agent-neutral implementation, and the Claude shim
# that points at it.
cp -a /src/skills "$PREFIX/skills"
EOF

# Everything above ran at the paths the overlay will occupy, so these are
# the real tools rather than a rehearsal — and they exercise the kit's own
# scripts, not stand-ins. A kit that cannot convert subtitles or process
# media must not publish.
RUN <<'EOF'
set -eu
export PATH="$PREFIX/bin:$PREFIX/python/bin:$PATH"
skill="$PREFIX/skills/agents/youtube-analyzer"
cd "$(mktemp -d)"

# The smoke test from the README, verbatim.
yt-dlp --version
ffmpeg -version | head -1
vtt-to-text 2>&1 | head -1

# Subtitle conversion, against the shape auto-captions arrive in: inline
# word timings, and a cue the next one repeats. The repeat is a whole cue
# because that is what `vtt-to-text` collapses — the skill's own
# `compact_vtt.py` below also removes a partial overlap, and the two are
# not equivalent on real auto-captions.
cat > talk.en.vtt <<'VTT'
WEBVTT
Kind: captions
Language: en

00:00:01.000 --> 00:00:03.500
<00:00:01.240><c>the sandbox</c> is the boundary

00:00:03.500 --> 00:00:06.000
the sandbox is the boundary

00:00:06.000 --> 00:00:08.500
a model cannot argue with

00:00:12.000 --> 00:00:14.000
and that is the whole point
VTT

vtt-to-text talk.en.vtt
grep -qx 'the sandbox is the boundary a model cannot argue with and that is the whole point' talk.en.txt

# The skill's own converter, which keeps timestamps and buckets the text
# into paragraphs.
"$skill/scripts/compact_vtt.py" talk.en.vtt --bucket-seconds 10 > transcript.txt
cat transcript.txt
grep -qx '\[00:01\] the sandbox is the boundary a model cannot argue with' transcript.txt
grep -qx '\[00:12\] and that is the whole point' transcript.txt

# Media processing, offline: synthesise a clip, then extract audio the way
# the context file's no-captions fallback does.
ffmpeg -hide_banner -loglevel error \
  -f lavfi -i "sine=frequency=440:duration=4" \
  -f lavfi -i "testsrc=size=320x240:rate=15:duration=4" \
  -c:v mpeg4 -c:a aac -shortest video.mp4
streams=$(ffprobe -hide_banner -loglevel error -show_entries stream=codec_name -of csv=p=0 video.mp4)
printf '%s\n' "$streams"
printf '%s\n' "$streams" | grep -qx mpeg4
printf '%s\n' "$streams" | grep -qx aac
ffmpeg -hide_banner -loglevel error -i video.mp4 -vn -c:a aac audio.m4a
test -s audio.m4a
test "$(ffprobe -hide_banner -loglevel error -show_entries format=nb_streams -of csv=p=0 audio.m4a)" = 1

# Frame capture through the skill's own script — the path its illustrated
# modes take.
"$skill/scripts/extract_frames.sh" video.mp4 frames 00:00:01 00:00:03
test -s frames/f_000001.jpg
test "$(ffprobe -hide_banner -loglevel error -show_entries stream=codec_name -of csv=p=0 frames/f_000003.jpg)" = mjpeg

# And the HTML embedder, whose requirement is only that it runs at all on
# a Python the workload never supplied.
printf '%s' '<img src="__IMG_hero__">' > template.html
"$skill/scripts/embed_images.py" template.html final.html hero=frames/f_000001.jpg
grep -q 'src="data:image/jpeg;base64,' final.html
EOF

# The overlay, assembled as a tree to be copied whole.
RUN <<'EOF'
set -eu
install -d -m 0755 /out/opt /out/usr/local/bin
cp -a "$PREFIX" "/out$PREFIX"

# The four entry points, on the PATH every workload already has. ENV PATH
# is the other option — a mixin's added PATH elements are merged into the
# composed image — but it only reaches a composed sandbox, while symlinks
# also work for anyone who FROMs this image or copies the prefix out of
# it.
ln -s "$PREFIX/bin/ffmpeg"        /out/usr/local/bin/ffmpeg
ln -s "$PREFIX/bin/ffprobe"       /out/usr/local/bin/ffprobe
ln -s "$PREFIX/bin/vtt-to-text"   /out/usr/local/bin/vtt-to-text
ln -s "$PREFIX/python/bin/yt-dlp" /out/usr/local/bin/yt-dlp

# Each agent's skills directory gets a symlink to the body in the prefix,
# rather than the body itself. The two are not interchangeable: the host's
# shared skills store is a bind mount over that directory when a user has
# one, which hides whatever an image put underneath it. A link that can be
# hidden costs a link; the body it points at is never in the way, and the
# context file names that path so the skill stays readable either way.
install -d -m 0755 /out/home/agent/.agents/skills /out/home/agent/.claude/skills
ln -s "$PREFIX/skills/agents/youtube-analyzer" /out/home/agent/.agents/skills/youtube-analyzer
ln -s "$PREFIX/skills/claude/youtube-analyzer" /out/home/agent/.claude/skills/youtube-analyzer

# A directory in an overlay carries its own ownership and mode onto the
# workload's copy of that path. /home/agent belongs to uid 1000 on every
# conforming base, and an overlay that recreated it root-owned would take
# the agent's own home away from it.
chown -R 1000:1000 /out/home/agent
chown 0:0 /out/home
EOF

# The overlay: one prefix, four symlinks, and the skill at both paths the
# agents read — landing on any glibc workload.
FROM scratch
COPY --from=build /out /
