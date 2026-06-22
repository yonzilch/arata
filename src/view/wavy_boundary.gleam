//// The wavy section boundary: a soft, SVG-based divider between two sections
//// of the site — a feature apollo does NOT have, designed fresh for arata.
////
//// Renders an `<svg>` with a gentle sine-like curve that stretches to full
//// width (`preserveAspectRatio="none"`). The `fill` is parameterised by the
//// "below" background so the wave blends into the next section, creating a
//// smooth visual transition. A second, offset path with the "above"
//// background creates a subtle layered effect.
////
//// Honours apollo's "no animation" ethos: no keyframes, no transitions. The
//// SVG is pure CSS — cheap to render and theme-aware via CSS custom
//// properties.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg

/// Render a wavy boundary between two sections.
///
/// - `above_bg`: the CSS background colour of the section above (e.g.
///   `"var(--bg-0)"`). Used for the back layer of the wave.
/// - `below_bg`: the CSS background colour of the section below (e.g.
///   `"var(--bg-1)"`). Used for the front layer of the wave, so it blends
///   into the next section.
///
/// The SVG uses `viewBox="0 0 1440 80"` and `preserveAspectRatio="none"` so it
/// stretches to any width while the wave height stays fixed at 80px. The path
/// is a gentle cubic bezier sine approximation.
pub fn view(above_bg: String, below_bg: String) -> Element(msg) {
  html.div([attribute.class("wavy-boundary")], [
    html.svg(
      [
        attribute.attribute("viewBox", "0 0 1440 80"),
        attribute.attribute("preserveAspectRatio", "none"),
        attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      ],
      [
        // Back layer: the "above" colour, a slightly smaller wave.
        svg.path([
          attribute.attribute(
            "d",
            "M0,40 C240,80 480,0 720,40 C960,80 1200,0 1440,40 L1440,80 L0,80 Z",
          ),
          attribute.attribute("fill", above_bg),
        ]),
        // Front layer: the "below" colour, the main wave. This blends into
        // the next section.
        svg.path([
          attribute.attribute(
            "d",
            "M0,48 C240,88 480,8 720,48 C960,88 1200,8 1440,48 L1440,80 L0,80 Z",
          ),
          attribute.attribute("fill", below_bg),
        ]),
      ],
    ),
  ])
}
