// arata — IntersectionObserver FFI for table-of-contents active highlighting.
//
// Sets up an IntersectionObserver over every element inside
// `main article section.body` (paragraphs, lists, etc.). For each intersecting
// entry it walks backwards to the nearest preceding heading (h2/h3) and
// reports that heading's `id` to Gleam via the `dispatch` callback.
//
// Only the topmost intersecting heading is reported on each callback, matching
// apollo's `toc.js` behaviour (the first visible paragraph's preceding heading
// is the "active" one). The observer disconnects before re-setup so navigating
// between posts does not leak listeners.

export function observe_toc(dispatch) {
  const root = document.querySelector("main section.body");
  if (!root) return;

  const headings = root.querySelectorAll("h2[id], h3[id]");
  if (headings.length === 0) return;

  const children = Array.from(root.children);
  // Map each child element to the id of the nearest preceding heading.
  let lastHeadingId = null;
  const childToHeading = new Map();
  for (const child of children) {
    if (child.tagName === "H2" || child.tagName === "H3") {
      lastHeadingId = child.id;
    }
    if (lastHeadingId) {
      childToHeading.set(child, lastHeadingId);
    }
  }

  const observer = new IntersectionObserver(
    (entries) => {
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

  return () => observer.disconnect();
}
