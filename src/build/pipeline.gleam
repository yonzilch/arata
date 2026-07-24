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
////      robots.txt, llms.txt, index.html, and 404.html.
////   2. Copies each CSS module under `src/css/` to `dist/css/`.
////   3. Copies all static assets from `static/` to `dist/`.
////   4. Compiles and bundles the Lustre SPA into `dist/app.mjs`.
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
import build/llms
import build/robots
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
import gleam/result
import gleam/string
import simplifile

/// The output directory for the built site.
const dist_dir = "dist"

/// CSS modules copied to `dist/css/` and inlined into generated HTML shells.
///
/// The order determines cascade precedence. Theme variables and global styles
/// must precede component styles, while accessibility overrides remain last.
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

      // 2. Search index JSON.
      write(
        dist_dir <> "/search_index.json",
        search_index_json(site_config, posts),
      )

      // 3. Feeds and their browser-facing stylesheets.
      build_feeds(site_meta, site_config, posts)

      // 4. Sitemap.
      let page_slugs = list.map(pages, fn(page) { page.slug })

      write(
        dist_dir <> "/sitemap.xml",
        feeds.sitemap(site_meta, posts, page_slugs),
      )

      // 5. robots.txt.
      write(dist_dir <> "/robots.txt", robots.render(site_meta))

      // 6. llms.txt.
      write(
        dist_dir <> "/llms.txt",
        llms.render(site_meta, posts, projects, links, pages),
      )

      // 7. Custom index.html with FOUC prevention.
      write(dist_dir <> "/index.html", index_html(site_meta, site_config))

      // 8. SPA shell for deep links.
      write(dist_dir <> "/404.html", not_found_html(site_meta, site_config))

      // 9. Debug/inspection CSS modules.
      build_css()

      // 10. Static assets.
      copy_directory_contents(static_dir, dist_dir)

      // 11. Browser bundle.
      bundle_spa()

      print_build_summary(site_config.feed_mode)

      Ok(Nil)
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
    aratafetch: None,
    fonts: None,
    assets: None,
    analytics: None,
    comments: None,
  )
}

/// Print the build output summary.
fn print_build_summary(feed_mode: config.FeedMode) -> Nil {
  io.println("Build complete. dist/ contains:")
  io.println("  index.html, 404.html, app.mjs,")
  io.println("  content_index.json, search_index.json,")

  case feed_mode {
    config.Full ->
      io.println(
        "  atom.xml, rss.xml, atom.xsl, rss.xsl (full content), sitemap.xml, robots.txt,",
      )

    config.Summary ->
      io.println(
        "  atom.xml, rss.xml, atom.xsl, rss.xsl (summaries), sitemap.xml, robots.txt,",
      )

    config.Disabled -> io.println("  sitemap.xml, robots.txt, (feeds disabled)")
  }

  io.println("  llms.txt, fonts/, icons/, images/, css/")
}

/// Write content to a path.
fn write(path: String, content: String) -> Nil {
  let _ = simplifile.write(path, content)
  Nil
}

/// Copy and minify each CSS module into `dist/css/`.
///
/// The inline shell CSS uses the same minification path so generated HTML and
/// inspection CSS remain consistent.
fn build_css() -> Nil {
  let _ = simplifile.create_directory_all(dist_dir <> "/css")

  list.each(css_modules, fn(path) {
    let filename =
      path
      |> string.split("/")
      |> list.last
      |> result.unwrap("unknown.css")

    case simplifile.read(path) {
      Ok(css) -> write(dist_dir <> "/css/" <> filename, minify_css(css))

      Error(file_error) ->
        io.println(
          "Warning: could not read CSS module "
          <> path
          <> ": "
          <> simplify_error(file_error),
        )
    }
  })

  Nil
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
    #("id", json.string(entry.id)),
    #("title", json.string(entry.title)),
    #("children", json.array(entry.children, toc_entry_json)),
  ])
}

/// Serialize the search index.
///
/// The already-resolved site configuration is passed explicitly so this
/// function cannot independently load defaults or configuration.
fn search_index_json(site_config: config.Config, posts: List(Post)) -> String {
  posts
  |> json.array(fn(post) {
    json.object([
      #("title", json.string(post.title)),
      #("description", json.string(post.description)),
      #("tags", json.string(string.join(post.tags, " "))),
      #(
        "url",
        json.string(config.with_base_path(
          site_config.base_path,
          "/posts/" <> post.slug,
        )),
      ),
    ])
  })
  |> json.to_string
}

/// Read, minify, and concatenate CSS modules for the HTML shell.
fn inline_css() -> String {
  css_modules
  |> list.map(fn(path) {
    case simplifile.read(path) {
      Ok(css) ->
        css
        |> minify_css
        |> sanitize_style_text

      Error(_) -> ""
    }
  })
  |> string.join("")
}

/// Prevent CSS content from terminating the generated inline style element.
fn sanitize_style_text(css: String) -> String {
  css
  |> string.replace("</style", "<\\/style")
}

type CssScanState {
  CssOutside
  CssComment
  CssString(quote: String, escaped: Bool)
}

/// Minify CSS while preserving quoted strings.
fn minify_css(css: String) -> String {
  css
  |> strip_css_comments
  |> collapse_css_whitespace
  |> trim_css_spaces_around_tokens
  |> string.trim
}

fn strip_css_comments(css: String) -> String {
  css
  |> string.to_graphemes
  |> strip_css_comments_loop(CssOutside, [])
  |> list.reverse
  |> string.join("")
}

fn strip_css_comments_loop(
  chars: List(String),
  state: CssScanState,
  acc: List(String),
) -> List(String) {
  case chars {
    [] -> acc

    [char, ..rest] ->
      case state {
        CssOutside ->
          case char {
            "/" ->
              case rest {
                ["*", ..tail] -> strip_css_comments_loop(tail, CssComment, acc)

                _ -> strip_css_comments_loop(rest, CssOutside, [char, ..acc])
              }

            "\"" ->
              strip_css_comments_loop(rest, CssString("\"", False), [
                char,
                ..acc
              ])

            "'" ->
              strip_css_comments_loop(rest, CssString("'", False), [char, ..acc])

            _ -> strip_css_comments_loop(rest, CssOutside, [char, ..acc])
          }

        CssComment ->
          case char {
            "*" ->
              case rest {
                ["/", ..tail] -> strip_css_comments_loop(tail, CssOutside, acc)

                _ -> strip_css_comments_loop(rest, CssComment, acc)
              }

            _ -> strip_css_comments_loop(rest, CssComment, acc)
          }

        CssString(quote, escaped) -> {
          let next_state = case escaped {
            True -> CssString(quote, False)

            False ->
              case char {
                "\\" -> CssString(quote, True)

                _ ->
                  case char == quote {
                    True -> CssOutside
                    False -> CssString(quote, False)
                  }
              }
          }

          strip_css_comments_loop(rest, next_state, [char, ..acc])
        }
      }
  }
}

fn collapse_css_whitespace(css: String) -> String {
  css
  |> string.replace("\r\n", "\n")
  |> string.replace("\r", "\n")
  |> string.replace("\n", " ")
  |> string.replace("\t", " ")
  |> collapse_repeated_spaces
}

fn collapse_repeated_spaces(css: String) -> String {
  let compacted = string.replace(css, "  ", " ")

  case compacted == css {
    True -> compacted

    False -> collapse_repeated_spaces(compacted)
  }
}

fn trim_css_spaces_around_tokens(css: String) -> String {
  css
  |> string.replace(" {", "{")
  |> string.replace("{ ", "{")
  |> string.replace(" }", "}")
  |> string.replace("} ", "}")
  |> string.replace(" :", ":")
  |> string.replace(": ", ":")
  |> string.replace(" ;", ";")
  |> string.replace("; ", ";")
  |> string.replace(" ,", ",")
  |> string.replace(", ", ",")
  |> string.replace(" >", ">")
  |> string.replace("> ", ">")
  |> string.replace("( ", "(")
  |> string.replace(" )", ")")
}

/// Generate the SPA HTML shell.
///
/// Feed metadata is emitted for both `Full` and `Summary` modes. Asset paths
/// are resolved from the configuration-derived deployment base path.
fn index_html(site_meta: site.SiteMeta, site_config: config.Config) -> String {
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

  "<!DOCTYPE html><html lang='en' class='dark light'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>"
  <> site_meta.title
  <> "</title><meta name='description' content='"
  <> site_meta.description
  <> "'>"
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
