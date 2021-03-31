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

      // basic tests with a second point
      final p1 = itemConstructor(2);
      gpc!.add(p1);
      expect(gpc!.length, 2, reason: 'wrong length after second add');
      expect(gpc![0], p0, reason: 'wrong point at [0] after second add');
      expect(gpc![1], p1, reason: 'wrong point at [1] after second add');
    });

    test('Check AddAll', () {
      final src = List<T>.filled(2, itemConstructor(0), growable: true);

      for (var i = 0; i < src.length; i++) {
        src[i] = itemConstructor(i + 1);
      }

      gpc!.addAll(src);
      expect(gpc!.length, src.length, reason: 'wrong length after addAll');
      for (var i = 0; i < src.length; i++) {
        expect(gpc![i], src[i], reason: 'incorrect point at position $i');
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
      // latitude being equal to the item index.
      var total = 0.0;
      gpc!.forEach((point) {
        total += point.latitude;
      });
      expect(total, 6.0);
    });
  });
}
