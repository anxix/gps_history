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
    testFor(int start1, int end1, int start2, int end2, expected) {
      // Test in the specified order.
      expect(
          compareTimeSpans(
              startA: start1, endA: end1, startB: start2, endB: end2),
          expected,
          reason: 'Wrong for time span ($start1, $end1), ($start2, $end2)');

      // Test calling in the opposite order (span 2, then 1).
      final expectedOpposite = opposite(expected);
      expect(
          compareTimeSpans(
              startA: start2, endA: end2, startB: start1, endB: end1),
          expectedOpposite,
          reason: 'Wrong for time span ($start2, $end2), ($start1, $end1)');
    }

    test('A before B / B before A', () {
      // Because the test also runs in opposite order, this implicitly also
      // tests B before A.

      // Separated spans.
      testFor(1, 2, 3, 4, TimeComparisonResult.before);

      // Adjacent spans.
      testFor(1, 2, 2, 4, TimeComparisonResult.before);

      // Meeting at end point
      testFor(1, 3, 3, 3, TimeComparisonResult.before);
    });
    test('A equal to B', () {
      // Test nonzero span.
      testFor(1, 2, 1, 2, TimeComparisonResult.same);
      // Test moment.
      testFor(1, 1, 1, 1, TimeComparisonResult.same);
    });

    test('A overlapping B', () {
      // Overlap from start.
      testFor(1, 2, 1, 3, TimeComparisonResult.overlapping);
      // Overlap to the end.
      testFor(1, 3, 2, 3, TimeComparisonResult.overlapping);
      // Overlap at start point.
      testFor(1, 3, 1, 1, TimeComparisonResult.overlapping);
      // Overlap in the middle.
      testFor(1, 4, 2, 3, TimeComparisonResult.overlapping);
      // Overlap in the middle point.
      testFor(1, 4, 2, 2, TimeComparisonResult.overlapping);
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

      expect(() {
        GpsTime(4294967295);
      }, throwsA(isA<RangeError>()),
          reason: 'Value higher than max should throw exception');
    });

    test('Constructors and factories', () {
      // Clamped constuctor.
      expect(GpsTime(0), GpsTime(-1, autoClamp: true),
          reason: 'wrong for clamped');
      expect(GpsTime(GpsTime.maxSecondsSinceEpoch),
          GpsTime(GpsTime.maxSecondsSinceEpoch + 1, autoClamp: true),
          reason: 'wrong for clamped');

      // fromDateTime
      expect(
          GpsTime(10), GpsTime.fromDateTime(DateTime.utc(1970, 1, 1, 0, 0, 10)),
          reason: 'wrong for fromDateTime');

      // fromMillisecondsSinceEpochUtc
      expect(GpsTime(10), GpsTime.fromMillisecondsSinceEpochUtc(10000),
          reason: 'wrong for fromMillisecondsSinceEpochUtc');

      // fromUtc
      expect(
          GpsTime.fromUtc(1971,
              month: 2, day: 3, hour: 4, minute: 5, second: 6),
          // a datetime with some extra milliseconds/microseconds should be rounded
          GpsTime.fromDateTime(DateTime.utc(1971, 2, 3, 4, 5, 6, 123, 456)),
          reason: 'wrong for fromUtc rounding down');
      expect(
          GpsTime.fromUtc(1971,
              month: 2, day: 3, hour: 4, minute: 5, second: 6),
          // a datetime with some extra milliseconds/microseconds should be rounded
          GpsTime.fromDateTime(DateTime.utc(1971, 2, 3, 4, 5, 5, 567, 890)),
          reason: 'wrong for fromUtc rounding up');
    });

    test('Comparisons', () {
      // compareTo
      expect(GpsTime(1).compareTo(GpsTime(2)), TimeComparisonResult.before,
          reason: '1 < 2');
      expect(GpsTime(2).compareTo(GpsTime(2)), TimeComparisonResult.same,
          reason: '2 = 2');
      expect(GpsTime(3).compareTo(GpsTime(2)), TimeComparisonResult.after,
          reason: '3 > 2');

      // isAfter
      expect(GpsTime(1).isAfter(GpsTime(0)), true, reason: '1 > 0');
      expect(GpsTime(1).isAfter(GpsTime(2)), false, reason: '1 < 2');
      expect(GpsTime(1).isAfter(GpsTime(1)), false, reason: '1 = 1');

      // isBefore
      expect(GpsTime(0).isBefore(GpsTime(1)), true, reason: '0 < 1');
      expect(GpsTime(2).isBefore(GpsTime(1)), false, reason: '2 < 1');
      expect(GpsTime(0).isBefore(GpsTime(0)), false, reason: '0 = 0');

      // ==
      expect(GpsTime(0) == (GpsTime(0)), true, reason: '0 = 0');
      expect(GpsTime(4) == (GpsTime(5)), false, reason: '4 != 5');
      expect(GpsTime(4) == (GpsTime(3)), false, reason: '4 != 3');
    });

    test('Hash', () {
      expect(GpsTime(0).hashCode != GpsTime(1).hashCode, true,
          reason: 'different time values should have different hashes');

      expect(
          GpsTime(0).hashCode ==
              GpsTime.fromMillisecondsSinceEpochUtc(0).hashCode,
          true,
          reason: 'same time values should have same hash');
    });

    test('Add', () {
      expect(GpsTime.zero.add(days: 1, hours: 2, minutes: 3, seconds: 4),
          GpsTime(24 * 3600 + 2 * 3600 + 3 * 60 + 4));
      expect(GpsTime(1).add(seconds: -1), GpsTime(0));
    });

    test('Difference', () {
      expect(GpsTime(10).difference(GpsTime(7)), 3);
    });

    test('toDateTime', () {
      expect(GpsTime(10).toDateTimeUtc(),
          DateTime.fromMillisecondsSinceEpoch(10000, isUtc: true));
    });
  });
}
