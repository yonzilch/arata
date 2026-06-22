//// arata — a faithful reimplementation of the apollo blog theme using Gleam
//// and the Lustre framework.
////
//// This module is the application entry point. It boots a `lustre.application`
//// SPA with client-side routing via `modem`: the `init` function reads the
//// initial URI and subscribes to navigation events, the `update` function
//// stores the current `Route` in the model, and the `view` function dispatches
//// to a per-route view wrapped in the apollo 3-column shell.
////
//// The `/posts` index and `/posts/{slug}` single-post routes are fully wired
//// (Phase 5): the list paginates the sample content, and a single post renders
//// its title, meta, body, and tags. The remaining routes (home, projects,
//// talks, tags, standalone pages) still render `.page-header` placeholders
//// pending Phases 7-9.

import config
import data/post.{type Post}
import data/sample_content
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import modem
import route.{
  type Route, Home, NotFound, Page, Post, Posts, Projects, Tag, Tags, Talks,
}
import view/footer
import view/header
import view/layout
import view/post as post_view
import view/post_list

// MAIN ------------------------------------------------------------------------

/// Number of posts per page on the post list. With 4 sample posts and a page
/// size of 3, page 1 shows 3 posts + a Next link, and page 2 shows 1 post +
/// a Prev link — exercising both pagination states with the sample data.
const posts_per_page = 3

/// Boot the Lustre application and mount it onto the `#app` element rendered
/// by the Lustre HTML tool's generated `index.html`.
pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(route: Route, config: config.Config, posts: List(Post))
}

fn init(_flags: Nil) -> #(Model, effect.Effect(Msg)) {
  // The server for a typical SPA serves the same `index.html` for every URL;
  // modem stores the first URL so we can parse it for the initial route.
  let initial_route = case modem.initial_uri() {
    Ok(uri) -> route.parse_route(uri)
    Error(_) -> Home
  }
  let model =
    Model(
      route: initial_route,
      config: config.default(),
      posts: sample_content.posts(),
    )

  // Initialise modem so internal `<a>` clicks are intercepted and dispatched
  // as `UserNavigatedTo` messages instead of triggering a full page reload.
  let nav_effect =
    modem.init(fn(uri) { uri |> route.parse_route |> UserNavigatedTo })

  #(model, nav_effect)
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UserNavigatedTo(route: Route)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserNavigatedTo(route) -> #(Model(..model, route:), effect.none())
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let main_content = case model.route {
    Home -> view_home()
    Posts(page) -> post_list.view(model.posts, page, posts_per_page)
    Post(slug) ->
      case post.find_by_slug(model.posts, slug) {
        Ok(found) -> post_view.view(found)
        Error(Nil) -> view_not_found()
      }
    Projects -> view_projects()
    Talks -> view_talks()
    Tags -> view_tags()
    Tag(name) -> view_tag(name)
    Page(slug) -> view_page(slug)
    NotFound(_) -> view_not_found()
  }

  layout.view([
    header.view(model.config, model.route),
    main_content,
    footer.view(model.config),
  ])
}

// PLACEHOLDER PAGE VIEWS ------------------------------------------------------
//
// Each route renders a minimal placeholder so the Phase 1 CSS (which targets
// `.page-header` and `.not-found-header`) styles the shell. Full rendering is
// Phases 4–6: post lists, single posts, projects grid, talks grid, tag lists,
// and standalone pages.

fn view_home() -> Element(Msg) {
  page_main("Home")
}

fn view_projects() -> Element(Msg) {
  page_main("Projects")
}

fn view_talks() -> Element(Msg) {
  page_main("Talks")
}

fn view_tags() -> Element(Msg) {
  page_main("Tags")
}

fn view_tag(name: String) -> Element(Msg) {
  page_main("Tag: " <> name)
}

fn view_page(slug: String) -> Element(Msg) {
  page_main(slug)
}

fn view_not_found() -> Element(Msg) {
  // Mirrors apollo's `404.html`: a `<main class="not-found-header">` containing
  // a `.page-header` "404" and a "Page not found :(" span.
  html.main([attribute.class("not-found-header")], [
    html.div([attribute.class("page-header")], [html.text("404")]),
    html.span([], [html.text("Page not found :(")]),
  ])
}

/// A `<main>` containing a single `.page-header` — the common placeholder
/// shape for section/list/standalone routes.
fn page_main(title: String) -> Element(Msg) {
  html.main([], [
    html.div([attribute.class("page-header")], [html.text(title)]),
  ])
}
