# line_snap_scroll_physics Specification

A Flutter package that quantizes scroll offsets to fixed line boundaries
for any `ScrollView`. Exposes a `ScrollController` that rounds every
pixel update during drag, fling, and programmatic scroll, plus a
`ScrollPhysics` that snaps ballistic simulations to the same boundaries.

---

## 1. Problem Statement §spec:lssp-problem-statement

*Status: complete*

Terminal- and console-style views need pixel-aligned lines: every frame
must render whole lines only, never fractional positions. Flutter's
built-in `FixedExtentScrollPhysics` implements the snap-to-item-boundary
ballistics correctly, but is coupled to `FixedExtentScrollController`
and therefore restricted to `ListWheelScrollView`. General-purpose
`ListView`, `CustomScrollView`, and their sliver equivalents have no
supported way to get line-snapping physics. See
[flutter/flutter#41472](https://github.com/flutter/flutter/issues/41472)
(open since 2019, P3) requesting this capability in the framework.

---

## 2. Scope §spec:lssp-scope

*Status: complete*

The package provides scroll primitives only. It does not:

- Render lines or virtualize content — pair with any list view.
- Track active lines, auto-scroll, or handle stream inputs — see
  `fixed_line_view` for that layer.
- Prescribe alignment semantics beyond the snap axis — line alignment
  (top versus bottom of viewport) is fixed to bottom-aligned so
  fractional lines appear at the top (terminal/xterm.js convention).

Pure Flutter. No project-specific code.

---

## 3. Why Not Framework or Community Alternatives §spec:lssp-why-not-alternatives

*Status: complete*

- **`FixedExtentScrollPhysics`** (Flutter framework): implements the
  same snap math but is gated to `FixedExtentScrollController` and
  `ListWheelScrollView`. The targeting logic is not reusable. The
  framework issue flutter/flutter#41472 tracks the gap.
- **`PageScrollPhysics`** (Flutter framework): snaps at viewport
  granularity, not line granularity. Wrong unit.
- **pub.dev**: no general-purpose snap-to-line physics exists at the
  time of extraction.

Extracting the ~40 lines of snap math into a reusable package removes
the framework restriction without blocking on an upstream fix.

---

## 4. API Surface §spec:lssp-api-surface

*Status: complete*

```dart
enum ScrollMode {
  line,   // snap to itemExtent boundaries after every scroll gesture
  pixel,  // platform-default smooth scrolling (no snapping)
}

final class LineSnapScrollController extends ScrollController {
  final double itemExtent;

  LineSnapScrollController({
    required double itemExtent,
    double? initialScrollOffset,
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

## 5. Snap Alignment §spec:lssp-snap-alignment

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

## 6. Mode Switching §spec:lssp-mode-switching

*Status: complete*

`ScrollMode.pixel` disables snap and delegates ballistic simulation to
the parent physics. A consumer that exposes a user-facing toggle between
"snap to line" and "smooth scroll" passes different `mode` values into
the same physics instance.

The controller does not have a mode: if a consumer wants non-snapped
positions, it passes a plain `ScrollController` instead.

---

## 7. Testing Strategy §spec:lssp-testing-strategy

*Status: complete*

Unit tests cover:

- Snap math for positive, zero, and negative offsets at multiple
  item extents and viewport dimensions.
- Bottom-alignment invariant across extent/viewport combinations.
- `ScrollMode.pixel` delegates to parent without mutation.
- `setPixels` quantization holds across drag simulation, fling
  simulation, and `jumpTo`.
- `assert(itemExtent > 0)` fires on zero and negative extents.

Tests run on the Flutter test runner because the classes extend Flutter
scroll primitives. No platform channels required.
