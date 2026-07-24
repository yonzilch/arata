+++
title = "Configuration"
date = "2026-06-23"
updated = "2026-07-24"
description = "Comprehensive configuration guide for arata."
tags = ["guide", "config"]
+++

# Configuration

Arata is configured through a single user-owned file:

```txt
content/arata.toml
```

As of v1.7.0, `arata.toml` is the entry point for all site configuration.
Earlier versions of Arata required editing generated Gleam source directly to
change the header, navigation, feature toggles, or metadata. That is no
longer necessary — `arata.toml` is loaded once at build time, decoded,
merged with Arata's built-in defaults, resolved against the site's
deployment path, validated, and handed to both the static build pipeline and
the compiled SPA runtime as a single, consistent configuration.

`arata.toml` is committed alongside your content and **must not** contain
secrets, API keys, private tokens, or other sensitive values. The analytics
and comments provider settings stored in it are public, browser-visible
configuration — not credentials.

## Configuration Pipeline

Internally, resolving configuration is a five-step pipeline:

1. `content/arata.toml` is parsed with `tom` into a `RawConfig`.
2. `config/defaults` supplies built-in fallback values for anything left
   unset.
3. `config/url` derives the deployment `base_path` from `site.base_url` and
   resolves every root-relative path declared in the file — menu URLs,
   social URLs, `logo`, `favicon`, vendored asset URLs — against it.
4. The resolved values are validated.
5. The result is exposed to the rest of Arata as a trusted `Config` value
   (consumed by the SPA) and as `SiteMeta` (consumed by build-only concerns
   such as feeds, `robots.txt`, and `llms.txt`).

`src/config.gleam` still owns the public `Config`, `Social`, `MenuItem`, and
`Fonts` types, and still exposes `config.default()` and `config.site_meta()`
as backward-compatible accessors that return Arata's built-in defaults
without reading `arata.toml`. These remain useful for tests and for anyone
working on Arata itself. Production builds do not call them directly — they
load and resolve `content/arata.toml` once at the build entry point instead,
so build output and runtime configuration always originate from the same
resolved input. See [Advanced: the Gleam configuration
API](#advanced-the-gleam-configuration-api) below if you're extending Arata
rather than configuring a site.

The build pipeline:

```sh
gleam run -m build/pipeline
```

reads `content/arata.toml`, reads Markdown files from `content/`, parses TOML
frontmatter with `tom`, renders Markdown bodies with
<https://hex.pm/packages/mork>, writes `dist/content_index.json`, emits
crawler files and feeds, copies static assets, inlines CSS into the HTML
shell, and bundles the SPA into `dist/app.mjs`.

At runtime, the browser fetches `/content_index.json` once via `rsvp`. The
browser never reads Markdown files, never reads `arata.toml`, and never uses
filesystem APIs — by the time the SPA runs, your configuration has already
been fully resolved into static HTML/JSON/JS by the build.

## `content/arata.toml`

Root-relative paths declared anywhere in `arata.toml` — menu URLs, social
URLs, `logo`, `favicon`, vendored asset paths — are resolved against the
deployment path derived from `site.base_url`. There is no separate base-path
setting; `site.base_url` is the single source of truth for it. See
[Deployment base path](#deployment-base-path) below.

### `[site]`

```toml
[site]
base_url = "https://arata.yon.im"
title = "Arata"
description = "A modern and minimalistic blog theme"
logo = ""
favicon = "/images/arata-logo.avif"
fediverse_creator = ""
```

#### `base_url`

The canonical, public URL the site is deployed at. Used by:

* feeds
* the sitemap
* `robots.txt`
* `llms.txt`
* absolute canonical resource links
* deriving the runtime deployment base path for every root-relative path in
  this file

For a root-domain deployment:

```toml
base_url = "https://blog.example.com"
```

This derives a base path of `""`, and runtime assets resolve like:

```txt
/app.mjs
/content_index.json
/rss.xml
/icons/search.svg
```

For a subdirectory deployment:

```toml
base_url = "https://example.com/blog"
```

This derives a base path of `"/blog"`, and runtime assets resolve like:

```txt
/blog/app.mjs
/blog/content_index.json
/blog/rss.xml
/blog/icons/search.svg
```

For GitHub Pages project sites, use the repository path:

```toml
base_url = "https://yonzilch.github.io/arata"
```

This derives a base path of `"/arata"`, so root-absolute requests such as
`/app.mjs` or `/rss.xml` no longer incorrectly resolve from the domain root
instead of the repository subdirectory.

A trailing slash is allowed and removed during resolution, so these are
equivalent:

```toml
base_url = "https://example.com/blog"
```

```toml
base_url = "https://example.com/blog/"
```

#### `title` and `description`

Site-wide title and description.

* `title` is used by the header when no `logo` is configured, and for SEO
  and feed metadata.
* `description` is used for metadata, feeds, and content index
  configuration.

Because both the SPA runtime and the build pipeline read the same resolved
`arata.toml`, these values can never drift between the header rendered by
the SPA and the metadata written into feeds, the sitemap, or `llms.txt`.

#### `logo`

An optional root-relative path to an asset under `static/`.

```toml
logo = "/images/avatar.avif"
```

Leave it as an empty string to render the site title as a text link instead
of an image:

```toml
logo = ""
```

Use an absolute, root-relative path. Avoid relative paths like
`"images/avatar.avif"`, since deep-link refreshes may resolve them relative
to the current route rather than the site root.

#### `favicon`

An optional root-relative path used by the build pipeline when generating
`index.html` and `404.html`.

```toml
favicon = "/images/favicon.ico"
```

Leave it as an empty string to fall back to Arata's default favicon:

```toml
favicon = ""
```

As with `logo`, prefer absolute root paths — this avoids depending on the
depth of the page the favicon `<link>` is emitted into.

#### `fediverse_creator`

An optional Fediverse attribution string, for example:

```toml
fediverse_creator = "@username@example.social"
```

Leave it as an empty string to disable the metadata:

```toml
fediverse_creator = ""
```

### `[[menu]]`

Navigation items, rendered in the header in declared order.

```toml
[[menu]]
name = "about"
url = "/about"

[[menu]]
name = "links"
url = "/links"

[[menu]]
name = "posts"
url = "/posts"

[[menu]]
name = "projects"
url = "/projects"

[[menu]]
name = "tags"
url = "/tags"
```

Rules:

* `name` is the displayed label.
* Internal URLs must be root-relative, beginning with `/`. Arata adds the
  deployment base path derived from `site.base_url` automatically during
  configuration resolution — do **not** hardcode a subdirectory yourself
  (e.g. write `/posts`, never `/arata/posts`), even for project-site
  deployments.
* External URLs may use an absolute HTTP or HTTPS URL and are left
  untouched.
* Internal routes are handled by modem as SPA navigation.

Common internal routes:

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

### `[[socials]]`

Social links, rendered as icon links in the header in declared order.

```toml
[[socials]]
name = "Codeberg"
url = "https://codeberg.org/yonzilch/arata"
icon = "codeberg"

[[socials]]
name = "GitHub"
url = "https://github.com/yonzilch/arata"
icon = "github"
```

Fields:

* `name` — accessible label.
* `url` — link target. Internal targets are root-relative and receive the
  base path automatically, same as `[[menu]]`.
* `icon` — SVG filename without extension, under `static/icons/social/`. For
  example, `icon = "github"` resolves to `/icons/social/github.svg`.

The RSS social entry is managed automatically through `features.rss` and
must **not** be declared in `[[socials]]`. When `features.rss` is `true`,
Arata prepends a managed entry equivalent to:

```toml
name = "RSS"
url = "/rss.xml"
icon = "rss"
```

ahead of your declared `[[socials]]` list. When `features.rss` is `false`,
no RSS entry is added.

Replace the shipped Codeberg/GitHub entries entirely with your own socials
when customizing a site — they point at Arata's own repositories and are
only a working example.

### `[features]`

```toml
[features]
rss = "summary"
search = true
navbar_fixed = true
mathjax = true
mermaid = true
syntax_highlight = true
sidebar = true
floating_buttons = true
aratafetch = true
lightbox = true
latest_posts = false
```

Most keys are boolean toggles. `rss` accepts a feed content mode and remains backward-compatible with the previous boolean form.

#### `rss`

Supported modes:

```toml
rss = "full"
rss = "summary"
rss = "disabled"
```

- `"full"` generates Atom and RSS feeds containing each published post's summary and complete rendered HTML body.
- `"summary"` generates Atom and RSS feeds containing post summaries only. This is the default behavior.
- `"disabled"` disables Atom and RSS generation.

The previous boolean form remains supported:

```toml
rss = true   # Equivalent to "summary"
rss = false  # Equivalent to "disabled"
```

When feeds are enabled with `"full"` or `"summary"`:

- `dist/atom.xml` and `dist/rss.xml` are written.
- `dist/atom.xsl` and `dist/rss.xsl` are written for browser-friendly feed previews.
- feed `<link rel="alternate">` tags are emitted in the HTML shell.
- the managed RSS social icon is included (see `[[socials]]` above).

When feeds are `"disabled"`:

- Atom, RSS, and their XSL stylesheets are not generated.
- stale feed artifacts from earlier builds are removed from `dist/`.
- feed `<link rel="alternate">` tags are omitted.
- the managed RSS social entry is omitted.

Only non-draft posts with a non-empty publication date are included in Atom and RSS feeds. Posts without a publication date remain available on the site but are excluded from feeds.

In `"full"` mode:

- Atom stores rendered article HTML in `<content type="html">`.
- RSS stores rendered article HTML in `<content:encoded>`.
- post summaries remain available through Atom `<summary>` and RSS `<description>`.
- referenced remote or site assets are not downloaded or embedded into the feed.

`robots.txt`, `llms.txt`, and `sitemap.xml` are generated independently of the selected RSS mode.

#### `search`

When `true`:

* the search button is rendered.
* the search modal is mounted.
* Cmd/Ctrl+K opens search.
* `dist/search_index.json` is generated and used by the SPA.

When `false`, search UI is omitted and the global search shortcut is not
subscribed to.

#### `navbar_fixed`

Controls whether the site header (navbar) stays pinned to the top of the
viewport while scrolling.

When `true`:

* the `<nav>` element receives the `.navbar-fixed` class.
* the navbar uses `position: sticky` and stays visible at the top.

When `false`:

* the `<nav>` element receives the `.navbar-static` class.
* the navbar participates in normal document flow (`position: static`) and
  scrolls out of view with the content.

Set it to `false` if you prefer a more traditional scrolling layout or want
to maximize vertical reading space on long posts.

#### `mathjax`

When `true`, post pages trigger MathJax typesetting for inline and display
LaTeX, using the runtime asset configured at `assets.mathjax_url` (see
below). When `false`, MathJax effects are skipped entirely — use this if no
posts contain math.

Even when enabled, the JavaScript FFI only lazy-loads MathJax on posts whose
rendered content actually contains likely TeX delimiters, so posts without
math incur no extra runtime cost.

#### `mermaid`

When `true`, Arata renders native Markdown fenced code blocks written as:

````markdown
```mermaid
graph TD
  A --> B
```
````

and keeps compatibility with legacy Mermaid shortcode output, using the
runtime asset configured at `assets.mermaid_url`. When `false`, no Mermaid
runtime module is imported at all.

#### `syntax_highlight`

When `true`, syntax highlighting is applied to fenced code blocks at
runtime, using the runtime asset configured at `assets.syntax_highlight_url`.
When `false`, code blocks retain plain rendering, language labels, and copy
controls, without loading the highlighting runtime.

#### `sidebar`

When `true`, post pages render the right sidebar containing post tags and
the table of contents. When `false`, the sidebar is omitted and the post
body gets more space.

#### `floating_buttons`

Controls whether the floating buttons are rendered: the ToC/tags FAB
(floating action button) shown alongside the sidebar, and the scroll-to-top
button shown in the mobile sidebar overlay.

When `true` (the default), both are rendered and reachable. When `false`, no
FAB is shown and the overlay is not reachable through it.

#### `aratafetch`

`aratafetch` is an optional terminal-style homepage summary block. When
`true`, it is rendered at the bottom of the homepage content, after the
Markdown body from `content/pages/home.md`.

It gives visitors a compact CLI-style overview of the site, computed from
the already-loaded runtime content model:

* friend link count
* published post count (drafts excluded)
* total word count
* project count
* unique tag count (case-insensitive)
* site title
* base URL
* site description
* the optional `[aratafetch].maintained_for` string (see below)

Rows with unavailable or empty values are omitted: numeric rows are omitted
when `0`, text rows are omitted when empty, and `maintain` is omitted when
`[aratafetch].maintained_for` is empty.

Example output:

```txt
[root@arata:~]$ aratafetch

        /\
       /  \
      / /\ \
     / ____ \
    /_/    \_\

links        5
posts        10
words        17182
projects     4
tags         11
site_title   Arata
base_url     https://yonzilch.github.io/arata
description  Arata is a modern and minimalistic blog theme
maintain     since 2026-06-21
```

aratafetch does not currently display comment counts — external comment
systems such as Giscus or Utterances do not provide a reliable static local
count in Arata's current data model, so comment statistics are intentionally
omitted until a stable data source is added.

#### `lightbox`

Arata includes an optional built-in image lightbox for Markdown body images.
When enabled, clicking images inside rendered post/page Markdown opens a
fullscreen overlay managed entirely by the Lustre application model,
supporting:

* fullscreen image preview
* page-local image galleries
* previous/next navigation
* keyboard navigation (`Escape` closes, `ArrowLeft`/`ArrowRight` navigate)
* backdrop click to close
* body scroll locking while the overlay is open
* image captions derived from `alt` or `title`
* mobile/touch navigation controls

When `false`, Markdown images render normally: no lightbox overlay DOM is
emitted, no lightbox event listeners are subscribed, and no scroll locking
behavior is enabled.

The lightbox only observes images rendered inside Markdown content bodies
(`.body img`), which intentionally excludes header icons, social icons,
project cards, the theme toggle, search UI icons, and other non-content
decorative images.

Individual images or wrappers may opt out with `data-no-lightbox`:

```html
<img data-no-lightbox ...>
```

```html
<span data-no-lightbox>
  <img ...>
</span>
```

> The current gallery implementation prioritizes correctness and simplicity
> over aggressive image preloading optimizations. During rapid navigation
> between partially-loaded responsive images, some browsers may temporarily
> reuse the previously-decoded bitmap frame until the next image finishes
> decoding.

#### `latest_posts`

Arata can optionally render a compact latest-posts section on the homepage,
above aratafetch, using the already-loaded runtime content model — no
additional requests are performed. It's intended as a lightweight,
editorial-style homepage overview without turning the homepage into a full
archive page.

The section:

* appears below the homepage Markdown body and above aratafetch
* displays published posts only, using the existing runtime post ordering
* does not render when there are no posts

The number of posts shown is controlled by `[latest_posts].count` (see
below). Example layout:

```txt
2026-06-25 ● Configurable homepage latest-posts section
2026-06-24 ● Implement Lustre-managed gallery lightbox
2026-06-24 ● Introducing aratafetch homepage summary
2026-06-23 ● Guide for multi-platform project hosting
```

Only post titles are interactive links; dates and separators are rendered as
non-interactive metadata for cleaner accessibility semantics and reduced
hover noise.

### `[latest_posts]`

```toml
[latest_posts]
count = 5
```

The maximum number of published posts shown in the homepage latest-posts
section. Only takes effect when `features.latest_posts = true`. This value
must be zero or greater.

### `[aratafetch]`

```toml
[aratafetch]
maintained_for = "since 2026-06-21"
```

An optional display value for the `maintained` row in the aratafetch
summary. Only takes effect when `features.aratafetch = true`.

```toml
maintained_for = "since 2026-06-21"
```

```toml
maintained_for = "2 years"
```

Leave it empty to omit the row entirely:

```toml
maintained_for = ""
```

### `[fonts]`

CSS `font-family` declarations used by Arata's CSS custom properties.

```toml
[fonts]
text = "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif"
header = "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif"
code = "ui-monospace, \"Cascadia Code\", \"Source Code Pro\", Menlo, Consolas, \"DejaVu Sans Mono\", monospace"
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

#### Optional font packages

Two optional font packages are known to work well and can be installed and
referenced from `[fonts]`:

* [**Maple Font**](https://github.com/subframe7536/maple-font) — a
  programming font with ligatures. Set:

  ```toml
  code = "\"Maple Mono NF\", \"Maple Mono\", monospace"
  ```

* [**Sarasa Gothic**](https://github.com/be5invis/sarasa-gothic) — a
  CJK-friendly font. Set either:

  ```toml
  text = "\"Sarasa Gothic SC\", sans-serif"
  ```

  or, for a CJK-friendly monospace code font:

  ```toml
  code = "\"Sarasa Mono SC\", monospace"
  ```

These fonts must be installed/vendored separately; `[fonts]` only controls
which CSS `font-family` declarations are emitted.

### `[assets]`

Runtime asset URLs for optional browser enhancements.

```toml
[assets]
mathjax_url = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"
mermaid_url = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"
syntax_highlight_url = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/highlight.min.js"
```

A URL is required whenever its corresponding `[features]` toggle is enabled.
These values may point to pinned CDN resources or to root-relative vendored
assets under `static/` (resolved against the deployment base path like any
other site-local path).

* `mathjax_url` — used only when `features.mathjax = true`. Replace with
  another CDN or a vendored local asset if you need to avoid jsDelivr.
* `mermaid_url` — used only when `features.mermaid = true`. Must point to a
  browser-importable ESM bundle exposing Mermaid's `initialize` and `render`
  APIs, such as jsDelivr's `mermaid.esm.min.mjs`.
* `syntax_highlight_url` — used only when `features.syntax_highlight =
  true`. Should point to a pinned, browser-compatible Highlight.js bundle.

### `[analytics]`

```toml
[analytics]
provider = "disabled"
```

Supported providers: `disabled`, `goatcounter`, `umami`, `liwan`.
Provider-specific values belong in this same table. Google Analytics is
intentionally not supported.

```toml
[analytics]
provider = "goatcounter"
data_goatcounter = "https://yoursite.goatcounter.com/count"
src = "//gc.zgo.at/count.js"
```

```toml
[analytics]
provider = "umami"
website_id = "your-website-id"
src = "https://umami.example.com/script.js"
```

```toml
[analytics]
provider = "liwan"
data_entity = "your-entity"
src = "https://liwan.example.com/script.js"
```

### `[comments]`

```toml
[comments]
provider = "disabled"
```

Supported providers: `disabled`, `giscus`, `utterances`. Provider-specific
values belong in this same table.

```toml
[comments]
provider = "utterances"
repo = "user/repo"
```

```toml
[comments]
provider = "giscus"
repo = "user/repo"
repo_id = "..."
category = "..."
category_id = "..."
```

## Deployment base path

`site.base_url` is the single value that determines every deployment path in
the site — there is no separate base-path setting to configure.

Keep every other path in `arata.toml` as a logical root-relative path:

```toml
favicon = "/images/favicon.ico"

[[socials]]
name = "RSS"
url = "/rss.xml"
```

Do not pre-prefix them manually with a subdirectory, even for project-site
deployments:

```toml
favicon = "/blog/images/favicon.ico"  # avoid

[[socials]]
url = "/blog/rss.xml"  # avoid
```

Arata applies the derived base path at the output layer when generating
HTML, fetching `content_index.json`, resolving header icons/social links,
and producing SPA route hrefs — doing it yourself would double-prefix the
path under a subdirectory deployment.

## Advanced: the Gleam configuration API

This section is for people extending Arata itself, not for configuring a
site — use `content/arata.toml` for that.

The important modules are:

* **`src/config.gleam`** — the stable, public runtime API: the `Config`,
  `Social`, `MenuItem`, and `Fonts` types, plus backward-compatible
  `config.default()` and `config.site_meta()` accessors that return Arata's
  built-in defaults without reading `arata.toml`. Existing views, effects,
  routes, and build modules consume `Config` through this module.
* **`src/data/site.gleam`** — shared metadata types only: `SiteMeta`,
  `Analytics`, and `CommentsConfig`.
* **`config/defaults`** — the built-in fallback values used to fill in
  anything left unset in `RawConfig`.
* **`config/url`** — deployment path derivation and URL resolution:
  `canonical_base_url`, `base_path_from_url`, `normalize_base_path`,
  `with_base_path`, `resolve_site_url`, `is_external_or_special_url`,
  `is_http_url`, and `is_site_local_url`. `config.gleam` re-exports these as
  compatibility wrappers.
* **`config/resolve`** — loads `content/arata.toml`, decodes it into
  `RawConfig`, and produces the final resolved `Config`/`SiteMeta` pair
  consumed by the build pipeline and the SPA. Production build code should
  call this once at the build entry point and pass the result downstream,
  rather than calling `config.default()` or `config.site_meta()`
  independently in multiple pipeline stages.

`Social.icon` is always the filename without extension of an SVG under
`static/icons/social/` — for example, `icon: "github"` resolves to
`/icons/social/github.svg`, exactly as documented for `[[socials]]` above.

## Site Metadata

Build-only metadata not directly consumed by application views and effects
lives in `SiteMeta` (`src/data/site.gleam`), populated from the same
resolved `arata.toml` input as `Config`:

* `base_url`, `title`, `description`, `analytics`, `comments`,
  `fediverse_creator`, and `rss_enabled`.

Because `Config` and `SiteMeta` are both derived from one resolved
`arata.toml`, values like title, description, RSS behavior, and analytics
can no longer drift between the SPA runtime and the metadata used to
generate feeds, the sitemap, `robots.txt`, and `llms.txt` — there's exactly
one place to change them.

## Content Authoring

All content lives under `content/`.

```txt
content/
├── arata.toml
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
date = "2026-06-21"
description = "Introducing arata project"
tags = ["gleam", "lustre"]
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

Arata also supports Zola-style link fields:

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

Generated from the resolved `site.base_url`.

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

Accent colors are defined in `src/css/theme.css`.

Arata uses separate light and dark accent values so the accent stays readable
across both themes:

```css
:root {
  --primary-color: #2f4fa3;
}

:root.dark {
  --primary-color: #5f7eea;
}
```

Change these variables to recolor links, active nav states, tags, heading
prefixes, selection highlights, blockquote accents, card hover borders, and
other accent surfaces.

## CSS

Source CSS is split into modules under:

```txt
src/css/
```

Current modules:

```txt
fonts.css
theme.css
globals.css
typography.css
home.css
layout.css
components.css
pagination.css
post.css
cards.css
links.css
search.css
toc.css
syntax.css
lightbox.css
aratafetch.css
accessibility.css
```

The build pipeline still copies these files to:

```txt
dist/css/
```

for inspection and debugging.

However, for performance, the SPA shell no longer references each file with
render-blocking `<link rel="stylesheet">` tags. Instead, the build pipeline
inlines the CSS modules into `index.html` and `404.html` inside a `<style>`
block.

This removes the previous render-blocking request chain for:

```txt
/css/fonts.css
/css/theme.css
/css/globals.css
/css/typography.css
/css/home.css
/css/layout.css
/css/components.css
/css/pagination.css
/css/post.css
/css/cards.css
/css/links.css
/css/search.css
/css/toc.css
/css/syntax.css
/css/lightbox.css
/css/aratafetch.css
/css/accessibility.css
```

### CSS order

CSS module order matters:

```txt
fonts
theme
globals
typography
home
layout
components
pagination
post
cards
links
search
toc
syntax
lightbox
aratafetch
accessibility
```

`fonts.css` must come first because it declares bundled font faces.

`theme.css` must be loaded before every module that uses CSS variables.

`globals.css` sets document-level defaults and responsive root scaling.

`typography.css` defines global heading, link, selection, separator, time,
deletion, and MathJax overflow behavior.

`home.css` comes after `typography.css` so homepage latest-post styles can
override global link hover behavior.

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

1. loads and resolves `content/arata.toml`
2. loads Markdown content from `content/`
3. parses TOML frontmatter
4. renders Markdown to HTML
5. writes `dist/content_index.json`
6. writes `dist/search_index.json`
7. writes feeds when RSS is enabled
8. writes `dist/sitemap.xml`
9. writes `dist/robots.txt`
10. writes `dist/llms.txt`
11. writes `dist/index.html`
12. writes `dist/404.html`
13. copies CSS modules to `dist/css/`
14. copies static assets to `dist/`
15. bundles the SPA to `dist/app.mjs` with Bun

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

## Tips for Local Preview

Arata supports live local development with hot reload as well as production `dist/` preview.

### Development Server (Hot Reload)

Use the dev server when authoring content, tweaking templates, or editing `arata.toml`:

```sh
bun run dev

```

This serves the site at `http://localhost:3333` and:

* Performs an initial full-site build.
* Watches `src/`, `content/` (including `arata.toml`), `static/`, and `gleam.toml`.
* Rebuilds automatically on changes and triggers live-reload in your browser.
