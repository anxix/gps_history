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

// headingToInt16
// int16ToHeading
}

/// Wraps around [testGpsPointsCollection] and adds extra tests.
///
/// See [testGpsPointsCollection] for the meaning of the parameters.
void testGpc<T extends GpsPoint>(
    String name,
    GpcEfficient<T> Function() collectionConstructor,
    T Function(int itemIndex) itemConstructor) {
  testGpsPointsCollection<T>(name, collectionConstructor, itemConstructor);

  test('$name: capacity', () {
    final gpc = collectionConstructor();
    const targetCapacity =
        77; // pick a number that's unlikely to be on an increment boundary

    // Start out empty.
    expect(gpc.capacity, 0, reason: 'Wrong initial capacity');
    expect(gpc.length, 0, reason: 'Wrong initial length');

    // Increase capacity without affecting length.
    gpc.capacity = targetCapacity;
    expect(gpc.capacity, targetCapacity,
        reason: 'Wrong capacity after initial increase');
    expect(gpc.length, 0, reason: 'Wrong length after incrased capacity');

    // Fill up to the capacity, shouldn't increase capacity.
    var oldcapacity = gpc.capacity;
    for (var i = 0; i < oldcapacity; i++) {
      var p = itemConstructor(i);
      gpc.add(p);
    }
    expect(gpc.capacity, oldcapacity, reason: 'Wrong capacity after filling');
    expect(gpc.length, oldcapacity, reason: 'Wrong length after filling');

    // Add beyond capacity -> should increase it.
    gpc.add(itemConstructor(gpc.length));
    expect(gpc.capacity > oldcapacity, true,
        reason: 'Capacity should have increased');

    // Test that we cannot decrease capacity below length.
    gpc.capacity += 50;
    gpc.capacity = gpc.length - 3;
    expect(gpc.capacity, gpc.length,
        reason: 'Capacity should have decreased to length');

    // Check that the contents still make sense
    expect(gpc.length, targetCapacity + 1,
        reason: 'Incorrect length after previous manipulations');
    for (var i = 0; i < gpc.length; i++) {
      expect(gpc[i].latitude.round(), i, reason: 'Incorrect item at $i');
    }
  });
}

void main() {
  testConversions();

  testGpc<GpsPoint>(
      'GpcCompactGpsPoint',
      () => GpcCompactGpsPoint(),
      (int i) => GpsPoint(
          // The constraints of GpcEfficientGpsPoint mean the date must be
          // somewhat reasonable, so we can't just use year 1.
          DateTime.utc(2000 + i),
          i.toDouble(), // required to be equal to i
          i.toDouble(),
          i.toDouble()));

  testGpc<GpsPoint>(
      'GpcCompactGpsPoint with extreme values',
      () => GpcCompactGpsPoint(),
      (int i) => GpsPoint(
          // Repeat the test with values close to the maximum date range, to
          // check that storage works OK near the boundaries.
          DateTime.utc(2103 + i),
          i.toDouble(), // required to be equal to i
          175.0 + i,
          16E3 + i));

  testGpc<GpsMeasurement>(
      'GpcCompactGpsMeasurement with extreme values',
      () => GpcCompactGpsMeasurement(),
      (int i) => GpsMeasurement(
          // Repeat the test with values close to the maximum date range, to
          // check that storage works OK near the boundaries.
          DateTime.utc(2103 + i),
          i.toDouble(), // required to be equal to i
          175.0 + i,
          16E3 + i,
          3.2,
          null, // make sure we also test a null
          6546.0,
          6545.0));
}
