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
//// active highlighting. The theme toggle (Phase 10) cycles Light/Dark/Auto
//// with localStorage persistence and matchMedia reactivity.

import config
import data/page.{type Page}
import data/post.{type Post}
import data/project.{type Project}
import data/sample_content
import data/search.{type SearchResult}
import data/talk.{type Talk}
import effect/codeblock as codeblock_effect
import effect/note as note_effect
import effect/script as script_effect
import effect/search as search_effect
import effect/theme as theme_effect
import effect/toc as toc_effect
import gleam/int
import gleam/list
import gleam/option.{type Option}
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element, none}
import lustre/element/html
import lustre/event
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
import view/search_modal
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
    /// The user's saved theme choice (Light/Dark/Auto).
    theme: theme_effect.Theme,
    /// Whether the OS prefers dark mode (used to resolve `Auto`).
    system_prefers_dark: Bool,
    /// The search modal state.
    search: SearchState,
  )
}

/// The search modal state: whether it's open, the current query, the results,
/// and the selected result index for keyboard navigation.
pub type SearchState {
  SearchState(
    open: Bool,
    query: String,
    results: List(SearchResult),
    selected_index: Int,
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
      theme: theme_effect.Light,
      system_prefers_dark: False,
      search: SearchState(
        open: False,
        query: "",
        results: [],
        selected_index: 0,
      ),
    )

  // Initialise modem so internal `<a>` clicks are intercepted and dispatched
  // as `UserNavigatedTo` messages instead of triggering a full page reload.
  // If the initial route is a single post, also kick off the TOC observer.
  // The theme init effect reads localStorage + subscribes to matchMedia.
  // The search keyboard listener subscribes to global keydown for Cmd/Ctrl+K.
  let nav_effect =
    modem.init(fn(uri) { uri |> route.parse_route |> UserNavigatedTo })
  let post_effects = post_effects_for(initial_route, False)
  let theme_init = effect.map(theme_effect.init_theme(), theme_msg_to_msg)
  let search_keys =
    effect.map(search_effect.subscribe_to_search_keys(), SearchKeyPressed)
  let effects =
    effect.batch([nav_effect, post_effects, theme_init, search_keys])

  #(model, effects)
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UserNavigatedTo(route: Route)
  /// The TOC IntersectionObserver reported a new active heading.
  TocActiveHeadingChanged(id: String)
  /// The user clicked the theme toggle button.
  UserToggledTheme
  /// The saved/system theme was loaded at startup.
  ThemeLoaded(theme: theme_effect.Theme)
  /// The OS theme preference changed.
  SystemPrefersDarkChanged(prefers_dark: Bool)
  /// A no-op message for effects that dispatch nothing (e.g. the code-block
  /// enhancer, which only performs a side effect).
  NoOp
  // SEARCH -----------------------------------------------------------------
  /// The user clicked the search button or pressed Cmd/Ctrl+K.
  UserOpenedSearch
  /// The user closed the search modal (Escape or backdrop click).
  UserClosedSearch
  /// The user typed in the search input.
  UserEnteredSearchQuery(query: String)
  /// The user clicked the clear button.
  UserClearedSearch
  /// A search keyboard shortcut was pressed.
  SearchKeyPressed(event: search_effect.SearchKeyEvent)
  /// The user clicked a search result (or pressed Enter on it).
  SearchResultClicked(slug: String)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserNavigatedTo(route) -> {
      // Reset the active heading on navigation, then re-arm the TOC observer
      // when landing on a single post (the previous observer watched the old
      // post's DOM, which is gone after the view re-renders).
      let model = Model(..model, route:, active_heading: option.None)
      #(
        model,
        post_effects_for(
          route,
          is_effective_dark(model.theme, model.system_prefers_dark),
        ),
      )
    }
    TocActiveHeadingChanged(id) -> #(
      Model(..model, active_heading: option.Some(id)),
      effect.none(),
    )
    UserToggledTheme -> {
      // 3-state cycle: Light -> Dark -> Auto -> Light (apollo's toggle-auto).
      let next_theme = case model.theme {
        theme_effect.Light -> theme_effect.Dark
        theme_effect.Dark -> theme_effect.Auto
        theme_effect.Auto -> theme_effect.Light
      }
      let new_model = Model(..model, theme: next_theme)
      // Re-render mermaid with the new theme if we're on a post page.
      let mermaid_eff = mermaid_rerender_for(new_model)
      #(
        new_model,
        effect.batch([
          effect.map(
            theme_effect.apply_theme_choice(next_theme),
            theme_msg_to_msg,
          ),
          mermaid_eff,
        ]),
      )
    }
    ThemeLoaded(theme) -> {
      // The FFI has already applied the theme to the DOM; we just store it.
      let new_model = Model(..model, theme:)
      #(new_model, mermaid_rerender_for(new_model))
    }
    SystemPrefersDarkChanged(prefers_dark) -> {
      // When the OS preference changes and the user chose Auto, re-apply the
      // theme so the <html> class updates, and re-render mermaid.
      let new_model = Model(..model, system_prefers_dark: prefers_dark)
      let theme_eff = case new_model.theme {
        theme_effect.Auto ->
          effect.map(
            theme_effect.apply_theme_choice(new_model.theme),
            theme_msg_to_msg,
          )
        _ -> effect.none()
      }
      #(new_model, effect.batch([theme_eff, mermaid_rerender_for(new_model)]))
    }
    NoOp -> #(model, effect.none())
    // SEARCH -------------------------------------------------------------
    UserOpenedSearch -> #(
      Model(
        ..model,
        search: SearchState(
          open: True,
          query: "",
          results: [],
          selected_index: 0,
        ),
      ),
      effect.none(),
    )
    UserClosedSearch -> #(
      Model(..model, search: closed_search()),
      effect.none(),
    )
    UserEnteredSearchQuery(query) -> {
      let results = search.search(model.posts, query)
      #(
        Model(
          ..model,
          search: SearchState(open: True, query:, results:, selected_index: 0),
        ),
        effect.none(),
      )
    }
    UserClearedSearch -> #(
      Model(
        ..model,
        search: SearchState(
          open: True,
          query: "",
          results: [],
          selected_index: 0,
        ),
      ),
      effect.none(),
    )
    SearchKeyPressed(event) -> handle_search_key(model, event)
    SearchResultClicked(slug) -> {
      // Navigate to the post and close the modal.
      let target_route = route.Post(slug)
      #(
        Model(
          ..model,
          route: target_route,
          search: closed_search(),
          active_heading: option.None,
        ),
        effect.batch([
          modem.push(route.href_url(target_route), option.None, option.None),
          post_effects_for(
            target_route,
            is_effective_dark(model.theme, model.system_prefers_dark),
          ),
        ]),
      )
    }
  }
}

/// Effects to run when landing on a route: on a single post, the TOC
/// IntersectionObserver, the code-block enhancer, the note toggle enhancer,
/// and the MathJax/Mermaid renderers are all armed. Everywhere else, no
/// effects. `is_dark` selects the mermaid theme ("dark" vs "neutral").
fn post_effects_for(route: Route, is_dark: Bool) -> effect.Effect(Msg) {
  case route {
    Post(_) ->
      effect.batch([
        effect.map(toc_effect.observe(), TocActiveHeadingChanged),
        effect.map(codeblock_effect.enhance(), fn(_) { NoOp }),
        effect.map(note_effect.enhance(), fn(_) { NoOp }),
        effect.map(script_effect.typeset_math(), fn(_) { NoOp }),
        effect.map(script_effect.render_mermaid(is_dark), fn(_) { NoOp }),
      ])
    _ -> effect.none()
  }
}

/// Whether the effective theme is dark, given the user's choice and the
/// system preference. `Auto` resolves to the system preference.
fn is_effective_dark(
  theme: theme_effect.Theme,
  system_prefers_dark: Bool,
) -> Bool {
  case theme {
    theme_effect.Dark -> True
    theme_effect.Light -> False
    theme_effect.Auto -> system_prefers_dark
  }
}

/// Re-render mermaid diagrams with the new theme, but only if we're currently
/// on a post page (mermaid blocks only exist inside post bodies). Returns
/// `effect.none()` on other routes.
fn mermaid_rerender_for(model: Model) -> effect.Effect(Msg) {
  case model.route {
    Post(_) ->
      effect.map(
        script_effect.render_mermaid(is_effective_dark(
          model.theme,
          model.system_prefers_dark,
        )),
        fn(_) { NoOp },
      )
    _ -> effect.none()
  }
}

/// Map a `ThemeMsg` (from the theme effect) into the app's `Msg` type.
fn theme_msg_to_msg(tm: theme_effect.ThemeMsg) -> Msg {
  case tm {
    theme_effect.ThemeLoaded(theme) -> ThemeLoaded(theme:)
    theme_effect.SystemPrefersDarkChanged(prefers_dark) ->
      SystemPrefersDarkChanged(prefers_dark:)
  }
}

/// A closed/empty search state.
fn closed_search() -> SearchState {
  SearchState(open: False, query: "", results: [], selected_index: 0)
}

/// Handle a search keyboard shortcut:
///   - Cmd/Ctrl+K opens the modal.
///   - Escape closes it.
///   - ArrowUp/ArrowDown navigate the results (only when open).
///   - Enter follows the selected result (only when open).
fn handle_search_key(
  model: Model,
  event: search_effect.SearchKeyEvent,
) -> #(Model, effect.Effect(Msg)) {
  case event.key, event.cmd_or_ctrl, model.search.open {
    // Cmd/Ctrl+K toggles the modal open.
    "k", True, False -> #(
      Model(..model, search: SearchState(..model.search, open: True)),
      effect.none(),
    )
    // Cmd/Ctrl+K when already open does nothing (don't close).
    "k", True, True -> #(model, effect.none())
    // Escape closes the modal.
    "Escape", _, True -> #(
      Model(..model, search: closed_search()),
      effect.none(),
    )
    // ArrowDown moves the selection down (clamp to last result).
    "ArrowDown", _, True -> {
      let max = list.length(model.search.results) - 1
      let next = int.min(model.search.selected_index + 1, max)
      #(
        Model(
          ..model,
          search: SearchState(..model.search, selected_index: next),
        ),
        effect.none(),
      )
    }
    // ArrowUp moves the selection up (clamp to 0).
    "ArrowUp", _, True -> {
      let prev = int.max(model.search.selected_index - 1, 0)
      #(
        Model(
          ..model,
          search: SearchState(..model.search, selected_index: prev),
        ),
        effect.none(),
      )
    }
    // Enter follows the selected result.
    "Enter", _, True ->
      case
        list.first(list.drop(model.search.results, model.search.selected_index))
      {
        Ok(result) -> {
          let target_route = route.Post(result.post.slug)
          #(
            Model(
              ..model,
              route: target_route,
              search: closed_search(),
              active_heading: option.None,
            ),
            effect.batch([
              modem.push(route.href_url(target_route), option.None, option.None),
              post_effects_for(
                target_route,
                is_effective_dark(model.theme, model.system_prefers_dark),
              ),
            ]),
          )
        }
        Error(Nil) -> #(model, effect.none())
      }
    // Any other key is ignored.
    _, _, _ -> #(model, effect.none())
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

  // The search modal is rendered as a sibling of the layout (it's a
  // fixed-position overlay, not part of the normal document flow).
  html.div([], [
    layout.view(
      [
        header.view(
          model.config,
          model.route,
          event.on_click(UserToggledTheme),
          event.on_click(UserOpenedSearch),
        ),
        main_content,
        footer.view(model.config),
      ],
      right_content,
    ),
    search_modal.view(
      model.search.open,
      model.search.query,
      model.search.results,
      model.search.selected_index,
      UserEnteredSearchQuery,
      UserClearedSearch,
      SearchResultClicked,
      fn(key) {
        SearchKeyPressed(search_effect.SearchKeyEvent(key:, cmd_or_ctrl: False))
      },
    ),
  ])
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
