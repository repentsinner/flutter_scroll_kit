# flutter_scroll_kit example

A demo app with one tab per primitive:

- **Line snap** applies `LineSnapScrollPhysics` and
  `LineSnapScrollController` to a `ListView` of fixed-height rows.
  Fling, drag, and programmatic scroll land on an exact row.
- **Sticky headers** renders a nested file tree in
  `StickyHierarchicalScrollView`. Section headers stack at the viewport
  top as their scope scrolls past, VS Code–style.
- **Fixed lines** renders 100 numbered lines in `FixedLineView` with an
  active line that advances on a timer. `AutoScrollBehavior.center`
  keeps the active line in view.
- **REPL** feeds a handful of `ConsoleEntry` items into `ReplView`.
  Input entries pin as sticky headers, and responses scroll beneath
  them.

Run it from this directory:

```sh
flutter create . --platforms=linux,macos,windows,web
flutter run
```
