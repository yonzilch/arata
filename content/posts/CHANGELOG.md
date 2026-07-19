+++
title = "CHANGELOG"
date = "2026-06-21"
description = "Comprehensive CHANGELOG of arata project"
tags = ["docs"]
+++

# Arata — CHANGELOG

All notable changes to arata are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This changelog generally follows the Keep a Changelog structure, but the section
names and grouping may be adjusted when needed to better reflect the actual
changes in arata.

For example, project-specific sections such as 
`CI`, `Contributors`, `Documentation`, or `Internal` may be used when they make a release easier to understand.

---

## [1.6.9] — 2026-07-19

### Added

- Added optional runtime syntax highlighting with configurable Highlight.js loading.

### Changed

- Expanded configuration documentation for Mermaid, syntax highlighting, floating buttons, lightbox, and latest posts.
- Consolidated syntax theme styles and removed redundant Giallo assets.

---

## [1.6.8] — 2026-07-16

### Added

- Added an section of About page explaining the meanings behind the project name "Arata".

### Changed

- Refactored aratafetch metadata rows to share a unified rendering path.
- Replaced the fixed metadata alignment width with dynamic label-based alignment.

### Fixed

- Corrected inconsistent aratafetch value alignment when rendering the longest metadata label.

### Contributors

- [@Fovir-GitHub](https://github.com/Fovir-GitHub) refactored aratafetch metadata rows.

---

## [1.6.7] — 2026-07-16

### Added

- Added Liwan analytics support and configuration documentation.

### Changed

- Updated outdated code comments and analytics documentation.

### Fixed

- Corrected the updated timestamp in `README_zh-CN.md`.

---

## [v1.6.6] — 2026-07-09

### Added
- Added initial GitHub issue template configuration.
- Added `CONTRIBUTING.md` with repository contribution guidelines.
- Added `Arata Lighthouse Score` to the README.
- Added `perfect-lighthouse-score.svg`.

### Changed
- Updated README links for `[Status]` and `[Latest Tag]`.
- Set the default port for `bun run serve` to `3333`.

---

## [v1.6.5] — 2026-07-08

### Added

- Added native Mermaid diagram rendering via Markdown fenced code blocks:

  ```mermaid
  flowchart TD
    A --> B
  ```

* Added configurable runtime asset URLs for MathJax and Mermaid:
  * `mathjax_cdn_url`
  * `mermaid_cdn_url`

* Added `mermaid_enabled` to control Mermaid runtime loading.

### Changed

* Mermaid diagrams are now a first-class Markdown feature instead of a shortcode feature.
* MathJax is now lazy-loaded only when rendered post content appears to contain TeX.
* Runtime script loading now flows through config → effect → FFI instead of relying on hardcoded URLs.
* Updated README and shortcode documentation to reflect native Mermaid fenced-block usage.

### Fixed

* Fixed native ` ```mermaid ` fenced blocks not rendering in post content.
* Fixed Mermaid rendering timing after SPA DOM updates.
* Fixed Mermaid blocks being decorated by the regular code-block enhancer before rendering.
* Fixed Mermaid-only posts unnecessarily loading MathJax.

### Removed

* `src/shortcodes/mermaid.gleam`

---

## [1.6.4] — 2026-07-08

### Changed

- Update README and Simplified Chinese README documentation.
- Remove the loading hint from the page header.
- Adjust `aratafetch` output elements order.

---

## [v1.6.3] — 2026-07-07

### Added

- Add `README_zh-CN.md` for Simplified Chinese readers.

### Changed

- Improve the local development environment by simplifying the Nix devshell:
  - The devshell now acts primarily as a Bun and Gleam toolchain provider.
  - Available Bun scripts from `package.json` are displayed when entering the shell.
  - Duplicated devshell project commands were removed in favor of `package.json` as the single source of truth.
  - Toolchain version output and prompt styling were cleaned up.
- Refine Gleam dependency version constraints.
- Improve README and deployment documentation.
- Rewrite the deployment guide's deployment section for clearer instructions.

### Fixed

- Fix the flake output argument pattern to accept implicit flake inputs.

---

## [v1.6.2-fix] — 2026-07-05

A follow-up patch to v1.6.2 tightening up local build reproducibility.

### Fixed
- `preview` script now runs a full clean before rebuilding, preventing stale `build/` artifacts from affecting the previewed output.

### Changed
- Restructured `deployment.md` to lead with local setup, hot reload, and deploy steps, moving pipeline internals to an appendix.
- Updated deployment docs to reflect current `package.json` scripts and added guidance for git-push-based PaaS deploys that require committing `dist/`.

---

## [v1.6.2] — 2026-07-05

A small but remarkable release focused on developer experience, project reproducibility, and brand asset cleanup.

This release makes local development smoother, CI feedback clearer, and brand assets easier to reuse.

### Added

- A Bun-powered hot reload dev server for instant rebuilds with automatic browser refresh during local development
- Nix flake support for reproducible development environments.
- SVG versions of the Arata logo, including a black-white variant.

### Changed

- Reordered links page entries.
- Replaced the existing `arata-logo` asset with the new logo version.
- Decoupled GitHub Pages deployment results from the main CI status.

---

## [1.6.1] — 2026-07-04

### Changed

- Refined the "Hello, Arata" introductory post and clarified that frontmatter fields such as `description`, `tags`, `draft`, and `tldr` are optional.
- Rewrote the accent color documentation and polished the project layout section in the README.
- Set the project version metadata to `0.0.0`.

### Fixed

- Improved CI deployment reliability by replacing timing-based tag guesswork with deployment state checks.
- Tightened deployment serialization and isolated PR Pages concurrency groups to avoid unnecessary queue blocking.

---

## [v1.6.0] — 2026-07-04

### Added

- Added GoatCounter SPA tracking support for history-based routes.
  - GoatCounter page views are now tracked when navigating between client-side routes.
  - This improves analytics accuracy for deployments using arata as a single-page application.

### Fixed

- Fixed analytics script injection for Umami and GoatCounter.
  - Resolved rendering issues that could prevent analytics scripts from being emitted correctly.
  - Normalized analytics script output to make generated HTML more reliable.
- Fixed an invisible theme icon in automatic theme mode.
  - The theme toggle icon now remains visible when the site is using auto/system theme mode.

### Documentation

- Updated analytics configuration instructions.
- Clarified analytics setup behavior for supported providers.

### CI

- Updated GitHub Pages deployment behavior so tag deployments can own tagged commits.

### Contributors

- [@atp-gh](https://github.com/atp-gh) contributed analytics fixes and GoatCounter SPA tracking support.
- [@not-matthias](https://github.com/not-matthias) fixed the invisible icon issue in auto theme mode.

---

## [v1.5.0] — 2026-06-29

### Changed

- Split the former monolithic `src/css/base.css` into focused CSS modules:
  - `fonts.css`
  - `theme.css`
  - `globals.css`
  - `typography.css`
  - `home.css`
- Extracted additional component-specific styles into dedicated modules:
  - `pagination.css`
  - `lightbox.css`
  - `aratafetch.css`
- Updated the build pipeline CSS order to inline the new module sequence:
  - `fonts`
  - `theme`
  - `globals`
  - `typography`
  - `home`
  - `layout`
  - `components`
  - `pagination`
  - `post`
  - `cards`
  - `links`
  - `search`
  - `toc`
  - `syntax`
  - `lightbox`
  - `aratafetch`
  - `accessibility`
- Updated CSS documentation in `README.md` and `content/posts/configuration.md`.
- Documented theme-specific accent colors in `src/css/theme.css`.
- Moved accent color configuration docs from `base.css` to `theme.css`.

### Improved

- Improved homepage latest-post styling:
  - latest posts now render as compact cards
  - card width is aligned with the aratafetch block
  - titles can wrap instead of being truncated with an ellipsis
  - global link hover styles no longer leak into latest-post titles
- Improved aratafetch layout so it visually aligns with homepage latest-post cards.
- Improved post list card layout and spacing.
- Improved mobile post list behavior by resetting the generated `<ul>` through `.post-list-items`.
- Improved blockquote readability with:
  - theme-aware text color
  - subtle background
  - better spacing
  - left accent border
  - rounded right corners
  - normalized inner paragraph margins

### Fixed

- Fixed post cards appearing offset on small screens due to default browser `<ul>` padding.
- Fixed homepage latest-post title styling conflicts with global link hover rules.
- Fixed outdated CSS module references in documentation.
- Fixed outdated accent color documentation that still pointed to `src/css/base.css`.

### Internal

- Added `.post-list-items` to the post list view so list spacing can be targeted directly.
- Removed `src/css/base.css`.
- Added `--text-color-muted` as a theme-level alias.
- Preserved `accessibility.css` as the final CSS module so focus and accessibility overrides remain authoritative.
- Kept CSS modules copied to `dist/css/` for inspection while continuing to inline them into `index.html` and `404.html`.

---

## [v1.4.3-fix] — 2026-06-26

### Fixed

- Corrected XML escaping test expectations.
  - Feed tests now use raw string inputs when validating XML escaping.
  - Keeps test behavior aligned with the intended `xml_escape` semantics:
    escape raw text once for valid XML output.

---

## [v1.4.3] — 2026-06-26

### Added

- Added browser-friendly previews for generated Atom and RSS feeds.
  - `/atom.xml` now references `atom.xsl`.
  - `/rss.xml` now references `rss.xsl`.
  - Opening feed URLs directly in a browser now shows a readable HTML preview
    instead of raw XML.
  - Feed previews include site title, description, feed URL, expandable entries,
    and total entry count.

### Changed

- Hid the URL scheme in aratafetch's `base_url` row for cleaner terminal-style
  output, while preserving the canonical configured URL for feeds, sitemap, and
  other build outputs.

- Updated the default `base_url` to use the custom domain
  `https://arata.yon.im`.
  - This matches the CNAME setup pointing `arata.yon.im` to GitHub Pages.
  - The site is treated as a root deployment, so `base_path` derives to `""`.

- Updated the build pipeline to emit feed XSL stylesheets when RSS is enabled.
  - `dist/atom.xsl`
  - `dist/rss.xsl`

- Feed stylesheet URLs are now resolved through `Config.base_path`.
  - Root deployments use paths such as `/atom.xsl`.
  - Subdirectory deployments use paths such as `/arata/atom.xsl`.

- Feed previews use self-contained inline styling.
  - No external CSS dependency is required.
  - Browser rendering works independently of the SPA bundle.

### Fixed

- Canonicalized `SiteMeta.base_url` at the configuration boundary.
  - Trailing slash variants such as
    `https://yonzilch.github.io/arata/` now normalize to
    `https://yonzilch.github.io/arata`.
  - This keeps `base_path`, SPA shell paths, runtime metadata, feeds, sitemap,
    robots output, and LLM output aligned.

- Hardened feed and sitemap URL generation.
  - Prevents malformed URLs such as `https://example.com//rss.xml`.
  - Applies defensive URL joins in feed/sitemap output even if a non-canonical
    `base_url` is passed in directly.

### Tests

- Updated feed tests for the new XSL-aware feed generator API.
- Added coverage for XML stylesheet processing instructions.
- Added coverage for omitted stylesheet instructions when no XSL href is passed.
- Preserved existing feed, sitemap, and XML escaping coverage.

### Internal

- Added `src/build/feeds_style.gleam` for feed preview stylesheets.
- Updated `src/build/feeds.gleam` to support optional XSL stylesheet hints.
- Updated `src/build/pipeline.gleam` to write feed XML and feed XSL files
  together when RSS is enabled.
- Updated `src/config.gleam` to normalize `base_url` earlier and more
  consistently.

---

## [v1.4.2] — 2026-06-26

### Added

- Added configurable navbar pinning via `navbar_fixed`.
  - `True` keeps the navbar sticky at the top of the viewport.
  - `False` makes the navbar scroll away with the page content.
  - Existing behavior is preserved by default.

- Added documentation for `navbar_fixed` in the configuration guide.

### Changed

- Reworked `aratafetch` into a compact terminal-style homepage summary.
  - Replaced the previous side-by-side ASCII/stat layout with a stacked CLI-style layout.
  - Added shell prompt output:

    ```txt
    [root@arata:~]$ aratafetch
    ```

  - Added support for rendering site metadata rows such as:
  1. `site_title`
  2. `base_url`
  3. `description`
  - Updated row order to match the current compact output:

    ```txt
    links
    posts
    words
    projects
    tags
    site_title
    base_url
    description
    maintain
    ```

  - Omitted unavailable rows:
  1. numeric rows are hidden when their value is `0`
  2. text rows are hidden when empty
  3. optional rows are hidden when `None`

- Updated `aratafetch` styling so it appears as a compact floating terminal window.
  - The block now shrink-wraps its content instead of stretching across the full page width.
  - Small-screen behavior is improved to avoid horizontal scrolling for normal summary output.

- Refined navbar styling.
  - Slightly reduced the visual size of the navbar.
  - Reduced spacing, icon sizes, and typography scale for a more compact header.

- Centered mobile hamburger menu items.
  - Navigation links, search button, and theme toggle are now centered inside the mobile dropdown.

- Refined floating ToC overlay styling.
  - Reduced overlay footprint so it no longer covers most of the viewport.
  - Constrained width on larger screens.
  - Improved compactness on smaller screens.
  - Hid native browser scrollbars while preserving scroll behavior.

- Hid native browser scrollbars in the right sidebar / sidebar ToC while preserving scroll behavior.

- Cleaned up CSS organization and comments.
  - Moved ToC-specific scrollbar rules into `toc.css`.
  - Updated comments in `toc.css` and `components.css` to reflect current ownership.
  - Removed duplicate pre-Lightbox CSS rules that were overridden by the canonical Lightbox section.

### Build

- Minified emitted CSS during the static build pipeline.
  - Removed inline CSS source markers from generated shell HTML.
  - Stripped CSS block comments.
  - Compacted CSS whitespace and safe token spacing.
  - Minified CSS before inlining into `index.html` and `404.html`.
  - Emitted minified CSS modules under `dist/css/`.
  - Kept existing Bun `--minify` behavior for `dist/app.mjs`.

- Reduced generated `index.html` size from approximately `85.7 kB` to `47.3 kB`.

### Documentation

- Updated configuration documentation for:
  - `navbar_fixed`
  - terminal-style `aratafetch`
  - omitted zero/empty aratafetch rows
  - updated aratafetch output order and example

### Commits

- `feat(aratafetch): render compact terminal-style site summary`
- `style(css): refine navigation and ToC styling`
- `build: minify emitted CSS during static pipeline`
- `style(nav): center mobile hamburger menu items`
- `docs(config): document navbar_fixed behavior`
- `feat(config): add configurable navbar pinning`

---

## [v1.4.1] — 2026-06-26

### Added

- Added an optional homepage latest-posts section rendered between the homepage Markdown body and aratafetch.
- Added `latest_posts_enabled` and `latest_posts_count` configuration options.
- Added a compact editorial-style homepage post listing for surfacing recent content directly from the runtime content model.

### Improved

- Refined homepage latest-posts presentation toward a cleaner editorial aesthetic.
- Reduced visual noise by limiting interaction to post titles only.
- Replaced inline text separators with CSS-generated markers.
- Improved homepage typography, spacing, subtitle hierarchy, and content rhythm.
- Enhanced homepage information density without turning the homepage into a full archive view.

### Documentation

- Documented the built-in Markdown image lightbox gallery feature.
- Documented homepage latest-posts configuration, behavior, and usage examples.

---

## [v1.4.0] — 2026-06-24

### Added

- Added a built-in Lustre-managed gallery lightbox for Markdown body images.
  - Clicking images inside rendered Markdown content now opens a fullscreen preview overlay.
  - The overlay is rendered by Gleam/Lustre and controlled by the app model.
  - JavaScript FFI is limited to observing DOM events from `unsafe_raw_html` content and forwarding typed events back into the update loop.

- Added page-local gallery navigation.
  - Supports previous/next navigation.
  - Supports keyboard controls:
  1. `Escape` closes the lightbox.
  2. `ArrowLeft` moves to the previous image.
  3. `ArrowRight` moves to the next image.
  - Includes image counter and caption display.

- Added mobile-friendly lightbox controls.
  - Larger touch targets for previous/next navigation.
  - Backdrop click closes the overlay.
  - Clicking the image itself does not close the overlay.

- Added lightbox scroll locking.
  - Opening the lightbox locks page scrolling.
  - Closing the lightbox or navigating away restores scrolling.

- Added `lightbox_enabled` configuration.
  - Enabled by default.
  - Can be disabled from `src/config.gleam`.
  - When disabled, Markdown images render normally and no lightbox event listeners are subscribed.

- Added `data-no-lightbox` opt-out support.
  - Individual images or wrappers can opt out of lightbox behavior with:
    ```html
    <img data-no-lightbox ...>
    ```
    or:
    ```html
    <span data-no-lightbox>
      <img ...>
    </span>
    ```

### Changed

- Updated configuration documentation.
  - Documented `lightbox_enabled`.
  - Documented lightbox behavior, keyboard controls, gallery navigation, scroll locking, and event boundaries.
  - Clarified that only Markdown body images matching `.body img` are observed.
  - Clarified that header icons, social icons, project card images, search icons, and theme toggle icons are excluded.

### Notes

- The lightbox is intentionally model-driven:
  - Gleam owns state.
  - Lustre renders the overlay.
  - FFI observes raw Markdown DOM events only.

- Known limitation:
  - During rapid gallery navigation between partially-loaded responsive images, some browsers may temporarily reuse the previously-decoded bitmap until the next image finishes decoding.

---

## [v1.3.1] — 2026-06-24

### Changed

- Increased the base font size for better body text readability.
- Improved light/dark theme contrast while preserving arata's minimal visual style.
- Added standard CSS compatibility improvements, including `line-clamp` alongside `-webkit-line-clamp`.

### Fixed

- Fixed the first theme-toggle click from `Auto` so it produces an immediate visible theme change.
- Fixed project card social icons resolving from the domain root under non-root deployments.
- Fixed incorrect paths in the `about` and `home` content pages.
- Improved theme-toggle icon visibility across Light, Dark, and Auto states.

---
## [v1.3.0] — 2026-06-24

### Added

- Added GitHub Pages deployment workflow.
  - Builds the site with the existing static build pipeline.
  - Runs the test suite in CI.
  - Uploads `dist/` as a GitHub Pages artifact.
  - Deploys with GitHub's Pages deployment action.

- Added support for non-root deployments.
  - Arata can now be deployed under a subdirectory such as a GitHub Pages project site:
    ```txt
    https://yonzilch.github.io/arata/
    ```
  - `Config.base_path` is derived from `SiteMeta.base_url`.
  - Root-domain deployments still resolve to an empty base path.
  - Subdirectory deployments derive the expected runtime prefix, such as:
    ```txt
    /arata
    ```

- Added base-path-aware route test coverage.
  - Tests now cover href generation with the configured base path.
  - Tests now cover parsing URLs that include the configured base path.
  - Round-trip route tests continue to verify:
    ```txt
    parse_route(href_url(route)) == route
    ```

### Changed

- Updated routing to support configured deployment base paths.
  - `route.parse_route` now strips the configured `base_path` before matching internal routes.
  - `route.href_url` now prefixes generated internal URLs with the configured `base_path`.
  - Deep links such as `/arata/posts/configuration` now resolve correctly to the internal post route.

- Updated runtime content loading for subdirectory deployments.
  - `content/runtime.gleam` now fetches `content_index.json` through the configured base path.
  - Requests such as:
    ```txt
    /content_index.json
    ```
    now correctly become:
    ```txt
    /arata/content_index.json
    ```
    when deployed under `/arata`.

- Updated generated HTML shell asset paths.
  - `index.html` and `404.html` now resolve `app.mjs`, favicon, Atom, and RSS links through the configured base path.
  - This prevents root-relative asset requests from breaking under GitHub Pages project-site deployments.

- Updated header asset and social URL resolution.
  - Header icons now resolve through the configured base path.
  - RSS/social feed links now resolve correctly under subdirectory deployments.
  - External URLs remain unchanged.
  - Already-prefixed local URLs are not double-prefixed.

- Updated configuration documentation.
  - Expanded the `base_url` section.
  - Documented how `Config.base_path` is derived from `SiteMeta.base_url`.
  - Added examples for:
    1. root-domain deployments
    2. subdirectory deployments
    3. GitHub Pages project sites
  - Clarified that config paths should remain logical root-relative paths, while arata applies `base_path` at the output/runtime layer.

- Simplified the gleeunit entrypoint.
  - Removed the placeholder `hello_world_test`.
  - Kept `test/arata_test.gleam` focused on running the test suite.

- Formatted code.

### Fixed

- Fixed GitHub Pages project-site deployments.
  - Previously, deploying under `/arata` caused root-relative requests like:
    ```txt
    /app.mjs
    /content_index.json
    /rss.xml
    /icons/social/rss.svg
    ```
    to resolve from the domain root instead of the repository subdirectory.
  - These now resolve correctly as:
    ```txt
    /arata/app.mjs
    /arata/content_index.json
    /arata/rss.xml
    /arata/icons/social/rss.svg
    ```

- Fixed SPA route resolution under non-root paths.
  - Content could load successfully while routes still failed because `/arata/posts/...` did not match the internal `/posts/...` route shape.
  - The router now strips the configured base path before route matching.

- Fixed internal navigation under non-root deployments.
  - Generated route hrefs now stay under the configured base path.
  - Navbar links, post links, tag links, and standalone page links no longer jump to root-level paths.

### Tests

- Updated route href tests to expect the configured base path.
- Added route parsing tests for configured base-path URLs.
- Preserved route round-trip tests for base-path-aware hrefs.
- Verified the test suite passes after enabling non-root deployment support.

---

## [v1.2.0] — 2026-06-24

### Added

- Added `aratafetch` homepage summary to documentation and homepage.
  - Documented configuration (`aratafetch_enabled`, `aratafetch_maintained_for`).
  - Simplified homepage (`content/pages/home.md`) with a minimal design and concise onboarding.

### Changed

- Updated README.
  - Reflected GFM-enabled Markdown rendering.
  - Documented aratafetch feature.
  - Updated build, CSS, and project layout descriptions.

- Simplified homepage content.
  - Reduced verbosity and removed scaffold-heavy instructions.
  - Replaced Quick Start with minimal build + serve workflow.
  - Emphasized file-based content authoring and core entry points.

### Fixed

- Fixed Markdown table rendering.
  - Enabled GFM table parsing via `mork.parse_with_options`.
  - Markdown tables now correctly render as `<table>` instead of plain text.

- Fixed code block enhancement timing.
  - Ensured clipboard button and language label appear on initial post navigation.
  - Added DOM-ready scheduling and mutation observation to handle SPA render timing.

### Notes

- This release stabilizes two core primitives:
  - **Markdown correctness** (GFM parity with expected authoring behavior)
  - **Post-render enhancement timing** (FFI reliability under SPA routing)

These fixes remove two major sources of user-visible inconsistency in authored content and post rendering.

## [v1.1.3] — 2026-06-24

### Added

- Added optional `aratafetch` homepage summary block.
  - Renders a neofetch-style ASCII site summary at the bottom of the homepage, after the Markdown body.
  - Controlled by `Config.aratafetch_enabled`.
  - Supports an optional `Config.aratafetch_maintained_for` display string for the `maintained` row.
  - Summarizes loaded runtime content:

  1. site title
  2. published post count
  3. total word count
  4. unique tag count
  5. friend link count
  6. project count
  7. optional maintenance string

### Changed

- Refactored project card layout.
  - Project tags are now rendered as an independent row between the card title and tagline.
  - The project card footer now only contains external icon links.
  - This prevents tag chips from competing with footer icons for horizontal space on narrow screens.

- Updated configuration documentation.
  - Documented `aratafetch_enabled`.
  - Documented `aratafetch_maintained_for`.
  - Clarified how aratafetch statistics are computed.
  - Clarified that draft posts are excluded from aratafetch post count, word count, and tag count.

- Updated content-authoring documentation.
  - Removed outdated homepage wording about the wavy boundary divider.
  - Added aratafetch behavior to the homepage section.
  - Documented that aratafetch uses the loaded runtime content model.

- Updated deployment documentation.

### Removed

- Removed `comment_count` from aratafetch.
  - Comment statistics are intentionally omitted for now because external comment providers such as Giscus or Utterances do not provide a reliable static local count in arata's current content model.

### Fixed

- Fixed project card tag overflow on small screens by moving tags out of the footer and allowing them to wrap as their own row.

---

## [v1.1.2] — 2026-06-24

### Added

- Added configurable favicon support.
  - `Config` now includes a `favicon` field.
  - `index.html` and `404.html` use the configured favicon during static build generation.
  - When no favicon is configured, the build falls back to the existing default favicon path.

### Changed

- Moved default `SiteMeta` values into `config.gleam`.
  - `config.site_meta()` is now the single source for site metadata defaults.
  - The build pipeline and SPA runtime now read site metadata from configuration instead of `data/site.default()`.
  - `data/site.gleam` is now focused on shared metadata types.

### Fixed

- Kept `index.html` and `404.html` favicon output consistent by generating both from the same configured value.
- Reduced configuration drift between `Config` and `SiteMeta` for shared values such as title, description, analytics, comments, and RSS settings.

---

## [v1.1.1] — 2026-06-23

### Added

- Added Zola-style `weight` support for friend links.
  - Links can now define `weight` in frontmatter.
  - Smaller `weight` values appear earlier on the `/links` page.
  - Links without an explicit `weight` fall back to the default weight.

- Added support for Zola-style link metadata compatibility.
  - `extra.link_to` can be used as the link target.
  - `extra.remote_image` can be used as the link avatar image.

- Added new icons for the links page and related external-link presentation.

### Changed

- Updated the links page content and presentation.
- Links are now sorted deterministically:
  - primary sort: `weight` ascending
  - fallback sort: lowercase `title` ascending
- Improved `/links` page behavior so display order is no longer dependent on filesystem listing order.

### Performance

- Inlined all CSS modules into the SPA shell during the static build.
  - `index.html` and `404.html` now include the generated CSS in a single inline `<style>` block.
  - The previous render-blocking stylesheet requests for `/css/base.css`, `/css/layout.css`, `/css/components.css`, `/css/post.css`, `/css/cards.css`, `/css/links.css`, `/css/search.css`, `/css/toc.css`, `/css/syntax.css`, and `/css/accessibility.css` are removed from the critical rendering path.
  - `dist/css/*.css` is still emitted for inspection/debugging, but the SPA shell no longer references those files directly.

### Fixed

- Fixed unstable ordering on the `/links` page.
  - Previously, link ordering could appear random or filesystem-dependent.
  - Link order is now controlled explicitly by frontmatter `weight`.

### Tests

- Added tests to lock weight-based link ordering.
  - Verifies links are sorted by ascending `weight`.
  - Verifies equal weights use deterministic lowercase title ordering.
  - Verifies loaded links have valid non-negative weights.

---

## [v1.1.0] — 2026-06-23

### Added

- Added `robots.txt` generation to the static build pipeline.
  - `dist/robots.txt` is now emitted during `gleam run -m build/pipeline`.
  - The generated file includes a `Sitemap:` directive based on `SiteMeta.base_url`.
  - The SPA router excludes `/robots.txt` so static hosts can serve the file directly.

- Added `llms.txt` generation to the static build pipeline.
  - `dist/llms.txt` is now emitted as a Markdown file for LLM/agent consumers.
  - The file includes a required H1 heading, site description, and canonical Markdown links to core resources, posts, pages, projects, external links, and the sitemap.
  - Draft posts are excluded from `llms.txt`.
  - Base URLs are normalized to avoid duplicate slashes.
  - The SPA router excludes `/llms.txt` so static hosts can serve the file directly.

- Added validation-oriented static-file routing coverage for crawler-facing assets.
  - `/robots.txt`
  - `/llms.txt`
  - `/atom.xml`
  - `/rss.xml`
  - `/sitemap.xml`
  - `/content_index.json`
  - `/search_index.json`

### Changed

- Updated local preview documentation to use `http-server` instead of Python's built-in static server.

```sh
  nix run nixpkgs#http-server -- -p 8080 dist
```

- Documented that local preview should use a static server suitable for SPA routes.
  - Python's `python -m http.server --directory dist` does not provide SPA deep-link fallback for routes like `/posts/configuration`.
  - `http-server` works correctly for the tested SPA navigation and refresh flow.

- Updated README documentation for the current static-site build and preview workflow.

- Updated demo-site content and homepage styling to better reflect the current arata feature set.

- Adjusted blockquote styling to use the arata accent color `#3555b3`.

- Updated post dates to use the correct 2026 dates.

### Fixed

- Fixed false 404 flashes during SPA startup.
  - Previously, deep-link refreshes could briefly render the 404 page because `posts`, `pages`, `projects`, and other content lists started empty while `content_index.json` was still loading.
  - The app now tracks content loading state explicitly.
  - Route-specific lookup only runs after `content_index.json` has loaded successfully.
  - Loading state now renders a loading view instead of a false 404.
  - Fetch/decode failure now renders a content-load error instead of pretending the site has no content.

- Fixed post-page side effects running too early.
  - TOC observer, code-block enhancement, note enhancement, MathJax, and Mermaid rendering are now armed after content has loaded and the post DOM can exist.
  - This avoids racing effects against an empty initial render on deep-link refresh.

- Fixed local deep-link preview workflow.
  - The documented preview command now avoids Python server behavior where `/posts`, `/posts/configuration`, `/about`, and other SPA routes are returned as server-level 404s.

- Fixed Gleam and Lustre image/icon rendering issues in project/demo content.

- Fixed MathJax rendering test coverage.

### Removed

- Removed unused image assets from the repository/demo content.

### CI

- Added mirror-to-other-git-server workflow support.

### Build

- Updated the generated arata demo site output.

---

## [v1.0.0] — 2026-06-23

### Added

- Post list tags: each entry on the `/posts` list now renders its `tags` as clickable pill chips between the title and the description/content excerpt; clicking a tag navigates to `/tags/<name>`.
- Config: `sidebar_enabled` (enable/disable right sidebar ToC+Tags).
- Config: `floating_buttons_enabled` (enable/disable floating ToC FAB).
- Scroll-to-top button inside floating overlay (top-right, smooth scroll).
- Post cards: each post in the list is wrapped in a bordered card with hover effect.
- **Floating ToC button (all screen sizes)**: the floating ToC FAB is now visible on desktop as well as mobile, so readers on any screen size can toggle the table of contents overlay.
- **Floating overlay Tags section**: the floating ToC overlay now shows a Tags list below the ToC for quick tag navigation.
- **Scroll-to-top button**: a floating button on all pages smoothly scrolls the window back to the top.
- **forgejo.svg social icon**: added a Forgejo icon to the bundled social icon set.
- **Multi-platform project hosting**: the `Project` type now has `gitlab`, `codeberg`, and `forgejo` fields (alongside `github`) so projects hosted on GitLab, Codeberg, or Forgejo link correctly from the card footer.
- **Route tests for static files and deep links**: added tests asserting `/atom.xml`, `/rss.xml`, and `/sitemap.xml` parse to `NotFound` (so modem lets the browser fetch them) and that deep post links parse to `Post(slug)`.
- **Search backdrop**: click outside the search modal to close it, via a CSS overlay backdrop rendered behind the modal.
- **Mobile menu**: hamburger button visible below 992px that toggles a vertical dropdown of nav links.
- **Tags menu item**: a "tags" entry added to the navbar for direct access to `/tags`.
- **Tags heading in sidebar**: a "Tags" label rendered above each post's tag list.
- **Link avatars**: optional `image` field on the `Link` type, rendered as a circular avatar on the links page.
- **Multi-level table of contents**: the ToC now parses `h2`, `h3`, and `h4` headings from the rendered HTML into a nested tree (previously single-level).
- **Bundle size analysis**: production bundle measured at 115 KB minified (32 KB gzipped), well-optimised for an SPA of this scope.
- Config: `mathjax_enabled` flag (default False) to enable/disable MathJax rendering.
- Optional font support documented: Maple Font and Sarasa Gothic.
- Post subheadings are now clickable with anchor links (`<a href="#id">`).
- Search now searches post body content (HTML stripped to plain text).
- **Search snippets**: search results show a context snippet (80 chars before/after the match).
- **Page jump input**: type a page number in the pagination bar and press Enter to jump straight to that page.
- **Mobile floating ToC button**: a bottom-right FAB on post pages (below 992px) opens a bottom-sheet overlay with the table of contents, so readers on small screens can still navigate the post outline.

### Changed

- Page-jump input: modernised with a visible border, rounded radius, and a `:focus` state that highlights with the accent colour; compact enough to slot into the pagination row.
- Post titles: font-weight 700 (bold) in post list.
- Floating overlay: Tags moved above ToC; duplicate "Table of Contents" heading removed.
- Standalone scroll-top FAB removed (replaced by in-overlay button).
- **Post title font-weight**: post titles now use font-weight 700 (was inherited 400) for clearer contrast with the 400-weight body text.
- **Project card tag chips**: `#tag` chips on project cards now use a 0.5rem gap, padding, and a rounded background for visual grouping.
- **Default fonts**: switched to system font stacks (`system-ui`, `-apple-system`, etc.) instead of bundled web fonts.
- **Navbar scaling**: larger navbar fonts and bigger icons — 28px social icons, 24px search/theme buttons.
- **CSS on-demand loading**: `dist/` now ships 10 separate CSS files under `dist/css/` rather than a single `arata.css`, so each page loads only the styles it needs.
- **CSS modular split**: source CSS reorganised into 10 modules under `src/css/` mirroring the runtime split.
- **CJK slugify**: replaced the ASCII allowlist with a punctuation denylist, so non-ASCII characters pass through into slugs.
- Sticky header navbar (position: sticky, always visible on scroll).
- Body font-weight reverted to 400 (normal) for a softer reading experience.
- Body text color: semi-transparent (`#F0F0F0DE` in dark, `#151515DE` in light) for less harsh contrast.
- Post content font-weight: 400 (distinct from the 700-weight title).
- Theme toggle: removed oval background; now a plain icon button with opacity hover.
- Default code font: `ui-monospace` system stack (no longer loads JetBrains Mono `@font-face`).
- Links page redesigned as cards with border, hover effect, and spacing.
- Search input auto-focuses when modal opens.
- Home page content updated with current features.
- Links page: card content no longer wrapped in `<a>` (`role=generic`); only the title is a link.
- Posts list: `post-header` changed from `<a>` to `<div>`; only the title is a link.
- Posts per page increased to 10 (was 7).
- Blockquote colour changed to `#3555b3` (was `#737373`).
- HR separator colour set to `#6c7086`.

### Fixed

- 404 flash: the SPA shell's `<div id="app">` now ships with a small loading indicator so deep-link refreshes show something meaningful instead of a white flash before `app.mjs` boots.
- Moon-icon: `filter: invert(1)` on `moon.svg` so the dark-theme state of the theme toggle is visible against the dark background (was a black glyph on dark).
- `text-1` color: light `#222222`, dark `#cccccc` (was `#666666` / `#999999`) — secondary text is now legible without squinting.
- Removed stray `/home/z/my-project/` absolute paths from `src/css/base.css` and `ROADMAP.md` (left over from local dev).
- Floating menu tags spacing: the Tags list inside the floating ToC overlay now uses pill-style chips with a `0.5rem` gap, padding, and a rounded background (was cramped with no gap).
- `toc-overlay-scroll-top`: `--primary-color` background with white text for contrast against the overlay (was nearly invisible).
- Deep link blank page: `index.html`/`404.html` now use absolute paths (`/app.mjs`, `/css/...`) instead of relative (`./app.mjs`). On `/posts/markdown`, `./app.mjs` resolved to `/posts/app.mjs` (404).
- Tags hidden on small screens: `.right-content .post-tags` now hides below 1365px, consistent with `.toc`.
- Auto-icon default style: `display:block; filter:invert(1)` (was `display:block` with no filter).
- All 2025 dates replaced with 2026.
- **Non-root page refresh (404 serves SPA shell)**: `404.html` now serves the SPA shell directly (same as `index.html`) — no redirect. modem reads the URL from the address bar and routes correctly, so deep-link refreshes load the right post and the URL is preserved. (Supersedes the earlier sessionStorage+redirect approach.)
- **ToC h4 headings**: `view_child` was not rendering children recursively, so any `h4` in a post silently dropped out of the ToC; the renderer now recurses so h2–h4 all appear. A test `h4` heading was added to a post to verify.
- **Theme toggle oval background**: added `appearance: none` to the theme toggle button to remove the user-agent default button styling, eliminating the residual oval background.
- **RSS icon 404 on sub-pages**: social links now use the absolute `/atom.xml` URL with `target=_blank` and `rel="noopener"` (was `rel="me"`); verified `/atom.xml` exists in `dist/`, so the feed icon resolves on every route.
- **Default theme icon visibility**: the `auto` icon is now visible by default; the `sun` and `moon` icons are hidden with `display: none`, so only the active state shows and the triple-icon flash on first paint is gone.
- **RSS/static file routing**: `/atom.xml`, `/rss.xml`, and `/sitemap.xml` are now matched before the `[slug]` catch-all, so feeds and the sitemap are served correctly.
- **CJK word count**: multi-byte characters (e.g. CJK ideographs) are now counted as individual words instead of being merged into a single run.
- **CJK heading IDs**: when a heading's slug is non-ASCII, a sequential fallback ID (`heading-1`, `heading-2`, …) is used so anchor links stay functional.
- **Links page layout**: `.link-item a` is now a flexbox row with proper avatar sizing and alignment.
- **ToC rendering**: `extract_toc_from_html` parsing bug fixed — heading IDs and titles are now extracted properly, so the ToC renders instead of being empty.
- **Cmd/Ctrl+K conflict**: `preventDefault` added so the shortcut no longer conflicts with the browser address bar's default Cmd/Ctrl+K behaviour.
- **Code font loading**: code font no longer loads JetBrains Mono via `@font-face`; defaults to the `ui-monospace` system stack.
- **Search scope**: search previously matched only title/description/tags; it now includes the post body too.

---

## [0.1.0] — 2026-06-22

The initial release of arata — a faithful reimplementation of the apollo blog theme using Gleam and Lustre.

### Added

- **Routing** (Phase 2): client-side routing via modem with 9 route variants (Home, Posts, Post, Projects, Talks, Tags, Tag, Page, NotFound) and paginated post index (`/posts/page/{n}`).
- **Design system** (Phase 1): the complete apollo visual design system ported from SCSS to plain CSS (2,135 lines) — colour palette, fonts, typography scale, 3-column layout, all component styles, syntax highlighting, 9 responsive breakpoints.
- **Post list** (Phase 5): paginated post list with Prev/Next pagination, draft labels, and active-nav highlighting.
- **Single post** (Phases 5-6): full article rendering with `.page-header` title, meta row (date, updated, word count, reading time), optional `tl;dr` box, body via `unsafe_raw_html`, tags, and a scroll-driven table of contents with IntersectionObserver active highlighting.
- **Projects** (Phase 7): column-balanced card grid with GitHub/Demo icon-buttons and `#tag` chips.
- **Talks** (Phase 7): responsive talk card grid with video thumbnails, play-button overlay, and meta row icon-buttons.
- **Taxonomy** (Phase 8): `/tags` index with post counts and `/tags/<tag>` single-tag pages.
- **Homepage** (Phase 9): custom landing page with hero section.
- **Standalone pages** (Phase 9): `/{slug}` pages (e.g. `/about`).
- **404** (Phase 9): apollo-style 404 page.
- **Theme system** (Phase 10): 3-state theme toggle (Light → Dark → Auto) with `localStorage` persistence and `matchMedia` reactivity.
- **Fancy code blocks** (Phase 11): copy-to-clipboard button and coloured language label on every `<pre><code>` block.
- **Search** (Phase 12): Cmd/Ctrl+K search modal with keyboard navigation (↑/↓ to navigate, Enter to follow, Esc to close).
- **Shortcodes** (Phase 13): note (static + dynamic), character, image, and mermaid shortcodes.
- **MathJax + Mermaid** (Phase 14): lazy-loaded MathJax typesetting and mermaid diagram rendering with theme-aware re-rendering.
- **SEO** (Phase 15): `<title>`, `<meta>` description, OpenGraph tags, Fediverse creator meta.
- **Feeds** (Phase 15): Atom 1.0 and RSS 2.0 feeds.
- **Sitemap** (Phase 15): `sitemap.xml` with all post + page URLs.
- **Analytics** (Phase 15): GoatCounter, Umami, and Google Analytics providers.
- **Comments** (Phase 15): Giscus and Utterances comment sections.
- **Wavy boundary** (Phase 16): a soft, SVG-based section divider (arata-original, not in apollo).
- **Build pipeline** (Phase 17): `gleam run -m build/pipeline` produces a complete static site in `dist/`.
- **Tests** (Phase 18): 57 unit tests covering routing, card reordering, tag index, search, and feed generation.
- **Accessibility** (Phase 18): `:focus-visible` styles for keyboard navigation.
- **Documentation** (Phase 19): configuration, content authoring, shortcode reference, and deployment guides.

### FFI modules

- `ffi/theme.ffi.mjs` — localStorage + matchMedia (theme toggle)
- `ffi/observer.ffi.mjs` — IntersectionObserver (TOC active highlighting)
- `ffi/codeblock.ffi.mjs` — code block enhancement (copy button + language label)
- `ffi/search.ffi.mjs` — global keydown listener (search shortcuts)
- `ffi/note.ffi.mjs` — note toggle (expand/collapse)
- `ffi/script.ffi.mjs` — MathJax + Mermaid loading and rendering
- `ffi/analytics.ffi.mjs` — analytics script injection

### Tech stack

- Gleam 1.14
- Lustre 5.7 (The Elm Architecture)
- modem 2.1 (client-side routing)
- gleam_json 3.1 (content index serialization)
- simplifile 2.4 (build pipeline file I/O)
- lustre_dev_tools 2.3 (dev server + bundling)
