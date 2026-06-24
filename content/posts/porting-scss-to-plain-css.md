+++
title = "Porting apollo's SCSS to plain CSS"
date = "2026-06-22"
updated = "2026-06-23"
description = "Notes on hand-porting a SCSS design system to a single plain-CSS file — and why it's worth it."
tags = ["css", "design"]
draft = false
+++

Apollo's styles are written in SCSS with variables, `@use`, and `darken()`/`lighten()` helpers. arata ports them by hand to a single plain-CSS file to avoid pulling a Sass toolchain into the build.

## Variables

SCSS `$variables` become CSS custom properties on `:root` (light defaults) and `:root.dark` (dark overrides), so the theme toggle only has to flip one class.

## Breakpoints

Apollo has seven breakpoints (1365, 1024, 992, 768, 720, 640, 600, 576). Each `@media` block is ported verbatim — the responsive behaviour must match exactly.

> The only `transition` in the whole stylesheet is on `.note-toggle`. No keyframes, no fade-ins — apollo's aesthetic is deliberately still.
