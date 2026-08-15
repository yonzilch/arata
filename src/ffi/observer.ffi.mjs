// arata — IntersectionObserver FFI for table-of-contents active highlighting.
//
// Sets up an IntersectionObserver over every element inside
// `main article section.body` (paragraphs, lists, etc.). For each intersecting
// entry it walks backwards to the nearest preceding heading (h1–h6) and
// reports that heading's `id` to Gleam via the `dispatch` callback.
//
// Only the topmost intersecting heading is reported on each callback, matching
// apollo's `toc.js` behaviour (the first visible paragraph's preceding heading
// is the "active" one). Fragment navigation (ToC clicks, fragment restores,
// back/forward) highlights its own target: `fragment.ffi.mjs` scrolls the
// heading to the vertical center of the viewport and dispatches the target id
// once the scroll has settled, so the highlight is not left tracking an
// intermediate position while the page scrolls.
//
// Setup is deferred by two animation frames because Lustre runs synchronous
// effects before its (deferred) render: when this effect runs, the post body
// for the new route does not exist yet, so `querySelector` would find nothing
// and the highlight would never activate. Deferring matches the approach in
// `fragment.ffi.mjs` and guarantees the observer attaches to the freshly
// rendered content on direct loads and on in-SPA route changes alike.
//
// The live observer is tracked at module level: the previous observer is
// disconnected before a new one is installed, so navigating between posts
// never leaks listeners or stacks duplicate observers.

let current_observer = null;

export function observe_toc(dispatch) {
  if (typeof window === "undefined" || typeof document === "undefined") return;

  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => {
      if (current_observer) {
        current_observer.disconnect();
        current_observer = null;
      }
      current_observer = setup_observer(dispatch);
    });
  });
}

function setup_observer(dispatch) {
  const root = document.querySelector("main section.body");
  if (!root) return null;

  const headings = root.querySelectorAll(
    "h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]",
  );
  if (headings.length === 0) return null;

  const children = Array.from(root.children);
  // Map each child element to the id of the nearest preceding heading.
  let lastHeadingId = null;
  const childToHeading = new Map();
  for (const child of children) {
    if (/^H[1-6]$/.test(child.tagName)) {
      lastHeadingId = child.id;
    }
    if (lastHeadingId) {
      childToHeading.set(child, lastHeadingId);
    }
  }

  const observer = new IntersectionObserver(
    (entries) => {
      // At the bottom of the document the final heading can never reach the
      // top of the viewport, so the topmost rule below would highlight the
      // second-to-last section. Prefer the final heading once scrolling is
      // exhausted.
      const at_bottom =
        window.innerHeight + window.scrollY >=
        document.documentElement.scrollHeight - 2;
      if (at_bottom) {
        dispatch(headings[headings.length - 1].id);
        return;
      }

      // Find the first (in document order) currently-intersecting child whose
      // preceding heading we know, and dispatch its id.
      const visible = entries
        .filter((e) => e.isIntersecting)
        .map((e) => e.target)
        .sort((a, b) => {
          if (a === b) return 0;
          const pos = a.compareDocumentPosition(b);
          return pos & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
        });
      for (const el of visible) {
        const headingId = childToHeading.get(el);
        if (headingId) {
          dispatch(headingId);
          return;
        }
      }
    },
    { threshold: 0 },
  );

  children.forEach((child) => observer.observe(child));

  return observer;
}
