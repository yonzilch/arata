//// Site configuration: title, description, navigation menu, socials, and logo.
////
//// This module mirrors the shape of apollo's `config.toml` `[extra]` block.
//// For now it returns hardcoded defaults; Phase 4 replaces `default/0` with a
//// JSON loader that reads a `config.json` shipped alongside the content index.
////
//// The `Social.icon` field is the filename (without extension) of an SVG in
//// `static/icons/social/` — e.g. `icon: "github"` resolves to
//// `/icons/social/github.svg`. This matches apollo's `get_url(path='icons/social/' ~ social.icon ~ '.svg')`.

import gleam/option.{type Option, None}

pub type Social {
  Social(name: String, url: String, icon: String)
}

pub type MenuItem {
  MenuItem(name: String, url: String)
}

pub type Config {
  Config(
    title: String,
    description: String,
    menu: List(MenuItem),
    socials: List(Social),
    /// Optional logo path (relative to `/`). When `None`, the site title is
    /// rendered as a text link in the nav.
    logo: Option(String),
  )
}

/// Hardcoded default config. Replaced by JSON loading in Phase 4.
pub fn default() -> Config {
  Config(
    title: "arata",
    description: "A blog built with Gleam and Lustre.",
    menu: [
      MenuItem(name: "posts", url: "/posts"),
      MenuItem(name: "projects", url: "/projects"),
      MenuItem(name: "links", url: "/links"),
      MenuItem(name: "about", url: "/about"),
    ],
    socials: [
      Social(
        name: "GitHub",
        url: "https://github.com/yonzilch/arata",
        icon: "github",
      ),
      Social(name: "RSS", url: "/atom.xml", icon: "rss"),
    ],
    logo: None,
  )
}
