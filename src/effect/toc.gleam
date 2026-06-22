//// Table-of-contents effect: sets up an IntersectionObserver over the
//// rendered post body and dispatches the active heading's id as a `String`,
//// which the caller maps into a `Msg` via `effect.map`.
////
//// Mirrors apollo's `static/js/toc.js` behaviour, but uses the idiomatic
//// Lustre approach: side effects are data (an `Effect(Msg)`), and the
//// observer calls `dispatch` to feed results back into `update` rather than
//// manipulating DOM classes directly. The `view/toc.gleam` module then
//// applies `.selected` / `.parent` classes declaratively from the model.
////
//// The FFI lives in `src/ffi/observer.ffi.mjs`. The `@external` declaration
//// has a no-op Gleam fallback body so the project still builds when targeting
//// Erlang (the observer only runs in the browser).

import lustre/effect.{type Effect}

/// Start observing the post body for scroll-driven TOC highlighting.
///
/// Returns an effect that, when run in the browser, installs an
/// IntersectionObserver over `main section.body` and dispatches the id of the
/// topmost visible heading as a `String`. The caller wraps this with
/// `effect.map(observe(), TocActiveHeadingChanged)` to turn the `String` into a
/// typed message. On Erlang (or if the body element is absent) the effect is a
/// no-op.
pub fn observe() -> Effect(String) {
  use dispatch <- effect.from
  observe_toc(dispatch)
  Nil
}

@external(javascript, "ffi/observer.ffi.mjs", "observe_toc")
fn observe_toc(dispatch: fn(String) -> Nil) -> Nil
