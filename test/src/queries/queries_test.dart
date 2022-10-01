/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:test/test.dart';

void main() {
  group('QueryCollectionInfo', () {
    test('Empty', () {
      final gpc = GpcListBased();
      final queryResult = QueryCollectionInfo().query(gpc);

      expect(queryResult.firstItemStartTime, null);
      expect(queryResult.lastItemEndTime, null);
      expect(queryResult.length, gpc.length);
    });

    test('Simple', () {
      final gpc = GpcCompactGpsPoint()
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(3)))
        ..add(GpsPoint.allZero.copyWith(time: GpsTime(10)));
      final queryResult = QueryCollectionInfo().query(gpc);

      expect(queryResult.firstItemStartTime, GpsTime(3));
      expect(queryResult.lastItemEndTime, GpsTime(10));
      expect(queryResult.length, gpc.length);
    });
  });
}
