// arata — script FFI: dynamically loads and invokes MathJax and Mermaid
// after each post view renders, mirroring apollo's MathJax config + main.js.
//
// Because arata doesn't yet have a custom index.html (Phase 17), the scripts
// are loaded lazily on first use: if MathJax/mermaid are not yet on the page,
// inject the <script> tags, wait for them to load, then call the render API.
// Subsequent calls skip the loading step.
//
// MathJax config matches apollo's: inlineMath [['$','$'], ['\\(','\\)']].
// Mermaid is initialized with theme "dark" or "neutral" based on the current
// effective theme, and re-rendered on theme change (apollo's mermaidRender).

const mathjax_cdn =
  "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js";
const mermaid_cdn =
  "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";

let mermaid_originals = null;

export function typeset_math() {
  if (typeof window === "undefined") return;
  if (window.MathJax && window.MathJax.typesetPromise) {
    window.MathJax.typesetPromise();
    return;
  }
  // Load MathJax lazily.
  if (document.getElementById("MathJax-script")) return;
  window.MathJax = {
    tex: { inlineMath: [["$", "$"], ["\\(", "\\)"]] },
    startup: { typeset: false },
  };
  const script = document.createElement("script");
  script.id = "MathJax-script";
  script.type = "text/javascript";
  script.async = true;
  script.src = mathjax_cdn;
  script.onload = () => {
    if (window.MathJax && window.MathJax.typesetPromise) {
      window.MathJax.typesetPromise();
    }
  };
  document.head.appendChild(script);
}

export function render_mermaid(is_dark) {
  if (typeof window === "undefined") return;
  const blocks = document.getElementsByClassName("mermaid");
  if (blocks.length === 0) return;

  // Store original innerHTML on first call so we can restore on re-render.
  if (!mermaid_originals) {
    mermaid_originals = [];
    for (let i = 0; i < blocks.length; i++) {
      mermaid_originals[i] = blocks[i].innerHTML;
    }
  }

  import(mermaid_cdn).then((mermaid) => {
    const theme = is_dark ? "dark" : "neutral";
    mermaid.default.initialize({ startOnLoad: false, theme: theme });
    // Restore original HTML and clear processed flag so mermaid re-renders.
    for (let i = 0; i < blocks.length; i++) {
      delete blocks[i].dataset.processed;
      blocks[i].innerHTML = mermaid_originals[i];
    }
    mermaid.default.run();
  });
}
