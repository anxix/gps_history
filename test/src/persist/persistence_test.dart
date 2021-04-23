/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history_persist.dart';

/// Checks that the standard [Persistence] class behaves correctly as a
/// singleton.
void testSingletonBehaviour() {
  test('Singleton behaviour', () {
    final p0 = Persistence();
    final p1 = Persistence();
    expect(identical(p0, p1), true,
        reason: 'Factory did not return identical object (singleton).');
    expect(p0 != null, true,
        reason: 'Factory returned null instead of singleton instance.');
  });
}

void main() {
  testSingletonBehaviour();
}
