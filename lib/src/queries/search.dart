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

/// Function to calculate the difference between item [itemNr] of [collection]
/// and [findTarget].
typedef DiffBetween<C extends GpsPointsView, F> = num Function(
    C collection, int itemNr, F findTarget);

/// Container for a [compareFunc] and a [diffFunc] to be passed around to search
/// algorithms.
class SearchCompareDiff<C extends GpsPointsView, F> {
  final CompareItemToTargetFunc<C, F> compareFunc;
  final DiffBetween<C, F>? diffFunc;

  const SearchCompareDiff(this.compareFunc, [this.diffFunc]);
}

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
          C collection, bool isSorted, SearchCompareDiff<C, F> compareDiff) {
    if (isSorted) {
      // Sorted collection can do a binary search.
      if (collection is GpcEfficient) {
        return BinarySearchInGpcEfficient<P, F>(collection as GpcEfficient<P>,
            compareDiff as SearchCompareDiff<GpcEfficient<P>, F>);
      } else {
        return BinarySearchInSlowCollection<P, F>(collection, compareDiff);
      }
    } else {
      // Unsorted collection requires linear search.
      if (collection is GpcEfficient) {
        return LinearSearchInGpcEfficient<P, F>(collection as GpcEfficient<P>,
            compareDiff as SearchCompareDiff<GpcEfficient<P>, F>);
      } else {
        return LinearSearchInSlowCollection<P, F>(collection, compareDiff);
      }
    }
  }

  /// The collection on which the search will be performed.
  final C collection;

  /// The comparison function that will be used to identify the desired item.
  final SearchCompareDiff<C, F> compareDiff;

  /// Constructor for the algorithm. It's necessary to bind both the
  /// [collection] and the [compreFunc], because an algorithm created for one
  /// list cannot necessarily be used in another list.
  ///
  /// E.g. if an algorithm object was created for a sorted list and would then
  /// be applied on an unsorted list, the result would not be reliable. Or if
  /// it was created for a [compareDiff] for which it is sorted, but is later
  /// used with one for which it is not sorted. Binding these at construction
  /// time avoids these issues, but does mean that using a conceptually equal
  /// algorithm on a different collection requires instantiating a new algorithm
  /// object.
  SearchAlgorithm(this.collection, this.compareDiff);

  /// Internal implementation for [find], which does not do any validity checks
  /// on its arguments. Not to be called directly.
  @protected
  // ignore: non_constant_identifier_names
  int? findUnsafe(F target, num? tolerance, int start, int end);

  /// Tries to find and return the item index between [start] and [end] for
  /// which the [compareDiff] returns [ComparisonResult.equal]. If such an
  /// item is not fount, the function returns null.
  ///
  /// The arguments must satisfy: 0 <= [start] <= [end] <= [length]. In other
  /// words, [start] will be considered, but the matching will stop at element
  /// index [end]-1.
  int? find(F target, [num? tolerance, int start = 0, int? end]) {
    end = RangeError.checkValidRange(
        start,
        end,
        collection.length,
        'start',
        'end',
        // Don't do expensive string interpolation here, if doing lots of find()
        // calls, this may end up taking half the time or more!
        'Invalid parameters to find().');
    // In order to do tolerance-based evaluations, a function to compute the
    // difference must have been provided.
    if (tolerance != null) {
      ArgumentError.checkNotNull(compareDiff.diffFunc, 'tolerance');
    }
    return findUnsafe(target, tolerance, start, end);
  }
}

class LinearSearch<P extends GpsPoint, C extends GpsPointsView<P>, F>
    extends SearchAlgorithm<P, C, F> {
  LinearSearch(super.collection, super.compareFunc);

  @override
  int? findUnsafe(F target, num? tolerance, int start, int end) {
    // Check that it's necessary and possible to deal with tolerances.
    final supportTolerance =
        tolerance != null && tolerance != 0 && compareDiff.diffFunc != null;

    int? bestIndexWithinTolerance;
    num? bestDiffWithinTolerance;

    // Slow implementation, as we've got to do a linear search.
    for (var i = start; i < end; i++) {
      if (compareDiff.compareFunc(collection, i, target) == 0) {
        return i;
      }

      if (supportTolerance) {
        final diff = compareDiff.diffFunc!(collection, i, target).abs();
        if (diff > tolerance) {
          continue;
        }
        if (bestDiffWithinTolerance == null || diff < bestDiffWithinTolerance) {
          bestDiffWithinTolerance = diff;
          bestIndexWithinTolerance = i;
        }
      }
    }

    // Did not find perfect match, but maybe found something within tolerance.
    if (bestIndexWithinTolerance != null) {
      return bestIndexWithinTolerance;
    }

    // Linear search delivered nothing -> return null.
    return null;
  }
}

class LinearSearchInGpcEfficient<P extends GpsPoint, F>
    extends LinearSearch<P, GpcEfficient<P>, F> {
  LinearSearchInGpcEfficient(super.collection, super.compareDiff);
}

class LinearSearchInSlowCollection<P extends GpsPoint, F>
    extends LinearSearch<P, GpsPointsView<P>, F> {
  LinearSearchInSlowCollection(super.collection, super.compareDiff);
}

class BinarySearch<P extends GpsPoint, C extends GpsPointsView<P>, F>
    extends SearchAlgorithm<P, C, F> {
  BinarySearch(super.collection, super.compareFunc);

  /// Given a situation where an exact match for [target] was not found,
  /// attempt to find an item that's within the [tolerance] from that [target].
  /// Matching will be done around a specified [refNonMatchingPos]
  /// that's the position where the binary search stopped trying to identify
  /// matches.
  int? _findNearestMatchWithinTolerance(F target, num? tolerance,
      final int start, final int end, final int refNonMatchingPos) {
    // Catch situation that cannot possibly return anything useful.
    if (tolerance == null || compareDiff.diffFunc == null || end - start == 0) {
      return null;
    }

    // Since the collection is sorted, it's only necessary to look at the
    // immediately adjacent items. Either one of those, or the reference
    // position will be the best one. Note that the reference position itself
    // may be outside the valid range.
    num? refDiff = start <= refNonMatchingPos && refNonMatchingPos < end
        ? compareDiff.diffFunc!(collection, refNonMatchingPos, target).abs()
        : null;
    if (refDiff != null && refDiff > tolerance) {
      refDiff = null;
    }

    final beforeIndex = refNonMatchingPos - 1;
    num? beforeDiff;
    if (start <= beforeIndex) {
      // It's possible to look at a lower index -> see if that one is closer.
      beforeDiff = compareDiff.diffFunc!(collection, beforeIndex, target).abs();
      // If this is not within the tolerance, set it back to invalid.
      if (beforeDiff > tolerance) {
        beforeDiff = null;
      }
    }

    final afterIndex = refNonMatchingPos + 1;
    num? afterDiff;
    if (afterIndex <= end - 1) {
      // It's possible to look at a higher index -> see if that one is closer.
      afterDiff = compareDiff.diffFunc!(collection, afterIndex, target);
      // If this is not within tolerance, set it back to invalid.
      if (afterDiff > tolerance) {
        afterDiff = null;
      }
    }

    // Find out which of the items is closest to the intended value, which means
    // it has the lowest diff.
    num? bestDiff;
    int? bestIndex;
    if (beforeDiff != null) {
      bestDiff = beforeDiff;
      bestIndex = beforeIndex;
    }

    if (refDiff != null) {
      var isBetter = true;
      if (bestDiff != null) {
        isBetter = refDiff < bestDiff;
      }
      if (isBetter) {
        bestDiff = refDiff;
        bestIndex = refNonMatchingPos;
      }
    }

    if (afterDiff != null) {
      var isBetter = true;
      if (bestDiff != null) {
        isBetter = afterDiff < bestDiff;
      }
      if (isBetter) {
        bestDiff = afterDiff;
        bestIndex = afterIndex;
      }
    }

    return bestIndex;
  }

  @override
  int? findUnsafe(F target, num? tolerance, final int start, final int end) {
    var localStart = start;
    var localEnd = end;

    while (true) {
      // Have not found anything.
      if (localStart == localEnd) {
        return _findNearestMatchWithinTolerance(
            target, tolerance, start, end, localStart);
      }

      // Only one option -> either it's a match, or there's no match.
      if (localStart == localEnd - 1) {
        if (compareDiff.compareFunc(collection, localStart, target) == 0) {
          return localStart;
        } else {
          return _findNearestMatchWithinTolerance(
              target, tolerance, start, end, localStart);
        }
      }

      // Can't tell yet -> subdivide and look in the upper/lower half depending
      // on how the midpoint works out.
      final mid = localStart + (localEnd - localStart) ~/ 2;
      final midComparison = compareDiff.compareFunc(collection, mid, target);
      if (midComparison == 0) {
        return mid;
      } else {
        if (midComparison < 0) {
          // mid is before the item we're looking for -> look from mid+1 to end
          localStart = mid + 1;
        } else {
          // mid is after the item we're looking for -> look from start to mid (excluding mid)
          localEnd = mid;
        }
      }
    }
  }
}

class BinarySearchInGpcEfficient<P extends GpsPoint, F>
    extends BinarySearch<P, GpcEfficient<P>, F> {
  BinarySearchInGpcEfficient(super.collection, super.compareDiff);
}

class BinarySearchInSlowCollection<P extends GpsPoint, F>
    extends BinarySearch<P, GpsPointsView<P>, F> {
  BinarySearchInSlowCollection(super.collection, super.compareDiff);
}
