/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

typedef PointConstructor = GpsPoint Function(
    DateTime date, double latitude, double longitude, double? altitude);

/// Perform basic point tests.
///
/// The [makePoint] function should be such that it creates a point that has
/// different values for all fields.
void testBasicPoint(PointConstructor makePoint) {
  final p = makePoint(DateTime.utc(2020), 10, 20, 30);

  test('Check time', () => expect(p.time, DateTime.utc(2020)));
  test('Check latitude', () => expect(p.latitude, 10));
  test('Check longitude', () => expect(p.longitude, 20));
  test('Check altitude', () => expect(p.altitude, 30));

  // Do a basic equality test for objects with different values in the various
  // fields (testEqualityOfPoints will test for objects that are mostly
  // identical).
  test('Check equality of same object', () => expect(p, p));
  final p2 = makePoint(p.time, p.latitude, p.longitude, p.altitude);
  test('Check equality of different object with same values',
      () => expect(p, p2));
  test('Check same hash for different object with same values',
      () => expect(p.hashCode, p2.hashCode));
}

void testUnequalPoints(String description, GpsPoint p0, GpsPoint p1) {
  test('Check inequality by $description', () => expect(p0 == p1, false));

  test('Check different hash for objects with different values',
      () => expect(p0.hashCode == p1.hashCode, false));
}

/// Perform equality tests on points.
///
/// The [makePoint] function should be optimized to create a point that has the
/// same value for all fields.
void testEqualityOfPoints(PointConstructor makePoint) {
  // Test against an all-zeroes point, so we can vary one field at a time to
  // make sure that the comparisons work properly.
  final p = makePoint(DateTime.utc(0), 0, 0, 0);

  test('Check equality of different object with same values',
      () => expect(p, makePoint(DateTime.utc(0), 0, 0, 0)));
  test('Check equal hashes of different object with same values',
      () => expect(p.hashCode, makePoint(DateTime.utc(0), 0, 0, 0).hashCode));

  testUnequalPoints('date', p, makePoint(DateTime.utc(1), 0, 0, 0));
  testUnequalPoints('latitude', p, makePoint(DateTime.utc(0), 1, 0, 0));
  testUnequalPoints('longitude', p, makePoint(DateTime.utc(0), 0, 1, 0));
  testUnequalPoints('altitude', p, makePoint(DateTime.utc(0), 0, 0, 1));
}

void main() {
  group('Test GpsPoint', () {
    makePoint(DateTime date, double latitude, double longitude,
            double? altitude) =>
        GpsPoint(date, latitude, longitude, altitude);

    testBasicPoint(makePoint);
    testEqualityOfPoints(makePoint);
  });

  /// Test correct construction of [GpsMeasurement] from [GpsPoint].
  void testMeasurementFromPoint() {
    test('Check correct construction from point', () {
      final p = GpsPoint(DateTime.utc(1), 2, 3, 4);
      final m = GpsMeasurement.fromPoint(p, 5, 6, 7, 8);
      expect(m, GpsMeasurement(DateTime.utc(1), 2, 3, 4, 5, 6, 7, 8));
    });
  }

  group('Test GpsMeasurement', () {
    // For basic point tests we want to have all fields different values, so any
    // mistaken implementation doesn't accidentally pass a test due to the
    // wrong fields being compared, that happen to have the same default value.
    makeMeasurement(DateTime date, double latitude, double longitude,
            double? altitude) =>
        GpsMeasurement(date, latitude, longitude, altitude, 400, 500, 600, 700);
    testBasicPoint(makeMeasurement);

    testMeasurementFromPoint();

    // run specific tests that are not covered by the basic point test
    final m = makeMeasurement(DateTime.utc(2020), 10, 20, 30);
    test('Check accuracy', () => expect(m.accuracy, 400));
    test('Check heading', () => expect(m.heading, 500));
    test('Check speed', () => expect(m.speed, 600));
    test('Check speedAccuracy', () => expect(m.speedAccuracy, 700));

    // For equality tests we want all fields as equal as possible, because we
    // will vary one field at a time. That way a mistaken implementation doesn't
    // accidentally pass due to fields being unequal just because they're in
    // reality different fields.
    makeMeasurementWithNulls(DateTime date, double latitude, double longitude,
            double? altitude) =>
        GpsMeasurement(date, latitude, longitude, altitude, 0, 0, 0, 0);
    testEqualityOfPoints(makeMeasurementWithNulls);
    final mz = makeMeasurementWithNulls(DateTime.utc(0), 0, 0, 0);
    testUnequalPoints(
        'accuracy', mz, GpsMeasurement(DateTime.utc(0), 0, 0, 0, 1, 0, 0, 0));
    testUnequalPoints(
        'heading', mz, GpsMeasurement(DateTime.utc(0), 0, 0, 0, 0, 1, 0, 0));
    testUnequalPoints(
        'speed', mz, GpsMeasurement(DateTime.utc(0), 0, 0, 0, 0, 0, 1, 0));
    testUnequalPoints('speedAccuracy', mz,
        GpsMeasurement(DateTime.utc(0), 0, 0, 0, 0, 0, 0, 1));
  });

  group('Test GpsMeasurement nulls', () {
    final m =
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, null, null, null, null);

    test('Check accuracy', () => expect(m.accuracy, null));
    test('Check heading', () => expect(m.heading, null));
    test('Check speed', () => expect(m.speed, null));
    test('Check speedAccuracy', () => expect(m.speedAccuracy, null));
  });
}
