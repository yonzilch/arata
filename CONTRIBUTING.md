# Contributing to Arata

Thank you for contributing to Arata.

This document defines the expected development workflow, coding standards, issue conventions, pull request requirements, and commit message format for this repository. The goal is to keep changes easy to review, easy to trace, and safe to release.

## Table of Contents

- [Motivation](#motivation)
- [Development Environment](#development-environment)
- [Project Layout](#project-layout)
- [Local Workflow](#local-workflow)
- [Code Style](#code-style)
- [Testing](#testing)
- [Issue Guidelines](#issue-guidelines)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Commit Message Convention](#commit-message-convention)
- [Review Expectations](#review-expectations)
- [Scope Control](#scope-control)
- [Definition of Done](#definition-of-done)

## Motivation

Arata should remain easy to understand, maintain, and evolve.

Contributors are expected to:
- keep changes small and focused
- preserve clear public API boundaries
- prefer explicit types and exhaustive matching
- avoid unrelated refactors
- include tests for behavior changes
- use consistent issue, pull request, and commit naming

The repository follows a lightweight engineering discipline:
- issues describe work clearly
- pull requests describe the implementation clearly
- commits remain traceable through Conventional Commits

## Development Environment

Before contributing, make sure your local environment can run the project commands successfully.

Typical commands:

```sh
gleam build
gleam check
gleam test
gleam format
gleam format --check
gleam run
```

A contribution is expected to pass at least:

```sh
gleam format --check
gleam check
gleam test
```

If your change affects runtime behavior, also verify it with an appropriate `gleam run` path or a focused manual test.

## Project Layout

Typical repository layout:

```text
src/arata/...
test/...
gleam.toml
manifest.toml
```

General expectations:

* production code lives under `src/arata/...`
* tests live under `test/...`
* test functions end with `_test`
* avoid placing unrelated experiments or scratch files in the repository

If a module becomes too broad, split it by responsibility rather than growing a single file indefinitely.

## Local Workflow

Recommended local workflow:

1. Create or pick an issue
2. Use a focused branch
3. Make the smallest effective change
4. Add or update tests
5. Run formatting, type checking, and tests
6. Open a pull request with a clear description

A good contribution should be:

* easy to review in one sitting
* limited to one clear goal
* supported by tests where behavior changes
* free of unrelated cleanup

## Code Style

### General

Follow these principles:

* prefer small, composable functions
* keep module boundaries explicit
* model domain states with meaningful types
* prefer sum types over boolean flags when state has multiple valid variants
* keep public APIs minimal
* avoid unnecessary indirection

### Gleam-specific expectations

Contributors should pay particular attention to:

* correct propagation of `Result` and `Option`
* exhaustive `case` handling
* avoiding misuse of `let assert`
* preserving type clarity at module boundaries
* avoiding dynamic escape when a stronger type is available

### Naming

* use clear and stable names
* keep module names aligned with responsibility
* use English for code, documentation, and comments
* avoid abbreviations unless they are widely understood

## Testing

Tests are required for:

* new user-visible behavior
* bug fixes
* boundary conditions
* regressions that could reappear

Testing expectations:

* place tests under `test/...`
* use names ending in `_test`
* cover both success and failure paths where relevant
* verify boundary conditions, not only happy paths

Examples of cases that should be verified:

* empty input
* invalid input
* multiple variants of a union type
* interaction between state transitions
* previously broken regressions

At minimum, run:

```sh
gleam test
```

Before opening a pull request, also run:

```sh
gleam format --check
gleam check
gleam test
```

## Issue Guidelines

Issues should describe one clear unit of work.

### Issue title format

Use the following format:

```text
<type>(<scope>): <summary>
```

Examples:

```text
feat(lightbox): support zoom and refine close button layout
fix(lightbox): prevent close button from overlapping image content
refactor(viewer): separate overlay controls from content container
docs(contributing): define issue and PR conventions
```

### Allowed issue types

Use one of the following types:

* `build`
* `chore`
* `ci`
* `feat`
* `fix`
* `docs`
* `perf`
* `test`
* `refactor`

### Scope rules

The `scope` should refer to a stable functional area, such as:

* `analyzer`
* `config`
* `deps`
* `devshell`
* `css`
* `lightbox`
* `viewer`
* `router`
* `parser`
* `shortcodes`
* `script`

Do not use unstable or overly specific scope values such as temporary implementation details, ticket IDs, or pixel-level descriptions.

### Summary rules

The `summary` should:

* use imperative mood
* express one core intent
* stay concise
* avoid implementation detail

Good:

* `feat(lightbox): support zoom and refine close button layout`

Bad:

* `lightbox changes`
* `feat: add something`
* `fix(lightbox): move close button to top-right and make it 32px and update CSS and cleanup state logic`

### Issue content expectations

A good issue should include:

* motivation or problem statement
* current behavior or limitation
* expected behavior
* scope
* acceptance criteria
* constraints or risks, if relevant

For bugs, include:

* steps to reproduce
* actual behavior
* expected behavior
* impact

For features, include:

* why the feature is needed
* what should change
* what is explicitly out of scope
* how completion will be verified

## Pull Request Guidelines

Pull requests should remain tightly scoped and easy to review.

### PR title format

Pull request titles should generally follow the same format as issue titles:

```text
<type>(<scope>): <summary>
```

If the pull request resolves a single issue, prefer using the same title for traceability.

### PR description should include

* motivation
* implementation summary
* key invariants
* edge cases
* verification steps
* linked issue(s)

Suggested PR checklist:

```md
- [ ] The change is scoped to one clear objective
- [ ] Code is formatted
- [ ] `gleam check` passes
- [ ] `gleam test` passes
- [ ] Tests were added or updated where needed
- [ ] No unrelated refactor is included
- [ ] Public API changes are explicitly called out
```

### PR size guidance

Prefer small to medium pull requests.

A pull request should not combine:

* feature work and refactor work
* bug fixes and broad cleanup
* behavioral change and unrelated renaming

If cleanup is necessary to enable the main change, keep it minimal and explain it clearly.

## Commit Message Convention

This repository uses Conventional Commits.

Format:

```text
<type>(<scope>): <summary>
```

Examples:

```text
feat(lightbox): support zoom and refine close button layout
fix(viewer): prevent overlay flicker during image transition
refactor(parser): simplify token normalization flow
docs(contributing): define issue and PR conventions
```

### Allowed commit types

* `build`
* `chore`
* `ci`
* `docs`
* `feat`
* `fix`
* `perf`
* `refactor`
* `test`


### Commit rules

* use English only
* keep the first line concise
* use imperative mood
* make each commit represent one meaningful change
* avoid mixed-purpose commits
* do not hide behavior changes inside formatting-only or refactor-only commits

If a change is breaking, explicitly describe it in the commit body using a `BREAKING CHANGE:` footer.

Example:

```text
feat(api): replace legacy viewer config shape

BREAKING CHANGE: viewer config now requires an explicit mode field.
```

## Review Expectations

Reviewers will primarily look for:

* correctness
* API clarity
* maintainability
* test coverage
* boundary handling
* unnecessary coupling
* scope discipline

Common review concerns include:

* incomplete `Result` or `Option` handling
* non-exhaustive branches
* weak type modeling
* hidden breaking changes
* missing regression tests
* unrelated edits in the same change

## Scope Control

Do not include unrelated changes in a contribution.

Avoid:

* repository-wide formatting sweeps unrelated to the task
* renaming modules without a clear reason
* speculative abstractions
* dependency additions without explicit justification
* broad refactors hidden inside a feature or fix

If a larger redesign is truly necessary, open a dedicated issue first.

## Definition of Done

A contribution is considered ready when:

* the issue is clearly defined
* the implementation is scoped correctly
* formatting, checks, and tests pass
* behavior changes are verified
* the pull request description is complete
* the title follows the required convention
* no unrelated changes are included

Thank you for helping keep Arata maintainable and consistent.
