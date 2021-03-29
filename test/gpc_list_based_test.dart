/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

// @override
// forEach(void f(T element)) => _points.forEach((element) {
//       f(element);
//     });

// addAll(Iterable<T> iterable) {
//   _points.addAll(iterable);
// }

void main() {
  group('Test GpcListBased', () {
    GpcListBased<GpsPoint>? gpc;

    setUp(() {
      gpc = GpcListBased<GpsPoint>();
    });

    test('Check length empty', () => expect(gpc!.length, 0));

    test('Check simple add and indexing', () {
      // basic tests with just one point
      var p0 = GpsPoint(DateTime.utc(2000), 1, 2, 3);
      gpc!.add(p0);
      expect(gpc!.length, 1, reason: 'wrong length after first add');
      expect(gpc![0], p0, reason: 'wrong point after first add');

      // basic tests with a second point
      var p1 = GpsPoint(DateTime.utc(2001), 3, 4, 5);
      gpc!.add(p1);
      expect(gpc!.length, 2, reason: 'wrong length after second add');
      expect(gpc![0], p0, reason: 'wrong point at [0] after second add');
      expect(gpc![1], p1, reason: 'wrong point at [1] after second add');
    });

    test('Check AddAll', () {
      var src = List<GpsPoint>.filled(2, GpsPoint(DateTime.utc(0), 0, 0, 0),
          growable: true);

      for (var i = 0; i < src.length; i++) {
        src[i] = GpsPoint(DateTime.utc(2000 + i), i.toDouble(),
            2 * i.toDouble(), 3 * i.toDouble());
      }

      gpc!.addAll(src);
      expect(gpc!.length, src.length, reason: 'wrong length after addAll');
      for (var i = 0; i < src.length; i++) {
        expect(gpc![i], src[i], reason: 'incorrect point at position $i');
      }
    });
  });
}
