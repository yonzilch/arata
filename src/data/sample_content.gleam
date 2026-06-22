import data/page.{type Page, Page}
import data/post.{type Post, Post, TocEntry}
import data/project.{type Project, Project}
import data/talk.{type Talk, Talk}
import gleam/option.{None, Some}

pub fn posts() -> List(Post) {
  [
    Post(
      slug: "hello-arata",
      title: "Hello, arata",
      date: "2025-01-15",
      updated: Some("2025-01-18"),
      description: "Introducing arata — a faithful reimplementation of the apollo blog theme in Gleam and Lustre.",
      body: "**arata** is a blog theme built with [Gleam](https://gleam.run) and [Lustre](https://hexdocs.pm/lustre). It reproduces the minimal, typography-driven aesthetic of the [apollo](https://github.com/not-matthias/apollo) Zola theme as a client-side single-page application.\n\n## Why Gleam?\n\nGleam is a typed, functional language that compiles to JavaScript and Erlang. Its exhaustiveness checking and immutable data make large view functions easy to refactor, which matters for a theme that will grow across nineteen roadmap phases.\n\n> The Elm Architecture gives us a single source of truth: the Model. Every interaction flows through `update`, and the `view` is a pure function of state.\n\n## The stack\n\n```shell\ngleam add lustre\ngleam add modem\ngleam add --dev lustre_dev_tools\n```\n\nRouting is handled by `modem` over the History API, so internal links are just ordinary `<a>` elements whose clicks are intercepted and dispatched as messages.",
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
      body: "Lustre follows The Elm Architecture: a single `Model`, a pure `update` function that returns a new model and an `Effect`, and a pure `view` function that produces a virtual DOM.\n\n## init\n\n`init` builds the initial model from flags and returns any startup effects — for arata, that means reading the initial URL and initialising the router.\n\n## update\n\n```gleam\nfn update(model, msg) {\n  case msg {\n    UserNavigatedTo(route) -> #(Model(..model, route:), effect.none())\n  }\n}\n```\n\n## view\n\nThe view pattern-matches on the current route and dispatches to a per-page view function. Side effects never live in the view — they are returned from `update` as data.",
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
      body: "apollo's styles are written in SCSS with variables, `@use`, and `darken()`/`lighten()` helpers. arata ports them by hand to a single plain-CSS file to avoid pulling a Sass toolchain into the build.\n\n## Variables\n\nSCSS `$variables` become CSS custom properties on `:root` (light defaults) and `:root.dark` (dark overrides), so the theme toggle only has to flip one class.\n\n## Breakpoints\n\napollo has seven breakpoints (1365, 1024, 992, 768, 720, 640, 600, 576). Each `@media` block is ported verbatim — the responsive behaviour must match exactly.\n\n> The only `transition` in the whole stylesheet is on `.note-toggle`. No keyframes, no fade-ins — apollo's aesthetic is deliberately still.",
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
      body: "Drafts show a `DRAFT` badge in the post list and on the page itself. In a real build pipeline they would be excluded from production output unless built with a `--drafts` flag.",
      toc: [],
      tags: ["meta"],
      draft: True,
      tldr: None,
      word_count: 40,
      reading_time: 1,
    ),
    Post(
      slug: "markdown",
      title: "Markdown Test",
      date: "2022-01-01",
      updated: Some("2022-05-01"),
      description: "A comprehensive test of markdown rendering: headings, code blocks, lists, quotes, tables, and inline code.",
      body: "# H1\n\n## H2\n\n### H3\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Aliquet sagittis id consectetur purus ut. In pellentesque massa placerat duis ultricies. Neque laoreet suspendisse interdum consectetur libero id. Justo nec ultrices dui sapien eget mi proin. Nunc consequat interdum varius sit amet mattis vulputate. Sollicitudin tempor id eu nisl nunc mi ipsum. Non odio euismod lacinia at quis. Sit amet nisl suscipit adipiscing. Amet mattis vulputate enim nulla aliquet porttitor lacus luctus accumsan. Sit amet consectetur adipiscing elit pellentesque habitant. Ac placerat vestibulum lectus mauris. Molestie ac feugiat sed lectus vestibulum mattis ullamcorper velit sed. [Google](https://www.google.com)\n\n![Markdown Logo](https://markdown-here.com/img/icon256.png)\n\n## Code Block\n\n```rust\nfn main() {\n    println!(\"Hello World\");\n}\n```\n\n## Ordered List\n\n1. First item\n2. Second item\n3. Third item\n\n## Unordered List\n\n- List item\n- Another item\n- And another item\n\n## Nested list\n\n- Fruit\n  - Apple\n  - Orange\n  - Banana\n- Dairy\n  - Milk\n  - Cheese\n\n## Quote\n\n> Two things are infinite: the universe and human stupidity; and I'm not sure about the\n> universe.\n> — Albert Einstein\n\n## Table Inline Markdown\n\n| Italics   | Bold     | Code   | StrikeThrough     |\n| --------- | -------- | ------ | ----------------- |\n| _italics_ | **bold** | `code` | ~~strikethrough~~ |\n\n## Foldable Text\n\n<details>\n    <summary>Title 1</summary>\n    <p>IT'S A SECRET TO EVERYBODY.</p>\n</details>\n\n<details>\n    <summary>Title 2</summary>\n    <p>Stay awhile, and listen!</p>\n</details>\n\n## Code tags\n\nLorem ipsum `dolor` sit amet, `consectetur adipiscing` elit.\n`Lorem ipsum dolor sit amet, consectetur adipiscing elit.`",
      toc: [
        TocEntry(id: "h2", title: "H2", children: []),
        TocEntry(id: "h3", title: "H3", children: []),
        TocEntry(id: "code-block", title: "Code Block", children: []),
        TocEntry(id: "ordered-list", title: "Ordered List", children: []),
        TocEntry(id: "unordered-list", title: "Unordered List", children: []),
        TocEntry(id: "nested-list", title: "Nested list", children: []),
        TocEntry(id: "quote", title: "Quote", children: []),
        TocEntry(
          id: "table-inline-markdown",
          title: "Table Inline Markdown",
          children: [],
        ),
        TocEntry(id: "foldable-text", title: "Foldable Text", children: []),
        TocEntry(id: "code-tags", title: "Code tags", children: []),
      ],
      tags: ["example"],
      draft: False,
      tldr: None,
      word_count: 200,
      reading_time: 2,
    ),
  ]
}

pub fn projects() -> List(Project) {
  [
    Project(
      slug: "arata",
      title: "arata",
      description: "A faithful reimplementation of the apollo blog theme in Gleam and Lustre.",
      link_to: Some("https://github.com/yonzilch/arata"),
      image: None,
      github: Some("https://github.com/yonzilch/arata"),
      demo: None,
      tags: ["gleam", "lustre", "blog"],
    ),
    Project(
      slug: "apollo",
      title: "apollo (upstream)",
      description: "The original Zola blog theme arata is based on — minimal and typography-driven.",
      link_to: Some("https://github.com/not-matthias/apollo"),
      image: None,
      github: Some("https://github.com/not-matthias/apollo"),
      demo: Some("https://not-matthias.github.io/apollo/"),
      tags: ["zola", "rust", "blog"],
    ),
    Project(
      slug: "lustre",
      title: "Lustre",
      description: "An opinionated Gleam frontend framework following The Elm Architecture.",
      link_to: Some("https://hexdocs.pm/lustre"),
      image: None,
      github: Some("https://github.com/lustre-labs/lustre"),
      demo: None,
      tags: ["gleam", "frontend", "mvu"],
    ),
    Project(
      slug: "gleam",
      title: "Gleam",
      description: "A typed, functional language that compiles to JavaScript and Erlang.",
      link_to: Some("https://gleam.run"),
      image: None,
      github: Some("https://github.com/gleam-lang/gleam"),
      demo: None,
      tags: ["language", "functional", "erlang", "javascript"],
    ),
  ]
}

pub fn talks() -> List(Talk) {
  [
    Talk(
      slug: "introducing-arata",
      title: "Introducing arata: apollo in Gleam",
      description: "A walk through porting a Zola theme to a Lustre single-page app — the design-system port, the routing shell, and the Elm-architecture patterns that keep it maintainable.",
      date: "2025-02-10",
      thumbnail: None,
      video_link: Some("https://www.youtube.com/watch?v=example"),
      organizer: Some(#("Gleam Conf", "https://gleam.run")),
      slides: Some("https://example.com/slides"),
      code: Some("https://github.com/yonzilch/arata"),
    ),
    Talk(
      slug: "the-elm-architecture",
      title: "The Elm Architecture in practice",
      description: "How Model-View-Update with managed effects scales from a counter to a full blog theme — and why keeping side effects as data makes refactoring safe.",
      date: "2025-03-05",
      thumbnail: None,
      video_link: Some("https://www.youtube.com/watch?v=example2"),
      organizer: Some(#("Functional Conf", "https://example.com")),
      slides: None,
      code: None,
    ),
  ]
}

pub fn homepage() -> Page {
  Page(
    slug: "home",
    title: "arata",
    subtitle: Some(
      "A modern and minimalistic blog theme powered by Gleam and Lustre.",
    ),
    body: "## Features\n\n- Light, dark, and auto themes\n- [Projects page](/projects)\n- [Talks page](/talks)\n- MathJax rendering\n- [Taxonomies](/tags)\n- Custom homepage\n- Comments\n- Search functionality\n\n## Quick Start\n\n1. **Scaffold the project:**\n   ```shell\ngleam new my-blog --template javascript\ncd my-blog\ngleam add lustre modem\n   ```\n2. **Start the dev server:**\n   ```shell\ngleam run -m lustre/dev start\n   ```\n3. **Write content** as markdown (parsed by mork).\n\nCheckout all the [options you can configure](/posts/configuration) and the [example posts](/posts).",
  )
}

pub fn pages() -> List(Page) {
  [
    Page(
      slug: "about",
      title: "About",
      subtitle: None,
      body: "**arata** is a faithful reimplementation of the [apollo](https://github.com/not-matthias/apollo) blog theme, built with [Gleam](https://gleam.run) and [Lustre](https://hexdocs.pm/lustre).\n\n## Why arata?\n\napollo is a beautiful, minimalistic theme for the Zola static site generator. arata reproduces its design and feature set as a client-side single-page application, leveraging Gleam's type safety and Lustre's Elm Architecture for a maintainable codebase.\n\n## The stack\n\n- **Gleam** — a typed, functional language compiling to JavaScript.\n- **Lustre** — a frontend framework following The Elm Architecture.\n- **modem** — client-side routing over the History API.\n- **mork** — a pure-Gleam CommonMark + GFM markdown parser.\n\nSee the [posts](/posts) for deep dives into the implementation, or the [projects page](/projects) for related work.",
    ),
  ]
}
