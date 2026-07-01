# fixed_line_view Specification

A Flutter package that renders virtualized fixed-height line views with
active-line tracking, auto-scroll, and optional pixel-aligned line
snapping. Wraps `ListView.builder` with conventions common to consoles,
code views, and log streams.

Implements §req:flv-problem, §req:flv-scope, and §req:flv-behavior.

---

## 1. Widgets §spec:flv-widgets

*Status: complete*

**`FixedLineView`** renders a flat list of `lineCount` items via
`lineBuilder(context, index)`. Callers drive `activeLineIndex` and
`autoScroll` (`none` / `center` / `bottom`). Optional `selectable`
wraps in a `SelectionArea` for cross-line text selection.

**`StreamLineView<T>`** wraps `FixedLineView` for stream-driven
content. Subscribes to `itemStream`, appends items to an internal
list, and optionally trims to `maxLines` as a ring buffer. Default
auto-scroll is `bottom` because the widget exists for log-like views.

**`FixedLineViewController`** shares a `ScrollController` between a
`FixedLineView` and a sticky-scroll overlay (or any other widget that
observes the same scroll). Owns the controller iff the consumer did
not pass one in, and disposes only what it owns.

---

## 2. Auto-Scroll State Machine §spec:flv-auto-scroll

*Status: complete*

The auto-scroll behavior has two orthogonal axes.

**Active-line tracking** (`AutoScrollBehavior.center`): when
`activeLineIndex` changes, scroll so the active line sits at the
viewport center.

**Bottom-following** (`AutoScrollBehavior.bottom`): when new content
arrives, scroll to keep the bottom visible. The widget tracks a
`userScrolledAway` flag: once the user manually scrolls above the
bottom edge, auto-scroll suppresses until the user scrolls back to the
bottom. Standard log-viewer behavior.

`AutoScrollBehavior.none` disables both. The viewer sits still and
respects only explicit programmatic scroll.

---

## 3. Line Snap §spec:flv-line-snap

*Status: complete*

`lineSnap: true` engages `line_snap_scroll_physics`.
`LineSnapScrollPhysics` always replaces the physics, targeting line
boundaries at the end of ballistic simulations. The controller is
line-snapping only when `FixedLineView` owns it: with no `controller`
passed, the widget creates a `LineSnapScrollController` that quantizes
every pixel update. A consumer-supplied `controller` is used as-is —
swapping it would break the shared-controller composition contract
(§spec:flv-composition), which hands the same instance to the sticky
view. To keep per-frame quantization while composing, pass a
`LineSnapScrollController`.

Line snap is off by default: most consumers (log panels, source views)
accept fractional-pixel scrolling. Console-like consumers enable it for
visual parity with terminal scrollbars.

---

## 4. Composition with Sticky Scroll §spec:flv-composition

*Status: complete*

The composition pattern:

1. Create a `FixedLineViewController` (or provide an external
   `ScrollController` to its constructor).
2. Pass `controller.scrollController` to both `FixedLineView` and the
   `sticky_hierarchical_scroll` widget.
3. Both widgets observe the same scroll offset; the sticky overlay
   updates from the shared listener as `FixedLineView` scrolls.

The two packages do not know about each other. The composition point
is the `ScrollController` and the contract is "same `itemExtent` and
same controller."

---

## 5. API Surface §spec:flv-api-surface

*Status: complete*

```dart
enum AutoScrollBehavior { none, center, bottom }

class FixedLineView extends StatefulWidget {
  const FixedLineView({
    required int lineCount,
    required double itemExtent,
    required Widget Function(BuildContext, int) lineBuilder,
    int? activeLineIndex,
    AutoScrollBehavior autoScroll = AutoScrollBehavior.none,
    ScrollController? controller,
    ScrollPhysics? physics,
    Widget? emptyBuilder,
    bool selectable = false,
    Color? selectionColor,
    bool lineSnap = false,
    double? scrollbarGutter,   // null → auto from theme; 0 → disabled
  });
}

class StreamLineView<T> extends StatefulWidget {
  const StreamLineView({
    required Stream<T> itemStream,
    List<T> initialItems = const [],
    int? maxLines,
    required double itemExtent,
    required Widget Function(BuildContext, T, int) itemBuilder,
    AutoScrollBehavior autoScroll = AutoScrollBehavior.bottom,
    Widget? emptyBuilder,
    ScrollController? controller,
    ScrollPhysics? physics,
    bool selectable = false,
    Color? selectionColor,
    bool lineSnap = false,
    double? scrollbarGutter,   // forwarded to FixedLineView
  });
}

final class FixedLineViewController {
  FixedLineViewController({ScrollController? scrollController});
  final ScrollController scrollController;
  void dispose();
}
```

---

## 6. Scrollbar Gutter §spec:flv-scrollbar-gutter

*Status: complete*

`FixedLineView` reserves a trailing `scrollbarGutter` so line content and
trailing tap targets render clear of the scroll lane. `StreamLineView`
forwards the parameter to the `FixedLineView` it wraps, so both views
share one rule.

`scrollbarGutter` inherits the §spec:shs-scrollbar-gutter contract
verbatim: `double?`, `null` (default) auto-derives from the effective
`ScrollbarThemeData.thickness` with the Material default as fallback, `0`
disables the gutter, a positive value reserves exactly that width — a
**static, uniform** reservation present in every layout state on every
platform, not gated on thumb visibility. A consumer that sets the gutter
on a `FixedLineView` and a `StickyHierarchicalScrollView` meets one
trailing-edge rule, not two, because both derive the width from the same
theme.

Unlike the sticky view, `FixedLineView` does not render its own
`Scrollbar` — it reserves the gutter as a trailing `ListView` padding
inset and leaves the bar to the ambient `ScrollBehavior`, which paints
into the reserved strip. Two reasons:

- *Composition* (§spec:flv-composition): `FixedLineView` and
  `StickyHierarchicalScrollView` share one `ScrollController`, and the
  sticky view already owns a `Scrollbar`. A second `Scrollbar` in the
  line view would paint two bars over the same scroll position.
- *Minimal chrome:* the line view delegates scrollbar rendering to the
  ambient behavior; a padding inset adds the gutter without taking
  ownership of the bar.

Owning a `Scrollbar` here was rejected: it reintroduces the double-bar
hazard, and shared `ScrollbarThemeData` already guarantees alignment.
The gutter costs horizontal space on every platform; full-bleed
consumers opt out with `scrollbarGutter: 0`.

---

## 7. Testing Strategy §spec:flv-testing-strategy

*Status: complete*

Unit tests cover:

- `AutoScrollBehavior.center`: changing `activeLineIndex` scrolls
  toward centering the line.
- `AutoScrollBehavior.bottom`: a growing `lineCount` scrolls to the
  bottom, on both initial build and update.
- `StreamLineView` ring buffer: items past `maxLines` drop from the
  head; the stream subscription is cancelled on dispose.
- Controller ownership: the widget disposes its internal controller,
  never a consumer-supplied one.
- Rendering: item count, `emptyBuilder` fallback, and `SelectionArea`
  wrapping under `selectable`.
- Virtualization bound: a 10000-line list builds only the visible
  window plus `ListView`'s cache extent — never the trailing index.
- `lineSnap` wiring: after a drag or fling, the offset settles on a
  line boundary (`offset % itemExtent == 0`).
- `AutoScrollBehavior.center` no-op: re-centering an already-centered
  line leaves the offset unchanged.
- `AutoScrollBehavior.bottom` suppression and resume: a user drag away
  from the bottom suppresses auto-follow on new content; a user drag
  back to the bottom resumes it.

Tests run on the Flutter widget test runner.
