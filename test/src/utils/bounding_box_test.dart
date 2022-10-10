/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/src/utils/binary_conversions.dart';
import 'package:gps_history/src/utils/bounding_box.dart';
import 'package:test/test.dart';

class PointTest {
  final double latitudeDeg;
  final double longitudeDeg;
  final bool expected;

  PointTest(this.latitudeDeg, this.longitudeDeg, this.expected);

  @override
  String toString() {
    return 'lat: $latitudeDeg, long: $longitudeDeg';
  }
}

void main() {
  group('Properties', () {
    test('Equals', () {
      final flatBb0 = FlatLatLongBoundingBox(10, 20, 30, 40);
      final flatBb1 = FlatLatLongBoundingBox(10, 20, 30, 40);
      expect(flatBb0, flatBb0,
          reason: 'Expected bounding box to be equal to itself.');
      expect(flatBb0, flatBb1,
          reason: 'Expected two bounding boxes with same values to be equal.');

      final geoBb0 = GeodeticLatLongBoundingBox(
          flatBb0.bottomLatitude.toDouble(),
          flatBb0.leftLongitude.toDouble(),
          flatBb0.topLatitude.toDouble(),
          flatBb0.rightLongitude.toDouble());
      expect(geoBb0, isNot(flatBb0),
          reason:
              'Expected two bounding boxes of different type and with same values to not be equal.');
    });

    test('Hash', () {
      final flatBb0 = FlatLatLongBoundingBox(10, 20, 30, 40);
      final flatBb1 = FlatLatLongBoundingBox(11, 22, 33, 44);
      final flatBb2 = FlatLatLongBoundingBox(10, 20, 30, 40);
      expect(flatBb0.hashCode, isNot(flatBb1.hashCode),
          reason: 'Expected different hashes with different values.');
      expect(flatBb0.hashCode, flatBb2.hashCode,
          reason: 'Expected same hashes with same values.');
    });
  });

  group('Contains', () {
    /// Creates the bounding box defined by the arguments and checks for each
    /// defined test in [tests] whether the containership check returns the
    /// expected value.
    ///
    /// Tests will also be executed in vertically mirrored configuration.
    runContainsTests(double bottomLatitudeDeg, double leftLongitudeDeg,
        double topLatitudeDeg, double rightLongitudeDeg, List<PointTest> tests,
        {bool alsoRunVertMirrored = true}) {
      // Tests will be executed on both types of bounding boxes.
      final geodeticBB = GeodeticLatLongBoundingBox(bottomLatitudeDeg,
          leftLongitudeDeg, topLatitudeDeg, rightLongitudeDeg);
      final flatBB = FlatLatLongBoundingBox(
          Conversions.latitudeToUint32(bottomLatitudeDeg),
          Conversions.longitudeToUint32(leftLongitudeDeg),
          Conversions.latitudeToUint32(topLatitudeDeg),
          Conversions.longitudeToUint32(rightLongitudeDeg));

      for (final pt in tests) {
        expect(
            geodeticBB.contains(pt.latitudeDeg, pt.longitudeDeg), pt.expected,
            reason: 'geodeticBB for $pt');
        expect(
            flatBB.contains(Conversions.latitudeToUint32(pt.latitudeDeg),
                Conversions.longitudeToUint32(pt.longitudeDeg)),
            pt.expected,
            reason: 'flatBB for $pt');
      }

      if (alsoRunVertMirrored) {
        final vertMirroredTests = <PointTest>[];
        for (final pt in tests) {
          vertMirroredTests
              .add(PointTest(-pt.latitudeDeg, pt.longitudeDeg, pt.expected));
        }
        runContainsTests(-topLatitudeDeg, leftLongitudeDeg, -bottomLatitudeDeg,
            rightLongitudeDeg, vertMirroredTests,
            alsoRunVertMirrored: false);
      }
    }

    test('Regular', () {
      runContainsTests(10, 10, 20, 20, [
        // Point well inside the box.
        PointTest(15, 15, true),
        // Points on the corners/edges.
        PointTest(10, 10, true),
        PointTest(20, 20, true),
        // Points outside the box.
        PointTest(8, 15, false),
        PointTest(22, 15, false),
        PointTest(15, 8, false),
        PointTest(15, 22, false),
      ]);
    });

    test('Around origin', () {
      runContainsTests(-10, -10, 10, 10, [
        // Point well inside the box.
        PointTest(0, 0, true),
        // Points on the corners/edges.
        PointTest(-10, -10, true),
        PointTest(10, 10, true),
        // Points outside the box.
        PointTest(-20, 0, false),
        PointTest(20, 0, false),
        PointTest(0, -20, false),
        PointTest(0, 20, false),
      ]);
    });

    test('At the pole', () {
      // Box configured for North pole, but the test automatically also runs
      // it inverted for the south pole.
      runContainsTests(80, 10, 90, 20, [
        // Point well inside the box.
        PointTest(85, 15, true),
        // Points on the corners/edges.
        PointTest(80, 10, true),
        PointTest(90, 20, true),
        // This is the top of the sphere -> anything at latitude=90/-90 is in
        // the BB, as it's a singular point.
        PointTest(90, 5, true),
      ]);
    });

    test('Invalid bounding box', () {
      // A bounding box that's defined "upside-down" is not allowed.
      expect(() => runContainsTests(10, 20, -10, 30, []),
          throwsA(isA<RangeError>()));
    });

    test('Wrapping antimeridian', () {
      runContainsTests(-10, 170, 10, -170, [
        // Point well inside the box.
        PointTest(0, 180, true),
        PointTest(0, -180, true),
        // Points on the corners/edges.
        PointTest(-10, 170, true),
        PointTest(10, -170, true),
        // Points outside the box.
        PointTest(0, 0, false),
        PointTest(0, 169, false),
        PointTest(0, -169, false),
      ]);
    });
  });
}
