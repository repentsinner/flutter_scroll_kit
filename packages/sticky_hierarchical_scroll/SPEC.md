# sticky_hierarchical_scroll Specification

A Flutter package that renders a scrollable list of hierarchical items
with a sticky overlay of ancestor section headers — a VS Code–style
breadcrumb that stays visible while the user scrolls through deep
structures.

---

## 1. Problem Statement §spec:shs-problem-statement

*Status: complete*

Tree-shaped content (code outlines, nested G-code structure, folder
trees) loses navigational context once the current section's header
scrolls off the top of the viewport. The reader no longer knows which
function, tool change, or folder they are inside. VS Code solves this
with "Sticky Scroll": the currently-active ancestor chain pins to the
top of the viewport as an overlay.

No equivalent widget exists for Flutter. `flutter_sticky_header`
(928 likes) and `sliver_tools` (1450 likes) provide single-level pinned
headers — neither implements a hierarchical breadcrumb with scope-aware
push-out.

---

## 2. Scope §spec:shs-scope

*Status: complete*

The package provides the sticky-header scroll view only. The consumer
owns:

- Item shape and hierarchy semantics — callbacks extract level, detect
  section starts, and build rows.
- Header widget content — `stickyHeaderBuilder` returns the full widget
  including any styling and indentation. The package supplies only the
  overlay container (configurable `Decoration`).
- Scroll controller — a consumer may pass an external `ScrollController`
  for composition with other widgets that observe the same scroll.

Generic over item type `T`. Pure Flutter. No project-specific code.

---

## 3. Why Slot-Fit §spec:shs-why-slot-fit

*Status: complete*

The rejected alternative was "keep every section whose start has been
scrolled past." In nested hierarchies that approach fails: once both a
parent and a child have scrolled off, both remain in the active set,
and they get pushed out of the viewport simultaneously when their
shared scope ends.

VS Code's `stickyScrollController` uses a **slot-fit test** instead: a
candidate is active iff it fits an assigned pixel slot in the overlay
*and* its scope still covers that slot. The moment a scope ends, the
header leaves the active set cleanly. Incoming headers appear
naturally from the candidate list — no synthetic replacement rendering
is needed, and only one header moves at a time during transitions.

Slot-fit also gives a bounded, predictable overlay: at most
`maxStickyHeaders` slots regardless of tree depth.

---

## 4. Algorithm §spec:shs-algorithm

*Status: complete*

Two phases run at different rates.

**Candidate generation** runs on content change (items list or
hierarchy callback). It walks the items once, builds a
`StickyCandidate<T>` per section header, records each candidate's scope
end index, and precomputes its pixel `startOffset` and
`scopeEndOffset`. For uniform-extent mode, offsets fall back to
`index * itemExtent`; for variable-height mode, a cumulative offset
table is built so lookups are O(log n). O(n) per content change.

**Active set resolution** runs on every scroll tick. It walks the
candidates in depth-first order; for each candidate it computes a slot
position (slot 0 at the overlay top, slot 1 at `slot0 + candidate[0]
itemExtent`, etc.) and keeps the candidate iff its header has scrolled
above its assigned slot *and* its scope end is still at or below that
slot's top. The walk stops at `maxStickyHeaders`. The result is small
(≤ max) and sorted by depth.

**Last-line offset**: the bottom-most active header receives a negative
pixel offset when its scope end approaches the slot bottom. The offset
equals `scopeEndViewport − slotBottom` when `slotBottom >
scopeEndViewport`, else zero. All other slots stay at fixed positions.
The overlay height equals the sum of active slot heights plus this
offset, so the overlay shrinks smoothly as the last header is pushed
out rather than holding fixed height and snapping.

---

## 5. Height Modes §spec:shs-height-modes

*Status: complete*

**Uniform mode** (default constructor): all rows share `itemExtent`.
`ListView.itemExtent` drives layout. Position lookups are arithmetic.

**Variable-height mode** (`.variableHeight` constructor): each item's
height comes from an `itemHeight` callback. A cumulative offset table
is precomputed and Flutter's `ListView.itemExtentBuilder` supplies the
per-index extent so the underlying sliver does not measure children.
Position lookups are O(log n) via binary search.

Both modes use the same `StickyCandidate` shape. The uniform
construction defaults `startOffset`/`scopeEndOffset` to null and the
candidate's accessors fall back to arithmetic; the variable
construction fills both.

---

## 6. Overlay Composition §spec:shs-overlay-composition

*Status: complete*

Sticky headers render as an overlay stacked above the list (via a
`Stack`), not a column above it. A column would paint the transitioning
header twice during the handoff frame. The overlay hides the row behind
it on entry — no duplicate.

The overlay's decoration is `StickyScrollConfig.stickyDecoration`
(defaults to VS Code's dark background). Consumers styling against a
different theme pass their own decoration.

---

## 7. Navigation §spec:shs-navigation

*Status: complete*

Tapping a sticky header is optional. When `StickyScrollConfig
.enableNavigation` is true and `onStickyHeaderTap` is supplied, it
fires with the tapped candidate's `originalIndex` and the package
leaves the scroll position alone — the consumer decides what "navigate"
means (scroll, open a pane, highlight). With navigation enabled and no
callback, the package falls back to animating the scroll to the tapped
section.

---

## 8. Trailing Items §spec:shs-trailing-items

*Status: complete*

`trailingItemCount` plus `trailingItemBuilder` append rows after the
hierarchical items. Trailing rows scroll with the list but never become
sticky. Use them for inline input, footers, or "load more" rows at the
bottom of the stream.

---

## 9. API Surface §spec:shs-api-surface

*Status: complete*

```dart
final class StickyCandidate<T> {
  final int level;
  final T data;
  final int originalIndex;
  final int endIndex;
  final double itemExtent;
  final double? startOffset;
  final double? scopeEndOffset;
}

final class StickyScrollConfig<T> {
  final int maxStickyHeaders;          // default 5
  final bool enableNavigation;          // default true
  final Decoration stickyDecoration;
  final Widget Function(BuildContext, StickyCandidate<T>) stickyHeaderBuilder;
}

class StickyHierarchicalScrollView<T> extends StatefulWidget {
  // Uniform-height constructor
  const StickyHierarchicalScrollView({
    required List<T> items,
    required int Function(T) getLevel,
    required bool Function(T) isSection,
    required Widget Function(BuildContext, T, int) itemBuilder,
    required double itemExtent,
    required StickyScrollConfig<T> config,
    ScrollController? controller,
    ScrollPhysics? physics,
    void Function(int)? onStickyHeaderTap,
    int trailingItemCount,
    Widget Function(BuildContext, int)? trailingItemBuilder,
    double? scrollbarGutter,   // null → auto from theme; 0 → disabled
  });

  // Variable-height constructor
  const StickyHierarchicalScrollView.variableHeight({
    ...,
    required double Function(T) itemHeight,
    double? scrollbarGutter,
    ...,
  });
}
```

`scrollbarGutter` governs the trailing reservation in §spec:shs-scrollbar-gutter.

---

## 10. Scrollbar Gutter §spec:shs-scrollbar-gutter

*Status: complete*

Implements §req:problem-statement: the primitive owns its own correct
layout so consumers don't re-pad to keep trailing content out of the
scroll lane.

The view reserves a trailing gutter on the scrollbar edge. Both the
scrolling rows and the sticky-header overlay are inset by the gutter, so
a trailing affordance stays clear of the lane in scrolling rows and
pinned headers alike. Without it the overlay scrollbar paints over the
trailing edge — trailing text is clipped under the thumb and, on
desktop, the interactive scrollbar intercepts pointer events so a
trailing `IconButton` there cannot be tapped. Reported in #31.

`scrollbarGutter` (`double?`) sets the width: `null` (default)
auto-derives from the effective `ScrollbarThemeData.thickness`, with the
Material default as fallback; `0` disables the gutter for full-bleed
content; a positive value reserves exactly that width.

The gutter is **static and uniform** — reserved in every layout state on
every platform, independent of whether the thumb is painted:

- *Static, not visibility-gated.* The Material `Scrollbar` is transient
  (iOS, Android, macOS). Reserving only while the thumb shows reflows
  content on every fade. Static reservation stays stable.
- *Uniform, not platform-gated.* The thumb occludes the lane wherever it
  appears; desktop adds pointer interception on top. One reservation
  covers both.

Auto-deriving from the theme thickness (the same source the wrapping
`Scrollbar` renders from) keeps the reservation tracking the configured
scrollbar width rather than a guessed constant.

Alternatives rejected:

- **Per-consumer padding** (the issue's ~12px workaround): every caller
  repeats it across rows and the overlay, and it drifts from the real
  scrollbar width. Correctness belongs in the primitive.
- **An `EdgeInsets` knob:** only the trailing inset matters; a full-edge
  knob duplicates `ListView.padding` and invites misuse. One `double?`
  is enough.

Tradeoff accepted: every consumer loses the gutter width of horizontal
space, including platforms where the scrollbar never intercepts input.
Full-bleed consumers opt out with `scrollbarGutter: 0`. Pre-1.0 the
layout change to existing consumers is acceptable.

---

## 11. Testing Strategy §spec:shs-testing-strategy

*Status: complete*

Unit tests cover:

- Candidate generation: level extraction, section detection, scope end
  indices, cumulative offsets in both height modes.
- Slot-fit filtering: a candidate enters the active set when its
  header passes above its slot and leaves when its scope ends; nested
  parents transition without lingering, including the stale-header
  regression after a scope ends.
- Last-line offset: overlay height shrinks smoothly as a scope ends,
  never negative.
- Binary-search activation: the strict-less-than boundary returns the
  correct active subset across scroll positions.
- Binary-search parity: in variable-height mode the binary search over
  candidate `startPosition` equals a linear scan for every threshold
  swept across the full offset domain, including each candidate
  boundary.
- An external `ScrollController` drives the overlay.
- Controller ownership: the internal controller is created and disposed
  without error; an external controller is never disposed by the widget
  and stays usable after the widget unmounts.
- Navigation callback: with `enableNavigation` true, tapping a pinned
  header fires `onStickyHeaderTap` with the candidate's `originalIndex`
  and leaves the scroll offset unchanged; with `enableNavigation` false
  the tap is a no-op.
- Trailing-item key stability: prepending a data item shifts trailing
  indices yet a trailing widget retains its element identity (a focused
  `TextField` keeps focus) via the negative-key `findChildIndexCallback`.
- Decoration: the pinned header renders inside a `DecoratedBox` carrying
  the configured `stickyDecoration`.

Tests run on the Flutter widget test runner.
