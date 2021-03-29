/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

void main() {
  group('Test GpsPoint', () {
    GpsPoint point = GpsPoint(DateTime.utc(2020), 10, 20, 30);

    test('Check time', () => expect(point.time, DateTime.utc(2020)));
    test('Check latitude', () => expect(point.latitude, 10));
    test('Check longitude', () => expect(point.longitude, 20));
    test('Check altitude', () => expect(point.altitude, 30));
    test('Check equality of same object', () => expect(point, point));
    test('Check equality of different object with same values',
        () => expect(point, GpsPoint(DateTime.utc(2020), 10, 20, 30)));
    test('Check inequality by date',
        () => expect(point == GpsPoint(DateTime.utc(2021), 10, 20, 30), false));
    test('Check inequality by latitude',
        () => expect(point == GpsPoint(DateTime.utc(2020), 11, 20, 30), false));
    test('Check inequality by longitude',
        () => expect(point == GpsPoint(DateTime.utc(2020), 10, 21, 30), false));
    test('Check inequality by altitude',
        () => expect(point == GpsPoint(DateTime.utc(2020), 10, 20, 31), false));
  });

  group('Test GpsMeasurement', () {
    GpsMeasurement m =
        GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 60, 70);

    test('Check time', () => expect(m.time, DateTime.utc(2020)));
    test('Check latitude', () => expect(m.latitude, 10));
    test('Check longitude', () => expect(m.longitude, 20));
    test('Check altitude', () => expect(m.altitude, 30));
    test('Check accuracy', () => expect(m.accuracy, 40));
    test('Check heading', () => expect(m.heading, 50));
    test('Check speed', () => expect(m.speed, 60));
    test('Check speedAccuracy', () => expect(m.speedAccuracy, 70));
    test('Check equality of same object', () => expect(m, m));
    test(
        'Check equality of different object with same values',
        () => expect(
            m, GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 60, 70)));
    test(
        'Check inequality by date',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2021), 10, 20, 30, 40, 50, 60, 70),
            false));
    test(
        'Check inequality by latitude',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2020), 11, 20, 30, 40, 50, 60, 70),
            false));
    test(
        'Check inequality by longitude',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2020), 10, 21, 30, 40, 50, 60, 70),
            false));
    test(
        'Check inequality by altitude',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2020), 10, 20, 31, 40, 50, 60, 70),
            false));
    test(
        'Check inequality by accuracy',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 41, 50, 60, 70),
            false));
    test(
        'Check inequality by heading',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 51, 60, 70),
            false));
    test(
        'Check inequality by speed',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 61, 70),
            false));
    test(
        'Check inequality by speedAccuracy',
        () => expect(
            m == GpsMeasurement(DateTime.utc(2020), 10, 20, 30, 40, 50, 60, 71),
            false));
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
