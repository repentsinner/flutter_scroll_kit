# repl_view Specification

A Flutter package that renders a REPL-style scrollback: a flat list of
interleaved input lines and response lines, where input lines pin as
sticky section headers over the responses they produced.

---

## 1. Problem Statement

*Status: complete*

Terminal- and REPL-shaped UIs (grblHAL console, Dart DevTools, shell
logs) share a scrollback model: the user submitted an input, the
system emitted one or more response lines, then the user submitted
another input. Two generic concerns recur across every implementation:

- **Context preservation**: as the user scrolls up through responses,
  the originating input scrolls off the top and the user loses track
  of which command produced what. The fix is to pin the current input
  as a sticky header.
- **Repetition collapse**: a busy status stream (grblHAL `?` status
  replies, loop output) floods the scrollback with identical lines.
  Consumers coalesce duplicates upstream into one entry with a count
  (`ok ×47`), but the view has to render that count without corrupting
  scroll position.

The `sticky_hierarchical_scroll` package supplies the pinning
primitive; `repl_view` specializes it to the two-level input/response
hierarchy that REPLs actually have, and adds the scroll-anchoring
behavior needed for coalesced updates.

---

## 2. Scope

*Status: complete*

The package owns the REPL scrollback widget and its viewport state
machine. It does not own:

- Coalescing. Duplicate detection and count aggregation happen
  upstream in the consumer's data source; `repl_view` consumes the
  already-coalesced stream. `ConsoleEntry.count > 1` arrives as
  such; the builder decides how to render the count badge.
- Entry shape. The consumer implements `ConsoleEntry` on its own type
  and supplies an `entryBuilder` that produces both the scroll-list
  row and the sticky-header representation of that row.
- Input capture. Prompt lines, cursor, keyboard handling, and command
  dispatch live in the consumer, typically as a trailing item.

Generic over `T extends ConsoleEntry`. Pure Flutter. Depends on
`sticky_hierarchical_scroll`.

---

## 3. Why Extract

*Status: complete*

REPL scrollback is a general pattern: any terminal-style UI
(CNC console, network debugger, game-engine REPL, database shell)
benefits from sticky input headers and coalesced-response rendering.
Decoupling the scroll and coalescing-aware viewport from CNC-specific
error enrichment and command dispatch lets the pattern be reused —
and keeps domain logic out of the widget layer.

Consumers become thin adapters: the domain's message type implements
`ConsoleEntry`, a message service feeds the entry list, and domain
concerns (error classification, retry, formatting) live above the
widget.

---

## 4. Entry Contract

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

`identity` is the scroll anchor (§5). Consumers typically use a
monotonic integer assigned when the message is created and preserved
across coalescing updates.

`coalescingKey` is exposed on the interface for consumer consistency;
the widget does not inspect it. Coalescing already happened upstream.

---

## 5. Viewport State Machine

*Status: complete*

Two states, three transitions.

**Stuck to bottom** (initial, default). The viewport tracks the tail.
Coalescing updates, tail appends, parent rebuilds, and
detach/reattach all settle back to `maxScrollExtent`. This is the
state a log viewer spends most of its time in.

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
- floating → stuck (forced): the anchor entry disappears from the
  scrollback (ring-buffer trim, clear-screen). Without a valid
  anchor the widget snaps back to the bottom rather than freeze on
  a stale pixel offset.

The state machine protects against the most common failure mode:
coalescing the most recent line (e.g. "ok ×47 → ok ×48") while the
user is reading scrollback. Without anchoring, the viewport jumps
with every update.

---

## 6. Layering

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

## 7. API Surface

*Status: complete*

```dart
abstract class ConsoleEntry { ... }  // see §4

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
  });
}
```

`trailingItemBuilder` is required when `trailingItemCount > 0` —
enforced by assertion.

---

## 8. Testing Strategy

*Status: complete*

Unit tests cover:

- Hierarchy: input entries become level-0 sections, non-input
  entries become their leaves; scopes close at the next input.
- Sticky behavior: when a section's input scrolls above the
  viewport top, its `entryBuilder` widget pins; the sticky
  representation is the same widget the list row uses.
- Coalescing render: `count > 1` entries are passed to
  `entryBuilder` unchanged; the widget never dedupes.
- Viewport state machine:
  - Stuck at bottom after mount; stays stuck through tail appends
    and coalescing updates.
  - Drag up → float; the anchored entry stays under the same
    viewport pixels across subsequent updates.
  - Drag back to bottom → stuck.
  - Anchor entry removed → snap to bottom, re-enter stuck.
- Trailing items: rows appended after `entries` scroll with the
  content and do not pin.

Tests run on the Flutter widget test runner.
