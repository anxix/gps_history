/// Provides a generic test skeleton for [GpsPointsCollection] implementations.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';

/// Runs standard tests on a collection of points.
///
/// The [name] of the test indicates how it will be identified (typically the
/// name of the collection under test). Two constructors must be provided to
/// create the collection to be tested ([collectionConstructor]) respectively
/// an item in the collection at a specific index ([itemConstructor]).
/// The [itemConstructor] must return an item with at least for the latitude
/// a value equal to the provided [itemIndex] parameter.
void testGpsPointsCollection<T extends GpsPoint>(
    String name,
    GpsPointsCollection<T> Function() collectionConstructor,
    T Function(int itemIndex) itemConstructor) {
  group('Test $name', () {
    GpsPointsCollection<T>? gpc;

    setUp(() {
      gpc = collectionConstructor();
    });

    test('Check length empty', () => expect(gpc!.length, 0));

    test('Check simple add and indexing', () {
      // basic tests with just one point
      final p0 = itemConstructor(1);
      gpc!.add(p0);
      expect(gpc!.length, 1, reason: 'wrong length after first add');
      expect(gpc![0], p0, reason: 'wrong point after first add');
      expect(gpc!.elementAt(0), p0, reason: 'wrong elementAt after first add');

      // basic tests with a second point
      final p1 = itemConstructor(2);
      gpc!.add(p1);
      expect(gpc!.length, 2, reason: 'wrong length after second add');
      expect(gpc![0], p0, reason: 'wrong point at [0] after second add');
      expect(gpc![1], p1, reason: 'wrong point at [1] after second add');
      expect(gpc!.elementAt(1), p1, reason: 'wrong elementAt after second add');
    });

    List<T> makeList(int nrItems) {
      final result =
          List<T>.filled(nrItems, itemConstructor(0), growable: true);
      for (var i = 0; i < result.length; i++) {
        result[i] = itemConstructor(i + 1);
      }
      return result;
    }

    test('Check AddAll', () {
      final src = makeList(2);

      gpc!.addAll(src);
      expect(gpc!.length, src.length, reason: 'wrong length');
      for (var i = 0; i < gpc!.length; i++) {
        expect(gpc![i], src[i], reason: 'incorrect point at position $i');
      }
    });

    test('Check AddAllStartingAt', () {
      final src = makeList(5);

      gpc!.addAllStartingAt(src, src.length);
      expect(gpc!.length, 0,
          reason: 'should be empty if adding from beyond the source boundary');

      final skip = 2;
      // Try addAllStartingAt on potentially different type (src and gpc are not
      // be of the same class).
      expect(gpc!.runtimeType, isNot(src.runtimeType),
          reason: 'test intended to be on different types');
      gpc!.addAllStartingAt(src, skip);
      expect(gpc!.length, src.length - skip, reason: 'wrong length');
      for (var i = 0; i < gpc!.length; i++) {
        expect(gpc![i], src[skip + i],
            reason: 'incorrect point at position $i');
      }

      // Try addAllStartingAlt on the same type.
      final otherGpc = collectionConstructor();
      expect(gpc!.runtimeType, otherGpc.runtimeType,
          reason: 'test intended to be on same types');
      otherGpc.addAllStartingAt(gpc!, 0);
      otherGpc.addAllStartingAt(gpc!, 1);
      expect(otherGpc.length, 2 * gpc!.length - 1,
          reason: 'wrong length after second addAllStartingAt');
      for (var i = 0; i < gpc!.length; i++) {
        expect(otherGpc[i], gpc![i],
            reason:
                'incorrect point at position $i after second addAllStartingAt');
      }
      for (var i = gpc!.length; i < otherGpc.length; i++) {
        expect(otherGpc[i], gpc![i - gpc!.length + 1],
            reason:
                'incorrect point at position $i after second addAllStartingAt');
      }
    });

    test('Check forEach', () {
      // Add three points. Start from 1 rather than 0, because we'll use
      // addition to detect if all elements have been traversed, and skipping
      // something with value 0 would obviously not be noticed.
      for (var i = 1; i < 4; i++) {
        gpc!.add(itemConstructor(i));
      }

      // It's required that the constructor returns items with at least the
      // latitude being equal to the itemIndex+1.
      var total = 0.0;
      for (var point in gpc!) {
        total += point.latitude;
      }
      expect(total, 6.0);
    });
  });
}
