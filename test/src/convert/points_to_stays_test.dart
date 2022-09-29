/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';
import 'package:test/test.dart';

void main() {
  checkTestResults(List<GpsStay> results, List<GpsStay> expected) {
    expect(results.length, expected.length, reason: 'Incorrect results length');

    for (var i = 0; i < results.length; i++) {
      final foundPoint = results[i];
      final expectedPoint = expected[i];
      expect(foundPoint, expectedPoint, reason: 'Mismatch at position $i');
    }
  }

  group('PointMerger', () {
    final maxTimeGapSeconds = 10;
    final maxDistanceGapMeters = 5.0;
    final offsetAtMaxDistanceGapMeter =
        maxDistanceGapMeters * 1 / metersPerDegreeLatitude;

    runTest(List<GpsPoint> input, List<GpsStay> expected) {
      final results = <GpsStay>[];
      final merger = PointMerger((result) => results.add(result),
          maxTimeGapSeconds: maxTimeGapSeconds,
          maxDistanceGapMeters: maxDistanceGapMeters);

      for (final point in input) {
        merger.addPoint(point);
      }
      merger.close();

      checkTestResults(results, expected);
    }

    test('Empty', () {
      runTest([], []);
    });

    test('Single item', () {
      makeAndTestPoint(GpsPoint Function() maker) {
        final p = maker();
        runTest([p], [GpsStay.fromPoint(p)]);
      }

      makeAndTestPoint(() =>
          GpsPoint(time: GpsTime(1), latitude: 2, longitude: 3, altitude: 4));

      // Test GpsStay with both null and non-null endTime.
      makeAndTestPoint(
          () => GpsStay(time: GpsTime(1), latitude: 2, longitude: 3));
      final sp = GpsStay(
          time: GpsTime(1),
          latitude: 2,
          longitude: 3,
          altitude: 4,
          endTime: GpsTime(6));
      runTest([sp], [sp]);

      // Test GpsMeasurement.
      makeAndTestPoint(
          () => GpsMeasurement(time: GpsTime(5), latitude: 6, longitude: 7));
      final mp = GpsMeasurement(
          time: GpsTime(7), latitude: 8, longitude: 9, accuracy: 12);
      runTest([mp], [GpsStay.fromPoint(mp).copyWith(accuracy: mp.accuracy)]);
    });

    test('No merging discontinuous time', () {
      final p1 = GpsPoint(time: GpsTime(1), latitude: 2, longitude: 3);
      final p2 = p1.copyWith(time: p1.time.add(seconds: maxTimeGapSeconds + 1));
      final result = [GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)];

      runTest([p1, p2], result);
      runTest([GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)], result);
      runTest(
          [GpsMeasurement.fromPoint(p1), GpsMeasurement.fromPoint(p2)], result);
    });

    test('No merging discontinuous space', () {
      final p1 = GpsPoint(time: GpsTime(2), latitude: 0, longitude: 1);
      final p2 = p1.copyWith(
          time: p1.time.add(seconds: maxTimeGapSeconds - 1),
          latitude: p1.latitude + 1.1 * offsetAtMaxDistanceGapMeter);
      final result = [GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)];

      runTest([p1, p2], result);
      runTest([GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)], result);
      runTest(
          [GpsMeasurement.fromPoint(p1), GpsMeasurement.fromPoint(p2)], result);
    });

    test('Merging nearby time in identical space', () {
      final p1 = GpsPoint(time: GpsTime(1), latitude: 2, longitude: 3);
      final p2 = p1.copyWith(time: p1.time.add(seconds: maxTimeGapSeconds - 1));
      final result = [GpsStay.fromPoint(p1).copyWith(endTime: p2.time)];

      runTest([p1, p2], result);
      runTest([GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)], result);
      runTest(
          [GpsMeasurement.fromPoint(p1), GpsMeasurement.fromPoint(p2)], result);
    });

    test('Merging nearby time in nearby space', () {
      final p1 = GpsPoint(time: GpsTime(1), latitude: 2, longitude: 3);
      final p2 = p1.copyWith(
          time: p1.time.add(seconds: maxTimeGapSeconds - 1),
          latitude: p1.latitude + 0.9 * offsetAtMaxDistanceGapMeter);
      final result = [GpsStay.fromPoint(p1).copyWith(endTime: p2.time)];

      runTest([p1, p2], result);
      runTest([GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)], result);
      runTest(
          [GpsMeasurement.fromPoint(p1), GpsMeasurement.fromPoint(p2)], result);
    });

    test('Merging GpsStays with non-zero durations', () {
      final p1 = GpsStay(
          time: GpsTime(1), latitude: 0, longitude: 0, endTime: GpsTime(2));
      final nextStartTime = p1.endTime.add(seconds: maxTimeGapSeconds - 1);
      final p2 = p1.copyWith(
          time: nextStartTime, endTime: nextStartTime.add(seconds: 100));
      final result = [p1.copyWith(endTime: p2.endTime)];

      runTest([p1, p2], result);
    });

    test('Merging GpsStays and GpsPoint', () {
      final p1 = GpsStay(
          time: GpsTime(1), latitude: 0, longitude: 0, endTime: GpsTime(2));
      final nextStartTime = p1.endTime.add(seconds: maxTimeGapSeconds - 1);
      final p2 = GpsPoint(
          time: nextStartTime, latitude: p1.latitude, longitude: p1.latitude);
      final result = [p1.copyWith(endTime: p2.time)];

      runTest([p1, p2], result);
    });

    test('Updating position from better accuracy', () {
      final p1 = GpsStay(
          time: GpsTime(1),
          latitude: 0,
          longitude: 0,
          altitude: 19,
          accuracy: 10,
          endTime: GpsTime(2));
      final nextStartTime = p1.endTime.add(seconds: maxTimeGapSeconds - 1);
      final p2 = p1.copyWith(
          time: nextStartTime,
          latitude: p1.latitude + 0.9 * offsetAtMaxDistanceGapMeter,
          altitude: 219,
          accuracy: 0.9 * p1.accuracy!,
          endTime: nextStartTime.add(seconds: 100));

      var result = [p2.copyWith(time: p1.time)];
      runTest([p1, p2], result);
    });

    test('Not updating position from worse accuracy', () {
      final p1 = GpsStay(
          time: GpsTime(1),
          latitude: 0,
          longitude: 0,
          endTime: GpsTime(2),
          accuracy: 10);
      final nextStartTime = p1.endTime.add(seconds: maxTimeGapSeconds - 1);
      final p2 = p1.copyWith(
          time: nextStartTime,
          endTime: nextStartTime.add(seconds: 100),
          latitude: p1.latitude + 0.9 * offsetAtMaxDistanceGapMeter,
          accuracy: 1.1 * p1.accuracy!);

      var result = [p1.copyWith(endTime: p2.endTime)];
      runTest([p1, p2], result);
    });

    test('Not merging points that are not in order of increasing time', () {
      final p1 = GpsStay(
          time: GpsTime(1000),
          latitude: 0,
          longitude: 0,
          endTime: GpsTime(2000));
      // p2 overlaps p1
      final p2 = p1.copyWith(
          time: p1.time.add(seconds: maxTimeGapSeconds - 1),
          endTime: p1.endTime.add(seconds: maxTimeGapSeconds - 1));
      // p3 is before p2 and hence cannot be merged
      final p3 = p2.copyWith(
          time: p2.time.add(seconds: -2), endTime: p2.time.add(seconds: -1));

      final result = [p1, p2, p3];

      runTest([p1, p2, p3], result);
    });

    test('Identical points', () {
      final p1 = GpsPoint(time: GpsTime(10), latitude: 1, longitude: 2);

      final result = [GpsStay.fromPoint(p1)];

      runTest([p1, p1], result);

      final sp1 =
          GpsStay.fromPoint(p1).copyWith(endTime: p1.time.add(seconds: 10));
      runTest([sp1, sp1], [sp1]);
    });
  });

  group('PointsToStaysDecoder', () {
    late PointsToStaysDecoder decoder;

    setUp(() {
      decoder = PointsToStaysDecoder();
    });

    test('convert', () {
      expect(() => decoder.convert(GpsPoint.allZero),
          throwsA(isA<UnimplementedError>()));
    });

    test('Chunked conversion', () async {
      final s1 = GpsStay(time: GpsTime(1), latitude: 1, longitude: 2);
      final s2 = GpsStay(time: GpsTime(2), latitude: 3, longitude: 4);
      final stays = [s1, s2];

      final stream = Stream<GpsPoint>.fromIterable(stays);

      final result = <GpsStay>[];
      final staysStream = stream.transform(decoder);
      await for (var s in staysStream) {
        result.add(s);
      }

      checkTestResults(result, stays);
    });
  });
}
