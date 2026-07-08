// arata — script FFI: runtime enhancement for MathJax and Mermaid.
//
// This module intentionally does not hard-code public CDN URLs as defaults.
// Runtime asset URLs should come from config.gleam. If an older Gleam caller
// still invokes these functions without arguments, the fallback is local static
// assets under /js/, not an external CDN.
//
// Supported inputs:
// - MathJax: inline/block TeX already present in rendered post HTML.
// - Mermaid: native fenced Markdown code blocks rendered as
//   <pre><code class="language-mermaid">...</code></pre>.
// - Mermaid legacy shortcode output that already produces .mermaid.
//
// Important invariants:
// - CDN or local script load failures must not crash the SPA.
// - MathJax must run after the SPA has patched the post DOM.
// - Mermaid source must be read from textContent, not innerHTML.
// - Mermaid original source is stored per DOM node, not by global array index.
// - Re-rendering for dark/light theme must be deterministic and idempotent.

const DEFAULT_MATHJAX_URL = "/js/tex-mml-chtml.js";
const DEFAULT_MERMAID_URL = "/js/mermaid.esm.min.mjs";

const MATHJAX_SCRIPT_ID = "MathJax-script";

let mathjax_loading_promise = null;
let mathjax_loading_url = null;

let mermaid_module_promise = null;
let mermaid_module_url = null;
let mermaid_render_counter = 0;

function normalize_url(url, fallback) {
  if (typeof url !== "string") return fallback;

  const trimmed = url.trim();
  return trimmed.length === 0 ? fallback : trimmed;
}

function absolute_url(url) {
  try {
    return new URL(url, window.location.origin).href;
  } catch (_error) {
    return url;
  }
}

function same_url(left, right) {
  return absolute_url(left) === absolute_url(right);
}

function after_dom_patch(callback) {
  if (typeof window === "undefined") return;

  window.requestAnimationFrame(() => {
    window.setTimeout(callback, 0);
  });
}

function log_debug(message, value) {
  if (typeof console === "undefined") return;

  console.debug(`[arata] ${message}`, value);
}

function configure_mathjax() {
  const existing = window.MathJax || {};

  window.MathJax = {
    ...existing,
    tex: {
      ...(existing.tex || {}),
      inlineMath: [
        ["$", "$"],
        ["\\(", "\\)"],
      ],
      displayMath: [
        ["$$", "$$"],
        ["\\[", "\\]"],
      ],
      processEscapes: true,
    },
    options: {
      ...(existing.options || {}),
      skipHtmlTags: ["script", "noscript", "style", "textarea", "pre", "code"],
    },
    startup: {
      ...(existing.startup || {}),
      typeset: false,
    },
  };
}

function remove_stale_mathjax_script(target_url) {
  const existing_script = document.getElementById(MATHJAX_SCRIPT_ID);

  if (!existing_script) return;

  const existing_src = existing_script.getAttribute("src") || "";

  if (same_url(existing_src, target_url)) return;

  if (window.MathJax && window.MathJax.typesetPromise) {
    console.warn(
      "[arata] MathJax is already loaded from a different URL. " +
        "Reload the page to switch MathJax asset URLs.",
      {
        existing: existing_script.src,
        expected: absolute_url(target_url),
      },
    );
    return;
  }

  existing_script.remove();
  mathjax_loading_promise = null;
  mathjax_loading_url = null;
}

function load_mathjax(mathjax_url) {
  const url = normalize_url(mathjax_url, DEFAULT_MATHJAX_URL);

  log_debug("MathJax requested URL:", url);

  if (window.MathJax && window.MathJax.typesetPromise) {
    return Promise.resolve(window.MathJax);
  }

  if (
    mathjax_loading_promise &&
    mathjax_loading_url &&
    same_url(mathjax_loading_url, url)
  ) {
    return mathjax_loading_promise;
  }

  configure_mathjax();
  remove_stale_mathjax_script(url);

  const existing_script = document.getElementById(MATHJAX_SCRIPT_ID);

  if (existing_script) {
    mathjax_loading_url = url;
    mathjax_loading_promise = new Promise((resolve, reject) => {
      existing_script.addEventListener("load", () => resolve(window.MathJax), {
        once: true,
      });
      existing_script.addEventListener("error", reject, { once: true });
    });

    return mathjax_loading_promise;
  }

  mathjax_loading_url = url;
  mathjax_loading_promise = new Promise((resolve, reject) => {
    const script = document.createElement("script");

    script.id = MATHJAX_SCRIPT_ID;
    script.type = "text/javascript";
    script.async = true;
    script.src = url;

    script.onload = () => {
      log_debug("MathJax loaded from:", script.src);
      resolve(window.MathJax);
    };

    script.onerror = () => {
      mathjax_loading_promise = null;
      mathjax_loading_url = null;
      reject(new Error(`Failed to load MathJax from ${url}`));
    };

    document.head.appendChild(script);
  });

  return mathjax_loading_promise;
}

function run_mathjax_typeset(mathjax) {
  if (!mathjax || typeof mathjax.typesetPromise !== "function") return;

  mathjax.typesetPromise().catch((error) => {
    console.warn("[arata] MathJax typeset failed:", error);
  });
}

export function typeset_math(mathjax_url = DEFAULT_MATHJAX_URL) {
  if (typeof window === "undefined" || typeof document === "undefined") return;

  const url = normalize_url(mathjax_url, DEFAULT_MATHJAX_URL);

  after_dom_patch(() => {
    load_mathjax(url)
      .then(run_mathjax_typeset)
      .catch((error) => {
        console.warn("[arata] MathJax load failed:", error);
      });
  });
}

function is_mermaid_code_block(code) {
  if (!code || !code.classList) return false;

  return (
    code.classList.contains("language-mermaid") ||
    code.classList.contains("mermaid")
  );
}

function get_mermaid_source(element) {
  if (!element) return "";

  if (element.dataset && element.dataset.arataMermaidSource) {
    return element.dataset.arataMermaidSource;
  }

  // textContent decodes escaped HTML entities from the rendered Markdown.
  // Example: "--&gt;" becomes "-->", which Mermaid can parse correctly.
  return element.textContent || "";
}

function set_mermaid_source(element, source) {
  if (!element || !element.dataset) return;

  element.dataset.arataMermaidSource = source;
}

function normalize_mermaid_code_blocks() {
  const code_blocks = Array.from(document.querySelectorAll("pre > code"));

  for (const code of code_blocks) {
    if (!is_mermaid_code_block(code)) continue;

    const pre = code.parentElement;
    if (!pre) continue;

    const source = get_mermaid_source(code).trim();
    const container = document.createElement("div");

    container.className = "mermaid";
    container.dataset.arataMermaid = "true";
    set_mermaid_source(container, source);
    container.textContent = source;

    pre.replaceWith(container);
  }
}

function normalize_existing_mermaid_blocks() {
  const blocks = Array.from(document.getElementsByClassName("mermaid"));

  for (const block of blocks) {
    if (!block.dataset) continue;

    if (!block.dataset.arataMermaidSource) {
      const source = get_mermaid_source(block).trim();
      set_mermaid_source(block, source);
    }

    block.dataset.arataMermaid = "true";
  }
}

function collect_mermaid_blocks() {
  normalize_mermaid_code_blocks();
  normalize_existing_mermaid_blocks();

  return Array.from(document.getElementsByClassName("mermaid")).filter(
    (block) => get_mermaid_source(block).trim().length > 0,
  );
}

function reset_mermaid_block(block) {
  const source = get_mermaid_source(block);

  delete block.dataset.processed;
  delete block.dataset.arataMermaidProcessed;
  delete block.dataset.arataMermaidTheme;
  delete block.dataset.arataMermaidError;

  block.classList.remove("arata-mermaid-error");
  block.textContent = source;
}

function load_mermaid(mermaid_url) {
  const url = normalize_url(mermaid_url, DEFAULT_MERMAID_URL);

  log_debug("Mermaid requested URL:", url);

  if (
    mermaid_module_promise &&
    mermaid_module_url &&
    same_url(mermaid_module_url, url)
  ) {
    return mermaid_module_promise;
  }

  mermaid_module_url = url;
  mermaid_module_promise = import(url).catch((error) => {
    mermaid_module_promise = null;
    mermaid_module_url = null;
    throw error;
  });

  return mermaid_module_promise;
}

async function render_mermaid_block(mermaid, block, theme) {
  const source = get_mermaid_source(block).trim();

  if (source.length === 0) return;

  if (
    block.dataset.arataMermaidProcessed === "true" &&
    block.dataset.arataMermaidTheme === theme
  ) {
    return;
  }

  reset_mermaid_block(block);

  const id = `arata-mermaid-${Date.now()}-${mermaid_render_counter}`;
  mermaid_render_counter += 1;

  try {
    const rendered = await mermaid.render(id, source);

    block.innerHTML = rendered.svg;

    if (typeof rendered.bindFunctions === "function") {
      rendered.bindFunctions(block);
    }

    block.dataset.arataMermaidProcessed = "true";
    block.dataset.arataMermaidTheme = theme;
  } catch (error) {
    block.classList.add("arata-mermaid-error");
    block.dataset.arataMermaidError = "true";
    block.textContent = source;

    console.warn("[arata] Mermaid render failed:", error);
  }
}

export function render_mermaid(is_dark, mermaid_url = DEFAULT_MERMAID_URL) {
  if (typeof window === "undefined" || typeof document === "undefined") return;

  const url = normalize_url(mermaid_url, DEFAULT_MERMAID_URL);

  after_dom_patch(() => {
    const blocks = collect_mermaid_blocks();
    if (blocks.length === 0) return;

    load_mermaid(url)
      .then(async (module) => {
        const mermaid = module.default || module;
        const theme = is_dark ? "dark" : "neutral";

        mermaid.initialize({
          startOnLoad: false,
          theme,
          securityLevel: "strict",
        });

        for (const block of blocks) {
          await render_mermaid_block(mermaid, block, theme);
        }
      })
      .catch((error) => {
        console.warn("[arata] Mermaid load failed:", error);
      });
  });
}
