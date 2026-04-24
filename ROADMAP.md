# Development Roadmap

## Publication to pub.dev

Implements §spec:publication-model. The monorepo, per-package
sources, workspace bootstrap, and SPECs are landed. The remaining
work gets the four packages onto pub.dev so external consumers
(starting with rove's `swap-to-pub-dev-deps` workstream) can depend
on hosted versions instead of git sources.

### §road:conventional-commits-lint

GitHub Actions workflow gating PRs to enforce Conventional Commits
on PR titles. release-please already reads commit messages on merge
to main; the title-based PR check prevents non-compliant titles from
reaching squash-merge.

### §road:first-publication

Publish each package to pub.dev in topological order:
`line_snap_scroll_physics` first, `sticky_hierarchical_scroll` and
`fixed_line_view` in parallel, `repl_view` last. Version is whatever
is current in `.release-please-manifest.json` at publish time (the
first release-please bump landed before any external publication, so
the first pub.dev version is `0.1.1`, not `0.1.0`). Verify each via
`dart pub add <package>` in a scratch project between publishes.
Closes §spec:publication-model.

**Verify:** After §road:first-publication lands, each of the four
packages appears on pub.dev at `https://pub.dev/packages/<name>`
with its documented description, README, dependency graph, and
per-package `CHANGELOG.md`. `dart pub add line_snap_scroll_physics`
in a scratch Flutter project resolves successfully and `import
'package:line_snap_scroll_physics/line_snap_scroll_physics.dart'`
compiles. Rove's `swap-to-pub-dev-deps` workstream (tracked in
[rove's ROADMAP](https://github.com/repentsinner/rove/blob/main/ROADMAP.md))
becomes unblocked.
