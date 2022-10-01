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
  group('GpvQuerier', () {
    late GpcListBased<GpsPoint> points;

    setUp(() {
      points = GpcListBased<GpsPoint>();
      for (var i = 0; i < 10; i++) {
        points.add(GpsPoint(
            time: GpsTime(i + 1),
            latitude: i.toDouble(),
            longitude: i.toDouble(),
            altitude: i.toDouble()));
      }
    });

    test('Readonly', () {
      final view = GpvQuerier(points, Int32List.fromList([2, 0]));
      // GpvQuerier entities should be readonly.
      expect(view.isReadonly, true);
    });

    test('Backwards', () {
      final view = GpvQuerier(points, Int32List.fromList([2, 0]));
      expect(view.length, 2, reason: 'incorrect length');
      expect(view[0], points[2], reason: 'incorrect first item');
      expect(view[1], points[0], reason: 'incorrect last item');
    });

    test('Sublist', () {
      final view =
          GpvQuerier(points, Int32List.fromList([0, 1, 2, 3, 4, 5, 6]));
      final sublist = view.sublist(3, 5);

      expect(sublist.runtimeType, view.runtimeType,
          reason: 'expected same type to be returned by sublist()');

      expect(sublist.length, 2, reason: 'incorrect length');

      for (var i = 0; i < sublist.length; i++) {
        expect(sublist[i], view[i + 3], reason: 'Wrong item at position $i');
      }
    });

    test('NewEmpty', () {
      final view =
          GpvQuerier(points, Int32List.fromList([0, 1, 2, 3, 4, 5, 6]));
      final newEmpty = view.newEmpty();

      expect(newEmpty.runtimeType, view.runtimeType,
          reason: 'expected same type to be returned by newEmpty()');
      expect(newEmpty.length, 0);
    });
  });
}
