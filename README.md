# flutter_scroll_kit

Composable Flutter scroll primitives that extend the built-in
`ScrollView` family with line-snap ballistics, hierarchical sticky
headers, virtualized fixed-height lines, and REPL-shaped scrollback.
The package depends only on Flutter.

## Install

```sh
dart pub add flutter_scroll_kit
```

Each primitive has its own library. Import the one you use, or import
`package:flutter_scroll_kit/flutter_scroll_kit.dart` for all four.
Tree-shaking keeps primitives you don't use out of the built app.

| Library | Purpose |
|---------|---------|
| [`line_snap_scroll_physics.dart`](#line-snap-scroll-physics) | `ScrollController` and `ScrollPhysics` that quantize scroll offsets to fixed line boundaries, for any `ScrollView`. |
| [`sticky_hierarchical_scroll.dart`](#sticky-hierarchical-scroll) | VS Code–style sticky headers for hierarchical lists. Nested section headers stack as their scope scrolls past the viewport top. |
| [`fixed_line_view.dart`](#fixed-line-view) | Virtualized fixed-height line view with active-line tracking and auto-scroll, plus a stream-driven variant for logs. Builds on line snap. |
| [`repl_view.dart`](#repl-view) | REPL scrollback: input lines pin as sticky headers, responses scroll beneath them, and repeated responses show a count. Builds on sticky headers. |

## Line snap scroll physics

```dart
import 'package:flutter_scroll_kit/line_snap_scroll_physics.dart';
```

Flutter's `FixedExtentScrollPhysics` snaps to item boundaries but works
only with `ListWheelScrollView`. `LineSnapScrollPhysics` applies the
same targeting math to `ListView`, `CustomScrollView`, and other
sliver-based scroll views. `LineSnapScrollController` quantizes every
pixel update. See
[flutter/flutter#41472](https://github.com/flutter/flutter/issues/41472).

```dart
final controller = LineSnapScrollController(itemExtent: 16.0);

ListView.builder(
  controller: controller,
  physics: const LineSnapScrollPhysics(itemExtent: 16.0),
  itemExtent: 16.0,
  itemCount: lines.length,
  itemBuilder: (context, i) => Text(lines[i]),
);
```

The controller and physics work independently, and using both gives
the strongest guarantee:

- `LineSnapScrollController` rounds every `setPixels` call to a line
  boundary before it reaches paint. That covers drag, fling, and
  programmatic `jumpTo`.
- `LineSnapScrollPhysics` targets item boundaries at the end of
  ballistic simulations. Without the controller, paint can see
  fractional pixels mid-fling.

`mode` switches between `ScrollMode.line`, the default, which snaps to
`itemExtent` boundaries after every gesture, and `ScrollMode.pixel`,
which hands the ballistic simulation to the parent physics. A
"snap to line" toggle can switch modes without replacing the physics.

Snap is bottom-aligned: the snapped offset satisfies
`(offset + viewportDimension) mod itemExtent == 0`. Whole lines pack
against the bottom of the viewport, and any fractional line appears at
the top. This matches terminal convention, where the newest output
sits on the bottom edge.

| Parameter | Applies to | Description |
|---|---|---|
| `itemExtent` | both | Fixed pixel height of every line. Must be positive. |
| `mode` | physics | `ScrollMode.line` (default) or `ScrollMode.pixel`. |
| `parent` | physics | Parent physics in the decorator chain. |
| `initialScrollOffset`, `keepScrollOffset`, `debugLabel` | controller | Inherited from `ScrollController`. |

## Sticky hierarchical scroll

```dart
import 'package:flutter_scroll_kit/sticky_hierarchical_scroll.dart';
```

Section headers stick to the top of the viewport as the list scrolls
and form a breadcrumb trail of the current position. When a section
ends, its header slides out, matching VS Code's tree sticky scroll.
Tapping a sticky header scrolls to its section. Rows share a fixed
height.

```dart
StickyHierarchicalScrollView<MyItem>(
  items: items,
  getLevel: (item) => item.level,
  isSection: (item) => item.isSection,
  itemExtent: 32.0,
  config: StickyScrollConfig<MyItem>(
    maxStickyHeaders: 3,
    stickyDecoration: BoxDecoration(color: Colors.grey[900]),
    stickyHeaderBuilder: (context, candidate) {
      return Text(candidate.data.label);
    },
  ),
  itemBuilder: (context, item, index) {
    return Text(item.label);
  },
)
```

| Parameter | Description |
|---|---|
| `items` | Flat list of all items, sections and leaves. |
| `getLevel` | Returns an item's depth. Root is level 0, its children level 1, and so on. Negative levels aren't supported. |
| `isSection` | Returns `true` for items that stick. |
| `itemExtent` | Fixed pixel height of every row. |
| `config` | Sticky behavior, described below. |
| `controller` | Optional external `ScrollController`. |
| `physics` | Scroll physics. Defaults to the platform's. |
| `onStickyHeaderTap` | Custom tap handler, which replaces the default scroll-to. |
| `itemKey` | Optional unique, stable identity of an item. When set, rows follow their item when the list shifts instead of rebuilding. |

`StickyScrollConfig` takes these properties:

| Property | Default | Description |
|---|---|---|
| `stickyHeaderBuilder` | required | Builds the widget for each sticky header. |
| `maxStickyHeaders` | `5` | Maximum headers shown at once. |
| `enableNavigation` | `true` | Tapping a header scrolls to its section. |
| `stickyDecoration` | `BoxDecoration(color: #1E1E1E)` | Decoration behind each sticky header, including gradients, borders, and shadows. |

`stickyHeaderBuilder` receives a `StickyCandidate<T>` that carries the
original item as `data`, its `level`, and its `originalIndex` in the
flat list.

## Fixed line view

```dart
import 'package:flutter_scroll_kit/fixed_line_view.dart';
```

Two widgets for log-, terminal-, and listing-shaped UIs whose rows
share one height. `FixedLineView` is an indexed virtualized list with
active-line tracking and auto-scroll. `StreamLineView<T>` appends items
from a stream as they arrive and can trim to a ring-buffer cap.

```dart
FixedLineView(
  lineCount: lines.length,
  itemExtent: 16.0,
  activeLineIndex: currentLine,
  autoScroll: AutoScrollBehavior.center,
  lineBuilder: (context, index) => Text(lines[index]),
);

StreamLineView<LogEvent>(
  itemStream: logStream,
  initialItems: history,
  maxLines: 10000,
  itemExtent: 16.0,
  autoScroll: AutoScrollBehavior.bottom,
  itemBuilder: (context, event, index) => Text(event.message),
);
```

`FixedLineView` takes these parameters:

| Parameter | Description |
|---|---|
| `lineCount` | Total number of lines. |
| `itemExtent` | Fixed pixel height of every line. |
| `lineBuilder` | Builds the widget for the line at `index`. |
| `activeLineIndex` | The active line, such as an executing line, or null. |
| `autoScroll` | How the view follows `activeLineIndex` changes, described below. |
| `controller` | Optional external `ScrollController`. |
| `physics` | Optional scroll physics. Pair with `LineSnapScrollPhysics` for snap behavior. |
| `emptyBuilder` | Widget shown when `lineCount == 0`. |
| `selectable` | Wraps the view in `SelectionArea` for cross-line text selection. |
| `selectionColor` | Selection highlight color when `selectable` is true. |
| `lineSnap` | Turns on line-snap physics without a custom `physics`. |

`StreamLineView` takes `itemStream`, `initialItems`, `maxLines` (null
means unlimited), `itemExtent`, and `itemBuilder`. Its `autoScroll`
defaults to `AutoScrollBehavior.bottom`, and it passes `controller`,
`physics`, `emptyBuilder`, `selectable`, `selectionColor`, and
`lineSnap` through to `FixedLineView`.

| `AutoScrollBehavior` | Behavior |
|---|---|
| `none` | No automatic scrolling. |
| `center` | Keeps the active line centered, as for an executing-line indicator in an editor. |
| `bottom` | Keeps the newest content at the bottom, as for logs and streaming output. |

Auto-scroll pauses while the user scrolls by hand and resumes once the
user returns to the tracked position. `FixedLineView` exposes its
`FixedLineViewController` so it can share one `ScrollController` with
other scroll-aware widgets, such as a sticky header overlay.

## REPL view

```dart
import 'package:flutter_scroll_kit/repl_view.dart';
```

Input lines pin as sticky section headers, and response lines scroll
as leaves within each section. The consumer's data source coalesces
repeated responses into one entry with `count > 1`, and the row builder
can render it as a badge, such as "ok ×47" in place of 47 identical
lines.

```dart
class MyEntry implements ConsoleEntry {
  MyEntry({
    required this.value,
    required this.isInput,
    required this.coalescingKey,
    required this.identity,
    this.count = 1,
  });

  @override
  final String value;
  @override
  final bool isInput;
  @override
  final String coalescingKey;
  @override
  final int count;
  @override
  final Object identity;
}

ReplView<MyEntry>(
  entries: entries,
  itemExtent: 16.0,
  entryBuilder: (context, entry) => Row(
    children: [
      if (entry.count > 1) Text('${entry.count}× '),
      Expanded(child: Text(entry.value, overflow: TextOverflow.ellipsis)),
    ],
  ),
);
```

| `ConsoleEntry` member | Description |
|---|---|
| `value` | Display text. |
| `isInput` | `true` pins the row as a sticky section header. |
| `coalescingKey` | Consumer-owned grouping key, for information only. |
| `count` | Number of coalesced occurrences. The row builder renders a badge when it's greater than 1. |
| `identity` | Stable identity that anchors the scroll position across coalescing and rebuilds. Typically a monotonic `int` assigned when the message is created. |

The viewport has two states:

- **Stuck to bottom** is the default. New entries, coalescing updates,
  parent rebuilds, and tab detach and reattach all settle at the
  bottom.
- **Floating** starts when the user drags away from the bottom. The
  viewport pins to an entry by `identity` plus a pixel offset within
  it, so appends and coalescing leave the visible content in place.
  When the consumer trims the anchor entry from its scrollback, the
  view returns to the bottom.

| Parameter | Description |
|---|---|
| `entries` | Flat list of inputs and responses in display order. |
| `entryBuilder` | Builds one row, for both scroll items and sticky headers. |
| `itemExtent` | Fixed pixel height of every row. |
| `maxStickyHeaders` | Maximum stacked sticky headers. Defaults to 1. |
| `stickyDecoration` | Decoration behind each sticky header. |
| `controller` | Optional external `ScrollController`. |
| `physics` | Scroll physics. Defaults to the platform's. |
| `trailingItemCount` | Number of rows appended after the entries, such as a prompt line. |
| `trailingItemBuilder` | Builds the trailing rows, which scroll with the content. |

`ReplView` doesn't deduplicate entries. It reads the supplied `count`,
so the consumer chooses what counts as a repeat. Inputs render as
level-0 sticky sections and responses as level-1 leaves, a fixed depth
of two.

## Example

`example/` is one app with a tab per primitive:

```sh
cd example
flutter create . --platforms=linux,macos,windows,web
flutter run
```

## Development

The root is the package, and `example/` resolves separately because it
depends on the package by path. CI runs these commands:

```sh
dart pub get && (cd example && dart pub get)
dart format .
dart analyze
flutter test && (cd example && flutter test)
```

Design documents live in [SPEC.md](SPEC.md) and
[REQUIREMENTS.md](REQUIREMENTS.md), with one `SPEC.md` and
`REQUIREMENTS.md` per primitive under [`doc/`](doc/).

## License

BSD 3-Clause. See [LICENSE](LICENSE).
