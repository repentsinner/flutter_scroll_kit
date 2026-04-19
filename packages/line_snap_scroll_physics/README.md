# line_snap_scroll_physics

Line-aligned scroll primitives for any Flutter `ScrollView`.

Flutter's `FixedExtentScrollPhysics` implements snap-to-item-boundary
ballistics correctly but is coupled to `FixedExtentScrollController`
and therefore restricted to `ListWheelScrollView`. This package
extracts the same targeting math into a general `ScrollPhysics` and
adds a `ScrollController` that quantizes every pixel update — so
general `ListView`, `CustomScrollView`, and sliver-based scroll views
can snap cleanly to line boundaries too.

Tracks [flutter/flutter#41472](https://github.com/flutter/flutter/issues/41472).

## Usage

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

The controller and physics are independent. Using both is the
strongest guarantee:

- `LineSnapScrollController` quantizes every `setPixels` call —
  drag, fling, and programmatic `jumpTo` all round to a line
  boundary before they reach paint.
- `LineSnapScrollPhysics` targets item boundaries at the end of
  ballistic simulations. Without the controller, paint can still
  see fractional pixels mid-fling; with it, every frame is aligned.

## ScrollMode

```dart
LineSnapScrollPhysics(
  itemExtent: 16.0,
  mode: ScrollMode.line,  // default — snap to line boundaries
)
```

| Mode | Behavior |
|---|---|
| `ScrollMode.line` | Snap to `itemExtent` boundaries after every gesture. |
| `ScrollMode.pixel` | Delegate ballistic simulation to parent physics (platform-default smooth scroll). |

Useful for user-facing toggles between "snap to line" and "smooth
scroll" without swapping the physics instance.

## Snap alignment

Snap is bottom-aligned: the snapped offset satisfies
`(offset + viewportDimension) mod itemExtent == 0`. Whole lines pack
against the bottom of the viewport and any fractional line appears
at the top — matching terminal/console convention (VS Code,
xterm.js) where the newest output sits on the bottom edge.

## Parameters

### `LineSnapScrollController`

| Parameter | Description |
|---|---|
| `itemExtent` | Fixed pixel height of every line. Must be positive. |
| `initialScrollOffset` | Inherited from `ScrollController`. |
| `keepScrollOffset` | Inherited from `ScrollController`. |
| `debugLabel` | Inherited from `ScrollController`. |

### `LineSnapScrollPhysics`

| Parameter | Description |
|---|---|
| `itemExtent` | Fixed pixel height of every line. Must be positive. |
| `mode` | `ScrollMode.line` (default) or `ScrollMode.pixel`. |
| `parent` | Parent physics in the decorator chain. |
