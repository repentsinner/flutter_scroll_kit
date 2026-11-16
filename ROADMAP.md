# Development Roadmap

New work enters here as `##` sections in build-dependency order. The
running system is described in SPEC.md.

## Automate publication with Flywheel §road:flywheel-publication

Closes §spec:publication-automation. Version 0.1.0 published by hand,
and pub.dev trusts this repository's tag-triggered publish workflow.

- **discontinue-old-packages**: mark `line_snap_scroll_physics`,
  `sticky_hierarchical_scroll`, `fixed_line_view`, and `repl_view`
  discontinued on pub.dev, with `flutter_scroll_kit` as the suggested
  replacement.
