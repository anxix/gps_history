/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:test/test.dart';

void main() {
  group('QueryCollectionInfo', () {
    test('Empty', () {
      final gpc = GpcListBased();
      final queryResult = QueryCollectionInfo().query(gpc);

      expect(queryResult.firstItemStartTime, null);
      expect(queryResult.lastItemEndTime, null);
      expect(queryResult.length, gpc.length);
    });

    test('Simple', () {
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(3)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)));
      final queryResult = QueryCollectionInfo().query(gpc);

      expect(queryResult.firstItemStartTime, GpsTime(3));
      expect(queryResult.lastItemEndTime, GpsTime(10));
      expect(queryResult.length, gpc.length);
    });
  });

  checkEqualCollections(GpsPointsView actual, GpsPointsView expected) {
    expect(actual.runtimeType, expected.runtimeType,
        reason: 'Collections not of same type');

    expect(actual.length, expected.length,
        reason: 'Collection not of same length');

    for (var i = 0; i < actual.length; i++) {
      expect(actual[i], expected[i], reason: 'Incorrect item at position $i');
    }
  }

  group('QueryCollectionItems', () {
    void runTest<C extends GpsPointsView>(
        C source, QueryCollectionItems<C> query, CollectionItems expected) {
      final result = query.query(source);

      expect(result.startIndex, expected.startIndex,
          reason: 'Incorrect startIndex');

      checkEqualCollections(result.collection, expected.collection);
    }

    test('Empty', () {
      // Try on some type of collection.
      final gpc = GpcListBased();
      final query = QueryCollectionItems<GpcListBased>();
      runTest(gpc, query, CollectionItems(0, gpc));
    });

    test('Entire list', () {
      // Try on some different type of collection.
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero)
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)));
      final query = QueryCollectionItems<GpcCompactGpsPoint>();
      runTest(gpc, query, CollectionItems(0, gpc));
    });

    test('Non-empty start list, empty result', () {
      // Try on some different type of collection.
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero)
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)));
      final query =
          QueryCollectionItems<GpcCompactGpsPoint>(startIndex: 1, nrItems: 0);
      runTest(gpc, query, CollectionItems(1, gpc.newEmpty()));
    });

    test('Sub list', () {
      // Try on some different type of collection.
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero)
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(20)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(30)));
      final query =
          QueryCollectionItems<GpcCompactGpsPoint>(startIndex: 1, nrItems: 2);
      runTest(gpc, query, CollectionItems(1, gpc.sublist(1, 3)));
    });
  });
}