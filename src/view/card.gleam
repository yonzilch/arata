//// Project card view: renders a single project as a `.card`, mirroring
//// apollo's `templates/cards.html` per-card structure.
////
//// Each card optionally shows media (image), a title (linked externally via
//// `link_to` or internally to `/{slug}`), a tagline description, and a footer
//// with GitHub/Demo icon-buttons and `#tag` chips.

import data/project.{type Project}
import gleam/list
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html
import view/icon_button

/// Render a single project card.
pub fn view(project: Project) -> Element(msg) {
  html.div([attribute.class("card")], [
    view_media(project.image, project.title),
    html.div([attribute.class("card-content")], [
      html.h1([attribute.class("card-title")], [view_title(project)]),
      view_tagline(project.description),
      view_footer(project),
    ]),
  ])
}

/// The card media: an image when `image` is set, otherwise nothing.
fn view_media(image: Option(String), alt: String) -> Element(msg) {
  case image {
    option.Some(src) ->
      html.div([attribute.class("card-media")], [
        html.img([
          attribute.class("card-image"),
          attribute.alt(alt),
          attribute.src(src),
        ]),
      ])
    option.None -> none()
  }
}

/// The card title as a link. External `link_to` opens in a new tab; otherwise
/// the title links to the internal project page `/{slug}` via modem.
fn view_title(project: Project) -> Element(msg) {
  case project.link_to {
    option.Some(url) ->
      html.a(
        [
          attribute.href(url),
          attribute.target("_blank"),
          attribute.rel("noopener"),
        ],
        [
          html.text(project.title),
        ],
      )
    option.None ->
      html.a([attribute.href("/" <> project.slug)], [html.text(project.title)])
  }
}

/// The card tagline (description). apollo wraps it in `<p class="card-tagline">`.
fn view_tagline(description: String) -> Element(msg) {
  case description {
    "" -> none()
    _ -> html.p([attribute.class("card-tagline")], [html.text(description)])
  }
}

/// The card footer: GitHub/GitLab/Codeberg/Forgejo/Demo icon-buttons and tag
/// chips. Shown only when the project has at least one of these.
fn view_footer(project: Project) -> Element(msg) {
  let links =
    view_links(
      project.github,
      project.gitlab,
      project.codeberg,
      project.forgejo,
      project.demo,
    )
  let tags = view_tags(project.tags)
  case list.is_empty(links) && tags == none() {
    True -> none()
    False ->
      html.div([attribute.class("card-footer")], [
        html.div([attribute.class("card-links")], links),
        tags,
      ])
  }
}

/// The GitHub, GitLab, Codeberg, Forgejo, and Demo icon-buttons, if their URLs
/// are set (Fix 13 added gitlab/codeberg/forgejo).
fn view_links(
  github: Option(String),
  gitlab: Option(String),
  codeberg: Option(String),
  forgejo: Option(String),
  demo: Option(String),
) -> List(Element(msg)) {
  let gh = case github {
    option.Some(url) -> [icon_button.view(url, "GitHub", "github")]
    option.None -> []
  }
  let gl = case gitlab {
    option.Some(url) -> [icon_button.view(url, "GitLab", "gitlab")]
    option.None -> []
  }
  let cb = case codeberg {
    option.Some(url) -> [icon_button.view(url, "Codeberg", "codeberg")]
    option.None -> []
  }
  let fj = case forgejo {
    option.Some(url) -> [icon_button.view(url, "Forgejo", "forgejo")]
    option.None -> []
  }
  let dm = case demo {
    option.Some(url) -> [icon_button.view(url, "Demo", "globe")]
    option.None -> []
  }
  list.flatten([gh, gl, cb, fj, dm])
}

/// The `#tag` chips, capped at 4 (apollo slices to 4). Each is a
/// `<span class="card-tag">` (not a link — apollo's card tags are decorative).
fn view_tags(tags: List(String)) -> Element(msg) {
  case tags {
    [] -> none()
    _ ->
      html.div([attribute.class("card-tags")], [
        list.map(list.take(tags, 4), fn(tag) {
          html.span([attribute.class("card-tag")], [html.text("#" <> tag)])
        })
        |> element_fragment,
      ])
  }
}

/// Wrap a list of elements into a single Element via a fragment, so the
/// tag chips sit as siblings inside `.card-tags`.
fn element_fragment(children: List(Element(msg))) -> Element(msg) {
  html.div([], children)
}
