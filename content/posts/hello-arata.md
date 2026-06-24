+++
title = "Hello, arata"
date = "2026-06-21"
updated = "2026-06-22"
description = "Introducing arata — a faithful reimplementation of the apollo blog theme in Gleam and Lustre."
tags = ["gleam", "lustre"]
draft = false
tldr = "arata rebuilds the apollo blog theme as a Gleam/Lustre single-page app with client-side routing and a hand-ported CSS design system."
+++

**Arata** is a blog theme built with [Gleam](https://gleam.run) and [Lustre](https://hexdocs.pm/lustre). It reproduces the minimal, typography-driven aesthetic of the [apollo](https://github.com/not-matthias/apollo) Zola theme as a client-side single-page application.

## Why Gleam?

Gleam is a typed, functional language that compiles to JavaScript and Erlang. Its exhaustiveness checking and immutable data make large view functions easy to refactor, which matters for a theme that will grow across nineteen roadmap phases.

> The Elm Architecture gives us a single source of truth: the Model. Every interaction flows through `update`, and the `view` is a pure function of state.

## The stack

```shell
gleam add lustre
gleam add modem
gleam add --dev lustre_dev_tools
```

Routing is handled by `modem` over the History API, so internal links are just ordinary `<a>` elements whose clicks are intercepted and dispatched as messages.
