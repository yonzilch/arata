//// Fragment navigation effect: owns URL-fragment updates and centered
//// scrolling for table-of-contents navigation.
////
//// ToC links are intercepted by the view (`view/toc.gleam`) and dispatched
//// to the app, which runs `set_hash` (pushState — the fragment stays in the
//// URL without a full-page navigation) and `scroll_to` (the target heading
//// scrolls to the vertical center of the viewport).
////
//// The FFI lives in `src/ffi/fragment.ffi.mjs`. It:
////
////   - scrolls to the fragment respecting `prefers-reduced-motion` (instant
////     jump instead of smooth scrolling);
////   - safely no-ops on missing/stale fragment targets (never throws);
////   - restores the fragment target after runtime content has mounted
////     (direct loads and refreshes of URLs with a heading fragment);
////   - subscribes to `hashchange` so browser back/forward navigation restores
////     the corresponding fragment target.
////
//// The `@external` declarations have no Gleam fallback bodies because the
//// project targets JavaScript only; the SPA entry chain is the only importer.

import gleam/option.{type Option}
import lustre/effect.{type Effect}

/// Scroll the element with the given id to the vertical center of the
/// viewport, or to the nearest possible position near document boundaries.
/// Respects `prefers-reduced-motion`. Safely no-ops when the target is
/// missing or stale.
///
/// Dispatches the id once the scroll has settled so callers can highlight the
/// navigated-to heading: the ToC IntersectionObserver only fires on
/// intersection changes, so it never reports the final position of a
/// programmatic scroll.
pub fn scroll_to(id: String) -> Effect(String) {
  use dispatch <- effect.from
  scroll_to_fragment(id, dispatch)
  Nil
}

/// Update the URL fragment via `history.pushState` without triggering a
/// full-page navigation. The browser does not scroll for pushState hash
/// changes, so scrolling stays fully controlled by `scroll_to`.
pub fn set_hash(id: String) -> Effect(Nil) {
  use _ <- effect.from
  set_fragment_hash(id)
  Nil
}

/// After runtime content has mounted, scroll to the fragment present in the
/// current URL (if any) and dispatch it once the scroll settles. Directly
/// opening or refreshing a post URL with a heading fragment restores the
/// target once the content has rendered. No-op (and no dispatch) when the URL
/// has no fragment.
pub fn restore_initial() -> Effect(String) {
  use dispatch <- effect.from
  restore_initial_fragment(dispatch)
  Nil
}

/// Subscribe to fragment changes in the URL (browser back/forward, manual
/// address-bar edits) and dispatch the new fragment, or `None` when the URL
/// has no fragment. Callers map the dispatched value into their own message
/// type, e.g. `effect.map(subscribe_to_hash_changes(), FragmentHashChanged)`.
pub fn subscribe_to_hash_changes() -> Effect(Option(String)) {
  use dispatch <- effect.from
  subscribe_hash_changes(dispatch)
  Nil
}

@external(javascript, "../ffi/fragment.ffi.mjs", "scroll_to_fragment")
fn scroll_to_fragment(id: String, dispatch: fn(String) -> Nil) -> Nil

@external(javascript, "../ffi/fragment.ffi.mjs", "set_fragment_hash")
fn set_fragment_hash(id: String) -> Nil

@external(javascript, "../ffi/fragment.ffi.mjs", "restore_initial_fragment")
fn restore_initial_fragment(dispatch: fn(String) -> Nil) -> Nil

@external(javascript, "../ffi/fragment.ffi.mjs", "subscribe_hash_changes")
fn subscribe_hash_changes(dispatch: fn(Option(String)) -> Nil) -> fn() -> Nil
