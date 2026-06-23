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
//// /posts/{slug} (single post with TOC), /projects (card grid), /links
//// (friend-link list), /tags (tag index), /tags/{name} (single tag), /
//// (homepage), and /{slug} (standalone pages). A single post also renders a
//// scroll-driven table of contents in the `.right-content` sidebar with
//// IntersectionObserver active highlighting. The theme toggle (Phase 10)
//// cycles Light/Dark/Auto with localStorage persistence and matchMedia
//// reactivity.

import config
import content/runtime as content_runtime
import data/link.{type Link}
import data/page.{type Page}
import data/post.{type Post}
import data/project.{type Project}
import data/search.{type SearchResult}
import data/site.{type SiteMeta}
import effect/analytics as analytics_effect
import effect/codeblock as codeblock_effect
import effect/note as note_effect
import effect/script as script_effect
import effect/search as search_effect
import effect/theme as theme_effect
import effect/toc as toc_effect
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element, none}
import lustre/element/html
import lustre/event
import modem
import route.{
  type Route, Home, Links, NotFound, Page, Post, Posts, Projects, Tag, Tags,
}
import view/cards
import view/header
import view/home as home_view
import view/layout
import view/links as links_view
import view/page as page_view
import view/post as post_view
import view/post_list
import view/search_modal
import view/tags
import view/toc as toc_view

// MAIN ------------------------------------------------------------------------

/// Number of posts per page on the post list. Fix 6 raised this from 7 to 10
/// so each page shows more posts before paginating.
const posts_per_page = 10

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
    site_meta: SiteMeta,
    posts: List(Post),
    projects: List(Project),
    links: List(Link),
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
    /// Whether the mobile hamburger menu is open (only relevant below 992px;
    /// the hamburger button itself is hidden on desktop via CSS, so this flag
    /// has no visible effect above the breakpoint).
    mobile_menu_open: Bool,
    /// Whether the mobile floating ToC overlay is open (only relevant below
    /// 992px on a post page; the FAB that toggles it is hidden on desktop).
    toc_overlay_open: Bool,
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
      site_meta: site.default(),
      // All content (posts/pages/homepage/links/projects) is loaded
      // asynchronously from `content_index.json` via `content_runtime.load()`;
      // the lists start empty and are populated when `ContentLoaded` arrives.
      posts: [],
      projects: [],
      links: [],
      homepage: page.Page(
        slug: "home",
        title: "arata",
        body: "",
        subtitle: option.None,
      ),
      pages: [],
      active_heading: option.None,
      theme: theme_effect.Light,
      system_prefers_dark: False,
      search: SearchState(
        open: False,
        query: "",
        results: [],
        selected_index: 0,
      ),
      mobile_menu_open: False,
      toc_overlay_open: False,
    )

  // Initialise modem so internal `<a>` clicks are intercepted and dispatched
  // as `UserNavigatedTo` messages instead of triggering a full page reload.
  // If the initial route is a single post, also kick off the TOC observer.
  // The theme init effect reads localStorage + subscribes to matchMedia.
  // The search keyboard listener subscribes to global keydown for Cmd/Ctrl+K.
  let nav_effect =
    modem.init(fn(uri) { uri |> route.parse_route |> UserNavigatedTo })
  let post_effects =
    post_effects_for(initial_route, False, model.config.mathjax_enabled)
  let theme_init = effect.map(theme_effect.init_theme(), theme_msg_to_msg)
  let search_keys = case model.config.search_enabled {
    True ->
      effect.map(search_effect.subscribe_to_search_keys(), SearchKeyPressed)
    False -> effect.none()
  }
  let analytics_eff =
    effect.map(analytics_effect.inject(model.config.analytics), fn(_) { NoOp })
  // Kick off the async fetch of `content_index.json`. The result arrives as
  // a `ContentLoaded` message that populates `posts`, `pages`, `homepage`.
  let content_eff = effect.map(content_runtime.load(), content_msg_to_msg)
  // Note: deep-link refresh on a static host is handled by 404.html, which
  // now serves the SPA shell directly. modem reads `window.location.pathname`
  // and dispatches the initial route via `nav_effect` above — no extra
  // redirect effect is needed.
  let effects =
    effect.batch([
      nav_effect,
      post_effects,
      theme_init,
      search_keys,
      analytics_eff,
      content_eff,
    ])

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
  /// Content was loaded from `content_index.json`.
  ContentLoaded(result: Result(content_runtime.Content, Nil))
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
  /// The user clicked the mobile hamburger menu button (toggles the
  /// dropdown nav menu below 992px).
  UserToggledMobileMenu
  /// The user clicked the mobile floating ToC button (toggles the
  /// bottom-sheet ToC overlay on post pages below 992px).
  UserToggledTocOverlay
  /// The user clicked the scroll-to-top floating button (Fix 7). Smooth-
  /// scrolls the window back to the top via the browser FFI.
  UserScrolledToTop
  /// The user submitted the page-jump input on the post list (Enter or
  /// blur). The string is the raw input value; the update parses it to an
  /// `Int` and navigates to `Posts(n)`.
  UserEnteredPageJump(page: String)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserNavigatedTo(route) -> {
      // Reset the active heading on navigation, then re-arm the TOC observer
      // when landing on a single post (the previous observer watched the old
      // post's DOM, which is gone after the view re-renders). Also close the
      // mobile menu so a click on a nav link dismisses the dropdown.
      let model =
        Model(
          ..model,
          route:,
          active_heading: option.None,
          mobile_menu_open: False,
          toc_overlay_open: False,
        )
      #(
        model,
        post_effects_for(
          route,
          is_effective_dark(model.theme, model.system_prefers_dark),
          model.config.mathjax_enabled,
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
    ContentLoaded(result) -> {
      // Replace the empty placeholder content with the fetched posts/pages/
      // homepage/links/projects. On error (e.g. fetch failed), keep the empty
      // defaults so the app still renders the shell.
      case result {
        Ok(content) -> {
          let model =
            Model(
              ..model,
              posts: content.posts,
              pages: content.pages,
              homepage: content.homepage,
              links: content.links,
              projects: content.projects,
            )
          #(model, effect.none())
        }
        Error(_) -> #(model, effect.none())
      }
    }
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
          mobile_menu_open: False,
          toc_overlay_open: False,
        ),
        effect.batch([
          modem.push(route.href_url(target_route), option.None, option.None),
          post_effects_for(
            target_route,
            is_effective_dark(model.theme, model.system_prefers_dark),
            model.config.mathjax_enabled,
          ),
        ]),
      )
    }
    UserToggledMobileMenu -> #(
      Model(..model, mobile_menu_open: !model.mobile_menu_open),
      effect.none(),
    )
    UserToggledTocOverlay -> #(
      Model(..model, toc_overlay_open: !model.toc_overlay_open),
      effect.none(),
    )
    UserScrolledToTop -> {
      // Fix 7: smooth-scroll the window to the top. The FFI is a no-op
      // outside the browser (Erlang target); the model is unchanged.
      let eff =
        effect.from(fn(_) {
          scroll_to_top()
          Nil
        })
      #(model, eff)
    }
    // PAGE JUMP ------------------------------------------------------------
    UserEnteredPageJump(page_str) ->
      // Parse the input value and navigate to `Posts(n)`. Invalid input
      // (non-numeric, < 1) is silently ignored — the user just stays on the
      // current page.
      case int.parse(page_str) {
        Ok(page) if page >= 1 -> {
          let target_route = route.Posts(page)
          #(
            Model(
              ..model,
              route: target_route,
              mobile_menu_open: False,
              toc_overlay_open: False,
            ),
            effect.batch([
              modem.push(route.href_url(target_route), option.None, option.None),
              post_effects_for(
                target_route,
                is_effective_dark(model.theme, model.system_prefers_dark),
                model.config.mathjax_enabled,
              ),
            ]),
          )
        }
        _ -> #(model, effect.none())
      }
  }
}

/// Effects to run when landing on a route: on a single post, the TOC
/// IntersectionObserver, the code-block enhancer, the note toggle enhancer,
/// and the MathJax/Mermaid renderers are all armed. Everywhere else, no
/// effects. `is_dark` selects the mermaid theme ("dark" vs "neutral").
fn post_effects_for(
  route: Route,
  is_dark: Bool,
  mathjax_enabled: Bool,
) -> effect.Effect(Msg) {
  case route {
    Post(_) -> {
      let mathjax_eff = case mathjax_enabled {
        True -> effect.map(script_effect.typeset_math(), fn(_) { NoOp })
        False -> effect.none()
      }
      effect.batch([
        effect.map(toc_effect.observe(), TocActiveHeadingChanged),
        effect.map(codeblock_effect.enhance(), fn(_) { NoOp }),
        effect.map(note_effect.enhance(), fn(_) { NoOp }),
        mathjax_eff,
        effect.map(script_effect.render_mermaid(is_dark), fn(_) { NoOp }),
      ])
    }
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

/// Map a `ContentMsg` (from the content runtime) into the app's `Msg` type.
/// The `rsvp.Error` from the fetch is collapsed to `Nil` — we don't surface
/// the specific error to the user, the content just stays empty.
fn content_msg_to_msg(cm: content_runtime.ContentMsg) -> Msg {
  case cm {
    content_runtime.ContentLoaded(result) ->
      ContentLoaded(result |> result.map_error(fn(_) { Nil }))
  }
}

/// Fix 7: smooth-scroll the window to the top. The FFI lives in
/// `src/ffi/browser.ffi.mjs`; on non-JS targets it's a no-op (returns `Nil`).
/// Note: this module (`src/arata.gleam`) is at the package root, so the path
/// is `./ffi/...` (not `../ffi/...` as in subdirectory modules).
@external(javascript, "./ffi/browser.ffi.mjs", "scroll_to_top")
fn scroll_to_top() -> Nil

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
                model.config.mathjax_enabled,
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
    Posts(page) -> #(
      post_list.view(model.posts, page, posts_per_page, UserEnteredPageJump),
      none(),
    )
    Post(slug) ->
      case post.find_by_slug(model.posts, slug) {
        Ok(found) -> #(
          post_view.view(found, model.site_meta.comments),
          view_tags_and_toc(found.tags, found.toc, model.active_heading),
        )
        Error(Nil) -> #(view_not_found(), none())
      }
    Projects -> #(cards.view(model.projects), none())
    Links -> #(links_view.view(model.links), none())
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
  // fixed-position overlay, not part of the normal document flow). When
  // search is disabled in the config, the modal is omitted entirely.
  let search_modal_el = case model.config.search_enabled {
    True ->
      search_modal.view(
        model.search.open,
        model.search.query,
        model.search.results,
        model.search.selected_index,
        UserEnteredSearchQuery,
        UserClearedSearch,
        UserClosedSearch,
        SearchResultClicked,
        fn(key) {
          SearchKeyPressed(search_effect.SearchKeyEvent(
            key:,
            cmd_or_ctrl: False,
          ))
        },
      )
    False -> none()
  }
  // An inline `<style>` rule that overrides the `:root` font CSS custom
  // properties with the values from `config.fonts`. The rest of `arata.css`
  // resolves the font families through `var(--text-font)` etc., so this is
  // the single seam where the configured fonts take effect.
  let fonts_style =
    html.style(
      [],
      ":root { --text-font: "
        <> model.config.fonts.text
        <> "; --header-font: "
        <> model.config.fonts.header
        <> "; --code-font: "
        <> model.config.fonts.code
        <> "; }",
    )
  // On a single post with TOC entries, render a floating action button (FAB)
  // in the bottom-right corner that opens a bottom-sheet ToC overlay. Fix 5
  // lifted the CSS media-query gate so the FAB and overlay are visible on
  // ALL screen sizes; emitting them on every platform is now intentional.
  // Fix 6 also renders the post's tags inside the overlay, below the ToC.
  let toc_fab_els = case model.route {
    Post(slug) ->
      case post.find_by_slug(model.posts, slug) {
        Ok(found) ->
          case found.toc {
            [] ->
              // No ToC entries: still show a FAB if the post has tags, so
              // mobile readers can reach them from any post.
              case found.tags {
                [] -> []
                _ -> [
                  html.button(
                    [
                      attribute.class("toc-fab"),
                      attribute.attribute("aria-label", "Open tags"),
                      event.on_click(UserToggledTocOverlay),
                    ],
                    [html.text("☰")],
                  ),
                  ..case model.toc_overlay_open {
                    True -> [
                      html.div(
                        [
                          attribute.class("toc-overlay"),
                          event.on_click(UserToggledTocOverlay),
                        ],
                        [
                          html.div([attribute.class("toc-overlay-content")], [
                            view_tags_sidebar(found.tags),
                          ]),
                        ],
                      ),
                    ]
                    False -> []
                  }
                ]
              }
            _ -> [
              html.button(
                [
                  attribute.class("toc-fab"),
                  attribute.attribute("aria-label", "Open table of contents"),
                  event.on_click(UserToggledTocOverlay),
                ],
                [html.text("☰")],
              ),
              ..case model.toc_overlay_open {
                True -> [
                  html.div(
                    [
                      attribute.class("toc-overlay"),
                      event.on_click(UserToggledTocOverlay),
                    ],
                    [
                      html.div([attribute.class("toc-overlay-content")], [
                        html.div([attribute.class("heading")], [
                          html.text("Table of Contents"),
                        ]),
                        toc_view.view(found.toc, model.active_heading),
                        // Fix 6: after the ToC, show the post's tags (if any)
                        // so mobile readers can jump to a taxonomy page
                        // without scrolling back to the right sidebar.
                        ..case found.tags {
                          [] -> []
                          _ -> [view_tags_sidebar(found.tags)]
                        }
                      ]),
                    ],
                  ),
                ]
                False -> []
              }
            ]
          }
        Error(Nil) -> []
      }
    _ -> []
  }
  // Fix 7: a separate scroll-to-top FAB, visible on ALL pages (not just
  // posts), positioned to the left of the ToC FAB. Smooth-scrolls via the
  // browser FFI.
  let scroll_top_fab_el =
    html.button(
      [
        attribute.class("scroll-top-fab"),
        attribute.attribute("aria-label", "Scroll to top"),
        event.on_click(UserScrolledToTop),
      ],
      [html.text("↑")],
    )
  html.div(
    [],
    list.flatten([
      [
        layout.view(
          list.append([fonts_style], [
            header.view(
              model.config,
              model.route,
              event.on_click(UserToggledTheme),
              event.on_click(UserOpenedSearch),
              event.on_click(UserToggledMobileMenu),
              model.mobile_menu_open,
            ),
            main_content,
          ]),
          right_content,
        ),
      ],
      [search_modal_el],
      [scroll_top_fab_el],
      toc_fab_els,
    ]),
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

/// Render the right sidebar for a single post: the post's tags (as a
/// `.post-tags` row of links to `/tags/<tag>`) followed by the table of
/// contents. Tags appear ABOVE the TOC with spacing between them and the
/// TOC below (see `.right-content .post-tags` in `arata.css`). When the
/// post has no tags AND no TOC entries, returns `element.none()` so the
/// sidebar stays empty.
fn view_tags_and_toc(
  post_tags: List(String),
  toc: List(post.TocEntry),
  active_heading: Option(String),
) -> Element(Msg) {
  case post_tags, toc {
    [], [] -> none()
    _, _ ->
      html.div([], [
        view_tags_sidebar(post_tags),
        toc_view.view(toc, active_heading),
      ])
  }
}

/// Render the post's tags as a `.post-tags` row for the right sidebar. Each
/// tag is a link to its taxonomy page via `route.href(route.Tag(tag))` so
/// modem intercepts the click. Returns `element.none()` when the post has
/// no tags, so the sidebar collapses cleanly.
fn view_tags_sidebar(post_tags: List(String)) -> Element(Msg) {
  case post_tags {
    [] -> none()
    _ ->
      html.div([attribute.class("post-tags")], [
        html.div([attribute.class("heading")], [html.text("Tags")]),
        ..list.map(post_tags, fn(tag) {
          html.a([attribute.class("tag"), route.href(route.Tag(tag))], [
            html.text(tag),
          ])
        })
      ])
  }
}
