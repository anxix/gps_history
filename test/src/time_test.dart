/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/src/time.dart';
import 'package:test/test.dart';

void main() {
  test('Time comparisons', () {
    // Simple comparisons on standalone entities.
    DateTime intToDateTime(int time) {
      return DateTime.utc(time);
    }

    expect(compareTime(intToDateTime(1), intToDateTime(2)),
        TimeComparisonResult.before);
    expect(compareTime(intToDateTime(1), intToDateTime(1)),
        TimeComparisonResult.same);
    expect(compareTime(intToDateTime(2), intToDateTime(1)),
        TimeComparisonResult.after);
  });
}
