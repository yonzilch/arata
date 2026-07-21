// arata — browser FFI: small DOM helpers for the SPA runtime.
//
// `arata_base_path` reads the deployment base path embedded by the build
// pipeline in both `index.html` and `404.html`:
//
//   <meta name="arata-base-path" content="/arata">
//
// An absent element or content attribute falls back to an empty string,
// representing a root deployment.
//
// `scroll_to_top` smooth-scrolls the window back to the top. It is called from
// the Lustre update function when the user activates the scroll-to-top control.

/**
 * Return the deployment base path embedded in the generated HTML shell.
 *
 * @returns {string}
 */
export function arata_base_path() {
  if (typeof document === "undefined") {
    return "";
  }

  const element = document.querySelector('meta[name="arata-base-path"]');

  if (element === null) {
    return "";
  }

  return element.getAttribute("content") ?? "";
}

/**
 * Smooth-scroll the browser window to the top.
 */
export function scroll_to_top() {
  if (typeof window !== "undefined") {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}
