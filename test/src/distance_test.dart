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

  test('deltaLatitudeAbs', () {
    // Various zero distance configurations.
    expect(deltaLatitudeAbs(0, 0), 0);
    expect(deltaLatitudeAbs(1, 1), 0);
    expect(deltaLatitudeAbs(-1, -1), 0);
    expect(deltaLatitudeAbs(180, 180), 0);
    expect(deltaLatitudeAbs(-180, -180), 0);
    expect(deltaLatitudeAbs(-180, 180), 0);
    expect(deltaLatitudeAbs(180, -180), 0);

    // Various nonzero distance configurations.
    expect(deltaLatitudeAbs(0, 1), 1);
    expect(deltaLatitudeAbs(1, 0), 1);
    expect(deltaLatitudeAbs(-1, 2), 3);
    expect(deltaLatitudeAbs(1, -2), 3);

    // Cases that span the seam at -180/180 degrees.
    expect(deltaLatitudeAbs(178, -177), 5);
    expect(deltaLatitudeAbs(-177, 178), 5);
  });

  test('deltaLongitudeAbs', () {
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
    const delta = 1E-9;

    _runTest(double latA, double longA, double latB, double longB,
        double expected, String reason) {
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

    final oneDegLongitudeDist = earthRadiusMeters * 2 * pi / 360;
    // On the prime meridian one degree longitude.
    _runTest(
        0, 0, 0, 1, oneDegLongitudeDist, 'one degree longitude from origin');
    _runTest(
        0, 2, 0, 3, oneDegLongitudeDist, 'one degree longitude from offset');
    _runTest(0, -1, 0, 1, 2 * oneDegLongitudeDist,
        'one degree longitude from offset');

    // On the equator 1 degree latitude (at equator one degree latitude or
    // longitude give the same distance).
    _runTest(
        0, 0, 1, 0, oneDegLongitudeDist, 'one degree latitude from origin');
  });
}
