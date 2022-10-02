/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/src/queries/search.dart';
import 'package:test/test.dart';

typedef SearchAlgorithmBuilder = SearchAlgorithm Function(
    GpcCompactGpsPoint collection, CompareTargetToItemFunc compareFunc);

void main() {
  group('Search algorithm', () {
    /// Runs a battery of tests on the algorithm returned by [s], using a target
    /// list built such that each item is [incrementPerItem] higher in value
    /// than the one before it. If [expectToFindAll] is true, all items must be
    /// found by the algorithm, otherwise it may or may not find all items.
    runTest(SearchAlgorithmBuilder algoBuilder, int incrementPerItem,
        bool expectToFindAll) {
      // Keep track of how many items were not found, because if expectToFindAll
      // is false, at least some items must be not found. This effectively tests
      // that binary searches don't probe the entire list.
      int nrNotFound = 0;
      // Run the test for a variety of collection lengths.
      for (var nrPoints = 0; nrPoints < 11; nrPoints++) {
        const refTime = 1000000;
        // Create a collection of the specified length.
        final collection = GpcCompactGpsPoint()..capacity = nrPoints;
        collection.sortingEnforcement = SortingEnforcement.notRequired;
        for (var pointNr = 0; pointNr < nrPoints; pointNr++) {
          final point = GpsPoint.allZero
              .copyWith(time: GpsTime(refTime + pointNr * incrementPerItem));
          collection.add(point);
        }

        final searchAlgo = algoBuilder(
            collection, makeTimeCompareFunc(collection, GpsTime(refTime)));

        if (collection.isEmpty) {
          expect(searchAlgo.find(), null,
              reason: 'Should not find anything in empty list.');
          continue;
        }

        // Try to find every element in the list.
        for (final target in collection) {
          final searchAlgo = algoBuilder(
              collection, makeTimeCompareFunc(collection, target.time));
          final result = searchAlgo.find();
          if (result != null) {
            // Found a match -> check it's correct.
            expect(collection[result].time, target.time,
                reason:
                    'Found result $result, but it is not the target (${target.time}) in ${collection.length} items.');
          } else {
            // Didn't find a match -> that's OK if we didn't expect to find all.
            nrNotFound++;
            expect(expectToFindAll, false,
                reason:
                    'Found no match for ${target.time} in ${collection.length} items, but expected one!');
          }
        }
      }
      if (!expectToFindAll && nrNotFound == 0) {
        fail('Expected to have at least some not found items, but found all.');
      }
    }

    test('Linear in sorted list', () {
      // Test that it finds items in a sorted list.
      runTest(
          (GpcCompactGpsPoint collection, CompareTargetToItemFunc compareFunc) {
        return LinearSearchInGpcEfficient(collection, compareFunc);
      }, 1, true);
    });

    test('Linear in unsorted list', () {
      // Test that it finds items in an unsorted list.
      runTest(
          (GpcCompactGpsPoint collection, CompareTargetToItemFunc compareFunc) {
        return LinearSearchInGpcEfficient(collection, compareFunc);
      }, -1, true);
    });

    test('Binary in sorted list', () {
      // Test that it finds items in a sorted list.
      runTest(
          (GpcCompactGpsPoint collection, CompareTargetToItemFunc compareFunc) {
        return BinarySearchInGpcEfficient(collection, compareFunc);
      }, 1, true);
    });

    test('Binary in unsorted list', () {
      // Test that it doesn't find all items in an unsorted list.
      runTest(
          (GpcCompactGpsPoint collection, CompareTargetToItemFunc compareFunc) {
        return BinarySearchInGpcEfficient(collection, compareFunc);
      }, -1, false);
    });
  });
}
