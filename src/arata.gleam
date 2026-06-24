//// arata — a faithful reimplementation of the apollo blog theme using Gleam
//// and the Lustre framework.
////
//// This module is the application entry point. It boots a `lustre.application`
//// SPA with client-side routing via `modem`.
////
//// Important invariant:
//// 404 must only be rendered after `content_index.json` has loaded
//// successfully. During the initial async content fetch, route-specific lookup
//// against empty lists would produce false 404s on deep-link refreshes.

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
import view/aratafetch
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

const posts_per_page = 10

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type ContentState {
  ContentLoading
  ContentReady
  ContentFailed
}

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
    content_state: ContentState,
    active_heading: Option(String),
    theme: theme_effect.Theme,
    system_prefers_dark: Bool,
    search: SearchState,
    mobile_menu_open: Bool,
    toc_overlay_open: Bool,
  )
}

pub type SearchState {
  SearchState(
    open: Bool,
    query: String,
    results: List(SearchResult),
    selected_index: Int,
  )
}

fn init(_flags: Nil) -> #(Model, effect.Effect(Msg)) {
  let initial_route = case modem.initial_uri() {
    Ok(uri) -> route.parse_route(uri)
    Error(_) -> Home
  }

  let model =
    Model(
      route: initial_route,
      config: config.default(),
      site_meta: config.site_meta(),
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
      content_state: ContentLoading,
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

  let nav_effect =
    modem.init(fn(uri) { uri |> route.parse_route |> UserNavigatedTo })

  let theme_init = effect.map(theme_effect.init_theme(), theme_msg_to_msg)

  let search_keys = case model.config.search_enabled {
    True ->
      effect.map(search_effect.subscribe_to_search_keys(), SearchKeyPressed)
    False -> effect.none()
  }

  let analytics_eff =
    effect.map(analytics_effect.inject(model.config.analytics), fn(_) { NoOp })

  let content_eff = effect.map(content_runtime.load(), content_msg_to_msg)

  // Do not run post effects here.
  //
  // On deep-link refresh, the route may already be `Post(slug)`, but the post
  // DOM does not exist until `content_index.json` has loaded. Running TOC,
  // codeblock, note, MathJax, or Mermaid effects here races against an empty
  // view. They are armed after `ContentLoaded(Ok(_))`.
  let effects =
    effect.batch([
      nav_effect,
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
  TocActiveHeadingChanged(id: String)
  UserToggledTheme
  ThemeLoaded(theme: theme_effect.Theme)
  SystemPrefersDarkChanged(prefers_dark: Bool)
  NoOp
  ContentLoaded(result: Result(content_runtime.Content, Nil))
  UserOpenedSearch
  UserClosedSearch
  UserEnteredSearchQuery(query: String)
  UserClearedSearch
  SearchKeyPressed(event: search_effect.SearchKeyEvent)
  SearchResultClicked(slug: String)
  UserToggledMobileMenu
  UserToggledTocOverlay
  UserScrolledToTop
  UserEnteredPageJump(page: String)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserNavigatedTo(route) -> {
      let new_model =
        Model(
          ..model,
          route:,
          active_heading: option.None,
          mobile_menu_open: False,
          toc_overlay_open: False,
        )

      let route_effects = case new_model.content_state {
        ContentReady ->
          post_effects_for(
            route,
            is_effective_dark(new_model.theme, new_model.system_prefers_dark),
            new_model.config.mathjax_enabled,
          )

        ContentLoading | ContentFailed -> effect.none()
      }

      #(new_model, route_effects)
    }

    TocActiveHeadingChanged(id) -> #(
      Model(..model, active_heading: option.Some(id)),
      effect.none(),
    )

    UserToggledTheme -> {
      let next_theme =
        next_theme_after_click(model.theme, model.system_prefers_dark)

      let new_model = Model(..model, theme: next_theme)

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
      let new_model = Model(..model, theme:)
      #(new_model, mermaid_rerender_for(new_model))
    }

    SystemPrefersDarkChanged(prefers_dark) -> {
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
      case result {
        Ok(content) -> {
          let new_model =
            Model(
              ..model,
              posts: content.posts,
              pages: content.pages,
              homepage: content.homepage,
              links: content.links,
              projects: content.projects,
              content_state: ContentReady,
            )

          #(
            new_model,
            post_effects_for(
              new_model.route,
              is_effective_dark(new_model.theme, new_model.system_prefers_dark),
              new_model.config.mathjax_enabled,
            ),
          )
        }

        Error(_) -> #(
          Model(..model, content_state: ContentFailed),
          effect.none(),
        )
      }
    }

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
      let eff =
        effect.from(fn(_) {
          scroll_to_top()
          Nil
        })

      #(model, eff)
    }

    UserEnteredPageJump(page_str) ->
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

/// Pick the next theme after a user click.
///
/// The cycle is system-aware so the first click from `Auto` always causes a
/// visible change:
///
///   system light: Auto(light) -> Dark -> Light -> Auto(light)
///   system dark:  Auto(dark)  -> Light -> Dark -> Auto(dark)
///
/// The final explicit theme -> Auto transition may be visually identical to
/// the previous explicit theme when it matches the system preference, but the
/// icon still changes to Auto and the state remains meaningful.
fn next_theme_after_click(
  theme: theme_effect.Theme,
  system_prefers_dark: Bool,
) -> theme_effect.Theme {
  case theme {
    theme_effect.Auto ->
      case system_prefers_dark {
        True -> theme_effect.Light
        False -> theme_effect.Dark
      }

    theme_effect.Light ->
      case system_prefers_dark {
        True -> theme_effect.Dark
        False -> theme_effect.Auto
      }

    theme_effect.Dark ->
      case system_prefers_dark {
        True -> theme_effect.Auto
        False -> theme_effect.Light
      }
  }
}

fn mermaid_rerender_for(model: Model) -> effect.Effect(Msg) {
  case model.content_state, model.route {
    ContentReady, Post(_) ->
      effect.map(
        script_effect.render_mermaid(is_effective_dark(
          model.theme,
          model.system_prefers_dark,
        )),
        fn(_) { NoOp },
      )

    _, _ -> effect.none()
  }
}

fn theme_msg_to_msg(tm: theme_effect.ThemeMsg) -> Msg {
  case tm {
    theme_effect.ThemeLoaded(theme) -> ThemeLoaded(theme:)
    theme_effect.SystemPrefersDarkChanged(prefers_dark) ->
      SystemPrefersDarkChanged(prefers_dark:)
  }
}

fn content_msg_to_msg(cm: content_runtime.ContentMsg) -> Msg {
  case cm {
    content_runtime.ContentLoaded(result) ->
      ContentLoaded(result |> result.map_error(fn(_) { Nil }))
  }
}

@external(javascript, "./ffi/browser.ffi.mjs", "scroll_to_top")
fn scroll_to_top() -> Nil

fn closed_search() -> SearchState {
  SearchState(open: False, query: "", results: [], selected_index: 0)
}

fn handle_search_key(
  model: Model,
  event: search_effect.SearchKeyEvent,
) -> #(Model, effect.Effect(Msg)) {
  case event.key, event.cmd_or_ctrl, model.search.open {
    "k", True, False -> #(
      Model(..model, search: SearchState(..model.search, open: True)),
      effect.none(),
    )

    "k", True, True -> #(model, effect.none())

    "Escape", _, True -> #(
      Model(..model, search: closed_search()),
      effect.none(),
    )

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

    _, _, _ -> #(model, effect.none())
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let #(main_content, right_content) = case model.content_state {
    ContentLoading -> #(view_loading(), none())

    ContentFailed -> #(view_content_failed(), none())

    ContentReady -> view_route_content(model)
  }

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

  let toc_fab_els = case
    model.content_state,
    model.config.floating_buttons_enabled
  {
    ContentReady, True -> toc_fab_elements(model)

    _, _ -> []
  }

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
      toc_fab_els,
    ]),
  )
}

fn view_route_content(model: Model) -> #(Element(Msg), Element(Msg)) {
  case model.route {
    Home -> {
      let stats =
        aratafetch.from_content(
          model.site_meta.title,
          model.posts,
          model.links,
          model.projects,
          model.config.aratafetch_maintained_for,
        )

      let fetch_el = aratafetch.view(model.config.aratafetch_enabled, stats)

      #(
        home_view.view(
          model.homepage,
          model.config.aratafetch_enabled,
          fetch_el,
        ),
        none(),
      )
    }

    Posts(page) -> #(
      post_list.view(model.posts, page, posts_per_page, UserEnteredPageJump),
      none(),
    )

    Post(slug) ->
      case post.find_by_slug(model.posts, slug) {
        Ok(found) -> #(
          post_view.view(found, model.site_meta.comments),
          case model.config.sidebar_enabled {
            True ->
              view_tags_and_toc(found.tags, found.toc, model.active_heading)

            False -> none()
          },
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
}

fn toc_fab_elements(model: Model) -> List(Element(Msg)) {
  case model.route {
    Post(slug) ->
      case post.find_by_slug(model.posts, slug) {
        Ok(found) ->
          case found.toc, found.tags {
            [], [] -> []

            _, _ -> [
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
                      html.div(
                        [attribute.class("toc-overlay-content")],
                        list.flatten([
                          [
                            html.div([attribute.class("toc-overlay-header")], [
                              html.button(
                                [
                                  attribute.class("toc-overlay-scroll-top"),
                                  event.on_click(UserScrolledToTop),
                                ],
                                [html.text("↑")],
                              ),
                            ]),
                          ],
                          case found.tags {
                            [] -> []
                            _ -> [view_tags_sidebar(found.tags)]
                          },
                          case found.toc {
                            [] -> []
                            _ -> [
                              toc_view.view(found.toc, model.active_heading),
                            ]
                          },
                        ]),
                      ),
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
}

fn view_loading() -> Element(Msg) {
  html.main([attribute.class("page-header")], [
    html.div([], [html.text("Loading…")]),
  ])
}

fn view_content_failed() -> Element(Msg) {
  html.main([attribute.class("not-found-header")], [
    html.div([attribute.class("page-header")], [
      html.text("Content failed to load"),
    ]),
    html.span([], [
      html.text("Could not fetch content_index.json."),
    ]),
  ])
}

fn view_not_found() -> Element(Msg) {
  html.main([attribute.class("not-found-header")], [
    html.div([attribute.class("page-header")], [html.text("404")]),
    html.span([], [html.text("Page not found :(")]),
  ])
}

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
