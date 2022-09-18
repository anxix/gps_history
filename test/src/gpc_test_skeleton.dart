/// Provides a generic test skeleton for [GpsPointsCollection] implementations.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

/// Runs standard tests on a collection of points.
///
/// The [name] of the test indicates how it will be identified (typically the
/// name of the collection under test). Two constructors must be provided to
/// create the collection to be tested ([collectionConstructor]) respectively
/// an item in the collection at a specific index ([itemConstructor]).
/// The [itemConstructor] must return an item with at least for the latitude
/// a value equal to the provided [itemIndex] parameter.
void testGpsPointsCollection<T extends GpsPoint>(
    String name,
    GpsPointsCollection<T> Function() collectionConstructor,
    T Function(int itemIndex) itemConstructor) {
  GpsPointsCollection<T>? gpc;

  /// Returns a list with [nrItems] items built with the specified
  /// [itemConstructor].
  List<T> makeList(int nrItems) {
    final result = List<T>.filled(nrItems, itemConstructor(0), growable: true);
    for (var i = 0; i < result.length; i++) {
      result[i] = itemConstructor(i + 1);
    }
    return result;
  }

  setUp(() {
    gpc = collectionConstructor();
  });

  group('Test $name - basics:', () {
    test('Length empty', () => expect(gpc!.length, 0));

    test('isEmpty/isNotEmpty', () {
      expect(gpc!.isEmpty, true, reason: 'wrong for empty list');
      expect(gpc!.isNotEmpty, false, reason: 'wrong for empty list');
      gpc!.add(itemConstructor(1));
      expect(gpc!.isEmpty, false, reason: 'wrong for non-empty list');
      expect(gpc!.isNotEmpty, true, reason: 'wrong for non-empty list');
    });

    test('Simple add and indexing', () {
      expect(() => gpc!.first, throwsA(isA<StateError>()));
      expect(() => gpc!.last, throwsA(isA<StateError>()));

      // basic tests with just one point
      final p0 = itemConstructor(1);
      gpc!.add(p0);
      expect(gpc!.length, 1, reason: 'wrong length after first add');
      expect(gpc![0], p0, reason: 'wrong point after first add');
      expect(gpc!.elementAt(0), p0, reason: 'wrong elementAt after first add');
      expect(gpc!.first, p0, reason: 'wrong first after first add');
      expect(gpc!.last, p0, reason: 'wrong last after first add');

      // basic tests with a second point
      final p1 = itemConstructor(2);
      gpc!.add(p1);
      expect(gpc!.length, 2, reason: 'wrong length after second add');
      expect(gpc![0], p0, reason: 'wrong point at [0] after second add');
      expect(gpc![1], p1, reason: 'wrong point at [1] after second add');
      expect(gpc!.elementAt(1), p1, reason: 'wrong elementAt after second add');
      expect(gpc!.first, p0, reason: 'wrong first after second add');
      expect(gpc!.last, p1, reason: 'wrong last after second add');
    });
  });

  group('Test $name - addAll* functionality:', () {
    test('addAll', () {
      final src = makeList(2);

      // Try addAll on different types (src and gpc are not of the
      // same class).
      expect(gpc!.runtimeType, isNot(src.runtimeType),
          reason: 'test intended to be on different types');
      gpc!.addAll(src);
      expect(gpc!.length, src.length, reason: 'wrong length');
      for (var i = 0; i < gpc!.length; i++) {
        expect(gpc![i], src[i], reason: 'incorrect point at position $i');
      }

      // Try addAll on the same type.
      final otherGpc = collectionConstructor();
      otherGpc.sortingEnforcement = SortingEnforcement.notRequired;
      expect(gpc!.runtimeType, otherGpc.runtimeType,
          reason: 'test intended to be on same types');
      otherGpc.addAll(gpc!);
      otherGpc.addAll(gpc!);
      expect(otherGpc.length, 2 * gpc!.length,
          reason: 'wrong length after addAll on same type');
      for (var i = 0; i < gpc!.length; i++) {
        expect(otherGpc[i], gpc![i],
            reason: 'incorrect point at position $i after addAll on same type');
        expect(otherGpc[gpc!.length + i], gpc![i],
            reason:
                'incorrect point at position ${gpc!.length + i} after addAll on same type');
      }
    });

    test('addAllStartingAt', () {
      final src = makeList(5);

      // It's valid to call add with skipItems beyond the source boundary.
      gpc!.addAllStartingAt(src, src.length);
      expect(gpc!.length, 0,
          reason: 'should be empty if adding from beyond the source boundary');

      final skip = 2;
      // Try addAllStartingAt on different types (src and gpc are not of the
      // same class).
      gpc!.sortingEnforcement = SortingEnforcement.notRequired;
      expect(gpc!.runtimeType, isNot(src.runtimeType),
          reason: 'test intended to be on different types');
      gpc!.addAllStartingAt(src, skip);
      expect(gpc!.length, src.length - skip, reason: 'wrong length');
      for (var i = 0; i < gpc!.length; i++) {
        expect(gpc![i], src[skip + i],
            reason: 'incorrect point at position $i');
      }

      // Try addAllStartingAlt on the same type.
      final otherGpc = collectionConstructor();
      expect(gpc!.runtimeType, otherGpc.runtimeType,
          reason: 'test intended to be on same types');
      otherGpc.addAllStartingAt(gpc!, 0);
      otherGpc.sortingEnforcement = SortingEnforcement.notRequired;
      otherGpc.addAllStartingAt(gpc!, 1);
      expect(otherGpc.length, 2 * gpc!.length - 1,
          reason: 'wrong length after addAllStartingAt on same type');
      for (var i = 0; i < gpc!.length; i++) {
        expect(otherGpc[i], gpc![i],
            reason:
                'incorrect point at position $i after addAllStartingAt on same type');
      }
      for (var i = gpc!.length; i < otherGpc.length; i++) {
        expect(otherGpc[i], gpc![i - gpc!.length + 1],
            reason:
                'incorrect point at position $i after addAllStartingAt on same type');
      }

      // Check invalid argument throws error.
      expect(() => otherGpc.addAllStartingAt(gpc!, -1),
          throwsA(isA<RangeError>()));
    });
  });

  group('Test $name - iterator behaviour:', () {
    test('forEach', () {
      // Add three points. Start from 1 rather than 0, because we'll use
      // addition to detect if all elements have been traversed, and skipping
      // something with value 0 would obviously not be noticed.
      for (var i = 1; i < 4; i++) {
        gpc!.add(itemConstructor(i));
      }

      // It's required that the constructor returns items with at least the
      // latitude being equal to the itemIndex+1.
      var total = 0.0;
      for (var point in gpc!) {
        total += point.latitude;
      }
      expect(total, 6.0);
    });

    test('Skip', () {
      for (var i = 1; i < 4; i++) {
        gpc!.add(itemConstructor(i));
      }

      var partialGpc = gpc!.skip(0);
      expect(partialGpc.length, gpc!.length);
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc![i], reason: 'Invalid point at position $i');
      }

      partialGpc = gpc!.skip(1);
      expect(partialGpc.length, 2);
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc![i + 1],
            reason: 'Invalid point at position $i');
      }

      partialGpc = gpc!.skip(1).skip(1);
      expect(partialGpc.length, 1);
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc![i + 2],
            reason: 'Invalid point at position $i');
      }
    });
  });

  group('Test $name - sorting behaviour:', () {
    test('Simple sorted states', () {
      expect(gpc!.sortedByTime, true,
          reason: 'empty list should implicitly be sorted');

      gpc!.add(itemConstructor(1));
      expect(gpc!.length, 1, reason: 'first item should have been added');
      expect(gpc!.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');

      gpc!.add(itemConstructor(2));
      expect(gpc!.length, 2, reason: 'second item should have been added');
      expect(gpc!.sortedByTime, true,
          reason: 'list with two incrementing items should be sorted');

      gpc!.add(itemConstructor(2));
      expect(gpc!.length, 3, reason: 'third item should have been added');
      expect(gpc!.sortedByTime, true,
          reason:
              'list with two identical incrementing items should be sorted');

      gpc!.sortingEnforcement = SortingEnforcement.notRequired;
      gpc!.add(itemConstructor(1));
      expect(gpc!.length, 4,
          reason:
              'fourth item should have been added even if it breaks sorting');
      expect(gpc!.sortedByTime, false,
          reason: 'list with non-incrementing items should be unsorted');
    });

    test('skipWrongItems sorting behaviour', () {
      gpc!.sortingEnforcement = SortingEnforcement.skipWrongItems;
      gpc!.add(itemConstructor(1));
      expect(gpc!.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');

      gpc!.add(itemConstructor(0));
      expect(gpc!.length, 1,
          reason: 'the invalid value should have been skipped');
      expect(gpc!.sortedByTime, true,
          reason: 'the invalid value should have been skipped');

      gpc!.add(itemConstructor(1));
      expect(gpc!.length, 2,
          reason: 'valid duplicate value should have been allowed');
      expect(gpc!.sortedByTime, true,
          reason: 'list with two identical items should be sorted');

      gpc!.add(itemConstructor(3));
      expect(gpc!.length, 3, reason: 'valid value should have been allowed');
      expect(gpc!.sortedByTime, true,
          reason: 'list with three incrementing items should be sorted');
    });

    test('Throwing behaviour in case of sorting violating items', () {
      gpc!.sortingEnforcement = SortingEnforcement.throwIfWrongItems;
      gpc!.add(itemConstructor(1));
      expect(gpc!.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');

      expect(() {
        gpc!.add(itemConstructor(0));
      }, throwsA(isA<GpsPointsViewSortingException>()));
      expect(gpc!.length, 1,
          reason: 'the invalid value should have not been added');
      expect(gpc!.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');
      expect(gpc!.last, itemConstructor(1),
          reason: 'contents of existing item were changed by failed addition');
    });

    test('Switching sorting enforcement', () {
      expect(gpc!.sortingEnforcement, SortingEnforcement.throwIfWrongItems,
          reason: 'initial state not as expected');

      // Create an unsorted state.
      gpc!.sortingEnforcement = SortingEnforcement.notRequired;
      gpc!.add(itemConstructor(1));
      gpc!.add(itemConstructor(0));

      expect(() {
        gpc!.sortingEnforcement = SortingEnforcement.skipWrongItems;
      }, throwsA(isA<GpsPointsViewSortingException>()),
          reason: 'should not switch to skipWrongItems while unsorted');
      expect(() {
        gpc!.sortingEnforcement = SortingEnforcement.throwIfWrongItems;
      }, throwsA(isA<GpsPointsViewSortingException>()),
          reason: 'should not switch to throwIfWrongItems while unsorted');
    });
  });

  test('checkContentsSortedByTime', () {
    expect(gpc!.checkContentsSortedByTime(), true,
        reason: 'Empty list is by definition sorted');

    gpc!.sortingEnforcement = SortingEnforcement.notRequired;
    gpc!.add(itemConstructor(1));
    gpc!.add(itemConstructor(0));
    gpc!.add(itemConstructor(2));

    expect(gpc!.sortedByTime, false,
        reason: 'list is incorrectly marked as sorted');

    expect(gpc!.checkContentsSortedByTime(), false,
        reason: 'entire list is unsorted');
    expect(gpc!.checkContentsSortedByTime(1), true,
        reason: 'list is partially unsorted');
    expect(gpc!.checkContentsSortedByTime(2), true,
        reason: 'last item of the list is by defintion sorted');
    expect(gpc!.sortedByTime, false,
        reason:
            'list is incorrectly marked as sorted because part of it is sorted');
    expect(gpc!.checkContentsSortedByTime(gpc!.length), true,
        reason:
            'contents beyond list are treated as empty list and hence sorted');
  });

  test('Time comparisons', () {
    // Simple comparisons on standalone entities.
    expect(gpc!.compareTime(itemConstructor(2), itemConstructor(2)),
        TimeComparisonResult.same);
    expect(gpc!.compareTime(itemConstructor(2), itemConstructor(3)),
        TimeComparisonResult.before);
    expect(gpc!.compareTime(itemConstructor(3), itemConstructor(2)),
        TimeComparisonResult.after);

    // Comparisons on all-internal items (may have optimized code paths).
    gpc!.add(itemConstructor(1));
    final newItem = itemConstructor(2);
    gpc!.add(newItem);
    expect(gpc!.compareElementTime(1, 1), TimeComparisonResult.same);
    expect(gpc!.compareElementTime(0, 1), TimeComparisonResult.before);
    expect(gpc!.compareElementTime(1, 0), TimeComparisonResult.after);

    // Comparisons on hybrid internal and standalone points
    expect(gpc!.compareElementTimeWithSeparateItem(0, newItem),
        TimeComparisonResult.before);
    expect(gpc!.compareElementTimeWithSeparateItem(0, itemConstructor(0)),
        TimeComparisonResult.after);
    expect(gpc!.compareElementTimeWithSeparateItem(1, newItem),
        TimeComparisonResult.same);
  });
}
