# flutter_scroll_kit Requirements

## Problem statement §req:problem-statement

Flutter application projects — starting with
[repentsinner/rove](https://github.com/repentsinner/rove) — reuse
scroll primitives that accumulated inside rove's in-tree modules:
line-snapping scroll physics, sticky hierarchical headers, fixed-
height line virtualization, and REPL-style scrollback with sticky
input headers. A consumer that wants any one of these primitives
without the rest can only fork rove or depend on it as a git
source, which pulls in unrelated application code and resists
independent versioning.

Community packages in this space are either heavier than needed
(full rich-text editors, terminal emulators) or don't compose —
mixing a third-party sticky-header implementation with a third-
party line-snap physics rarely works because each assumes its own
scroll infrastructure.

## Success criteria §req:success-criteria

- Each primitive is installable on its own via
  `dart pub add <package>` with no git reference.
- A consumer can adopt any single primitive without pulling the
  others they don't use.
- A fix or breaking change in one primitive does not force
  consumers of the other three to upgrade or re-pin.
- Rove's `swap-to-pub-dev-deps` workstream — migrating from git
  source deps to pub.dev version deps — unblocks and closes.
