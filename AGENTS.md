# leehack.com

Personal link page for Jhin Lee, built with Jaspr in static mode and deployed to GitHub Pages.

## Commands

Jaspr is pinned to a 0.24 beta because the 0.23 stable line does not resolve on Dart 3.14. Use the project-local CLI, not a global `jaspr`.

- Build: `dart run jaspr_cli:jaspr build` (output in `build/jaspr/`)
- Dev server: `dart run jaspr_cli:jaspr serve`
- Analyze: `dart analyze`
- Refresh live numbers: `dart run tool/refresh.dart`
- Short-link pages, after a build: `dart run tool/shortlinks.dart`

## Layout

- `content/site.yaml`: all hand-edited content. Adding a link, talk or chip must never need a code change.
- `content/live.json`: generated numbers and posts. Committed so that builds work offline.
- `lib/`: Jaspr components. `lib/main.server.dart` runs at build time and may use `dart:io`.
- `tool/`: build-time scripts, plain Dart.
- `design/mockup.html`: the approved design. It is the visual and behavioural spec, not shipped.
- `web/images/llama.svg`: Noto Emoji llama, Apache 2.0.
- `web/images/dash.png`: Dash, Flutter's mascot, from the Flutter brand page.
- Colour themes are the variable blocks at the top of `web/site.css`. The default is navy; the list in `site_interactions_web.dart` must match.

## Content contract

`content/live.json`:

```json
{
  "generatedAt": "2026-11-20T18:11:40Z",
  "packages": {"mcp_dart": {"downloads30d": 443323, "stars": 116}},
  "postCount": 20,
  "posts": [{"title": "…", "url": "https://dev.to/…", "date": "2026-10-20"}]
}
```

- `packages` has one entry per package listed under any `type: packages` answer in `site.yaml`, keyed by its `name`. `downloads30d` comes from `pub`, `stars` from `repo`.
- `posts` is newest first and holds at least `sources.posts_shown` entries.
- `profile.facts` is the line under the name. `{downloads}` in a fact's `value` becomes the sum of `downloads30d`, in thousands.

The site reads the base path from the `SITE_BASE` environment variable at build time, defaulting to `/`.

## Rules

- No email address anywhere on the site.
- No career history or CV content.
- All motion must switch off under `prefers-reduced-motion`.
- With JavaScript disabled, every answer and link must still be readable.
