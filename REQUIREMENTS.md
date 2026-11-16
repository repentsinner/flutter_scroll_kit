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

- All four primitives are installable via
  `dart pub add flutter_scroll_kit` with no git reference.
- A consumer can import any single primitive through its own
  library, and primitives it doesn't import stay out of the built
  app.
- A fix in one primitive does not force consumers of the other
  three to upgrade or re-pin.
- Rove's `swap-to-pub-dev-deps` workstream — migrating from git
  source deps to pub.dev version deps — unblocks and closes.

## Packaging §req:packaging

- The four primitives shall publish as one pub.dev package,
  `flutter_scroll_kit`, on one SemVer track.
- Each primitive shall have its own public library,
  `package:flutter_scroll_kit/<primitive>.dart`, that exports that
  primitive's public API.
- The package should also provide
  `package:flutter_scroll_kit/flutter_scroll_kit.dart`, which exports
  all four.

*Why*: the primitives share one version, so a breaking change in one
primitive moves the version for all four. Below 1.0, a caret
constraint such as `^0.1.0` excludes the next minor, so a consumer of
an unchanged primitive has to re-pin to keep receiving its fixes. A
raised Flutter SDK floor reaches all four primitives the same way.
This cost is accepted because the primitives are close to their
stated goals, change rarely, and depend on nothing beyond Flutter, so
no third-party bump drives a release. Per-primitive libraries keep
adoption selective at the import level, and tree-shaking keeps unused
primitives out of the build.

*Rejected*: four independently versioned packages. Each needed its
own release automation and publish workflow, consumers had to
publish in dependency order, and pub.dev usage was split across four
listings.

## Publication integrity §req:publication-integrity

Publication of the package (§req:packaging) shall preserve two
guarantees:

- **Dry-run gate.** The package shall pass
  `dart pub publish --dry-run` before it publishes.
- **No ambient credentials.** Publication shall authenticate with
  short-lived, per-publish credentials; the pipeline shall hold no
  long-lived pub.dev tokens in repository secrets.
