# leehack.com

Personal link page built with Jaspr and deployed to GitHub Pages.

## Edit the site

Make content changes in [content/site.yaml](content/site.yaml).

- Add or edit a link under `links`. Reference its key in `nav` to show it in the header, or in the `links` answer’s `items` to show it there.
- Add or edit a chip under `answers`. Give it a unique `id`, chip text, a lead, and one of the existing types: `packages`, `list`, `posts`, or `links`.
- Add a talk under the `speak` answer’s `items`. The line of facts under the name is `profile.facts`. Update its talk count by hand.
- Add a key and destination URL under `shortlinks`. A key like `flight-mode-ai` creates `/flight-mode-ai/` and accepts lowercase letters, digits, and hyphens.
- To enable Google Analytics, set `analytics.ga_measurement_id` to your GA4 measurement ID, such as `G-XXXXXXXXXX`.

[content/live.json](content/live.json) stores 30-day downloads from pub.dev and the latest posts from dev.to. The checked-in snapshot lets you build offline.

## Run locally

Use Dart 3.14 and the project’s Jaspr CLI.

```sh
dart pub get
dart run jaspr_cli:jaspr serve
dart analyze
dart test
dart run tool/refresh.dart
dart run jaspr_cli:jaspr build
dart run tool/shortlinks.dart
dart run tool/not_found.dart
```

The dev server is available at `http://localhost:8080`. The static build, short-link pages, and `404.html` go to `build/jaspr/`. For a subpath deployment, use the same `SITE_BASE` for the build and `tool/not_found.dart`. Refresh is optional for local builds.

## Themes

Colour themes are defined once, in `lib/site_themes.dart`. The first entry is the default; adding an entry there adds it to the footer's theme switch.

The fonts are self-hosted under `web/fonts/` and licensed under the SIL Open Font License (OFL).

## Deploy and cut over

The Pages workflow runs on pushes to `main`, daily at 09:17 UTC, and on manual dispatch. It runs static analysis and tests before building. It refreshes the snapshot for the build, uses the Pages base path for assets, and deploys the output.

1. In GitHub **Settings → Pages**, select **GitHub Actions** as the source. Run the workflow and check the site at its GitHub Pages URL.
2. At cutover, add `web/CNAME` containing only `leehack.com` and set `leehack.com` as the custom domain in GitHub **Settings → Pages**.
3. In Cloudflare, point the apex DNS records at GitHub Pages and remove the existing redirect rule. Keep the `_atproto` TXT record because the Bluesky handle is `leehack.com`. [GitHub Pages DNS records](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#dns-records-for-your-custom-domain)
4. After DNS resolves, enable **Enforce HTTPS** in Pages and check the homepage and a short link at `https://leehack.com`.

Llama artwork by [Noto Emoji](https://github.com/googlefonts/noto-emoji), licensed under Apache 2.0. Dash is Flutter's mascot; the image comes from the [Flutter brand page](https://flutter.dev/brand).

## Resource finder

The homepage finder uses the same catalog as the profile answers. Links are visible
without JavaScript. Keyword search filters them in the browser. Add an optional
`summary` to a talk or community entry to give the finder more context.

To try the optional local semantic search:

```sh
bash prototypes/flight-mode/build.sh
python3 prototypes/flight-mode/serve.py
```

Use the search field below the intro on the [local homepage](http://127.0.0.1:8094/).
After the page finishes loading, the browser downloads and initializes the
37 MB BGE-small English model and embeds the resource catalog in the
background. When a browser reports Data Saver, it waits for the first search.
Once local search is ready, pressing Enter or choosing **Search** only needs
to embed the question and rank the links. The browser reuses the weights from
Cache Storage across visits until it clears them.

The preview serves the version-matched llamadart bridge and cross-origin
isolation headers. The Pages workflow packages the same model and bridge.
At the public edge, the homepage and bridge worker responses must include
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`. The finder uses keyword search
when the page is not cross-origin isolated.
