// arata — analytics FFI: dynamically injects the analytics provider's script
// into the document head, mirroring apollo's `partials/header.html` analytics
// section.
//
// Because arata doesn't yet have a custom index.html (Phase 17), the scripts
// are injected dynamically on first load. The provider is selected by the
// `Analytics` config type:
//   - GoatCounter
//   - Umami
//   - Liwan

function analytics_already_injected() {
  return document.getElementById("arata-analytics") !== null;
}

export function inject_umami(website_id, src) {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (analytics_already_injected()) return;
  if (!src || !website_id) return;

  const script = document.createElement("script");
  script.defer = true;
  script.id = "arata-analytics";
  script.src = src;
  script.setAttribute("data-website-id", website_id);

  document.head.appendChild(script);
}

export function inject_liwan(data_entity, src) {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (analytics_already_injected()) return;
  if (!src || !data_entity) return;

  const script = document.createElement("script");
  script.type = "module";
  script.id = "arata-analytics";
  script.src = src;
  script.setAttribute("data-entity", data_entity);

  document.head.appendChild(script);
}

export function inject_goatcounter(data_goatcounter, src) {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (analytics_already_injected()) return;
  if (!src || !data_goatcounter) return;

  // GoatCounter SPA integration reference:
  // https://www.goatcounter.com/help/spa
  // GoatCounter's official SPA example is designed for hash-based routing.
  // It sets `no_onload: true` and listens to the `hashchange` event.
  // But arata does not use hash routing.
  // This implementation adapts the official GoatCounter SPA idea to normal
  // path routing by hooking into the browser History API:
  //
  //   - `history.pushState` for normal client-side navigations
  //   - `history.replaceState` for route replacements
  //   - `popstate` for browser back/forward navigation

  window.goatcounter = { no_onload: true };

  let lastPath = "";

  function count() {
    if (!window.goatcounter || typeof window.goatcounter.count !== "function") {
      return;
    }

    const path = location.pathname + location.search + location.hash;

    if (path === lastPath) {
      return;
    }

    lastPath = path;

    window.goatcounter.count({ path });
  }

  window.addEventListener("popstate", count);

  const pushState = history.pushState;
  history.pushState = function () {
    const result = pushState.apply(this, arguments);
    count();
    return result;
  };

  const replaceState = history.replaceState;
  history.replaceState = function () {
    const result = replaceState.apply(this, arguments);
    count();
    return result;
  };

  const script = document.createElement("script");
  script.id = "arata-analytics";
  script.setAttribute("data-goatcounter", data_goatcounter);
  script.async = true;
  script.src = src;

  script.addEventListener("load", count);

  document.head.appendChild(script);
}
