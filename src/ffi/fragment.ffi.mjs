// arata — fragment navigation FFI.
//
// Heading links in the table of contents are intercepted by Lustre (the view
// attaches a click handler that prevents default and stops propagation) and
// dispatched to Gleam, which runs the effects in `effect/fragment.gleam`.
// Those effects own URL-fragment updates and centered scrolling so ToC
// navigation behaves consistently:
//
//   - the fragment stays in the URL (pushState, no full-page navigation);
//   - the target heading scrolls to the vertical center of the viewport, or
//     to the nearest possible position near document boundaries;
//   - reduced-motion users get an instant jump instead of smooth scrolling;
//   - missing/stale targets are ignored (never throw);
//   - opening/refreshing a URL with a fragment restores the target once the
//     SPA content has mounted;
//   - browser back/forward restores the corresponding fragment target.
//
// All scrolling is deferred by two animation frames. Modem's popstate handler
// scrolls to fragments itself (top-aligned) on the next frame, so deferring
// guarantees this module's centered scroll always runs last and wins.

import { Some, None } from "../../gleam_stdlib/gleam/option.mjs";

function prefers_reduced_motion() {
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

/// The current URL fragment, URL-decoded, or null when the URL has no
/// fragment. Fragment ids are stored percent-encoded in the URL but heading
/// ids in the DOM are plain strings, so the decode is required for matching.
function current_fragment() {
  if (typeof window === "undefined") return null;
  const hash = window.location.hash;
  if (!hash || hash === "#") return null;
  const raw = hash.slice(1);
  try {
    return decodeURIComponent(raw);
  } catch {
    // Malformed percent-encoding — fall back to the raw fragment.
    return raw;
  }
}

// Run `callback` after two animation frames. Lustre renders after its effects
// run, so an effect that needs to touch the DOM must defer the lookup until the
// next frames; this also guarantees our centered scroll runs after modem's own
// top-aligned popstate scroll.
function deferred(callback) {
  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => callback());
  });
}

// Each fragment scroll bumps this counter. When the scroll settles, only the
// most recent scroll reports its target, so rapid consecutive ToC clicks (or a
// click immediately after a back/forward navigation) cannot leave the
// highlight on a stale target.
let scroll_generation = 0;

// Report the scrolled-to target to Gleam once the scroll has settled. The
// IntersectionObserver in `observer.ffi.mjs` only fires on intersection
// *changes*, so after a programmatic scroll it never reports the final
// position: without this explicit report the active highlight would stay on
// an intermediate heading.
function report_after_scroll(dispatch, id) {
  const generation = ++scroll_generation;
  let done = false;

  const finish = () => {
    if (done) return;
    done = true;
    window.removeEventListener("scrollend", finish);
    clearTimeout(timer);
    // Only the most recently started scroll reports its target.
    if (generation === scroll_generation) dispatch(id);
  };

  window.addEventListener("scrollend", finish);
  // `scrollend` is not supported everywhere; fall back to a fixed delay that
  // comfortably covers the browser's smooth-scroll animation.
  const timer = setTimeout(finish, 800);
}

/// Scroll the element with `id` to the vertical center of the viewport and,
/// once the scroll has settled, dispatch the id so the app can highlight the
/// navigated-to heading. No-op when the element is missing (stale fragment
/// target, or the effect ran before the content finished rendering).
export function scroll_to_fragment(id, dispatch) {
  if (typeof document === "undefined" || typeof window === "undefined") return;
  deferred(() => {
    const element = document.getElementById(id);
    if (!element) return;
    element.scrollIntoView({
      behavior: prefers_reduced_motion() ? "auto" : "smooth",
      block: "center",
      inline: "nearest",
    });
    report_after_scroll(dispatch, id);
  });
}

/// Update the URL fragment via pushState. pushState does not fire hashchange
/// and does not trigger the browser's default scroll-to-fragment behavior, so
/// scrolling remains fully controlled by `scroll_to_fragment`.
export function set_fragment_hash(id) {
  if (typeof window === "undefined") return;
  const url = new URL(window.location.href);
  url.hash = id;
  window.history.pushState({}, "", url.toString());
}

/// Restore the fragment target after runtime content has mounted, reporting
/// the restored target once the scroll settles (see `scroll_to_fragment`).
/// No-op when the URL has no fragment or the target does not exist yet.
export function restore_initial_fragment(dispatch) {
  if (typeof window === "undefined") return;
  const fragment = current_fragment();
  if (fragment === null) return;
  scroll_to_fragment(fragment, dispatch);
}

/// Subscribe to URL fragment changes (browser back/forward, manual address-bar
/// edits) and dispatch the decoded fragment, or None when the URL has no
/// fragment. Returns an unsubscribe function.
export function subscribe_hash_changes(dispatch) {
  if (typeof window === "undefined") return () => {};
  const handler = () => {
    const fragment = current_fragment();
    if (fragment === null) {
      dispatch(new None());
    } else {
      dispatch(new Some(fragment));
    }
  };
  window.addEventListener("hashchange", handler);
  return () => window.removeEventListener("hashchange", handler);
}
