// arata — runtime syntax-highlighting FFI.
//
// Markdown is parsed at build time, but fenced code blocks remain plain
// `<pre><code>` elements until this enhancer runs in the browser.
//
// The configured asset URL must point to a prebuilt Highlight.js browser
// bundle that exposes `globalThis.hljs`. Arata owns syntax colors through
// `syntax.css`, so this module does not load a Highlight.js theme.
//
// Invariants:
//
//   - no runtime asset is requested when no eligible code block exists
//   - concurrent calls share one runtime-loading promise
//   - the configured runtime is loaded at most once after a successful load
//   - each mounted code element is highlighted at most once
//   - Mermaid, untyped, and explicit plain-text blocks remain untouched
//   - declared languages take precedence over automatic detection
//   - unsupported languages remain readable as plain code
//   - failures never prevent Markdown content from rendering
//   - newly mounted code blocks can be highlighted after SPA navigation
//   - unregistered languages trigger on-demand grammar loading before being
//     marked unsupported
//   - each grammar URL is requested at most once
//   - concurrent blocks sharing a language share one grammar-loading promise
//   - language aliases are normalized before registration checks and resolution
//   - the original author-facing language is preserved in data-lang
//
// Copy buttons, language labels, and horizontal-scroll behavior remain the
// responsibility of `codeblock.ffi.mjs`.

const SCRIPT_ATTRIBUTE = "data-arata-syntax-highlight-runtime";
const HIGHLIGHTED_ATTRIBUTE = "data-arata-syntax-highlighted";
const FAILED_ATTRIBUTE = "data-arata-syntax-highlight-failed";

const OBSERVE_TIMEOUT_MS = 1500;

const SKIPPED_LANGUAGES = new Set([
  "default",
  "mermaid",
  "none",
  "plain",
  "plaintext",
  "text",
  "txt",
]);

const LANGUAGE_ALIASES = new Map([
  ["c++", "cpp"],
  ["cc", "cpp"],
  ["cjs", "javascript"],
  ["cs", "csharp"],
  ["docker", "dockerfile"],
  ["erl", "erlang"],
  ["ex", "elixir"],
  ["exs", "elixir"],
  ["golang", "go"],
  ["html", "xml"],
  ["js", "javascript"],
  ["jsx", "javascript"],
  ["kt", "kotlin"],
  ["md", "markdown"],
  ["mjs", "javascript"],
  ["objective-c", "objectivec"],
  ["objc", "objectivec"],
  ["pl", "perl"],
  ["ps1", "powershell"],
  ["py", "python"],
  ["rb", "ruby"],
  ["rs", "rust"],
  ["sh", "bash"],
  ["shell", "bash"],
  ["toml", "ini"],
  ["ts", "typescript"],
  ["tsx", "typescript"],
  ["yml", "yaml"],
]);

let scheduled = false;
let observer = null;
let observerTimer = null;

let loadedRuntimeUrl = null;
let runtimePromise = null;

// On-demand grammar loading state
let grammarPromises = new Map(); // normalizedLanguage -> Promise<void|null>
let grammarLoaded = new Set();   // normalizedLanguage

/**
 * Build a lookup map from the Gleam list of pairs.
 *
 * @param {Array<[string, string]>} pairs
 * @returns {Map<string, string>}
 */
function buildGrammarMap(pairs) {
  const map = new Map();
  for (const [lang, url] of pairs) {
    const normalized = normalizeRuntimeLanguage(lang);
    if (normalized !== "" && !SKIPPED_LANGUAGES.has(normalized)) {
      map.set(normalized, url);
    }
  }
  return map;
}

/**
 * Highlight eligible Markdown code blocks.
 *
 * Calls made within the same render cycle are coalesced. If Lustre has not yet
 * mounted the raw Markdown HTML, a short-lived MutationObserver waits for the
 * eligible code blocks to appear.
 *
 * @param {string} cdnUrl
 * @param {Array<[string, string]>} grammarPairs
 */
export function enhance_code_blocks(cdnUrl, grammarPairs) {
  if (typeof window === "undefined" || typeof document === "undefined") {
    return;
  }

  const runtimeUrl = normalizeRuntimeUrl(cdnUrl);
  const grammarMap = buildGrammarMap(grammarPairs);

  if (runtimeUrl === "" || scheduled) {
    return;
  }

  scheduled = true;

  afterPaint(async () => {
    scheduled = false;

    const blocks = findEligibleCodeBlocks();

    if (blocks.length === 0) {
      observeUntilCodeBlocksExist(runtimeUrl, grammarMap);
      return;
    }

    stopObserver();
    await enhanceBlocks(runtimeUrl, grammarMap, blocks);
  });
}

/**
 * Run after two animation frames so Lustre can mount `unsafe_raw_html`.
 *
 * @param {() => void | Promise<void>} callback
 */
function afterPaint(callback) {
  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => {
      void callback();
    });
  });
}

/**
 * Wait briefly when the effect runs before Markdown content enters the DOM.
 *
 * @param {string} runtimeUrl
 * @param {Map<string, string>} grammarMap
 */
function observeUntilCodeBlocksExist(runtimeUrl, grammarMap) {
  stopObserver();

  observer = new MutationObserver(() => {
    const blocks = findEligibleCodeBlocks();

    if (blocks.length === 0) {
      return;
    }

    stopObserver();
    void enhanceBlocks(runtimeUrl, grammarMap, blocks);
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });

  observerTimer = window.setTimeout(() => {
    const blocks = findEligibleCodeBlocks();

    stopObserver();

    if (blocks.length > 0) {
      void enhanceBlocks(runtimeUrl, grammarMap, blocks);
    }
  }, OBSERVE_TIMEOUT_MS);
}

/**
 * Stop and clear the temporary DOM observer.
 */
function stopObserver() {
  if (observer !== null) {
    observer.disconnect();
    observer = null;
  }

  if (observerTimer !== null) {
    window.clearTimeout(observerTimer);
    observerTimer = null;
  }
}

/**
 * Find mounted code blocks eligible for syntax highlighting.
 *
 * Untyped code blocks are intentionally skipped instead of using automatic
 * language detection. This prevents source code from being incorrectly
 * classified and keeps output deterministic.
 *
 * @returns {HTMLElement[]}
 */
function findEligibleCodeBlocks() {
  return Array.from(document.querySelectorAll("pre > code")).filter(
    (codeBlock) => {
      const pre = codeBlock.parentElement;

      if (pre === null) {
        return false;
      }

      if (isAlreadyProcessed(codeBlock)) {
        return false;
      }

      if (isMermaidCodeBlock(codeBlock, pre)) {
        return false;
      }

      const language = getDeclaredLanguage(codeBlock);

      if (language === null || SKIPPED_LANGUAGES.has(language)) {
        return false;
      }

      return true;
    },
  );
}

/**
 * Load Highlight.js and process the supplied blocks.
 *
 * @param {string} runtimeUrl
 * @param {Map<string, string>} grammarMap
 * @param {HTMLElement[]} blocks
 */
async function enhanceBlocks(runtimeUrl, grammarMap, blocks) {
  const highlighter = await loadHighlighter(runtimeUrl);

  if (highlighter === null) {
    markRuntimeFailure(blocks);
    return;
  }

  await highlightBlocks(highlighter, grammarMap, blocks);
}

/**
 * Load the configured classic Highlight.js browser bundle.
 *
 * A successful runtime is reused for the lifetime of the SPA. Concurrent calls
 * share one promise and cannot append duplicate script elements.
 *
 * @param {string} runtimeUrl
 * @returns {Promise<object | null>}
 */
function loadHighlighter(runtimeUrl) {
  const existingHighlighter = getHighlighter();

  if (existingHighlighter !== null) {
    loadedRuntimeUrl ??= runtimeUrl;
    return Promise.resolve(existingHighlighter);
  }

  if (runtimePromise !== null) {
    return runtimePromise;
  }

  loadedRuntimeUrl = runtimeUrl;

  runtimePromise = new Promise((resolve) => {
    const existingScript = findRuntimeScript(runtimeUrl);

    if (existingScript !== null) {
      attachRuntimeListeners(existingScript, resolve);
      return;
    }

    const script = document.createElement("script");

    script.src = runtimeUrl;
    script.async = true;
    script.crossOrigin = "anonymous";
    script.setAttribute(SCRIPT_ATTRIBUTE, runtimeUrl);

    attachRuntimeListeners(script, resolve);
    document.head.appendChild(script);
  }).finally(() => {
    if (getHighlighter() === null) {
      runtimePromise = null;
      loadedRuntimeUrl = null;
    }
  });

  return runtimePromise;
}

/**
 * Resolve runtime loading from an existing or newly created script element.
 *
 * @param {HTMLScriptElement} script
 * @param {(highlighter: object | null) => void} resolve
 */
function attachRuntimeListeners(script, resolve) {
  const existingHighlighter = getHighlighter();

  if (existingHighlighter !== null) {
    resolve(existingHighlighter);
    return;
  }

  let settled = false;

  const finish = (value) => {
    if (settled) {
      return;
    }

    settled = true;

    script.removeEventListener("load", onLoad);
    script.removeEventListener("error", onError);

    resolve(value);
  };

  const onLoad = () => {
    finish(getHighlighter());
  };

  const onError = () => {
    script.remove();
    finish(null);
  };

  script.addEventListener("load", onLoad, { once: true });
  script.addEventListener("error", onError, { once: true });
}

/**
 * Return the loaded Highlight.js browser API.
 *
 * @returns {object | null}
 */
function getHighlighter() {
  const highlighter = globalThis.hljs;

  if (
    highlighter === null ||
    highlighter === undefined ||
    typeof highlighter.highlightElement !== "function" ||
    typeof highlighter.getLanguage !== "function"
  ) {
    return null;
  }

  return highlighter;
}

/**
 * Find an Arata-managed runtime script for the configured URL.
 *
 * @param {string} runtimeUrl
 * @returns {HTMLScriptElement | null}
 */
function findRuntimeScript(runtimeUrl) {
  const scripts = document.querySelectorAll(`script[${SCRIPT_ATTRIBUTE}]`);

  for (const script of scripts) {
    if (script.getAttribute(SCRIPT_ATTRIBUTE) === runtimeUrl) {
      return script;
    }
  }

  return null;
}

/**
 * Highlight each block, loading required grammars on demand.
 *
 * @param {object} highlighter
 * @param {Map<string, string>} grammarMap
 * @param {HTMLElement[]} blocks
 */
async function highlightBlocks(highlighter, grammarMap, blocks) {
  // Group blocks by language
  const groups = new Map();

  for (const codeBlock of blocks) {
    if (isAlreadyProcessed(codeBlock)) {
      continue;
    }

    const pre = codeBlock.parentElement;
    if (pre === null || isMermaidCodeBlock(codeBlock, pre)) {
      continue;
    }

    const declaredLanguage = getDeclaredLanguage(codeBlock);
    if (declaredLanguage === null || SKIPPED_LANGUAGES.has(declaredLanguage)) {
      continue;
    }

    const runtimeLanguage = normalizeRuntimeLanguage(declaredLanguage);

    if (!groups.has(runtimeLanguage)) {
      groups.set(runtimeLanguage, []);
    }
    groups.get(runtimeLanguage).push(codeBlock);
  }

  // Process each language group
  for (const [runtimeLanguage, languageBlocks] of groups) {
    const alreadyRegistered = highlighter.getLanguage(runtimeLanguage);

    if (alreadyRegistered) {
      for (const codeBlock of languageBlocks) {
        highlightBlock(highlighter, codeBlock);
      }
      continue;
    }

    // Check if grammar is already loaded or loading
    const cached = grammarLoaded.has(runtimeLanguage);

    if (cached) {
      for (const codeBlock of languageBlocks) {
        highlightBlock(highlighter, codeBlock);
      }
      continue;
    }

    if (grammarPromises.has(runtimeLanguage)) {
      await grammarPromises.get(runtimeLanguage);
      for (const codeBlock of languageBlocks) {
        highlightBlock(highlighter, codeBlock);
      }
      continue;
    }

    // Try to load grammar
    const grammarUrl = grammarMap.get(runtimeLanguage);

    if (grammarUrl === undefined) {
      for (const codeBlock of languageBlocks) {
        markUnsupportedLanguage(codeBlock);
      }
      continue;
    }

    const promise = loadGrammar(grammarUrl, runtimeLanguage);
    grammarPromises.set(runtimeLanguage, promise);

    await promise;

    for (const codeBlock of languageBlocks) {
      highlightBlock(highlighter, codeBlock);
    }
  }
}

/**
 * Load a Highlight.js language grammar script.
 *
 * @param {string} url
 * @param {string} language
 * @returns {Promise<void | null>}
 */
function loadGrammar(url, language) {
  return new Promise((resolve) => {
    const script = document.createElement("script");

    script.src = url;
    script.async = true;
    script.crossOrigin = "anonymous";

    let settled = false;

    const finish = (value) => {
      if (settled) {
        return;
      }

      settled = true;

      script.removeEventListener("load", onLoad);
      script.removeEventListener("error", onError);

      if (value === true) {
        grammarLoaded.add(language);
      }

      resolve(value ? undefined : null);
    };

    const onLoad = () => {
      finish(true);
    };

    const onError = () => {
      script.remove();
      finish(false);
    };

    script.addEventListener("load", onLoad, { once: true });
    script.addEventListener("error", onError, { once: true });

    document.head.appendChild(script);
  });
}

/**
 * Highlight one code block using its explicitly declared language.
 *
 * @param {object} highlighter
 * @param {HTMLElement} codeBlock
 */
function highlightBlock(highlighter, codeBlock) {
  if (isAlreadyProcessed(codeBlock)) {
    return;
  }

  const pre = codeBlock.parentElement;

  if (pre === null || isMermaidCodeBlock(codeBlock, pre)) {
    return;
  }

  const declaredLanguage = getDeclaredLanguage(codeBlock);

  if (declaredLanguage === null || SKIPPED_LANGUAGES.has(declaredLanguage)) {
    return;
  }

  const runtimeLanguage = normalizeRuntimeLanguage(declaredLanguage);

  if (!highlighter.getLanguage(runtimeLanguage)) {
    markUnsupportedLanguage(codeBlock);
    return;
  }

  prepareLanguageMetadata(codeBlock, declaredLanguage, runtimeLanguage);

  try {
    highlighter.highlightElement(codeBlock);

    codeBlock.setAttribute(HIGHLIGHTED_ATTRIBUTE, "true");
    codeBlock.removeAttribute(FAILED_ATTRIBUTE);

    pre.classList.add("syntax-highlighted");
  } catch {
    codeBlock.setAttribute(FAILED_ATTRIBUTE, "true");
  }
}

/**
 * Preserve the author-facing language while exposing the normalized grammar
 * name to Highlight.js.
 *
 * Existing `language-*` classes are removed before the normalized class is
 * added. This prevents Highlight.js from selecting an unsupported alias such
 * as `language-js` before reaching `language-javascript`.
 *
 * The original language remains available through `data-lang`, which is used
 * by Arata's language-label enhancer.
 *
 * @param {HTMLElement} codeBlock
 * @param {string} declaredLanguage
 * @param {string} runtimeLanguage
 */
function prepareLanguageMetadata(codeBlock, declaredLanguage, runtimeLanguage) {
  if (!codeBlock.hasAttribute("data-lang")) {
    codeBlock.setAttribute("data-lang", declaredLanguage);
  }

  for (const className of Array.from(codeBlock.classList)) {
    if (className.startsWith("language-")) {
      codeBlock.classList.remove(className);
    }
  }

  codeBlock.classList.add(`language-${sanitizeLanguageClass(runtimeLanguage)}`);
}

/**
 * Mark blocks when the Highlight.js runtime fails to load.
 *
 * @param {HTMLElement[]} blocks
 */
function markRuntimeFailure(blocks) {
  for (const codeBlock of blocks) {
    codeBlock.setAttribute(FAILED_ATTRIBUTE, "true");
  }
}

/**
 * Mark an unsupported language as processed while leaving its source intact.
 *
 * @param {HTMLElement} codeBlock
 */
function markUnsupportedLanguage(codeBlock) {
  codeBlock.setAttribute(HIGHLIGHTED_ATTRIBUTE, "unsupported");
}

/**
 * Determine whether a code block has already been processed.
 *
 * Highlight.js uses `data-highlighted="yes"` after successful processing.
 * Arata mirrors that state into its own attribute when encountered.
 *
 * @param {HTMLElement} codeBlock
 * @returns {boolean}
 */
function isAlreadyProcessed(codeBlock) {
  if (codeBlock.hasAttribute(HIGHLIGHTED_ATTRIBUTE)) {
    return true;
  }

  if (codeBlock.hasAttribute(FAILED_ATTRIBUTE)) {
    return true;
  }

  if (codeBlock.dataset.highlighted === "yes") {
    codeBlock.setAttribute(HIGHLIGHTED_ATTRIBUTE, "true");
    return true;
  }

  return false;
}

/**
 * Determine whether the block belongs to the Mermaid renderer.
 *
 * @param {HTMLElement} codeBlock
 * @param {HTMLElement} pre
 * @returns {boolean}
 */
function isMermaidCodeBlock(codeBlock, pre) {
  const language = getDeclaredLanguage(codeBlock);

  if (language === "mermaid") {
    return true;
  }

  return (
    codeBlock.classList.contains("mermaid") ||
    codeBlock.classList.contains("language-mermaid") ||
    pre.classList.contains("mermaid") ||
    pre.dataset.arataMermaid === "true" ||
    codeBlock.dataset.arataMermaid === "true"
  );
}

/**
 * Read the language metadata produced by mork.
 *
 * `data-lang` takes precedence because it preserves the author-facing language
 * after aliases are normalized for Highlight.js.
 *
 * @param {HTMLElement} codeBlock
 * @returns {string | null}
 */
function getDeclaredLanguage(codeBlock) {
  const dataLanguage = codeBlock.getAttribute("data-lang");

  if (dataLanguage !== null && dataLanguage.trim() !== "") {
    return normalizeLanguageName(dataLanguage);
  }

  for (const className of codeBlock.classList) {
    if (!className.startsWith("language-")) {
      continue;
    }

    const language = className.slice("language-".length).trim();

    if (language !== "") {
      return normalizeLanguageName(language);
    }
  }

  return null;
}

/**
 * Convert common author-facing aliases to Highlight.js grammar names.
 *
 * @param {string} language
 * @returns {string}
 */
function normalizeRuntimeLanguage(language) {
  const normalized = normalizeLanguageName(language);
  return LANGUAGE_ALIASES.get(normalized) ?? normalized;
}

/**
 * Normalize language metadata for comparison.
 *
 * @param {string} language
 * @returns {string}
 */
function normalizeLanguageName(language) {
  return String(language).trim().toLowerCase();
}

/**
 * Convert a grammar name into a safe `language-*` class suffix.
 *
 * @param {string} language
 * @returns {string}
 */
function sanitizeLanguageClass(language) {
  return (
    normalizeLanguageName(language)
      .replace(/[^a-z0-9_-]+/g, "-")
      .replace(/^-+|-+$/g, "") || "plaintext"
  );
}

/**
 * Normalize and validate the configured runtime URL.
 *
 * Relative paths are allowed so users can replace the CDN asset with a
 * vendored local bundle.
 *
 * @param {string} value
 * @returns {string}
 */
function normalizeRuntimeUrl(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim();
}
