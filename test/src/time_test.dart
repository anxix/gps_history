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
    GpsTime intToDateTime(int time) {
      return GpsTime(time);
    }

    testFor(a, b, expectedResult) {
      expect(compareTime(intToDateTime(a), intToDateTime(b)), expectedResult);
      expect(compareIntRepresentationTime(a, b), expectedResult);
    }

    testFor(1, 2, TimeComparisonResult.before);
    testFor(1, 1, TimeComparisonResult.same);
    testFor(2, 1, TimeComparisonResult.after);
  });

  group('Timespan comparisons', () {
    testFor(int start1, int end1, int start2, int end2, expectedResult,
        expectedResultOpposite) {
      // Test in the specified order.
      expect(
          compareTimeSpans(
              startA: start1, endA: end1, startB: start2, endB: end2),
          expectedResult,
          reason: 'Wrong for time span ($start1, $end1), ($start2, $end2)');

      // Test calling in the opposite order (span 2, then 1).
      expect(
          compareTimeSpans(
              startA: start2, endA: end2, startB: start1, endB: end1),
          expectedResultOpposite,
          reason: 'Wrong for time span ($start2, $end2), ($start1, $end1)');
    }

    test('A before B / B before A', () {
      // Because the test also runs in opposite order, this implicitly also
      // tests B before A.

      // Separated spans.
      testFor(
          1, 2, 3, 4, TimeComparisonResult.before, TimeComparisonResult.after);

      // Adjacent spans.
      testFor(
          1, 2, 2, 4, TimeComparisonResult.before, TimeComparisonResult.after);

      // Meeting at end point
      testFor(
          1, 3, 3, 3, TimeComparisonResult.before, TimeComparisonResult.after);
    });
    test('A equal to B', () {
      // Test nonzero span.
      testFor(1, 2, 1, 2, TimeComparisonResult.same, TimeComparisonResult.same);
      // Test moment.
      testFor(1, 1, 1, 1, TimeComparisonResult.same, TimeComparisonResult.same);
    });

    test('A overlapping B', () {
      // Overlap from start.
      testFor(1, 2, 1, 3, TimeComparisonResult.overlapping,
          TimeComparisonResult.overlapping);
      // Overlap to the end.
      testFor(1, 3, 2, 3, TimeComparisonResult.overlapping,
          TimeComparisonResult.overlapping);
      // Overlap at start point.
      testFor(1, 3, 1, 1, TimeComparisonResult.overlapping,
          TimeComparisonResult.overlapping);
      // Overlap in the middle.
      testFor(1, 4, 2, 3, TimeComparisonResult.overlapping,
          TimeComparisonResult.overlapping);
      // Overlap in the middle point.
      testFor(1, 4, 2, 2, TimeComparisonResult.overlapping,
          TimeComparisonResult.overlapping);
    });
  });

  group('GpsTime', () {
    test('Invalid times', () {
      expect(() {
        GpsTime(-1);
      }, throwsA(isA<RangeError>()),
          reason: 'Pre-epoch value should throw exception');
      expect(() {
        GpsTime.fromUtc(2110);
      }, throwsA(isA<RangeError>()),
          reason: 'Value higher than max should throw exception');
    });
  });
}
