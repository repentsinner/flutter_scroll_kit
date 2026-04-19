# sticky_hierarchical_scroll Specification

A Flutter package that renders a scrollable list of hierarchical items
with a sticky overlay of ancestor section headers — a VS Code–style
breadcrumb that stays visible while the user scrolls through deep
structures.

---

## 1. Problem Statement

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

## 2. Scope

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

## 3. Why Slot-Fit

*Status: complete*

The rejected alternative was "keep every section whose start has been
scrolled past." In nested hierarchies that approach fails: once both a
parent and a child have scrolled off, both remain in the active set,
and they get pushed out of the viewport simultaneously when their
shared scope ends. Stale headers linger after their scope closes.

VS Code's `stickyScrollController` uses a **slot-fit test** instead: a
candidate is active iff it fits an assigned pixel slot in the overlay
*and* its scope still covers that slot. The moment a scope ends, the
header leaves the active set cleanly. Incoming headers appear
naturally from the candidate list — no synthetic replacement rendering
is needed, and only one header moves at a time during transitions.

Slot-fit also gives a bounded, predictable overlay: at most
`maxStickyHeaders` slots regardless of tree depth.

---

## 4. Algorithm

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
above its assigned slot *and* its scope end is still below that slot's
bottom. The walk stops at `maxStickyHeaders`. The result is small
(≤ max) and sorted by depth.

**Last-line offset**: the bottom-most active header receives a negative
pixel offset when its scope end approaches the slot bottom. The offset
equals `scopeEndViewport − slotBottom` when `slotBottom >
scopeEndViewport`, else zero. All other slots stay at fixed positions.
The overlay height equals the sum of active slot heights plus this
offset, so the overlay shrinks smoothly as the last header is pushed
out rather than holding fixed height and snapping.

---

## 5. Height Modes

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

## 6. Overlay Composition

*Status: complete*

Sticky headers render as an overlay stacked above the list (via a
`Stack`), not a column above it. The column approach causes a
doubled-header artifact as a header transitions from scrolling to
sticky — it would be painted twice during the handoff frame. The
overlay approach hides the row behind the overlay when it enters its
slot, so there is no duplicate.

The overlay's decoration is `StickyScrollConfig.stickyDecoration`
(defaults to VS Code's dark background). Consumers styling against a
different theme pass their own decoration.

---

## 7. Navigation

*Status: complete*

Tapping a sticky header is optional. When `StickyScrollConfig
.enableNavigation` is true, `onStickyHeaderTap(index)` fires with the
tapped candidate's `originalIndex`. The consumer decides what
"navigate" means (scroll, open a pane, highlight). The package does
not animate or jump the scroll position itself.

---

## 8. Trailing Items

*Status: complete*

`trailingItemCount` plus `trailingItemBuilder` append rows after the
hierarchical items. Trailing rows scroll with the list but are not
candidates — they never become sticky. This exists for inline input
areas, footers, or "load more" rows that belong at the bottom of the
stream.

---

## 9. API Surface

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
  });

  // Variable-height constructor
  const StickyHierarchicalScrollView.variableHeight({
    ...,
    required double Function(T) itemHeight,
    ...,
  });
}
```

---

## 10. Testing Strategy

*Status: complete*

Unit tests cover:

- Candidate generation: level extraction, section detection, scope end
  indices, cumulative offsets in both height modes.
- Slot-fit filtering: a candidate enters the active set when its
  header passes above its slot and leaves when its scope ends; nested
  parents transition without lingering.
- Last-line offset: overlay height shrinks smoothly as a scope ends,
  never negative.
- External vs internal `ScrollController`: widget disposes only
  the controller it created.
- Variable-height position lookup: binary search returns the same
  index as linear scan for every offset in the domain.

Tests run on the Flutter widget test runner.
