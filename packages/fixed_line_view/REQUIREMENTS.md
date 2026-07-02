# fixed_line_view Requirements

## Problem statement §req:flv-problem

Console-, code-, and log-style views share a recurring shape. The package
shall provide:

- Fixed line height so virtualization is cheap (`ListView.itemExtent`).
- An "active" line (executing G-code, selected log entry) tracked and kept
  visible under a configurable auto-scroll rule.
- Bottom-following that follows new content, suppresses once the user
  scrolls away, and resumes when the user returns to the bottom.
- Optional pixel-aligned line snapping so every frame renders whole lines.
- Optional multi-line text selection.

No community option fits:

- **`xterm`**: a full terminal emulator (ANSI parsing, grid buffer,
  cursor/keyboard) — far heavier than a scrollable line list.
- **General `ListView`/`CustomScrollView`** recipes: reimplement
  follow / suppress / resume each time, often with fling and
  programmatic-scroll bugs.

Consumers otherwise re-implement the shape as one-off widgets.

## Scope §req:flv-scope

The package shall own the virtualized list shell and its auto-scroll state
machine. It shall not own:

- Line content — the consumer supplies `lineBuilder` / `itemBuilder`.
- Hierarchical sticky headers — compose with `sticky_hierarchical_scroll`
  via a shared `ScrollController` (§req:flv-behavior).
- Text styling, syntax highlighting, decoration.

Pure Flutter. Depends on `line_snap_scroll_physics` for the optional
line-snap mode.

## Behavioral requirements §req:flv-behavior

- **Active-line tracking.** `AutoScrollBehavior.center` shall scroll the
  active line toward the viewport center when `activeLineIndex` changes.
- **Bottom-following.** `AutoScrollBehavior.bottom` shall follow new
  content, shall suppress once the user scrolls away from the bottom, and
  shall resume when the user returns to the bottom.
- **Controller identity.** A consumer-supplied `ScrollController` shall be
  used as-is, never swapped, because composition hands the same instance to
  the sticky view. Line-snap shall supply a `LineSnapScrollController` only
  when the widget owns the controller.
- **Ownership.** The widget shall dispose only the controller it owns,
  never a consumer-supplied one.
- **Ring buffer.** `StreamLineView` shall trim to `maxLines` as a ring
  buffer when set.
- **Scrollbar clearance.** Trailing content shall stay clear of the
  scrollbar lane via the reserved gutter — a static, uniform reservation.
