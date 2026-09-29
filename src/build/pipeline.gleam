//// The build pipeline: orchestrates the content -> `dist/` build, replacing
//// Zola's role end-to-end.
////
//// Configuration is loaded exactly once from `content/arata.toml`, decoded,
//// resolved, and validated before `dist/` is created or modified.
////
//// Running `gleam run -m build/pipeline` produces a complete static site in
//// `dist/`:
////
////   1. Emits the JSON content index, search index, configured feeds, sitemap,
////      robots.txt, and llms.txt.
////   2. Bundles every CSS module under `src/css/` into `dist/css/arata.css`
////      with Bun's CSS bundler.
////   3. Emits index.html and 404.html with the bundled CSS inlined.
////   4. Copies all static assets from `static/` to `dist/`.
////   5. Compiles and bundles the Lustre SPA into `dist/app.mjs`.
////
//// Feed generation follows the resolved `FeedMode`:
////
////   - `Full` emits complete rendered post content;
////   - `Summary` emits post summaries;
////   - `Disabled` emits no feed artifacts and removes stale feed files.
////
//// Runtime-safe configuration is embedded in `content_index.json`. The browser
//// does not fetch `content/arata.toml` or a separate configuration file.

import build/feeds
import build/feeds_style
import build/head as build_head
import build/llms
import build/robots
import build/theme_bootstrap
import config
import config/decoder as config_decoder
import config/encoder as config_encoder
import config/error as config_error
import config/loader as config_loader
import config/raw.{type RawConfig, RawConfig}
import config/resolve as config_resolve
import config/runtime as config_runtime
import config/validate as config_validate
import content/loader as content_loader
import data/link.{type Link}
import data/page.{type Page}
import data/post.{type Post, type TocEntry}
import data/project.{type Project}
import data/site
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import simplifile

/// The output directory for the built site.
const dist_dir = "dist"

/// CSS modules bundled into `dist/css/arata.css` and inlined into the
/// generated HTML shells.
///
/// The order determines cascade precedence. Theme variables and global styles
/// must precede component styles, while accessibility overrides remain last.
/// This list is the single source of truth for stylesheet order: the Bun entry
/// file is generated from it at build time.
const css_modules = [
  "src/css/fonts.css",
  "src/css/theme.css",
  "src/css/globals.css",
  "src/css/typography.css",
  "src/css/home.css",
  "src/css/aratafetch.css",
  "src/css/layout.css",
  "src/css/components.css",
  "src/css/pagination.css",
  "src/css/post.css",
  "src/css/cards.css",
  "src/css/links.css",
  "src/css/search.css",
  "src/css/toc.css",
  "src/css/syntax.css",
  "src/css/lightbox.css",
  "src/css/accessibility.css",
]

/// Feed files managed by the build pipeline.
///
/// These files must be removed when feeds are disabled so a reused `dist/`
/// directory cannot expose stale feed output from an earlier build.
const feed_artifacts = [
  "atom.xml",
  "rss.xml",
  "atom.xsl",
  "rss.xsl",
]

/// The static assets directory.
const static_dir = "static"

/// The bundled stylesheet.
///
/// This is the single CSS artifact emitted to `dist/`. It is also inlined into
/// `index.html` and `404.html`, so the browser never requests it separately.
const css_bundle_path = "dist/css/arata.css"

/// Directory the generated Bun CSS entry file is written to.
///
/// The entry is a build artifact, so it lives under the gitignored `build/`
/// tree rather than in `src/`, mirroring the shim `bundle_spa/0` writes for the
/// JavaScript bundle.
const css_entry_dir = "build/dev/arata"

/// The generated Bun CSS entry file.
///
/// Bun merges multiple entry points into separate outputs rather than one
/// bundle, so a single entry that `@import`s every module in `css_modules`
/// order is required.
const css_entry_path = css_entry_dir <> "/entry.css"

/// Root-absolute `url()` references that Bun must not try to resolve.
///
/// `fonts.css` points at deployment-absolute font paths such as
/// `/fonts/SpaceGrotesk/SpaceGrotesk-Regular.ttf`. These are served from
/// `dist/fonts/` rather than imported from the module graph, so Bun is told to
/// leave them untouched instead of failing to resolve them as modules.
const css_external_urls = "/*"

/// Run the full build pipeline.
///
/// `run()` keeps build failures as typed `Error` values so tests and internal
/// callers can inspect them without terminating the process.
///
/// The executable entry point converts those errors into a panic. On the
/// JavaScript target this terminates `gleam run -m build/pipeline` with a
/// non-zero exit status, preventing CI, package scripts, and deployment chains
/// from treating an invalid configuration as a successful build.
pub fn main() -> Nil {
  case run() {
    Ok(_) -> Nil

    Error(message) -> panic as message
  }
}

/// Run the build pipeline.
///
/// Configuration is completely loaded and validated before the output
/// directory is created. Invalid configuration therefore cannot begin a new
/// build or overwrite existing build artifacts.
pub fn run() -> Result(Nil, String) {
  case load_configuration() {
    Error(message) -> Error(message)

    Ok(resolved) -> {
      let site_meta = config_resolve.site_meta(resolved)
      let site_config = config_resolve.runtime_config(resolved)
      let runtime_config = config_runtime.from_resolved(resolved)

      let posts = content_loader.load_posts()
      let projects = content_loader.load_projects()
      let links = content_loader.load_links()
      let pages = content_loader.load_pages()
      let homepage = content_loader.load_homepage()

      // Configuration has succeeded. Build output may now be written.
      let _ = simplifile.create_directory_all(dist_dir)

      // 1. Content index JSON.
      write(
        dist_dir <> "/content_index.json",
        content_index_json(
          runtime_config,
          posts,
          projects,
          links,
          pages,
          homepage,
        ),
      )

      // 2. Feeds and their browser-facing stylesheets.
      build_feeds(site_meta, site_config, posts)

      // 3. Sitemap.
      let page_slugs = list.map(pages, fn(page) { page.slug })

      write(
        dist_dir <> "/sitemap.xml",
        feeds.sitemap(site_meta, posts, page_slugs),
      )

      // 4. robots.txt.
      write(dist_dir <> "/robots.txt", robots.render(site_meta))

      // 5. llms.txt.
      write(
        dist_dir <> "/llms.txt",
        llms.render(site_meta, posts, projects, links, pages),
      )

      // 6. Bundled stylesheet. This must precede the HTML shells, which
      //    inline the bundle's contents.
      case bundle_css() {
        Error(message) -> Error(message)

        Ok(_) -> {
          // 7. Custom index.html with FOUC prevention.
          write(dist_dir <> "/index.html", index_html(site_meta, site_config))

          // 8. SPA shell for deep links.
          write(dist_dir <> "/404.html", not_found_html(site_meta, site_config))

          // 9. Static assets.
          copy_directory_contents(static_dir, dist_dir)

          // 10. Browser bundle.
          bundle_spa()

          print_build_summary(site_config.feed_mode)

          Ok(Nil)
        }
      }
    }
  }
}

/// Generate or remove feed artifacts according to the resolved feed mode.
///
/// `Full` and `Summary` both generate the standard Atom and RSS files. The
/// selected mode is passed to the feed renderer so it can choose between full
/// rendered HTML and summary-only entries.
///
/// `Disabled` removes all managed feed files. This is required because Arata
/// permits reuse of an existing `dist/` directory between builds.
fn build_feeds(
  site_meta: site.SiteMeta,
  site_config: config.Config,
  posts: List(Post),
) -> Nil {
  case site_config.feed_mode {
    config.Disabled -> remove_feed_artifacts()

    config.Full | config.Summary -> {
      let atom_xsl_href =
        config.with_base_path(site_config.base_path, "/atom.xsl")

      let rss_xsl_href =
        config.with_base_path(site_config.base_path, "/rss.xsl")

      write(
        dist_dir <> "/atom.xml",
        feeds.atom_feed(site_meta, posts, atom_xsl_href, site_config.feed_mode),
      )

      write(
        dist_dir <> "/rss.xml",
        feeds.rss_feed(site_meta, posts, rss_xsl_href, site_config.feed_mode),
      )

      write(dist_dir <> "/atom.xsl", feeds_style.atom_xsl())
      write(dist_dir <> "/rss.xsl", feeds_style.rss_xsl())
    }
  }
}

/// Remove generated feed files from a reused output directory.
///
/// Missing files are intentionally ignored: `simplifile.delete_all` does not
/// error when one or more of the given paths do not exist, so a first build
/// or a directory that never had feeds is a no-op. Deleting through
/// simplifile rather than shelling out to `rm` keeps this portable to targets
/// without a POSIX shell (e.g. native Windows builds), and receives only
/// fixed build-owned paths, never user-controlled values.
fn remove_feed_artifacts() -> Nil {
  let paths =
    list.map(feed_artifacts, fn(filename) { dist_dir <> "/" <> filename })

  let _ = simplifile.delete_all(paths)

  Nil
}

/// Load, decode, resolve, and validate Arata configuration exactly once.
///
/// A missing `content/arata.toml` resolves entirely from built-in defaults.
/// A present but unreadable or invalid file aborts the build.
fn load_configuration() -> Result(config_resolve.ResolvedConfig, String) {
  case config_loader.load() {
    Error(load_error) -> Error(config_error.render(load_error))

    Ok(None) ->
      resolve_and_validate(config_loader.default_path, empty_raw_config())

    Ok(Some(source)) ->
      case config_decoder.decode(source) {
        Error(errors) -> Error(config_error.render_all(errors))

        Ok(raw) -> resolve_and_validate(config_loader.path(source), raw)
      }
  }
}

/// Resolve and validate configuration while preserving the source path in all
/// diagnostics.
fn resolve_and_validate(
  source_path: String,
  raw: RawConfig,
) -> Result(config_resolve.ResolvedConfig, String) {
  case config_resolve.resolve_from(source_path, raw) {
    Error(errors) -> Error(config_error.render_all(errors))

    Ok(resolved) ->
      case config_validate.validate_from(source_path, resolved) {
        Error(errors) -> Error(config_error.render_all(errors))

        Ok(validated) -> Ok(validated)
      }
  }
}

/// Empty raw configuration used only when the optional TOML file is absent.
///
/// Every missing value is later populated by `config/defaults`.
fn empty_raw_config() -> RawConfig {
  RawConfig(
    site: None,
    menu: None,
    socials: None,
    features: None,
    latest_posts: None,
    posts: None,
    aratafetch: None,
    fonts: None,
    assets: None,
    syntax_highlight_grammars: None,
    analytics: None,
    comments: None,
  )
}

/// Print the build output summary.
fn print_build_summary(feed_mode: config.FeedMode) -> Nil {
  io.println("Build complete. dist/ contains:")
  io.println(
    "  app.mjs, index.html, 404.html, content_index.json, llms.txt, robots.txt, sitemap.xml,",
  )

  case feed_mode {
    config.Full ->
      io.println("  atom.xml, rss.xml, atom.xsl, rss.xsl (full content)")

    config.Summary ->
      io.println("  atom.xml, rss.xml, atom.xsl, rss.xsl (summaries)")

    config.Disabled -> io.println("")
  }

  io.println("  css/arata.css, fonts/*, icons/*, images/*")
}

/// Write content to a path.
fn write(path: String, content: String) -> Nil {
  let _ = simplifile.write(path, content)
  Nil
}

/// Bundle every CSS module in `css_modules` into `dist/css/arata.css`.
///
/// Bun's CSS bundler (Lightning CSS) replaces the previous hand-written
/// comment/whitespace stripper. That stripper applied its string replacements
/// inside quoted values too, so `content: " : "` collapsed to `":"` and
/// `grid-template-areas: "x  y"` lost its column alignment. Bun parses the
/// stylesheet properly and only rewrites tokens it understands.
///
/// Unlike the JavaScript bundle, a CSS bundle failure aborts the build. A
/// missing stylesheet ships an unstyled site silently, which is worse than a
/// non-zero exit status for CI and deployment chains to catch.
fn bundle_css() -> Result(Nil, String) {
  let assert Ok(_) = simplifile.create_directory_all(dist_dir <> "/css")

  let assert Ok(_) = simplifile.create_directory_all(css_entry_dir)

  let assert Ok(_) = simplifile.write(css_entry_path, css_entry_contents())

  let command =
    "bun build "
    <> css_entry_path
    <> " --outfile "
    <> css_bundle_path
    <> " --target=browser --minify --sourcemap=none"
    <> " --external '"
    <> css_external_urls
    <> "'"

  case run_command(command) {
    0 -> Ok(Nil)

    exit_code ->
      Error(
        "CSS bundle failed (exit "
        <> int.to_string(exit_code)
        <> "). Run `"
        <> command
        <> "` manually to debug.",
      )
  }
}

/// Build the Bun entry file from `css_modules`.
///
/// Bun emits one bundle per entry point, so the ordered `@import` list is what
/// collapses the modules into a single stylesheet. Generating it from
/// `css_modules` keeps the Gleam constant the only place cascade order is
/// declared.
///
/// Public so the generated file's shape can be asserted in tests: an `@import`
/// that no longer resolves, or one that is emitted twice, breaks the Bun
/// bundle step.
pub fn css_entry_contents() -> String {
  let prefix = css_entry_relative_prefix()

  css_modules
  |> list.map(fn(path) { "@import \"" <> prefix <> path <> "\";\n" })
  |> string.concat
}

/// Relative path from the generated entry file back to the project root.
///
/// `@import` URLs resolve against the importing stylesheet, so the
/// project-root-relative paths in `css_modules` need this prefix to stay valid
/// from `build/dev/arata/`. Deriving it from the entry directory keeps the two
/// constants consistent instead of hard-coding a `../` count.
fn css_entry_relative_prefix() -> String {
  let depth =
    css_entry_dir
    |> string.split("/")
    |> list.length

  string.repeat("../", depth)
}

/// Copy a single file, logging failures without stopping the build.
fn copy_file(src: String, dest: String) -> Nil {
  case simplifile.copy(src, dest) {
    Ok(_) -> Nil

    Error(file_error) -> {
      io.println(
        "Warning: could not copy " <> src <> ": " <> simplify_error(file_error),
      )

      Nil
    }
  }
}

/// Copy a directory's contents recursively into another directory.
///
/// `simplifile.copy_directory` copies the source directory itself. Arata needs
/// the contents of `static/` directly under `dist/`, so each entry is copied
/// individually.
fn copy_directory_contents(src: String, dest: String) -> Nil {
  case simplifile.read_directory(src) {
    Ok(entries) ->
      list.each(entries, fn(entry) {
        let src_path = src <> "/" <> entry
        let dest_path = dest <> "/" <> entry

        case simplifile.copy_directory(src_path, dest_path) {
          Ok(_) -> Nil

          Error(_) -> copy_file(src_path, dest_path)
        }
      })

    Error(file_error) ->
      io.println(
        "Warning: could not read " <> src <> ": " <> simplify_error(file_error),
      )
  }

  Nil
}

/// Compile the Gleam JavaScript and bundle it into `dist/app.mjs`.
///
/// The Gleam entry module exports `main()` but does not invoke it on the
/// JavaScript target, so a temporary entry shim performs the invocation.
fn bundle_spa() -> Nil {
  let shim = "import { main } from \"./arata.mjs\"; main();"
  let shim_path = "build/dev/javascript/arata/entry.mjs"
  let _ = simplifile.write(shim_path, shim)

  let command =
    "bun build "
    <> shim_path
    <> " --outfile "
    <> dist_dir
    <> "/app.mjs --target=browser --minify --sourcemap=none 2>/dev/null"

  case run_command(command) {
    0 -> Nil

    exit_code -> {
      io.println(
        "Warning: SPA bundle failed (exit "
        <> int.to_string(exit_code)
        <> "). Run `"
        <> command
        <> "` manually to debug.",
      )

      Nil
    }
  }
}

/// Convert a simplifile error to a readable string.
fn simplify_error(_error: simplifile.FileError) -> String {
  "file error"
}

@external(javascript, "../ffi/shell.ffi.mjs", "run_command")
fn run_command(command: String) -> Int

/// Serialize the complete content tree and browser-safe configuration.
///
/// Runtime configuration is embedded in this object so the browser retains
/// Arata's single-fetch startup model.
fn content_index_json(
  runtime_config: config_runtime.RuntimeConfig,
  posts: List(Post),
  projects: List(Project),
  links: List(Link),
  pages: List(Page),
  homepage: Page,
) -> String {
  let posts_array =
    json.array(posts, fn(post) {
      json.object([
        #("slug", json.string(post.slug)),
        #("title", json.string(post.title)),
        #("date", json.string(post.date)),
        #("updated", case post.updated {
          Some(value) -> json.string(value)
          None -> json.null()
        }),
        #("description", json.string(post.description)),
        #("body", json.string(post.body)),
        #("toc", json.array(post.toc, toc_entry_json)),
        #("tags", json.array(post.tags, json.string)),
        #("draft", json.bool(post.draft)),
        #("pinned", json.bool(post.pinned)),
        #("tldr", case post.tldr {
          Some(value) -> json.string(value)
          None -> json.null()
        }),
        #("word_count", json.int(post.word_count)),
        #("reading_time", json.int(post.reading_time)),
      ])
    })

  let projects_array = json.array(projects, project_json)

  let links_array =
    json.array(links, fn(link) {
      json.object([
        #("title", json.string(link.title)),
        #("url", json.string(link.url)),
        #("description", json.string(link.description)),
        #("image", option_to_json(link.image)),
        #("weight", json.int(link.weight)),
      ])
    })

  let pages_array = json.array(pages, page_json)

  let homepage_object = page_json(homepage)

  json.object([
    #("config", config_encoder.to_json(runtime_config)),
    #("posts", posts_array),
    #("projects", projects_array),
    #("links", links_array),
    #("pages", pages_array),
    #("homepage", homepage_object),
  ])
  |> json.to_string
}

/// Serialize a project.
fn project_json(project: Project) -> json.Json {
  json.object([
    #("slug", json.string(project.slug)),
    #("title", json.string(project.title)),
    #("description", json.string(project.description)),
    #("link_to", option_to_json(project.link_to)),
    #("image", option_to_json(project.image)),
    #("github", option_to_json(project.github)),
    #("gitlab", option_to_json(project.gitlab)),
    #("codeberg", option_to_json(project.codeberg)),
    #("forgejo", option_to_json(project.forgejo)),
    #("demo", option_to_json(project.demo)),
    #("tags", json.array(project.tags, json.string)),
  ])
}

/// Serialize a standalone page or homepage.
fn page_json(page: Page) -> json.Json {
  json.object([
    #("slug", json.string(page.slug)),
    #("title", json.string(page.title)),
    #("body", json.string(page.body)),
    #("subtitle", option_to_json(page.subtitle)),
  ])
}

/// Serialize an optional string.
fn option_to_json(value: option.Option(String)) -> json.Json {
  case value {
    Some(string_value) -> json.string(string_value)

    None -> json.null()
  }
}

/// Serialize a table-of-contents entry.
fn toc_entry_json(entry: TocEntry) -> json.Json {
  json.object([
    #("level", json.int(entry.level)),
    #("id", json.string(entry.id)),
    #("title", json.string(entry.title)),
    #("children", json.array(entry.children, toc_entry_json)),
  ])
}

/// Read the bundled stylesheet for inlining into the HTML shell.
///
/// `bundle_css/0` has already written `css_bundle_path` by the time the shells
/// are generated, so the inline copy and `dist/css/arata.css` are guaranteed to
/// be the same bytes.
fn inline_css() -> String {
  case simplifile.read(css_bundle_path) {
    Ok(css) -> sanitize_style_text(css)

    Error(file_error) -> {
      // Unreachable in practice: `bundle_css/0` aborts the build when the
      // bundle cannot be written. Rendering unstyled beats aborting here,
      // where the failure would be much harder to trace back to its cause.
      io.println(
        "Warning: could not read "
        <> css_bundle_path
        <> ": "
        <> simplify_error(file_error),
      )

      ""
    }
  }
}

/// Prevent CSS content from terminating the generated inline style element.
fn sanitize_style_text(css: String) -> String {
  css
  |> string.replace("</style", "<\\/style")
}

/// Generate the SPA HTML shell.
///
/// Feed metadata is emitted for both `Full` and `Summary` modes. Asset paths
/// are resolved from the configuration-derived deployment base path.
///
/// The shell carries a synchronous theme bootstrap in `<head>` (before the
/// main CSS) so an explicit persisted `light`/`dark` preference is applied
/// before the first visible paint, instead of flashing the system theme.
pub fn index_html(
  site_meta: site.SiteMeta,
  site_config: config.Config,
) -> String {
  let base_path = site_config.base_path
  let atom_href = config.with_base_path(base_path, "/atom.xml")
  let rss_href = config.with_base_path(base_path, "/rss.xml")
  let app_src = config.with_base_path(base_path, "/app.mjs")
  let bootstrap_meta = "<meta name='arata-base-path' content='" <> base_path

  // Configured favicon paths have already been resolved by the configuration
  // resolver. Only the fallback path needs a deployment prefix here.
  let favicon = case site_config.favicon {
    Some(path) -> path
    None -> config.with_base_path(base_path, "/icon/favicon.png")
  }

  let feed_links = case site_config.feed_mode {
    config.Full | config.Summary ->
      "<link rel='alternate' type='application/atom+xml' title='Atom Feed' href='"
      <> atom_href
      <> "'><link rel='alternate' type='application/rss+xml' title='RSS Feed' href='"
      <> rss_href
      <> "'>"

    config.Disabled -> ""
  }

  let css = inline_css()

  // The shell is a single page, so it only carries site-level SEO metadata.
  // `og:url` needs the deployment prefix, so the base path is used as the path.
  let head =
    build_head.head_metadata(site_meta, None, None, base_path <> "/", [])

  "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'>"
  <> theme_bootstrap.html_script()
  <> head
  <> bootstrap_meta
  <> "'><link rel='icon' href='"
  <> favicon
  <> "'>"
  <> feed_links
  <> "<style id='arata-css'>"
  <> css
  <> "</style></head><body><div id='app'><div style='position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:var(--bg-0);color:var(--text-1);font-family:sans-serif;'>Loading…</div></div><script type='module' src='"
  <> app_src
  <> "'></script></body></html>"
}

/// Generate the deep-link fallback shell.
fn not_found_html(
  site_meta: site.SiteMeta,
  site_config: config.Config,
) -> String {
  index_html(site_meta, site_config)
}
