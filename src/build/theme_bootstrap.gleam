//// Synchronous theme bootstrap script for generated HTML shells.
////
//// Emits a tiny inline script that resolves the persisted theme preference
//// (`localStorage["theme-storage"]`) before the first paint, so an explicit
//// `light` or `dark` choice overrides `prefers-color-scheme` without a
//// flash.
////
//// The same script body is emitted in two wrappers:
////
////   - `html_script()` for the SPA HTML shell (`index.html` / `404.html`);
////   - `xsl_script()` for the feed XSL stylesheets, where the body must be
////     wrapped in a CDATA section so the XML parser does not treat `<`/`&`
////     as markup.
////
//// Contract (shared with `effect/theme.gleam` and `src/ffi/theme.ffi.mjs`):
////
////   - Storage key: `theme-storage`; values `light` | `dark` | `auto`.
////   - Dark DOM state: `<html class="dark">`.
////   - Explicit `light`/`dark` preferences take precedence over
////     `prefers-color-scheme`.
////   - Only `auto`, missing, invalid, or inaccessible storage falls back to
////     the system preference.
////   - Failures (localStorage or matchMedia unavailable) degrade to light.
////
//// The script must run synchronously in `<head>` before the main CSS can
//// produce a visible paint and before Lustre initializes, so the persisted
//// explicit preference is in effect from the very first frame.

/// Plain `<script>` wrapper for HTML documents.
pub fn html_script() -> String {
  "<script>" <> script_body() <> "</script>"
}

/// CDATA-wrapped `<script>` for XML (feed XSL) documents.
///
/// The newlines around the body are part of the historical feed output and
/// are preserved byte-for-byte.
pub fn xsl_script() -> String {
  "<script><![CDATA[\n" <> script_body() <> "\n]]></script>"
}

/// The raw JavaScript body shared by both wrappers, kept minified because it
/// is inlined into every generated HTML page and feed stylesheet.
fn script_body() -> String {
  "(function(){var theme=null;try{theme=window.localStorage.getItem('theme-storage');}catch(_){theme=null;}if(theme!=='light'&&theme!=='dark'&&theme!=='auto'){theme='auto';}var dark=theme==='dark';if(theme==='auto'){try{dark=window.matchMedia('(prefers-color-scheme: dark)').matches;}catch(_){dark=false;}}document.documentElement.classList.toggle('dark',dark);})();"
}
