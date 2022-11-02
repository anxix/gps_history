/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:gps_history/gps_history.dart';
import 'gpc_test_skeleton.dart';

class GpcDummy extends GpcCompactGpsPoint {}

/// Wraps around [testGpsPointsCollection] and adds extra tests.
///
/// See [testGpsPointsCollection] for the meaning of the parameters.
void testGpc<T extends GpsPoint>(
    String name,
    GpcEfficient<T> Function() collectionConstructor,
    T Function(int itemIndex) itemConstructor) {
  testGpsPointsCollection<T>(name, collectionConstructor, itemConstructor);

  late GpcEfficient<T> gpc;

  setUp(() {
    gpc = collectionConstructor()
      ..sortingEnforcement = SortingEnforcement.notRequired;
  });

  test('$name: capacity', () {
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

  group('$name: addByteData', () {
    test('add nothing', () {
      final data = ByteData(0);
      gpc.addByteData(data);

      expect(gpc.length, 0);

      gpc.add(itemConstructor(0));
      gpc.addByteData(data);
      expect(gpc.length, 1);
    });

    test('add some items', () {
      const nrElements = 10;
      final data = ByteData(nrElements * gpc.elementSizeInBytes);
      for (var elemNr = 0; elemNr < nrElements; elemNr++) {
        for (var byteNr = 0; byteNr < gpc.elementSizeInBytes; byteNr++) {
          data.setUint8(
              byteNr + elemNr * gpc.elementSizeInBytes, 1 + elemNr + byteNr);
        }
      }

      gpc.addByteData(data);
      expect(gpc.length, nrElements);

      // Add some more.
      gpc.addByteData(data);
      expect(gpc.length, 2 * nrElements);

      // Check the contents.
      expect(gpc[0].altitude, 1798.5);
      expect(gpc[1].altitude, 1927);
      expect(gpc[9].altitude, 2955);
      expect(gpc[10].altitude, 1798.5);
      expect(gpc[11].altitude, 1927);
      expect(gpc[19].altitude, 2955);
    });

    test('add wrongly sized data', () {
      var data = ByteData(2 * gpc.elementSizeInBytes + 1);
      expect(() => gpc.addByteData(data), throwsA(isA<Exception>()));

      data = ByteData(gpc.elementSizeInBytes - 1);
      expect(() => gpc.addByteData(data), throwsA(isA<Exception>()));
    });
  });
}

void main() {
  testGpc<GpsPoint>(
      'GpcCompactGpsPoint',
      () => GpcCompactGpsPoint(),
      (int i) => GpsPoint(
          // The constraints of GpcEfficientGpsPoint mean the date must be
          // somewhat reasonable, so we can't just use year 1.
          time: GpsTime.fromUtc(2100).add(days: i),
          latitude: i.toDouble(), // required to be equal to i
          longitude: i.toDouble(),
          altitude: i.toDouble()));

  testGpc<GpsPoint>(
      'GpcCompactGpsPoint with extreme values',
      () => GpcCompactGpsPoint(),
      (int i) => GpsPoint(
          // Repeat the test with values close to the maximum date range, to
          // check that storage works OK near the boundaries.
          time: GpsTime.fromUtc(2100).add(days: i),
          latitude: i.toDouble(), // required to be equal to i
          longitude: 175.0 + i,
          altitude: 16E3 + i));

  testGpc<GpsPointWithAccuracy>(
      'GpcCompactGpsPointWithAccuracy with extreme values',
      () => GpcCompactGpsPointWithAccuracy(),
      (int i) => GpsPointWithAccuracy(
          // Repeat the test with values close to the maximum date range, to
          // check that storage works OK near the boundaries.
          time: GpsTime.fromUtc(2100).add(days: i),
          latitude: i.toDouble(), // required to be equal to i
          longitude: 175.0 + i,
          altitude: 16E3 + i,
          accuracy: 3.2));

  testGpc<GpsStay>(
      'GpcCompactGpsMeasurement with extreme values',
      () => GpcCompactGpsStay(),
      (int i) => GpsStay(
            // Repeat the test with values close to the maximum date range, to
            // check that storage works OK near the boundaries.
            time: GpsTime.fromUtc(2100).add(days: i),
            latitude: i.toDouble(), // required to be equal to i
            longitude: 175.0 + i,
            altitude: 16E3 + i,
            accuracy: null, // make sure we also test a null
            endTime: GpsTime.fromUtc(2100).add(days: i, minutes: 1),
          ));

  testGpc<GpsMeasurement>(
      'GpcCompactGpsMeasurement with extreme values',
      () => GpcCompactGpsMeasurement(),
      (int i) => GpsMeasurement(
          // Repeat the test with values close to the maximum date range, to
          // check that storage works OK near the boundaries.
          time: GpsTime.fromUtc(2100).add(days: i),
          latitude: i.toDouble(), // required to be equal to i
          longitude: 175.0 + i,
          altitude: 16E3 + i,
          accuracy: 3.2,
          heading: null, // make sure we also test a null
          speed: 6546.0,
          speedAccuracy: 6545.0));
}
