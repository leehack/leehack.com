# leehack.com

Personal link page built with Jaspr and deployed to GitHub Pages.

## Edit the site

Make content changes in [content/site.yaml](content/site.yaml).

- Add or edit a link under `links`. Reference its key in `nav` to show it in the header, or in the `links` answer’s `items` to show it there.
- Add or edit a chip under `answers`. Give it a unique `id`, chip text, a lead, and one of the existing types: `packages`, `list`, `posts`, or `links`.
- Add a talk under the `speak` answer’s `items`. The line of facts under the name is `profile.facts`; update its talk count by hand.
- Add a key and destination URL under `shortlinks`. A key like `flight-mode-ai` creates `/flight-mode-ai/` and accepts lowercase letters, digits, and hyphens.
- To enable Google Analytics, set `analytics.ga_measurement_id` to your GA4 measurement ID, such as `G-XXXXXXXXXX`.

[content/live.json](content/live.json) stores 30-day downloads from pub.dev, GitHub stars, and the total and latest posts from dev.to. The checked-in snapshot lets you build offline.

## Run locally

Use Dart 3.14 and the project’s Jaspr CLI.

```sh
dart pub get
dart run jaspr_cli:jaspr serve
dart analyze
dart run tool/refresh.dart
dart run jaspr_cli:jaspr build
dart run tool/shortlinks.dart
```

The dev server is available at `http://localhost:8080`. The static build and short-link pages go to `build/jaspr/`. Refresh is optional for local builds.

## Deploy and cut over

The Pages workflow runs on pushes to `main`, daily at 09:17 UTC, and on manual dispatch. It refreshes the snapshot for the build, uses the Pages base path for assets, and deploys the output.

1. In GitHub **Settings → Pages**, select **GitHub Actions** as the source. Run the workflow and check the site at its GitHub Pages URL.
2. At cutover, add `web/CNAME` containing only `leehack.com` and set `leehack.com` as the custom domain in GitHub **Settings → Pages**.
3. In Cloudflare, point the apex DNS records at GitHub Pages and remove the existing redirect rule. Keep the `_atproto` TXT record because the Bluesky handle is `leehack.com`. [GitHub Pages DNS records](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#dns-records-for-your-custom-domain)
4. After DNS resolves, enable **Enforce HTTPS** in Pages and check the homepage and a short link at `https://leehack.com`.

Llama artwork by [Noto Emoji](https://github.com/googlefonts/noto-emoji), licensed under Apache 2.0. Dash is Flutter's mascot; the image comes from the [Flutter brand page](https://flutter.dev/brand).
