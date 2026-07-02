//// Theme management (light / dark / auto) via FFI: localStorage persistence
//// and a `prefers-color-scheme` media-query subscription.
////
//// Mirrors apollo's `static/js/themetoggle.js` behaviour:
////   - `init_theme()` reads the saved theme from localStorage (falling back to
////     the system preference) and subscribes to system theme changes.
////   - `apply_theme(theme)` writes the new theme to localStorage and applies
////     the `dark`/`light` class on `<html>` so the CSS variables switch.
////
//// The FFI lives in `src/ffi/theme.ffi.mjs`. The `@external` declarations have
//// no-op Gleam fallback bodies so the project still builds when targeting
//// Erlang (theme management only runs in the browser).
////
//// FOUC prevention: in a server-rendered `index.html` (Phase 17), the initial
//// `<html>` would carry both `dark` and `light` classes and an inline script
//// would call `apply_theme` before first paint. For now (client-only SPA), the
//// theme is applied as soon as the `init_theme` effect runs — there may be a
//// brief flash on hard reload, which is acceptable until SSR lands.

import lustre/effect.{type Effect}

/// The user's theme choice.
pub type Theme {
  Light
  Dark
  Auto
}

/// Messages emitted by theme effects.
pub type ThemeMsg {
  /// The saved/system theme was loaded at startup.
  ThemeLoaded(theme: Theme)
  /// The OS theme preference changed (only relevant when the user's choice is
  /// `Auto`).
  SystemPrefersDarkChanged(prefers_dark: Bool)
}

/// At startup, read the saved theme from localStorage and subscribe to system
/// theme changes. Returns an effect that dispatches `ThemeLoaded` (with the
/// resolved theme) and then `SystemPrefersDarkChanged` whenever the OS
/// preference flips.
pub fn init_theme() -> Effect(ThemeMsg) {
  use dispatch <- effect.from
  let mode = get_theme()
  let theme = parse_theme(mode)
  apply_theme(mode)
  let _ =
    subscribe_to_system_changes(fn(prefers_dark) {
      dispatch(SystemPrefersDarkChanged(prefers_dark:))
    })
  // Seed the current value; the change listener above only fires on flips.
  dispatch(SystemPrefersDarkChanged(prefers_dark: get_system_prefers_dark()))
  dispatch(ThemeLoaded(theme:))
}

/// Persist a new theme choice and apply it to the DOM immediately.
pub fn apply_theme_choice(theme: Theme) -> Effect(ThemeMsg) {
  use _dispatch <- effect.from
  let mode = theme_to_string(theme)
  set_theme(mode)
  Nil
}

/// Convert the FFI string ("light"/"dark"/"auto") to a `Theme`.
fn parse_theme(mode: String) -> Theme {
  case mode {
    "dark" -> Dark
    "auto" -> Auto
    _ -> Light
  }
}

/// Convert a `Theme` to the FFI string.
fn theme_to_string(theme: Theme) -> String {
  case theme {
    Light -> "light"
    Dark -> "dark"
    Auto -> "auto"
  }
}

@external(javascript, "../ffi/theme.ffi.mjs", "get_theme")
fn get_theme() -> String

@external(javascript, "../ffi/theme.ffi.mjs", "set_theme")
fn set_theme(mode: String) -> Nil

@external(javascript, "../ffi/theme.ffi.mjs", "apply_theme")
fn apply_theme(mode: String) -> Nil

@external(javascript, "../ffi/theme.ffi.mjs", "subscribe_to_system_changes")
fn subscribe_to_system_changes(dispatch: fn(Bool) -> Nil) -> fn() -> Nil

@external(javascript, "../ffi/theme.ffi.mjs", "get_system_prefers_dark")
fn get_system_prefers_dark() -> Bool
