import 'package:flutter_test/flutter_test.dart';
import 'package:sticky_hierarchical_scroll/src/sticky_candidate.dart';

void main() {
  group('StickyCandidate', () {
    test('startPosition is originalIndex * itemExtent', () {
      final candidate = StickyCandidate<String>(
        level: 0,
        data: 'Section A',
        originalIndex: 3,
        endIndex: 7,
        itemExtent: 20.0,
      );

      expect(candidate.startPosition, 60.0); // 3 * 20
    });

    test('startPosition with non-default itemExtent', () {
      final candidate = StickyCandidate<String>(
        level: 0,
        data: 'Section A',
        originalIndex: 5,
        endIndex: 10,
        itemExtent: 32.0,
      );

      expect(candidate.startPosition, 160.0); // 5 * 32
    });

    test('scopeEndPosition uses (endIndex + 1) * itemExtent', () {
      // Bug fix: endIndex is the index of the last item in scope.
      // Its bottom edge is at (endIndex + 1) * itemExtent, not
      // endIndex * itemExtent.
      final candidate = StickyCandidate<String>(
        level: 0,
        data: 'Section A',
        originalIndex: 0,
        endIndex: 4,
        itemExtent: 20.0,
      );

      // Items 0..4 occupy pixels 0..100. The scope ends at pixel 100.
      expect(candidate.scopeEndPosition, 100.0); // (4 + 1) * 20
    });

    test('scopeEndPosition with single-item scope', () {
      final candidate = StickyCandidate<String>(
        level: 1,
        data: 'Sub-section',
        originalIndex: 2,
        endIndex: 2,
        itemExtent: 20.0,
      );

      // A scope containing only item 2: bottom edge at (2 + 1) * 20 = 60.
      expect(candidate.scopeEndPosition, 60.0);
    });

    test('endPosition is startPosition + itemExtent', () {
      final candidate = StickyCandidate<String>(
        level: 0,
        data: 'Header',
        originalIndex: 1,
        endIndex: 5,
        itemExtent: 24.0,
      );

      expect(candidate.endPosition, 48.0); // 1 * 24 + 24
    });
  });

  group('StickyCandidate with cumulative offsets', () {
    test('startPosition uses startOffset when provided', () {
      final candidate = StickyCandidate<String>(
        level: 0,
        data: 'Section A',
        originalIndex: 2,
        endIndex: 5,
        itemExtent: 30.0,
        startOffset: 50.0, // Not 2 * 30 = 60
        scopeEndOffset: 180.0,
      );

      expect(candidate.startPosition, 50.0);
    });

    test('scopeEndPosition uses scopeEndOffset when provided', () {
      final candidate = StickyCandidate<String>(
        level: 0,
        data: 'Section A',
        originalIndex: 0,
        endIndex: 3,
        itemExtent: 20.0,
        startOffset: 0.0,
        scopeEndOffset: 95.0, // Variable heights: not (3+1)*20=80
      );

      expect(candidate.scopeEndPosition, 95.0);
    });

    test('falls back to uniform calculation when offsets not provided', () {
      final candidate = StickyCandidate<String>(
        level: 0,
        data: 'Section A',
        originalIndex: 2,
        endIndex: 5,
        itemExtent: 20.0,
      );

      // Uniform: startPosition = 2 * 20 = 40
      expect(candidate.startPosition, 40.0);
      // Uniform: scopeEndPosition = (5 + 1) * 20 = 120
      expect(candidate.scopeEndPosition, 120.0);
    });
  });
}
