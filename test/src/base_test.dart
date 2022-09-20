/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

typedef PointConstructor = GpsPoint Function(
    {GpsTime? time, double? latitude, double? longitude, double? altitude});

/// Perform basic point tests.
///
/// The [makePoint] function is called to instantiate a point of the correct
/// type for the current class that's being tested.
void testBasicPoint(PointConstructor makePoint) {
  final p = makePoint(
      time: GpsTime.fromUtc(2020), latitude: 10, longitude: 20, altitude: 30);

  test('Check time', () => expect(p.time, GpsTime.fromUtc(2020)));
  test('Check latitude', () => expect(p.latitude, 10));
  test('Check longitude', () => expect(p.longitude, 20));
  test('Check altitude', () => expect(p.altitude, 30));

  // Do a basic equality test for objects with different values in the various
  // fields (testEqualityOfPoints will test for objects that are mostly
  // identical).
  test('Check equality of same object', () => expect(p, p));
  final p2 = makePoint(
      time: p.time,
      latitude: p.latitude,
      longitude: p.longitude,
      altitude: p.altitude);
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
  final p = makePoint();

  test('Check equality of different object with same values',
      () => expect(p, makePoint()));
  test('Check equal hashes of different object with same values',
      () => expect(p.hashCode, makePoint().hashCode));

  testUnequalPoints('date', p, makePoint(time: GpsTime(1)));
  testUnequalPoints('latitude', p, makePoint(latitude: 1));
  testUnequalPoints('longitude', p, makePoint(longitude: 1));
  testUnequalPoints('altitude', p, makePoint(altitude: 1));
}

void main() {
  test('GpsHistoryException', () {
    expect(GpsHistoryException().toString(), 'GpsHistoryException');
    expect(GpsHistoryException('test').toString(), 'GpsHistoryException: test');
  });

  group('Test GpsPoint', () {
    testBasicPoint(GpsPoint.allZero.copyWith);
    testEqualityOfPoints(GpsPoint.allZero.copyWith);
  });

  /// Test correct construction of [GpsMeasurement] from [GpsPoint].
  void testStayFromPoint() {
    test('Correct construction from point', () {
      final p =
          GpsPoint(time: GpsTime(1), latitude: 2, longitude: 3, altitude: 4);
      var s = GpsStay.fromPoint(p, accuracy: 5, endTime: GpsTime(6));
      expect(
          s,
          GpsStay(
              time: GpsTime(1),
              latitude: 2,
              longitude: 3,
              altitude: 4,
              accuracy: 5,
              endTime: GpsTime(6)));
    });
  }

  void testStayEndTime() {
    test('Handling of null endTime (implicitly equal to time)', () {
      // Check that null endTime is regarded as equal to time.
      final s = GpsStay(time: GpsTime(1), latitude: 2, longitude: 3);
      expect(s.endTime, GpsTime(1),
          reason: 'endTime not determined based on time');
      final s2 = s.copyWith(time: GpsTime(50));
      // Check that this works even after time is redefined in a copy.
      expect(s2.endTime, GpsTime(50),
          reason: 'endTime not determined based on time after copyWith');
    });

    test('Invalid endTime at construction time', () {
      expect(
          () => {
                GpsStay(
                  time: GpsTime(2),
                  latitude: 1,
                  longitude: 2,
                  // endTime before time should throw an exception
                  endTime: GpsTime(1),
                )
              },
          throwsA(isA<GpsInvalidValue>()));
    });

    test('copyWith handling of times', () {
      // Creating a copy of an item with a fixed endTime such that the time
      // of the copy is after the original's endTime gives an invalid object
      // and hence an exception must be thrown.
      final s = GpsStay(
          time: GpsTime(1), latitude: 2, longitude: 3, endTime: GpsTime(2));
      expect(() => {s.copyWith(time: GpsTime(3))},
          throwsA(isA<GpsInvalidValue>()));
    });
  }

  group('Test GpsStay', () {
    // For basic point tests we want to have all fields different values, so any
    // mistaken implementation doesn't accidentally pass a test due to the
    // wrong fields being compared, that happen to have the same default value.
    final makeStay =
        GpsStay.allZero.copyWith(accuracy: 400, endTime: null).copyWith;
    testBasicPoint(makeStay);

    testStayFromPoint();

    testStayEndTime();

    // run specific tests that are not covered by the basic point test
    final s = makeStay(
        time: GpsTime(2020),
        latitude: 10,
        longitude: 20,
        altitude: 30,
        endTime: GpsTime(2022));
    test('Check accuracy', () => expect(s.accuracy, 400));
    test('Check endTime', () => expect(s.endTime, GpsTime(2022)));

    // For equality tests we want all fields as equal as possible, because we
    // will vary one field at a time. That way a mistaken implementation doesn't
    // accidentally pass due to fields being unequal just because they're in
    // reality different fields.
    testEqualityOfPoints(GpsStay.allZero.copyWith);

    final sz = GpsStay.allZero;
    testUnequalPoints('accuracy', sz, GpsStay.allZero.copyWith(accuracy: 1));
    testUnequalPoints(
        'heading', sz, GpsMeasurement.allZero.copyWith(time: GpsTime(2022)));
  });

  /// Test correct construction of [GpsMeasurement] from [GpsPoint].
  void testMeasurementFromPoint() {
    test('Check correct construction from point', () {
      final p =
          GpsPoint(time: GpsTime(1), latitude: 2, longitude: 3, altitude: 4);
      final m = GpsMeasurement.fromPoint(p,
          accuracy: 5, heading: 6, speed: 7, speedAccuracy: 8);
      expect(
          m,
          GpsMeasurement(
              time: GpsTime(1),
              latitude: 2,
              longitude: 3,
              altitude: 4,
              accuracy: 5,
              heading: 6,
              speed: 7,
              speedAccuracy: 8));
    });
  }

  group('Test GpsMeasurement nulls', () {
    final m = GpsMeasurement(
        time: GpsTime(2020), latitude: 10, longitude: 20, altitude: 30);

    test('Check accuracy', () => expect(m.accuracy, null));
    test('Check heading', () => expect(m.heading, null));
    test('Check speed', () => expect(m.speed, null));
    test('Check speedAccuracy', () => expect(m.speedAccuracy, null));
  });

  group('Test GpsMeasurement', () {
    // For basic point tests we want to have all fields different values, so any
    // mistaken implementation doesn't accidentally pass a test due to the
    // wrong fields being compared, that happen to have the same default value.
    final makeMeasurement = GpsMeasurement.allZero
        .copyWith(
          accuracy: 400,
          heading: 500,
          speed: 600,
          speedAccuracy: 700,
        )
        .copyWith;
    testBasicPoint(makeMeasurement);

    testMeasurementFromPoint();

    // run specific tests that are not covered by the basic point test
    final m = makeMeasurement(
        time: GpsTime(2020), latitude: 10, longitude: 20, altitude: 30);
    test('Check accuracy', () => expect(m.accuracy, 400));
    test('Check heading', () => expect(m.heading, 500));
    test('Check speed', () => expect(m.speed, 600));
    test('Check speedAccuracy', () => expect(m.speedAccuracy, 700));

    // For equality tests we want all fields as equal as possible, because we
    // will vary one field at a time. That way a mistaken implementation doesn't
    // accidentally pass due to fields being unequal just because they're in
    // reality different fields.
    testEqualityOfPoints(GpsMeasurement.allZero.copyWith);

    final mz = GpsMeasurement.allZero;
    testUnequalPoints(
        'accuracy', mz, GpsMeasurement.allZero.copyWith(accuracy: 1));
    testUnequalPoints(
        'heading', mz, GpsMeasurement.allZero.copyWith(heading: 1));
    testUnequalPoints('speed', mz, GpsMeasurement.allZero.copyWith(speed: 1));
    testUnequalPoints(
        'speedAccuracy', mz, GpsMeasurement.allZero.copyWith(speedAccuracy: 1));
  });

  group('Test GpsMeasurement nulls', () {
    final m = GpsMeasurement(
        time: GpsTime(2020), latitude: 10, longitude: 20, altitude: 30);

    test('Check accuracy', () => expect(m.accuracy, null));
    test('Check heading', () => expect(m.heading, null));
    test('Check speed', () => expect(m.speed, null));
    test('Check speedAccuracy', () => expect(m.speedAccuracy, null));
  });
}
