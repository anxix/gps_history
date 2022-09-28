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
  group('PointMerger', () {
    final maxTimeGapSeconds = 10;
    final maxDistanceGapMeters = 5.0;

    runTest(List<GpsPoint> input, List<GpsStay> expected) {
      final results = <GpsStay>[];
      final merger = PointMerger((result) => results.add(result),
          maxTimeGapSeconds: maxTimeGapSeconds,
          maxDistanceGapMeters: maxDistanceGapMeters);

      for (final point in input) {
        merger.addPoint(point);
      }
      merger.close();

      expect(results.length, expected.length,
          reason: 'Incorrect results length');

      for (var i = 0; i < results.length; i++) {
        final foundPoint = results[i];
        final expectedPoint = expected[i];
        expect(foundPoint, expectedPoint, reason: 'Mismatch at position $i');
      }
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

      runTest([p1, p2], [GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)]);
      runTest([GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)],
          [GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)]);
      runTest([GpsMeasurement.fromPoint(p1), GpsMeasurement.fromPoint(p2)],
          [GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)]);
    });

    test('No merging discontinuous space', () {
      final p1 = GpsPoint(time: GpsTime(2), latitude: 0, longitude: 1);
      final p2 = p1.copyWith(
          time: p1.time.add(seconds: maxTimeGapSeconds - 1),
          latitude: p1.latitude +
              (maxDistanceGapMeters + 1) * 1 / metersPerDegreeLatitude);
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
          latitude: p1.latitude +
              (maxDistanceGapMeters - 1) * 1 / metersPerDegreeLatitude);
      final result = [GpsStay.fromPoint(p1).copyWith(endTime: p2.time)];

      runTest([p1, p2], result);
      runTest([GpsStay.fromPoint(p1), GpsStay.fromPoint(p2)], result);
      runTest(
          [GpsMeasurement.fromPoint(p1), GpsMeasurement.fromPoint(p2)], result);
    });
  });
}
