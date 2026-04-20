# Development Roadmap

## Publication to pub.dev

Implements §spec:publication-model. The monorepo, per-package
sources, workspace bootstrap, and SPECs are landed. The remaining
work gets the four packages onto pub.dev so external consumers
(starting with rove's `swap-to-pub-dev-deps` workstream) can depend
on hosted versions instead of git sources.

### §road:ci-workflow

GitHub Actions workflow running `dart analyze --fatal-infos`,
`dart format --output=none --set-exit-if-changed .`, and
`flutter test` on every push and PR. Matrix across the four
packages for per-package isolation. Conventional Commits lint gate
on PR (release tooling consumes commit messages). Depends on
§road:pubspec-publish-prep.

### §road:release-tooling

Wire release-please (preferred — handles per-package versioning
via release-please-manifest) for automated version bumps,
`CHANGELOG.md` generation, tag creation, and pub.dev publishing on
merge to main. Configure the four packages as independent release
components. Depends on §road:ci-workflow.

### §road:first-publication

Publish `0.1.0` of each package to pub.dev in topological order:
`line_snap_scroll_physics` first, `sticky_hierarchical_scroll` and
`fixed_line_view` in parallel, `repl_view` last. Verify each via
`dart pub add <package>` in a scratch project between publishes.
Depends on §road:release-tooling. Closes §spec:publication-model.

**Verify:** After §road:first-publication lands, each of the four
packages appears on pub.dev at `https://pub.dev/packages/<name>`
with its documented description, README, dependency graph, and
per-package `CHANGELOG.md`. `dart pub add line_snap_scroll_physics`
in a scratch Flutter project resolves successfully and `import
'package:line_snap_scroll_physics/line_snap_scroll_physics.dart'`
compiles. Rove's `swap-to-pub-dev-deps` workstream (tracked in
[rove's ROADMAP](https://github.com/repentsinner/rove/blob/main/ROADMAP.md))
becomes unblocked.
