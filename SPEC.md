# flutter_scroll_kit Specification

A publication-focused monorepo of four composable Flutter scroll
primitives extracted from
[repentsinner/rove](https://github.com/repentsinner/rove) for external
use. The repo owns packaging, dependency graph, and publication
concerns; per-package internal design, API, and algorithms are
governed by each package's own `SPEC.md` under `packages/<name>/`.

## 1. Packages

*Status: complete*

The repo publishes four packages, each with its own `SPEC.md` that
governs its internal design:

| Package | Purpose | Depends on |
|---------|---------|------------|
| `line_snap_scroll_physics` | `ScrollController` and `ScrollPhysics` that quantize offsets to fixed line boundaries | — |
| `sticky_hierarchical_scroll` | VS Code–style hierarchical sticky header overlay for flat lists | `line_snap_scroll_physics` |
| `fixed_line_view` | Virtualized fixed-height line view with active-line tracking and auto-scroll | `line_snap_scroll_physics` |
| `repl_view` | Two-level REPL scrollback with sticky input headers, coalesced responses, and identity-anchored viewport | `sticky_hierarchical_scroll` |

All four target pure Flutter — no third-party runtime dependencies.
Dev dependencies are limited to `flutter_lints` and `flutter_test`.

## 2. Dependency Graph

*Status: complete*

```text
line_snap_scroll_physics
├── sticky_hierarchical_scroll
│   └── repl_view
└── fixed_line_view
```

Publication order must match topological order: the base physics
package publishes first, the two direct consumers next (parallelizable),
the transitive consumer last. During development, inter-package
dependencies resolve through the root Dart workspace via `path:`
declarations; at publication time those swap to pub.dev version
constraints.

## 3. Publication Model

*Status: in progress*

Each package publishes to pub.dev under an independent SemVer track.
Initial release is `0.1.0` across all four, reflecting "API shapes
are stable enough to use, but expect breakage until validated by
real consumers." Version `1.0.0` signals API commitment once at
least one external consumer has validated the shape.

Packages are versioned independently: a bug fix in `repl_view` does
not bump `line_snap_scroll_physics`. Release tooling (release-please
or Melos publish) produces per-package `CHANGELOG.md` files.

`dart pub publish --dry-run` is the gate — each package must be
independently publishable before any is published. Rationale: a
partially-published dependency graph is harder to recover from than
a failed dry-run on the first package.

## 4. Development Workflow

*Status: complete*

The repository is a Dart 3.6+ workspace. The root `pubspec.yaml`
declares `packages/*` under `workspace:`, and each package declares
`resolution: workspace` to participate in shared resolution. A
single `dart pub get` at the root bootstraps all four packages.

Melos scripts (`melos.yaml`) run analyze, test, and format-check
across all packages in one command. Melos is a convenience layer —
every script has a direct `dart` equivalent that works from any
package directory. Contributors without Melos installed can still
develop and test.

## 5. Origin and License

*Status: complete*

The packages lived as in-tree modules inside
[repentsinner/rove](https://github.com/repentsinner/rove) from
PR #119 (scroll widget package extraction) until the initial import
to this repo. Pre-extraction history remains in rove; this repo
carries per-file history from the extraction onward.

BSD 3-Clause, matching upstream rove.
