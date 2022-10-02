/// Comparators that can be used in the search algorithms.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import '../../gps_queries.dart';
import '../base_collections.dart';
import '../utils/time.dart';

/// Creates and returns a function that can be use used to compare an item
/// at a specific position in [collection] to a given [time], returning
/// -1 if the item in the [collection] is before [time], 0 if they're the same
/// or overlapping, and 1 if the item in the [collection] is after [time].
CompareTargetToItemFunc makeTimeCompareFunc(
    GpsPointsView collection, GpsTime time) {
  return (int itemIndex) {
    final result =
        collection.compareElementTimeWithSeparateTime(itemIndex, time);
    switch (result) {
      case TimeComparisonResult.before:
        return -1;
      // same and overlapping both count as matches.
      case TimeComparisonResult.same:
      case TimeComparisonResult.overlapping:
        return 0;
      case TimeComparisonResult.after:
        return 1;
      default:
        throw ArgumentError(
            'Comparison on $collection returns unexpected value $result for ($itemIndex, $time). '
            'This is not allowed.');
    }
  };
}
