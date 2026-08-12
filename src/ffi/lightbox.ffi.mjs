// arata — lightbox FFI.
//
// This module does not render the lightbox. Rendering and state are owned by
// Gleam/Lustre. The FFI only observes DOM events that Lustre cannot attach
// directly because Markdown bodies are rendered with unsafe_raw_html, and
// applies the continuous zoom transform that would be janky to drive through
// the update loop.
//
// Responsibilities:
//   - capture clicks on `.body img`
//   - collect the current page's `.body img` gallery
//   - dispatch gallery srcs/alts as separator-joined strings plus clicked index
//   - dispatch Escape / ArrowLeft / ArrowRight key presses to Gleam
//   - lock/unlock page scrolling while the lightbox is open
//   - zoom/pan the lightbox preview (click toggle, wheel zoom, drag pan,
//     two-finger pinch on touch devices)
//   - hide the previous frame and show a loading placeholder while a new
//     lightbox image loads, so a still-loading image never shows the
//     previously decoded frame or a bare black preview
//   - report coarse zoom state changes to Gleam so the model stays truthful
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
//   - zoom transforms are applied to Lustre-rendered DOM via delegated events,
//     so they survive Lustre re-renders of unrelated state
//   - zoom always resets on open, close, and image change

const FIELD_SEPARATOR = "\u001e";

const ZOOM_CLICK_SCALE = 2;
const MAX_ZOOM = 5;
const ZOOM_IN_FACTOR = 1.12;
const ZOOM_OUT_FACTOR = 1 / 1.12;

let subscribed = false;
let currentOpenCallback = null;
let currentCloseCallback = null;
let currentPreviousCallback = null;
let currentNextCallback = null;
let currentZoomChangedCallback = null;

let zoomState = { scale: 1, tx: 0, ty: 0 };
let isDragging = false;
let dragged = false;
let dragStart = null;
let suppressClick = false;
let lastZoomed = false;

// Active pointers on the preview frame, used to detect pinch gestures.
let activePointers = new Map();
let pinchState = null; // { lastDistance }

let lightboxImageObserver = null;

export function subscribe_to_lightbox_events(
  onOpen,
  onClose,
  onPrevious,
  onNext,
  onZoomChanged,
) {
  currentOpenCallback = onOpen;
  currentCloseCallback = onClose;
  currentPreviousCallback = onPrevious;
  currentNextCallback = onNext;
  currentZoomChangedCallback = onZoomChanged;

  if (subscribed) return;

  document.addEventListener("click", handleDocumentClick);
  window.addEventListener("keydown", handleKeyDown);
  document.addEventListener("wheel", handleLightboxWheel, { passive: false });
  document.addEventListener("pointerdown", handleLightboxPointerDown);
  document.addEventListener("pointermove", handleLightboxPointerMove);
  document.addEventListener("pointerup", handleLightboxPointerUp);
  document.addEventListener("pointercancel", handleLightboxPointerUp);
  document.addEventListener("load", handleLightboxImageLoad, true);
  document.addEventListener("error", handleLightboxImageError, true);

  ensureLightboxImageObserver();

  subscribed = true;
}

function ensureLightboxImageObserver() {
  if (lightboxImageObserver) return;

  lightboxImageObserver = new MutationObserver(handleLightboxImageMutations);
  lightboxImageObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["src"],
    subtree: true,
  });
}

// Lustre reuses the lightbox `<img>` node when navigating and only patches its
// `src` attribute. Browsers keep displaying the previously decoded frame while
// the new source is still loading. The node must NOT be replaced — Lustre's
// reconciler caches node references, so swapping the element would make later
// patches target a detached node. Instead the old frame is hidden with opacity
// and a loading placeholder is shown until the new source decodes; the
// load/error handlers fade the new image back in.
function handleLightboxImageMutations(mutations) {
  for (const mutation of mutations) {
    if (mutation.type !== "attributes") continue;
    const image = mutation.target;
    if (!(image instanceof HTMLImageElement)) continue;
    if (!image.classList.contains("lightbox-image")) continue;

    // Already decoded (cached or previously shown): the browser swaps the
    // frame immediately, so there is nothing stale to hide.
    if (image.complete && image.naturalWidth > 0) continue;

    // Hide the previous frame and show the loading placeholder while the new
    // source loads.
    markLightboxImageLoading(image);
    return;
  }
}

function markLightboxImageLoading(image) {
  const frame = image.closest(".lightbox-image-frame");
  if (frame) frame.classList.add("lightbox-image-frame--loading");
  image.style.opacity = "0";
}


export function set_lightbox_scroll_lock(locked) {
  if (typeof document === "undefined") return;

  const html = document.documentElement;
  const body = document.body;

  if (!html || !body) return;

  html.classList.toggle("lightbox-open", Boolean(locked));
  body.classList.toggle("lightbox-open", Boolean(locked));

  // When opening, the overlay is rendered after this effect runs, so mark the
  // preview as loading on the next frame if its image has not decoded yet.
  if (locked) {
    window.requestAnimationFrame(() => {
      const image = document.querySelector(".lightbox-image");
      if (!image) return;
      if (image.complete && image.naturalWidth > 0) return;
      markLightboxImageLoading(image);
    });
  }

  // The lightbox lifecycle always starts and ends at fit zoom.
  reset_lightbox_zoom();
}

export function reset_lightbox_zoom() {
  zoomState = { scale: 1, tx: 0, ty: 0 };
  isDragging = false;
  dragged = false;
  dragStart = null;
  suppressClick = false;
  activePointers.clear();
  pinchState = null;

  const frame = document.querySelector(".lightbox-image-frame");
  if (frame) {
    frame.classList.remove("lightbox-image-frame--dragging");
    frame.classList.remove("lightbox-image-frame--animating");
    frame.classList.remove("lightbox-image-frame--loading");
    const image = frame.querySelector(".lightbox-image");
    if (image) image.style.transform = "";
  }

  // Every reset path also resets the model's zoomed flag (open, close, and
  // image change all set it to fit), so there is nothing to report here.
  lastZoomed = false;
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

  // A click that follows a drag-pan must not be treated as a zoom toggle.
  if (suppressClick) {
    suppressClick = false;
    return;
  }

  // Clicking the lightbox preview toggles zoom in/out around the cursor.
  const frame = target.closest(".lightbox-image-frame");
  if (frame) {
    event.preventDefault();
    event.stopPropagation();
    toggleZoomAt(event.clientX, event.clientY);
    return;
  }

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

// ZOOM -----------------------------------------------------------------------

function handleLightboxWheel(event) {
  if (!isLightboxOpen()) return;
  const target = event.target;
  if (!(target instanceof Element)) return;
  if (!target.closest(".lightbox-image-frame")) return;

  event.preventDefault();
  zoomAt(
    event.clientX,
    event.clientY,
    event.deltaY < 0 ? ZOOM_IN_FACTOR : ZOOM_OUT_FACTOR,
  );
}

function handleLightboxPointerDown(event) {
  if (!isLightboxOpen()) return;
  if (event.button !== 0) return;
  const target = event.target;
  if (!(target instanceof Element)) return;
  if (!target.closest(".lightbox-image-frame")) return;

  const frame = target.closest(".lightbox-image-frame");

  // A second finger on the preview begins a pinch gesture.
  if (activePointers.size === 1) {
    activePointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
    const points = framePointers();
    pinchState = { lastDistance: pointerDistance(points[0], points[1]) };

    // A pinch supersedes any in-progress single-finger pan.
    isDragging = false;
    dragged = false;
    dragStart = null;
    frame.classList.remove("lightbox-image-frame--dragging");

    event.preventDefault();
    return;
  }

  // The pinch pair is the first two fingers; extra fingers are ignored.
  if (activePointers.size >= 2) return;

  activePointers.set(event.pointerId, { x: event.clientX, y: event.clientY });

  // Single-finger panning only makes sense while zoomed in.
  if (zoomState.scale <= 1) return;

  isDragging = true;
  dragged = false;
  dragStart = {
    x: event.clientX,
    y: event.clientY,
    tx: zoomState.tx,
    ty: zoomState.ty,
  };
  frame.classList.add("lightbox-image-frame--dragging");

  // Prevent native image drag, text selection, and touch gestures.
  event.preventDefault();
}

function handleLightboxPointerMove(event) {
  if (!activePointers.has(event.pointerId)) return;
  activePointers.set(event.pointerId, { x: event.clientX, y: event.clientY });

  // Two-finger pinch: zoom around the midpoint of the fingers.
  if (pinchState && activePointers.size === 2) {
    const points = framePointers();
    const distance = pointerDistance(points[0], points[1]);

    if (pinchState.lastDistance > 0) {
      const factor = distance / pinchState.lastDistance;
      if (Math.abs(factor - 1) > 0.005) {
        zoomAt(
          (points[0].x + points[1].x) / 2,
          (points[0].y + points[1].y) / 2,
          factor,
        );
      }
    }
    pinchState.lastDistance = distance;
    return;
  }

  if (!isDragging || !dragStart) return;

  dragged = true;
  zoomState.tx = dragStart.tx + (event.clientX - dragStart.x);
  zoomState.ty = dragStart.ty + (event.clientY - dragStart.y);
  clampPan();
  applyZoom();
}

function handleLightboxPointerUp(event) {
  if (!activePointers.has(event.pointerId)) return;
  activePointers.delete(event.pointerId);

  // End of a pinch: if one finger remains while zoomed, resume panning with it.
  if (pinchState) {
    pinchState = null;

    if (activePointers.size === 1 && zoomState.scale > 1) {
      const remaining = framePointers()[0];
      isDragging = true;
      dragged = false;
      dragStart = {
        x: remaining.x,
        y: remaining.y,
        tx: zoomState.tx,
        ty: zoomState.ty,
      };
      const frame = document.querySelector(".lightbox-image-frame");
      if (frame) frame.classList.add("lightbox-image-frame--dragging");
    }
    return;
  }

  if (!isDragging) return;

  isDragging = false;
  dragStart = null;

  // A click that follows a drag-pan must not toggle zoom. Only the release
  // right after the drag is affected, so expire the flag shortly after.
  if (dragged) {
    suppressClick = true;
    window.setTimeout(() => {
      suppressClick = false;
    }, 300);
  }
  dragged = false;

  const frame = document.querySelector(".lightbox-image-frame");
  if (frame) frame.classList.remove("lightbox-image-frame--dragging");
}

function framePointers() {
  return Array.from(activePointers.values());
}

function pointerDistance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function handleLightboxImageLoad(event) {
  const target = event.target;
  if (!(target instanceof HTMLImageElement)) return;
  if (!target.classList.contains("lightbox-image")) return;

  // Fade the freshly loaded image back in and hide the loading placeholder.
  target.style.opacity = "";
  const frame = target.closest(".lightbox-image-frame");
  if (frame) frame.classList.remove("lightbox-image-frame--loading");

  if (!isLightboxOpen()) return;

  // Re-derive pan bounds once the image dimensions are known, so a zoom
  // performed before the preview finished loading can still be panned.
  clampPan();
  applyZoom();
}

function handleLightboxImageError(event) {
  const target = event.target;
  if (!(target instanceof HTMLImageElement)) return;
  if (!target.classList.contains("lightbox-image")) return;

  // Never leave a failed image hidden or stuck on the loading placeholder.
  target.style.opacity = "";
  const frame = target.closest(".lightbox-image-frame");
  if (frame) frame.classList.remove("lightbox-image-frame--loading");
}

function toggleZoomAt(clientX, clientY) {
  const frame = document.querySelector(".lightbox-image-frame");
  const image = frame && frame.querySelector(".lightbox-image");
  if (!frame || !image) return;

  if (zoomState.scale > 1) {
    setZoomState(1, 0, 0);
    return;
  }

  const rect = image.getBoundingClientRect();
  const cLocalX = clientX - rect.left;
  const cLocalY = clientY - rect.top;
  const ratio = ZOOM_CLICK_SCALE;

  setZoomState(ratio, cLocalX * (1 - ratio), cLocalY * (1 - ratio));
}

function zoomAt(clientX, clientY, factor) {
  const frame = document.querySelector(".lightbox-image-frame");
  const image = frame && frame.querySelector(".lightbox-image");
  if (!frame || !image) return;

  const rect = image.getBoundingClientRect();
  const cLocalX = clientX - rect.left;
  const cLocalY = clientY - rect.top;

  const currentScale = zoomState.scale;
  const nextScale = clamp(currentScale * factor, 1, MAX_ZOOM);
  const ratio = nextScale / currentScale;

  const nextTx = zoomState.tx + cLocalX * (1 - ratio);
  const nextTy = zoomState.ty + cLocalY * (1 - ratio);

  setZoomState(nextScale, nextTx, nextTy);
}

function setZoomState(scale, tx, ty) {
  const wasZoomed = zoomState.scale > 1;
  zoomState = { scale, tx, ty };
  clampPan();

  // Animate discrete zoom steps but keep drag panning instant.
  const frame = document.querySelector(".lightbox-image-frame");
  if (frame && wasZoomed !== (zoomState.scale > 1)) {
    frame.classList.add("lightbox-image-frame--animating");
    window.setTimeout(() => {
      frame.classList.remove("lightbox-image-frame--animating");
    }, 160);
  }

  applyZoom();
}

function applyZoom() {
  const frame = document.querySelector(".lightbox-image-frame");
  const image = frame && frame.querySelector(".lightbox-image");
  if (!frame || !image) return;

  if (zoomState.scale <= 1) {
    image.style.transform = "";
  } else {
    image.style.transformOrigin = "0 0";
    image.style.transform =
      `translate(${zoomState.tx}px, ${zoomState.ty}px) scale(${zoomState.scale})`;
  }

  syncZoomedFlag(zoomState.scale > 1);
}

function clampPan() {
  const frame = document.querySelector(".lightbox-image-frame");
  const image = frame && frame.querySelector(".lightbox-image");
  if (!frame || !image) return;

  // offsetWidth/Height ignore transforms, so they report the fit size.
  const baseWidth = image.offsetWidth;
  const baseHeight = image.offsetHeight;
  const frameWidth = frame.clientWidth;
  const frameHeight = frame.clientHeight;

  const maxTx = Math.max(0, (baseWidth * zoomState.scale - frameWidth) / 2);
  const maxTy = Math.max(0, (baseHeight * zoomState.scale - frameHeight) / 2);

  zoomState.tx = clamp(zoomState.tx, -maxTx, maxTx);
  zoomState.ty = clamp(zoomState.ty, -maxTy, maxTy);
}

function syncZoomedFlag(zoomed) {
  if (zoomed === lastZoomed) return;
  lastZoomed = zoomed;
  if (currentZoomChangedCallback) currentZoomChangedCallback(zoomed);
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

// HELPERS --------------------------------------------------------------------

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
