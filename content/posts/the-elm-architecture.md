+++
title = "The Elm Architecture in Lustre"
date = "2026-01-20"
description = "How Model-View-Update with managed effects keeps arata's code predictable."
tags = ["lustre", "architecture"]
draft = false
+++

Lustre follows The Elm Architecture: a single `Model`, a pure `update` function that returns a new model and an `Effect`, and a pure `view` function that produces a virtual DOM.

## init

`init` builds the initial model from flags and returns any startup effects — for arata, that means reading the initial URL and initialising the router.

## update

```gleam
fn update(model, msg) {
  case msg {
    UserNavigatedTo(route) -> #(Model(..model, route:), effect.none())
  }
}
```

## view

The view pattern-matches on the current route and dispatches to a per-page view function. Side effects never live in the view — they are returned from `update` as data.
