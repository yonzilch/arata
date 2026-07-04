+++
title = "Hello, Arata"
date = "2026-06-21"
updated = "2026-07-04"
description = "Introducing Arata — a faithful reimplementation of the apollo blog theme in Gleam and Lustre."
tags = ["gleam", "lustre"]
draft = false
tldr = "Arata rebuilds the apollo blog theme as a Gleam/Lustre single-page app with client-side routing and a hand-ported CSS design system."
+++

# Hello, Arata

**Arata** is a blog theme built with [Gleam](https://gleam.run) and [Lustre](https://hexdocs.pm/lustre). It grew out of [Apollo](https://github.com/not-matthias/apollo), a Zola theme known for its quiet, typography-first feel — only here, that whole presentation has been rebuilt as a client-side single-page app.

The point was never to just copy the look. What this project is really after is retelling a much-loved static theme in a typed, functional way — without losing what made the original work: its restraint, its clarity, the focus feeling you get reading it.

## Why Arata

Most blog themes, if you're honest about it, are templates, partials, and scattered bits of state stitched together. That's fine while the theme is small. But once it needs to keep growing over time, the cracks or issues start to show.

Arata takes a different path.

With Gleam and Lustre, the whole interface is written as a series of explicit state changes, rendered by pure functions. What the pages look like, how navigation works, how the UI responds — all of it grows out of one single model, instead of being scattered across templates and scripts that each do their own thing.

That matters, because Arata is meant to keep evolving through phase after phase — without getting weighed down by the kind of complexity that creeps in unnoticed, one "quick addition" at a time.

## Why Gleam

Gleam brings a strong type system, immutable data, and exhaustive pattern matching. Those constraints turn out to be genuinely useful here.

As the theme grows, view logic becomes easier to refactor, route handling becomes safer, and invalid states become harder to represent at all. Instead of layering behavior on top of markup, Arata models each interaction directly.

> The model is the source of truth.
> Events produce messages, messages update state, and the view is a pure function of that state.

That's what keeps the app feeling small in spirit, even as the codebase itself grows more capable. It also means the project stays easier to maintain — the type system carries the context that would otherwise live only in the author's head, and catches a whole class of bugs at compile time instead of letting them surface later at runtime.

## The tech stack

```shell
gleam add lustre
gleam add modem
```

Arata is built on a deliberately small stack.

* **Gleam** provides the typed, functional foundation for the application.
* **Lustre** provides the UI runtime and Elm-style architecture.
* **modem** handles client-side routing over the browser History API.

The goal was never to accumulate tooling. It was to keep the implementation clear, explicit, and easy to extend.

A small stack fits this project well: fewer moving parts, an architecture that's easier to read, and less distance between the theme's design and the code behind it.

Internal navigation uses ordinary `<a>` elements. Clicks are intercepted, translated into messages, and resolved through client-side routing — so standard link semantics are preserved, while page transitions still feel immediate.

## Design goals

Arata is built around a few simple goals:

* keep the interface visually quiet
* make state transitions explicit
* preserve semantic HTML where possible
* stay small, readable, and easy to extend
* port the original design language carefully, rather than loosely imitating it
* care about performance and feel — fast loads, smooth transitions, and an interface that never disrupts the users.

The CSS was hand-ported as a design system, not copied over mechanically. That makes the theme easier to maintain, and gives it room to keep growing on its own terms.

## What comes next

This first post is only an introduction. The real work is turning a minimal shell into a complete theme system: posts, tags, archives, navigation states, content rendering, and all the small details that make a blog feel finished.

Arata starts by honoring Apollo's aesthetic, but its long-term goal was never imitation. It's to become a clean, typed, extensible blogging foundation for Gleam.

If this post reads like a beginning, that's because it is — "**Hello, Arata**."
