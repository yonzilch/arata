+++
title = "Syntax Highlight Test"
date = "2026-08-10"
description = "Minimal syntax highlighting verification for Arata."
tags = ["docs", "syntax"]
+++

# Syntax Highlight Test

This page verifies language alias resolution, skipped languages, and a few directly supported languages.

## Skipped Language

Should render as plain text without syntax highlighting.

```text
Hello, World!
```

```
Hello, World!
```

## Bash (`bash`)

```bash
echo "Hello, World!"
```

## Bash Alias (`sh`)

Should be resolved to `bash`.

```sh
printf "Hello, World!\n"
```

## JavaScript (`javascript`)

```javascript
console.log("Hello, World!");
```

## JavaScript Alias (`js`)

Should be resolved to `javascript`.

```js
console.log("Hello from js!");
```

## TypeScript (`typescript`)

```typescript
console.log("Hello, World!");
```

## TypeScript Alias (`ts`)

Should be resolved to `typescript`.

```ts
console.log("Hello from ts!");
```

## Python (`python`)

```python
print("Hello, World!")
```

## Python Alias (`py`)

Should be resolved to `python`.

```py
print("Hello from py!")
```

## Rust (`rust`)

```rust
fn main() {
    println!("Hello, World!");
}
```

## Rust Alias (`rs`)

Should be resolved to `rust`.

```rs
fn main() {
    println!("Hello from rs!");
}
```

## C++ (`cpp`)

```cpp
#include <iostream>

int main() {
    std::cout << "Hello, World!\n";
}
```

## C++ Alias (`c++`)

Should be resolved to `cpp`.

```c++
#include <iostream>

int main() {
    std::cout << "Hello from c++!\n";
}
```

## C# Alias (`cs`)

Should be resolved to `csharp`.

```cs
Console.WriteLine("Hello, World!");
```

## HTML Alias (`html`)

Should be resolved to `xml`.

```html
<h1>Hello, World!</h1>
```

## YAML Alias (`yml`)

Should be resolved to `yaml`.

```yml
message: Hello, World!
```

## Docker Alias (`docker`)

Should be resolved to `dockerfile`.

```docker
FROM alpine
CMD echo "Hello, World!"
```

## Markdown Alias (`md`)

Should be resolved to `markdown`.

```md
# Hello, World!
```

## Third-party (`gleam`)

Use [gleam highlight cdn](https://cdn.jsdelivr.net/gh/gleam-lang/gleam-highlight.js@main/dist/gleam.min.js) to render.

```gleam
import gleam/io

pub fn main() {
  io.println("Hello, World!")
}
```
