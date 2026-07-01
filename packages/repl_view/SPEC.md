# repl_view Specification

A Flutter package that renders a REPL-style scrollback: a flat list of
interleaved input lines and response lines, where input lines pin as
sticky section headers over the responses they produced.

Implements §req:repl-problem, §req:repl-scope, and §req:repl-behavior.

---

## 1. Entry Contract §spec:repl-entry-contract

*Status: complete*

```dart
abstract class ConsoleEntry {
  String get value;            // display text
  bool get isInput;            // true → sticky section header; false → leaf
  String get coalescingKey;    // consumer-owned grouping key (informational)
  int get count;               // 1 = single occurrence; >1 = badge
  Object get identity;         // stable identity across coalescing updates
}
```

`isInput` selects the two-level hierarchy: an input entry starts a new
section at level 0 and all following non-input entries belong to its
scope until the next input arrives.

`identity` is the scroll anchor (§2). Consumers typically use a
monotonic integer assigned when the message is created and preserved
across coalescing updates.

`coalescingKey` is exposed on the interface for consumer consistency;
the widget does not inspect it. Coalescing already happened upstream.

---

## 2. Viewport State Machine §spec:repl-viewport-state

*Status: complete*

Two states, three transitions.

**Stuck to bottom** (initial, default). The viewport tracks the tail.
Coalescing updates, tail appends, parent rebuilds, and
detach/reattach all settle back to `maxScrollExtent`.

**Floating**. When the user drags away from the bottom, the viewport
freezes on a `_FloatingAnchor`: an entry `identity` plus a pixel
offset within that entry's row. On subsequent content changes the
viewport scrolls so the anchored content stays under the same
viewport pixels. Coalescing and tail appends therefore do not shift
what the user is reading.

Transitions:

- stuck → floating: user drags upward, scroll offset falls below
  `maxScrollExtent`.
- floating → stuck: user drags back to `maxScrollExtent`.
- floating → stuck (forced): the anchored content returns to the
  bottom. Either the anchor entry disappears from the scrollback
  (ring-buffer trim, clear-screen), or its resolved target lands
  within one item of `maxScrollExtent` (a tail trim shrank the list
  beneath it). In both cases the widget snaps to the tail and resumes
  following it, rather than freeze on a stale, now sub-bottom pixel
  offset that would stall auto-follow.

Anchoring targets one failure mode: coalescing the most recent line
while the user reads scrollback would otherwise jump the viewport on
every update.

---

## 3. Layering §spec:repl-layering

*Status: complete*

`repl_view` composes `StickyHierarchicalScrollView` with:

- Hierarchy callbacks wired to `ConsoleEntry.isInput`
  (input → level 0, response → level 1).
- `maxStickyHeaders` defaulting to 1 — REPL convention is one input
  pinned at a time; the consumer can raise the ceiling for nested
  subcommand transcripts.
- Trailing items (prompt line, status bar, live output) passed
  through to the sticky view's trailing-item slots.

The consumer owns the sticky header's visual (styling, count badge,
tap handlers) — `entryBuilder` is used for both list rows and
sticky-header rendering, so a single builder covers both.

---

## 4. API Surface §spec:repl-api-surface

*Status: complete*

```dart
abstract class ConsoleEntry { ... }  // see §1

class ReplView<T extends ConsoleEntry> extends StatefulWidget {
  const ReplView({
    required List<T> entries,
    required Widget Function(BuildContext, T) entryBuilder,
    required double itemExtent,
    int maxStickyHeaders = 1,
    Decoration? stickyDecoration,
    ScrollController? controller,
    ScrollPhysics? physics,
    int trailingItemCount = 0,
    Widget Function(BuildContext, int)? trailingItemBuilder,
    double? scrollbarGutter,   // forwarded to StickyHierarchicalScrollView
  });
}
```

`trailingItemBuilder` is required when `trailingItemCount > 0` —
enforced by assertion.

---

## 5. Scrollbar Gutter §spec:repl-scrollbar-gutter

*Status: complete*

`ReplView` exposes `scrollbarGutter` (`double?`) and forwards it verbatim
to the wrapped `StickyHierarchicalScrollView` (§spec:shs-scrollbar-gutter),
which owns the contract and the reservation.

Why forward rather than re-implement: `repl_view` owns no scrollbar or
list of its own — it composes the sticky view, which already reserves the
gutter for both scrollback rows and the pinned sticky input header
(`entryBuilder` renders both). Re-padding rows here would double the inset
and still miss the pinned header.

Why it matters: a pinned input header's trailing controls would
otherwise collide with the scrollbar.

---

## 6. Testing Strategy §spec:repl-testing-strategy

*Status: complete*

Unit tests cover:

- Hierarchy: input entries become level-0 sections, non-input
  entries become their leaves.
- Coalescing render: `count > 1` entries are passed to
  `entryBuilder` unchanged; the widget never dedupes.
- Viewport state machine:
  - Stuck at bottom after mount; stays stuck through tail appends
    and coalescing updates.
  - Drag up → float; the anchored entry stays under the same
    viewport pixels across coalescing and tail-append updates.
  - Drag back to bottom → stuck.
  - Anchor entry removed → snap to bottom, re-enter stuck.
- Trailing rows render after `entries`.
- Sticky input pinning: an input scrolled above the viewport top pins
  its `entryBuilder` widget at the viewport top via the sticky overlay.
- Empty-entries render path: an empty `entries` list builds the sticky
  view without error, including via the internal controller.
- Controller disposal: the internal controller is disposed on unmount;
  a consumer-supplied controller is not. Swapping from internal to
  external releases the internal controller.

Tests run on the Flutter widget test runner.
