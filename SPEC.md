# flutter_scroll_kit Specification

One pub.dev package of four composable Flutter scroll primitives
extracted from [repentsinner/rove](https://github.com/repentsinner/rove)
for external use. This file owns packaging, library layout, and
publication. Each primitive's internal design, API, and algorithms are
governed by its own `SPEC.md` under `doc/<primitive>/`.

## Libraries §spec:libraries

*Status: complete*

Implements §req:problem-statement and §req:packaging. The package
`flutter_scroll_kit` ships one public library per primitive, plus a
library that exports all four:

| Library | Purpose | Imports |
|---------|---------|---------|
| `line_snap_scroll_physics.dart` | `ScrollController` and `ScrollPhysics` that quantize offsets to fixed line boundaries | — |
| `sticky_hierarchical_scroll.dart` | VS Code–style hierarchical sticky header overlay for flat lists | — |
| `fixed_line_view.dart` | Virtualized fixed-height line view with active-line tracking and auto-scroll | `line_snap_scroll_physics.dart` |
| `repl_view.dart` | Two-level REPL scrollback with sticky input headers, coalesced responses, and identity-anchored viewport | `sticky_hierarchical_scroll.dart` |
| `flutter_scroll_kit.dart` | Exports the four libraries above | all four |

Each primitive's sources live under `lib/src/<primitive>/`, its tests
under `test/<primitive>/`, and its `SPEC.md` and `REQUIREMENTS.md`
under `doc/<primitive>/`.

The package targets pure Flutter, with no third-party runtime
dependencies. Dev dependencies are limited to `flutter_lints` and
`flutter_test`.

## Dependency Graph §spec:dependency-graph

*Status: complete*

Implements §req:success-criteria. A consumer imports only the libraries
it uses, and tree-shaking keeps the rest out of the built app.

```text
line_snap_scroll_physics
└── fixed_line_view

sticky_hierarchical_scroll
└── repl_view
```

A library imports another primitive through that primitive's public
library, `package:flutter_scroll_kit/<primitive>.dart`.

## Framework Dependency §spec:framework-dependency

*Status: not started*

Implements §req:packaging. Every library imports Flutter through
`package:flutter/widgets.dart` and its lower layers. No library imports
`package:flutter/material.dart` or `package:flutter/cupertino.dart`, so
the primitives run under any app root: `MaterialApp`, `CupertinoApp`, a
plain `WidgetsApp`, or a design system that ships its own app widget,
such as `material_ui`.

- *Selection.* `FixedLineView(selectable: true)` builds selection from
  the widgets layer, so it needs no localizations from a design system.
  A consumer that wants its design system's handles and context menu
  leaves `selectable` off and wraps the view in that system's
  selection widget.
- *Scrollbar.* `StickyHierarchicalScrollView` asks the ambient
  `ScrollBehavior` to build its scrollbar, so the host app's design
  system draws it.
- *Gutter width.* With `scrollbarGutter` null, the gutter defaults to a
  documented constant equal to the Material scrollbar thickness.
  Consumers whose scrollbar is wider or narrower pass the width.

*Why*: each primitive sits under a host app's design system. Importing
one design system's library binds its lookups to that system's
`Localizations` and theme types, which apps on another root don't
provide. `SelectionArea` then throws, and theme lookups fall back to
defaults without warning. Reported in #67.

## Publication Model §spec:publication-model

*Status: complete*

Implements §req:packaging and §req:publication-integrity. The package
publishes to pub.dev under one SemVer track shared by all four
primitives, with one `CHANGELOG.md`.

Pre-1.0 versions (`0.x.y`) signal "API shapes are stable enough to
use, but expect breakage until validated by real consumers."
Version `1.0.0` signals API commitment once at least one external
consumer has validated the shape.

`dart pub publish --dry-run` is the gate before every publish.
`.pubignore` keeps build output, generated example platform folders,
and the Vale styles out of the archive.

## Example App §spec:example-app

*Status: complete*

Implements §req:success-criteria. `example/` is one Flutter app with a
tab per primitive. It depends on the package by path and keeps its own
`pubspec.lock`. A widget test in `example/test/` opens each tab and
finds that tab's primitive.

The example carries no platform folders. `flutter create .` in
`example/` generates them.

## Development Workflow §spec:development-workflow

*Status: complete*

Implements §req:problem-statement. The root is a single Flutter
package, and `example/` resolves separately because it depends on the
package by path.

```sh
dart pub get && (cd example && dart pub get)
dart format .
dart analyze
flutter test && (cd example && flutter test)
```

These are the commands CI runs. Analysis covers both trees, so both
need resolving first. CI runs every check against two SDKs: the
`.fvmrc` pin and the Flutter floor in `pubspec.yaml`.

## Origin and License §spec:origin-and-license

*Status: complete*

Implements §req:problem-statement. The extraction from rove is the
mechanism by which the primitives become consumable by projects
other than rove.

The primitives lived as in-tree modules inside
[repentsinner/rove](https://github.com/repentsinner/rove) from
PR #119 (scroll widget package extraction) until the initial import
to this repo. Pre-extraction history remains in rove; this repo
carries per-file history from the extraction onward.

Before `flutter_scroll_kit` 0.1.0, the four primitives published as
separate pub.dev packages under their own names. Those packages are
discontinued on pub.dev, with `flutter_scroll_kit` as the suggested
replacement.

BSD 3-Clause, matching upstream rove.

## Publication Automation §spec:publication-automation

*Status: complete*

Implements §req:publication-integrity. Flywheel cuts releases from
conventional commits and pushes a `v<version>` tag on the release
commit. A tag-triggered workflow publishes that tag to pub.dev, through
the `pub.dev` GitHub environment, which holds each publish for a
maintainer's approval.

Each GitHub release carries release builds of the example app for
Linux, macOS, and Windows, built on each platform's runner from the
release tag. The repository uses immutable releases, which freeze a
release's assets once it publishes, so Flywheel creates each release
as a draft. The build workflow attaches the builds to the draft and
publishes it once every platform has attached. The builds are unsigned.

Authentication uses OIDC against pub.dev's trusted publisher
mechanism: the workflow exchanges a GitHub-signed OIDC token for a
short-lived pub.dev credential, scoped to one publish. No long-lived
credentials live in the repo or GitHub secrets. Reference:
[dart.dev/tools/pub/automated-publishing](https://dart.dev/tools/pub/automated-publishing).

*Why*: pub.dev accepts automated publication only from tag-triggered
workflows, and only for a package that already exists. The first
version publishes by hand, and the package's pub.dev Admin page then
registers this repository as a trusted publisher for the tag pattern
`v{{version}}`. The pub.dev package owner grants this trust; a GitHub
App cannot.
