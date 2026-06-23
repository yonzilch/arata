//// Content model for a project (card), mirroring apollo's cards frontmatter.
////
//// apollo renders projects with the `cards.html` template in a column-balanced
//// card grid. Each card optionally shows media (image/video), a title (linked
//// externally via `link_to` or internally to a detail page), a tagline, and a
//// footer with GitHub/Demo icon-buttons and tag chips.

import gleam/option.{type Option}

/// A project card.
pub type Project {
  Project(
    slug: String,
    title: String,
    description: String,
    /// External link (apollo's `link_to`). When set, the card title links here
    /// and the `↗` external indicator is shown. When `None`, the title links
    /// to the internal project page `/{slug}`.
    link_to: Option(String),
    /// Optional remote image URL for the card media.
    image: Option(String),
    /// Optional GitHub URL for the icon-button.
    github: Option(String),
    /// Optional GitLab URL for the icon-button (Fix 13).
    gitlab: Option(String),
    /// Optional Codeberg URL for the icon-button (Fix 13).
    codeberg: Option(String),
    /// Optional Forgejo URL for the icon-button (Fix 13).
    forgejo: Option(String),
    /// Optional demo URL for the icon-button.
    demo: Option(String),
    /// Inline tag chips shown on the card footer.
    tags: List(String),
  )
}
