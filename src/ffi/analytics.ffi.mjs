// arata — analytics FFI: dynamically injects the analytics provider's script
// into the document head, mirroring apollo's `partials/header.html` analytics
// section.
//
// Because arata doesn't yet have a custom index.html (Phase 17), the scripts
// are injected dynamically on first load. The provider is selected by the
// `Analytics` config type:
//   - GoatCounter
//   - Umami

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

export function inject_goatcounter(data_goatcounter, src) {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (analytics_already_injected()) return;
  if (!src || !data_goatcounter) return;

  const script = document.createElement("script");
  script.id = "arata-analytics";
  script.setAttribute("data-goatcounter", data_goatcounter);
  script.async = true;
  script.src = src;

  document.head.appendChild(script);
}
