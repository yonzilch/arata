//// Sample blog content for arata.
////
//// Posts are authored directly as Gleam constants with pre-rendered HTML
//// bodies, following the pattern of the Lustre `01-routing` example. This
//// unblocks post-list and single-post rendering (ROADMAP Phase 5) before the
//// markdown build pipeline lands (ROADMAP Phase 17).
////
//// The HTML bodies use single-quoted attributes to keep the Gleam string
//// literals readable; the rendered output is identical. They deliberately
//// include headings, paragraphs, code blocks, blockquotes, and links so the
//// ported apollo CSS (headings with `# ` accents, `pre`/`code` styling,

///  blockquotes, link hovers) is exercised.
import data/post.{type Post, Post}

/// The full list of sample posts, newest first (the post list renders them in
/// this order; a later phase will sort by `date`).
pub fn posts() -> List(Post) {
  [
    Post(
      slug: "hello-arata",
      title: "Hello, arata",
      date: "2025-01-15",
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
        <h2>Why Gleam?</h2>
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
        <h2>The stack</h2>
        <pre><code>gleam add lustre
gleam add modem
gleam add --dev lustre_dev_tools</code></pre>
        <p>
          Routing is handled by <code>modem</code> over the History API, so
          internal links are just ordinary <code>&lt;a&gt;</code> elements whose
          clicks are intercepted and dispatched as messages.
        </p>
      ",
      tags: ["gleam", "lustre"],
      draft: False,
    ),
    Post(
      slug: "the-elm-architecture",
      title: "The Elm Architecture in Lustre",
      date: "2025-01-20",
      description: "How Model-View-Update with managed effects keeps arata's code predictable.",
      body: "
        <p>
          Lustre follows The Elm Architecture: a single <code>Model</code>, a
          pure <code>update</code> function that returns a new model and an
          <code>Effect</code>, and a pure <code>view</code> function that
          produces a virtual DOM.
        </p>
        <h2>init</h2>
        <p>
          <code>init</code> builds the initial model from flags and returns any
          startup effects — for arata, that means reading the initial URL and
          initialising the router.
        </p>
        <h2>update</h2>
        <pre><code>fn update(model, msg) {
  case msg {
    UserNavigatedTo(route) -&gt; #(Model(..model, route:), effect.none())
  }
}</code></pre>
        <h2>view</h2>
        <p>
          The view pattern-matches on the current route and dispatches to a
          per-page view function. Side effects never live in the view — they are
          returned from <code>update</code> as data.
        </p>
      ",
      tags: ["lustre", "architecture"],
      draft: False,
    ),
    Post(
      slug: "porting-scss-to-plain-css",
      title: "Porting apollo's SCSS to plain CSS",
      date: "2025-01-25",
      description: "Notes on hand-porting a SCSS design system to a single plain-CSS file — and why it's worth it.",
      body: "
        <p>
          apollo's styles are written in SCSS with variables, <code>@use</code>,
          and <code>darken()</code>/<code>lighten()</code> helpers. arata ports
          them by hand to a single plain-CSS file to avoid pulling a Sass
          toolchain into the build.
        </p>
        <h2>Variables</h2>
        <p>
          SCSS <code>$variables</code> become CSS custom properties on
          <code>:root</code> (light defaults) and <code>:root.dark</code> (dark
          overrides), so the theme toggle only has to flip one class.
        </p>
        <h2>Breakpoints</h2>
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
      tags: ["css", "design"],
      draft: False,
    ),
    Post(
      slug: "draft-wip",
      title: "A work-in-progress draft",
      date: "2025-02-01",
      description: "This post is marked as a draft to exercise the DRAFT label.",
      body: "
        <p>
          Drafts show a <code>DRAFT</code> badge in the post list and on the
          page itself. In a real build pipeline they would be excluded from
          production output unless built with a <code>--drafts</code> flag.
        </p>
      ",
      tags: ["meta"],
      draft: True,
    ),
  ]
}
