# fixed_line_view

Virtualized fixed-height line view widgets for Flutter.

Two widgets for log-, terminal-, and listing-shaped UIs where rows
share a uniform height:

- `FixedLineView` — an indexed virtualized list with active-line
  tracking and configurable auto-scroll.
- `StreamLineView<T>` — a stream-driven variant that appends items
  as they arrive and optionally trims to a ring-buffer cap.

Depends on [`line_snap_scroll_physics`](../line_snap_scroll_physics/)
for optional line-snap behavior.

## FixedLineView

```dart
FixedLineView(
  lineCount: lines.length,
  itemExtent: 16.0,
  activeLineIndex: currentLine,
  autoScroll: AutoScrollBehavior.center,
  lineBuilder: (context, index) => Text(lines[index]),
);
```

| Parameter | Description |
|---|---|
| `lineCount` | Total number of lines. |
| `itemExtent` | Fixed pixel height of every line. |
| `lineBuilder` | Builds the widget for line at `index`. |
| `activeLineIndex` | Currently active line (e.g. executing line), or null. |
| `autoScroll` | How to follow `activeLineIndex` changes (see below). |
| `controller` | Optional external `ScrollController`. |
| `physics` | Optional scroll physics (pair with `LineSnapScrollPhysics` for snap behavior). |
| `emptyBuilder` | Widget shown when `lineCount == 0`. |
| `selectable` | Wrap in `SelectionArea` for cross-line text selection. |
| `selectionColor` | Selection highlight color when `selectable` is true. |
| `lineSnap` | Enable line-snap physics without supplying a custom `physics`. |

## StreamLineView

```dart
StreamLineView<LogEvent>(
  itemStream: logStream,
  initialItems: history,
  maxLines: 10000,
  itemExtent: 16.0,
  autoScroll: AutoScrollBehavior.bottom,
  itemBuilder: (context, event, index) => Text(event.message),
);
```

| Parameter | Description |
|---|---|
| `itemStream` | Stream of individual items to append. |
| `initialItems` | Items to seed the list with before the stream starts. |
| `maxLines` | Ring-buffer cap; oldest items are trimmed when exceeded. `null` = unlimited. |
| `itemExtent` | Fixed pixel height of every row. |
| `itemBuilder` | Builds the widget for an item. |
| `autoScroll` | Default `AutoScrollBehavior.bottom` for log-shaped content. |
| `controller`, `physics`, `emptyBuilder`, `selectable`, `selectionColor`, `lineSnap` | Passed through to the underlying `FixedLineView`. |

## AutoScrollBehavior

| Value | Behavior |
|---|---|
| `none` | No automatic scrolling. |
| `center` | Keep the active line centered. Typical for executing-line indicators in editors or G-code viewers. |
| `bottom` | Keep the newest content at the bottom. Typical for logs and streaming output. |

The widget suspends auto-scroll while the user is manually scrolling
and resumes once the user returns to the tracked position.

## Composition

`FixedLineView` exposes its internal `FixedLineViewController` for
composition with other scroll-aware widgets
(e.g. `sticky_hierarchical_scroll`) via a shared `ScrollController`.
Pass the same controller into both widgets when composing.
