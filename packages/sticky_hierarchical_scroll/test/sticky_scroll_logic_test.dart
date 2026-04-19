import 'package:flutter_test/flutter_test.dart';
import 'package:sticky_hierarchical_scroll/src/sticky_candidate.dart';

/// Helper to build candidates for a simple hierarchy.
///
/// Given items like:
///   [Section A (level 0), item, item, Section B (level 1), item, Section C (level 0)]
/// Produces candidates with correct scope endIndex values.
List<StickyCandidate<String>> buildCandidates(
  List<({String name, int level, bool isSection})> items, {
  double itemExtent = 20.0,
}) {
  final candidates = <StickyCandidate<String>>[];
  final itemCount = items.length;

  for (int i = 0; i < itemCount; i++) {
    final item = items[i];
    if (!item.isSection) continue;

    int endIndex = itemCount - 1;
    for (int j = i + 1; j < itemCount; j++) {
      if (items[j].isSection && items[j].level <= item.level) {
        endIndex = j - 1;
        break;
      }
    }

    candidates.add(
      StickyCandidate<String>(
        level: item.level,
        data: item.name,
        originalIndex: i,
        endIndex: endIndex,
        itemExtent: itemExtent,
      ),
    );
  }
  return candidates;
}

/// Binary search: find all candidates whose startPosition < scrollTop.
///
/// Uses strict less-than to match the widget's `_getCandidatesIntersecting`.
/// A section at exactly the scroll threshold (e.g. scrollTop == 0 and
/// startPosition == 0) is NOT included — prevents sticky headers at idle.
List<StickyCandidate<String>> getCandidatesIntersecting(
  List<StickyCandidate<String>> candidates,
  double scrollTop,
) {
  if (candidates.isEmpty) return [];

  int left = 0;
  int right = candidates.length - 1;

  while (left <= right) {
    final mid = (left + right) ~/ 2;
    if (candidates[mid].startPosition < scrollTop) {
      left = mid + 1;
    } else {
      right = mid - 1;
    }
  }

  if (right < 0) return [];
  return candidates.sublist(0, right + 1);
}

/// Build context stack from intersecting candidates.
Map<int, StickyCandidate<String>> buildContextStack(
  List<StickyCandidate<String>> intersecting,
) {
  final contextStack = <int, StickyCandidate<String>>{};
  for (final candidate in intersecting) {
    contextStack[candidate.level] = candidate;
    contextStack.removeWhere((level, _) => level > candidate.level);
  }
  return contextStack;
}

void main() {
  // Hierarchy used across tests:
  //  0: Section A   (level 0)     <- section
  //  1:   item a1
  //  2:   item a2
  //  3:   Sub-section B (level 1) <- section
  //  4:     item b1
  //  5:     item b2
  //  6: Section C   (level 0)     <- section
  //  7:   item c1
  final items = [
    (name: 'Section A', level: 0, isSection: true),
    (name: 'item a1', level: 1, isSection: false),
    (name: 'item a2', level: 1, isSection: false),
    (name: 'Sub-section B', level: 1, isSection: true),
    (name: 'item b1', level: 2, isSection: false),
    (name: 'item b2', level: 2, isSection: false),
    (name: 'Section C', level: 0, isSection: true),
    (name: 'item c1', level: 1, isSection: false),
  ];

  group('Scope computation', () {
    test('Section A scope ends before Section C', () {
      final candidates = buildCandidates(items);
      // Section A (index 0): scope ends at index 5 (before Section C at 6).
      expect(candidates[0].originalIndex, 0);
      expect(candidates[0].endIndex, 5);
    });

    test('Sub-section B scope ends before Section C', () {
      final candidates = buildCandidates(items);
      // Sub-section B (index 3): scope ends at index 5.
      expect(candidates[1].originalIndex, 3);
      expect(candidates[1].endIndex, 5);
    });

    test('Last section scope extends to end of list', () {
      final candidates = buildCandidates(items);
      // Section C (index 6): scope extends to last item (index 7).
      expect(candidates[2].originalIndex, 6);
      expect(candidates[2].endIndex, 7);
    });
  });

  group('Binary search', () {
    test('scrollTop 0 returns empty (strict less-than)', () {
      final candidates = buildCandidates(items);
      // Section A starts at position 0. With strict <, 0 < 0 is false.
      final result = getCandidatesIntersecting(candidates, 0.0);
      expect(result, isEmpty);
    });

    test('scrollTop just past 0 finds first candidate', () {
      final candidates = buildCandidates(items);
      final result = getCandidatesIntersecting(candidates, 1.0);
      expect(result.length, 1);
      expect(result[0].data, 'Section A');
    });

    test('scrollTop before any candidate returns empty', () {
      // If the first candidate starts at index 2 (position 40), scrollTop
      // 10 should find nothing.
      final shiftedItems = [
        (name: 'item 0', level: 0, isSection: false),
        (name: 'item 1', level: 0, isSection: false),
        (name: 'Section', level: 0, isSection: true),
        (name: 'item 3', level: 1, isSection: false),
      ];
      final candidates = buildCandidates(shiftedItems);
      final result = getCandidatesIntersecting(candidates, 10.0);
      expect(result, isEmpty);
    });

    test('scrollTop at Sub-section B finds only A (strict less-than)', () {
      final candidates = buildCandidates(items);
      // Sub-section B starts at index 3 -> position 60.
      // With strict <, 60 < 60 is false, so B is excluded.
      final result = getCandidatesIntersecting(candidates, 60.0);
      expect(result.length, 1);
      expect(result[0].data, 'Section A');
    });

    test('scrollTop just past Sub-section B finds A and B', () {
      final candidates = buildCandidates(items);
      final result = getCandidatesIntersecting(candidates, 61.0);
      expect(result.length, 2);
      expect(result[0].data, 'Section A');
      expect(result[1].data, 'Sub-section B');
    });

    test('scrollTop at Section C finds A and B (strict less-than)', () {
      final candidates = buildCandidates(items);
      // Section C starts at index 6 -> position 120.
      // With strict <, 120 < 120 is false, so C is excluded.
      final result = getCandidatesIntersecting(candidates, 120.0);
      expect(result.length, 2);
    });

    test('scrollTop past Section C finds all three', () {
      final candidates = buildCandidates(items);
      final result = getCandidatesIntersecting(candidates, 121.0);
      expect(result.length, 3);
    });

    test('scrollTop between candidates returns correct subset', () {
      final candidates = buildCandidates(items);
      // scrollTop 50 is between A (0) and B (60). Only A qualifies.
      final result = getCandidatesIntersecting(candidates, 50.0);
      expect(result.length, 1);
      expect(result[0].data, 'Section A');
    });
  });

  group('Context stack', () {
    test('single section produces single-entry stack', () {
      final candidates = buildCandidates(items);
      // scrollTop 1 (just past Section A at 0).
      final intersecting = getCandidatesIntersecting(candidates, 1.0);
      final stack = buildContextStack(intersecting);
      expect(stack.length, 1);
      expect(stack[0]!.data, 'Section A');
    });

    test('nested section keeps parent in stack', () {
      final candidates = buildCandidates(items);
      // At scrollTop 61, both A (level 0) and B (level 1) are intersecting.
      final intersecting = getCandidatesIntersecting(candidates, 61.0);
      final stack = buildContextStack(intersecting);
      expect(stack.length, 2);
      expect(stack[0]!.data, 'Section A');
      expect(stack[1]!.data, 'Sub-section B');
    });

    test('same-level section replaces previous and clears deeper', () {
      final candidates = buildCandidates(items);
      // At scrollTop 121, all three candidates are intersecting.
      // Processing: A(0) -> B(1) -> C(0).
      // C replaces A at level 0 and clears level 1 (B).
      final intersecting = getCandidatesIntersecting(candidates, 121.0);
      final stack = buildContextStack(intersecting);
      expect(stack.length, 1);
      expect(stack[0]!.data, 'Section C');
    });
  });

  group('Push-out math', () {
    test('push-out offset when scope end enters sticky area', () {
      final candidates = buildCandidates(items);
      // Section A: scope end at (5 + 1) * 20 = 120.
      // Sticky area height = 1 header * 20 = 20.
      // At scrollTop 110: relativeEnd = 120 - 110 = 10.
      // 10 < 20, so pushOut = 10 - 20 = -10.
      final sectionA = candidates[0];
      const scrollTop = 110.0;
      const stickyAreaHeight = 20.0;
      final relativeEnd = sectionA.scopeEndPosition - scrollTop;
      expect(relativeEnd, 10.0);

      final pushOut = relativeEnd - stickyAreaHeight;
      expect(pushOut, -10.0);
    });

    test('no push-out when scope end is below sticky area', () {
      final candidates = buildCandidates(items);
      final sectionA = candidates[0];
      // At scrollTop 0: relativeEnd = 120 - 0 = 120. 120 >= 20. No push.
      const scrollTop = 0.0;
      const stickyAreaHeight = 20.0;
      final relativeEnd = sectionA.scopeEndPosition - scrollTop;
      expect(relativeEnd >= stickyAreaHeight, isTrue);
    });
  });
}
