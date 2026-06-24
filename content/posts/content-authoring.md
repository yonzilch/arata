+++
title = "Content Authoring"
date = "2026-06-22"
updated = "2022-06-24"
description = "How to author posts, projects, links, and pages as markdown with TOML frontmatter."
tags = ["docs", "content"]
+++

# Content Authoring

Arata's content is authored as markdown files with TOML frontmatter in:

```txt
content/
├── posts/
├── pages/
├── projects/
└── links/
````

At build time, `content/loader.gleam` reads each file, parses the TOML
frontmatter, renders Markdown bodies via `mork`, and serializes the typed
content tree to `dist/content_index.json` for the SPA to fetch at runtime.

The browser never reads Markdown files directly.

## Frontmatter Format

arata uses TOML frontmatter delimited by `+++`:

```toml
+++
title = "My Content"
description = "A short summary."
+++
```

YAML frontmatter delimited by `---` is not supported.

## Posts

Posts live in:

```txt
content/posts/*.md
```

Example:

```markdown
+++
title = "My Post"
date = "2026-01-15"
updated = "2026-01-20"          # optional
description = "A short description for the post list and SEO."
tags = ["gleam", "lustre"]
draft = false                   # optional, default false
tldr = "A one-line summary."    # optional
+++

Your markdown body here.
```

Fields:

* `title` — post title.
* `date` — publish date.
* `updated` — optional last-updated date.
* `description` — summary used in the post list, search, and metadata.
* `tags` — optional list of taxonomy tags.
* `draft` — optional boolean. Draft posts show a `DRAFT` badge.
* `tldr` — optional summary box rendered above the post body.

Behavior:

* `slug` is derived from the filename.
* The URL is `/posts/{slug}`.
* The Markdown body is rendered to HTML at build time.
* Heading IDs are generated after Markdown rendering.
* The table of contents is extracted from rendered headings.
* `word_count` and `reading_time` are computed automatically.
* `word_count` is also used by aratafetch's total word-count summary.
* Draft posts are excluded from aratafetch statistics.

## Projects

Projects live in:

```txt
content/projects/*.md
```

Example:

```markdown
+++
title = "My Project"
description = "What it does."
link_to = "https://github.com/me/project"   # optional external link
image = "/images/projects/project.png"      # optional card image
github = "https://github.com/me/project"    # optional
gitlab = "https://gitlab.com/me/project"    # optional
codeberg = "https://codeberg.org/me/project" # optional
forgejo = "https://forgejo.example.com/me/project" # optional
demo = "https://example.com"                # optional
tags = ["gleam", "tool"]                    # optional
+++
```

Projects render as cards at `/projects`.

Projects have no Markdown body — only frontmatter is used.

Supported hosting fields:

* `github`
* `gitlab`
* `codeberg`
* `forgejo`
* `demo`

Projects are counted by aratafetch when the homepage summary is enabled.

## Pages

Pages live in:

```txt
content/pages/*.md
```

Example:

```markdown
+++
title = "About"
subtitle = "A tagline under the title"   # optional
+++

Your markdown body here.
```

Standalone pages are accessible at:

```txt
/{slug}
```

For example:

```txt
content/pages/about.md -> /about
```

## Links

Links live in:

```txt
content/links/*.md
```

Links render as external cards at `/links`.

### Native arata Format

```markdown
+++
title = "Friend Blog"
url = "https://friend.example.com"
description = "A short description."
image = "https://friend.example.com/avatar.png" # optional
weight = 10                                     # optional
+++
```

### Zola-compatible Format

arata also supports Zola-style link metadata:

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
* If `url` is missing, `[extra].link_to` is used.
* `image` is used first.
* If `image` is missing, `[extra].remote_image` is used.
* Missing `weight` defaults to `999`.

### Link Ordering

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

If two links have the same weight, arata falls back to lowercase title
ordering for deterministic output.

This prevents `/links` ordering from depending on filesystem directory order.

Links are also counted by aratafetch when the homepage summary is enabled.

## Homepage

The homepage is a special page stored at:

```txt
content/pages/home.md
```

It renders at:

```txt
/
```

Example:

```markdown
+++
title = "Home"
subtitle = "Optional homepage subtitle"
+++

Welcome to my site.
```

The homepage renders:

1. the page header
2. the optional subtitle
3. the rendered Markdown body
4. the optional aratafetch summary block

## aratafetch

`aratafetch` is an optional neofetch-style ASCII summary block shown at the
bottom of the homepage, after the Markdown body.

It is configured in `src/config.gleam`, not in homepage frontmatter.

Example config:

```gleam
Config(
  // ...
  aratafetch_enabled: True,
  aratafetch_maintained_for: Some("since 2024-06-23"),
)
```

Disable it with:

```gleam
aratafetch_enabled: False,
```

When disabled, no aratafetch DOM is emitted.

`aratafetch_maintained_for` is an optional display string rendered as-is:

```gleam
aratafetch_maintained_for: Some("since 2024-06-23")
```

```gleam
aratafetch_maintained_for: Some("2 years")
```

```gleam
aratafetch_maintained_for: None
```

When `None`, the `maintained` row displays `n/a`.

aratafetch currently summarizes:

* site title
* published post count
* total word count
* unique tag count
* friend link count
* project count
* optional maintenance string

Draft posts are excluded from aratafetch post count, word count, and tag
count.

Comment counts are intentionally omitted for now because external comment
providers such as Giscus or Utterances do not provide a reliable static local
count in arata's current content model.

## Build Output

After running:

```sh
gleam run -m build/pipeline
```

the generated `dist/content_index.json` contains the loaded content tree:

* posts
* pages
* homepage
* links
* projects

The SPA fetches this JSON once on startup and renders all routes from it.

aratafetch also uses this loaded runtime content model, which makes its
statistics deterministic and testable without adding a separate content query
system.
