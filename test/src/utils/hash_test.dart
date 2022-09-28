/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/src/utils/hash.dart';
import 'package:test/test.dart';

void main() {
  test('hashing', () {
    // Check consistent hashing between separate calls and hashObjects.
    expect(hash1(1), hashObjects([1]));
    expect(hash2(8, 1), hashObjects([8, 1]));
    expect(hash3(8, 1, 2), hashObjects([8, 1, 2]));
    expect(hash4(8, 1, 2, 3), hashObjects([8, 1, 2, 3]));
    expect(hash5(8, 1, 2, 3, 4), hashObjects([8, 1, 2, 3, 4]));
    expect(hash6(8, 1, 2, 3, 4, 5), hashObjects([8, 1, 2, 3, 4, 5]));
    expect(hash7(8, 1, 2, 3, 4, 5, 6), hashObjects([8, 1, 2, 3, 4, 5, 6]));
    expect(
        hash8(8, 1, 2, 3, 4, 5, 6, 7), hashObjects([8, 1, 2, 3, 4, 5, 6, 7]));

    // Check hashes are indeed different given different input.
    expect(hash1(1) != hash2(1, 1), true,
        reason: 'different calls should give different hashes');
  });
}
