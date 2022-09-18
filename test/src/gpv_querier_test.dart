/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

void main() {
  group('Test GpvQuerier', () {
    final points = GpcListBased<GpsPoint>()
      ..addAll([
        GpsPoint(time: DateTime.utc(1), latitude: 1, longitude: 1, altitude: 1),
        GpsPoint(time: DateTime.utc(2), latitude: 2, longitude: 2, altitude: 2),
        GpsPoint(time: DateTime.utc(3), latitude: 3, longitude: 3, altitude: 3),
      ]);

    test('Check backwards', () {
      var view = GpvQuerier(points, Int32List.fromList([2, 0]));
      expect(view.length, 2, reason: 'incorrect length');
      expect(view[0], points[2], reason: 'incorrect first item');
      expect(view[1], points[0], reason: 'incorrect last item');
    });
  });
}
