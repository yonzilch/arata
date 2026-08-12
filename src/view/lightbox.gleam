//// Lightbox view: renders an image overlay controlled by the Lustre model.
////
//// The lightbox state is owned by `arata.gleam`. JavaScript FFI should only
//// detect clicks on Markdown body images and dispatch gallery data back into
//// the app. The FFI also applies the zoom transform to the rendered image;
//// Lustre tracks a coarse `zoomed` flag so the overlay can reset zoom on
//// close, navigation, and gallery changes.
////
//// Invariants:
////   - Closed renders `none()`
////   - Open renders one fixed-position overlay
////   - Open stores a page-local image gallery, the current index, and whether
////     the preview is zoomed
////   - the current image is selected safely from the gallery
////   - the caption is derived from image alt/title text supplied by the FFI
////   - closing/previous/next are represented by messages provided by caller
////   - previous/next always reset zoom to fit
////
//// Interaction model:
////   - close button closes the overlay
////   - backdrop button closes the overlay
////   - clicking the image/dialog itself does not close via bubbling
////   - previous/next buttons are shown only when there is more than one image
////   - keyboard previous/next is handled by FFI + arata.gleam
////   - zoom toggling/panning is handled by the FFI on the rendered DOM

import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html
import lustre/event

pub type Image {
  Image(src: String, alt: String)
}

pub type State {
  Closed
  Open(images: List(Image), index: Int, zoomed: Bool)
}

/// Move to the previous image, resetting zoom to fit.
pub fn previous(state: State) -> State {
  case state {
    Closed -> Closed

    Open(..) as open -> {
      let total = list.length(open.images)

      case total <= 1 {
        True -> state

        False ->
          Open(..open, index: previous_index(open.index, total), zoomed: False)
      }
    }
  }
}

/// Move to the next image, resetting zoom to fit.
pub fn next(state: State) -> State {
  case state {
    Closed -> Closed

    Open(..) as open -> {
      let total = list.length(open.images)

      case total <= 1 {
        True -> state

        False ->
          Open(..open, index: next_index(open.index, total), zoomed: False)
      }
    }
  }
}

/// Update the zoomed flag. The FFI applies the visual transform and reports
/// zoom state changes back through this function.
pub fn set_zoomed(state: State, zoomed: Bool) -> State {
  case state {
    Closed -> Closed

    Open(..) as open -> Open(..open, zoomed: zoomed)
  }
}

pub fn view(
  state: State,
  on_close: msg,
  on_previous: msg,
  on_next: msg,
) -> Element(msg) {
  case state {
    Closed -> none()

    Open(images, index, zoomed) ->
      case current_image(images, index) {
        Ok(#(image, safe_index, total)) ->
          view_open(
            image,
            safe_index,
            total,
            zoomed,
            on_close,
            on_previous,
            on_next,
          )

        Error(Nil) -> none()
      }
  }
}

fn view_open(
  image: Image,
  index: Int,
  total: Int,
  zoomed: Bool,
  on_close: msg,
  on_previous: msg,
  on_next: msg,
) -> Element(msg) {
  let frame_attributes = case zoomed {
    True -> [
      attribute.class("lightbox-image-frame"),
      attribute.class("lightbox-image-frame--zoomed"),
    ]

    False -> [attribute.class("lightbox-image-frame")]
  }

  html.div(
    [
      attribute.class("lightbox-backdrop"),
      attribute.attribute("role", "presentation"),
    ],
    [
      html.button(
        [
          attribute.class("lightbox-backdrop-close"),
          attribute.type_("button"),
          attribute.attribute("aria-label", "Close image preview"),
          event.on_click(on_close),
        ],
        [],
      ),
      html.div(
        [
          attribute.class("lightbox-dialog"),
          attribute.attribute("role", "dialog"),
          attribute.attribute("aria-modal", "true"),
          attribute.attribute("aria-label", aria_label(image.alt)),
        ],
        [
          html.button(
            [
              attribute.class("lightbox-close"),
              attribute.type_("button"),
              attribute.attribute("aria-label", "Close image preview"),
              attribute.attribute("autofocus", "true"),
              event.on_click(on_close),
            ],
            [html.text("×")],
          ),
          html.div(
            [
              attribute.attribute("data-lightbox-src", image.src),
              ..frame_attributes
            ],
            [
              html.img([
                attribute.class("lightbox-image"),
                attribute.src(image.src),
                attribute.alt(image.alt),
                attribute.attribute("decoding", "async"),
                attribute.attribute("loading", "eager"),
              ]),
            ],
          ),
          view_caption(image.alt),
          view_gallery_footer(index, total, on_previous, on_next),
        ],
      ),
    ],
  )
}

fn view_gallery_footer(
  index: Int,
  total: Int,
  on_previous: msg,
  on_next: msg,
) -> Element(msg) {
  case total > 1 {
    True ->
      html.div([attribute.class("lightbox-footer")], [
        html.button(
          [
            attribute.class("lightbox-nav"),
            attribute.class("lightbox-prev"),
            attribute.type_("button"),
            attribute.attribute("aria-label", "Previous image"),
            event.on_click(on_previous),
          ],
          [],
        ),
        html.div([attribute.class("lightbox-counter")], [
          html.text(int.to_string(index + 1)),
          html.text(" / "),
          html.text(int.to_string(total)),
        ]),
        html.button(
          [
            attribute.class("lightbox-nav"),
            attribute.class("lightbox-next"),
            attribute.type_("button"),
            attribute.attribute("aria-label", "Next image"),
            event.on_click(on_next),
          ],
          [],
        ),
      ])

    False -> none()
  }
}

fn current_image(
  images: List(Image),
  index: Int,
) -> Result(#(Image, Int, Int), Nil) {
  let total = list.length(images)

  case total <= 0 {
    True -> Error(Nil)

    False -> {
      let safe_index = clamp_index(index, total)

      case list.first(list.drop(images, safe_index)) {
        Ok(image) -> Ok(#(image, safe_index, total))

        Error(Nil) -> Error(Nil)
      }
    }
  }
}

fn clamp_index(index: Int, total: Int) -> Int {
  case total <= 0 {
    True -> 0

    False -> int.max(0, int.min(index, total - 1))
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

fn view_caption(alt: String) -> Element(msg) {
  case alt {
    "" -> none()

    _ ->
      html.p([attribute.class("lightbox-caption")], [
        html.text(alt),
      ])
  }
}

fn aria_label(alt: String) -> String {
  case alt {
    "" -> "Image preview"

    _ -> "Image preview: " <> alt
  }
}
