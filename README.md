# flutter_scroll_kit

A collection of composable Flutter scroll primitives that extend the
built-in `ScrollView` family with line-snap ballistics, hierarchical
sticky headers, virtualized fixed-height lines, and REPL-shaped
scrollback.

## Packages

| Package | Purpose |
|---------|---------|
| [`line_snap_scroll_physics`](packages/line_snap_scroll_physics) | `ScrollController` and `ScrollPhysics` that quantize scroll offsets to fixed line boundaries. Generalizes Flutter's `FixedExtentScrollPhysics` beyond `ListWheelScrollView`. |
| [`sticky_hierarchical_scroll`](packages/sticky_hierarchical_scroll) | VS Code–style hierarchical sticky header overlay for flat lists. Stacks nested section headers as the scope scrolls past the viewport top. |
| [`fixed_line_view`](packages/fixed_line_view) | Virtualized fixed-height line view with active-line tracking and auto-scroll. Pairs with stream sources for log-style displays. |
| [`repl_view`](packages/repl_view) | Two-level REPL scrollback: input lines pin as sticky section headers, response lines scroll as leaves. Identity-anchored viewport preservation across coalescing and tab-switches. |

Each package ships its own `SPEC.md` describing design rationale and
API. Per-package governance, not root-governed.

## Dependency graph

```
line_snap_scroll_physics ──┬── sticky_hierarchical_scroll ── repl_view
                           └── fixed_line_view
```

All four are pure Flutter — no third-party dependencies.

## Development

This repo is a Dart workspace (`resolution: workspace`). From the
root:

```sh
dart pub get         # bootstrap all packages at once
dart analyze         # analyze all packages
```

Or with Melos:

```sh
dart pub global activate melos
melos bootstrap
melos run analyze
melos run test
melos run format-check
```

## History

These packages were extracted from
[repentsinner/rove](https://github.com/repentsinner/rove) before
being moved here for publication. Full pre-extraction history lives
in that repo; this repo carries per-file history from the extraction
point forward.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
