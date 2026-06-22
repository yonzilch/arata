//// Site header / nav: logo or site title, socials, menu, search trigger, and
//// theme toggle.
////
//// Mirrors apollo's `templates/partials/nav.html` structure: a `<nav>` with
//// `.left-nav` (site title or logo + `.socials`) and `.right-nav` (menu items
//// + search button + theme toggle).
////
//// Internal links use `route.href/1` so modem intercepts them for client-side
//// navigation. Social links are external and use `attribute.href/1` directly
//// with `rel="me"` (apollo's default). The search button is wired via the
//// `on_open_search` attribute parameter (Phase 12); the theme toggle is
//// wired via the `on_toggle_theme` attribute parameter (Phase 10).

import config.{type Config}
import gleam/list
import gleam/option
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import route.{type Route, Home, Links, Page, Post, Posts, Projects}

/// Render the site header (`<nav>`).
///
/// `current_route` is passed in so the active menu item can be highlighted
/// with an `active` class (apollo itself does not highlight the active nav
/// item; this is a small arata addition for better wayfinding).
pub fn view(
  config: Config,
  current_route: Route,
  on_toggle_theme: Attribute(msg),
  on_open_search: Attribute(msg),
) -> Element(msg) {
  html.nav([], [
    html.div([attribute.class("left-nav")], [
      view_site_title(config),
      html.div([attribute.class("socials")], view_socials(config.socials)),
    ]),
    html.div(
      [attribute.class("right-nav")],
      // Menu items (internal links) followed by the search button (wired via
      // on_open_search) and the theme toggle (wired via on_toggle_theme).
      list.append(view_menu(config.menu, current_route), [
        view_search_button(on_open_search),
        view_theme_toggle(on_toggle_theme),
      ]),
    ),
  ])
}

/// Whether the menu item with `url` is the active nav entry for
/// `current_route`. Matches apollo's URL scheme:
///
///   "/"          -> Home
///   "/posts"     -> Posts(_) or Post(_) (single posts are still in the
///                   posts section, so the section link stays active)
///   "/projects"  -> Projects
///   "/links"     -> Links
///   "/about"     -> Page("about")
///
/// `/projects/{slug}` parses as `Page(slug)` rather than `Projects`, so the
/// section link only highlights on the section index itself (matching
/// apollo's section/page distinction). A future phase can refine this if
/// desired.
fn is_active(current_route: Route, url: String) -> Bool {
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
    "/about" ->
      case current_route {
        Page("about") -> True
        _ -> False
      }
    _ -> False
  }
}

// LEFT NAV ---------------------------------------------------------------------

fn view_site_title(config: Config) -> Element(msg) {
  case config.logo {
    option.Some(path) ->
      html.a([route.href(route.Home), attribute.class("logo")], [
        html.img([attribute.alt(config.title), attribute.src(path)]),
      ])
    option.None -> html.a([route.href(route.Home)], [html.text(config.title)])
  }
}

fn view_socials(socials: List(config.Social)) -> List(Element(msg)) {
  list.map(socials, fn(social) {
    html.a(
      [
        attribute.class("social"),
        attribute.href(social.url),
        attribute.rel("me"),
      ],
      [
        html.img([
          attribute.alt(social.name),
          attribute.src("/icons/social/" <> social.icon <> ".svg"),
        ]),
      ],
    )
  })
}

// RIGHT NAV --------------------------------------------------------------------

fn view_menu(
  menu: List(config.MenuItem),
  current_route: Route,
) -> List(Element(msg)) {
  list.map(menu, fn(item) {
    // Menu URLs are same-origin paths; modem intercepts the click and routes
    // through `parse_route`. Using `attribute.href` (rather than `route.href`)
    // because the URL is a raw string from config, not a typed `Route`.
    //
    // The `active` class is added (via `attribute.classes`) when this item's
    // URL matches `current_route` per `is_active`; `arata.css` paints an
    // active item with `--primary-color`.
    html.a(
      [
        attribute.href(item.url),
        attribute.style("margin-right", "0.5em"),
        attribute.classes([#("active", is_active(current_route, item.url))]),
      ],
      [html.text(item.name)],
    )
  })
}

fn view_search_button(on_open: Attribute(msg)) -> Element(msg) {
  html.button(
    [
      attribute.id("search-button"),
      attribute.class("search-button"),
      attribute.title("Cmd/Ctrl+K to open search"),
      on_open,
    ],
    [
      html.img([
        attribute.src("/icons/search.svg"),
        attribute.alt("Search"),
        attribute.class("search-icon"),
      ]),
    ],
  )
}

fn view_theme_toggle(on_toggle: Attribute(msg)) -> Element(msg) {
  // apollo renders this as an `<a id="dark-mode-toggle">` with inline
  // `onclick`. arata uses a `<button>` carrying both the apollo id and a class
  // so the ported CSS (`#dark-mode-toggle`) applies. The `on_toggle` attribute
  // (an `event.on_click(UserToggledTheme)` from the caller) dispatches the
  // theme-cycle message. Three icons (sun/moon/auto) are rendered; the FFI
  // shows/hides them based on the current theme.
  html.button(
    [
      attribute.id("dark-mode-toggle"),
      attribute.class("theme-toggle"),
      on_toggle,
    ],
    [
      html.img([
        attribute.src("/icons/sun.svg"),
        attribute.id("sun-icon"),
        attribute.alt("Light"),
      ]),
      html.img([
        attribute.src("/icons/moon.svg"),
        attribute.id("moon-icon"),
        attribute.alt("Dark"),
      ]),
      html.img([
        attribute.src("/icons/auto.svg"),
        attribute.id("auto-icon"),
        attribute.alt("Auto"),
      ]),
    ],
  )
}
