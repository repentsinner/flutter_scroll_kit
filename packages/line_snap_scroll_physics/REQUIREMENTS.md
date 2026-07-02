# line_snap_scroll_physics Requirements

## Problem statement §req:lssp-problem

Terminal- and console-style views need pixel-aligned lines: every
rendered frame shall show whole lines, never fractional positions.

No framework or community option covers the general case:

- **`FixedExtentScrollPhysics`** (Flutter) does the same snap math but is
  gated to `FixedExtentScrollController` and `ListWheelScrollView`; the
  targeting logic is not reusable
  ([flutter/flutter#41472](https://github.com/flutter/flutter/issues/41472),
  open since 2019, P3).
- **`PageScrollPhysics`** (Flutter) snaps at viewport granularity, not
  line granularity — wrong unit.
- **pub.dev**: no general-purpose snap-to-line physics.

General-purpose `ListView`, `CustomScrollView`, and their sliver
equivalents therefore have no supported way to get line-snapping physics.

## Scope §req:lssp-scope

The package shall provide scroll primitives only. It shall not:

- Render lines or virtualize content — pair with any list view.
- Track active lines, auto-scroll, or handle stream inputs (see
  `fixed_line_view`).
- Prescribe alignment beyond the snap axis.

Pure Flutter, no project-specific code.

## Behavioral requirements §req:lssp-behavior

- **Bottom-aligned snap.** The snapped offset shall satisfy
  `(offset + viewportDimension) mod itemExtent == 0`, so whole lines pack
  against the bottom and any fractional line appears at the top (terminal
  / xterm.js convention).
- **Per-frame quantization.** The controller shall round every pixel
  update — drag, fling, `jumpTo` — before it reaches paint.
- **Ballistic snap.** The physics shall target line boundaries at the end
  of a ballistic simulation.
- **Mode toggle.** `ScrollMode.pixel` shall disable snapping and delegate
  ballistics to the parent physics.
- **Guard.** A non-positive `itemExtent` shall be rejected
  (`assert(itemExtent > 0)`).
