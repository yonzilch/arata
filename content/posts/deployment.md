+++
title = "Deployment"
date = "2026-06-22"
updated = "2026-07-05"
description = "Arata deployment guide"
tags = ["docs", "deployment"]
+++

# Deployment

Arata builds to a static site in `dist/` that can be deployed to any static
host — GitHub Pages, Cloudflare Pages, Netlify, or anything else that can
serve a folder of files.

## Local setup

The fastest path is [**Nix**](https://github.com/nixos/nix) + [**direnv**](https://github.com/direnv/direnv)

For Arata project, `flake.nix` with a `devshell` provides the exact [Bun](https://github.com/oven-sh/bun) and [Gleam](https://github.com/gleam-lang/gleam) on both x86 and ARM.

```sh
direnv allow
```

That's it — `bun` and `gleam` are now on your `PATH` inside the project
directory, with nothing installed globally and nothing to keep in sync
manually.

If you'd rather not use Nix, just make sure you have Gleam
`>= 1.14` and Bun `>= 1.0` installed yourself.

## Local development (hot reload)

```sh
bun run dev
```

This starts a dev server at `http://localhost:3333` that:

- runs an initial build of the full site,
- watches `src/`, `content/`, `static/`, and `gleam.toml`,
- rebuilds automatically on any change, and
- pushes a live-reload signal to your browser tab — no manual refresh.

Use this while writing posts or working on templates/styles.

## Building for production

```sh
bun run rebuild
```

This is a clean build: it removes any existing `dist/`, then runs the
Gleam pipeline (`gleam run -m build/pipeline`) to regenerate everything
from scratch. Use this before deploying, and use it as the build command
in CI.

Want to sanity-check the production build locally before pushing it
anywhere? `bun run preview` does a clean rebuild and then serves `dist/`
at `http://localhost:3333` — this is the closest local approximation of
what your static host will actually serve.

| Script            | What it does                                   |
| ----------------- | ----------------------------------------------- |
| `bun run dev`      | Hot-reload dev server                          |
| `bun run build`    | Build once (no cleanup)                        |
| `bun run rebuild`  | Clean build (`rm -rf dist` + build) — use this for deploys |
| `bun run preview`  | Clean build + serve, to check the prod output locally |
| `bun run check`    | `gleam check` + `gleam test`                   |
| `bun run clean`    | Remove `dist/` and `build/`                    |

## Deploying

### GitHub Pages

1. Push the repo to GitHub.
2. Add a GitHub Action that runs `bun run rebuild` and publishes `dist/`
   to GitHub Pages.
3. Done — GitHub Pages serves `404.html` for unknown paths automatically,
   so deep-link refreshes (e.g. `/posts/foo`) load the SPA and resolve to
   the right page with the URL untouched. No redirect rule needed.

### Cloudflare Pages

1. Connect the repo to Cloudflare Pages.
2. Build command: `bun run rebuild`. Output directory: `dist/`.
3. Same `404.html`-as-SPA-shell behavior as GitHub Pages — deep links
   work out of the box.

### Netlify

1. Connect the repo to Netlify.
2. Build command: `bun run rebuild`. Publish directory: `dist/`.
3. Same as above: Netlify serves `404.html` for unknown paths.

### Custom domain

Set `base_url` in `src/data/config.gleam` to your domain before building.
It's used in feeds, the sitemap, and OpenGraph meta tags.

### If your host deploys straight from `git push` (no build step)

`dist/` is gitignored by default, since it's a build artifact regenerated
by CI on every deploy. If your target platform instead deploys whatever
you push to a branch **without running a build step** (some PaaS setups
work this way), you'll need to commit `dist/` for that branch specifically:

```sh
git add -f dist
```

Keep this to a dedicated deploy branch rather than committing build
output on `main` — it's easy to forget to regenerate it and ship a stale
`dist/`.

---

## Appendix: the build pipeline in detail

### Prerequisites

- **Gleam** >= 1.14
- **Bun** >= 1.0 (used for the SPA bundle step and the dev server)
- **Erlang/OTP is not required** — the pipeline uses `bun build` instead
  of `lustre/dev build`, so there's no Erlang runtime to install.

### What `gleam run -m build/pipeline` does

1. Generates `index.html` and `404.html` — byte-identical SPA shells;
   the only difference is which filename the host serves for unknown
   paths.
2. Builds the 10 CSS modules from `src/css/` into `dist/css/`. Each page
   links only the modules it needs (a post loads `post.css` + `toc.css`;
   the projects page doesn't).
3. Copies static assets (`fonts/`, `icons/`, `images/`) from `static/`
   into `dist/`.
4. Bundles the Gleam-compiled JS into `dist/app.mjs` via `bun build
   --minify`.
5. Writes `content_index.json`, `search_index.json`, `atom.xml`,
   `rss.xml`, `sitemap.xml`, `robots.txt`, and `llms.txt`.

### Why asset paths are absolute

`index.html` / `404.html` reference assets with absolute paths:

```html
<script type="module" src="/app.mjs"></script>
<link rel="stylesheet" href="/css/base.css" />
```

This is required for deep links to work: a relative `./app.mjs` would
resolve to `/posts/app.mjs` on a route like `/posts/markdown` — a 404,
and the SPA would never boot. Absolute paths always resolve from the
site root, regardless of which route served the shell.
