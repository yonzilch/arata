//// Content model for a friend link, rendered on the /links page.

import gleam/option.{type Option}

pub type Link {
  Link(title: String, url: String, description: String, image: Option(String))
}
