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

/// Function to compare item [itemNr] of [collection] to [findTarget] and
/// return a result, like [Comparator].
typedef CompareItemToTargetFunc<C extends GpsPointsView, F> = int Function(
    C collection, int itemNr, F findTarget);

/// Abstract class representing a search algorithm looking for entities of type
/// [P] in a collection of type [C]. The entity of type [P] will be identified
/// based on find-target data of type [F].
///
/// For example if looking for items of type [GpsStay] with a specific
/// [GpsStay.endTime] in a [GpcCompactGpsStay], the types will be:
///   - [P]: [GpsStay]
///   - [C]: [GpcCompactGpsStay]
///   - [F]: [GpsTime]
abstract class SearchAlgorithm<P extends GpsPoint, C extends GpsPointsView<P>,
    F> {
  /// Determines which algorithm is best suited for the search in the given
  /// [collection].
  static SearchAlgorithm
      getBestAlgorithm<P extends GpsPoint, C extends GpsPointsView<P>, F>(
          C collection,
          bool isSorted,
          CompareItemToTargetFunc<C, F> compareFunc) {
    if (isSorted) {
      // Sorted collection can do a binary search.
      if (collection is GpcEfficient) {
        return BinarySearchInGpcEfficient<P, F>(collection as GpcEfficient<P>,
            compareFunc as CompareItemToTargetFunc<GpcEfficient<P>, F>);
      } else {
        return BinarySearchInSlowCollection<P, F>(collection,
            compareFunc as CompareItemToTargetFunc<GpsPointsView, F>);
      }
    } else {
      // Unsorted collection requires linear search.
      if (collection is GpcEfficient) {
        return LinearSearchInGpcEfficient<P, F>(collection as GpcEfficient<P>,
            compareFunc as CompareItemToTargetFunc<GpcEfficient<P>, F>);
      } else {
        return LinearSearchInSlowCollection<P, F>(collection,
            compareFunc as CompareItemToTargetFunc<GpsPointsView, F>);
      }
    }
  }

  /// The collection on which the search will be performed.
  final C collection;

  /// The comparison function that will be used to identify the desired item.
  final CompareItemToTargetFunc<C, F> compareFunc;

  /// Constructor for the algorithm. It's necessary to bind both the
  /// [collection] and the [compreFunc], because an algorithm created for one
  /// list cannot necessarily be used in another list.
  ///
  /// E.g. if an algorithm object was created for a sorted list and would then
  /// be applied on an unsorted list, the result would not be reliable. Or if
  /// it was created for a [compareFunc] for which it is sorted, but is later
  /// used with one for which it is not sorted. Binding these at construction
  /// time avoids these issues, but does mean that using a conceptually equal
  /// algorithm on a different collection requires instantiating a new algorithm
  /// object.
  SearchAlgorithm(this.collection, this.compareFunc);

  /// Internal implementation for [find], which does not do any validity checks
  /// on its arguments. Not to be called directly.
  @protected
  // ignore: non_constant_identifier_names
  int? findUnsafe(F target, int start, int end);

  /// Tries to find and return the item index between [start] and [end] for
  /// which the [compareFunc] returns [ComparisonResult.equal]. If such an
  /// item is not fount, the function returns null.
  ///
  /// The arguments must satisfy: 0 <= [start] <= [end] <= [length]. In other
  /// words, [start] will be considered, but the matching will stop at element
  /// index [end]-1.
  int? find(F target, [int start = 0, int? end]) {
    end = RangeError.checkValidRange(
        start,
        end,
        collection.length,
        'start',
        'end',
        // Don't do expensive string interpolation here, if doing lots of find()
        // calls, this mayend up taking half the time!
        'Invalid parameters to find().');
    return findUnsafe(target, start, end);
  }
}

class LinearSearch<P extends GpsPoint, C extends GpsPointsView<P>, F>
    extends SearchAlgorithm<P, C, F> {
  LinearSearch(super.collection, super.compareFunc);

  @override
  int? findUnsafe(F target, int start, int end) {
    // Slow implementation, as we've got to do a linear search.
    for (var i = start; i < end; i++) {
      if (compareFunc(collection, i, target) == 0) {
        return i;
      }
    }

    // Linear search delivered nothing -> return null.
    return null;
  }
}

class LinearSearchInGpcEfficient<P extends GpsPoint, F>
    extends LinearSearch<P, GpcEfficient<P>, F> {
  LinearSearchInGpcEfficient(super.collection, super.compareFunc);
}

class LinearSearchInSlowCollection<P extends GpsPoint, F>
    extends LinearSearch<P, GpsPointsView<P>, F> {
  LinearSearchInSlowCollection(super.collection, super.compareFunc);
}

class BinarySearch<P extends GpsPoint, C extends GpsPointsView<P>, F>
    extends SearchAlgorithm<P, C, F> {
  BinarySearch(super.collection, super.compareFunc);

  @override
  int? findUnsafe(F target, int start, int end) {
    while (true) {
      // Impossible situation -> have not found anything.
      if (start >= end) {
        return null;
      }

      // Only one option -> either it's a match, or there's no match.
      if (start == end - 1) {
        if (compareFunc(collection, start, target) == 0) {
          return start;
        } else {
          return null;
        }
      }

      // Can't tell yet -> subdivide and look in the upper/lower half depending
      // on how the midpoint works out.
      final mid = start + (end - start) ~/ 2;
      final midComparison = compareFunc(collection, mid, target);
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

class BinarySearchInGpcEfficient<P extends GpsPoint, F>
    extends BinarySearch<P, GpcEfficient<P>, F> {
  BinarySearchInGpcEfficient(super.collection, super.compareFunc);
}

class BinarySearchInSlowCollection<P extends GpsPoint, F>
    extends BinarySearch<P, GpsPointsView<P>, F> {
  BinarySearchInSlowCollection(super.collection, super.compareFunc);
}
