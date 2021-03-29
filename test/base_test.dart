/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

testUnequalPoints(String description, GpsPoint p0, GpsPoint p1) {
  test('Check inequality by $description', () => expect(p0 == p1, false));
}

testBasicPoint(GpsPoint p) {
  test('Check time', () => expect(p.time, DateTime.utc(2020)));
  test('Check latitude', () => expect(p.latitude, 10));
  test('Check longitude', () => expect(p.longitude, 20));
  test('Check altitude', () => expect(p.altitude, 30));
  test('Check equality of same object', () => expect(p, p));
}

void main() {
  group('Test GpsPoint', () {
    GpsPoint p = GpsPoint(DateTime.utc(2020), 10, 20, 30);

    testBasicPoint(p);
    test('Check equality of different object with same values',
        () => expect(p, GpsPoint(DateTime.utc(2020), 10, 20, 30)));
    testUnequalPoints('date', p, GpsPoint(DateTime.utc(2021), 10, 20, 30));
    testUnequalPoints('latitude', p, GpsPoint(DateTime.utc(2020), 11, 20, 30));
    testUnequalPoints('longitude', p, GpsPoint(DateTime.utc(2020), 10, 21, 30));
    testUnequalPoints('altitude', p, GpsPoint(DateTime.utc(2020), 10, 20, 31));
  });

  group('Test GpsMeasurement', () {
    GpsMeasurement m =
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 60, 70);

    testBasicPoint(m);
    test(
        'Check equality of different object with same values',
        () => expect(
            m, GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 60, 70)));
    testUnequalPoints('date', m,
        GpsMeasurement(DateTime.utc(2021), 10, 20, 30, 40, 50, 60, 70));
    testUnequalPoints('latitude', m,
        GpsMeasurement(DateTime.utc(2020), 11, 20, 30, 40, 50, 60, 70));
    testUnequalPoints('longitude', m,
        GpsMeasurement(DateTime.utc(2020), 10, 21, 30, 40, 50, 60, 70));
    testUnequalPoints('altitude', m,
        GpsMeasurement(DateTime.utc(2020), 10, 20, 31, 40, 50, 60, 70));
    testUnequalPoints('accuracy', m,
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 41, 50, 60, 70));
    testUnequalPoints('heading', m,
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 51, 60, 70));
    testUnequalPoints('speed', m,
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 61, 70));
    testUnequalPoints('speedAccuracy', m,
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 60, 71));
  });

  group('Test GpsMeasurement nulls', () {
    GpsMeasurement m =
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, null, null, null, null);

    test('Check accuracy', () => expect(m.accuracy, null));
    test('Check heading', () => expect(m.heading, null));
    test('Check speed', () => expect(m.speed, null));
    test('Check speedAccuracy', () => expect(m.speedAccuracy, null));
  });
}
