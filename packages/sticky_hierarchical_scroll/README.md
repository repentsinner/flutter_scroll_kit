# sticky_hierarchical_scroll

VS Code-style sticky headers for hierarchical Flutter lists.

Section headers stick to the top of the viewport as the user scrolls,
maintaining a breadcrumb trail of the current position in the hierarchy.
When a section ends, its header pushes out smoothly — matching VS Code's
tree Sticky Scroll behavior.

## Features

- **Hierarchical sticky headers** — nested sections stack in depth order
- **Push-out animation** — outgoing headers slide up as their scope ends
- **Click-to-navigate** — tap a sticky header to scroll to that section
- **Fixed-height rows** — optimized for uniform item extents
- **Configurable depth** — limit the maximum number of sticky headers

## Usage

```dart
StickyHierarchicalScrollView<MyItem>(
  items: items,
  getLevel: (item) => item.level,
  isSection: (item) => item.isSection,
  itemExtent: 32.0,
  config: StickyScrollConfig<MyItem>(
    maxStickyHeaders: 3,
    stickyDecoration: BoxDecoration(color: Colors.grey[900]),
    stickyHeaderBuilder: (context, candidate) {
      return Text(candidate.data.label);
    },
  ),
  itemBuilder: (context, item, index) {
    return Text(item.label);
  },
)
```

### Parameters

| Parameter | Description |
|---|---|
| `items` | Flat list of all items (sections and leaves) |
| `getLevel` | Returns the hierarchical depth (0-based) of an item |
| `isSection` | Returns `true` for items that should stick |
| `itemExtent` | Fixed pixel height of every row |
| `config` | Sticky behavior configuration (see below) |
| `controller` | Optional external `ScrollController` |
| `physics` | Scroll physics (default: platform default) |
| `onStickyHeaderTap` | Custom tap handler (overrides default scroll-to) |

### StickyScrollConfig

| Property | Default | Description |
|---|---|---|
| `stickyHeaderBuilder` | required | Builds the widget for each sticky header |
| `maxStickyHeaders` | `5` | Maximum headers shown simultaneously |
| `enableNavigation` | `true` | Tap headers to scroll to that section |
| `stickyDecoration` | `BoxDecoration(color: #1E1E1E)` | Decoration for each sticky header (supports gradients, borders, shadows) |

### StickyCandidate

The `stickyHeaderBuilder` receives a `StickyCandidate<T>` with:

- `data` — the original item of type `T`
- `level` — hierarchical depth
- `originalIndex` — position in the flat item list

## Example

See the [example app](example/) for a complete file-tree demo.

```sh
cd example
flutter run
```
