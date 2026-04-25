# Development Roadmap

## Publication to pub.dev

Implements §spec:publication-model and §spec:publication-automation.
The monorepo, per-package sources, workspace bootstrap, SPECs, and
per-package publish workflows are landed. The remaining work
performs the one-time trusted-publisher configuration on pub.dev
so external consumers (starting with rove's `swap-to-pub-dev-deps`
workstream) can depend on hosted versions instead of git sources.

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
