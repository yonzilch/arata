// arata — browser FFI: small DOM helpers for the SPA runtime.
//
// Currently only exports `scroll_to_top` (Fix 7): smooth-scrolls the window
// back to the top. Called from the Lustre `update` function via an effect when
// the user clicks the `.scroll-top-fab` button.

export function scroll_to_top() {
  if (typeof window !== "undefined") {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}
