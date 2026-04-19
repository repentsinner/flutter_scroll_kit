# repl_view

Generic REPL-style scroll view for Flutter.

Input lines pin as sticky section headers; response lines scroll as
leaves within each section. Repeated identical responses coalesce
with a count badge (e.g. "ok x47" instead of 47 identical lines) when
the consumer's data source supplies a pre-coalesced entry with
`count > 1`.

Built on [`sticky_hierarchical_scroll`](../sticky_hierarchical_scroll/).

## Usage

```dart
class MyEntry implements ConsoleEntry {
  @override
  final String value;
  @override
  final bool isInput;
  @override
  final String coalescingKey;
  @override
  final int count;
  @override
  final Object identity;

  MyEntry({
    required this.value,
    required this.isInput,
    required this.coalescingKey,
    required this.identity,
    this.count = 1,
  });
}

ReplView<MyEntry>(
  entries: entries,
  itemExtent: 16.0,
  entryBuilder: (context, entry) {
    return Row(
      children: [
        if (entry.count > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.all(Radius.circular(7)),
            ),
            child: Text('${entry.count}'),
          ),
        Expanded(child: Text(entry.value, overflow: TextOverflow.ellipsis)),
      ],
    );
  },
);
```

## Interface

| Member | Description |
|---|---|
| `ConsoleEntry.value` | Display text |
| `ConsoleEntry.isInput` | `true` pins the row as a sticky section header |
| `ConsoleEntry.coalescingKey` | Consumer-owned grouping key (informational) |
| `ConsoleEntry.count` | Number of coalesced occurrences; the row builder renders a badge when > 1 |
| `ConsoleEntry.identity` | Stable identity used as the scroll anchor across coalescing and list rebuilds. Typically a monotonic `int` assigned when the message is created and preserved across coalescing updates. |

## Features

- **Sticky input headers** — input entries pin at the top of their
  response scope (VS Code terminal style).
- **Coalescing display** — consumer-supplied `count > 1` on an entry
  lets the `entryBuilder` render a count badge, keeping the
  scrollback compact.
- **Identity-anchored viewport** — two observable states:
  - **Stuck to bottom** (default): new entries, coalescing updates,
    parent rebuilds, and tab detach/reattach all resettle to the
    bottom.
  - **Floating**: when the user drags away from the bottom, the
    viewport pins to a specific entry by `identity` plus a pixel
    offset within it. Tail appends and coalescing leave the pinned
    content unchanged. When the anchor entry is trimmed from the
    consumer's scrollback, the view snaps back to the bottom and
    returns to stuck.
- **Trailing items** — optional prompt line, separators, or status
  text scroll with the content rather than pinning as a footer.

## Parameters

| Parameter | Description |
|---|---|
| `entries` | Flat list of entries (inputs and responses in display order) |
| `entryBuilder` | Builds a single row; used for both scroll items and sticky headers |
| `itemExtent` | Fixed pixel height of every row |
| `maxStickyHeaders` | Maximum stacked sticky headers (default 1) |
| `stickyDecoration` | Decoration behind each sticky header |
| `controller` | Optional external `ScrollController` |
| `physics` | Scroll physics (default: platform default) |
| `trailingItemCount` | Number of footer rows appended after entries |
| `trailingItemBuilder` | Builds footer rows (prompt line, status, etc.) |

## Design

Coalescing happens upstream in the consumer's data source. The widget
reads the supplied `count` and hands the entry to `entryBuilder`
— it does not dedupe entries. This keeps the package agnostic to
the consumer's equivalence relation (exact string match, regex
canonicalisation, session-scoped key, etc.).

Input entries render as level-0 sticky sections; responses render
as level-1 leaves. Depth is fixed at 2 — the REPL model has one
level of nesting (input -> its responses), unlike the general
`sticky_hierarchical_scroll` which supports arbitrary depth.
