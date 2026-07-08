// arata — code-block FFI: inject copy buttons and language labels into
// rendered post body code blocks.
//
// This enhancer is intentionally idempotent and timing-tolerant. Lustre route
// effects can run before unsafe_raw_html has been patched into the DOM, so this
// module schedules enhancement after paint and also observes DOM mutations
// briefly until enhanceable `pre > code` nodes appear.
//
// Mermaid fenced blocks are intentionally skipped here. A Markdown block like:
//
//   ```mermaid
//   graph TD
//     A --> B
//   ```
//
// is initially rendered as:
//
//   <pre><code class="language-mermaid">...</code></pre>
//
// That block must remain untouched for `script.ffi.mjs` to normalize and render
// with Mermaid. Adding copy buttons or language labels before Mermaid runs can
// create route/theme rerender races and pollute the diagram source.

const copyIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M10 1.5a.5.5 0 0 1 .5-.5h2a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h2a.5.5 0 0 1 .5.5V3h3V1.5zM6.5 3V2h3v1h-3zm4 0v1h2a1 1 0 0 0-1-1h-2V3zm-5 0H3a1 1 0 0 0-1 1v11a1 1 0 0 0 1 1h9a1 1 0 0 0 1-1V4a1 1 0 0 0-1-1H5.5V3z"/></svg>`;
const successIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M13.485 1.85a.5.5 0 0 1 1.065.02.75.75 0 0 1-.02 1.065L5.82 12.78a.75.75 0 0 1-1.106.02L1.476 9.346a.75.75 0 1 1 1.05-1.07l2.74 2.742L12.44 2.92a.75.75 0 0 1 1.045-.07z"/></svg>`;
const errorIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M2.293 2.293a1 1 0 0 1 1.414 0L8 6.586l4.293-4.293a1 1 0 0 1 1.414 1.414L9.414 8l4.293 4.293a1 1 0 0 1-1.414 1.414L8 9.414l-4.293 4.293a1 1 0 0 1-1.414-1.414L6.586 8 2.293 3.707a1 1 0 0 1 0-1.414z"/></svg>`;

const OBSERVE_TIMEOUT_MS = 1500;

let scheduled = false;
let observer = null;
let observerTimer = null;

export function enhance_code_blocks() {
  if (typeof window === "undefined" || typeof document === "undefined") return;

  if (scheduled) return;
  scheduled = true;

  afterPaint(() => {
    scheduled = false;

    const enhanced = enhanceNow();

    if (enhanced > 0 || hasEnhanceableCodeBlocks()) {
      stopObserver();
      return;
    }

    observeUntilCodeBlocksExist();
  });
}

function afterPaint(callback) {
  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(callback);
  });
}

function observeUntilCodeBlocksExist() {
  stopObserver();

  observer = new MutationObserver(() => {
    const enhanced = enhanceNow();

    if (enhanced > 0 || hasEnhanceableCodeBlocks()) {
      stopObserver();
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });

  observerTimer = window.setTimeout(() => {
    enhanceNow();
    stopObserver();
  }, OBSERVE_TIMEOUT_MS);
}

function stopObserver() {
  if (observer) {
    observer.disconnect();
    observer = null;
  }

  if (observerTimer) {
    window.clearTimeout(observerTimer);
    observerTimer = null;
  }
}

function hasEnhanceableCodeBlocks() {
  return Array.from(document.querySelectorAll("pre code")).some((codeBlock) => {
    const pre = codeBlock.parentElement;

    if (!pre) return false;
    if (isMermaidCodeBlock(codeBlock, pre)) return false;
    if (pre.dataset.arataCodeEnhanced === "true") return false;

    return true;
  });
}

function enhanceNow() {
  const blocks = document.querySelectorAll("pre code");
  let enhancedCount = 0;

  blocks.forEach((codeBlock) => {
    const pre = codeBlock.parentElement;
    if (!pre) return;

    if (isMermaidCodeBlock(codeBlock, pre)) return;

    if (pre.dataset.arataCodeEnhanced === "true") return;
    if (pre.querySelector(".clipboard-button")) {
      pre.dataset.arataCodeEnhanced = "true";
      return;
    }

    pre.dataset.arataCodeEnhanced = "true";
    pre.style.position = "relative";

    const copyBtn = document.createElement("button");
    copyBtn.className = "clipboard-button";
    copyBtn.type = "button";
    copyBtn.innerHTML = copyIcon;
    copyBtn.setAttribute("aria-label", "Copy code to clipboard");

    copyBtn.addEventListener("click", async () => {
      try {
        const codeToCopy = getCodeText(codeBlock);

        if (!navigator.clipboard || !navigator.clipboard.writeText) {
          throw new Error("Clipboard API unavailable");
        }

        await navigator.clipboard.writeText(codeToCopy);
        changeIcon(copyBtn, true);
      } catch {
        changeIcon(copyBtn, false);
      }
    });

    pre.appendChild(copyBtn);

    const lang = getCodeLanguage(codeBlock);
    const safeLang = normalizeLanguageClass(lang);

    const label = document.createElement("span");
    label.className = "code-label label-" + safeLang;
    label.textContent = lang.toUpperCase();

    pre.appendChild(label);

    pinOnHorizontalScroll(pre, copyBtn, label);

    enhancedCount += 1;
  });

  return enhancedCount;
}

function isMermaidCodeBlock(codeBlock, pre) {
  const lang = getCodeLanguage(codeBlock);

  if (normalizeLanguageClass(lang) === "mermaid") return true;

  if (codeBlock.classList.contains("language-mermaid")) return true;
  if (codeBlock.classList.contains("mermaid")) return true;
  if (pre.classList.contains("mermaid")) return true;
  if (pre.dataset.arataMermaid === "true") return true;
  if (codeBlock.dataset.arataMermaid === "true") return true;

  return false;
}

function getCodeLanguage(codeBlock) {
  const dataLang = codeBlock.getAttribute("data-lang");

  if (dataLang && dataLang.trim() !== "") {
    return dataLang.trim();
  }

  for (const className of codeBlock.classList) {
    if (className.startsWith("language-")) {
      const lang = className.slice("language-".length).trim();

      if (lang !== "") {
        return lang;
      }
    }
  }

  return "default";
}

function pinOnHorizontalScroll(pre, copyBtn, label) {
  let ticking = false;

  pre.addEventListener("scroll", () => {
    if (ticking) return;

    window.requestAnimationFrame(() => {
      const offset = `-${pre.scrollLeft}px`;
      copyBtn.style.right = offset;
      label.style.right = offset;
      ticking = false;
    });

    ticking = true;
  });
}

function getCodeText(codeBlock) {
  const clone = codeBlock.cloneNode(true);
  clone.querySelectorAll(".giallo-ln").forEach((el) => el.remove());
  return clone.textContent.trim();
}

function changeIcon(button, isSuccess) {
  button.innerHTML = isSuccess ? successIcon : errorIcon;

  window.setTimeout(() => {
    button.innerHTML = copyIcon;
  }, 2000);
}

function normalizeLanguageClass(lang) {
  return (
    String(lang)
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, "-")
      .replace(/^-+|-+$/g, "") || "default"
  );
}
