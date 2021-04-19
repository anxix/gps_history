/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history_persist.dart';

void testGetFirstNonAsciiCharIndex() {
  test('getFirstNonAsciiCharIndex', () {
    // Test all invalid char codes before the space.
    for (var charChode = 0; charChode < 32; charChode++) {
      final s = String.fromCharCode(charChode);
      expect(getFirstNonAsciiCharIndex(s), 0,
          reason: 'Incorrect result for charCode=$charChode');
    }

    // Test some invalid char codes after ~.
    for (var charChode = 127; charChode < 1000; charChode++) {
      var s = String.fromCharCode(charChode);
      expect(getFirstNonAsciiCharIndex(s), 0,
          reason: 'Incorrect result for charCode=$charChode');
    }

    // Test valid char codes.
    for (var charChode = 32; charChode <= 126; charChode++) {
      final s = String.fromCharCode(charChode);
      expect(getFirstNonAsciiCharIndex(s), null,
          reason: 'Incorrect result for charCode=$charChode');
    }

    // Test multi-char strings.
    expect(getFirstNonAsciiCharIndex('string'), null,
        reason: 'String with all-valid chars');
    expect(getFirstNonAsciiCharIndex('str\ning'), 3,
        reason: 'String with one invalid char');
  });
}

void main() {
  testGetFirstNonAsciiCharIndex();
}
