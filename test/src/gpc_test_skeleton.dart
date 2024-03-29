/// Provides a generic test skeleton for [GpsPointsCollection] implementations.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';

import 'package:gps_history/src/utils/binary_conversions.dart';
import 'package:gps_history/src/utils/bounding_box.dart';
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
  late GpsPointsCollection<T> gpc;

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
    test('Length empty', () => expect(gpc.length, 0));

    test('isEmpty/isNotEmpty', () {
      expect(gpc.isEmpty, true, reason: 'wrong for empty list');
      expect(gpc.isNotEmpty, false, reason: 'wrong for empty list');
      gpc.add(itemConstructor(1));
      expect(gpc.isEmpty, false, reason: 'wrong for non-empty list');
      expect(gpc.isNotEmpty, true, reason: 'wrong for non-empty list');
    });

    test('Simple add and indexing', () {
      expect(() => gpc.first, throwsA(isA<StateError>()));
      expect(() => gpc.last, throwsA(isA<StateError>()));

      // basic tests with just one point
      final p0 = itemConstructor(1);
      gpc.add(p0);
      expect(gpc.length, 1, reason: 'wrong length after first add');
      expect(gpc[0], p0, reason: 'wrong point after first add');
      expect(gpc.elementAt(0), p0, reason: 'wrong elementAt after first add');
      expect(gpc.first, p0, reason: 'wrong first after first add');
      expect(gpc.last, p0, reason: 'wrong last after first add');

      // basic tests with a second point
      final p1 = itemConstructor(2);
      gpc.add(p1);
      expect(gpc.length, 2, reason: 'wrong length after second add');
      expect(gpc[0], p0, reason: 'wrong point at [0] after second add');
      expect(gpc[1], p1, reason: 'wrong point at [1] after second add');
      expect(gpc.elementAt(1), p1, reason: 'wrong elementAt after second add');
      expect(gpc.first, p0, reason: 'wrong first after second add');
      expect(gpc.last, p1, reason: 'wrong last after second add');
    });

    test('Invalid indexing', () {
      expect(() => gpc[-1], throwsA(isA<RangeError>()));
      expect(() => gpc[0], throwsA(isA<RangeError>()));
    });
  });

  group('Test $name - addAll* functionality:', () {
    test('addAll', () {
      final src = makeList(2);

      // Try addAll on different types (src and gpc are not of the
      // same class).
      expect(gpc.runtimeType, isNot(src.runtimeType),
          reason: 'test intended to be on different types');
      gpc.addAll(src);
      expect(gpc.length, src.length, reason: 'wrong length');
      for (var i = 0; i < gpc.length; i++) {
        expect(gpc[i], src[i], reason: 'incorrect point at position $i');
      }

      // Try addAll on the same type.
      final otherGpc = collectionConstructor();
      otherGpc.sortingEnforcement = SortingEnforcement.notRequired;
      expect(gpc.runtimeType, otherGpc.runtimeType,
          reason: 'test intended to be on same types');
      otherGpc.addAll(gpc);
      otherGpc.addAll(gpc);
      expect(otherGpc.length, 2 * gpc.length,
          reason: 'wrong length after addAll on same type');
      for (var i = 0; i < gpc.length; i++) {
        expect(otherGpc[i], gpc[i],
            reason: 'incorrect point at position $i after addAll on same type');
        expect(otherGpc[gpc.length + i], gpc[i],
            reason:
                'incorrect point at position ${gpc.length + i} after addAll on same type');
      }
    });

    test('addAllStartingAt', () {
      final src = makeList(5);

      // It's valid to call add with skipItems beyond the source boundary.
      gpc.addAllStartingAt(src, src.length);
      expect(gpc.length, 0,
          reason: 'should be empty if adding from beyond the source boundary');

      final skip = 2;
      // Try addAllStartingAt on different types (src and gpc are not of the
      // same class).
      gpc.sortingEnforcement = SortingEnforcement.notRequired;
      expect(gpc.runtimeType, isNot(src.runtimeType),
          reason: 'test intended to be on different types');
      gpc.addAllStartingAt(src, skip);
      expect(gpc.length, src.length - skip, reason: 'wrong length');
      for (var i = 0; i < gpc.length; i++) {
        expect(gpc[i], src[skip + i], reason: 'incorrect point at position $i');
      }

      // Try addAllStartingAt on the same type.
      final otherGpc = collectionConstructor();
      expect(gpc.runtimeType, otherGpc.runtimeType,
          reason: 'test intended to be on same types');
      otherGpc.addAllStartingAt(gpc, 0);
      otherGpc.sortingEnforcement = SortingEnforcement.notRequired;
      otherGpc.addAllStartingAt(gpc, 1);
      expect(otherGpc.length, 2 * gpc.length - 1,
          reason: 'wrong length after addAllStartingAt on same type');
      for (var i = 0; i < gpc.length; i++) {
        expect(otherGpc[i], gpc[i],
            reason:
                'incorrect point at position $i after addAllStartingAt on same type');
      }
      for (var i = gpc.length; i < otherGpc.length; i++) {
        expect(otherGpc[i], gpc[i - gpc.length + 1],
            reason:
                'incorrect point at position $i after addAllStartingAt on same type');
      }

      // Check invalid argument throws error.
      expect(
          () => otherGpc.addAllStartingAt(gpc, -1), throwsA(isA<RangeError>()));
    });

    test('addAllStartingAt with limited length', () {
      final src = makeList(10);

      // Try addAllStartingAt on different types (src and gpc are not of the
      // same class).
      expect(gpc.runtimeType, isNot(src.runtimeType),
          reason: 'test intended to be on different types');
      gpc.addAllStartingAt(src, 2, 3);
      expect(gpc.length, 3, reason: 'incorrect number of items added');
      for (var i = 0; i < gpc.length; i++) {
        expect(gpc[i], src[i + 2], reason: 'incorrect point at position $i');
      }

      // Add the rest of the items
      gpc.addAllStartingAt(src, 5);
      expect(gpc.length, 8,
          reason: 'incorrect number of items after adding rest');

      // Try addAllStartingAt on the same type.
      final otherGpc = collectionConstructor();
      expect(gpc.runtimeType, otherGpc.runtimeType,
          reason: 'test intended to be on same types');
      otherGpc.addAllStartingAt(gpc, 1, 4);
      expect(otherGpc.length, 4,
          reason: 'wrong length after addAllStartingAt on same type');
      for (var i = 0; i < otherGpc.length; i++) {
        expect(otherGpc[i], gpc[i + 1],
            reason:
                'incorrect point at position $i after addAllStartingAt on same type');
      }

      // Check invalid argument throws error.
      expect(() => otherGpc.addAllStartingAt(gpc, 1, -2),
          throwsA(isA<RangeError>()));
    });
  });

  group('Sublist', () {
    test('Zero length', () {
      final result = gpc.sublist(0);
      expect(result.runtimeType, gpc.runtimeType,
          reason: 'expected sublist of same type');
      expect(result.length, 0);
      expect(result.runtimeType, gpc.runtimeType);
    });

    test('Whole list', () {
      final src = makeList(5);
      gpc.addAll(src);
      final result = gpc.sublist(0);
      expect(result.length, src.length, reason: 'wrong length');
      for (var i = 0; i < result.length; i++) {
        expect(result[i], gpc[i], reason: 'incorrect item at position $i');
      }
    });
  });

  group('Test $name - iterator behaviour:', () {
    test('forEach', () {
      // Add three points. Start from 1 rather than 0, because we'll use
      // addition to detect if all elements have been traversed, and skipping
      // something with value 0 would obviously not be noticed.
      for (var i = 1; i < 4; i++) {
        gpc.add(itemConstructor(i));
      }

      // It's required that the constructor returns items with at least the
      // latitude being equal to the itemIndex+1.
      var total = 0.0;
      for (var point in gpc) {
        total += point.latitude;
      }
      expect(total, 6.0);
    });

    test('Skip', () {
      for (var i = 1; i < 4; i++) {
        gpc.add(itemConstructor(i));
      }

      var partialGpc = gpc.skip(0);
      expect(partialGpc.length, gpc.length);
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc[i], reason: 'Invalid point at position $i');
      }

      partialGpc = gpc.skip(1);
      expect(partialGpc.length, 2);
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc[i + 1],
            reason: 'Invalid point at position $i');
      }

      partialGpc = gpc.skip(1).skip(1);
      expect(partialGpc.length, 1);
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc[i + 2],
            reason: 'Invalid point at position $i');
      }
    });

    test('Take', () {
      gpc.addAll(makeList(5));

      // Take nothing.
      var partialGpc = gpc.take(0);
      expect(partialGpc.length, 0, reason: 'no elements to take');

      partialGpc = gpc.take(2);
      expect(partialGpc.length, 2,
          reason: 'should have specified number of elements');
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc[i], reason: 'Invalid point at position $i');
      }
      // Make sure indexing outside the taken range doesn't work.
      expect(() {
        partialGpc[3];
      }, throwsA(isA<IndexError>()));

      // Take everything, with parameter greater than length.
      partialGpc = gpc.take(gpc.length + 1);
      expect(partialGpc.length, gpc.length,
          reason: 'should have taken all elements');
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc[i], reason: 'Invalid point at position $i');
      }
    });

    test('Skip and take', () {
      gpc.addAll(makeList(10));

      final partialGpc = gpc.skip(3).take(4);
      expect(partialGpc.length, 4, reason: 'wrong number of elements taken');
      for (var i = 0; i < partialGpc.length; i++) {
        expect(partialGpc[i], gpc[i + 3],
            reason: 'Invalid point at position $i');
      }
    });
  });

  group('Test $name - sorting behaviour:', () {
    test('Simple sorted states', () {
      expect(gpc.sortedByTime, true,
          reason: 'empty list should implicitly be sorted');

      gpc.add(itemConstructor(1));
      expect(gpc.length, 1, reason: 'first item should have been added');
      expect(gpc.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');

      gpc.add(itemConstructor(2));
      expect(gpc.length, 2, reason: 'second item should have been added');
      expect(gpc.sortedByTime, true,
          reason: 'list with two incrementing items should be sorted');

      // Not allowed to add two items with the same time.
      expect(() {
        gpc.add(itemConstructor(2));
      }, throwsA(isA<GpsPointsViewSortingException>()));
      expect(gpc.length, 2, reason: 'third item should not have been added');
      expect(gpc.sortedByTime, true,
          reason: 'list should remain sorted after failed addition');

      gpc.sortingEnforcement = SortingEnforcement.notRequired;
      gpc.add(itemConstructor(1));
      expect(gpc.length, 3,
          reason:
              'third item should have been added even if it breaks sorting');
      expect(gpc.sortedByTime, false,
          reason: 'list with non-incrementing items should be unsorted');
    });

    test('skipWrongItems sorting behaviour', () {
      gpc.sortingEnforcement = SortingEnforcement.skipWrongItems;
      gpc.add(itemConstructor(1));
      expect(gpc.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');

      gpc.add(itemConstructor(0));
      expect(gpc.length, 1,
          reason: 'the invalid value should have been skipped');
      expect(gpc.sortedByTime, true,
          reason: 'the invalid value should have been skipped');

      gpc.add(itemConstructor(1));
      expect(gpc.length, 1, reason: 'duplicate value should have been skipped');
      expect(gpc.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');

      gpc.add(itemConstructor(3));
      expect(gpc.length, 2, reason: 'valid value should have been allowed');
      expect(gpc.sortedByTime, true,
          reason: 'list with three incrementing items should be sorted');
    });

    test('Throwing behaviour in case of sorting violating items', () {
      gpc.sortingEnforcement = SortingEnforcement.throwIfWrongItems;
      gpc.add(itemConstructor(1));
      expect(gpc.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');

      expect(() {
        gpc.add(itemConstructor(0));
      }, throwsA(isA<GpsPointsViewSortingException>()));
      expect(gpc.length, 1,
          reason: 'the invalid value should have not been added');
      expect(gpc.sortedByTime, true,
          reason: 'one-item list should implicitly be sorted');
      expect(gpc.last, itemConstructor(1),
          reason: 'contents of existing item were changed by failed addition');
    });

    test('Switching sorting enforcement', () {
      expect(gpc.sortingEnforcement, SortingEnforcement.throwIfWrongItems,
          reason: 'initial state not as expected');

      // Create an unsorted state.
      gpc.sortingEnforcement = SortingEnforcement.notRequired;
      gpc.add(itemConstructor(1));
      gpc.add(itemConstructor(0));

      expect(() {
        gpc.sortingEnforcement = SortingEnforcement.skipWrongItems;
      }, throwsA(isA<GpsPointsViewSortingException>()),
          reason: 'should not switch to skipWrongItems while unsorted');
      expect(() {
        gpc.sortingEnforcement = SortingEnforcement.throwIfWrongItems;
      }, throwsA(isA<GpsPointsViewSortingException>()),
          reason: 'should not switch to throwIfWrongItems while unsorted');
    });
  });

  test('checkContentsSortedByTime', () {
    expect(gpc.checkContentsSortedByTime(), true,
        reason: 'Empty list is by definition sorted');

    gpc.sortingEnforcement = SortingEnforcement.notRequired;
    gpc.add(itemConstructor(1));
    gpc.add(itemConstructor(0));
    gpc.add(itemConstructor(2));

    expect(gpc.sortedByTime, false,
        reason: 'list is incorrectly marked as sorted');

    expect(gpc.checkContentsSortedByTime(), false,
        reason: 'entire list is unsorted');
    expect(gpc.checkContentsSortedByTime(1), true,
        reason: 'list is partially unsorted');
    expect(gpc.checkContentsSortedByTime(2), true,
        reason: 'last item of the list is by defintion sorted');
    expect(gpc.sortedByTime, false,
        reason:
            'list is incorrectly marked as sorted because part of it is sorted');
    expect(gpc.checkContentsSortedByTime(gpc.length), true,
        reason:
            'contents beyond list are treated as empty list and hence sorted');
  });

  group('addAllStartingAt with (partially) unsorted source', () {
    runTest(dynamic source) {
      // Tests for adding invalid data.
      gpc.sortingEnforcement = SortingEnforcement.throwIfWrongItems;
      gpc.add(itemConstructor(0));
      for (var i = 0; i <= 1; i++) {
        expect(() {
          gpc.addAllStartingAt(source, i);
        }, throwsA(isA<GpsPointsViewSortingException>()),
            reason:
                'Should not be able to add unsorted source starting from index $i');
      }

      // Test for adding valid subset of data from overall invalid source.
      for (var i = 3; i <= source.length; i++) {
        final target = collectionConstructor();
        target.add(itemConstructor(0));
        target.addAllStartingAt(source, i);
        expect(target.length, max<int>(0, source.length - i) + 1,
            reason:
                'Should be able to add partially sorted source starting from index $i');
      }

      // Test with originally empty target and throwing in case of invalid data.
      for (var i = 0; i <= 1; i++) {
        final target = collectionConstructor();
        target.sortingEnforcement = SortingEnforcement.throwIfWrongItems;
        expect(() {
          target.addAllStartingAt(source, i);
        }, throwsA(isA<GpsPointsViewSortingException>()),
            reason: 'Expected failure when adding invalid data');
      }

      // Test for adding invalid data to target that doesn't care about sorting.
      for (var i = 0; i <= source.length; i++) {
        final target = collectionConstructor();
        target.sortingEnforcement = SortingEnforcement.notRequired;
        target.add(itemConstructor(0));
        target.addAllStartingAt(source, i);
        expect(target.length, max<int>(0, source.length - i) + 1,
            reason:
                'Should be able to add unsorted source starting from index $i');
      }

      // Test for adding partially invalid data to target that skips invalid data.
      for (var skipNr = 0; skipNr <= 1; skipNr++) {
        final target = collectionConstructor();
        target.sortingEnforcement = SortingEnforcement.skipWrongItems;
        target.add(itemConstructor(0));
        // The below will only copy up to but exculding source[2], as that's where
        // there's a discontinuity in the sorting.
        target.addAllStartingAt(source, skipNr);
        expect(target.length, 1 + (2 - skipNr),
            reason:
                'Should be able to add unsorted source starting from index $skipNr, skipping invalid items');
        for (var targetItemNr = 1;
            targetItemNr < target.length;
            targetItemNr++) {
          expect(target[targetItemNr], source[targetItemNr - 1 + skipNr],
              reason:
                  'invalid data at position $targetItemNr after copying from index $skipNr');
        }
      }
    }

    List<T> makeUnsortedList() {
      final result = makeList(0);
      // Create a list where the sorting is broken after the second item.
      result.add(itemConstructor(3));
      result.add(itemConstructor(4));
      result.add(itemConstructor(0));
      result.add(itemConstructor(1));
      result.add(itemConstructor(2));

      return result;
    }

    test('with source of different type', () {
      // There's a separate code path for source of different type than target.
      final source = makeUnsortedList();
      runTest(source);
    });

    test('with source of same type', () {
      final source = makeUnsortedList();
      final typedSource = collectionConstructor();
      typedSource.sortingEnforcement = SortingEnforcement.notRequired;
      for (final element in source) {
        typedSource.add(element);
      }
      // There's a separate code path for source of same type as target.
      runTest(typedSource);
    });
  });

  test('Time comparisons', () {
    gpc.add(itemConstructor(1));
    final newItem = itemConstructor(2);
    gpc.add(newItem);

    // Comparisons on all-internal items (may have optimized code paths).
    expect(gpc.compareElementTime(1, 1), TimeComparisonResult.same);
    expect(gpc.compareElementTime(0, 1), TimeComparisonResult.before);
    expect(gpc.compareElementTime(1, 0), TimeComparisonResult.after);

    // Comparisons on hybrid internal and standalone times.
    expect(gpc.compareElementTimeWithSeparateTime(0, newItem.time),
        TimeComparisonResult.before);
    expect(gpc.compareElementTimeWithSeparateTime(0, itemConstructor(0).time),
        TimeComparisonResult.after);

    // Comparisons on hybrid internal and standalone points.
    expect(gpc.compareElementTimeWithSeparateItem(0, newItem),
        TimeComparisonResult.before);
    expect(gpc.compareElementTimeWithSeparateItem(0, itemConstructor(0)),
        TimeComparisonResult.after);
    expect(gpc.compareElementTimeWithSeparateItem(1, newItem),
        TimeComparisonResult.same);

    // Comparisons with time spans.
    expect(
        gpc.compareElementTimeWithSeparateTimeSpan(
            1,
            newItem.time.secondsSinceEpoch - 10,
            newItem.endTime.secondsSinceEpoch + 10),
        TimeComparisonResult.overlapping);
  });

  test('Bounding box', () {
    final item = itemConstructor(1);
    gpc.add(item);
    final geodeticBBContaining = GeodeticLatLongBoundingBox(item.latitude - 1,
        item.longitude - 1, item.latitude + 1, item.longitude + 1);
    final geodeticBBExcluding = GeodeticLatLongBoundingBox(item.latitude + 1,
        item.longitude + 1, item.latitude + 2, item.longitude + 2);

    expect(gpc.elementContainedByBoundingBox(0, geodeticBBContaining), true);
    expect(
        gpc.elementContainedByBoundingBox(
            0, FlatLatLongBoundingBox.fromGeodetic(geodeticBBContaining)),
        true);
    expect(gpc.elementContainedByBoundingBox(0, geodeticBBExcluding), false);
    expect(
        gpc.elementContainedByBoundingBox(
            0, FlatLatLongBoundingBox.fromGeodetic(geodeticBBExcluding)),
        false);
  });

  test('For each lat/long E7', () {
    gpc.add(itemConstructor(1));
    gpc.add(itemConstructor(2));
    gpc.add(itemConstructor(3));

    // Test the entire list.
    int loopNr = -1;
    gpc.forEachLatLongE7((index, latitudeE7, longitudeE7) {
      loopNr++;
      expect(index, loopNr);
      expect(latitudeE7, Conversions.latitudeToUint32(gpc[index].latitude));
      expect(longitudeE7, Conversions.longitudeToUint32(gpc[index].longitude));
    });

    // Test just subset.
    gpc.forEachLatLongE7((index, latitudeE7, longitudeE7) {
      expect(index, 1);
    }, 1, 2);
  });
}
