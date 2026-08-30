//// Theme management (light / dark) via FFI: localStorage persistence.
////
//// There is no `Auto` state: the system preference is resolved once at
//// startup into an explicit `Light` or `Dark`, and the toggle then flips
//// between the two. This keeps every click on the toggle a visible change.
////
//// Mirrors apollo's `static/js/themetoggle.js` behaviour:
////   - `init_theme()` reads the saved theme from localStorage (falling back
////     to the system preference) and applies it before Lustre takes over.
////   - `apply_theme_choice(theme)` writes the new theme to localStorage and
////     applies the `dark`/`light` class on `<html>` so the CSS variables
////     switch.
////
//// The FFI lives in `src/ffi/theme.ffi.mjs`. The `@external` declarations
//// have no-op Gleam fallback bodies so the project still builds when
//// targeting Erlang (theme management only runs in the browser).
////
//// FOUC prevention: the generated HTML shell (`build/theme_bootstrap.gleam`)
//// embeds a synchronous theme bootstrap in `<head>` that resolves the
//// persisted preference before first paint. `init_theme` re-applies the same
//// resolved mode at startup, so Lustre never overwrites the bootstrapped
//// theme with an intermediate default.
////
//// Compatibility: `theme-storage` may still hold the legacy value `auto`
//// from earlier versions; it resolves against the current system preference.

import lustre/effect.{type Effect}

/// The user's theme choice.
pub type Theme {
  Light
  Dark
}

/// Messages emitted by theme effects.
pub type ThemeMsg {
  /// The saved/system theme was resolved at startup.
  ThemeLoaded(theme: Theme)
}

/// At startup, read the saved theme from localStorage and apply it to the
/// DOM. Returns an effect that dispatches `ThemeLoaded` with the resolved
/// theme. A legacy stored `auto` (or a missing/unreadable value) resolves
/// against the current system preference.
pub fn init_theme() -> Effect(ThemeMsg) {
  use dispatch <- effect.from
  let mode = get_theme()
  let theme = parse_theme(mode)
  apply_theme(mode)
  dispatch(ThemeLoaded(theme:))
}

/// Persist a new theme choice and apply it to the DOM immediately.
pub fn apply_theme_choice(theme: Theme) -> Effect(ThemeMsg) {
  use _dispatch <- effect.from
  let mode = theme_to_string(theme)
  set_theme(mode)
  Nil
}

/// Convert the FFI string ("light"/"dark"/legacy "auto") to a `Theme`.
fn parse_theme(mode: String) -> Theme {
  case mode {
    "dark" -> Dark
    "light" -> Light
    // Legacy "auto": resolve against the system preference once.
    _ ->
      case get_system_prefers_dark() {
        True -> Dark
        False -> Light
      }
  }
}

/// Convert a `Theme` to the FFI string.
fn theme_to_string(theme: Theme) -> String {
  case theme {
    Light -> "light"
    Dark -> "dark"
  }
}

@external(javascript, "../ffi/theme.ffi.mjs", "get_theme")
fn get_theme() -> String

@external(javascript, "../ffi/theme.ffi.mjs", "set_theme")
fn set_theme(mode: String) -> Nil

@external(javascript, "../ffi/theme.ffi.mjs", "apply_theme")
fn apply_theme(mode: String) -> Nil

@external(javascript, "../ffi/theme.ffi.mjs", "get_system_prefers_dark")
fn get_system_prefers_dark() -> Bool
