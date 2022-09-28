/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';

import 'package:gps_history/src/utils/binary_conversions.dart';
import 'package:gps_history/src/utils/time.dart';

void main() {
  test('Check latitude to Uint32 conversions', () {
    // Check that converting back and forth gives the same value.
    for (var i = -90 * 4; i <= 90 * 4; i++) {
      final deg = i / 4;
      expect(
          Conversions.uint32ToLatitude(Conversions.latitudeToUint32(deg)), deg);
    }

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.latitudeToUint32(15.3), 1053000000);
    expect(Conversions.latitudeToUint32(-89.2), 8000000);

    // Check the caps
    expect(Conversions.latitudeToUint32(90.0), 1800000000);
    expect(Conversions.latitudeToUint32(-90.0), 0);
    expect(Conversions.latitudeToUint32(90.00001), 1800000000);
    expect(Conversions.latitudeToUint32(-90.00001), 0);
  });

  test('Check longitude to Uint32 conversions', () {
    // Check that converting back and forth gives the same value.
    for (var i = -180 * 4; i <= 180 * 4; i++) {
      final deg = i / 4;
      expect(Conversions.uint32ToLongitude(Conversions.longitudeToUint32(deg)),
          deg);
    }

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.longitudeToUint32(15.3), 1953000000);
    expect(Conversions.longitudeToUint32(-179.2), 8000000);

    // Check the caps
    expect(Conversions.longitudeToUint32(180.0), 3600000000);
    expect(Conversions.longitudeToUint32(-180.0), 0);
    expect(Conversions.longitudeToUint32(180.00001), 3600000000);
    expect(Conversions.longitudeToUint32(-180.00001), 0);
  });

  test('Check time to Uint32 conversions', () {
    // Check that converting back and forth gives the same value.
    for (var year = 2000; year <= 2020; year++) {
      for (var month = 1; month <= 12; month += 3) {
        final t = GpsTime.fromUtc(year, month: month);
        expect(Conversions.uint32ToGpsTime(Conversions.gpsTimeToUint32(t)), t);
      }
    }

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.gpsTimeToUint32(GpsTime.fromUtc(1970)), 0);
    expect(
        // 1 second after t=0
        Conversions.gpsTimeToUint32(GpsTime.fromUtc(1970,
            month: 1, day: 1, hour: 0, minute: 0, second: 1)),
        1);

    // Check the caps.
    expect(() {
      Conversions.gpsTimeToUint32(GpsTime.fromUtc(1969));
    }, throwsA(isA<RangeError>()));
    expect(() {
      // Two values after the max should both encode to the same integer.
      Conversions.uint32ToGpsTime(
          Conversions.gpsTimeToUint32(GpsTime.fromUtc(5000)));
    }, throwsA(isA<RangeError>()));

    // Check null.
    final nullDateTimeAsInt = 4294967295;
    expect(Conversions.gpsTimeToUint32(null), nullDateTimeAsInt);
    expect(Conversions.uint32ToGpsTime(nullDateTimeAsInt), null);
  });

  test('Check altitude to Int16 conversions', () {
    // Check that converting back and forth gives the same value.
    for (var i = 0; i <= 100; i++) {
      final altitude = i / 2.0;
      expect(Conversions.int16ToAltitude(Conversions.altitudeToInt16(altitude)),
          altitude);
    }

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.altitudeToInt16(15.3), 31);
    expect(Conversions.altitudeToInt16(-10.2), -20);

    // Check the caps
    expect(Conversions.altitudeToInt16(-999999), -32766);
    expect(Conversions.altitudeToInt16(999999), 32766);

    // Check the null
    expect(Conversions.altitudeToInt16(null), 32767);
    expect(Conversions.int16ToAltitude(32767), null);
  });

  test('Check small double to Uint16 conversions, with null support', () {
    // Check that converting back and fort gives the same value.
    for (var i = 0; i <= 100; i++) {
      final value = i / 2;
      expect(
          Conversions.uint16ToSmallDouble(
              Conversions.smallDoubleToUint16(value)),
          value);
    }

    // Test converting null back and forth.
    expect(
        Conversions.uint16ToSmallDouble(Conversions.smallDoubleToUint16(null)),
        null);

    // Check that converting one way gives the correct value (the back and
    // forth test ensures implicitly that the other direction is correct too).
    expect(Conversions.smallDoubleToUint16(10.2), 102);
    expect(Conversions.smallDoubleToUint16(null), 65535);

    // Check the caps.
    expect(Conversions.smallDoubleToUint16(-999999), 0);
    expect(Conversions.smallDoubleToUint16(999999), 65534);

    // Check value close to cap.
    expect(Conversions.smallDoubleToUint16(6553), 65530);
    expect(Conversions.uint16ToSmallDouble(65530), 6553);
    expect(Conversions.uint16ToSmallDouble(65534), 6553.4);
    expect(Conversions.uint16ToSmallDouble(65535), null);
    expect(
        Conversions.uint16ToSmallDouble(Conversions.smallDoubleToUint16(null)),
        null);
    expect(
        Conversions.uint16ToSmallDouble(Conversions.smallDoubleToUint16(6553)),
        6553);
  });

  test('Check heading to Uint16 conversions, with null support', () {
    /// [headingToInt16] calls [uint16ToSmallDouble] (and similar for the
    /// inverse conversion). No need to do a full test, the caps suffice.
    expect(Conversions.headingToInt16(-90.0), 270.0 * 10);
    expect(Conversions.headingToInt16(-180.0), 180.0 * 10);
    expect(Conversions.headingToInt16(-450), 270.0 * 10);
    expect(Conversions.headingToInt16(450), 90.0 * 10);
    expect(Conversions.headingToInt16(null), 65535);
  });
}
