//// Sample blog content for arata.
////
//// Posts are authored directly as Gleam constants with pre-rendered HTML
//// bodies, following the pattern of the Lustre `01-routing` example. This
//// unblocks post-list and single-post rendering (ROADMAP Phase 5) and the
//// table-of-contents + meta-row rendering (ROADMAP Phase 6) before the
//// markdown build pipeline lands (ROADMAP Phase 17).
////
//// The HTML bodies use single-quoted attributes to keep the Gleam string
//// literals readable; the rendered output is identical. Each `<h2>` carries an
//// `id` matching the corresponding `TocEntry` so the TOC links resolve.
////
//// The `toc`, `word_count`, and `reading_time` fields are normally produced by
//// the build pipeline from the markdown source; here they are hand-authored to
//// match the bodies.

import data/post.{type Post, Post, TocEntry}
import gleam/option.{None, Some}

/// The full list of sample posts, newest first (the post list renders them in
/// this order; a later phase will sort by `date`).
pub fn posts() -> List(Post) {
  [
    Post(
      slug: "hello-arata",
      title: "Hello, arata",
      date: "2025-01-15",
      updated: Some("2025-01-18"),
      description: "Introducing arata — a faithful reimplementation of the apollo blog theme in Gleam and Lustre.",
      body: "
        <p>
          <strong>arata</strong> is a blog theme built with
          <a href='https://gleam.run'>Gleam</a> and
          <a href='https://hexdocs.pm/lustre'>Lustre</a>. It reproduces the
          minimal, typography-driven aesthetic of the
          <a href='https://github.com/not-matthias/apollo'>apollo</a> Zola theme
          as a client-side single-page application.
        </p>
        <h2 id='why-gleam'>Why Gleam?</h2>
        <p>
          Gleam is a typed, functional language that compiles to JavaScript and
          Erlang. Its exhaustiveness checking and immutable data make large view
          functions easy to refactor, which matters for a theme that will grow
          across nineteen roadmap phases.
        </p>
        <blockquote>
          <p>
            The Elm Architecture gives us a single source of truth: the Model.
            Every interaction flows through <code>update</code>, and the
            <code>view</code> is a pure function of state.
          </p>
        </blockquote>
        <h2 id='the-stack'>The stack</h2>
        <pre><code>gleam add lustre
gleam add modem
gleam add --dev lustre_dev_tools</code></pre>
        <p>
          Routing is handled by <code>modem</code> over the History API, so
          internal links are just ordinary <code>&lt;a&gt;</code> elements whose
          clicks are intercepted and dispatched as messages.
        </p>
      ",
      toc: [
        TocEntry(id: "why-gleam", title: "Why Gleam?", children: []),
        TocEntry(id: "the-stack", title: "The stack", children: []),
      ],
      tags: ["gleam", "lustre"],
      draft: False,
      tldr: Some(
        "arata rebuilds the apollo blog theme as a Gleam/Lustre single-page app with client-side routing and a hand-ported CSS design system.",
      ),
      word_count: 120,
      reading_time: 1,
    ),
    Post(
      slug: "the-elm-architecture",
      title: "The Elm Architecture in Lustre",
      date: "2025-01-20",
      updated: None,
      description: "How Model-View-Update with managed effects keeps arata's code predictable.",
      body: "
        <p>
          Lustre follows The Elm Architecture: a single <code>Model</code>, a
          pure <code>update</code> function that returns a new model and an
          <code>Effect</code>, and a pure <code>view</code> function that
          produces a virtual DOM.
        </p>
        <h2 id='init'>init</h2>
        <p>
          <code>init</code> builds the initial model from flags and returns any
          startup effects — for arata, that means reading the initial URL and
          initialising the router.
        </p>
        <h2 id='update'>update</h2>
        <pre><code>fn update(model, msg) {
  case msg {
    UserNavigatedTo(route) -&gt; #(Model(..model, route:), effect.none())
  }
}</code></pre>
        <h2 id='view'>view</h2>
        <p>
          The view pattern-matches on the current route and dispatches to a
          per-page view function. Side effects never live in the view — they are
          returned from <code>update</code> as data.
        </p>
      ",
      toc: [
        TocEntry(id: "init", title: "init", children: []),
        TocEntry(id: "update", title: "update", children: []),
        TocEntry(id: "view", title: "view", children: []),
      ],
      tags: ["lustre", "architecture"],
      draft: False,
      tldr: None,
      word_count: 110,
      reading_time: 1,
    ),
    Post(
      slug: "porting-scss-to-plain-css",
      title: "Porting apollo's SCSS to plain CSS",
      date: "2025-01-25",
      updated: Some("2025-02-03"),
      description: "Notes on hand-porting a SCSS design system to a single plain-CSS file — and why it's worth it.",
      body: "
        <p>
          apollo's styles are written in SCSS with variables, <code>@use</code>,
          and <code>darken()</code>/<code>lighten()</code> helpers. arata ports
          them by hand to a single plain-CSS file to avoid pulling a Sass
          toolchain into the build.
        </p>
        <h2 id='variables'>Variables</h2>
        <p>
          SCSS <code>$variables</code> become CSS custom properties on
          <code>:root</code> (light defaults) and <code>:root.dark</code> (dark
          overrides), so the theme toggle only has to flip one class.
        </p>
        <h2 id='breakpoints'>Breakpoints</h2>
        <p>
          apollo has seven breakpoints (1365, 1024, 992, 768, 720, 640, 600, 576).
          Each <code>@media</code> block is ported verbatim — the responsive
          behaviour must match exactly.
        </p>
        <blockquote>
          <p>
            The only <code>transition</code> in the whole stylesheet is on
            <code>.note-toggle</code>. No keyframes, no fade-ins — apollo's
            aesthetic is deliberately still.
          </p>
        </blockquote>
      ",
      toc: [
        TocEntry(id: "variables", title: "Variables", children: []),
        TocEntry(id: "breakpoints", title: "Breakpoints", children: []),
      ],
      tags: ["css", "design"],
      draft: False,
      tldr: None,
      word_count: 105,
      reading_time: 1,
    ),
    Post(
      slug: "draft-wip",
      title: "A work-in-progress draft",
      date: "2025-02-01",
      updated: None,
      description: "This post is marked as a draft to exercise the DRAFT label.",
      body: "
        <p>
          Drafts show a <code>DRAFT</code> badge in the post list and on the
          page itself. In a real build pipeline they would be excluded from
          production output unless built with a <code>--drafts</code> flag.
        </p>
      ",
      toc: [],
      tags: ["meta"],
      draft: True,
      tldr: None,
      word_count: 40,
      reading_time: 1,
    ),
  ]
}
