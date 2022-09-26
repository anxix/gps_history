/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';

import 'package:gps_history/src/distance.dart';
import 'package:test/test.dart';

void main() {
  test('degToRad', () {
    const delta = pi / 1E9;

    expect(degToRad(0), 0);
    expect(degToRad(180), closeTo(pi, delta));
    expect(degToRad(360), closeTo(2 * pi, delta));

    expect(degToRad(-180), closeTo(-pi, delta));
  });

  test('deltaLongitudeAbs', () {
    // Various zero distance configurations.
    expect(deltaLongitudeAbs(0, 0), 0);
    expect(deltaLongitudeAbs(1, 1), 0);
    expect(deltaLongitudeAbs(-1, -1), 0);
    expect(deltaLongitudeAbs(180, 180), 0);
    expect(deltaLongitudeAbs(-180, -180), 0);
    expect(deltaLongitudeAbs(-180, 180), 0);
    expect(deltaLongitudeAbs(180, -180), 0);

    // Various nonzero distance configurations.
    expect(deltaLongitudeAbs(0, 1), 1);
    expect(deltaLongitudeAbs(1, 0), 1);
    expect(deltaLongitudeAbs(-1, 2), 3);
    expect(deltaLongitudeAbs(1, -2), 3);

    // Cases that span the seam at -180/180 degrees.
    expect(deltaLongitudeAbs(178, -177), 5);
    expect(deltaLongitudeAbs(-177, 178), 5);
  });

  test('deltaLatitudeAbs', () {
    // Various zero distance configurations.
    expect(deltaLatitudeAbs(0, 0), 0);
    expect(deltaLatitudeAbs(1, 1), 0);
    expect(deltaLatitudeAbs(-1, -1), 0);
    expect(deltaLatitudeAbs(90, 90), 0);
    expect(deltaLatitudeAbs(-90, -90), 0);

    // Various nonzero distance configurations.
    expect(deltaLatitudeAbs(0, 1), 1);
    expect(deltaLatitudeAbs(1, 0), 1);
    expect(deltaLatitudeAbs(-1, 2), 3);
    expect(deltaLatitudeAbs(1, -2), 3);

    // Extreme values.
    expect(deltaLatitudeAbs(90, -90), 180);
    expect(deltaLatitudeAbs(-90, 90), 180);
  });

  test('distanceCoordsHaversine', () {
    const relDelta = 1E-9;

    runTestWithVariations(double latA, double longA, double latB, double longB,
        double expected, String reason) {
      final delta = relDelta * expected;
      expect(distanceCoordsHaversine(latA, longA, latB, longB),
          closeTo(expected, delta),
          reason: reason);
      expect(distanceCoordsHaversine(latB, longB, latA, longA),
          closeTo(expected, delta),
          reason: '(inverted) $reason');

      expect(distanceCoordsHaversine(-latA, -longA, -latB, -longB),
          closeTo(expected, delta),
          reason: '(mirrored) $reason');
      expect(distanceCoordsHaversine(-latA, longA, -latB, longB),
          closeTo(expected, delta),
          reason: '(lat-mirrored) $reason');
      expect(distanceCoordsHaversine(latA, -longA, latB, -longB),
          closeTo(expected, delta),
          reason: '(long-mirrored) $reason');
    }

    final oneDegLatitudeDist = earthRadiusMeters * 2 * pi / 360;
    // On the prime meridian one degree latitude.
    runTestWithVariations(
        0, 0, 1, 0, oneDegLatitudeDist, 'one degree latitude from origin');
    runTestWithVariations(
        2, 0, 3, 0, oneDegLatitudeDist, 'one degree latitude from offset');
    runTestWithVariations(-1, 0, 1, 0, 2 * oneDegLatitudeDist,
        'two degree longitude spanning the equator');
    // Offset to a non-zero longitude, shouldn't affect results for constant
    // longitude.
    runTestWithVariations(5, 3, 7, 3, 2 * oneDegLatitudeDist,
        'two degree latitude from offset at low non-standard longitude');
    runTestWithVariations(5, 89, 7, 89, 2 * oneDegLatitudeDist,
        'two degree latitude from offset at high non-standard longitude');

    // On the equator 1 degree longitude (at equator one degree longitude or
    // latitude give the same distance).
    runTestWithVariations(
        0, 0, 0, 1, oneDegLatitudeDist, 'one degree longitude from origin');
    runTestWithVariations(
        0, 1, 0, 2, oneDegLatitudeDist, 'one degree longitude from offset');
  });
}
