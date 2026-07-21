//// Arata application entry point.
////
//// This module boots the Lustre SPA and performs client-side routing through
//// `modem`.
////
//// Runtime configuration is loaded together with content from the generated
//// `content_index.json`. Built-in configuration is used only while that single
//// bootstrap request is pending.
////
//// Important invariants:
////
////   - route-specific content is not rendered before the content index loads;
////   - runtime feature effects are started only after resolved configuration
////     has been decoded;
////   - analytics, search, lightbox, MathJax, Mermaid, and syntax highlighting
////     use the configuration embedded in the content index;
////   - a deep-link refresh must not produce a false 404 while content is still
////     loading.

import config
import content/runtime as content_runtime
import data/link.{type Link}
import data/page.{type Page}
import data/post.{type Post}
import data/project.{type Project}
import data/search.{type SearchResult}
import data/site.{type SiteMeta, SiteMeta}
import effect/analytics as analytics_effect
import effect/codeblock as codeblock_effect
import effect/lightbox as lightbox_effect
import effect/note as note_effect
import effect/script as script_effect
import effect/search as search_effect
import effect/syntax_highlight as syntax_highlight_effect
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
import view/lightbox
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
    lightbox: lightbox.State,
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

  // These values are bootstrap placeholders only. The resolved TOML
  // configuration replaces them when content_index.json has loaded.
  let bootstrap_config = config.default()
  let bootstrap_site_meta = config.site_meta()

  let model =
    Model(
      route: initial_route,
      config: bootstrap_config,
      site_meta: bootstrap_site_meta,
      posts: [],
      projects: [],
      links: [],
      homepage: page.Page(
        slug: "home",
        title: bootstrap_config.title,
        body: "",
        subtitle: option.None,
      ),
      pages: [],
      content_state: ContentLoading,
      active_heading: option.None,
      theme: theme_effect.Light,
      system_prefers_dark: False,
      search: closed_search(),
      mobile_menu_open: False,
      toc_overlay_open: False,
      lightbox: lightbox.Closed,
    )

  let navigation_effect =
    modem.init(fn(uri) {
      uri
      |> route.parse_route
      |> UserNavigatedTo
    })

  let theme_effect = effect.map(theme_effect.init_theme(), theme_msg_to_msg)

  let content_effect = effect.map(content_runtime.load(), content_msg_to_msg)

  // Configuration-dependent effects must not start from bootstrap defaults.
  // They are armed after ContentLoaded(Ok(_)).
  let effects =
    effect.batch([
      navigation_effect,
      theme_effect,
      content_effect,
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
  LightboxOpened(src: String, alt: String)
  LightboxGalleryOpened(srcs: List(String), alts: List(String), index: Int)
  LightboxPrevious
  LightboxNext
  LightboxClosed
  LightboxEventReceived(event: lightbox_effect.Event)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserNavigatedTo(route) -> {
      let new_model =
        Model(
          ..model,
          route: route,
          active_heading: option.None,
          mobile_menu_open: False,
          toc_overlay_open: False,
          lightbox: lightbox.Closed,
        )

      let route_effects = case new_model.content_state {
        ContentReady -> configured_post_effects(new_model)

        ContentLoading | ContentFailed -> effect.none()
      }

      #(
        new_model,
        effect.batch([
          route_effects,
          lightbox_scroll_lock(False),
        ]),
      )
    }

    TocActiveHeadingChanged(id) -> #(
      Model(..model, active_heading: option.Some(id)),
      effect.none(),
    )

    UserToggledTheme -> {
      let next_theme =
        next_theme_after_click(model.theme, model.system_prefers_dark)

      let new_model = Model(..model, theme: next_theme)

      #(
        new_model,
        effect.batch([
          effect.map(
            theme_effect.apply_theme_choice(next_theme),
            theme_msg_to_msg,
          ),
          mermaid_rerender_for(new_model),
        ]),
      )
    }

    ThemeLoaded(theme) -> {
      let new_model = Model(..model, theme: theme)

      #(new_model, mermaid_rerender_for(new_model))
    }

    SystemPrefersDarkChanged(prefers_dark) -> {
      let new_model = Model(..model, system_prefers_dark: prefers_dark)

      let apply_theme_effect = case new_model.theme {
        theme_effect.Auto ->
          effect.map(
            theme_effect.apply_theme_choice(new_model.theme),
            theme_msg_to_msg,
          )

        _ -> effect.none()
      }

      #(
        new_model,
        effect.batch([
          apply_theme_effect,
          mermaid_rerender_for(new_model),
        ]),
      )
    }

    NoOp -> #(model, effect.none())

    ContentLoaded(result) ->
      case result {
        Ok(content) -> {
          let runtime_config = content.config
          let application_config = runtime_config.application
          let runtime_site = runtime_config.site

          let site_meta =
            SiteMeta(
              base_url: runtime_site.base_url,
              title: application_config.title,
              description: application_config.description,
              analytics: application_config.analytics,
              comments: runtime_site.comments,
              fediverse_creator: runtime_site.fediverse_creator,
              rss_enabled: application_config.rss_enabled,
            )

          let new_model =
            Model(
              ..model,
              config: application_config,
              site_meta: site_meta,
              posts: content.posts,
              pages: content.pages,
              homepage: content.homepage,
              links: content.links,
              projects: content.projects,
              content_state: ContentReady,
              search: closed_search(),
              mobile_menu_open: False,
              toc_overlay_open: False,
              lightbox: lightbox.Closed,
            )

          #(
            new_model,
            effect.batch([
              configured_search_subscription(application_config),
              configured_analytics_effect(application_config),
              configured_lightbox_effect(application_config),
              configured_post_effects(new_model),
            ]),
          )
        }

        Error(_) -> #(
          Model(..model, content_state: ContentFailed),
          effect.none(),
        )
      }

    UserOpenedSearch ->
      case model.content_state, model.config.search_enabled {
        ContentReady, True -> #(
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

        _, _ -> #(model, effect.none())
      }

    UserClosedSearch -> #(
      Model(..model, search: closed_search()),
      effect.none(),
    )

    UserEnteredSearchQuery(query) -> {
      let results = search.search(model.posts, query)

      #(
        Model(
          ..model,
          search: SearchState(
            open: True,
            query: query,
            results: results,
            selected_index: 0,
          ),
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

    SearchKeyPressed(event) ->
      case model.config.search_enabled {
        True -> handle_search_key(model, event)
        False -> #(model, effect.none())
      }

    SearchResultClicked(slug) -> {
      let target_route = route.Post(slug)

      let new_model =
        Model(
          ..model,
          route: target_route,
          search: closed_search(),
          active_heading: option.None,
          lightbox: lightbox.Closed,
        )

      #(
        new_model,
        effect.batch([
          modem.push(route.href_url(target_route), option.None, option.None),
          configured_post_effects(new_model),
          lightbox_scroll_lock(False),
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
      let scroll_effect =
        effect.from(fn(_) {
          scroll_to_top()
          Nil
        })

      #(model, scroll_effect)
    }

    UserEnteredPageJump(page_string) ->
      case int.parse(page_string) {
        Ok(page_number) if page_number >= 1 -> {
          let target_route = route.Posts(page_number)

          let new_model =
            Model(
              ..model,
              route: target_route,
              mobile_menu_open: False,
              toc_overlay_open: False,
              lightbox: lightbox.Closed,
            )

          #(
            new_model,
            effect.batch([
              modem.push(route.href_url(target_route), option.None, option.None),
              configured_post_effects(new_model),
              lightbox_scroll_lock(False),
            ]),
          )
        }

        _ -> #(model, effect.none())
      }

    LightboxEventReceived(event) ->
      case event {
        lightbox_effect.ImageClicked(srcs, alts, index) ->
          update(model, LightboxGalleryOpened(srcs, alts, index))

        lightbox_effect.EscapePressed -> update(model, LightboxClosed)

        lightbox_effect.PreviousPressed -> update(model, LightboxPrevious)

        lightbox_effect.NextPressed -> update(model, LightboxNext)
      }

    LightboxOpened(src, alt) ->
      update(model, LightboxGalleryOpened([src], [alt], 0))

    LightboxGalleryOpened(srcs, alts, index) ->
      case model.config.lightbox_enabled {
        True -> {
          let images = lightbox_images(srcs, alts)

          case images {
            [] -> #(
              Model(..model, lightbox: lightbox.Closed),
              lightbox_scroll_lock(False),
            )

            _ -> #(
              Model(
                ..model,
                lightbox: lightbox.Open(
                  images: images,
                  index: clamp_index(index, list.length(images)),
                ),
              ),
              lightbox_scroll_lock(True),
            )
          }
        }

        False -> #(
          Model(..model, lightbox: lightbox.Closed),
          lightbox_scroll_lock(False),
        )
      }

    LightboxPrevious -> #(
      Model(..model, lightbox: lightbox_previous(model.lightbox)),
      effect.none(),
    )

    LightboxNext -> #(
      Model(..model, lightbox: lightbox_next(model.lightbox)),
      effect.none(),
    )

    LightboxClosed -> #(
      Model(..model, lightbox: lightbox.Closed),
      lightbox_scroll_lock(False),
    )
  }
}

fn configured_search_subscription(
  site_config: config.Config,
) -> effect.Effect(Msg) {
  case site_config.search_enabled {
    True ->
      effect.map(search_effect.subscribe_to_search_keys(), SearchKeyPressed)

    False -> effect.none()
  }
}

fn configured_analytics_effect(
  site_config: config.Config,
) -> effect.Effect(Msg) {
  effect.map(analytics_effect.inject(site_config.analytics), fn(_) { NoOp })
}

fn configured_lightbox_effect(
  site_config: config.Config,
) -> effect.Effect(Msg) {
  case site_config.lightbox_enabled {
    True -> effect.map(lightbox_effect.observe(), LightboxEventReceived)

    False -> effect.none()
  }
}

fn configured_post_effects(model: Model) -> effect.Effect(Msg) {
  post_effects_for(
    model.route,
    is_effective_dark(model.theme, model.system_prefers_dark),
    model.config.mathjax_enabled,
    model.config.mathjax_cdn_url,
    model.config.mermaid_enabled,
    model.config.mermaid_cdn_url,
    model.config.syntax_highlight_enabled,
    model.config.syntax_highlight_cdn_url,
  )
}

fn lightbox_scroll_lock(locked: Bool) -> effect.Effect(Msg) {
  effect.map(lightbox_effect.set_scroll_lock(locked), fn(_) { NoOp })
}

fn lightbox_images(
  srcs: List(String),
  alts: List(String),
) -> List(lightbox.Image) {
  case srcs, alts {
    [], _ -> []

    [src, ..rest_srcs], [alt, ..rest_alts] -> [
      lightbox.Image(src: src, alt: alt),
      ..lightbox_images(rest_srcs, rest_alts)
    ]

    [src, ..rest_srcs], [] -> [
      lightbox.Image(src: src, alt: ""),
      ..lightbox_images(rest_srcs, [])
    ]
  }
}

fn clamp_index(index: Int, total: Int) -> Int {
  case total <= 0 {
    True -> 0

    False -> int.max(0, int.min(index, total - 1))
  }
}

fn lightbox_previous(state: lightbox.State) -> lightbox.State {
  case state {
    lightbox.Closed -> lightbox.Closed

    lightbox.Open(images, index) -> {
      let total = list.length(images)

      case total <= 1 {
        True -> state

        False ->
          lightbox.Open(images: images, index: previous_index(index, total))
      }
    }
  }
}

fn lightbox_next(state: lightbox.State) -> lightbox.State {
  case state {
    lightbox.Closed -> lightbox.Closed

    lightbox.Open(images, index) -> {
      let total = list.length(images)

      case total <= 1 {
        True -> state

        False -> lightbox.Open(images: images, index: next_index(index, total))
      }
    }
  }
}

fn previous_index(index: Int, total: Int) -> Int {
  case index <= 0 {
    True -> total - 1
    False -> index - 1
  }
}

fn next_index(index: Int, total: Int) -> Int {
  case index >= total - 1 {
    True -> 0
    False -> index + 1
  }
}

fn post_effects_for(
  route: Route,
  is_dark: Bool,
  mathjax_enabled: Bool,
  mathjax_cdn_url: String,
  mermaid_enabled: Bool,
  mermaid_cdn_url: String,
  syntax_highlight_enabled: Bool,
  syntax_highlight_cdn_url: String,
) -> effect.Effect(Msg) {
  case route {
    Post(_) -> {
      let mathjax_effect = case mathjax_enabled {
        True ->
          effect.map(script_effect.typeset_math(mathjax_cdn_url), fn(_) { NoOp })

        False -> effect.none()
      }

      let mermaid_effect = case mermaid_enabled {
        True ->
          effect.map(
            script_effect.render_mermaid(is_dark, mermaid_cdn_url),
            fn(_) { NoOp },
          )

        False -> effect.none()
      }

      let syntax_highlight_effect =
        effect.map(
          syntax_highlight_effect.enhance(
            syntax_highlight_enabled,
            syntax_highlight_cdn_url,
          ),
          fn(_) { NoOp },
        )

      effect.batch([
        effect.map(toc_effect.observe(), TocActiveHeadingChanged),
        syntax_highlight_effect,
        effect.map(codeblock_effect.enhance(), fn(_) { NoOp }),
        effect.map(note_effect.enhance(), fn(_) { NoOp }),
        mathjax_effect,
        mermaid_effect,
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
  case model.content_state, model.route, model.config.mermaid_enabled {
    ContentReady, Post(_), True ->
      effect.map(
        script_effect.render_mermaid(
          is_effective_dark(model.theme, model.system_prefers_dark),
          model.config.mermaid_cdn_url,
        ),
        fn(_) { NoOp },
      )

    _, _, _ -> effect.none()
  }
}

fn theme_msg_to_msg(theme_message: theme_effect.ThemeMsg) -> Msg {
  case theme_message {
    theme_effect.ThemeLoaded(theme) -> ThemeLoaded(theme: theme)

    theme_effect.SystemPrefersDarkChanged(prefers_dark) ->
      SystemPrefersDarkChanged(prefers_dark: prefers_dark)
  }
}

fn content_msg_to_msg(content_message: content_runtime.ContentMsg) -> Msg {
  case content_message {
    content_runtime.ContentLoaded(result) ->
      ContentLoaded(
        result
        |> result.map_error(fn(_) { Nil }),
      )
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
      let maximum = list.length(model.search.results) - 1

      let next = int.max(0, int.min(model.search.selected_index + 1, maximum))

      #(
        Model(
          ..model,
          search: SearchState(..model.search, selected_index: next),
        ),
        effect.none(),
      )
    }

    "ArrowUp", _, True -> {
      let previous = int.max(model.search.selected_index - 1, 0)

      #(
        Model(
          ..model,
          search: SearchState(..model.search, selected_index: previous),
        ),
        effect.none(),
      )
    }

    "Enter", _, True ->
      case
        list.first(list.drop(model.search.results, model.search.selected_index))
      {
        Ok(search_result) -> {
          let target_route = route.Post(search_result.post.slug)

          let new_model =
            Model(
              ..model,
              route: target_route,
              search: closed_search(),
              active_heading: option.None,
              lightbox: lightbox.Closed,
            )

          #(
            new_model,
            effect.batch([
              modem.push(route.href_url(target_route), option.None, option.None),
              configured_post_effects(new_model),
              lightbox_scroll_lock(False),
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

  let search_modal_element = case model.config.search_enabled {
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
            key: key,
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

  let toc_fab_elements = case
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
          [
            fonts_style,
            header.view(
              model.config,
              model.route,
              model.theme,
              is_effective_dark(model.theme, model.system_prefers_dark),
              event.on_click(UserToggledTheme),
              event.on_click(UserOpenedSearch),
              event.on_click(UserToggledMobileMenu),
              model.mobile_menu_open,
            ),
            main_content,
          ],
          right_content,
        ),
      ],
      [search_modal_element],
      toc_fab_elements,
      [
        lightbox.view(
          model.lightbox,
          LightboxClosed,
          LightboxPrevious,
          LightboxNext,
        ),
      ],
    ]),
  )
}

fn view_route_content(model: Model) -> #(Element(Msg), Element(Msg)) {
  case model.route {
    Home -> {
      let statistics =
        aratafetch.from_content(
          model.links,
          model.posts,
          model.projects,
          model.site_meta.title,
          model.site_meta.description,
          model.site_meta.base_url,
          model.config.aratafetch_maintained_for,
        )

      let aratafetch_element =
        aratafetch.view(model.config.aratafetch_enabled, statistics)

      #(
        home_view.view(
          model.homepage,
          model.posts,
          model.config.latest_posts_enabled,
          model.config.latest_posts_count,
          model.config.aratafetch_enabled,
          aratafetch_element,
        ),
        none(),
      )
    }

    Posts(page_number) -> #(
      post_list.view(
        model.posts,
        page_number,
        posts_per_page,
        UserEnteredPageJump,
      ),
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
                        [
                          attribute.class("toc-overlay-content"),
                        ],
                        list.flatten([
                          [
                            html.div(
                              [
                                attribute.class("toc-overlay-header"),
                              ],
                              [
                                html.button(
                                  [
                                    attribute.class("toc-overlay-scroll-top"),
                                    event.on_click(UserScrolledToTop),
                                  ],
                                  [html.text("↑")],
                                ),
                              ],
                            ),
                          ],
                          case found.tags {
                            [] -> []

                            _ -> [
                              view_tags_sidebar(found.tags),
                            ]
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
  html.main([attribute.class("page-header")], [])
}

fn view_content_failed() -> Element(Msg) {
  html.main([attribute.class("not-found-header")], [
    html.div([attribute.class("page-header")], [
      html.text("Content failed to load"),
    ]),
    html.span([], [
      html.text("Could not fetch or decode content_index.json."),
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
          html.a(
            [
              attribute.class("tag"),
              route.href(route.Tag(tag)),
            ],
            [html.text(tag)],
          )
        })
      ])
  }
}
