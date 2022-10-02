/// Search algorithms.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:meta/meta.dart';

import '../base.dart';
import '../base_collections.dart';
import '../gpc_efficient.dart';

typedef CompareTargetToItemFunc = int Function(int itemNr);


/// Abstract class representing a search algorithm looking for entities of type
/// [P] in a collection of type [C].
abstract class SearchAlgorithm<P extends GpsPoint, C extends GpsPointsView<P>> {
  /// Determins which algorithm is best suited for searching for items of
  /// type [P] in the given [collection] of type [C].
  static SearchAlgorithm
      getBestAlgorithm<P extends GpsPoint, C extends GpsPointsView<P>>(
          C collection, bool isSorted, CompareTargetToItemFunc compareFunc) {
    if (isSorted) {
      // Sorted collection can do a binary search.
      if (collection is GpcEfficient) {
        return BinarySearchInGpcEfficient<P>(
            collection as GpcEfficient<P>, compareFunc);
      } else {
        return BinarySearchInSlowCollection<P>(collection, compareFunc);
      }
    } else {
      // Unsorted collection requires linear search.
      if (collection is GpcEfficient) {
        return LinearSearchInGpcEfficient<P>(
            collection as GpcEfficient<P>, compareFunc);
      } else {
        return LinearSearchInSlowCollection<P>(collection, compareFunc);
      }
    }
  }

  /// The collection on which the search will be performed.
  final C collection;

  /// The comparison function that will be used to identify the desired item.
  final CompareTargetToItemFunc compareFunc;

  SearchAlgorithm(this.collection, this.compareFunc);

  /// Internal implementation for [find], which does not do any validity checks
  /// on its arguments. Not to be called directly.
  @protected
  // ignore: non_constant_identifier_names
  int? findUnsafe(int start, int end);

  /// Tries to find and return the item index between [start] and [end] for
  /// which the [compareFunc] returns [ComparisonResult.equal]. If such an
  /// item is not fount, the function returns null.
  ///
  /// The arguments must satisfy: 0 <= [start] <= [end] <= [length]. In other
  /// words, [start] will be considered, but the matching will stop at element
  /// index [end]-1.
  int? find([int start = 0, int? end]) {
    end = RangeError.checkValidRange(start, end, collection.length, 'start',
        'end', 'Invalid parameters to $runtimeType.find.');
    return findUnsafe(start, end);
  }
}

class LinearSearch<P extends GpsPoint, C extends GpsPointsView<P>>
    extends SearchAlgorithm<P, C> {
  LinearSearch(super.collection, super.compareFunc);

  @override
  int? findUnsafe(int start, int end) {
    // Slow implementation, as we've got to do a linear search.
    for (var i = start; i < end; i++) {
      if (compareFunc(i) == 0) {
        return i;
      }
    }

    // Linear search delivered nothing -> return null.
    return null;
  }
}

class LinearSearchInGpcEfficient<P extends GpsPoint>
    extends LinearSearch<P, GpcEfficient<P>> {
  LinearSearchInGpcEfficient(super.collection, super.compareFunc);
}

class LinearSearchInSlowCollection<P extends GpsPoint>
    extends LinearSearch<P, GpsPointsView<P>> {
  LinearSearchInSlowCollection(super.collection, super.compareFunc);
}

class BinarySearch<P extends GpsPoint, C extends GpsPointsView<P>>
    extends SearchAlgorithm<P, C> {
  BinarySearch(super.collection, super.compareFunc);

  @override
  int? findUnsafe(int start, int end) {
    while (true) {
      // Impossible situation -> have not found anything.
      if (start >= end) {
        return null;
      }

      // Only one option -> either it's a match, or there's no match.
      if (start == end - 1) {
        if (compareFunc(start) == 0) {
          return start;
        } else {
          return null;
        }
      }

      // Can't tell yet -> subdivide and look in the upper/lower half depending
      // on how the midpoint works out.
      final mid = start + (end - start) ~/ 2;
      final midComparison = compareFunc(mid);
      if (midComparison == 0) {
        return mid;
      } else {
        if (midComparison < 0) {
          // mid is before the item we're looking for -> look from mid+1 to end
          start = mid + 1;
        } else {
          // mid is after the item we're looking for -> look from start to mid (excluding mid)
          end = mid;
        }
      }
    }
  }
}

class BinarySearchInGpcEfficient<P extends GpsPoint>
    extends BinarySearch<P, GpcEfficient<P>> {
  BinarySearchInGpcEfficient(super.collection, super.compareFunc);
}

class BinarySearchInSlowCollection<P extends GpsPoint>
    extends BinarySearch<P, GpsPointsView<P>> {
  BinarySearchInSlowCollection(super.collection, super.compareFunc);
}
