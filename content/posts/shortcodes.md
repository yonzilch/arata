+++
title = "Shortcode Reference"
date = "2026-06-22"
description = "Reference for the note, character, image, and mermaid shortcodes available in arata posts."
tags = ["docs", "shortcodes"]
+++

# Shortcode Reference

Arata supports four shortcodes, mirroring apollo's `templates/shortcodes/`. In the current implementation, shortcodes are Gleam functions in `src/shortcodes/` that return HTML strings for embedding in post bodies. The markdown pipeline expands `{{ note(...) }}`-style syntax by calling these functions.

## note

A note box with a header and content. Can be static (always visible) or dynamic (toggle button).

```gleam
import shortcodes/note

// Static note
note.view("Tip", "<p>This is always visible.</p>", False, False, False)

// Dynamic note (clickable, hidden by default, centered)
note.view("Click to expand", "<p>Hidden content.</p>", True, True, True)
```

**Parameters:**
| Param | Type | Description |
|---|---|---|
| `header` | String | The header text. |
| `body` | String | The body HTML. |
| `clickable` | Bool | When `True`, the header becomes a toggle button. |
| `hidden` | Bool | When `True` (and clickable), the body starts hidden. |
| `center` | Bool | When `True`, the header is centered instead of using an icon. |

## character

An avatar with a speech bubble.

```gleam
import shortcodes/character

character.view("hooded", "<p>The hooded figure speaks.</p>", "right", "")
```

**Parameters:**
| Param | Type | Description |
|---|---|---|
| `name` | String | Character name (used for CSS classes and default image). |
| `body` | String | The speech text HTML. |
| `position` | String | `"left"` or `"right"` (flips the row direction). |
| `image` | String | Optional image filename (defaults to `hooded.png` when name is "hooded"). |

## image

An image with lazy loading and an aspect-ratio attribute.

```gleam
import shortcodes/image

image.view("/images/photo.png", "Alt text", 800, 600, "lazy", "async")
```

**Parameters:**
| Param | Type | Description |
|---|---|---|
| `path` | String | The image src URL. |
| `alt` | String | The alt text. |
| `width` | Int | Used for the `aspect-ratio` attribute. |
| `height` | Int | Used for the `aspect-ratio` attribute. |
| `loading` | String | `"lazy"` (default) or `"eager"`. |
| `decoding` | String | `"async"` (default) or `"sync"`. |

Image resizing (avif/webp derivatives) is deferred to the build pipeline.

## mermaid

A mermaid diagram container.

```gleam
import shortcodes/mermaid

mermaid.view("graph LR\n  A --> B")
```

Renders `<pre class="mermaid">` for client-side rendering by the mermaid library. The actual diagram rendering is handled by `effect/script.gleam`, which loads mermaid v11 from CDN and calls `mermaid.run()` after each post view. The mermaid theme switches between `"dark"` and `"neutral"` based on the effective theme.
