//// The build pipeline: orchestrates the content → `dist/` build, replacing
//// Zola's role end-to-end.
////
//// Running `gleam run -m build/pipeline` produces a complete static site in
//// `dist/`:
////   1. Emits the JSON content index, search index, feeds, sitemap, robots.txt,
////      a custom `index.html` with FOUC prevention, and a `404.html` that
////      serves the SPA shell directly.
////   2. Copies each CSS module under `src/css/` to `dist/css/`.
////   3. Copies all static assets from `static/` to `dist/`.
////   4. Compiles the Gleam JavaScript and bundles it into `dist/app.mjs`.
////
//// The content source is the `.md` files under `content/` (loaded by
//// `content/loader`), serialized to `content_index.json` for the SPA to
//// fetch at runtime.

import build/feeds
import build/llms
import build/robots
import content/loader
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

/// The CSS modules that are copied, in order, to `dist/css/` as separate
/// files. `base.css` must come first (theme variables + resets); the rest
/// follow the dependency order so cascade specificity resolves as intended.
/// The `<link>` tags in `index.html` reference each file in this same order.
const css_modules = [
  "src/css/base.css",
  "src/css/layout.css",
  "src/css/components.css",
  "src/css/post.css",
  "src/css/cards.css",
  "src/css/links.css",
  "src/css/search.css",
  "src/css/toc.css",
  "src/css/syntax.css",
  "src/css/accessibility.css",
]

/// The static assets directory.
const static_dir = "static"

/// Run the full build pipeline.
pub fn main() -> Nil {
  let assert Ok(_) = run()
  Nil
}

/// Run the build pipeline, returning a result.
pub fn run() -> Result(Nil, String) {
  let site_meta = site.default()
  let posts = loader.load_posts()
  let projects = loader.load_projects()
  let links = loader.load_links()
  let pages = loader.load_pages()
  let homepage = loader.load_homepage()

  // Ensure the dist directory exists.
  let _ = simplifile.create_directory_all(dist_dir)

  // 1. Content index JSON.
  write(
    dist_dir <> "/content_index.json",
    content_index_json(site_meta, posts, projects, links, pages, homepage),
  )

  // 2. Search index JSON.
  write(dist_dir <> "/search_index.json", search_index_json(posts))

  // 3. Feeds. Only emit `atom.xml` / `rss.xml` when RSS is enabled in the
  // site metadata; otherwise the feed files are skipped. This mirrors
  // blogatto's opt-out feed model.
  case site_meta.rss_enabled {
    True -> {
      write(dist_dir <> "/atom.xml", feeds.atom_feed(site_meta, posts))
      write(dist_dir <> "/rss.xml", feeds.rss_feed(site_meta, posts))
    }
    False -> Nil
  }

  // 4. Sitemap.
  let page_slugs = list.map(pages, fn(p) { p.slug })
  write(dist_dir <> "/sitemap.xml", feeds.sitemap(site_meta, posts, page_slugs))

  // 5. robots.txt.
  write(dist_dir <> "/robots.txt", robots.render(site_meta))

  // 6. llms.txt.
  //
  // Must be a real Markdown file in dist/. Lighthouse/PageSpeed expects at
  // least one H1 and at least one Markdown link.
  write(
    dist_dir <> "/llms.txt",
    llms.render(site_meta, posts, projects, links, pages),
  )

  // 7. Custom index.html with FOUC prevention.
  write(dist_dir <> "/index.html", index_html(site_meta))

  // 8. 404.html — the SPA shell (same content as index.html). Static hosts
  // that serve 404.html for unknown paths load the SPA directly; the SPA's
  // modem reads `window.location.pathname` and the router handles the deep
  // link, no redirect needed (preserves the URL).
  write(dist_dir <> "/404.html", not_found_html(site_meta))

  // 9. Copy each CSS module from src/css/ to dist/css/ as a separate file.
  build_css()

  // 10. Copy all static assets (fonts, icons, images, vendored CSS) to dist/.
  copy_directory_contents(static_dir, dist_dir)

  // 11. Compile the Gleam JavaScript and bundle into dist/app.mjs.
  bundle_spa()

  io.println("Build complete. dist/ contains:")
  io.println("  index.html, 404.html, app.mjs,")
  io.println("  content_index.json, search_index.json,")
  case site_meta.rss_enabled {
    True -> io.println("  atom.xml, rss.xml, sitemap.xml, robots.txt,")
    False -> io.println("  sitemap.xml, robots.txt, (feeds disabled)")
  }
  io.println("  fonts/, icons/, images/, css/")

  Ok(Nil)
}

/// Write `content` to `path`.
fn write(path: String, content: String) -> Nil {
  let _ = simplifile.write(path, content)
  Nil
}

/// Copy each CSS module listed in `css_modules` to `dist/css/` as a separate
/// file (true on-demand loading). Each file is loaded by its own `<link>` tag
/// in `index.html`, so the browser can fetch them in parallel and cache them
/// independently. A missing module is logged but does not abort the build.
fn build_css() -> Nil {
  let _ = simplifile.create_directory_all(dist_dir <> "/css")

  list.each(css_modules, fn(path) {
    let filename =
      path
      |> string.split("/")
      |> list.last
      |> result.unwrap("unknown.css")

    case simplifile.copy(path, dist_dir <> "/css/" <> filename) {
      Ok(_) -> Nil
      Error(e) ->
        io.println(
          "Warning: could not copy CSS module "
          <> path
          <> ": "
          <> simplify_error(e),
        )
    }
  })

  Nil
}

/// Copy a single file, logging on error.
fn copy_file(src: String, dest: String) -> Nil {
  case simplifile.copy(src, dest) {
    Ok(_) -> Nil
    Error(e) -> {
      io.println("Warning: could not copy " <> src <> ": " <> simplify_error(e))
      Nil
    }
  }
}

/// Copy the contents of a directory recursively. `simplifile.copy_directory`
/// copies the directory itself (creating `dest/src/`); we want the contents
/// at `dest/`, so we read and copy each entry.
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

    Error(e) ->
      io.println("Warning: could not read " <> src <> ": " <> simplify_error(e))
  }

  Nil
}

/// Compile the Gleam JavaScript and bundle it into `dist/app.mjs` using
/// `bun build`. This replaces `lustre/dev build` (which requires Erlang/OTP).
/// `gleam build` must have already run (it does as part of `gleam run`).
///
/// The Gleam entry module (`arata.mjs`) exports `main()` but does not call it
/// on the JavaScript target. We write a small temporary entry shim that imports
/// and invokes `main()`, then bundle that.
fn bundle_spa() -> Nil {
  let shim = "import { main } from \"./arata.mjs\"; main();"
  let shim_path = "build/dev/javascript/arata/entry.mjs"
  let _ = simplifile.write(shim_path, shim)

  let cmd =
    "bun build "
    <> shim_path
    <> " --outfile "
    <> dist_dir
    <> "/app.mjs --minify --target=browser 2>/dev/null"

  case run_command(cmd) {
    0 -> Nil
    code -> {
      io.println(
        "Warning: SPA bundle failed (exit "
        <> int.to_string(code)
        <> "). Run `"
        <> cmd
        <> "` manually to debug.",
      )
      Nil
    }
  }
}

/// Convert a simplifile FileError to a readable string.
fn simplify_error(_e: simplifile.FileError) -> String {
  "file error"
}

@external(javascript, "../ffi/shell.ffi.mjs", "run_command")
fn run_command(command: String) -> Int

/// The content index JSON: the full content tree serialized for the SPA to
/// consume.
fn content_index_json(
  site_meta: site.SiteMeta,
  posts: List(Post),
  projects: List(Project),
  links: List(Link),
  pages: List(Page),
  homepage: Page,
) -> String {
  let config_obj =
    json.object([
      #("title", json.string(site_meta.title)),
      #("description", json.string(site_meta.description)),
      #("base_url", json.string(site_meta.base_url)),
    ])

  let posts_arr =
    json.array(posts, fn(post) {
      json.object([
        #("slug", json.string(post.slug)),
        #("title", json.string(post.title)),
        #("date", json.string(post.date)),
        #("updated", case post.updated {
          Some(s) -> json.string(s)
          None -> json.null()
        }),
        #("description", json.string(post.description)),
        #("body", json.string(post.body)),
        #("toc", json.array(post.toc, toc_entry_json)),
        #("tags", json.array(post.tags, json.string)),
        #("draft", json.bool(post.draft)),
        #("tldr", case post.tldr {
          Some(s) -> json.string(s)
          None -> json.null()
        }),
        #("word_count", json.int(post.word_count)),
        #("reading_time", json.int(post.reading_time)),
      ])
    })

  let projects_arr = json.array(projects, fn(project) { project_json(project) })

  let links_arr =
    json.array(links, fn(link) {
      json.object([
        #("title", json.string(link.title)),
        #("url", json.string(link.url)),
        #("description", json.string(link.description)),
        #("image", option_to_json(link.image)),
      ])
    })

  let pages_arr =
    json.array(pages, fn(page) {
      json.object([
        #("slug", json.string(page.slug)),
        #("title", json.string(page.title)),
        #("body", json.string(page.body)),
        #("subtitle", case page.subtitle {
          Some(s) -> json.string(s)
          None -> json.null()
        }),
      ])
    })

  let home_obj =
    json.object([
      #("slug", json.string(homepage.slug)),
      #("title", json.string(homepage.title)),
      #("body", json.string(homepage.body)),
      #("subtitle", case homepage.subtitle {
        Some(s) -> json.string(s)
        None -> json.null()
      }),
    ])

  json.to_string(
    json.object([
      #("config", config_obj),
      #("posts", posts_arr),
      #("projects", projects_arr),
      #("links", links_arr),
      #("pages", pages_arr),
      #("homepage", home_obj),
    ]),
  )
}

/// Serialize a `Project` as `{slug, title, description, link_to, image,
/// github, gitlab, codeberg, forgejo, demo, tags}`. Optional fields are
/// emitted as JSON `null` when `None`.
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

fn option_to_json(opt: option.Option(String)) -> json.Json {
  case opt {
    Some(s) -> json.string(s)
    None -> json.null()
  }
}

/// Serialize a `TocEntry` as `{"id": ..., "title": ..., "children": [...]}`.
fn toc_entry_json(entry: TocEntry) -> json.Json {
  json.object([
    #("id", json.string(entry.id)),
    #("title", json.string(entry.title)),
    #("children", json.array(entry.children, toc_entry_json)),
  ])
}

/// The search index JSON: a simple array of searchable documents.
fn search_index_json(posts: List(Post)) -> String {
  json.to_string(
    json.array(posts, fn(post) {
      json.object([
        #("title", json.string(post.title)),
        #("description", json.string(post.description)),
        #("tags", json.string(string.join(post.tags, " "))),
        #("url", json.string("/posts/" <> post.slug)),
      ])
    }),
  )
}

/// The custom `index.html` with FOUC prevention: both `light` and `dark`
/// classes on `<html>`, CSS modules loaded in order, and the SPA script.
///
/// Feed `<link rel='alternate'>` tags are only emitted when
/// `site_meta.rss_enabled` is `True`.
///
/// All asset paths are absolute (`/app.mjs`, `/css/...`, `/icon/...`) rather
/// than relative (`./app.mjs`). On a deep link like `/posts/markdown`, the
/// static host serves 404.html, and relative assets would resolve incorrectly.
fn index_html(site_meta: site.SiteMeta) -> String {
  let feed_links = case site_meta.rss_enabled {
    True ->
      "  <link rel='alternate' type='application/atom+xml' href='/atom.xml'>
  <link rel='alternate' type='application/rss+xml' href='/rss.xml'>
"
    False -> ""
  }

  "<!DOCTYPE html>
<html lang='en' class='dark light'>
<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <title>" <> site_meta.title <> "</title>
  <meta name='description' content='" <> site_meta.description <> "'>
  <link rel='icon' type='image/png' href='/icon/favicon.png'>
" <> feed_links <> "  <link rel='stylesheet' href='/css/base.css'>
  <link rel='stylesheet' href='/css/layout.css'>
  <link rel='stylesheet' href='/css/components.css'>
  <link rel='stylesheet' href='/css/post.css'>
  <link rel='stylesheet' href='/css/cards.css'>
  <link rel='stylesheet' href='/css/links.css'>
  <link rel='stylesheet' href='/css/search.css'>
  <link rel='stylesheet' href='/css/toc.css'>
  <link rel='stylesheet' href='/css/syntax.css'>
  <link rel='stylesheet' href='/css/accessibility.css'>
</head>
<body>
  <div id='app'><div style='position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:var(--bg-0);color:var(--text-1);font-family:sans-serif;'>Loading…</div></div>
  <script type='module' src='/app.mjs'></script>
</body>
</html>"
}

/// The 404.html page: the SPA shell, identical to `index.html`.
fn not_found_html(site_meta: site.SiteMeta) -> String {
  index_html(site_meta)
}
