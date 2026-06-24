//// Lightbox effect: bridges DOM image clicks from Markdown bodies into the
//// Lustre update loop.
////
//// The rendered post/page body uses `unsafe_raw_html`, so images inside
//// `.body` are not created by Lustre and cannot receive `event.on_click`
//// directly. This effect asks the JavaScript FFI to observe clicks on
//// `.body img` and dispatch typed Gleam events back to the app.
////
//// Important FFI invariant:
//// JavaScript arrays are not Gleam lists. The FFI sends gallery src/alt data
//// as separator-joined strings, and this module splits them back into real
//// Gleam `List(String)` values before dispatching `ImageClicked`.

import gleam/string
import lustre/effect.{type Effect}

const field_separator = "\u{001e}"

pub type Event {
  ImageClicked(srcs: List(String), alts: List(String), index: Int)
  EscapePressed
  PreviousPressed
  NextPressed
}

/// Subscribe to Markdown body image clicks and lightbox keyboard events.
///
/// The FFI is idempotent: repeated calls update callbacks but do not register
/// duplicate DOM listeners.
pub fn observe() -> Effect(Event) {
  use dispatch <- effect.from

  subscribe_to_lightbox_events(
    fn(srcs_blob, alts_blob, index) {
      dispatch(ImageClicked(
        srcs: split_blob(srcs_blob),
        alts: split_blob(alts_blob),
        index: index,
      ))
    },
    fn() { dispatch(EscapePressed) },
    fn() { dispatch(PreviousPressed) },
    fn() { dispatch(NextPressed) },
  )

  Nil
}

/// Toggle page scroll locking while the lightbox is open.
pub fn set_scroll_lock(locked: Bool) -> Effect(Nil) {
  use _ <- effect.from
  set_lightbox_scroll_lock(locked)
  Nil
}

fn split_blob(blob: String) -> List(String) {
  case blob {
    "" -> []

    _ -> string.split(blob, field_separator)
  }
}

@external(javascript, "../ffi/lightbox.ffi.mjs", "subscribe_to_lightbox_events")
fn subscribe_to_lightbox_events(
  on_open: fn(String, String, Int) -> Nil,
  on_close: fn() -> Nil,
  on_previous: fn() -> Nil,
  on_next: fn() -> Nil,
) -> Nil

@external(javascript, "../ffi/lightbox.ffi.mjs", "set_lightbox_scroll_lock")
fn set_lightbox_scroll_lock(locked: Bool) -> Nil
