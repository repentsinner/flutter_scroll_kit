# Development Roadmap

New work enters here as `##` sections in build-dependency order. The
running system is described in SPEC.md.

## Automate publication with Flywheel §road:flywheel-publication

Closes §spec:publication-automation. Release-please and the four
per-package publish workflows are gone, so nothing publishes until
these land, in order.

- **baseline-tag**: push the `v0.1.0` tag on the `main` commit that
  carries `version: 0.1.0`. Without it, Flywheel's first run cuts
  `v1.0.0`.
- **first-publish**: run `dart pub publish` from that commit. pub.dev
  accepts automated publication only for a package that already
  exists.
- **trusted-publisher**: on the pub.dev Admin page, enable GitHub
  Actions publishing for this repository with tag pattern
  `v{{version}}` and the `pub.dev` environment.
- **flywheel-workflows**: add `.flywheel.yml`, the Flywheel push and
  pull request workflows, and a publish workflow triggered by
  `v[0-9]+.[0-9]+.[0-9]+` tags. Depends on the Flywheel App installed
  on the repository with its app ID variable and private key secret.
- **example-release-builds**: add a workflow triggered by
  `release: published` that runs `flutter create .` and
  `flutter build` for the example on Linux, macOS, and Windows
  runners, and uploads one archive per platform to the release.
  Depends on `flywheel-workflows`, because Flywheel creates the
  release.
- **discontinue-old-packages**: mark `line_snap_scroll_physics`,
  `sticky_hierarchical_scroll`, `fixed_line_view`, and `repl_view`
  discontinued on pub.dev, with `flutter_scroll_kit` as the suggested
  replacement. Depends on `first-publish`.
