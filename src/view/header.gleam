//// Site header / nav: logo or site title, socials, menu, search trigger, and
//// theme toggle.
////
//// Mirrors apollo's `templates/partials/nav.html` structure: a `<nav>` with
//// `.left-nav` (site title or logo + `.socials`) and `.right-nav` (menu items
//// + search button + theme toggle).
////
//// Internal links use configured menu URLs and modem intercepts them for
//// client-side navigation. Root-relative runtime assets and social feed links
//// are resolved through `Config.base_path` so project-site deployments such as
//// GitHub Pages under `/arata` do not request assets from the domain root.

import config.{type Config}
import effect/theme as theme_effect
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import route.{type Route, Home, Links, Page, Post, Posts, Projects, Tag, Tags}

/// Render the site header (`<nav>`).
///
/// `current_route` is passed in so the active menu item can be highlighted
/// with an `active` class.
///
/// `on_toggle_menu` is wired to the mobile hamburger button. `mobile_menu_open`
/// adds a `mobile-open` class to `.right-nav` so the dropdown shows on mobile.
///
/// `site_config.navbar_fixed` controls whether the nav stays pinned while the
/// page scrolls. The CSS layer owns the actual positioning behavior:
///
///   True  -> `.navbar-fixed`
///   False -> `.navbar-static`
pub fn view(
  site_config: Config,
  current_route: Route,
  current_theme: theme_effect.Theme,
  effective_dark: Bool,
  on_toggle_theme: Attribute(msg),
  on_open_search: Attribute(msg),
  on_toggle_menu: Attribute(msg),
  mobile_menu_open: Bool,
) -> Element(msg) {
  html.nav(
    [
      attribute.classes([
        #("navbar-fixed", site_config.navbar_fixed),
        #("navbar-static", bool_negate(site_config.navbar_fixed)),
      ]),
    ],
    [
      html.div([attribute.class("left-nav")], [
        view_site_title(site_config),
        html.div(
          [attribute.class("socials")],
          view_socials(site_config, site_config.socials),
        ),
      ]),
      html.button(
        [
          attribute.class("mobile-menu-btn"),
          attribute.type_("button"),
          attribute.attribute("aria-label", "Toggle menu"),
          attribute.attribute("aria-expanded", bool_to_attr(mobile_menu_open)),
          on_toggle_menu,
        ],
        [html.text("☰")],
      ),
      html.div(
        [
          attribute.classes([
            #("right-nav", True),
            #("mobile-open", mobile_menu_open),
          ]),
        ],
        list.flatten([
          view_menu(site_config.menu, current_route, site_config.base_path),
          case site_config.search_enabled {
            True -> [view_search_button(site_config, on_open_search)]
            False -> []
          },
          [
            view_theme_toggle(
              site_config,
              current_theme,
              effective_dark,
              on_toggle_theme,
            ),
          ],
        ]),
      ),
    ],
  )
}

fn bool_to_attr(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

fn bool_negate(b: Bool) -> Bool {
  case b {
    True -> False
    False -> True
  }
}

/// Resolve a site-local URL against the configured deployment base path.
///
/// External URLs are returned unchanged:
///
///   https://github.com/... -> https://github.com/...
///
/// Root-relative URLs are prefixed:
///
///   /rss.xml -> /arata/rss.xml
///   /icons/search.svg -> /arata/icons/search.svg
///
/// Already-prefixed URLs are returned unchanged to avoid `/arata/arata/...`.
fn resolve_site_url(site_config: Config, url: String) -> String {
  let base_path = config.normalize_base_path(site_config.base_path)

  case string.starts_with(url, "/") {
    False -> url

    True ->
      case
        base_path != ""
        && { url == base_path || string.starts_with(url, base_path <> "/") }
      {
        True -> url

        False -> config.with_base_path(base_path, url)
      }
  }
}

/// Strip the configured base path before comparing a configured menu URL with
/// the internal typed `Route`.
///
/// Example:
///
///   /arata/posts -> /posts
fn strip_base_path(path: String, base_path: String) -> String {
  let base_path = config.normalize_base_path(base_path)

  case base_path {
    "" -> path

    _ ->
      case path == base_path {
        True -> "/"

        False ->
          case string.starts_with(path, base_path <> "/") {
            True -> {
              let base_len = string.length(base_path)
              string.slice(path, base_len, string.length(path) - base_len)
            }

            False -> path
          }
      }
  }
}

/// Whether the menu item with `url` is the active nav entry for
/// `current_route`.
fn is_active(current_route: Route, url: String, base_path: String) -> Bool {
  let url = strip_base_path(url, base_path)

  case url {
    "/" ->
      case current_route {
        Home -> True
        _ -> False
      }

    "/posts" ->
      case current_route {
        Posts(_) -> True
        Post(_) -> True
        _ -> False
      }

    "/projects" ->
      case current_route {
        Projects -> True
        _ -> False
      }

    "/links" ->
      case current_route {
        Links -> True
        _ -> False
      }

    "/tags" ->
      case current_route {
        Tags -> True
        Tag(_) -> True
        _ -> False
      }

    "/about" ->
      case current_route {
        Page("about") -> True
        _ -> False
      }

    _ -> False
  }
}

// LEFT NAV ---------------------------------------------------------------------

fn view_site_title(site_config: Config) -> Element(msg) {
  case site_config.logo {
    option.Some(path) ->
      html.a([route.href(route.Home), attribute.class("logo")], [
        html.img([
          attribute.alt(site_config.title),
          attribute.src(resolve_site_url(site_config, path)),
        ]),
      ])

    option.None ->
      html.a([route.href(route.Home)], [html.text(site_config.title)])
  }
}

fn view_socials(
  site_config: Config,
  socials: List(config.Social),
) -> List(Element(msg)) {
  list.map(socials, fn(social) {
    html.a(
      [
        attribute.class("social"),
        attribute.href(resolve_site_url(site_config, social.url)),
        attribute.target("_blank"),
        attribute.rel("noopener"),
      ],
      [
        html.img([
          attribute.alt(social.name),
          attribute.src(resolve_site_url(
            site_config,
            "/icons/social/" <> social.icon <> ".svg",
          )),
        ]),
      ],
    )
  })
}

// RIGHT NAV --------------------------------------------------------------------

fn view_menu(
  menu: List(config.MenuItem),
  current_route: Route,
  base_path: String,
) -> List(Element(msg)) {
  list.map(menu, fn(item) {
    html.a(
      [
        attribute.href(item.url),
        attribute.style("margin-right", "0.5em"),
        attribute.classes([
          #("active", is_active(current_route, item.url, base_path)),
        ]),
      ],
      [html.text(item.name)],
    )
  })
}

fn view_search_button(
  site_config: Config,
  on_open: Attribute(msg),
) -> Element(msg) {
  html.button(
    [
      attribute.id("search-button"),
      attribute.class("search-button"),
      attribute.title("Cmd/Ctrl+K to open search"),
      on_open,
    ],
    [
      html.img([
        attribute.src(resolve_site_url(site_config, "/icons/search.svg")),
        attribute.alt("Search"),
        attribute.class("search-icon"),
      ]),
    ],
  )
}

fn view_theme_toggle(
  site_config: Config,
  current_theme: theme_effect.Theme,
  _effective_dark: Bool,
  on_toggle: Attribute(msg),
) -> Element(msg) {
  let #(icon_path, icon_id, icon_alt) = case current_theme {
    theme_effect.Light -> #("/icons/sun.svg", "sun-icon", "Light")

    theme_effect.Dark -> #("/icons/moon.svg", "moon-icon", "Dark")

    theme_effect.Auto -> #("/icons/auto.svg", "auto-icon", "Auto")
  }

  html.button(
    [
      attribute.id("dark-mode-toggle"),
      attribute.class("theme-toggle"),
      attribute.attribute("aria-label", "Toggle theme"),
      attribute.title("Toggle theme"),
      on_toggle,
    ],
    [
      html.img([
        attribute.src(resolve_site_url(site_config, icon_path)),
        attribute.id(icon_id),
        attribute.alt(icon_alt),
        attribute.style("display", "block"),
        attribute.style("filter", theme_icon_filter(current_theme)),
      ]),
    ],
  )
}

fn theme_icon_filter(theme: theme_effect.Theme) -> String {
  case theme {
    theme_effect.Light -> "none"
    theme_effect.Dark -> "invert(1)"
    theme_effect.Auto -> "invert(1)"
  }
}
