# flutter_scroll_kit example

A demo app with one tab per primitive. A caption at the top of each tab
names the library it uses.

- **Code view** shows a source file in a `ListView` driven by
  `LineSnapScrollPhysics` and `LineSnapScrollController`. Drags, flings,
  and programmatic scrolls stop on a whole line, so no line is cut off
  at the bottom edge.
- **Sticky headers** renders a nested file tree in
  `StickyHierarchicalScrollView`. Section headers stack at the viewport
  top as their scope scrolls past, VS Code–style.
- **Log stream** feeds a live log into `StreamLineView`. The view
  follows the newest line, holds still while scrolled back, and follows
  again once scrolled back to the bottom.
- **REPL** is a terminal-style `ReplView` with a prompt as its last row.
  Typing `help`, `status`, or `ls -l logs` and pressing Enter appends
  the command and its output. Each command pins as a sticky header while
  its output scrolls beneath it.

Run it from this directory:

```sh
flutter create . --platforms=linux,macos,windows,web
flutter run
```

On a desktop platform, `--tour` loops through every tab with scripted
drags and typing:

```sh
flutter run -a --tour
```
