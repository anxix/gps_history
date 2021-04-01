/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';
import 'gpc_test_skeleton.dart';

// static int altitudeToInt16(double value)
// static double int16ToAltitude(int value)

void testConversions() {
  test('Check degrees to Int32 conversions', () {
    // Check that converting back and forth gives the same value.
    for (var i = -180 * 4; i <= 180 * 4; i++) {
      final deg = i / 4;
      expect(Conversions.int32ToDegrees(Conversions.degreesToInt32(deg)), deg);
    }

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.degreesToInt32(15.3), 153000000);
    expect(Conversions.degreesToInt32(-179.2), -1792000000);

    // Check the caps
    expect(Conversions.degreesToInt32(180.0), 1800000000);
    expect(Conversions.degreesToInt32(-180.0), -1800000000);
    expect(Conversions.degreesToInt32(180.00001), 1800000000);
    expect(Conversions.degreesToInt32(-180.00001), -1800000000);
  });

  test('Check time to Uint32 conversions', () {
    // Check that converting back and forth gives the same value.
    for (var year = 2000; year <= 2020; year++) {
      for (var month = 1; month <= 12; month += 3) {
        final t = DateTime.utc(year, month);
        expect(
            Conversions.uint32ToDateTime(Conversions.dateTimeToUint32(t)), t);
      }
    }

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.dateTimeToUint32(DateTime.utc(1970)), 0);
    expect(
        // 1.002003 seconds after t=0
        Conversions.dateTimeToUint32(DateTime.utc(1970, 1, 1, 0, 0, 1, 2, 3)),
        1);

    // Check the caps.
    expect(Conversions.dateTimeToUint32(DateTime.utc(1969)), 0);
    expect(
        // Two values after the max should both encode to the same integer.
        Conversions.uint32ToDateTime(
            Conversions.dateTimeToUint32(DateTime.utc(5000))),
        Conversions.uint32ToDateTime(
            Conversions.dateTimeToUint32(DateTime.utc(2106, 12))));
  });

  test('Check altitude to Int16 conversions', () {
    // Check that converting back and forth gives the same value.
    for (var i = 100; i <= 100; i++) {
      final altitude = i / 2;
      expect(Conversions.int16ToAltitude(Conversions.altitudeToInt16(altitude)),
          altitude);
    }

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.altitudeToInt16(15.3), 31);
    expect(Conversions.altitudeToInt16(-10.2), -20);

    // Check the caps
    expect(Conversions.altitudeToInt16(-999999), -32767);
    expect(Conversions.altitudeToInt16(999999), 32767);
  });
}

void main() {
  testConversions();

  testGpsPointsCollection<GpsPoint>(
      'GpcEfficientGpsPoint',
      () => GpcEfficientGpsPoint(),
      (int i) => GpsPoint(
          // The constraints of GpcEfficientGpsPoint mean the date must be
          // somewhat reasonable, so we can't just use year 1.
          DateTime.utc(2000 + i),
          i.toDouble(),
          i.toDouble(),
          i.toDouble()));
}
