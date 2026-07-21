+++
title = "ROADMAP"
date = "2026-06-21"
updated = "2026-06-24"
description = "Comprehensive ROADMAP of arata project"
tags = ["docs"]
+++

# Arata — ROADMAP

> A faithful reimplementation of the [apollo](https://github.com/not-matthias/apollo)
> blog theme, built with [Gleam](https://gleam.run) and the
> [Lustre](https://hexdocs.pm/lustre) framework.

This document is the canonical, step-by-step plan for turning the scaffold into a
complete reproduction of apollo. It is organised as a phased roadmap: each phase
has a goal, the apollo source it mirrors, the files it touches, concrete steps,
and acceptance criteria. Phases are ordered so that each one produces a
runnable, reviewable increment.

---

## Table of contents

1. [Project goals & scope](#1-project-goals--scope)
2. [Current status (scaffold)](#2-current-status-scaffold)
3. [Architecture](#3-architecture)
4. [The apollo → arata feature map](#4-the-apollo--arata-feature-map)
5. [Design system specification](#5-design-system-specification)
6. [Content model & configuration](#6-content-model--configuration)
7. [Phased implementation plan](#7-phased-implementation-plan)
8. [Post-v0.1.0 Improvements](#8-post-v010-improvements)
9. [Risks & key decisions](#9-risks--key-decisions)
10. [Version pins & dependencies](#10-version-pins--dependencies)
11. [Definition of done](#11-definition-of-done)
12. [References](#12-references)
13. [Follow-up Notes](#13-follow-up-notes)

---

## 1. Project goals & scope

### 1.1 Goal
Reproduce apollo's **visual design, content model, and feature set** as a
Gleam/Lustre single-page application (SPA), so that an apollo-authored blog
renders — pixel-for-pixel at the same breakpoints, with the same interactions —
inside arata.

### 1.2 In scope
- All apollo page templates: homepage, section (post list), single post/page,
  cards (projects), talks, taxonomy list, taxonomy single, 404.
- The full apollo feature set (theme switching, syntax highlighting, TOC,
  search, shortcodes, MathJax, Mermaid, comments, analytics, SEO, feeds,
  sitemap, etc. — see §4).
- A build pipeline that replaces Zola: markdown → HTML, frontmatter parsing,
  syntax highlighting, image resizing, search-index emission, feed/sitemap
  emission, minification.

### 1.3 Out of scope
- apollo's Playwright visual-regression test suite, Lighthouse CI, Nix/Docker
  scaffolding (these are test/infra, not the theme).
- `lustre/ui` (unreleased at time of writing).
- Server components / WebSocket streaming (arata is a client SPA; SSR/SSG is a
  late, optional phase).

### 1.4 Fidelity target
At the end of Phase 17, the same `content/` tree rendered through apollo (Zola)
and through arata (Lustre SPA) should be visually indistinguishable at every
breakpoint in §5.5, and every interaction in §4 should behave identically.

---

## 2. Current status (scaffold)

The scaffold (Phase 0) is **complete**. The project builds with `gleam build`
(only intentional `todo` warnings from stub modules remain).

```
arata/
├── gleam.toml            # project + [tools.lustre.html] config (deps pinned)
├── README.md             # project overview + dev commands
├── .gitignore            # /build, /dist, node_modules, gleam artefacts
├── src/
│   ├── arata.gleam       # entry: boots a minimal lustre.simple app (placeholder)
│   ├── arata.css         # CSS entry (empty; Phase 1 ports the design system here)
│   ├── route.gleam       # Route type + parse_route/href stubs
│   ├── data/post.gleam   # Post type stub
│   ├── view/             # layout, header, footer, post_list, post, page (stubs)
│   └── effect/theme.gleam # Theme type + init_theme stub
├── static/{css,fonts,icons}/  # empty (Phase 1 fills these)
└── test/                 # default gleeunit
```

### Build & run
```sh
gleam build                    # type-check + compile to JavaScript (works today)
gleam run -m lustre/dev start  # dev server on http://localhost:1234 (needs Erlang)
gleam test                     # run the test suite
gleam run -m lustre/dev build --minify --outdir=dist  # production bundle
```

> **Note:** running `lustre/dev` requires Erlang/OTP installed (the dev tool is
> an escript). `gleam build` itself does not require Erlang. Phase 0 verification
> used `gleam build` only.

---

## 3. Architecture

### 3.1 The Elm Architecture (Lustre)
arata follows Lustre's Model-View-Update with managed effects:

- `init(flags) -> #(Model, Effect(Msg))` — build the initial model and kick off
  startup effects (read theme, load content index, initialise the router).
- `update(model, msg) -> #(Model, Effect(Msg))` — pure transition; side effects
  are returned as `Effect(Msg)` values, never performed inline.
- `view(model) -> Element(Msg)` — pure virtual-DOM render.
- Routing is handled by [`modem`](https://hexdocs.pm/modem): `modem.init` in
  `init` intercepts `<a>` clicks and dispatches `UserNavigatedTo(Route)`.

### 3.2 Target module layout (end state)
The scaffold already seeds this; phases expand each module.

```
src/
├── arata.gleam               # main(): start_app, top-level init/update/view
├── arata.css                 # design system (Phase 1)
├── route.gleam               # Route, parse_route, href
├── models.gleam              # Model, Msg, Config, Page, Section, Theme, ...
├── config.gleam              # site config loader (from content_index.json)
├── data/
│   ├── post.gleam            # Post type + decoder
│   ├── project.gleam         # Project (card) type + decoder
│   ├── talk.gleam            # Talk type + decoder
│   └── content.gleam         # ContentTree: all posts/projects/talks/tags/pages
├── view/
│   ├── layout.gleam          # shell: header + main + footer
│   ├── header.gleam          # nav: logo/title, menu, socials, search, toggle
│   ├── footer.gleam          # socials, copyright
│   ├── toc.gleam             # table of contents + active-highlight
│   ├── post_list.gleam       # list_post / list_posts / page_header
│   ├── post.gleam            # single post article
│   ├── card.gleam            # project card
│   ├── talk_card.gleam       # talk card
│   ├── icon_button.gleam     # reusable icon-button (macros/components.html)
│   ├── search_modal.gleam    # Cmd/Ctrl+K search modal
│   └── page.gleam            # standalone page + 404
├── pages/
│   ├── home.gleam            # homepage.html
│   ├── section.gleam         # section.html
│   ├── cards.gleam           # cards.html
│   ├── talks.gleam           # talks.html
│   ├── taxonomy_list.gleam   # /tags/
│   ├── taxonomy_single.gleam # /tags/<tag>/
│   └── not_found.gleam       # 404.html
├── shortcodes/
│   ├── character.gleam       # character.html
│   ├── note.gleam            # note.html
│   ├── mermaid.gleam         # mermaid.html
│   └── image.gleam           # image.html
├── effect/
│   ├── theme.gleam           # localStorage + matchMedia
│   ├── search.gleam          # fetch + query elasticlunr index
│   ├── clipboard.gleam       # navigator.clipboard.writeText
│   ├── toc.gleam             # IntersectionObserver
│   └── script.gleam          # post-render MathJax/Mermaid/Giscus invocation
├── ffi/
│   ├── theme.ffi.mjs         # localStorage / matchMedia FFI
│   ├── search.ffi.mjs        # elasticlunr core bridge
│   ├── clipboard.ffi.mjs     # clipboard FFI
│   └── observer.ffi.mjs      # IntersectionObserver FFI
└── build/                    # the Zola-replacement build step (Phase 17)
    ├── pipeline.gleam        # orchestrates the content → dist pipeline
    ├── frontmatter.gleam     # TOML frontmatter parser
    ├── markdown.gleam        # markdown → HTML + shortcode pre-processor
    ├── highlight.gleam       # syntax highlighting (giallo class names)
    ├── image.gleam           # resize_image equivalent (libvips/imagemagick)
    ├── search_index.gleam    # elasticlunr index emitter
    ├── feeds.gleam           # atom.xml / rss.xml / sitemap.xml
    └── minify.gleam          # HTML/CSS/JS minification
```

### 3.3 Routing table
apollo is multi-page (one HTML file per URL). arata is an SPA with a
History-API router (modem). Routes:

| Route | apollo template | Notes |
|---|---|---|
| `/` | `homepage.html` | Custom homepage (no post list). |
| `/posts` | `section.html` | Paginated post list (`paginate_by` from section frontmatter). |
| `/posts/<slug>` | `page.html` | Single post. |
| `/projects` | `cards.html` | Project card grid (column-balanced). |
| `/projects/<slug>` | `page.html` or external | Single project. |
| `/talks` | `talks.html` | Talk card grid. |
| `/talks/<slug>` | `page.html` or external | Single talk. |
| `/tags` | `taxonomy_list.html` | Tag index. |
| `/tags/<tag>` | `taxonomy_single.html` | Posts with tag. |
| `/<page>` | `page.html` | Standalone page (e.g. `/about`). |
| `*` | `404.html` | |

### 3.4 Data flow
```
content/*.md  --(Phase 17 build pipeline)--> content_index.json + search_index.json
                                                       |
                          index.html (Phase 17) <-- lustre/dev build
                                  |
              browser loads SPA -> init() fetches content_index.json (rsvp)
                                  |
                          Model holds ContentTree + Route + Theme + Search + Toc
                                  |
                          view(model) renders the current page
```

---

## 4. The apollo → arata feature map

Every apollo feature (50 enumerated in the research notes) maps to an arata
implementation. "Phase" refers to §7.

| apollo feature | arata implementation | Phase |
|---|---|---|
| Theme switching (5 modes: light/dark/auto/toggle/toggle-auto) | `Theme` + `ThemeMode` model; `effect/theme.gleam` (localStorage + matchMedia); `Msg = UserToggledTheme \| SystemPrefersDarkChanged(Bool) \| ThemeSaved(Theme) \| ApplyTheme` | 10 |
| FOUC prevention (`<html class="dark light">` + always-load light CSS) | Emitted in the SSR `index.html` (Phase 17); SPA hydrates onto matching DOM | 10, 17 |
| Syntax highlighting (syntect class-based + `giallo-{light,dark}.css`) | Build-time highlighting emitting `giallo` class names; `giallo-*.css` copied verbatim | 11, 17 |
| Fancy code blocks (copy button + language label) | `view_code_block`; `Msg = UserCopiedCode(String)`; `effect/clipboard.gleam`; `$language-colors` → Gleam `dict` | 11 |
| Copy code button (strips line-number spans) | `effect/clipboard.gleam` + 2s icon swap | 11 |
| Table of contents (3-level, IntersectionObserver highlight) | `view/toc.gleam` + `effect/toc.gleam`; `Msg = TocActiveHeadingChanged(String)` | 6 |
| Pagination (Prev/Next only) | `Paginator` model field; `<a href>` links via `route.href` | 5 |
| Search (elasticlunr, Cmd/Ctrl+K modal, lazy index load) | `view/search_modal.gleam` + `effect/search.gleam`; keep elasticlunr core, rewrite the 635-line modal controller in Lustre | 12 |
| RSS / Atom feeds | `build/feeds.gleam` emits `atom.xml`/`rss.xml`; `<link rel="alternate">` in head | 17 |
| Taxonomies (tags) | `pages/taxonomy_{list,single}.gleam`; sort by name or page_count | 8 |
| Authors taxonomy (optional) | Same pattern as tags, `@`-prefixed links | 8 |
| Social links (44 icons) | `view/header.gleam` + `view/footer.gleam`; `static/icons/social/*` copied verbatim | 3 |
| Navbar menu (`/posts` style) | `view/header.gleam`; `config.menu` | 3 |
| Logo | `view/header.gleam`; `config.logo` | 3 |
| Analytics (GoatCounter/Umami/Google) | Head `<script>`s in `index.html`; vendored `count.js`/`imamu.js` kept as-is | 15 |
| MathJax (global + per-page) | Head script in `index.html` + `effect/script.gleam` calls `MathJax.typesetPromise()` after view patch | 14 |
| Mermaid diagrams | `<pre class="mermaid">` + `effect/script.gleam` calls `mermaid.run()` after view patch; vendored `mermaid.js` kept | 14 |
| Notes (static & dynamic) | `shortcodes/note.gleam`; `open_notes: Set(String)`; `Msg = UserToggledNote(String)` | 13 |
| Character shortcode | `shortcodes/character.gleam` (avatar + speech bubble, left/right flip) | 13 |
| Image shortcode (avif/webp resize, aspect-ratio) | `shortcodes/image.gleam` + `build/image.gleam` (libvips/imagemagick) | 13, 17 |
| Custom homepage | `pages/home.gleam` | 9 |
| Cards page (projects, column-balanced) | `pages/cards.gleam` + `view/card.gleam`; pure `reorder_for_columns(items, cols)` | 7 |
| Talks page (row→column flip) | `pages/talks.gleam` + `view/talk_card.gleam` | 7 |
| Comments (giscus/utterances) | `view/post.gleam` emits `<div class="giscus">` + script; `effect/script.gleam` re-injects on route change | 15 |
| SEO meta tags (title/og:description, dedup, `extra.meta`) | `view_head`/`index.html` head builder; pure dedup logic | 15 |
| Fediverse attribution | One conditional `<meta>` in head | 15 |
| Favicon | `<link rel="icon">` in head | 3 |
| Word count / reading time | Computed at build time; shown in meta row per config | 6, 17 |
| Source-code link on posts | `view/post.gleam`; `repo_url <> relative_path` | 6 |
| tl;dr box | `view/post.gleam` | 6 |
| Draft label | `view/post.gleam` + `view/post_list.gleam` | 6 |
| Anchor links in headings | Build-time heading-id generator; `.zola-anchor` class | 6, 17 |
| Custom stylesheets | `config.stylesheets` → `<link>`s in head | 15 |
| Custom HTML injection (4 points) | `head_start/head_end/body_start/body_end` raw-HTML strings via `element.unsafe_raw_html` | 15 |
| Open Graph | Auto-emitted in head builder | 15 |
| External-link indicator (`↗`, "Read original ⟶") | `view/post_list.gleam` + `view/card.gleam` | 5, 7 |
| Theme persistence (`localStorage["theme-storage"]`) | `effect/theme.gleam` | 10 |
| System-pref change (auto mode) | `matchMedia` subscription → `SystemPrefersDarkChanged` | 10 |
| Build minification | `build/minify.gleam` (esbuild/lightningcss or shell-out) | 17 |
| SCSS compilation | **Hand-ported** to plain CSS (no SCSS toolchain) | 1 |
| Sitemap | `build/feeds.gleam` emits `sitemap.xml` | 17 |
| Image format defaults (avif/webp, quality) | `build/image.gleam` | 17 |
| Lazy loading images | `<img loading="lazy" decoding="async">` in shortcodes | 13 |

---

## 5. Design system specification

This is the port target for Phase 1. Source: `apollo/sass/`.

### 5.1 Color palette
CSS custom properties on `:root.light` and `:root.dark`.

| Variable | Light | Dark |
|---|---|---|
| `--bg-0` (page bg) | `#ffffff` | `#121212` |
| `--bg-1` (code/card/bubble bg) | `#fafafa` | `#1c1c1c` |
| `--bg-2` (borders/hover/note header) | `#f0f0f0` | `#262626` |
| `--text-0` (primary text) | `#151515` | `#f0f0f0` |
| `--text-1` (muted: dates, captions) | `#666666` | `#999999` |
| `--text-2` (very muted: TOC) | `#b3b3b3` | `#737373` |
| `--border-color` | `var(--bg-2)` | `var(--bg-2)` |
| `--primary-color` (the only accent) | `#ef5350` | `#ef5350` |
| `--hover-color` (text on primary bg) | `white` | `white` |
| `--icon-filter` | `none` | `invert(1)` |

Other constants: blockquote text `#737373`; table borders `#dfe2e5`; selection
bg `--primary-color` / fg `--hover-color`. Code-language label colors come from
the `$language-colors` SCSS map (26 languages, e.g. rust `#ff4647`, python
`#3572a5`, go `#00add8`, typescript `#3178c6`, js `#f7df1e`, bash `#4eaa25`,
default `#333`); label text color `--label-color: #f0f0f0`.

### 5.2 Fonts
| Variable | Family | Source |
|---|---|---|
| `--text-font` | `"ZedTextFtl"` | `static/fonts/zed-fonts/ZedTextL-{Regular,Bold}.woff2` |
| `--header-font` | `"ZedDisplayFtl" "Space Grotesk", "Helvetica", sans-serif` | `ZedDisplayL-Heavy.woff2` + `SpaceGrotesk-*.ttf` |
| `--mono-text-font` / `--code-font` | `"Jetbrains Mono"` | `static/fonts/JetbrainsMono/JetBrainsMono-*.ttf` |

> Replicate the `use_cdn = true` quirk: when CDN mode is on, Zed fonts are
> dropped (not on a CDN) and Space Grotesk becomes the fallback for everything.

### 5.3 Typography scale
- `--font-size-base: 16px` on `:root`; `--line-height: 1.5`.
- `html` font-size scales at breakpoints: `992px→0.97×`, `768px→0.95×`,
  `576px→0.92×`.
- `.page-header`: `2.5em`, `line-height:100%`, `--header-font`,
  `margin: 4rem 0 1rem 0`.
- `.not-found-header` (404): `3em`, absolute-centered.
- In-article `h1–h6`: `1.2rem`, `--header-font`, `margin-top: 2em`, each with
  `::before { content: "# "/"## "/…; color: var(--primary-color) }`.
- `.post-header h1` (post-list): `font-weight: normal`, `--header-font`,
  `margin: 0`.
- `.left-nav` (site title): `1.5rem`. `.note-toggle`/`.note-header`: `1.2em`.
- `.card-tag`: `0.7rem`. `.icon-button`: `0.75rem`. `time`: `--mono-text-font`.
- `.modal h1` (search): `1.2rem`.

### 5.4 Layout
- `--page-width: 920px` (max width of `.content`).
- `body`: `display:flex`, `padding: 0.9rem 0.9rem 1.5rem`,
  `min-height: calc(100vh - 150px)`. ≥992px: `flex-direction:row;
  justify-content:center; align-items:flex-start`.
- Three columns ≥992px: `.left-content` (spacer, `flex:1 1 0`), `.content`
  (`max-width: var(--page-width); flex-shrink:0`), `.right-content` (sticky TOC,
  `position:sticky; top:60px; max-height:calc(100vh - 100px); overflow-y:auto`).
- `nav`: `flex-wrap:wrap; justify-content:space-between` (column ≤600px).
- `.cards`: `column-count:2` default (overridable via `--columns` CSS var),
  `column-gap:20px` (1 col ≤640px).
- `.talks-grid`: CSS Grid, `gap:24px`; 1 col default, 2 cols at 640–1023px, row
  layout ≥1024px (`.talk-card` becomes `flex-direction:row`).
- `.post-list .post-header`: 2-col grid ≥640px (`auto 1fr`), 2-row below.

### 5.5 Responsive breakpoints
| Breakpoint | Effect |
|---|---|
| `max-width: 1365px` | `.toc` hidden |
| `max-width: 1023.98px` | talks cards stack vertically |
| `min-width: 1024px` | talks cards become horizontal |
| `min-width: 992px` | body becomes 3-column flex |
| `max-width: 992px` | font-size 0.97× |
| `max-width: 768px` | font-size 0.95× |
| `max-width: 720px` | cards padding 16px, card-media height 160px |
| `max-width: 640px` | post-list stacks; cards → 1 column |
| `max-width: 600px` | nav wraps vertically; search modal 92% width |
| `max-width: 576px` | font-size 0.92× |

### 5.6 Animations / hover (deliberately minimal)
- `a:hover` → `background: var(--primary-color); color: var(--hover-color)`
  (same for `a:hover > code`).
- `main a` → `border-bottom: 2px solid var(--primary-color)` (disabled in
  `.meta`, `.talks-grid`, `.cards`, `.zola-anchor`).
- `.icon-button:hover` → `background: var(--bg-1)`.
- `.note-toggle::before` `▼` (no rotation; just show/hide content).
- `.character-avatar` in `.character-right` → `transform: scaleX(-1)`.
- `.talk-image` → `filter: brightness(75%) grayscale(50%)`.
- `::selection` → `--primary-color`/`--hover-color`.
- Only one explicit `transition`: `.note-toggle { transition: background-color 0.3s ease }`.
  `.toc { transition: none }`. **No keyframes, no fade/slide-in.**

### 5.7 Icons
- Theme toggle / search / calendar / presentation / code / map-pin: Feather
  24×24 line icons (`stroke=currentColor stroke-width=2`).
- Social icons (44 SVGs in `static/icons/social/`): Font Awesome Pro 6.2.0 solid
  (`fill=currentColor`). Copy verbatim.

---

## 6. Content model & configuration

### 6.1 Frontmatter (TOML `+++ … +++`)
**Built-in fields:** `title` (required), `date`, `updated`, `description`,
`weight`, `path`, `template`, `sort_by`, `paginate_by`, `insert_anchor_links`,
`draft`, `taxonomies.tags`, `taxonomies.authors`, `summary` (auto from
`<!-- more -->`).

**apollo `[extra]` fields:** `mathjax`, `comment`, `tldr`, `read_time`,
`repo_view`, `repo_url`, `meta` (array of `{key,value}`), `link_to`,
`local_image`, `remote_image`, `local_video`, `remote_video`, `github`, `demo`,
`tags` (card chips, distinct from taxonomy tags), `video{link,thumbnail}`,
`organizer{name,link}`, `slides`, `code`, `cards_columns`, `card_media_height`,
`section_path`.

### 6.2 Site config (`config.toml` `[extra]`)
| Key | Type | Default | Effect |
|---|---|---|---|
| `theme` | string | `"toggle"` | `light\|dark\|auto\|toggle\|toggle-auto` |
| `toc` | bool | `false` | Enable TOC |
| `use_cdn` | bool | `false` | Load fonts from jsDelivr |
| `favicon` | string | `/icons/favicon.png` | Favicon path |
| `fancy_code` | bool | `false` | Copy button + language label |
| `dynamic_note` | bool | `false` | Toggling note shortcode |
| `mathjax` | bool | `false` | Global MathJax |
| `repo_url` | string | — | Base for "Source Code" links |
| `repo_view` | bool | `false` | Global source-code link |
| `word_count` | bool | `false` | Show word count |
| `logo` | string | — | Replace site-title with `<img>` |
| `fediverse` | bool | `false` | Emit fediverse:creator meta |
| `fediverse_creator` | string | `""` | Handle |
| `menu` | `[{name,url,weight}]` | `[]` | Nav menu |
| `socials` | `[{name,url,icon}]` | `[]` | Social links |
| `stylesheets` | `[string]` | `[]` | Extra CSS |
| `[extra.taxonomies]` | table | — | `sort_by`, `reverse` |
| `[extra.analytics]` | table | — | `enabled` + provider sub-tables |

arata's `config.gleam` reads these from the `config` object in
`content_index.json` (emitted by the Phase 17 build pipeline).

---

## 7. Phased implementation plan

Each phase is self-contained: it ends with `gleam build` passing and a runnable
increment. Conventional Commits are used per phase (e.g.
`feat(theme): implement 5-mode theme switching`).

### Phase 0 — Scaffold ✅ DONE
- gleam project (`javascript` target), lustre + modem + gleam_json +
  lustre_dev_tools deps pinned, `[tools.lustre.html]` config, stub module
  layout, minimal bootable `arata.gleam`.
- **Acceptance:** `gleam build` passes; `gleam run -m lustre/dev start` serves a
  placeholder page.

### Phase 1 — Visual design system & static assets ✅ DONE
**Goal:** port apollo's SCSS to plain CSS and copy static assets so the
placeholder page already looks like apollo.

**Apollo reference:** `apollo/sass/**`, `apollo/static/{fonts,icons,giallo-*.css}`.

**Files:**
- `src/arata.css` — concatenate `main.scss` + `sass/parts/_*.scss` with SCSS
  vars inlined (`--page-width`, `--font-size-base`, font-family vars,
  `$language-colors` → CSS).
- `static/theme/light.css`, `static/theme/dark.css` — from
  `sass/theme/{light,dark}.scss` → `:root.light { … }` / `:root.dark { … }`.
- `static/giallo-light.css`, `static/giallo-dark.css` — copy verbatim.
- `static/fonts/` — copy `{zed-fonts,JetbrainsMono,SpaceGrotesk}` verbatim.
- `static/icons/` — copy `social/` (44) + UI icons verbatim.

**Steps:**
1. Copy fonts, icons, `giallo-*.css` from the cloned apollo repo into
   `arata/static/`.
2. Hand-port `sass/theme/light.scss` → `static/theme/light.css`.
3. Hand-port `sass/theme/dark.scss` → `static/theme/dark.css`.
4. Hand-port `sass/main.scss` + `sass/parts/_*.scss` → `src/arata.css`,
   inlining SCSS variables and expanding `@use`/`@media`.
5. Wire both theme stylesheets into the head via `[tools.lustre.html]` or a
   custom `index.html` (light unconditional, dark with `disabled`).
6. Style the placeholder page with apollo's `.page-header` so it matches.

**Acceptance:** the placeholder renders with apollo's fonts, colours, and
`.page-header` typography in both light and dark (toggle via devtools).

### Phase 2 — Routing & app shell ✅ DONE
**Goal:** wire modem + the `Route` type so navigation works end-to-end (pages
can be empty placeholders).

**Apollo reference:** apollo has no client router; this is new. Pattern after
`lustre/examples/04-applications/01-routing`.

**Files:** `src/route.gleam`, `src/models.gleam`, `src/arata.gleam`,
`src/config.gleam` (stub).

**Steps:**
1. Implement `route.parse_route(Uri) -> Route` covering every entry in §3.3.
2. Implement `route.href(Route) -> Attribute(msg)` (the inverse).
3. Define `Model` (route + config + content placeholders + theme + search + toc)
   and `Msg` (`UserNavigatedTo(Route)` first).
4. Switch `arata.gleam` from `lustre.simple` to `lustre.application(init,
   update, view)`; call `modem.init(...)` in `init`; parse `modem.initial_uri()`
   for the first route.
5. `view` pattern-matches on `model.route` and renders a per-route placeholder.
6. Make every internal link use `route.href` so modem intercepts clicks.

**Acceptance:** clicking nav links changes the URL and the rendered placeholder
without a full page reload; deep links load the right route; unknown paths hit
`NotFound`.

### Phase 3 — Layout, header, footer, nav ✅ DONE
**Goal:** the chrome around every page — header (logo/title, menu, socials,
search button, theme toggle), footer (socials, copyright), 3-column layout.

**Apollo reference:** `templates/base.html`, `partials/{header,nav}.html`,
`macros/{macros,components}.html`.

**Files:** `src/view/{layout,header,footer,icon_button}.gleam`, `src/config.gleam`.

**Steps:**
1. Implement `layout.view(content)` producing the 3-column flex skeleton
   (`.left-content` / `.content` / `.right-content`) + header + footer.
2. Implement `header.view` with `.left-nav` (title or `<img class="logo">`) and
   `.right-nav` (menu `<a>`s, conditional search button, conditional toggle).
3. Implement `footer.view` with social links + copyright.
4. Implement `icon_button.view(href, text, icon)` (from `components.html`).
5. Load `config` (menu, socials, logo, favicon) into the model.
6. Emit favicon `<link>` and `<title>` in the head.

**Acceptance:** every route renders inside the apollo chrome; menu/socials
render from config; active nav link is highlighted (`attribute.classes`).

### Phase 4 — Content pipeline (build step, part 1) ✅ DONE
**Goal:** read `content/`, parse frontmatter, render markdown to HTML, emit
`content_index.json` for the SPA to consume.

**Apollo reference:** Zola's markdown pipeline + shortcodes.

**Files:** `src/build/{pipeline,frontmatter,markdown}.gleam`, a `content/`
directory with sample apollo posts.

**Steps:**
1. Choose a markdown renderer (comrak via FFI, or a pure-Gleam CommonMark port).
2. Write `frontmatter.parse` for TOML `+++ … +++` (use `gleam/toml` or a TOML
   lib).
3. Write a shortcode pre-processor that expands `{{ character(…) }}`,
   `{{ note(…) }}`, `{% mermaid() %}…{% end %}`, `{{ image(…) }}` into
   placeholder HTML before markdown rendering (full shortcode rendering is
   Phase 13; here just pass-through).
4. Emit `content_index.json` with the shape from the research notes (posts,
   projects, talks, tags, pages, config).
5. Add a `gleam run -m arata/build` entrypoint.

**Acceptance:** running the build on the sample `content/` produces a valid
`content_index.json`; the SPA can `rsvp.get` it and log the post count.

### Phase 5 — Post list & pagination ✅ DONE
**Goal:** the `/posts` page renders a chronological, paginated post list.

**Apollo reference:** `templates/section.html`, `macros/macros.html::list_post`.

**Files:** `src/view/post_list.gleam`, `src/pages/section.gleam`, `src/data/{post,content}.gleam`.

**Steps:**
1. Decode `content_index.json` into `ContentTree` (posts sorted by date desc).
2. Implement `post_list.view(posts)` using `keyed.ul` keyed by slug.
3. Implement `list_post` (the per-item view: title link, date, description,
   draft label, external-link `↗`).
4. Implement `Paginator` (prev/next from `paginate_by`).
5. Render pagination `<a href>` via `route.href`.

**Acceptance:** `/posts` shows N posts per page with prev/next; drafts show the
`DRAFT` label; external-link posts show `↗`.

### Phase 6 — Single post, TOC, meta ✅ DONE
**Goal:** the `/posts/<slug>` page renders a full article with TOC and meta row.

**Apollo reference:** `templates/page.html`, `partials/toc.html`, `static/js/toc.js`.

**Files:** `src/view/{post,toc}.gleam`, `src/effect/toc.gleam`, `src/ffi/observer.ffi.mjs`.

**Steps:**
1. Implement `post.view(post)`: `.page-header` (title + meta row), optional
   `.tldr`, `<section class="body">` (rendered HTML), anchor links on headings.
2. Meta row: date, `:: Updated on`, word count (if `extra.word_count`), reading
   time (if `extra.read_time`), `:: Source Code` link (if `extra.repo_view`),
   draft label, authors.
3. Implement `toc.view(toc)` (3-level nested `<ul>`).
4. Implement `effect/toc.gleam` with an IntersectionObserver FFI dispatching
   `TocActiveHeadingChanged(id)`; model stores `active_heading`; apply
   `.selected`/`.parent` classes.
5. Hide TOC below 1365px (CSS).

**Acceptance:** a post renders with TOC; scrolling highlights the active
heading; meta row shows the right fields per frontmatter.

### Phase 7 — Projects (cards) & Talks grids ✅ DONE
**Goal:** `/projects` and `/talks` render their card grids.

**Apollo reference:** `templates/cards.html`, `templates/talks.html`.

**Files:** `src/pages/{cards,talks}.gleam`, `src/view/{card,talk_card}.gleam`.

**Steps:**
1. Implement `reorder_for_columns(items, cols)` (column-balanced reordering).
2. Implement `card.view(project)`: media (local/remote image/video), title,
   description, `#tag` chips, github/demo icon-buttons, external `link_to`.
3. Implement `talk_card.view(talk)`: video thumbnail with play-button overlay,
   title, truncated description, organizer, slides/code icon-buttons.
4. Respect `cards_columns` / `card_media_height` frontmatter via CSS vars.
5. Apply responsive row↔column flip for talks at 1024px.

**Acceptance:** projects fill columns in balanced order; talks flip layout at
1024px; icon-buttons link correctly.

### Phase 8 — Taxonomy (tags) ✅ DONE
**Goal:** `/tags` and `/tags/<tag>` pages.

**Apollo reference:** `templates/taxonomy_{list,single}.html`.

**Files:** `src/pages/taxonomy_{list,single}.gleam`.

**Steps:**
1. Build the tag index from `ContentTree` (name, slug, page_count, pages).
2. `taxonomy_list.view`: sorted by `name` or `page_count` per
   `[extra.taxonomies]`.
3. `taxonomy_single.view`: reuse `post_list.view` with a
   `Entries tagged :: <tag>` header.

**Acceptance:** `/tags` lists all tags; `/tags/<tag>` lists that tag's posts.

### Phase 9 — Homepage, standalone pages, 404 ✅ DONE
**Goal:** `/`, `/<page>`, and the 404.

**Apollo reference:** `templates/homepage.html`, `page.html`, `404.html`.

**Files:** `src/pages/{home,not_found}.gleam`, `src/view/page.gleam`.

**Steps:**
1. `home.view`: render the homepage markdown body (no post list, unless the
   homepage frontmatter opts into a recent-posts slice).
2. `page.view`: standalone page (about, etc.).
3. `not_found.view`: absolute-centered `.not-found-header` at `3em`.

**Acceptance:** `/` shows the homepage; `/about` shows the about page; a bogus
URL shows the 404.

### Phase 10 — Theme system (5 modes, FOUC, persistence) ✅ DONE
**Goal:** faithful theme switching with all 5 modes.

**Apollo reference:** `partials/header.html` (lines 179–261),
`static/js/themetoggle.js`.

**Files:** `src/effect/theme.gleam`, `src/ffi/theme.ffi.mjs`, `src/models.gleam`.

**Steps:**
1. Define `Theme { Light; Dark; Auto }` and
   `ThemeMode { LightOnly; DarkOnly; AutoOnly; Toggle; ToggleAuto }`.
2. `init` reads `localStorage["theme-storage"]` via FFI; falls back to system
   preference.
3. `update(ToggleTheme)` cycles modes per `ThemeMode`.
4. Subscribe to `matchMedia('(prefers-color-scheme: dark)')` →
   `SystemPrefersDarkChanged(Bool)`; recompute `effective_theme` when `Auto`.
5. Apply theme by toggling `class="light"`/`"dark"` on `<html>` and the
   `disabled` attribute on the syntax/theme `<link>`s.
6. FOUC: emit `<html class="dark light">` + always-load-light-CSS in the initial
   `index.html` (Phase 17); SPA only toggles `disabled`.

**Acceptance:** all 5 `config.theme` modes behave like apollo; theme survives
reload; system-pref change updates `auto` mode live.

### Phase 11 — Syntax highlighting & fancy code blocks ✅ DONE
**Goal:** highlighted code with copy button + language label.

**Apollo reference:** `[markdown.highlighting]`, `static/js/codeblock.js`,
`sass/parts/_code.scss`.

**Files:** `src/build/highlight.gleam`, `src/view/code_block.gleam`,
`src/effect/clipboard.gleam`, `src/ffi/clipboard.ffi.mjs`.

**Steps:**
1. Build-time: highlight code emitting `giallo` class names (`pre.giallo`,
   `.giallo-l`, `.giallo-ln`, `.z-hl`).
2. `view_code_block(lang, code)`: inject `.clipboard-button` +
   `.code-label.label-<lang>` (color from the ported `$language-colors` map).
3. `Msg = UserCopiedCode(String) \| ClipboardReturned(Result)`;
   `effect/clipboard.gleam` calls `navigator.clipboard.writeText` (strips
   `.giallo-ln` spans first); 2s icon swap (clipboard → check / ×).
4. IntersectionObserver + scroll listener to pin button/label on wide `pre`.

**Acceptance:** code blocks show a colored language label and a working copy
button; copied text has no line numbers.

### Phase 12 — Search (elasticlunr, Cmd/Ctrl+K modal) ✅ DONE
**Goal:** the search modal with keyboard navigation.

**Apollo reference:** `partials/nav.html`, `static/js/searchElasticlunr.js`
(keep the elasticlunr core, lines 1–2567; rewrite the modal controller,
lines 2569–3202, in Lustre).

**Files:** `src/view/search_modal.gleam`, `src/effect/search.gleam`,
`src/ffi/search.ffi.mjs`, `src/build/search_index.gleam`.

**Steps:**
1. Build-time: emit `search_index.<lang>.json` (elasticlunr format).
2. `SearchState { open, query, results, selected_index, index_loaded }`.
3. `Msg = UserOpenedSearch \| UserClosedSearch \| UserEnteredSearchQuery(String) \| SearchReturnedResults(List) \| UserPressedSearchKey(Key) \| UserClearedSearch \| IndexLoaded`.
4. Lazy-load the index on first search-button hover/touch (effect).
5. Global `keydown` listener: Cmd/Ctrl+K opens, Esc closes, ↑/↓ navigate,
   Enter follows.
6. Modal: backdrop-blur, max-height 50vh (70vh mobile), `aria-selected`
   highlighting.

**Acceptance:** Cmd/Ctrl+K opens the modal; typing queries the index; keyboard
navigation works; results link to posts.

### Phase 13 — Shortcodes (note, character, image, mermaid) ✅ DONE
**Goal:** all four shortcodes render correctly inside markdown bodies.

**Apollo reference:** `templates/shortcodes/{note,character,mermaid,image}.html`.

**Files:** `src/shortcodes/{note,character,mermaid,image}.gleam`,
`src/build/markdown.gleam` (integrate).

**Steps:**
1. `note.view`: static (`.note-header` + `.note-content`) or dynamic
   (`<button class="note-toggle">` toggling `open_notes: Set(String)`).
2. `character.view`: 80×80 avatar + speech bubble, left/right flip.
3. `image.view`: `<img aspect-ratio="W/H" loading="lazy" decoding="async">`.
4. `mermaid.view`: `<pre class="mermaid">` (rendering in Phase 14).
5. Wire the shortcode pre-processor (Phase 4) to call these.

**Acceptance:** posts using each shortcode render identically to apollo.

### Phase 14 — MathJax & Mermaid rendering ✅ DONE
**Goal:** math typesets and mermaid diagrams render after navigation.

**Apollo reference:** `partials/header.html` (MathJax config),
`static/js/mermaid.js`, `static/js/main.js::mermaidRender`.

**Files:** `src/effect/script.gleam`, `src/ffi/script.ffi.mjs`, head scripts in
`index.html`.

**Steps:**
1. Emit MathJax config + CDN script in `index.html` head (global or per-page).
2. Emit the vendored `mermaid.js` in `index.html`.
3. `effect/script.gleam`: after each post view patch, call
   `MathJax.typesetPromise()` (if `extra.mathjax`) and `mermaid.run()` (if
   mermaid blocks present). Theme change re-renders mermaid with
   `dark`/`neutral` theme.

**Acceptance:** `$$…$$` math renders; mermaid blocks render; both survive route
changes; mermaid re-themes on toggle.

### Phase 15 — Comments, analytics, SEO, feeds, sitemap, injection points ✅ DONE
**Goal:** the long tail of site-wide features.

**Apollo reference:** `partials/header.html`, `base.html` injection points,
`_giscus_script.html`, analytics JS.

**Files:** head builder in `index.html` (Phase 17), `src/build/feeds.gleam`,
`src/view/head.gleam`.

**Steps:**
1. Comments: `view/post.gleam` emits `<div class="giscus">` + script when
   `extra.comment`; `effect/script.gleam` re-injects giscus on route change.
2. Analytics: emit GoatCounter/Umami/Google scripts in head when enabled; copy
   vendored `count.js`/`imamu.js`.
3. SEO: head builder emits `<title>`, `og:title`, `description`,
   `og:description` with dedup against `extra.meta`; OpenGraph; Fediverse meta.
4. Custom stylesheets + 4 HTML injection points (`head_start/end`,
   `body_start/end`) via `element.unsafe_raw_html`.
5. `build/feeds.gleam`: emit `atom.xml`/`rss.xml` (per `feed_filenames`) +
   `sitemap.xml`.

**Acceptance:** per-page comments load; analytics fire; view-source shows
correct meta; feeds and sitemap validate.

### Phase 16 — Static-site generation / build pipeline ✅ DONE
**Goal:** replace Zola end-to-end: `content/` → `dist/` with a hydratable SPA,
search index, feeds, sitemap, minified assets.

**Files:** `src/build/{pipeline,minify,image}.gleam`, a custom `index.html`
template.

**Steps:**
1. `pipeline.run`: walk `content/` → `content_index.json` + per-page HTML +
   `search_index.json` + `atom.xml`/`rss.xml` + `sitemap.xml`.
2. `build/image.gleam`: shell out to `libvips`/`imagemagick` for
   `resize_image` (avif/webp, quality defaults from §4).
3. Emit `index.html` with the FOUC-prevention `<html class="dark light">`, both
   theme `<link>`s (dark `disabled`), fonts, favicon, MathJax/Mermaid/analytics
   scripts, and a `<script type="application/json" id="arata-state">` blob for
   hydration (optional, Phase 18+).
4. Bundle the SPA (`gleam run -m lustre/dev build --minify --outdir=dist`).
5. `build/minify.gleam`: minify HTML/CSS/JS into `dist/`.
6. Add a `404.html` redirect shim for static hosts (deep-link support).
7. Document the deploy (GitHub/Cloudflare Pages).

**Acceptance:** `gleam run -m arata/build` produces a `dist/` that, served
statically, behaves identically to `zola build` on the same content.

### Phase 17 — Polish, accessibility, responsive, tests ✅ DONE
**Goal:** production quality.

**Steps:**
1. Audit semantic HTML (`main`, `header`, `nav`, `article`, `footer`), ARIA
   (search modal roles, note `aria-expanded`, TOC nav).
2. Keyboard navigation across all interactive elements; visible focus states.
3. Verify every breakpoint in §5.5 against the apollo reference.
4. Sticky-footer behaviour (short pages pin footer, long pages push it).
5. Unit tests with `gleeunit` for pure logic (`parse_route`, `href`,
   `reorder_for_columns`, frontmatter parsing, dedup).
6. Lustre view tests with `lustre/dev/query` + `lustre/dev/simulate`.
7. Optional: snapshot tests with `element.to_readable_string`.

**Acceptance:** no axe/lighthouse critical issues; all breakpoints match apollo;
test suite green.

### Phase 18 — Release & docs ✅ DONE
**Steps:**
1. Write a `docs/` guide (config reference, content authoring, shortcode
   reference, deployment).
2. Tag `v0.1.0`; publish a demo deployment.
3. Cut a `CHANGELOG.md`.

---

## 8. Post-v0.1.0 Improvements

After the v0.1.0 release, arata received a round of polish and architectural
improvements. These are not part of the original 19-phase plan but reflect the
project's evolution toward a leaner, more maintainable codebase.

### File-based content model

Replaced the build-time `content_index.json` emission with a runtime file-based
loader. Markdown files live under `content/{posts,pages,projects,links}/*.md`
and are parsed at runtime by the [`mork`](https://hexdocs.pm/mork) markdown
parser. This removes the build step's frontmatter/HTML pipeline and lets authors
edit content without rebuilding.

### CSS modular split

Source CSS reorganised into 10 modules under `src/css/`:
`base`, `layout`, `components`, `post`, `toc`, `search`, `cards`, `links`,
`syntax`, `accessibility`. The build emits each as a separate `<link>` tag
under `dist/css/`, so each page loads only the styles it needs. Total: ~115 KB
minified (32 KB gzipped).

### Config system

A unified `config.gleam` reads site configuration from a single source, with
flags for:

- font families (text, header, code),
- `rss_enabled`, `search_enabled`, `mathjax_enabled`,
- analytics providers (GoatCounter, Umami, Google).

### Mobile menu

A hamburger button appears below 992px and toggles a vertical dropdown of nav
links, replacing the previous always-visible nav which overflowed on small
screens.

### Search improvements

- Search now includes the post body (HTML stripped to plain text), not just
  title/description/tags.
- Results show a context snippet (80 chars before/after the match) so the
  reader gets more surrounding context for a hit.
- The search input auto-focuses when the modal opens.

### ToC multi-level with CJK support

The table of contents now parses `h2`, `h3`, and `h4` headings into a nested
tree (previously single-level). CJK heading IDs use a punctuation-denylist
slugify with a sequential fallback (`heading-1`, `heading-2`, …) for non-ASCII
slugs. The `view_child` renderer is now recursive, so `h4` headings under an
`h3` actually appear in the ToC instead of being silently dropped.

### Links page with avatars

The links page renders each link as a card with an optional circular avatar
(from the `image` field), a border, and a hover effect. Card content is no
longer wrapped in an `<a>` (`role=generic`); only the title is a link.

### Bundle optimization

Production bundle measured at 115 KB minified (32 KB gzipped), well-optimised
for an SPA of this scope. Achieved via the CSS modular split, removal of
bundled web fonts (system font stacks), and tree-shaking of unused Lustre APIs.

### Theme toggle modernized

The theme toggle is now a plain icon button with an opacity hover, replacing
the earlier oval-background variant. The moon/auto icons are hidden by default
(`display: none`) so only the active icon shows, eliminating the triple-icon
flash on first paint.

### Post headings clickable with anchor links

Post subheadings (`h2`–`h4`) are now wrapped in `<a href="#id">` so readers can
click to copy/share a deep link to a section.

### Page jump input in pagination

The pagination bar now includes a page-jump input — type a page number and
press Enter to navigate directly to that page.

### 404.html serves SPA shell directly (no redirect loop)

Static hosts that serve `index.html` for every path used to cause a refresh
loop on deep links: refreshing `/posts/foo` served `404.html`, which
redirected to `/#/posts/foo`, which the SPA re-parsed as a navigation, ad
infinitum. The first fix stored the requested path in `sessionStorage` and
redirected to `/` cleanly. The current approach is simpler and avoids the
redirect entirely: `404.html` now serves the SPA shell directly (same payload
as `index.html`). modem reads the URL from the address bar on init and routes
to the right post in a single navigation, so deep-link refreshes load the
correct page and the URL is preserved verbatim — no `sessionStorage`, no
redirect, no loop.

### Floating ToC + scroll-to-top buttons (all screen sizes)

The floating table-of-contents button is now visible on **all screen sizes**
(desktop as well as mobile), not just below 992px. Tapping it opens an overlay
that re-renders the `.toc` tree plus a **Tags** list beneath, so readers can
jump between sections or pivot to a tag from anywhere on a post. A second
floating button — **scroll-to-top** — appears on every page and smoothly
scrolls the window back to the top. Both FABs sit in the bottom-right corner
and do not overlap.

### Multi-platform project hosting

The `Project` type now has explicit `gitlab`, `codeberg`, and `forgejo` fields
(alongside the existing `github` field), so projects hosted on GitLab,
Codeberg, or a self-hosted Forgejo instance link correctly from the card
footer's icon-button row. Each field is optional; the card renders an
icon-button only for the providers that are set.

### forgejo.svg social icon

A `forgejo.svg` icon was added to the bundled social icon set
(`static/icons/social/`), alongside the existing `github.svg`, `gitlab.svg`,
and `codeberg.svg`, so Forgejo links render with a recognisable glyph in both
the navbar social row and project card footers.

### Default theme icon: auto

The theme toggle now defaults to showing the `auto` icon; the `sun` and
`moon` icons are hidden with `display: none` until their theme is active.
This eliminates the triple-icon flash on first paint and makes the default
(`auto`) state visually obvious. The toggle button also sets `appearance:
none` to shed the user-agent's default button styling, so the icon reads as a
plain glyph with an opacity hover.

### Route tests for static files and deep links

Added unit tests in `test/route_test.gleam` that assert `/atom.xml`,
`/rss.xml`, and `/sitemap.xml` parse to `NotFound` (so modem lets the browser
fetch them directly rather than intercepting as 404 pages), and that deep
post links (e.g. `/posts/markdown`) parse to `Post(slug)` rather than
`NotFound`. These guard against regressions in the static-file vs.
catch-all ordering.

### Project card tag styling

The `#tag` chips on project cards now use a 0.5rem gap, horizontal padding,
and a rounded background, so the chips read as a grouped pill row rather than
plain text. Post titles on cards also moved to font-weight 700 (was inherited
400) for clearer contrast against the 400-weight body copy.

### CJK word count

The post meta word-count now counts multi-byte characters (e.g. CJK
ideographs) as individual words instead of treating a whole run as a single
word, so the displayed count is meaningful for non-Latin content.

### RSS path fix

Social-link RSS icons used to 404 on sub-pages because they pointed at a
relative URL. They now use the absolute `/atom.xml` path with `target=_blank`
and `rel="noopener"` (was `rel="me"`); `/atom.xml` is verified to exist in
`dist/`, so the feed resolves on every route.

### Body text color and font-weight adjustments

Body font-weight reverted to 400 (normal) for a softer reading experience, and
the body text colour is now semi-transparent (`#F0F0F0DE` in dark, `#151515DE`
in light) to reduce harsh contrast. Post content uses 400-weight body text —
distinct from the 700-weight title — so headings stand out without the body
feeling heavy. HR separators use `#6c7086` for a subtler rule.

### 404 flash fix (loading indicator in `#app`)

On deep-link refreshes the SPA shell was blank for the brief moment between
the static `404.html` (served by the host) rendering and `app.mjs` booting.
The shell's `<div id="app">` now ships with a small loading indicator so the
reader sees something meaningful immediately instead of a white flash. The
indicator is replaced by the Lustre-rendered tree on the first paint.

### Post list tags (clickable pills between title and content)

Each entry on the `/posts` list now renders its `tags` as clickable pill
chips, placed between the title and the description/content excerpt. Clicking
a tag navigates to `/tags/<name>`. The pills reuse the existing `.tag` /
`.tag-list` styling from `src/css/components.css`, so they pick up the
`--primary-color` accent and the dark-theme variants automatically.

### Page-jump input modernized

The pagination-bar page-jump input was restyled: it now has a visible border,
a rounded radius, and a `:focus` state that highlights the field with the
accent colour. The control is also more compact so it slots into the
pagination row without pushing the Prev/Next buttons onto a second line on
narrow viewports.

### `toc-overlay-scroll-top` contrast

The scroll-to-top button inside the floating ToC overlay was nearly invisible
against the overlay background. It now uses `--primary-color` as its
background, with white text, so it reads as a deliberate call-to-action and
matches the accent used elsewhere on the page (links, active nav, tag pills).

### Floating menu tags spacing (pill chips)

The Tags list inside the floating ToC overlay was cramped — the chips ran
together with no gap. They are now laid out as a proper pill row with
`gap: 0.5rem`, padding, and a rounded background per chip, matching the
project-card tag styling. Long tag lists wrap cleanly to the next line.

### Moon-icon `filter: invert(1)`

The `moon.svg` icon (used for the dark-theme state of the theme toggle) is
drawn as a black glyph on transparent. In dark mode the black glyph was
invisible against the dark background. The icon now carries
`filter: invert(1)` in its CSS rule so it renders white-on-dark — visible in
both themes without shipping a second, inverted SVG.

### `text-1` color adjustment

The `--text-1` token (used for secondary text: meta rows, captions, the
`tl;dr` body, etc.) was too washed out (`#666666` light / `#999999` dark).
It is now `#222222` in light mode and `#cccccc` in dark mode — still clearly
secondary to the body text but legible enough to read without squinting.

### Config: `sidebar_enabled` and `floating_buttons_enabled`

The `Config` type gained two new boolean toggles:

- **`sidebar_enabled`** — when `False`, the right sidebar (ToC + Tags) is
  omitted on post pages so the body takes the full content width. Defaults
  to `True`.
- **`floating_buttons_enabled`** — when `False`, the floating ToC/tags FAB
  and the overlay's scroll-to-top button are not rendered (the overlay is
  also unreachable since there is no entry point). Defaults to `True`.

Both are documented in `content/posts/configuration.md` and surfaced in the
`Config` code sample.

### Post cards (bordered with hover)

Each entry on the `/posts` list is now wrapped in a bordered card with a
hover effect (subtle border-colour shift + elevation). This mirrors the
visual treatment already used by the links page and the projects grid, so
all three list pages now read as a consistent "card" pattern.

### Absolute paths in `index.html` / `404.html` (deep-link fix)

`index.html` and `404.html` previously referenced `./app.mjs` and
`./css/…`, which broke on deep links: refreshing `/posts/markdown` resolved
`./app.mjs` to `/posts/app.mjs` (a 404) so the SPA never booted. Both shells
now use absolute paths (`/app.mjs`, `/css/…`) so the assets resolve from the
site root on every route. This complements the earlier "404.html serves the
SPA shell directly" change and makes deep-link refreshes reliable on every
static host.

---

## 9. Risks & key decisions

1. **External `<script src=…>` execution in Lustre.** Lustre's vdom diff does
   not re-execute scripts on route change. **Mitigation:** emit MathJax,
   Mermaid, Giscus, and analytics scripts in the initial `index.html`; use
   `effect/script.gleam` to call their JS APIs (`MathJax.typesetPromise()`,
   `mermaid.run()`, giscus re-inject) after each view patch.
2. **Markdown pipeline with shortcodes.** apollo relies on Zola's CommonMark +
   GFM + shortcodes. arata must pre-process shortcodes in Gleam before handing
   markdown to the renderer (comrak via FFI is the leading candidate).
3. **`resize_image`.** Shell out to `libvips` (`vips thumbnail`) or
   `imagemagick` (`convert`) at build time.
4. **SPA vs SSG.** arata is a client SPA with a build step that emits static
   assets. Full SSR/SSG (server-rendered HTML per route) is deferred to a
   future phase using `element.to_document_string` + `lustre/ssg`.
5. **FOUC.** Replicate apollo's `<html class="dark light">` + always-load-light
   approach by emitting both `<link>`s in `index.html` before the SPA script.
6. **SCSS.** Hand-port to plain CSS to avoid a Dart-Sass dependency in the
   build. apollo's SCSS is mostly variables + `@media`, so the port is
   mechanical.
7. **elasticlunr.** Keep the vendored core; rewrite only the 635-line modal
   controller in Lustre. Alternatively evaluate a Gleam search library later.

---

## 10. Version pins & dependencies

| Package | Pin | Purpose |
|---|---|---|
| `gleam` | `1.14.0` (installed from source) | language/toolchain |
| `lustre` | `>= 5.7.0 and < 6.0.0` | UI framework (v6 may rename APIs) |
| `lustre_dev_tools` | `>= 2.3.6 and < 3.0.0` | dev server + build |
| `modem` | `>= 2.1.3 and < 3.0.0` | client-side routing |
| `gleam_json` | `>= 3.1.0 and < 4.0.0` | JSON encode/decode |
| `gleam_stdlib` | `>= 0.44.0 and < 2.0.0` | stdlib |
| `rsvp` | `>= 1.0.1 and < 2.0.0` | HTTP (content index fetch) — add in Phase 4 |
| `formal` | `>= 3.0.0 and < 4.0.0` | form parsing (if needed) |
| `gleeunit` | `>= 1.0.0 and < 2.0.0` | tests (dev) |

API notes (current names — older tutorials may differ): use `lustre.simple` /
`lustre.application` / `lustre.component` (not `full_app`); `lustre.start(app,
selector, flags)` is the only SPA starter; `effect.subscribe`/`unsubscribe`/
`provide` are new in v5.7.0; `element.memo`/`ref` are new in v5.5.0 (opt-in).

---

## 11. Definition of done

arata is "done" when **all** of the following hold:

1. Every feature in §4 is implemented and matches apollo's behaviour.
2. The same `content/` tree rendered through apollo and arata is visually
   indistinguishable at every breakpoint in §5.5.
3. `gleam build` and `gleam test` pass with no warnings except intentional
   `todo`s in unstarted phases.
4. `gleam run -m arata/build` produces a `dist/` that serves identically to
   `zola build` on the same content (feeds, sitemap, search index, minified
   assets).
5. Accessibility audit passes (semantic HTML, ARIA, keyboard nav, focus states).
6. `docs/` is written and a demo deployment is live.

---

## 12. References

- apollo source: `https://github.com/not-matthias/apollo` (cloned to
  `apollo/`).
- Lustre source: `https://github.com/lustre-labs/lustre` (cloned to
  `lustre/`).
- Lustre docs: `https://hexdocs.pm/lustre`.
- Key example: `lustre/examples/04-applications/01-routing` (the arata skeleton).
- modem docs: `https://hexdocs.pm/modem`.
- Gleam docs: `https://gleam.run`.

## 13. Follow-up Notes

Following the release of v1.0.0, the ROADMAP has fulfilled its purpose. 

Please refer to CHANGELOG for subsequent versions.
