/// Base classes for the GPS collections.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:meta/meta.dart';

import 'base.dart';
import 'utils/bounding_box.dart';
import 'utils/random_access_iterable.dart';
import 'utils/time.dart';

/// Exception class for sorting issues in [GpsPointsView] (sub)classes.
class GpsPointsViewSortingException extends GpsHistoryException {
  GpsPointsViewSortingException([message]) : super(message);
}

/// Read-only view on the GPS points stored in a [GpsPointsCollection].
///
/// Provides read-only access to GPS points, therefore typically acting as
/// a view onto a read/write collection of GpsPoints.
/// Subclass names may start with "Gpv".
abstract class GpsPointsView<T extends GpsPoint>
    extends RandomAccessIterable<T> {
  /// Indicate if the view is read-only and cannot be modified.
  bool get isReadonly => true;

  /// Indicates whether the contents are sorted in increasing order of time
  /// value. If this is the case, time-based queries can be faster by performing
  /// a binary search. For every point in time only one entity is allowed to
  /// provide a location value, i.e. a list is not sorted if it contains two
  /// identical elements consecutively.
  bool get sortedByTime;

  /// Returns a new collection of the same type as the current collection
  /// containing the elements between [start] and [end].
  ///
  /// If [end] is omitted, it defaults to the [length] of this collection.
  ///
  /// The `start` and `end` positions must satisfy the relations
  /// 0 ≤ `start` ≤ `end` ≤ [length].
  /// If `end` is equal to `start`, then the returned list is empty.
  GpsPointsView<T> sublist(int start, [int? end]);

  /// Creates a collection of the same type as this, optionally with
  /// a starting [capacity] for children that support that.
  ///
  /// Setting the capacity at the correct value can for huge lists with
  /// millions of items have a significant impact on the performance
  /// of filling the list.
  @protected
  GpsPointsView<T> newEmpty({int? capacity});

  /// Performs [compareTime] for the elements in the positions [elementNrA]
  /// and [elementNrB], then returns the result.
  ///
  /// Children my override this method to implement more efficient or custom
  /// implementations, for example if they support overlapping time or if
  /// they have a way to do quick time comparisons without doing full item
  /// retrieval.
  TimeComparisonResult compareElementTime(int elementNrA, int elementNrB) {
    return comparePointTimes(this[elementNrA], this[elementNrB]);
  }

  /// Performs [compareTime] for the item in the positions [elementNrA]
  /// and some separate [timeB] that's presumably not in the list, then
  /// returns the result.
  ///
  /// Children my override this method to implement more efficient or custom
  /// algorithms, for example if they support overlapping time or if
  /// they have a way to do quick time comparisons without doing full item
  /// retrieval.
  TimeComparisonResult compareElementTimeWithSeparateTime(
      int elementNrA, GpsTime timeB) {
    return compareElementTimeWithSeparateTimeSpan(
        elementNrA, timeB.secondsSinceEpoch, timeB.secondsSinceEpoch);
  }

  /// Performs [compareTimeSpans] for the item in the positions [elementNrA]
  /// and some separate time span between [startB] and [endB] (in seconds since
  /// epoch) that's presumably not in the list, then returns the result.
  ///
  /// Children my override this method to implement more efficient or custom
  /// algorithms, for example if they have a way to do quick time comparisons
  /// without doing full item retrieval.
  TimeComparisonResult compareElementTimeWithSeparateTimeSpan(
      int elementNrA, int startB, int endB) {
    final elemA = this[elementNrA];
    return compareTimeSpans(
        startA: elemA.time.secondsSinceEpoch,
        endA: elemA.endTime.secondsSinceEpoch,
        startB: startB,
        endB: endB);
  }

  /// Performs [compareTime] for the item in the positions [elementNrA]
  /// and some separate [elementB] that's presumably not in the list, then
  /// returns the result.
  ///
  /// Children my override this method to implement more efficient or custom
  /// algorithms, for example if they support overlapping time or if
  /// they have a way to do quick time comparisons without doing full item
  /// retrieval.
  TimeComparisonResult compareElementTimeWithSeparateItem(
      int elementNrA, T elementB) {
    return comparePointTimes(this[elementNrA], elementB);
  }

  /// Calculate the difference in time between the item in the position
  /// [elementNrA] and the [timeB]. See [diffTime] for explanations on
  /// how the difference is calculated and when it is positive, negative or
  /// zero.
  int diffElementTimeAndSeparateTime(int elementNrA, GpsTime timeB) {
    final elem = this[elementNrA];
    return diffTime(
        startTimeA: elem.time, endTimeA: elem.endTime, timeB: timeB);
  }

  /// Determine if the element at position [elementNr] is contained by the
  /// [boundingBox].
  ///
  /// Children my override this method to implement more efficient or custom
  /// algorithms, for example if they have a way to do quick position
  /// comparisons without doing full item retrieval.
  bool elementContainedByBoundingBox(
      int elementNr, LatLongBoundingBox boundingBox) {
    if (boundingBox is FlatLatLongBoundingBox) {
      boundingBox = GeodeticLatLongBoundingBox.fromFlat(boundingBox);
    }
    final item = this[elementNr];
    return boundingBox.contains(item.latitude, item.longitude);
  }
}

/// Indicates how the sorting requirement for [GpsPointsCollection] should
/// behave.
///
/// [SortingEnforcement.notRequired] means that the collection will accept
/// elements in non-sorted order.
/// [SortingEnforcement.skipWrongItems] means that the collection will not add
/// any elements that violate the sorting order, but not throw an exception.
/// [SortingEnforcement.throwIfWrongItems] means that the list will throw an
/// exception if trying to add elements that violate the sorting order.
enum SortingEnforcement {
  notRequired,
  skipWrongItems,
  throwIfWrongItems,
}

/// Stores GPS points with read/write access.
///
/// Provides read/write access to GPS points. Because lightweight
/// [GpsPointsView]s may be created on the data in the list, adding is the only
/// modification operation that's allowed, as inserting or removing could lead
/// to invalid views.
/// Subclass names may start with "Gpc".
abstract class GpsPointsCollection<T extends GpsPoint>
    extends GpsPointsView<T> {
  /// [_sortingEnforcement] defaults to the strictest possible setting, as it's
  /// easy to detect problems with this default and become more lenient if
  /// necessary. Hunting for bugs due to unexpected sorting issues in huge lists
  /// would however be very unpleasant, which could happen if the default was
  /// chosen to be lenient.
  SortingEnforcement _sortingEnforcement = SortingEnforcement.throwIfWrongItems;

  bool _sortedByTime = true;

  /// Whether the list is will disallow modifications that render it
  /// in a state that's not sorted by time. Setting this property to true
  /// while the collection is in an unsorted state will raise an exception.
  SortingEnforcement get sortingEnforcement => _sortingEnforcement;
  set sortingEnforcement(SortingEnforcement value) {
    // If unchanged, do nothing.
    if (sortingEnforcement == value) {
      return;
    }

    // Change to not force sorting is always safe.
    if (value == SortingEnforcement.notRequired) {
      _sortingEnforcement = value;
    } else {
      // Change to force sorting -> only safe if the contents are currently
      // sorted, otherwise throw an exception.
      if (!sortedByTime) {
        throw GpsPointsViewSortingException(
            'Cannot switch to force sorting by time if the list is currently unsorted.');
      } else {
        _sortingEnforcement = value;
      }
    }
  }

  @override
  bool get sortedByTime => _sortedByTime;

  /// Checks whether the contents are sorted by increasing time in cases where
  /// the list is not marked as [sortedByTime].
  ///
  /// Even if the collection is not marked as [sortedByTime], it might be
  /// entirely or partially sorted (depending on how its contents were
  /// initialized).
  /// If [sortedByTime] is true, the method immediately returns true. Otherwise
  /// it checks the contents (optionally skipping the first [skipItems] items
  /// and limiting itself to [nrItems] rather than the entire list) to determine
  /// if they are in fact sorted.
  /// In the situation that the list is found to be fully sorted,
  /// [sortedByTime] will be set to true as well.
  bool checkContentsSortedByTime([int skipItems = 0, int? nrItems]) {
    if (sortedByTime) {
      return true;
    }

    final endIndex = skipItems + (nrItems ?? (length - skipItems));

    var detectedSorted = true;
    for (var itemNr = skipItems + 1; itemNr < endIndex; itemNr++) {
      switch (compareElementTime(itemNr - 1, itemNr)) {
        case TimeComparisonResult.before:
          break; // Breaks the swithc, not the for loop.
        case TimeComparisonResult.same:
        case TimeComparisonResult.after:
        case TimeComparisonResult.overlapping:
          detectedSorted = false;
          break; // Breaks the switch, not the for loop.
      }
      // Stop the loop as soon as we find it's not sorted.
      if (!detectedSorted) {
        break;
      }
    }

    // If we compared the entire list and found it's sorted, set the internal
    // flag.
    if (detectedSorted && skipItems == 0 && endIndex == length) {
      _sortedByTime = true;
    }

    // Note that detectedSorted is not necessarily same as _sortedByTime,
    // since the comparison may have skipped a number of items at the beginning!
    return detectedSorted;
  }

  /// Add a single [element] to the collection.
  ///
  /// Returns true if the addition was successful. In case of failure it will
  /// either return false
  /// (if [sortingEnforcement] == [SortingEnforcement.skipWrongItems]) or
  /// it will throw [GpsPointsViewSortingException]
  /// (if [sortingEnforcement] == [SortingEnforcement.throwIfWrongItems]).
  bool add(T element) {
    try {
      // [GpcCompact] and subclasses have very fast comparison operations for
      // items that are in the list. It is therefore cheaper to not first check
      // if the new item is valid, but rather add it to the list, check if that
      // makes the list invalid, and rollback if necessary. This is of course
      // for the common case where additions are typically valid, because if
      // incoming data is mostly invalid the add-and-rollback combo may be more
      // expensive.
      add_Unsafe(element);

      // For the non-empty list, we need to take into consideration sorting
      // requirements.
      if (length <= 1) {
        return true;
      } else {
        // If it's already not sorted by time, we don't have to check anything, so
        // only do further checks if currently sorted.
        if (sortedByTime) {
          final comparison = compareElementTime(length - 2, length - 1);
          switch (comparison) {
            case TimeComparisonResult.before:
              return true;
            case TimeComparisonResult.same:
            case TimeComparisonResult.after:
            case TimeComparisonResult.overlapping:
              // Disallow adding unsorted item if configured to force sorting.
              if (sortingEnforcement != SortingEnforcement.notRequired) {
                throw GpsPointsViewSortingException(
                    'Adding element ${this[length - 1]} after ${this[length - 2]} would make the list unsorted!');
              }
              _sortedByTime = false;
              return true;
          }
        }
      }
    } on GpsPointsViewSortingException {
      rollbackAddingLastItem();
      if (sortingEnforcement == SortingEnforcement.throwIfWrongItems) {
        rethrow;
      } // otherwise we just skip the item, silently
      return false;
    }
    return false;
  }

  /// Removes the last object in this list, but only intended for use during
  /// [add] and similar calls. The list is in general not supposed to have
  /// insert/remove operations available as explained in the documentation
  /// of the list itself.
  @protected
  rollbackAddingLastItem();

  /// Internal implementation of [add], which does not do any safety checks
  /// regarding sorting. Only to be overridden in children.
  @protected
  // ignore: non_constant_identifier_names
  void add_Unsafe(T element);

  void addAll(Iterable<T> source) {
    addAllStartingAt(source);
  }

  /// Add all elements from [source] to [this], after skipping [skipItems]
  /// items from the [source]. [skipItems]=0 is equivalent to calling [addAll].
  void addAllStartingAt(Iterable<T> source, [int skipItems = 0, int? nrItems]) {
    if (nrItems != null && nrItems < 0) {
      throw (RangeError(
          'Incorrect number of items specified for addAllStartingAt: $nrItems'));
    }

    // If the collection doesn't care about sorting or it's already unsorted, go
    // ahead and add.
    if (sortingEnforcement == SortingEnforcement.notRequired || !sortedByTime) {
      _addAllStartingAt_NoSortingRequired(source, skipItems, nrItems);
      return;
    }

    // If the code arrives here, the current collection is sorted and cares
    // about sorting.

    // If the source is itself a collection, rely on its internal sorting
    // flags to determine the validity of the situation cheaply.
    if (source is GpsPointsCollection<T>) {
      _addAllStartingAt_CollectionSource(source, skipItems, nrItems);
      return;
    }

    // Source is some random iterable. Convert it to a collection and run it
    // through the procedure again. This is an expensive operation both in time
    // and in terms of memory. Memory could possibly be reduced by using an
    // async stream-based approach, but that's not worth the effort for now.

    // Pre-setting the capacity has a massive effect on speed - the benchmark
    // in point_addition.dart is about 3-4x faster with preset capacity than if
    // the list is grown incrementally with the natural capacity increasing
    // algo.
    int? copiedCapacity;
    if (source is RandomAccessIterable) {
      copiedCapacity = (source.length - skipItems);
    }

    final copiedSource =
        newEmpty(capacity: copiedCapacity) as GpsPointsCollection<T>;
    // Use same enforcement strategy as the target collection. That way if the
    // data is incorrect, it can be detected already while copying from the
    // iterable to the list.
    copiedSource.sortingEnforcement = sortingEnforcement;
    // Add the last item of the current collection, as that's going to be the
    // benchmark that everything else is compared to.
    if (isNotEmpty) {
      copiedSource.add(last);
    }
    // Only copy after any skipped items.
    final subSource = getSubSource(source, skipItems, nrItems);
    for (final element in subSource) {
      copiedSource.add(element);
    }
    // When adding, skip the reference item that we copied from the current
    // collection, if any.
    addAllStartingAt(copiedSource, isNotEmpty ? 1 : 0);
  }

  /// Implements the [addAllStartingAt] code path for the situation where the
  /// sorting is not relevant.
  // ignore: non_constant_identifier_names
  void _addAllStartingAt_NoSortingRequired(
      Iterable<T> source, int skipItems, int? nrItems) {
    final originalLength = length;
    addAllStartingAt_Unsafe(source, skipItems, nrItems);
    // If the collection was originally sorted by time, check if it still is.
    if (sortedByTime) {
      // Start checking including the original last element, because it needs
      // to determine if the first newly added element is sorted compared to
      // the original last element.
      checkContentsSortedByTime(
        originalLength > 0 // include original last element if there was one
            ? originalLength - 1 // position of original last element
            : 0, // no original last element -> start at beginning of list
        originalLength > 0 // extra item being last from original list
            ? nrItems != null
                ? nrItems + 1 // include the original last element
                : null
            : nrItems, // no original last element -> check all new items
      );
    }
  }

  /// Implements the [addAllStartingAt] code path for the situation where the
  /// source is a collection.
  // ignore: non_constant_identifier_names
  void _addAllStartingAt_CollectionSource(
      GpsPointsCollection<T> source, int skipItems, int? nrItems) {
    // Stop if there's nothing to add.
    if ((nrItems != null && nrItems < 1) || (source.length - skipItems < 1)) {
      return;
    }

    // If the source is sorted by time completely or at least for the part
    // starting at skipItems, find the correct starting point in the source for
    // performing the addition. Everything after that point can be inserted
    // immediately with confidence that sorted state will be maintained.
    if (source.checkContentsSortedByTime(skipItems, nrItems)) {
      late int maxStartingPoint;
      if (sortingEnforcement == SortingEnforcement.throwIfWrongItems) {
        // Unsorted parts not silently skipped during add() -> there must be
        // valid data from the start.
        maxStartingPoint = skipItems;
      } else {
        // Can skip unsorted parts during add() -> need valid data anywehere
        // between the start and the end.
        maxStartingPoint =
            nrItems != null ? nrItems + skipItems - 1 : source.length - 1;
      }

      // Find the starting point for the addition and add everything from there.
      for (var i = skipItems; i <= maxStartingPoint; i++) {
        if (add(source[i])) {
          // If the add() call didn't fail, this is the location where the two
          // lists can be joined while maintaining sorted conditions. Add the
          // rest of the source as well.
          // For the situation of
          // sortingEnforcement == SortingEnforcement.throwIfWrongItems,
          // the add() will throw an exception if the source[i] item is invalid
          // and the whole addition will (correctly) fail.
          addAllStartingAt_Unsafe(source, i + 1,
              nrItems != null ? nrItems - (i - skipItems) - 1 : null);
          return;
        }
      }

      // The execution will end up here if no valid starting point for the
      // addition of source to this collection was found -> can stop.
      return;
    } else {
      // Source is not sorted in the region that should be added. This requires
      // slow item-by-item adding. However, this is only possible if the list
      // is not set up to throw an exception in case of wrong items, because
      // otherwise it's guaranteed to throw at some point and hence the entire
      // operation is not allowed.
      if (sortingEnforcement == SortingEnforcement.skipWrongItems) {
        for (final element in getSubSource(source, skipItems, nrItems)) {
          add(element);
        }
      } else {
        assert(sortingEnforcement == SortingEnforcement.throwIfWrongItems);
        throw GpsPointsViewSortingException(
            'Adding all points from unsorted source would make the list unsorted.');
      }
    }
  }

  /// Returns a subset iterable from [source] that skips [skipItems] and copies
  /// up to [nrItems] (if specified) or the entire list (if not specified).
  @protected
  Iterable<T> getSubSource(Iterable<T> source, int skipItems, int? nrItems) {
    Iterable<T> subSource = source.skip(skipItems);
    if (nrItems != null) {
      subSource = subSource.take(nrItems);
    }
    return subSource;
  }

  /// Internal implementation of [addAllStartingAt], which does not do any
  /// safety checks regarding sorting. Only to be overridden in children.
  @protected
  // ignore: non_constant_identifier_names
  void addAllStartingAt_Unsafe(Iterable<T> source,
      [int skipItems = 0, int? nrItems]);

  @override
  GpsPointsCollection<T> sublist(int start, [int? end]) {
    end = RangeError.checkValidRange(start, end, length, 'start', 'end',
        'incorrect parameters for sublist() call');

    final result = newEmpty() as GpsPointsCollection<T>;

    result.addAllStartingAt(this, start, end - start);
    return result;
  }

  /// Collections are typically not read-only.
  @override
  bool get isReadonly => false;
}
