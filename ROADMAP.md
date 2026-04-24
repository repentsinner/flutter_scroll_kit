# Development Roadmap

## Publication to pub.dev

Implements §spec:publication-model and §spec:publication-automation.
The monorepo, per-package sources, workspace bootstrap, and SPECs are
landed. The remaining work gates commit hygiene, wires each package
to publish on tag push, and performs the one-time trusted-publisher
configuration on pub.dev so external consumers (starting with rove's
`swap-to-pub-dev-deps` workstream) can depend on hosted versions
instead of git sources.

### §road:conventional-commits-lint

GitHub Actions workflow gating PR titles against Conventional Commits
(`.github/workflows/conventional-commits-lint.yml`); implements
§spec:publication-model by protecting the release-please commit-parse
input.

### §road:publication-workflow

Per-package GitHub Actions publish workflows
(`.github/workflows/publish-<package>.yml`) triggered on
`<package>-v*` tag pushes, authenticated via `dart-lang/setup-dart`
OIDC and serialized by shared concurrency group for topological
ordering across simultaneous release-please tag bursts; implements
§spec:publication-automation.

### §road:first-publication

One-time pub.dev trusted-publisher configuration for all four packages
followed by the initial publication trigger (human-only operations,
no repo changes — requires pub.dev account access); closes
§spec:publication-model and §spec:publication-automation.

**Verify:** Each of the four packages appears at
`https://pub.dev/packages/<name>` with its documented description,
README, dependency graph, and per-package `CHANGELOG.md`. In a
scratch Flutter project, `dart pub add <package>` resolves for each
without a git reference, and
`import 'package:<package>/<package>.dart';` compiles — starting with
`line_snap_scroll_physics`, then `sticky_hierarchical_scroll` and
`fixed_line_view` in either order, then `repl_view`. Rove's
`swap-to-pub-dev-deps` workstream (tracked in
[rove's ROADMAP](https://github.com/repentsinner/rove/blob/main/ROADMAP.md))
unblocks.
