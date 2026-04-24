# flutter_scroll_kit Specification

A publication-focused monorepo of four composable Flutter scroll
primitives extracted from
[repentsinner/rove](https://github.com/repentsinner/rove) for external
use. The repo owns packaging, dependency graph, and publication
concerns; per-package internal design, API, and algorithms are
governed by each package's own `SPEC.md` under `packages/<name>/`.

## 1. Packages §spec:packages

*Status: complete*

Implements §req:problem-statement. The repo publishes four packages,
each with its own `SPEC.md` that governs its internal design:

| Package | Purpose | Depends on |
|---------|---------|------------|
| `line_snap_scroll_physics` | `ScrollController` and `ScrollPhysics` that quantize offsets to fixed line boundaries | — |
| `sticky_hierarchical_scroll` | VS Code–style hierarchical sticky header overlay for flat lists | `line_snap_scroll_physics` |
| `fixed_line_view` | Virtualized fixed-height line view with active-line tracking and auto-scroll | `line_snap_scroll_physics` |
| `repl_view` | Two-level REPL scrollback with sticky input headers, coalesced responses, and identity-anchored viewport | `sticky_hierarchical_scroll` |

All four target pure Flutter — no third-party runtime dependencies.
Dev dependencies are limited to `flutter_lints` and `flutter_test`.

## 2. Dependency Graph §spec:dependency-graph

*Status: complete*

Implements §req:problem-statement. The graph is shaped by the
composability requirement: a consumer of one primitive does not pay
for primitives they do not use.

```text
line_snap_scroll_physics
├── sticky_hierarchical_scroll
│   └── repl_view
└── fixed_line_view
```

Publication order shall match topological order: the base physics
package first, the two direct consumers next (parallelizable), the
transitive consumer last. Publishing an upstream package with a
dependency on an unpublished package fails the pub.dev resolver, so
order is load-bearing, not merely tidy.

## 3. Publication Model §spec:publication-model

*Status: in progress*

Implements §req:success-criteria. Independent installation, adoption,
and upgrade all depend on per-package publication with per-package
versioning.

Each package publishes to pub.dev under an independent SemVer track.
Pre-1.0 versions (`0.x.y`) signal "API shapes are stable enough to
use, but expect breakage until validated by real consumers."
Version `1.0.0` signals API commitment once at least one external
consumer has validated the shape.

Packages version independently: a bug fix in `repl_view` does not
bump `line_snap_scroll_physics`. Each package carries its own
`CHANGELOG.md` tracking only its own history.

`dart pub publish --dry-run` is the gate — each package shall be
independently publishable before any is published. Rationale: a
partially-published dependency graph is harder to recover from than
a failed dry-run on the first package.

## 4. Development Workflow §spec:development-workflow

*Status: complete*

Implements §req:problem-statement. Maintaining four interdependent
packages in lockstep during development requires shared workspace
tooling; contributors working across packages need a single
resolve step.

The repository is a Dart 3.6+ workspace. The root `pubspec.yaml`
declares `packages/*` under `workspace:`, and each package declares
`resolution: workspace` to participate in shared resolution. A
single `dart pub get` at the root bootstraps all four packages.

Melos scripts (`melos.yaml`) run analyze, test, and format-check
across all packages in one command. Melos is a convenience layer —
every script has a direct `dart` equivalent that works from any
package directory. Contributors without Melos installed can still
develop and test.

## 5. Origin and License §spec:origin-and-license

*Status: complete*

Implements §req:problem-statement. The extraction from rove is the
mechanism by which the primitives become consumable by projects
other than rove.

The packages lived as in-tree modules inside
[repentsinner/rove](https://github.com/repentsinner/rove) from
PR #119 (scroll widget package extraction) until the initial import
to this repo. Pre-extraction history remains in rove; this repo
carries per-file history from the extraction onward.

BSD 3-Clause, matching upstream rove.

## 6. Publication Automation §spec:publication-automation

*Status: not started*

Implements §req:success-criteria. The publication mechanism avoids
ambient credentials — long-lived tokens stored in repository secrets
would be readable by every workflow in the repo and would broaden
the blast radius of any compromise.

Publishing is triggered by git tag push events. pub.dev accepts
automated publication only from tag-triggered workflows, and the
`<component>-v<version>` tag format release-please already produces
matches pub.dev's per-package trusted publisher pattern. Merging a
release-please PR creates the tags; the tags trigger the publishes.

Authentication uses OIDC against pub.dev's trusted publisher
mechanism — the workflow exchanges a GitHub-signed OIDC token for a
short-lived pub.dev credential, scoped to one publish. No
long-lived credentials live in the repo or GitHub secrets. Reference:
[dart.dev/tools/pub/automated-publishing](https://dart.dev/tools/pub/automated-publishing).

Topological publication order is preserved across simultaneous
releases. When release-please bumps multiple packages in one PR —
most notably on initial publication — all tags land in a single push
and all workflows trigger together. A dependent that publishes before
its dependency is indexed on pub.dev fails resolver lookup. The
workflow enforces ordering (base physics package before its two
direct consumers, those before the transitive consumer) without
prescribing a specific mechanism. Subsequent releases rarely exercise
this path; release-please only tags packages with version-bumping
commits, so most releases touch one package in isolation.

One-time human setup is required and cannot be automated. Each of
the four packages shall be registered as a trusted publisher on its
pub.dev Admin page with a matching tag pattern. The pub.dev package
owner grants this trust; a GitHub App cannot. Until registration
completes for a given package, its workflow cannot publish that
package — the first publication of each package necessarily follows
the trusted publisher registration for that package.
