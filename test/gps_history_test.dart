/*
 * Copyright (c) 
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
}
