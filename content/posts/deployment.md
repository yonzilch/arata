+++
title = "Deployment"
date = "2026-06-22"
updated = "2022-06-23"
description = "Building and deploying arata to GitHub Pages, Cloudflare Pages, or any static host."
tags = ["docs", "deployment"]
+++

# Deployment

arata builds to a static site in `dist/` that can be deployed to any static host (GitHub Pages, Cloudflare Pages, Netlify, etc.).

## Build

```sh
# Build the complete static site in one command:
gleam run -m build/pipeline
```

This produces everything in `dist/`:

- `index.html` — the SPA shell with FOUC-prevention theme classes and a
  loading indicator inside `<div id="app">`.
- `404.html` — **identical** SPA shell (same payload as `index.html`).
  Static hosts that serve `404.html` for unknown paths (GitHub Pages,
  Cloudflare Pages, Netlify) load the SPA directly on a deep-link refresh —
  modem reads the URL from the address bar and routes to the right post, so
  the URL is preserved verbatim. **No redirect is needed.**
- `app.mjs` — the minified SPA JavaScript bundle (bundled via `bun build`).
- `css/` — the **10 CSS modules** under `dist/css/` (one file per module:
  `base.css`, `layout.css`, `components.css`, `post.css`, `cards.css`,
  `links.css`, `search.css`, `toc.css`, `syntax.css`, `accessibility.css`).
  Each page loads only the modules it needs.
- `content_index.json` — the content tree (posts, pages, links, projects,
  homepage) fetched by the SPA at runtime.
- `search_index.json` — the search corpus (consumed when `search_enabled`
  is `True`).
- `atom.xml` / `rss.xml` — Atom 1.0 and RSS 2.0 feeds (written when
  `rss_enabled` is `True`).
- `sitemap.xml` — sitemap.
- `fonts/`, `icons/`, `images/` — static assets (copied from `static/`).

### What the pipeline does

1. Emits the JSON content index, search index, feeds, sitemap, `index.html`,
   and `404.html` (`index.html` and `404.html` are byte-identical SPA
   shells — the only difference is the filename the host serves).
2. Concatenates the 10 CSS modules under `src/css/` in dependency order and
   writes each one to `dist/css/`. The page templates link only the modules
   that page needs, so a post page loads `post.css` + `toc.css` but the
   projects page does not.
3. Copies all static assets from `static/` (`fonts/`, `icons/`, `images/`)
   to `dist/`.
4. Compiles the Gleam JavaScript and bundles it into `dist/app.mjs` via
   `bun build` (replacing `lustre/dev build`, which requires Erlang/OTP).

### All asset paths are absolute

`index.html` and `404.html` reference the SPA bundle and stylesheet links
with **absolute** paths:

```html
<script type="module" src="/app.mjs"></script>
<link rel="stylesheet" href="/css/base.css" />
<link rel="stylesheet" href="/css/layout.css" />
<!-- …etc… -->
```

This is what makes deep-link refreshes work. A relative `./app.mjs` would
resolve to `/posts/app.mjs` on `/posts/markdown` (a 404), so the SPA would
never boot. Absolute paths resolve from the site root on every route, so
`/posts/markdown`, `/tags/gleam`, and `/` all load the bundle correctly.

### Prerequisites

- **Gleam** >= 1.14
- **Bun** >= 1.0 (for the SPA bundle step — `bun build --outfile dist/app.mjs
  --minify --target=browser`)
- **Erlang/OTP is NOT required** — the pipeline uses `bun build` instead of
  `lustre/dev build`, so no Erlang runtime is needed on the build machine.

## GitHub Pages

1. Push the repo to GitHub.
2. Set up a GitHub Action that runs `gleam run -m build/pipeline` and
   publishes `dist/` to GitHub Pages.
3. GitHub Pages automatically serves `404.html` for unknown paths. Because
   `404.html` **is** the SPA shell (not a redirect), a refresh of
   `/posts/foo` loads the SPA directly, modem reads the URL from the address
   bar, and the correct post renders — the URL is preserved and no redirect
   occurs.

## Cloudflare Pages

1. Connect the repo to Cloudflare Pages.
2. Set the build command to `gleam run -m build/pipeline`.
3. Set the output directory to `dist/`.
4. Cloudflare Pages automatically serves `404.html` for unknown paths, so
   deep links work out of the box — same behaviour as GitHub Pages (SPA
   shell, no redirect, URL preserved).

## Netlify

1. Connect the repo to Netlify.
2. Set the build command to `gleam run -m build/pipeline`.
3. Set the publish directory to `dist/`.
4. Netlify serves `404.html` for unknown paths, so deep-link refreshes load
   the SPA shell and the URL is preserved.

## Custom domain

Set `base_url` in `src/data/site.gleam` to your domain before building — this
is used in the feeds, sitemap, and OpenGraph meta tags.

## Environment requirements

- **Gleam** >= 1.14
- **Bun** >= 1.0 (for the SPA bundle)
- **Erlang/OTP** — not required.
