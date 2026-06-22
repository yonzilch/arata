//// arata — a faithful reimplementation of the apollo blog theme using Gleam
//// and the Lustre framework.
////
//// This module is the application entry point. It boots a `lustre.application`
//// SPA with client-side routing via `modem`: the `init` function reads the
//// initial URI and subscribes to navigation events, the `update` function
//// stores the current `Route` in the model, and the `view` function dispatches
//// to a per-route view wrapped in the apollo 3-column shell.
////
//// All routes are now fully wired (Phases 5-9): /posts (paginated list),
//// /posts/{slug} (single post with TOC), /projects (card grid), /talks (talk
//// grid), /tags (tag index), /tags/{name} (single tag), / (homepage), and
//// /{slug} (standalone pages). A single post also renders a scroll-driven
//// table of contents in the `.right-content` sidebar with IntersectionObserver
//// active highlighting.

import config
import data/page.{type Page}
import data/post.{type Post}
import data/project.{type Project}
import data/sample_content
import data/talk.{type Talk}
import effect/toc as toc_effect
import gleam/option.{type Option}
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element, none}
import lustre/element/html
import modem
import route.{
  type Route, Home, NotFound, Page, Post, Posts, Projects, Tag, Tags, Talks,
}
import view/cards
import view/footer
import view/header
import view/home as home_view
import view/layout
import view/page as page_view
import view/post as post_view
import view/post_list
import view/tags
import view/talks
import view/toc as toc_view

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
  Model(
    route: Route,
    config: config.Config,
    posts: List(Post),
    projects: List(Project),
    talks: List(Talk),
    homepage: Page,
    pages: List(Page),
    /// The id of the heading currently highlighted in the TOC, or `None`.
    active_heading: Option(String),
  )
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
      projects: sample_content.projects(),
      talks: sample_content.talks(),
      homepage: sample_content.homepage(),
      pages: sample_content.pages(),
      active_heading: option.None,
    )

  // Initialise modem so internal `<a>` clicks are intercepted and dispatched
  // as `UserNavigatedTo` messages instead of triggering a full page reload.
  // If the initial route is a single post, also kick off the TOC observer.
  let nav_effect =
    modem.init(fn(uri) { uri |> route.parse_route |> UserNavigatedTo })
  let toc_effect = toc_effect_for(initial_route)
  let effects = effect.batch([nav_effect, toc_effect])

  #(model, effects)
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UserNavigatedTo(route: Route)
  /// The TOC IntersectionObserver reported a new active heading.
  TocActiveHeadingChanged(id: String)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserNavigatedTo(route) -> {
      // Reset the active heading on navigation, then re-arm the TOC observer
      // when landing on a single post (the previous observer watched the old
      // post's DOM, which is gone after the view re-renders).
      let model = Model(..model, route:, active_heading: option.None)
      #(model, toc_effect_for(route))
    }
    TocActiveHeadingChanged(id) -> #(
      Model(..model, active_heading: option.Some(id)),
      effect.none(),
    )
  }
}

/// The TOC observer effect to run for a route: `observe()` on a single post,
/// `effect.none()` everywhere else.
fn toc_effect_for(route: Route) -> effect.Effect(Msg) {
  case route {
    Post(_) -> effect.map(toc_effect.observe(), TocActiveHeadingChanged)
    _ -> effect.none()
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let #(main_content, right_content) = case model.route {
    Home -> #(home_view.view(model.homepage), none())
    Posts(page) -> #(post_list.view(model.posts, page, posts_per_page), none())
    Post(slug) ->
      case post.find_by_slug(model.posts, slug) {
        Ok(found) -> #(
          post_view.view(found),
          toc_view.view(found.toc, model.active_heading),
        )
        Error(Nil) -> #(view_not_found(), none())
      }
    Projects -> #(cards.view(model.projects), none())
    Talks -> #(talks.view(model.talks), none())
    Tags -> #(tags.view_list(post.tag_index(model.posts)), none())
    Tag(name) ->
      case post.find_tag(post.tag_index(model.posts), name) {
        Ok(entry) -> #(tags.view_single(entry.name, entry.posts), none())
        Error(Nil) -> #(view_not_found(), none())
      }
    Page(slug) ->
      case page.find_by_slug(model.pages, slug) {
        Ok(found) -> #(page_view.view(found), none())
        Error(Nil) -> #(view_not_found(), none())
      }
    NotFound(_) -> #(view_not_found(), none())
  }

  layout.view(
    [
      header.view(model.config, model.route),
      main_content,
      footer.view(model.config),
    ],
    right_content,
  )
}

// All routes are now fully wired — no placeholder views remain.

fn view_not_found() -> Element(Msg) {
  // Mirrors apollo's `404.html`: a `<main class="not-found-header">` containing
  // a `.page-header` "404" and a "Page not found :(" span.
  html.main([attribute.class("not-found-header")], [
    html.div([attribute.class("page-header")], [html.text("404")]),
    html.span([], [html.text("Page not found :(")]),
  ])
}
