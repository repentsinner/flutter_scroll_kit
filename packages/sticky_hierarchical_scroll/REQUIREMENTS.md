# sticky_hierarchical_scroll Requirements

## Problem statement §req:shs-problem

Tree-shaped content (code outlines, nested G-code structure, folder
trees) loses navigational context once the current section's header
scrolls off the top of the viewport. The reader no longer knows which
function, tool change, or folder they are inside. The view shall pin the
active ancestor chain to the top as an overlay — VS Code's "Sticky
Scroll" — so context stays visible through deep structures.

No equivalent Flutter widget exists. `flutter_sticky_header` (928 likes)
and `sliver_tools` (1450 likes) provide single-level pinned headers only —
neither implements a hierarchical breadcrumb with scope-aware push-out.

## Scope §req:shs-scope

The package shall provide the sticky-header scroll view only. The
consumer shall own:

- Item shape and hierarchy semantics — callbacks extract level, detect
  section starts, and build rows.
- Header widget content — `stickyHeaderBuilder` returns the full widget
  including styling and indentation. The package shall supply only the
  overlay container (configurable `Decoration`).
- Scroll controller — a consumer may pass an external `ScrollController`
  for composition with other widgets observing the same scroll.

The package shall not embed project-specific code. Generic over `T`.
Pure Flutter.

## Behavioral requirements §req:shs-behavior

- The active ancestor chain shall pin as an overlay while its scope is
  on screen; a header shall leave the overlay the moment its scope ends,
  leaving no stale or lingering headers.
- The overlay shall bound to at most `maxStickyHeaders` slots regardless
  of tree depth.
- The bottom-most active header shall receive the last-line push-out
  offset so the overlay shrinks smoothly rather than snapping.
- Trailing content shall stay clear of the scrollbar lane: the reserved
  gutter shall be static and uniform — present in every layout state on
  every platform — so trailing controls neither clip under the thumb nor
  lose taps to the interactive scrollbar.
