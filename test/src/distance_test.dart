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

    // Cases that span the antimeridian at -180/180 degrees.
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

  group('Distance checking methods', () {
    const relDelta = 1E-9;

    /// Creates and returns a test runner that will execute the specified
    /// distance calculation function [distCalc] with the provided parameters,
    /// and various variations thereof.
    makeTestRunnerWithVariations(
        double Function(double latA, double longA, double latB, double longB)
            distCalc) {
      return (double latA, double longA, double latB, double longB,
          double expected, String reason) {
        final delta = relDelta * expected;
        expect(distCalc(latA, longA, latB, longB), closeTo(expected, delta),
            reason: reason);
        expect(distCalc(latB, longB, latA, longA), closeTo(expected, delta),
            reason: '(inverted) $reason');

        expect(distCalc(-latA, -longA, -latB, -longB), closeTo(expected, delta),
            reason: '(mirrored) $reason');
        expect(distCalc(-latA, longA, -latB, longB), closeTo(expected, delta),
            reason: '(lat-mirrored) $reason');
        expect(distCalc(latA, -longA, latB, -longB), closeTo(expected, delta),
            reason: '(long-mirrored) $reason');
      };
    }

    test('distanceCoordsHaversine', () {
      final runner = makeTestRunnerWithVariations(distanceCoordsHaversine);
      final oneDegLatitudeDist = earthRadiusMeters * 2 * pi / 360;

      // On the prime meridian one degree latitude.
      runner(0, 0, 1, 0, oneDegLatitudeDist, 'one degree latitude from origin');
      runner(2, 0, 3, 0, oneDegLatitudeDist, 'one degree latitude from offset');
      runner(-1, 0, 1, 0, 2 * oneDegLatitudeDist,
          'two degree longitude spanning the equator');
      // Offset to a non-zero longitude, shouldn't affect results for constant
      // longitude.
      runner(5, 3, 7, 3, 2 * oneDegLatitudeDist,
          'two degree latitude from offset at low non-standard longitude');
      runner(5, 89, 7, 89, 2 * oneDegLatitudeDist,
          'two degree latitude from offset at high non-standard longitude');

      // On the equator 1 degree longitude (at equator one degree longitude or
      // latitude give the same distance).
      runner(
          0, 0, 0, 1, oneDegLatitudeDist, 'one degree longitude from origin');
      runner(
          0, 1, 0, 2, oneDegLatitudeDist, 'one degree longitude from offset');
      runner(0, 179, 0, -178, 3 * oneDegLatitudeDist,
          'three degree longitude spanning the antimeridian');

      // Test some predefined points. Validated against
      // https://www.vcalc.com/wiki/vCalc/Haversine+-+Distance.
      runner(1, 2, 3, 4, 314402.95102362486, 'predefined A');
      runner(10, 20, 30, 40, 3040602.8180682, 'predefined B');
    });
  });
}
