+++
title = "Configuration"
date = "2026-06-23"
updated = "2022-06-23"
description = "Comprehensive configuration guide for arata."
tags = ["guide", "config"]
+++

# Configuration

arata is configured through two Gleam modules whose types mirror the
`[extra]` block of apollo's `config.toml`:

- **`src/config.gleam`** — the `Config` type: `title`, `description`,
  navigation `menu`, `socials`, `logo`, `fonts`, `rss_enabled`,
  `search_enabled`, `mathjax_enabled`, `sidebar_enabled`,
  `floating_buttons_enabled`, and `analytics`.
- **`src/data/site.gleam`** — the `SiteMeta` type: `base_url`, `title`,
  `description`, `analytics`, `comments`, `fediverse_creator`, and
  `rss_enabled`.

For now these are Gleam constants (`default/0` in each module). A future
phase will replace them with a `config.toml` loader, but the shape of the
types will not change — every field documented here will keep its name and
semantics.

The build pipeline (`gleam run -m build/pipeline`) reads the `.md` files
under `content/`, parses their TOML frontmatter with `tom`, renders the
Markdown bodies with [mork](https://hex.pm/packages/mork) (a pure-Gleam
CommonMark + GFM parser), and serializes everything to
`dist/content_index.json`. The SPA fetches that JSON at runtime via `rsvp`
— the browser never touches the file system.

## Site Configuration (`config.gleam`)

The `Config` type drives the header view, the nav menu, the socials row,
the font overrides injected into `:root`, and the search and RSS toggles.

```gleam
Config(
  title: "arata",
  description: "A blog built with Gleam and Lustre.",
  menu: [
    MenuItem(name: "posts", url: "/posts"),
    MenuItem(name: "projects", url: "/projects"),
    MenuItem(name: "links", url: "/links"),
    MenuItem(name: "tags", url: "/tags"),
    MenuItem(name: "about", url: "/about"),
  ],
  socials: default_socials(rss_enabled),
  logo: None,                       // or Some("/images/logo.png")
  rss_enabled: True,                // set False to skip feeds + hide RSS social
  fonts: Fonts(
    text: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, ...",
    header: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, ...",
    code: "\"SF Mono\", \"Fira Code\", \"JetBrains Mono\", Consolas, ...",
  ),
  search_enabled: True,             // set False to hide the search button + modal
  analytics: AnalyticsDisabled,
  mathjax_enabled: False,           // set True to load MathJax on post pages
  sidebar_enabled: True,            // set False to hide the right sidebar (ToC + Tags)
  floating_buttons_enabled: True,   // set False to hide the floating ToC/tags FAB
)
```

### `title` and `description`

Site-wide title and description. `title` appears in the header (unless a
`logo` is set) and is used as the site `<title>` fallback. `description` is
emitted as the `<meta name="description">` tag on the index page.

### `menu` — navigation menu items

A list of `MenuItem(name, url)` rendered in the header. The convention is:

- `name` is the lowercase label **without** a leading slash — e.g. `"posts"`,
  `"about"`. The header renders it as-is.
- `url` is the route **with** a leading slash — e.g. `"/posts"`, `"/about"`.

```gleam
MenuItem(name: "posts", url: "/posts"),
```

The default menu includes five entries — `posts`, `projects`, `links`,
`tags`, and `about` — matching arata's five top-level section routes. The
`posts`, `links`, and `projects` entries map to the four content
directories under `content/` (`pages/` is reachable via standalone `/{slug}`
routes such as `/about`, not via a dedicated nav entry).

### `socials` — social links

A list of `Social(name, url, icon)` rendered as icon links in the header,
to the right of the menu. Each field:

| Field  | Meaning |
|--------|---------|
| `name` | Accessible label / tooltip text — e.g. `"GitHub"`, `"RSS"`. |
| `url`  | Link target. Use `./atom.xml` (relative) for the RSS feed so it resolves correctly under subdirectory hosting; use absolute `https://…` URLs for external socials. |
| `icon` | Filename (without extension) of an SVG in `static/icons/social/`. `icon: "github"` resolves to `/icons/social/github.svg`. |

arata ships a set of Font-Academy-style social SVGs (GitHub, RSS, X,
Mastodon, etc.). Drop new SVGs into `static/icons/social/` and reference
them by filename.

> **Note on the RSS social:** the `default_socials/1` helper in
> `config.gleam` prepends the RSS link **only when** `rss_enabled` is `True`,
> so the RSS icon appears at the leftmost position of the socials row
> whenever feeds are enabled. Set `rss_enabled: False` to drop it. The
> default socials list is RSS (leftmost) + GitHub.

### `logo` — optional logo path

An `Option(String)` containing a path relative to `/` — for example
`Some("/images/logo.png")`. When `None`, the site title is rendered as a
text link in the nav; when `Some`, the logo image is rendered instead.

### `fonts` — custom font families

A `Fonts(text, header, code)` record whose fields are CSS `font-family`
declarations. They are injected as a `:root` CSS override (an inline
`<style>` rule) at boot, so the rest of `arata.css` resolves them through
the `--text-font`, `--header-font`, and `--code-font` custom properties
defined in `src/css/base.css`.

By default arata uses **system font stacks** so the site looks native on
every platform without shipping any web fonts:

```gleam
Fonts(
  text: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif",
  header: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif",
  code: "\"SF Mono\", \"Fira Code\", \"JetBrains Mono\", Consolas, \"Liberation Mono\", Menlo, monospace",
)
```

To use a web font, ship the font files in `static/fonts/`, add the
`@font-face` declarations to `src/css/base.css`, and reference them here.

### `rss_enabled` — enable/disable RSS feeds

A `Bool`. When `True` (the default):

- The build pipeline writes `dist/atom.xml` and `dist/rss.xml`.
- `<link rel="alternate">` feed tags are emitted in `index.html`.
- The RSS social link is added to the header (leftmost position).

When `False`, all three are suppressed — no feed files, no `<link>` tags,
and no RSS icon. This mirrors blogatto's opt-out feed model.

### `search_enabled` — enable/disable search

A `Bool`. When `True` (the default):

- The search button is rendered in the header.
- The search modal is mounted and the `Cmd/Ctrl+K` keyboard shortcut is
  subscribed to.
- A `search_index.json` is written to `dist/`.

When `False`, the search button, the modal, and the keyboard shortcut are
all omitted.

### `mathjax_enabled` — enable/disable MathJax rendering

A `Bool`. When `True`, the MathJax script is injected on post pages and
the SPA queues a `MathJax.typesetPromise()` call after each post renders,
so inline (`$…$`) and display (`$$…$$`) LaTeX typesets correctly. When
`False` (the default), MathJax is never loaded — useful when no post uses
LaTeX, since the script is ~280 KB and would otherwise be dead weight.

### `sidebar_enabled` — enable/disable the right sidebar

A `Bool`. When `True` (the default), post pages render the right sidebar
containing the table of contents (ToC) and the post's tag list. When
`False`, `view_tags_and_toc` is omitted so the post body takes the full
content width — useful for prose-heavy posts that don't need a ToC, or on
layouts where the sidebar would crowd the body.

### `floating_buttons_enabled` — enable/disable floating buttons

A `Bool`. When `True` (the default), the floating ToC/tags FAB is
rendered in the bottom-right corner (visible on all screen sizes), and
the floating overlay's scroll-to-top button is available. When `False`,
no FAB is rendered and the floating overlay is unreachable (there is no
entry point). Combine with `sidebar_enabled: True` if you want the ToC
available only via the right sidebar, never as a floating overlay.

### `analytics` — analytics provider

Configurable from the `Config` type (mirrors `SiteMeta.analytics`). One of:

| Provider    | Config                                                          | Behaviour |
|-------------|-----------------------------------------------------------------|-----------|
| GoatCounter | `GoatCounter(user: "your-user", host: "goatcounter.com")`       | Loads GoatCounter's `count.js` with `data-goatcounter`. |
| Umami       | `Umami(website_id: "xxx", host_url: "https://api.umami.dev/")`  | Loads Umami's script with `data-website-id`. |
| Disabled    | `AnalyticsDisabled`                                             | No analytics script injected. |

> **Note:** Google Analytics is intentionally **not** supported.

## Site Metadata (`data/site.gleam`)

The `SiteMeta` type is consumed by the head builder, the analytics FFI, and
the comments view. It overlaps with `Config` for `analytics` and
`rss_enabled` so both code paths can read them.

```gleam
SiteMeta(
  base_url: "https://arata.example.com",
  title: "arata",
  description: "A modern and minimalistic blog theme powered by Gleam and Lustre.",
  analytics: AnalyticsDisabled,
  comments: CommentsDisabled,
  fediverse_creator: None,
  rss_enabled: True,
)
```

### `base_url`, `title`, `description`

- `base_url` — the canonical origin of the deployed site. Used to build
  absolute URLs in the RSS feed, the sitemap, and `<link rel="canonical">`.
- `title` — site title used in SEO tags and the feed.
- `description` — site description emitted as `<meta name="description">`.

### `analytics`

Same `Analytics` type as in `Config` — `GoatCounter`, `Umami`, or
`AnalyticsDisabled`. Set it in whichever module your integration reads;
both paths honor it.

### `comments` — comment provider

A `CommentsConfig` controlling the per-page comments section. One of:

| Provider   | Config                                                                   | Behaviour |
|------------|--------------------------------------------------------------------------|-----------|
| Giscus     | `Giscus(repo: "user/repo", repo_id: "...", category: "...", category_id: "...")` | Loads the Giscus client. |
| Utterances | `Utterances(repo: "user/repo")`                                          | Loads the utteranc.es client. |
| Disabled   | `CommentsDisabled`                                                       | No comments section rendered. |

### `fediverse_creator` — optional Fediverse handle

An `Option(String)`. When `Some("@you@example.social")`, arata emits a
`<meta name="fediverse:creator" content="@you@example.social">` tag so
Mastodon and other ActivityPub clients can attribute link previews to you.
Leave it `None` to omit the tag.

### `rss_enabled`

A `Bool`. The build pipeline reads this field on `SiteMeta` (because the
pipeline operates on `SiteMeta`, not on `Config`). Keep it in sync with
`Config.rss_enabled` — when `False`, no `atom.xml` / `rss.xml` are written
and no feed `<link>` tags are emitted.

## Content Authoring

All content lives under `content/` in four subdirectories. Each Markdown
file uses **TOML frontmatter** delimited by `+++ … +++`. The body is
rendered to HTML by mork at build time and stored pre-rendered in
`content_index.json` — no Markdown parsing happens in the browser.

```
+++
title = "My Post"
date = "2026-02-01"
description = "A short summary."
tags = ["gleam", "lustre"]
+++

Body in Markdown…
```

### Posts — `content/posts/*.md`

Blog posts. Supported frontmatter:

```toml
+++
title = "Hello, arata"
date = "2026-01-15"
updated = "2026-01-18"          # optional
description = "Introducing arata."
tags = ["gleam", "lustre"]
draft = false                    # optional, default false
tldr = "One-line summary."       # optional, shown above the body
+++
```

Posts appear on the `/posts` list page (with the date on the left and the
title on the right), in the RSS feed, in the search index, and in the
sitemap. Heading IDs are post-processed at load time so the table of
contents' `#id` anchors resolve to mork's `<h1>`–`<h6>` output.

### Pages — `content/pages/*.md`

Standalone pages such as `/about` and `/home`. Minimal frontmatter:

```toml
+++
title = "About"
subtitle = "Optional one-liner under the title"   # optional
+++
```

Pages are reachable from the nav menu but are not listed on `/posts` and are
not included in the RSS feed. `content/pages/home.md` is special-cased: it
backs the `/` homepage.

### Links — `content/links/*.md`

External link cards shown on the `/links` page. Frontmatter:

```toml
+++
title = "Gleam"
url = "https://gleam.run"
description = "A typed, functional language that compiles to JS and Erlang."
image = "https://gleam.run/favicon.ico"   # optional avatar
+++
```

Links have no Markdown body — just frontmatter. The list is sorted
alphabetically by title for a stable display order.

### Projects — `content/projects/*.md`

Project showcase cards shown on the `/projects` page. Frontmatter:

```toml
+++
title = "arata"
description = "A faithful reimplementation of the apollo blog theme in Gleam and Lustre."
link_to = "https://github.com/yonzilch/arata"      # "Visit" link (optional)
github = "https://github.com/yonzilch/arata"       # GitHub icon link (optional)
demo = "https://arata.example.com"                  # "Demo" link (optional)
image = "/images/projects/arata.png"                # card thumbnail (optional)
tags = ["gleam", "lustre", "blog"]                  # optional
+++
```

Projects have no Markdown body — just frontmatter. The list is sorted
alphabetically by slug.

### Frontmatter format

arata uses **TOML** frontmatter exclusively, delimited by `+++` on its own
line at the very top of the file:

```
+++
key = "value"
array = ["a", "b"]
boolean = true
date = "2026-01-15"
+++
```

YAML (`---`) and JSON (`;;;`) delimiters are not supported.

## Theme

### Light / Dark / Auto toggle

The theme toggle cycles **Light → Dark → Auto → Light** (apollo's
`toggle-auto` mode). The choice is persisted to
`localStorage["theme-storage"]`. When `Auto` is selected, arata respects
the system preference via `prefers-color-scheme` and updates live when the
OS theme changes.

### Custom accent color

The accent color is a single CSS custom property defined in
`src/css/base.css`:

```css
:root {
  --primary-color: #3555b3;
}
```

`#3555b3` is a dark blue. Change the hex value to recolor every accent
surface — links, the active nav item, the search button, tag pills,
heading `::before` prefixes, and `::selection` highlights all resolve
through `var(--primary-color)`. The dark theme (defined on `:root.dark` in
the same file) keeps the same hue, so a single edit covers both modes.

## CSS Modules

The stylesheet is split into **10 modular files** under `src/css/`. The
build pipeline concatenates them in dependency order (base first) into a
single `dist/arata.css`. Each module owns a clearly-scoped slice of the
design system:

| File                  | Covers |
|-----------------------|--------|
| `src/css/base.css`    | `@font-face` declarations, light/dark theme variables on `:root` / `:root.dark`, `html`/`body` resets, responsive font-size scaling, `h1`–`h6` + `::before` prefixes, links, `::selection`, `<hr>`, `<time>`, `<del>`, MathJax containers. |
| `src/css/layout.css`  | `.arata-shell`, `.content`, `.left-content`, `.right-content`, `nav`, `.left-nav`, `.right-nav`, `.logo` — the 3-column layout. |
| `src/css/components.css` | `.page-header`, `.not-found-header`, `.meta`, `.post-list`, `.list-item`, `.post-header`, `.pagination`, `.icon-button`, `.tags`, `.tag-list`, `.tag`, `.authors`, `.post-tags`. |
| `src/css/post.css`    | `.draft-label`, `blockquote`, `.tldr`, `img` / `figure`, `table`, `.mermaid`, `.note-*` (note shortcode), `.character-*` (character shortcode), `.code-label`, `.label-<lang>` (25 languages + `.label-default`), `pre`, `code`, `.clipboard-button`. |
| `src/css/cards.css`   | `.cards`, `.card`, `.card-media`, `.card-image`, `.card-video`, `.card-content`, `.card-title`, `.card-tagline`, `.card-footer`, `.card-links`, `.card-tags`, `.card-tag`, plus the talks grid (`.talks-grid`, `.talk-card`, ...). |
| `src/css/links.css`   | `.link-avatar` — the avatar image shown beside a friend link's title/description. |
| `src/css/search.css`  | `.search-button`, `.search-modal`, `.search-backdrop`, `#modal-content`, `#searchBar`, `#searchInput`, `.clear-button`, `#results`, `#results-container`, `#results-info`. |
| `src/css/toc.css`     | `.toc`, `.toc a`, `.toc li`, `.toc ul`, `.heading`, `.selected`, `.parent` — the table of contents sidebar. |
| `src/css/syntax.css`  | giallo light + dark syntax highlighting (all `.z-*` and `.giallo-*` rules). Light rules are the default; dark rules are scoped under `:root.dark` so syntax colors switch with the theme. |
| `src/css/accessibility.css` | `:focus-visible` outlines for keyboard navigation across all interactive elements, plus the `.skip-link` for screen-reader users. |

To add new styles, either extend the relevant module or append a new one.
If you add a new module, register it in the `css_modules` list in
`src/build/pipeline.gleam` so the build concatenates it.

## Build

### Build command

From the project root:

```bash
gleam run -m build/pipeline
```

This runs the full build pipeline (`src/build/pipeline.gleam`):

1. **Load content** — `content/loader.gleam` reads every `.md` file under
   `content/`, parses the TOML frontmatter with `tom`, and renders the
   Markdown body to HTML with `mork` (`data/markdown.gleam`). Posts are
   sorted by date descending; projects and links are sorted alphabetically.
2. **Content index JSON** — serializes the typed content tree (posts,
   pages, links, projects, homepage) to `dist/content_index.json`. The SPA
   fetches this file at runtime via `rsvp`.
3. **Search index JSON** — `dist/search_index.json` (always written; only
   consumed when `search_enabled` is `True`).
4. **Feeds** — `dist/atom.xml` and `dist/rss.xml`, only when
   `SiteMeta.rss_enabled` is `True`.
5. **Sitemap** — `dist/sitemap.xml`.
6. **HTML shells** — `dist/index.html` (with FOUC-prevention theme classes
   and conditional feed `<link>` tags) and `dist/404.html` (a redirect
   shim for SPA deep-linking on static hosts).
7. **CSS** — concatenates the 10 CSS modules under `src/css/` (in
   dependency order) into a single `dist/arata.css`.
8. **Static assets** — copies `static/` (fonts, icons, images, vendored
   CSS) into `dist/`.
9. **SPA bundle** — writes a small entry shim and runs
   `bun build --outfile dist/app.mjs --minify --target=browser` to produce
   the bundled SPA. This replaces `lustre/dev build` (which requires
   Erlang/OTP) — `bun` is the only runtime requirement.

### Output directory structure

The build writes to `dist/`:

```
dist/
├── index.html              # SPA shell with <link> tags for feeds
├── 404.html                # not-found redirect shim
├── app.mjs                 # bundled Lustre SPA
├── arata.css               # concatenated stylesheet (10 CSS modules)
├── content_index.json      # content manifest fetched by the SPA
├── search_index.json       # search corpus
├── atom.xml                # Atom feed (when rss_enabled = True)
├── rss.xml                 # RSS 2.0 feed (when rss_enabled = True)
├── sitemap.xml             # sitemap
├── css/                    # vendored theme stylesheets (giallo-light, giallo-dark)
├── fonts/                  # font files
├── icons/                  # social + UI icons
└── images/                 # static images
```

Serve `dist/` with any static file server (e.g. `python -m http.server
--directory dist`) and open the URL in a browser. For static hosts that
serve `404.html` for unknown paths (GitHub Pages, Cloudflare Pages,
Netlify), the included `404.html` redirects back into the SPA so
client-side routing handles deep links.
