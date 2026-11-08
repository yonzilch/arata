// arata — video FFI: runtime enhancement for `video` shortcode output.
//
// The build-time `video` shortcode emits semantic native markup:
// a <figure class="video-embed" data-arata-video="true"> containing a
// <div data-video-player> with a native <video controls> and a direct
// source link. This module upgrades that native video with the default
// runtime player (ArtPlayer) while preserving the baseline on failure.
//
// Important invariants:
// - ArtPlayer is loaded only when mounted content contains video shortcode
//   output; pages without embeds never download it.
// - The HLS provider (hls.js) is loaded only when an HLS source requires it
//   and the browser cannot play HLS natively.
// - Each mounted container owns at most one player instance and one provider
//   instance; repeated enhancement calls never create a second player.
// - Async initialization that completes after its container was removed is
//   discarded; cleanup is idempotent and releases player, provider,
//   listeners, and media requests.
// - Enhancement failure never removes the native video or the source link.

const ARTPLAYER_URL = "https://cdn.jsdelivr.net/npm/artplayer@5.2.0/dist/artplayer.js";
const HLS_URL = "https://cdn.jsdelivr.net/npm/hls.js@1.5.18/dist/hls.min.js";

const SELECTOR = "[data-arata-video]";
const OBSERVE_TIMEOUT_MS = 1500;

let instances = new Map();
let generation = 0;
let scheduled = false;
let observer = null;
let observerTimer = null;
let artplayerPromise = null;
let hlsPromise = null;

export function enhance_videos() {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  // Prune players whose containers left the document (SPA content swap).
  pruneDetached();
  if (scheduled) return;
  scheduled = true;
  afterPaint(() => {
    scheduled = false;
    const containers = findContainers();
    if (containers.length > 0) {
      stopObserver();
      void enhanceAsync(containers, ++generation);
      return;
    }
    observeUntilVideosExist();
  });
}

export function cleanup_videos() {
  generation += 1;
  stopObserver();
  scheduled = false;
  destroyAll();
}

function afterPaint(callback) {
  if (typeof window.requestAnimationFrame === "function") {
    window.requestAnimationFrame(() => window.requestAnimationFrame(callback));
  } else {
    window.setTimeout(callback, 0);
  }
}

function observeUntilVideosExist() {
  if (observer || typeof MutationObserver === "undefined") return;
  if (typeof document.body === "undefined" || document.body === null) {
    // Body may not exist yet; retry on the next paint.
    afterPaint(() => observeUntilVideosExist());
    return;
  }
  observer = new MutationObserver(() => {
    const containers = findContainers();
    if (containers.length > 0) {
      stopObserver();
      void enhanceAsync(containers, ++generation);
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });
  observerTimer = window.setTimeout(() => {
    stopObserver();
  }, OBSERVE_TIMEOUT_MS);
}

function stopObserver() {
  if (observer) {
    try {
      observer.disconnect();
    } catch {
      // Ignore disconnect errors during teardown.
    }
    observer = null;
  }
  if (observerTimer) {
    window.clearTimeout(observerTimer);
    observerTimer = null;
  }
}

function findContainers() {
  return Array.from(document.querySelectorAll(SELECTOR)).filter((el) => !instances.has(el));
}

function pruneDetached() {
  for (const [container] of instances) {
    if (!document.contains(container)) {
      destroyInstance(container);
    }
  }
}

async function enhanceAsync(containers, gen) {
  let ArtplayerCtor;
  try {
    ArtplayerCtor = await loadArtPlayer();
  } catch {
    return;
  }
  if (gen !== generation) return;

  const pending = containers.filter((el) => document.contains(el) && !instances.has(el));
  if (pending.length === 0) return;

  const needsProvider = pending.some((el) => needsHlsProvider(el));
  let HlsCtor = null;
  if (needsProvider) {
    try {
      HlsCtor = await loadHls();
    } catch {
      HlsCtor = null;
    }
    if (gen !== generation) return;
  }

  for (const container of pending) {
    if (gen !== generation) return;
    if (!document.contains(container)) continue;
    if (instances.has(container)) continue;
    // HLS sources that need the provider keep the native fallback when the
    // provider failed to load.
    if (needsHlsProvider(container) && !HlsCtor) continue;
    enhanceOne(container, ArtplayerCtor, HlsCtor);
  }
}

function needsHlsProvider(container) {
  const isHls = container.getAttribute("data-video-hls") === "true";
  if (!isHls) return false;
  return !nativeHlsSupported();
}

function nativeHlsSupported() {
  const probe = document.createElement("video");
  return Boolean(
    probe.canPlayType("application/vnd.apple.mpegurl") ||
      probe.canPlayType("application/x-mpegURL"),
  );
}

function enhanceOne(container, ArtplayerCtor, HlsCtor) {
  const nativeVideo = container.querySelector("video");
  if (!nativeVideo) return;
  const sourceEl = nativeVideo.querySelector("source");
  const src =
    (sourceEl && sourceEl.getAttribute("src")) ||
    nativeVideo.getAttribute("src") ||
    container.getAttribute("data-video-src") ||
    "";
  if (!src) return;
  const poster = nativeVideo.getAttribute("poster") || "";
  const autoplay = nativeVideo.hasAttribute("autoplay");
  const muted = nativeVideo.hasAttribute("muted");
  const loop = nativeVideo.hasAttribute("loop");
  const isHls = container.getAttribute("data-video-hls") === "true";
  const useNativeHls = isHls && nativeHlsSupported();
  const useProvider = isHls && !useNativeHls;

  const mount =
    container.querySelector("[data-video-player]") || container;
  const holder = document.createElement("div");
  holder.className = "video-embed-enhanced";
  // ArtPlayer sizes itself from its container; keep the holder collapsed
  // until the player is ready so the native video reserves layout space.
  holder.style.display = "none";
  mount.appendChild(holder);

  let providerInstance = null;
  const playerOptions = {
    container: holder,
    url: src,
    poster: poster || undefined,
    autoplay: Boolean(autoplay),
    muted: Boolean(muted),
    loop: Boolean(loop),
    playsInline: true,
    volume: 0.7,
  };
  if (isHls) {
    playerOptions.type = "m3u8";
    if (useProvider) {
      playerOptions.customType = {
        m3u8: (video, url) => {
          const hls = new HlsCtor();
          providerInstance = hls;
          hls.loadSource(url);
          hls.attachMedia(video);
        },
      };
    }
  }
  if (useNativeHls) {
    // Let the browser's native HLS pipeline handle the stream.
    playerOptions.type = "m3u8";
  }

  let art;
  try {
    art = new ArtplayerCtor(playerOptions);
  } catch {
    try {
      holder.remove();
    } catch {
      // Ignore removal errors on already-detached nodes.
    }
    return;
  }

  const record = {
    container,
    mount,
    holder,
    art,
    hls: providerInstance,
    nativeVideo,
    readyHandler: null,
  };
  instances.set(container, record);
  holder.style.display = "";
  container.classList.add("is-enhanced");

  const onReady = () => {
    if (!instances.has(container)) return;
    try {
      nativeVideo.pause();
    } catch {
      // Native video may already be paused.
    }
    nativeVideo.style.display = "none";
    // ArtPlayer's own video element is already created; keep the record
    // provider in sync for cleanup.
    if (providerInstance && !record.hls) record.hls = providerInstance;
    if (autoplay && !muted) {
      // Autoplay with sound may be blocked; the player UI remains usable.
    }
  };
  record.readyHandler = onReady;
  try {
    art.on("ready", onReady);
  } catch {
    // If the emitter is unavailable, treat the player as ready.
    onReady();
  }
  // Some ArtPlayer builds signal readiness synchronously; make sure the
  // native fallback is hidden once the enhanced player exists.
  if (art.playing !== undefined) {
    // No-op: readiness is handled by the event above.
  }
}

function destroyAll() {
  // Copy keys first: destroyInstance mutates the map.
  for (const container of Array.from(instances.keys())) {
    destroyInstance(container);
  }
  instances.clear();
}

function destroyInstance(container) {
  const record = instances.get(container);
  if (!record) return;
  instances.delete(container);
  const { art, hls, holder, nativeVideo } = record;
  try {
    if (nativeVideo) nativeVideo.pause();
  } catch {
    // Native video may be detached.
  }
  try {
    if (hls && typeof hls.destroy === "function") hls.destroy();
  } catch {
    // Provider may already be destroyed.
  }
  try {
    if (art && typeof art.pause === "function") art.pause();
  } catch {
    // Player may already be paused.
  }
  try {
    if (art && typeof art.destroy === "function") art.destroy(false);
  } catch {
    // Player may already be destroyed.
  }
  try {
    if (holder) holder.remove();
  } catch {
    // Holder may already be detached.
  }
  try {
    if (nativeVideo) nativeVideo.style.display = "";
  } catch {
    // Restore is best-effort.
  }
  try {
    container.classList.remove("is-enhanced");
  } catch {
    // Class removal on detached nodes is best-effort.
  }
}

function loadArtPlayer() {
  if (typeof window.Artplayer !== "undefined") return Promise.resolve(window.Artplayer);
  if (artplayerPromise) return artplayerPromise;
  artplayerPromise = loadScript(ARTPLAYER_URL).then(() => {
    if (typeof window.Artplayer === "undefined") {
      throw new Error("ArtPlayer global missing after load");
    }
    return window.Artplayer;
  });
  // Allow a retry after failure so a later route with video can succeed.
  artplayerPromise.catch(() => {
    artplayerPromise = null;
  });
  return artplayerPromise;
}

function loadHls() {
  if (typeof window.Hls !== "undefined") return Promise.resolve(window.Hls);
  if (hlsPromise) return hlsPromise;
  hlsPromise = loadScript(HLS_URL).then(() => {
    if (typeof window.Hls === "undefined") {
      throw new Error("Hls global missing after load");
    }
    return window.Hls;
  });
  hlsPromise.catch(() => {
    hlsPromise = null;
  });
  return hlsPromise;
}

function loadScript(url) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = url;
    script.async = true;
    script.onload = () => resolve(undefined);
    script.onerror = () => reject(new Error(`Failed to load ${url}`));
    document.head.appendChild(script);
  });
}
