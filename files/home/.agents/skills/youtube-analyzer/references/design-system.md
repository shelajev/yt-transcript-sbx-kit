# Illustrated notes design system

Use this fixed visual identity for `notes`, `brief`, and `series` output so multiple
summaries read as a coherent collection rather than one-off pages. Use the single
GitHub-inspired dark theme deliberately; do not add a light-mode override. Paint each
color explicitly so the page works regardless of the viewer's theme.

## Contents

- [CSS](#css)
- [Single-video page skeleton](#single-video-page-skeleton)
- [`notes` walkthrough](#notes-walkthrough)
- [`brief` key moments](#brief-key-moments)
- [Writing rules](#writing-rules)
- [`series` index](#series-index)

## CSS

Copy this CSS verbatim into each generated page:

```css
:root{--bg:#0d1117;--panel:#161b22;--fg:#e6edf3;--muted:#9aa7b4;--accent:#4aa3ff;--accent2:#f0883e;--border:#30363d;--code:#1f2630}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:900px;margin:0 auto;padding:40px 24px 90px}
h1{font-size:2.05rem;line-height:1.2;margin:.2em 0 .3em;text-wrap:balance}
h2{font-size:1.45rem;margin:2.3em 0 .6em;padding-bottom:.3em;border-bottom:1px solid var(--border)}
h3{font-size:1.14rem;margin:1.9em 0 .4em;color:#fff}
h3 a.ts{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:.85rem;color:var(--accent);font-weight:400;margin-left:.5em;white-space:nowrap}
h3 a.ts:hover{text-decoration:underline}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
a:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
p{margin:.7em 0}
.sub{color:var(--muted);font-size:.98rem;margin:.2em 0 1.6em}
.meta{color:var(--muted);font-size:.9rem;margin:0 0 1.6em;border-bottom:1px solid var(--border);padding-bottom:1.2em;display:flex;flex-wrap:wrap;gap:.3em 1.4em;font-variant-numeric:tabular-nums}
.meta b{color:var(--fg);font-weight:600}
blockquote{margin:1em 0;padding:.7em 1.1em;border-left:4px solid var(--accent2);background:var(--panel);color:#f5e8dc;border-radius:0 6px 6px 0;font-style:italic;font-size:.95rem}
blockquote.pull{color:var(--fg);font-style:normal;border-left-color:var(--accent);background:var(--panel)}
code{background:var(--code);padding:.12em .4em;border-radius:4px;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:.9em}
table{border-collapse:collapse;width:100%;margin:1.2em 0;font-size:.9rem;display:block;overflow-x:auto}
th,td{border:1px solid var(--border);padding:7px 10px;text-align:left;vertical-align:top}
th{background:var(--panel)}
tr:nth-child(even) td{background:rgba(255,255,255,.02)}
figure{margin:1.3em 0;text-align:center}
figure img{max-width:100%;height:auto;border:1px solid var(--border);border-radius:10px;box-shadow:0 8px 30px rgba(0,0,0,.4)}
figcaption{color:var(--muted);font-size:.83rem;margin-top:.55em;padding:0 8px}
hr{border:none;border-top:1px solid var(--border);margin:2.3em 0}
ol.threads{padding-left:1.3em;margin:1em 0}
ol.threads li{margin-bottom:1.1em}
ul.remember{padding-left:1.3em;margin:1em 0}
ul.remember li{margin-bottom:.8em}
.tag{display:inline-block;font-size:.72rem;color:var(--accent2);border:1px solid var(--accent2);border-radius:20px;padding:1px 9px;margin-left:6px;vertical-align:middle}
.note{background:var(--panel);border:1px solid var(--border);border-left:4px solid var(--accent2);border-radius:0 8px 8px 0;padding:14px 18px;color:var(--muted);font-size:.87rem;margin:2.2em 0 0}
footer{margin-top:2em;color:var(--muted);font-size:.83rem;border-top:1px solid var(--border);padding-top:1.3em}
.cards{display:grid;gap:18px;margin:1.2em 0}
.card{display:block;background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:20px 22px;transition:border-color .15s,transform .15s}
.card:hover{border-color:var(--accent);transform:translateY(-2px);text-decoration:none}
.card h3{margin:.1em 0 .3em;font-size:1.2rem;color:#fff}
.card .meta{color:var(--muted);font-size:.85rem;margin-bottom:.5em;border:none;padding:0}
.card p{margin:.4em 0 0;color:var(--fg);font-size:.95rem}
@media (prefers-reduced-motion: reduce){ *{transition:none !important} }
```

The `.cards` and `.card` rules are needed only for a `series` index.

## Single-video page skeleton

Use this order for `notes` and `brief`:

1. `<title>` and the CSS above.
2. `.wrap > h1`: the actual talk or video title.
3. `.sub`: one sentence stating who speaks, what they argue, and what they show.
   Write this after reading the entire transcript.
4. `.meta`: flex items for video link, channel, upload date, event or speaker context,
   duration, and views/likes when available. Never invent missing values.
5. Header `<figure>`: a title slide when available, otherwise a characteristic early
   frame.
6. `<blockquote>`: caption language, any correction made from slide text, and a note
   that timestamped headings link to the video.
7. `<hr>`.
8. `<h2>TL;DR</h2>` plus `<ol class="threads">` containing 3-5 threads. Give each a
   bold claim, one or two supporting sentences, and a timestamped quote or paraphrase.
   Close with one line beginning **Why it matters**.
9. `<hr>`.
10. `<h2>Walkthrough</h2>` for `notes`, or `<h2>Key moments</h2>` for `brief`.
11. `<hr>`.
12. `<h2>What to remember</h2>` plus `<ul class="remember">` with 3-5 takeaways.
13. For `notes` only, add `<hr>` and `<h2>Frames &amp; slides</h2>` with a table of
    every embedded image, linked timestamp, and one-line description.
14. `.note`: source and attribution, commentary use of stills and quotes, and an
    unofficial/independent disclaimer.
15. `<footer>`: captions and frame-capture methodology, caption-error caveat, and any
    relevant resource limitation.

## `notes` walkthrough

Use one `<h3>` per real structural beat rather than forcing a fixed count:

```html
<h3>Beat title <a class="ts" href="https://youtu.be/<id>?t=<seconds>">[MM:SS]</a></h3>
<figure>
  <img loading="lazy" src="__IMG_<token>__" alt="<literal description of the screen>">
  <figcaption><description or the slide's key line></figcaption>
</figure>
<p>Prose. <strong>Bold</strong> the key claim or term. <em>&ldquo;Exact quote.&rdquo;</em>
[<a href="...">MM:SS</a>] for quoted or specifically attributed material.</p>
```

Not every beat needs a figure. Skip it for segments without a useful visual.

## `brief` key moments

Use a single table instead of one heading per beat:

```html
<h2>Key moments</h2>
<div class="table-wrap">... Timestamp | What happens | Why it matters ...</div>
```

Place at most one or two supporting figures immediately after the TL;DR.

## Writing rules

- Verify each bracketed timestamp against the transcript line containing the actual
  quotation or attribution, not the nearest round beat boundary.
- Prefer the speaker's exact on-screen slide text to an auto-caption rendering of the
  same words. Disclose corrections in the methodology blockquote.
- Use `<em>` for exact speech and `<strong>` for the analytical claim. Do not italicize
  paraphrases.
- Make every heading timestamp a real `https://youtu.be/<id>?t=<seconds>` link.
- Attribute factual assertions to the speaker. A transcript proves that a statement
  was made, not that it is true.
- Include real friction, such as a broken demo or an overstated claim, rather than
  smoothing it over.
- Write for someone deciding whether and where to watch: preserve the argument's
  sequence, explain demonstrations, and make the page useful without the video.

## `series` index

Build one index plus a `notes` or `brief` page for each video:

- Use `.wrap > h1` and `.sub`, followed by `.cards > a.card` elements linking to each
  page. Each card contains its title, optional `.tag`, metadata, and one summary
  sentence.
- Put `<p class="home"><a href="index.html">&larr; All sessions</a></p>` at the top
  of each detail page.
- For one multi-talk stream, split by transcript and title-card boundaries, not fixed
  durations. Add a talk-index table with `#`, `Time`, `Talk`, `Speaker(s)`, and `Org`
  before the detailed talk sections.
