+++
title = ""
subtitle = "Welcome to demo site of arata"
+++

> Arata is a modern and minimalistic blog theme powered by Gleam and Lustre.

## Features

- Light, dark, and auto themes
- [Projects page](/projects)
- [Links page](/links)
- MathJax rendering (configurable)
- [Taxonomies](/tags)
- Custom homepage
- Comments (Giscus/Utterances)
- Search functionality (searches title, description, tags, and body content)
- File-based content model (write `.md` files, not code)
- CSS modular loading (10 separate stylesheets)
- Mobile-responsive with hamburger menu

## Quick Start

1. **Scaffold the project:**

```shell
gleam new my-blog --template javascript
cd my-blog
gleam add lustre modem mork
```

2. **Build the site:**

```shell
gleam run -m build/pipeline
```

3. **Write content** as markdown files in `content/posts/`, `content/pages/`, `content/links/`, and `content/projects/`.

Checkout the [configuration guide](/posts/configuration) and the [example posts](/posts).
