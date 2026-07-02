# repl_view Requirements

## Problem statement §req:repl-problem

Terminal- and REPL-shaped UIs (grblHAL console, Dart DevTools, shell
logs) share a scrollback model: the user submits an input, the system
emits one or more response lines, then the user submits another input.
Two concerns recur:

- **Context preservation.** As the user scrolls up through responses, the
  originating input scrolls off the top. The current input shall pin as a
  sticky header so the user keeps track of which command produced what.
- **Repetition collapse.** A busy status stream floods the scrollback with
  identical lines. Consumers coalesce duplicates upstream into one entry
  with a count (`ok ×47`); the view shall render that count without
  corrupting scroll position.

REPL scrollback is a general pattern, so this behavior belongs in a
reusable primitive rather than any one domain. Decoupling the
coalescing-aware viewport from domain concerns (error enrichment, command
dispatch) keeps consumers thin adapters and domain logic out of the widget
layer.

## Scope §req:repl-scope

The package shall own the REPL scrollback widget and its viewport state
machine. It shall not own:

- **Coalescing.** Duplicate detection and count aggregation happen
  upstream; `repl_view` consumes the already-coalesced stream.
- **Entry shape.** The consumer implements `ConsoleEntry` and supplies an
  `entryBuilder` for both the scroll-list row and the sticky-header
  rendering.
- **Input capture.** Prompt, cursor, keyboard, and command dispatch live
  in the consumer, typically as a trailing item.

Generic over `T extends ConsoleEntry`. Pure Flutter. Depends on
`sticky_hierarchical_scroll`.

## Behavioral requirements §req:repl-behavior

- **Two-level hierarchy.** An input entry shall start a level-0 section;
  following non-input entries shall belong to its scope until the next
  input.
- **Coalescing render.** The widget shall pass `count > 1` entries to
  `entryBuilder` unchanged and shall never dedupe.
- **Read-stability.** While floating (the user has dragged away from the
  bottom), coalescing updates and tail appends shall not shift the
  anchored content under the viewport.
- **Auto-follow.** Stuck-to-bottom shall track the tail. The viewport
  shall force back to stuck when the anchored entry disappears or its
  resolved target lands within one item of the bottom.
- **Gutter forwarding.** `scrollbarGutter` shall forward verbatim to the
  wrapped sticky view, which owns the reservation.
- **Trailing builder.** `trailingItemBuilder` shall be provided when
  `trailingItemCount > 0`.
