/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:test/test.dart';
import 'gpc_test_skeleton.dart';

void main() {
  testGpsPointsCollection<GpsPoint>(
      'GpcListBased',
      () => GpcListBased<GpsPoint>(),
      (int i) => GpsPoint(
          time: GpsTime.fromUtc(1970 + i),
          latitude: i.toDouble(), // required to be equal to i
          longitude: i.toDouble(),
          altitude: i.toDouble()));

  group('compareElementTime... variations', () {
    late GpcListBased<GpsStay> collection;

    setUp(() {
      collection = GpcListBased<GpsStay>();
      collection.add(
          GpsStay.allZero.copyWith(time: GpsTime(10), endTime: GpsTime(14)));
    });

    test('compareElementTimeWithSeparateTime', () {
      final elemA = collection.first;
      final resultOverlapping = collection.compareElementTimeWithSeparateTime(
          0,
          elemA.startTime
              .add(seconds: elemA.endTime.difference(elemA.time) ~/ 2));
      expect(resultOverlapping, TimeComparisonResult.overlapping,
          reason: 'wrong for overlapping');

      final resultBefore = collection.compareElementTimeWithSeparateTime(
          0, (elemA.endTime.add(seconds: 1)));
      expect(resultBefore, TimeComparisonResult.before,
          reason: 'wrong for span before test time');

      final resultAfter = collection.compareElementTimeWithSeparateTime(
          0, (elemA.startTime.add(seconds: -1)));
      expect(resultAfter, TimeComparisonResult.after,
          reason: 'wrong for span after test time');
    });

    test('compareElementTimeWithSeparateItem', () {
      final elementB = collection.first.copyWith(
          time: collection.first.time.add(seconds: 1),
          endTime: collection.first.endTime.add(seconds: -1));

      final result = collection.compareElementTimeWithSeparateItem(0, elementB);
      expect(result, TimeComparisonResult.overlapping);
    });

    test('compareElementTime', () {
      collection.sortingEnforcement = SortingEnforcement.notRequired;
      collection.add(collection.first.copyWith(
          time: collection.first.endTime.add(seconds: -1),
          endTime: collection.first.endTime.add(seconds: 1)));
      expect(collection.length, 2,
          reason: 'Test is intended to have 2 items in the list!');
      final result = collection.compareElementTime(0, 1);
      expect(result, TimeComparisonResult.overlapping);
    });
  });
}
