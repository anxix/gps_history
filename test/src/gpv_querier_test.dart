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
    final _points = GpcListBased<GpsPoint>()
      ..addAll([
        GpsPoint(DateTime.utc(1), 1, 1, 1),
        GpsPoint(DateTime.utc(2), 2, 2, 2),
        GpsPoint(DateTime.utc(3), 3, 3, 3),
      ]);

    test('Check backwards', () {
      var view = GpvQuerier(_points, Int32List.fromList([2, 0]));
      expect(view.length, 2, reason: 'incorrect length');
      expect(view[0], _points[2], reason: 'incorrect first item');
      expect(view[1], _points[0], reason: 'incorrect last item');
    });
  });
}
