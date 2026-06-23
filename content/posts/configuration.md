+++
title = "Configuration"
date = "2026-06-24"
updated = "2026-06-23"
description = "Comprehensive configuration guide for arata."
tags = ["guide", "config"]
+++

# Configuration

arata is configured through Gleam modules. The important split is:

- **`src/config.gleam`** — the user-facing configuration source:
  `Config`, `config.default()`, and `config.site_meta()`.
- **`src/data/site.gleam`** — shared metadata types only:
  `SiteMeta`, `Analytics`, and `CommentsConfig`.

`config.gleam` is the single place where default site values live. The SPA
runtime and the build pipeline both read from it, so values such as title,
description, RSS settings, analytics, comments, and favicon configuration do
not drift between build-time and runtime paths.

A future phase may replace these hardcoded Gleam constants with a `config.toml`
or JSON loader, but the documented field names and semantics are intended to
remain stable.

The build pipeline:

```sh
gleam run -m build/pipeline
````

reads Markdown files from `content/`, parses TOML frontmatter with `tom`,
renders Markdown bodies with <https://hex.pm/packages/mork>, writes
`dist/content_index.json`, emits crawler files and feeds, copies static
assets, inlines CSS into the HTML shell, and bundles the SPA into
`dist/app.mjs`.

At runtime, the browser fetches `/content_index.json` once via `rsvp`.
The browser never reads Markdown files or uses filesystem APIs.

## Site Configuration

The main config lives in `src/config.gleam`.

### `Config`

`Config` drives the header, navigation, socials, logo, favicon, font
overrides, feature toggles, and runtime analytics injection.

Example:

```gleam
Config(
  title: "Arata",
  description: "Arata is a modern and minimalistic blog theme powered by Gleam and Lustre.",
  menu: [
    MenuItem(name: "posts", url: "/posts"),
    MenuItem(name: "projects", url: "/projects"),
    MenuItem(name: "links", url: "/links"),
    MenuItem(name: "tags", url: "/tags"),
    MenuItem(name: "about", url: "/about"),
  ],
  socials: default_socials(rss_enabled),
  logo: Some("/images/avatar.avif"),
  favicon: Some("/images/favicon.ico"),
  rss_enabled: True,
  fonts: Fonts(
    text: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif",
    header: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif",
    code: "ui-monospace, \"Cascadia Code\", \"Source Code Pro\", Menlo, Consolas, \"DejaVu Sans Mono\", monospace",
  ),
  search_enabled: True,
  analytics: AnalyticsDisabled,
  mathjax_enabled: True,
  sidebar_enabled: True,
  floating_buttons_enabled: True,
)
```

### `title` and `description`

Site-wide title and description.

* `title` is used by the header when no logo is configured.
* `description` is used for metadata and content index configuration.

Keep these aligned with `config.site_meta()` by deriving `Config` defaults
from `site_meta()` when possible.

### `menu`

A list of `MenuItem(name, url)` values rendered in the header.

```gleam
MenuItem(name: "posts", url: "/posts")
MenuItem(name: "projects", url: "/projects")
MenuItem(name: "links", url: "/links")
MenuItem(name: "tags", url: "/tags")
MenuItem(name: "about", url: "/about")
```

Rules:

* `name` is the displayed label.
* `url` should usually be an absolute site path beginning with `/`.
* Internal routes are handled by modem as SPA navigation.

Common routes:

```txt
/
 /posts
 /posts/page/{n}
 /posts/{slug}
 /projects
 /links
 /tags
 /tags/{name}
 /{slug}
```

### `socials`

Social links are rendered as icon links in the header.

```gleam
Social(
  name: "GitHub",
  url: "https://github.com/yonzilch/arata",
  icon: "github",
)
```

Fields:

* `name` — accessible label.
* `url` — link target.
* `icon` — SVG filename without extension under `static/icons/social/`.

For example:

```gleam
icon: "github"
```

resolves to:

```txt
/icons/social/github.svg
```

The default RSS social link is added only when `rss_enabled` is `True`:

```gleam
Social(name: "RSS", url: "/atom.xml", icon: "rss")
```

Use an absolute root path like `/atom.xml` so the RSS link works from nested
routes such as `/posts/configuration`.

### `logo`

An `Option(String)`.

```gleam
logo: Some("/images/avatar.avif")
```

When `None`, the header renders the site title as text. When `Some(path)`,
the header renders the image.

Use an absolute path beginning with `/`:

```gleam
Some("/images/avatar.avif")
```

Avoid relative paths like:

```gleam
Some("images/avatar.avif")
```

because deep-link refreshes may resolve them relative to the current route.

### `favicon`

An `Option(String)` used by the build pipeline when generating `index.html`
and `404.html`.

```gleam
favicon: Some("/images/avatar.avif")
```

When `None`, arata falls back to the default favicon path.

Recommended:

```gleam
favicon: Some("/images/favicon.ico")
```

or:

```gleam
favicon: Some("/images/avatar.avif")
```

As with `logo`, prefer absolute root paths.

### `fonts`

A `Fonts(text, header, code)` record containing CSS `font-family`
declarations.

```gleam
Fonts(
  text: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif",
  header: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif",
  code: "ui-monospace, \"Cascadia Code\", \"Source Code Pro\", Menlo, Consolas, \"DejaVu Sans Mono\", monospace",
)
```

These values are injected as CSS custom property overrides:

```css
:root {
  --text-font: ...;
  --header-font: ...;
  --code-font: ...;
}
```

The rest of the stylesheet resolves fonts through those variables.

### `rss_enabled`

A `Bool`.

When `True`:

* `dist/atom.xml` is written.
* `dist/rss.xml` is written.
* feed `<link rel="alternate">` tags are emitted in the HTML shell.
* the RSS social icon is included.

When `False`:

* feed files are skipped.
* feed `<link>` tags are omitted.
* RSS social is omitted.

`robots.txt`, `llms.txt`, and `sitemap.xml` are independent of this toggle.

### `search_enabled`

A `Bool`.

When `True`:

* the search button is rendered.
* the search modal is mounted.
* Cmd/Ctrl+K opens search.
* `dist/search_index.json` is generated and used by the SPA.

When `False`:

* search UI is omitted.
* global search shortcut is not subscribed to.

### `mathjax_enabled`

A `Bool`.

When `True`, post pages trigger MathJax typesetting for inline and display
LaTeX.

When `False`, MathJax effects are skipped.

Use `False` if no posts contain math.

### `sidebar_enabled`

A `Bool`.

When `True`, post pages render the right sidebar containing:

* post tags
* table of contents

When `False`, the right sidebar is omitted and the post body gets more space.

### `floating_buttons_enabled`

A `Bool`.

When `True`, post pages render the floating ToC/tags button and overlay.

When `False`, the floating button and overlay are omitted.

### `analytics`

One of:

```gleam
AnalyticsDisabled
GoatCounter(user: "your-user", host: "goatcounter.com")
Umami(website_id: "xxx", host_url: "https://analytics.example.com")
```

Google Analytics is intentionally not supported.

## Site Metadata

`SiteMeta` is defined in `src/data/site.gleam`, but its default value is
configured in `src/config.gleam` via `site_meta()`.

Example:

```gleam
pub fn site_meta() -> SiteMeta {
  SiteMeta(
    base_url: "https://example.com",
    title: "Yon Zilch",
    description: "This is Yonzilch's blog",
    analytics: AnalyticsDisabled,
    comments: CommentsDisabled,
    fediverse_creator: None,
    rss_enabled: True,
  )
}
```

### `base_url`

The canonical deployed site URL.

Used by:

* feeds
* sitemap
* robots.txt
* llms.txt
* absolute canonical resource links

Do not include a trailing slash unless your deployment path requires it.
The build helpers normalize trailing slashes where needed.

Example:

```gleam
base_url: "https://blog.example.com"
```

For subdirectory deployments:

```gleam
base_url: "https://example.com/blog"
```

### `title` and `description`

Used for SEO, feeds, and generated metadata.

These should usually match `Config.title` and `Config.description`.

### `analytics`

Same analytics type used by `Config`.

### `comments`

One of:

```gleam
CommentsDisabled
Utterances(repo: "user/repo")
Giscus(
  repo: "user/repo",
  repo_id: "...",
  category: "...",
  category_id: "...",
)
```

### `fediverse_creator`

An `Option(String)`.

```gleam
fediverse_creator: Some("@you@example.social")
```

or:

```gleam
fediverse_creator: None
```

When present, arata can emit Fediverse creator metadata.

### `rss_enabled`

The build pipeline reads RSS behavior from `SiteMeta`.

Keep this synchronized with `Config.rss_enabled`. The recommended approach is
to derive `Config` values from `site_meta()` in `config.gleam`.

## Content Authoring

All content lives under `content/`.

```txt
content/
├── posts/
├── pages/
├── links/
└── projects/
```

Each Markdown file uses TOML frontmatter delimited by `+++`.

```toml
+++
title = "My Post"
date = "2026-02-01"
description = "A short summary."
tags = ["gleam", "lustre"]
+++

Body in Markdown.
```

YAML frontmatter is not supported.

## Posts

Directory:

```txt
content/posts/*.md
```

Frontmatter:

```toml
+++
title = "Hello, arata"
date = "2026-01-15"
updated = "2026-01-18"
description = "Introducing arata."
tags = ["gleam", "lustre"]
draft = false
tldr = "One-line summary."
+++
```

Fields:

* `title` — post title.
* `date` — publish date.
* `updated` — optional update date.
* `description` — summary used in lists/search.
* `tags` — optional list of tags.
* `draft` — optional bool, default `false`.
* `tldr` — optional summary box above the post body.

Posts are sorted by date descending.

Post body Markdown is rendered to HTML at build time. Heading IDs are added
after rendering so the ToC and heading links point to stable anchors.

CJK headings that cannot safely become URL fragments use sequential fallback
IDs such as:

```txt
heading-1
heading-2
```

## Pages

Directory:

```txt
content/pages/*.md
```

Frontmatter:

```toml
+++
title = "About"
subtitle = "Optional subtitle"
+++
```

Pages are standalone routes:

```txt
/about
/any-page-slug
```

Special page:

```txt
content/pages/home.md
```

backs the homepage route:

```txt
/
```

## Links

Directory:

```txt
content/links/*.md
```

Links are external cards shown on `/links`.

### Native arata format

```toml
+++
title = "Gleam"
url = "https://gleam.run"
description = "A friendly language for building type-safe systems."
image = "https://gleam.run/favicon.ico"
weight = 10
+++
```

### Zola-compatible format

arata also supports Zola-style link fields:

```toml
+++
title = "Fovir.FYI"
description = ""
weight = 6

[extra]
remote_image = "https://avatars-githubusercontent-webp.webp.se/u/175422207"
link_to = "https://www.fovir.fyi/"
+++
```

Supported fields:

* `title`
* `description`
* `url`
* `image`
* `weight`
* `[extra].link_to`
* `[extra].remote_image`

Resolution rules:

* `url` is used first.
* if `url` is missing, `[extra].link_to` is used.
* `image` is used first.
* if `image` is missing, `[extra].remote_image` is used.
* missing `weight` defaults to `999`.

### Link ordering

Links support Zola-style weight ordering:

```txt
smaller weight = earlier position
```

Example:

```toml
weight = 1
```

appears before:

```toml
weight = 10
```

When two links have the same weight, arata falls back to lowercase title
ordering for deterministic output.

This prevents `/links` ordering from depending on filesystem directory order.

## Projects

Directory:

```txt
content/projects/*.md
```

Frontmatter:

```toml
+++
title = "arata"
description = "A faithful reimplementation of the apollo blog theme in Gleam and Lustre."
link_to = "https://github.com/yonzilch/arata"
image = "/images/projects/arata.png"
github = "https://github.com/yonzilch/arata"
gitlab = "https://gitlab.com/user/project"
codeberg = "https://codeberg.org/user/project"
forgejo = "https://forgejo.example.com/user/project"
demo = "https://arata.example.com"
tags = ["gleam", "lustre", "blog"]
+++
```

Supported hosting fields:

* `github`
* `gitlab`
* `codeberg`
* `forgejo`

Projects are sorted by slug.

## Static Files and Crawler Files

The build pipeline emits:

```txt
dist/sitemap.xml
dist/robots.txt
dist/llms.txt
```

### `sitemap.xml`

Contains crawlable post and page URLs.

### `robots.txt`

Generated from `SiteMeta.base_url`.

Example:

```txt
User-agent: *
Allow: /

Sitemap: https://example.com/sitemap.xml
```

### `llms.txt`

Generated as Markdown for LLM/agent consumers.

It includes:

* H1 title
* site description
* core links
* posts
* pages
* projects
* external links
* sitemap link

The file is intended as a concise map of important site resources.

## Theme

### Light / Dark / Auto

The theme toggle cycles:

```txt
Light → Dark → Auto → Light
```

The selected value is persisted in `localStorage`.

When `Auto` is selected, arata follows `prefers-color-scheme` and updates
when the operating system theme changes.

### Accent color

The accent color is defined in `src/css/base.css`:

```css
:root {
  --primary-color: #3555b3;
}
```

Change this variable to recolor links, active nav states, tags, heading
prefixes, selection highlights, and other accent surfaces.

## CSS

Source CSS is split into modules under:

```txt
src/css/
```

Current modules:

```txt
base.css
layout.css
components.css
post.css
cards.css
links.css
search.css
toc.css
syntax.css
accessibility.css
```

The build pipeline still copies these files to:

```txt
dist/css/
```

for inspection and debugging.

However, for performance, the SPA shell no longer references each file with
render-blocking `<link rel="stylesheet">` tags. Instead, the build pipeline
inlines the CSS modules into `index.html` and `404.html` inside:



This removes the previous render-blocking request chain for:

```txt
/css/base.css
/css/layout.css
/css/components.css
/css/post.css
/css/cards.css
/css/links.css
/css/search.css
/css/toc.css
/css/syntax.css
/css/accessibility.css
```

### CSS order

CSS module order matters:

```txt
base
layout
components
post
cards
links
search
toc
syntax
accessibility
```

`base.css` must come first because it defines theme variables and resets.
`accessibility.css` should come last because it contains focus-visible and
accessibility overrides.

If you add a new CSS module, register it in `css_modules` in
`src/build/pipeline.gleam`.

## Build

Run:

```sh
gleam run -m build/pipeline
```

The pipeline:

1. loads Markdown content from `content/`
2. parses TOML frontmatter
3. renders Markdown to HTML
4. writes `dist/content_index.json`
5. writes `dist/search_index.json`
6. writes feeds when RSS is enabled
7. writes `dist/sitemap.xml`
8. writes `dist/robots.txt`
9. writes `dist/llms.txt`
10. writes `dist/index.html`
11. writes `dist/404.html`
12. copies CSS modules to `dist/css/`
13. copies static assets to `dist/`
14. bundles the SPA to `dist/app.mjs` with Bun

## Output Directory

A typical `dist/` contains:

```txt
dist/
├── index.html
├── 404.html
├── app.mjs
├── content_index.json
├── search_index.json
├── atom.xml
├── rss.xml
├── sitemap.xml
├── robots.txt
├── llms.txt
├── css/
├── fonts/
├── icons/
└── images/
```

`atom.xml` and `rss.xml` are only emitted when RSS is enabled.

## Local Preview

Use a static server suitable for SPA routes.

Recommended with Nix:

```sh
nix run nixpkgs#http-server -- -p 8080 dist
```

Then open:

```txt
http://0.0.0.0:8080/
```

Avoid using Python's built-in static server for SPA deep-link refresh testing:

```sh
python -m http.server --directory dist
```

It does not provide SPA fallback for routes such as:

```txt
/posts/configuration
/about
/tags/gleam
```

and may return a server-level 404 before the SPA can start.
