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

  test('radToDeg', () {
    const delta = 180 / 1E9;

    expect(radToDeg(0), 0);
    expect(radToDeg(pi), closeTo(180, delta));
    expect(radToDeg(2 * pi), closeTo(360, delta));

    expect(radToDeg(-pi), closeTo(-180, delta));
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
      final oneDegLatitudeDist = EarthRadiusMeters.mean * 2 * pi / 360;

      // Zero-cases.
      runner(0, 0, 0, 0, 0, 'zero');
      runner(1, 2, 1, 2, 0, 'identical coords');
      runner(90, 90, 90, 90, 0, 'all 90');
      runner(90, 180, 90, 180, 0, 'etremes');

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

      // And some points that span the meridian, equator and antimeridian.
      runner(1, 179, -1, -179, 314498.76254388725, 'meridian spanning A');
      runner(-1, 179, 1, -179, 314498.76254388725, 'meridian spanning B');
    });

    test('distanceCoordsLambert', () {
      final runner = makeTestRunnerWithVariations(distanceCoordsLambert);

      // Zero-cases.
      runner(0, 0, 0, 0, 0, 'zero');
      runner(1, 2, 1, 2, 0, 'identical coords');
      runner(90, 90, 90, 90, 0, 'all 90');
      runner(90, 180, 90, 180, 0, 'extremes');

      // Test cases from https://python.algorithms-library.com/geodesy/lamberts_ellipsoidal_distance,
      // and compared with results from https://www.calculator.net/distance-calculator.html.
      final sanFrancisco = [37.774856, -122.424227];
      final yosemite = [37.864742, -119.537521];
      final newYork = [40.713019, -74.012647];
      final venice = [45.443012, 12.313071];

      runner(sanFrancisco[0], sanFrancisco[1], sanFrancisco[0], sanFrancisco[1],
          0, 'San Francisco to San Francisco');
      runner(sanFrancisco[0], sanFrancisco[1], yosemite[0], yosemite[1],
          254351.21287678572, 'San Francisco to Yosemite');
      runner(sanFrancisco[0], sanFrancisco[1], newYork[0], newYork[1],
          4138992.0167704853, 'San Francisco to New York');
      runner(sanFrancisco[0], sanFrancisco[1], venice[0], venice[1],
          9737326.376993028, 'San Francisco to Venice');

      // And some points that span the meridian, equator and antimeridian.
      runner(1, 179, -1, -179, 313798.6941713983, 'meridian spanning A');
      runner(-1, 179, 1, -179, 313798.6941713983, 'meridian spanning B');
    });
  });
}