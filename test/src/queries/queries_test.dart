/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_queries.dart';
import 'package:gps_history/src/utils/bounding_box.dart';
import 'package:test/test.dart';

void main() {
  group('QueryCollectionInfo', () {
    test('Empty', () async {
      final gpc = GpcListBased();
      final queryResult = await QueryCollectionInfo().query(gpc);

      expect(queryResult.firstItemStartTime, null);
      expect(queryResult.lastItemEndTime, null);
      expect(queryResult.length, gpc.length);
    });

    test('Simple', () async {
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(3)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)));
      final queryResult = await QueryCollectionInfo().query(gpc);

      expect(queryResult.firstItemStartTime, GpsTime(3));
      expect(queryResult.lastItemEndTime, GpsTime(10));
      expect(queryResult.length, gpc.length);
    });
  });

  group('QueryCollectionItems', () {
    checkEqualCollections(GpsPointsView actual, GpsPointsView expected) {
      expect(actual.runtimeType, expected.runtimeType,
          reason: 'Collections not of same type');

      expect(actual.length, expected.length,
          reason: 'Collection not of same length');

      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], expected[i], reason: 'Incorrect item at position $i');
      }
    }

    void runTest<P extends GpsPoint, C extends GpsPointsView<P>>(C source,
        QueryCollectionItems<P, C> query, CollectionItems expected) async {
      final result = await query.query(source);

      expect(result.startIndex, expected.startIndex,
          reason: 'Incorrect startIndex');

      checkEqualCollections(result.collection, expected.collection);
    }

    test('Empty', () {
      // Try on some type of collection.
      final gpc = GpcListBased();
      final query = QueryCollectionItems<GpsPoint, GpcListBased>();
      runTest(gpc, query, CollectionItems(0, gpc));
    });

    test('Entire list', () {
      // Try on some different type of collection.
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero)
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)));
      final query = QueryCollectionItems<GpsPoint, GpcCompactGpsPoint>();
      runTest(gpc, query, CollectionItems(0, gpc));
    });

    test('Non-empty start list, empty result', () {
      // Try on some different type of collection.
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero)
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)));
      final query = QueryCollectionItems<GpsPoint, GpcCompactGpsPoint>(
          startIndex: 1, nrItems: 0);
      runTest(gpc, query, CollectionItems(1, gpc.newEmpty()));
    });

    test('Sub list', () {
      // Try on some different type of collection.
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero)
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(20)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(30)));
      final query = QueryCollectionItems<GpsPoint, GpcCompactGpsPoint>(
          startIndex: 1, nrItems: 2);
      runTest(gpc, query, CollectionItems(1, gpc.sublist(1, 3)));
    });
  });

  group('QueryLocationByTime', () {
    // Doesn't require extensive testing since it just wraps the search
    // algorithm functionality, which has its own thorough tests.

    test('No match', () async {
      final collection = GpcListBased<GpsPoint>();
      final queryTime = GpsTime(10);
      final result =
          await QueryLocationByTime<GpsPoint, GpcListBased<GpsPoint>>(
                  queryTime, null)
              .query(collection);
      expect(result.location, null);
      expect(result.time, queryTime);
      expect(result.toleranceSeconds, null);
    });

    test('Exact match', () async {
      final collection = GpcListBased<GpsPoint>()
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(20)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(30)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(40)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(50)));
      final itemIndex = 4;
      final queryTime = collection[itemIndex].time;
      final result =
          await QueryLocationByTime<GpsPoint, GpcListBased<GpsPoint>>(
                  queryTime, null)
              .query(collection);
      expect(result.location, collection[itemIndex]);
      expect(result.time, queryTime);
      expect(result.toleranceSeconds, null);
    });

    test('Match thanks to tolerance', () async {
      final collection = GpcListBased<GpsPoint>()
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(20)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(30)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(40)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(50)));
      final itemIndex = 4;
      final queryTime = collection[itemIndex].time.add(seconds: 2);
      final perfectMatchResult =
          await QueryLocationByTime<GpsPoint, GpcListBased<GpsPoint>>(
                  queryTime, null)
              .query(collection);
      expect(perfectMatchResult.location, null,
          reason: 'Perfect match should not be found');

      final smallToleranceMatchResult =
          await QueryLocationByTime<GpsPoint, GpcListBased<GpsPoint>>(
                  queryTime, 1)
              .query(collection);
      expect(smallToleranceMatchResult.location, null,
          reason: 'Small tolerance match should not be found');

      final largeToleranceMatchResult =
          await QueryLocationByTime<GpsPoint, GpcListBased<GpsPoint>>(
                  queryTime, 2)
              .query(collection);
      expect(largeToleranceMatchResult.location, collection[itemIndex],
          reason: 'Large tolerance match should be found');
    });
  });

  group('Generate intervals', () {
    runTest(int startTimeSeconds, int endTimeSeconds, int nrIntervals,
        List<Interval> expectedIntervals,
        [String message = '']) async {
      final foundIntervals = <Interval>[];
      await for (final interval in generateIntervals(
          GpsTime(startTimeSeconds), GpsTime(endTimeSeconds), nrIntervals)) {
        foundIntervals.add(interval);
      }

      final msg = message == '' ? '' : '$message: ';

      expect(foundIntervals.length, expectedIntervals.length,
          reason: '${msg}Incorrect number of intervals.');
      for (var i = 0; i < foundIntervals.length; i++) {
        expect(foundIntervals[i], expectedIntervals[i],
            reason: '${msg}Incorrect interval at position $i');
      }
    }

    test('Invalid times', () {
      runTest(2, 1, 1, []);
    });

    test('Invalid intervals', () {
      runTest(1, 2, -1, []);
    });

    test('Single interval', () {
      runTest(1, 2, 1, [Interval.fromSeconds(1, 2)]);
      runTest(0, 20, 1, [Interval.fromSeconds(0, 20)]);
    });

    test('Multi interval', () {
      runTest(0, 20, 2,
          [Interval.fromSeconds(0, 10), Interval.fromSeconds(10, 20)], 'Long');

      runTest(1, 2, 2, [Interval.fromSeconds(1, 2), Interval.fromSeconds(2, 2)],
          'Short');

      runTest(2, 13, 2,
          [Interval.fromSeconds(2, 8), Interval.fromSeconds(8, 13)], 'Primes');
    });
  });

  group('Interval', () {
    test('toString', () {
      expect(Interval.fromSeconds(1, 2).toString(), 'start: 1, end: 2');
    });

    test('hash', () {
      expect(Interval.fromSeconds(1, 2).hashCode,
          isNot(Interval.fromSeconds(2, 3).hashCode));
    });
  });

  group('QueryDataAvailability', () {
    late GpsTime startTime;
    late GpsTime endTime;
    late int nrIntervals;
    late GeodeticLatLongBoundingBox boundingBox;
    late GpcCompactGpsPoint collection;

    setUp(() {
      startTime = GpsTime(100);
      endTime = GpsTime(200);
      nrIntervals = 50;
      boundingBox = GeodeticLatLongBoundingBox(0, 0, 10, 10);
      // Very simple collection that should return a match.
      collection = GpcCompactGpsPoint()
        ..add(GpsPoint(
            time: startTime.add(seconds: endTime.difference(startTime) ~/ 2),
            latitude: boundingBox.bottomLatitude +
                (boundingBox.topLatitude - boundingBox.bottomLatitude) ~/ 2,
            longitude: boundingBox.leftLongitude +
                (boundingBox.rightLongitude - boundingBox.leftLongitude) ~/ 1));
    });

    checkResultDataOnly(DataAvailability result, List<Data> expectedData,
        [String message = '']) {
      final msg = message == '' ? '' : '$message: ';
      expect(result.length, expectedData.length,
          reason: '${msg}Wrong amount of data.');
      for (var i = 0; i < result.length; i++) {
        expect(result[i], expectedData[i],
            reason: '${msg}Wrong data found at index $i');
      }
    }

    checkResultFull(
        DataAvailability result,
        GpsTime expectedStartTime,
        GpsTime expectedEndTime,
        int expectedNrIntervals,
        GeodeticLatLongBoundingBox? expectedBoundingBox,
        List<Data> expectedData,
        [String message = '']) {
      final msg = message == '' ? '' : '$message: ';

      expect(result.startTime, expectedStartTime,
          reason: '${msg}Incorrect startTime.');
      expect(result.endTime, expectedEndTime,
          reason: '${msg}Incorrect endTime.');
      expect(result.nrIntervals, expectedNrIntervals,
          reason: '${msg}Incorrect nrIntervals.');
      expect(result.boundingBox, expectedBoundingBox,
          reason: '${msg}Incorrect bounding box.');

      checkResultDataOnly(result, expectedData, message);
    }

    test('Empty collection', () async {
      final query =
          QueryDataAvailability(startTime, endTime, nrIntervals, boundingBox);
      final result = await query.query(GpcCompactGpsPoint());
      checkResultFull(result, startTime, endTime, nrIntervals, boundingBox, []);
    });

    test('Invalid time range', () async {
      final query =
          QueryDataAvailability(endTime, startTime, nrIntervals, null);
      final result = await query.query(collection);
      checkResultFull(result, endTime, startTime, nrIntervals, null, []);
    });

    test('Invalid number of intervals', () async {
      var query = QueryDataAvailability(startTime, endTime, 0, boundingBox);
      var result = await query.query(collection);
      checkResultFull(
          result, startTime, endTime, 0, boundingBox, [], 'Zero interval');

      query = QueryDataAvailability(startTime, endTime, -1, boundingBox);
      result = await query.query(collection);
      checkResultFull(
          result, startTime, endTime, -1, boundingBox, [], 'Negative interval');
    });

    test('Unsorted collection', () async {
      collection.sortingEnforcement = SortingEnforcement.notRequired;
      collection.add(
          // Add a point outside the bounding box.
          collection[0].copyWith(
              time: collection[0].time.add(seconds: -25),
              latitude: boundingBox.topLatitude + 1,
              longitude: boundingBox.rightLongitude + 1));
      expect(collection.sortedByTime, false,
          reason: 'Expected collection to be unsorted');

      var query = QueryDataAvailability(startTime, endTime, 4, null);
      var result = await query.query(collection);
      checkResultDataOnly(
          result,
          [
            Data.notAvailable,
            Data.availableWithinBoundingBox,
            Data.availableWithinBoundingBox,
            Data.notAvailable
          ],
          'Unsorted collection no bounding box');

      query = QueryDataAvailability(startTime, endTime, 4, boundingBox);
      result = await query.query(collection);
      checkResultDataOnly(
          result,
          [
            Data.notAvailable,
            Data.availableOutsideBoundingBox,
            Data.availableWithinBoundingBox,
            Data.notAvailable
          ],
          'Unsorted collection with bounding box');
    });
  });
}
