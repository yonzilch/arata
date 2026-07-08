// arata — script FFI: runtime enhancement for MathJax and Mermaid.
//
// Runtime enhancement responsibilities:
// - MathJax: typeset inline/block TeX after the SPA has patched the DOM.
// - Mermaid: render native fenced Markdown code blocks and legacy shortcode
//   containers after the SPA has patched the DOM.
//
// Supported Mermaid inputs:
// - <pre><code class="language-mermaid">...</code></pre>
// - <code class="language-mermaid">...</code>
// - <pre class="mermaid">...</pre>
// - <div class="mermaid">...</div>
//
// Important invariants:
// - Runtime asset URLs come from config.gleam via effect/script.gleam.
// - Local fallback URLs are used only when old callers pass no URL.
// - Script load/render failures must not crash the SPA.
// - MathJax must not be loaded on posts without TeX.
// - Mermaid source must be stored per DOM node, not globally by index.
// - Mermaid source extraction must use textContent and decode HTML entities.
// - Mermaid rendering must be idempotent across route changes and theme changes.

const DEFAULT_MATHJAX_URL = "/js/tex-mml-chtml.js";
const DEFAULT_MERMAID_URL = "/js/mermaid.esm.min.mjs";

const MATHJAX_SCRIPT_ID = "MathJax-script";
const MERMAID_OBSERVE_TIMEOUT_MS = 1500;

let mathjax_loading_promise = null;
let mathjax_loading_url = null;

let mermaid_module_promise = null;
let mermaid_module_url = null;
let mermaid_render_counter = 0;
let mermaid_observer = null;
let mermaid_observer_timer = null;

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

function decode_html_entities(value) {
  if (typeof document === "undefined") return value;
  if (typeof value !== "string" || value.length === 0) return value;

  const textarea = document.createElement("textarea");
  textarea.innerHTML = value;
  return textarea.value;
}

// -----------------------------------------------------------------------------
// MathJax
// -----------------------------------------------------------------------------

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

function get_math_scan_root() {
  return (
    document.querySelector("article") ||
    document.querySelector("main") ||
    document.querySelector(".content") ||
    document.body
  );
}

function text_without_skipped_math_nodes(root) {
  if (!root) return "";

  const clone = root.cloneNode(true);

  clone
    .querySelectorAll(
      [
        "script",
        "noscript",
        "style",
        "textarea",
        "pre",
        "code",
        ".mermaid",
        "[data-arata-mermaid='true']",
      ].join(","),
    )
    .forEach((node) => node.remove());

  return clone.textContent || "";
}

function has_likely_inline_dollar_math(text) {
  const matches = text.match(/\$([^\s$][^$\n]*?[^\s$])\$/g);

  if (!matches) return false;

  return matches.some((match) => {
    const body = match.slice(1, -1);

    if (/^\d+(\.\d+)?$/.test(body.trim())) return false;

    return /[\\^_=+\-*/{}()[\]]/.test(body);
  });
}

function has_math_content() {
  const root = get_math_scan_root();
  const text = text_without_skipped_math_nodes(root);

  if (text.trim().length === 0) return false;

  if (/\$\$[\s\S]+?\$\$/.test(text)) return true;
  if (/\\\([\s\S]+?\\\)/.test(text)) return true;
  if (/\\\[[\s\S]+?\\\]/.test(text)) return true;

  return has_likely_inline_dollar_math(text);
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
    if (!has_math_content()) return;

    load_mathjax(url)
      .then(run_mathjax_typeset)
      .catch((error) => {
        console.warn("[arata] MathJax load failed:", error);
      });
  });
}

// -----------------------------------------------------------------------------
// Mermaid
// -----------------------------------------------------------------------------

function get_code_language(code) {
  if (!code) return "";

  const data_lang = code.getAttribute("data-lang");

  if (data_lang && data_lang.trim() !== "") {
    return data_lang.trim().toLowerCase();
  }

  for (const class_name of code.classList || []) {
    if (class_name === "mermaid") return "mermaid";

    if (class_name.startsWith("language-")) {
      return class_name.slice("language-".length).trim().toLowerCase();
    }
  }

  return "";
}

function is_mermaid_code_node(node) {
  if (!node || !node.classList) return false;

  if (node.classList.contains("mermaid")) return true;
  if (node.classList.contains("language-mermaid")) return true;

  return get_code_language(node) === "mermaid";
}

function is_legacy_mermaid_container(node) {
  if (!node || !node.classList) return false;

  if (!node.classList.contains("mermaid")) return false;

  const tag = node.tagName ? node.tagName.toLowerCase() : "";

  return tag === "pre" || tag === "div";
}

function get_mermaid_source(element) {
  if (!element) return "";

  if (element.dataset && element.dataset.arataMermaidSource) {
    return element.dataset.arataMermaidSource;
  }

  const raw = element.textContent || "";

  // mork/CommonMark code output can preserve author-written entities.
  // Decode Mermaid source so diagrams copied from escaped README HTML still work:
  //   --&gt;      -> -->
  //   &lt;br/&gt; -> <br/>
  return decode_html_entities(raw);
}

function set_mermaid_source(element, source) {
  if (!element || !element.dataset) return;

  element.dataset.arataMermaidSource = source;
}

function normalize_mermaid_code_nodes() {
  const code_nodes = Array.from(
    document.querySelectorAll("code.language-mermaid, code.mermaid, pre code"),
  );

  let normalized_count = 0;

  for (const code of code_nodes) {
    if (!is_mermaid_code_node(code)) continue;

    const pre = code.closest("pre");
    const source = get_mermaid_source(code).trim();

    if (source.length === 0) continue;

    const container = document.createElement("div");

    container.className = "mermaid";
    container.dataset.arataMermaid = "true";
    set_mermaid_source(container, source);
    container.textContent = source;

    if (pre) {
      pre.replaceWith(container);
    } else {
      code.replaceWith(container);
    }

    normalized_count += 1;
  }

  return normalized_count;
}

function normalize_legacy_mermaid_containers() {
  const containers = Array.from(
    document.querySelectorAll("pre.mermaid, div.mermaid"),
  );

  let normalized_count = 0;

  for (const container of containers) {
    if (!is_legacy_mermaid_container(container)) continue;
    if (!container.dataset) continue;

    if (!container.dataset.arataMermaidSource) {
      const source = get_mermaid_source(container).trim();
      set_mermaid_source(container, source);
      container.textContent = source;
    }

    container.dataset.arataMermaid = "true";
    normalized_count += 1;
  }

  return normalized_count;
}

function collect_mermaid_blocks() {
  normalize_mermaid_code_nodes();
  normalize_legacy_mermaid_containers();

  return Array.from(document.querySelectorAll(".mermaid")).filter(
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

function resolve_mermaid_api(module) {
  const candidates = [
    module && module.default,
    module,
    module && module.mermaid,
    module && module.default && module.default.default,
    typeof window !== "undefined" && window.mermaid,
  ];

  for (const candidate of candidates) {
    if (
      candidate &&
      typeof candidate.initialize === "function" &&
      typeof candidate.render === "function"
    ) {
      return candidate;
    }
  }

  throw new Error("Loaded Mermaid module does not expose initialize/render");
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

    console.warn("[arata] Mermaid render failed:", {
      error,
      source,
    });
  }
}

async function render_mermaid_now(is_dark, mermaid_url) {
  const blocks = collect_mermaid_blocks();

  if (blocks.length === 0) {
    return 0;
  }

  const module = await load_mermaid(mermaid_url);
  const mermaid = resolve_mermaid_api(module);
  const theme = is_dark ? "dark" : "neutral";

  mermaid.initialize({
    startOnLoad: false,
    theme,
    securityLevel: "loose",
    flowchart: {
      htmlLabels: true,
    },
  });

  for (const block of blocks) {
    await render_mermaid_block(mermaid, block, theme);
  }

  return blocks.length;
}

function stop_mermaid_observer() {
  if (mermaid_observer) {
    mermaid_observer.disconnect();
    mermaid_observer = null;
  }

  if (mermaid_observer_timer) {
    window.clearTimeout(mermaid_observer_timer);
    mermaid_observer_timer = null;
  }
}

function observe_until_mermaid_blocks_exist(is_dark, mermaid_url) {
  stop_mermaid_observer();

  mermaid_observer = new MutationObserver(() => {
    render_mermaid_now(is_dark, mermaid_url)
      .then((count) => {
        if (count > 0) {
          stop_mermaid_observer();
        }
      })
      .catch((error) => {
        console.warn("[arata] Mermaid render failed:", error);
        stop_mermaid_observer();
      });
  });

  mermaid_observer.observe(document.body, {
    childList: true,
    subtree: true,
  });

  mermaid_observer_timer = window.setTimeout(() => {
    render_mermaid_now(is_dark, mermaid_url).catch((error) => {
      console.warn("[arata] Mermaid render failed:", error);
    });
    stop_mermaid_observer();
  }, MERMAID_OBSERVE_TIMEOUT_MS);
}

export function render_mermaid(is_dark, mermaid_url = DEFAULT_MERMAID_URL) {
  if (typeof window === "undefined" || typeof document === "undefined") return;

  const url = normalize_url(mermaid_url, DEFAULT_MERMAID_URL);

  after_dom_patch(() => {
    render_mermaid_now(is_dark, url)
      .then((count) => {
        if (count > 0) return;

        observe_until_mermaid_blocks_exist(is_dark, url);
      })
      .catch((error) => {
        console.warn("[arata] Mermaid load/render failed:", error);
      });
  });
}
