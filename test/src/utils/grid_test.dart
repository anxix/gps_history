/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/src/utils/grid.dart';
import 'package:test/test.dart';

void main() {
  group('Grid', () {
    late GpcCompactGpsPoint gpc;

    setUp(() {
      gpc = GpcCompactGpsPoint();
    });

    test('Empty', () {
      final grid = Grid(gpc);
      var nrCells = 0;
      grid.forEachCell((itemsInCell) {
        nrCells++;
      });
      expect(nrCells, 0);
    });

    test('Single item', () {
      final point = GpsPoint.allZero;
      gpc.add(point);
      final grid = Grid(gpc);
      var nrCells = 0;
      grid.forEachCell((itemsInCell) {
        nrCells++;
        expect(itemsInCell[0], 0);
      });
      expect(nrCells, 1);
    });

    test('Multiple different items', () {
      gpc.sortingEnforcement = SortingEnforcement.notRequired;
      final point = GpsPoint.allZero;
      gpc.add(point);
      gpc.add(point.copyWith(latitude: 1, longitude: 1));
      gpc.add(gpc[0]);
      gpc.add(gpc[0]);
      final grid = Grid(gpc);
      var nrCells = 0;
      grid.forEachCell((itemsInCell) {
        if (itemsInCell.length == 1) {
          nrCells++;
          expect(itemsInCell[0], 1, reason: 'wrong one-item cell');
        } else if (itemsInCell.length == 3) {
          nrCells++;
          expect(itemsInCell[0], 0, reason: 'wrong three-item cell');
          expect(itemsInCell[1], 2, reason: 'wrong three-item cell');
          expect(itemsInCell[2], 3, reason: 'wrong three-item cell');
        }
      });
      expect(nrCells, 2);
    });
  });
}
