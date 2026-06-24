// arata — lightbox FFI.
//
// This module does not render the lightbox. Rendering and state are owned by
// Gleam/Lustre. The FFI only observes DOM events that Lustre cannot attach
// directly because Markdown bodies are rendered with unsafe_raw_html.
//
// Responsibilities:
//   - capture clicks on `.body img`
//   - collect the current page's `.body img` gallery
//   - dispatch gallery srcs/alts as separator-joined strings plus clicked index
//   - dispatch Escape / ArrowLeft / ArrowRight key presses to Gleam
//   - lock/unlock page scrolling while the lightbox is open
//
// Important:
// JavaScript arrays are not Gleam lists. Do not pass JS arrays to Gleam
// callbacks typed as `List(String)`. Instead, this FFI joins arrays into string
// blobs using FIELD_SEPARATOR; `effect/lightbox.gleam` splits them back into
// real Gleam lists.
//
// Invariants:
//   - only `.body img` is observed
//   - logo/social/theme/search/project icons are ignored
//   - listeners are registered at most once
//   - repeated subscriptions update callbacks without duplicating listeners
//   - overlay DOM is never created here; it is rendered by Lustre

const FIELD_SEPARATOR = "\u001e";

let subscribed = false;
let currentOpenCallback = null;
let currentCloseCallback = null;
let currentPreviousCallback = null;
let currentNextCallback = null;

export function subscribe_to_lightbox_events(
  onOpen,
  onClose,
  onPrevious,
  onNext,
) {
  currentOpenCallback = onOpen;
  currentCloseCallback = onClose;
  currentPreviousCallback = onPrevious;
  currentNextCallback = onNext;

  if (subscribed) return;

  document.addEventListener("click", handleDocumentClick);
  window.addEventListener("keydown", handleKeyDown);

  subscribed = true;
}

export function set_lightbox_scroll_lock(locked) {
  if (typeof document === "undefined") return;

  const html = document.documentElement;
  const body = document.body;

  if (!html || !body) return;

  html.classList.toggle("lightbox-open", Boolean(locked));
  body.classList.toggle("lightbox-open", Boolean(locked));
}

function preloadNearbyImages(srcs, index) {
  if (!Array.isArray(srcs)) return;

  preloadImage(srcs.at(index - 1));
  preloadImage(srcs.at(index + 1));
}

const preloadedImages = new Set();

function preloadImage(src) {
  if (!src) return;
  if (preloadedImages.has(src)) return;
  preloadedImages.add(src);
  const image = new Image();
  image.decoding = "async";
  image.loading = "eager";
  image.fetchPriority = "high";
  image.src = src;
  if (typeof image.decode === "function") {
    image.decode().catch(() => {});
  }
}

function handleDocumentClick(event) {
  const target = event.target;

  if (!(target instanceof Element)) return;

  // Only Markdown/page body images should open the lightbox.
  const image = target.closest(".body img");

  if (!(image instanceof HTMLImageElement)) return;

  // Do not react to images inside the lightbox overlay itself.
  if (target.closest(".lightbox-backdrop")) return;

  // Allow authors to opt out for a specific image or wrapper if needed:
  //   <img data-no-lightbox ...>
  //   <span data-no-lightbox><img ...></span>
  if (image.closest("[data-no-lightbox]")) return;

  const gallery = collectBodyImageGallery();
  const index = gallery.elements.indexOf(image);

  if (index < 0) return;

  // If the Markdown image is wrapped in a link, prefer opening the lightbox
  // instead of navigating away.
  event.preventDefault();
  event.stopPropagation();

  if (currentOpenCallback) {
    currentOpenCallback(
      joinFields(gallery.srcs),
      joinFields(gallery.alts),
      index,
    );
  }
  queueMicrotask(() => {
    preloadNearbyImages(gallery.srcs, index);
  });
}

function handleKeyDown(event) {
  if (!isLightboxOpen()) return;

  switch (event.key) {
    case "Escape":
      event.preventDefault();
      if (currentCloseCallback) currentCloseCallback();
      break;

    case "ArrowLeft":
      event.preventDefault();
      if (currentPreviousCallback) currentPreviousCallback();
      break;

    case "ArrowRight":
      event.preventDefault();
      if (currentNextCallback) currentNextCallback();
      break;

    default:
      break;
  }
}

function isLightboxOpen() {
  return document.querySelector(".lightbox-backdrop") !== null;
}

function collectBodyImageGallery() {
  const entries = Array.from(document.querySelectorAll(".body img"))
    .filter((image) => image instanceof HTMLImageElement)
    .filter((image) => !image.closest(".lightbox-backdrop"))
    .filter((image) => !image.closest("[data-no-lightbox]"))
    .map((image) => {
      const currentSrc = image.currentSrc || image.getAttribute("src") || "";

      // Only persist fully-loaded image sources.
      //
      // Without this guard, partially-loaded responsive/lazy images may expose
      // temporary currentSrc values that later change after loading finishes.
      if (image.complete && currentSrc) {
        image.dataset.lightboxSrc = currentSrc;
      }

      return {
        element: image,

        // Prefer:
        //   1. fully-loaded currentSrc
        //   2. last known fully-loaded src
        //   3. current currentSrc
        //   4. raw src attribute
        src:
          (image.complete && currentSrc) ||
          image.dataset.lightboxSrc ||
          currentSrc ||
          image.getAttribute("src") ||
          "",

        alt: getImageCaption(image),
      };
    })
    .filter((entry) => entry.src !== "");

  return {
    elements: entries.map((entry) => entry.element),
    srcs: entries.map((entry) => sanitizeField(entry.src)),
    alts: entries.map((entry) => sanitizeField(entry.alt)),
  };
}

function getImageCaption(image) {
  return (
    image.getAttribute("alt") ||
    image.getAttribute("title") ||
    ""
  ).trim();
}

function joinFields(values) {
  return values.map(sanitizeField).join(FIELD_SEPARATOR);
}

function sanitizeField(value) {
  return String(value).replaceAll(FIELD_SEPARATOR, " ");
}
