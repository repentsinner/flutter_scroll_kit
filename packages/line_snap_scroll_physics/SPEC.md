# line_snap_scroll_physics Specification

A Flutter package that quantizes scroll offsets to fixed line boundaries
for any `ScrollView`. Exposes a `ScrollController` that rounds every
pixel update during drag, fling, and programmatic scroll, plus a
`ScrollPhysics` that snaps ballistic simulations to the same boundaries.

Implements §req:lssp-problem, §req:lssp-scope, and §req:lssp-behavior.

---

## 1. API Surface §spec:lssp-api-surface

*Status: complete*

```dart
enum ScrollMode {
  line,   // snap to itemExtent boundaries every frame
  pixel,  // platform-default smooth scrolling (no snapping)
}

final class LineSnapScrollController extends ScrollController {
  final double itemExtent;

  LineSnapScrollController({
    required double itemExtent,
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    String? debugLabel,
  });
}

class LineSnapScrollPhysics extends ScrollPhysics {
  final double itemExtent;
  final ScrollMode mode;

  const LineSnapScrollPhysics({
    ScrollPhysics? parent,
    required double itemExtent,
    ScrollMode mode = ScrollMode.line,
  });
}
```

The controller and physics are independent. A consumer may use either
alone or both together. Using both is the strongest guarantee:

- `LineSnapScrollController` rounds every `setPixels` call. Any
  fractional offset produced by drag, fling, or `jumpTo` is quantized
  before it reaches paint.
- `LineSnapScrollPhysics` targets item boundaries at the end of
  ballistic simulations. Without the controller, paint can still see
  fractional pixels mid-fling; with it, every frame is aligned.

---

## 2. Snap Alignment §spec:lssp-snap-alignment

*Status: complete*

Snap is bottom-aligned: the snapped offset satisfies
`(offset + viewportDimension) mod itemExtent == 0`. Whole lines pack
against the bottom of the viewport and any fractional line appears at
the top. This matches terminal/console convention (VS Code, xterm.js)
where the newest output sits on the bottom edge.

`viewportDimension` is `0.0` before first layout; the controller falls
back to top-aligned snap for that one frame. Ballistic physics never
run before layout, so `LineSnapScrollPhysics` does not need a fallback.

---

## 3. Mode Switching §spec:lssp-mode-switching

*Status: complete*

`ScrollMode.pixel` disables snap and delegates ballistic simulation to
the parent physics. A consumer that exposes a user-facing toggle between
"snap to line" and "smooth scroll" passes different `mode` values into
the same physics instance.

The controller does not have a mode: if a consumer wants non-snapped
positions, it passes a plain `ScrollController` instead.

---

## 4. Testing Strategy §spec:lssp-testing-strategy

*Status: complete*

Unit tests cover:

- Quantization: `setPixels` holds line-aligned offsets across drag,
  fling (including every frame of the fling animation), and `jumpTo`;
  settling rounds to the nearest boundary.
- `ScrollMode.pixel` scrolls without snapping; `applyTo` preserves
  `itemExtent` and mode.
- Bottom-alignment invariant `(offset + viewportDimension) mod
  itemExtent == 0` holds across extent/viewport combinations, including
  non-divisible viewports (e.g. itemExtent 20, viewport 150), after
  drag, fling, and `jumpTo` away from the scroll boundaries.
- Snap math at the zero/negative boundary: the formula's nearest
  aligned target may be negative; the scroll view clamps it to
  `minScrollExtent`, so offset never goes below 0 under negative-
  direction input.
- The `assert(itemExtent > 0)` guard rejects zero and negative extents
  for both `LineSnapScrollController` and `LineSnapScrollPhysics`.

Tests run on the Flutter test runner because the classes extend Flutter
scroll primitives. No platform channels required.
