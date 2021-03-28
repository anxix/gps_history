/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:test/test.dart';

void main() {
  group('Test GpsPoint', () {
    GpsPoint point = GpsPoint(DateTime.utc(2020), 10, 20, 30);

    test('Check time', () => expect(point.time, DateTime.utc(2020)));
    test('Check latitude', () => expect(point.latitude, 10));
    test('Check longitude', () => expect(point.longitude, 20));
    test('Check altitude', () => expect(point.altitude, 30));
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
