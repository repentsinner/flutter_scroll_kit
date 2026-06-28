# Development Roadmap

All four packages are published to pub.dev and their publish automation
is live; the running system is described in SPEC.md. New work enters
here as `##` sections in build-dependency order.

## Close Testing-Strategy coverage gaps

Each package's SPEC `Testing Strategy` section was compressed to
describe only verified behavior. The behaviors below are specified and
implemented but untested; each workstream adds the tests and restores
the fuller coverage claim to that package's SPEC. Ordered by the
dependency graph — base packages first.

- **lssp-snap-invariant-tests**: bottom-alignment invariant on a
  non-divisible viewport (assert `(offset + viewportDimension) %
  itemExtent` lands on a boundary), snap math at negative and zero
  offsets across multiple item extents and viewports, and the
  `assert(itemExtent > 0)` guard firing on zero and negative extents.
- **shs-trailing-key-tests**: trailing-item key stability across
  rebuild (the `findChildIndexCallback` negative-key encoding),
  variable-height binary-search parity against a linear scan over the
  full offset domain, internal-`ScrollController` disposal, the
  `onStickyHeaderTap` navigation callback (fires with `originalIndex`,
  no scroll; no-op when `enableNavigation` is false), and
  `stickyDecoration` application.
- **flv-virtualization-tests**: virtualization bound (only the visible
  window of `lineBuilder` fires for large `lineCount`), `lineSnap`
  quantization under drag/fling/`jumpTo`, the center no-op when the
  line is already centered, and drag-away bottom-follow suppression
  with return-to-bottom resume. Depends on `lssp-snap-invariant-tests`
  for the snap assertions.
- **repl-pinning-tests**: sticky input pinning (an input scrolled above
  the viewport top pins its `entryBuilder` widget at the viewport top),
  the empty-entries render path, and internal-controller disposal.
  Depends on `shs-trailing-key-tests` for the pinning harness.

## Reserve scrollbar gutters across scrolling primitives

The scrolling primitives reserve no space for the scrollbar, so trailing
content and tap targets render under the scroll lane — on desktop the
overlay scrollbar also steals their pointer events. Reported in #31 for
`sticky_hierarchical_scroll`; the gap is repo-wide. Each package's SPEC
gains a `Scrollbar Gutter` section. Ordered by the dependency graph — the
sticky base package first, its consumers next.

- **repl-scrollbar-gutter**: forward the sticky view's gutter through
  `ReplView` to scrollback rows, the pinned input header, and trailing
  slots. **Verify:** a trailing affordance on a pinned input header is
  tappable with the scrollbar shown. Depends on shs-scrollbar-gutter.
