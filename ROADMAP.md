# Development Roadmap

New work enters here as `##` sections in build-dependency order. The
running system is described in SPEC.md.

## Framework Dependency §spec:framework-dependency

### §road:widgets-only-imports

Replace the `flutter/material` imports in `fixed_line_view`,
`repl_view`, and `sticky_hierarchical_scroll` with
`flutter/widgets`. Rebuild selection, the sticky view's scrollbar, and
the default gutter width on the widgets layer, and update
§spec:shs-scrollbar-gutter and the `selectable` description in
`doc/fixed_line_view/SPEC.md` to match. Reported in #67.

**Verify:**

- No file under `lib/` imports `flutter/material` or
  `flutter/cupertino`, and a test fails if one does.
- Under a `WidgetsApp` root, `FixedLineView(selectable: true)` builds
  without error and its lines can be selected.
- Under a `WidgetsApp` root, `StickyHierarchicalScrollView` shows the
  scrollbar that the ambient `ScrollBehavior` builds.
- With `scrollbarGutter` null, the gutter equals the documented
  default constant.
