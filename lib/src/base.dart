/// Base classes for the GPS History functionality

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/src/hash.dart';
import 'package:meta/meta.dart';

/// [Exception] class that can act as ancestor for exceptions raised by
/// this package.
class GpsHistoryException implements Exception {
  final String? message;

  GpsHistoryException([this.message]);

  @override
  String toString() {
    final extraText = (message != null) ? ': $message' : '';
    return '${runtimeType.toString()}$extraText';
  }
}

/// Represents the most basic GPS location.
///
/// This excludes heading and accuracy information that is typically provided
/// by GPS sensors).
class GpsPoint {
  /// The datetime for the point record.
  final DateTime time;

  /// The latitude of the point, in degrees.
  final double latitude;

  /// The longitude of the point, in degrees.
  final double longitude;

  /// The altitude of the point, in meters (is not present for some data
  /// sources).
  final double? altitude;

  /// The DateTime that is regarded as point zero in various collection/storage
  /// implementations.
  static final zeroDateTime = DateTime.utc(1970);

  /// A point with all fields set to null if possible, or to zero otherwise.
  static final zeroOrNulls =
      GpsPoint(time: zeroDateTime, latitude: 0, longitude: 0);

  /// A point with all fields set to zero.
  static final allZero =
      GpsPoint(time: zeroDateTime, latitude: 0, longitude: 0, altitude: 0);

  /// Constant constructor, as modifying points while they're part of a
  /// collection could have bad effects in that collection's meta flags, like
  /// sorted state.
  const GpsPoint({
    required this.time,
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  /// Create a copy of the point with optionally one or more of its fields set
  /// to new values.
  GpsPoint copyWith({
    DateTime? time,
    double? latitude,
    double? longitude,
    double? altitude,
  }) {
    return GpsPoint(
      time: time ?? this.time,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
    );
  }

  /// Equality operator overload.
  ///
  /// Equality should be tested based on values, because we may use this class
  /// by instantiating it at runtime based on some other source. In that case,
  /// there may be multiple distinct instances representing the same point.
  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return other is GpsPoint &&
        other.time == time &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude;
  }

  @override
  int get hashCode {
    return hash4(time, latitude, longitude, altitude);
  }

  @override
  String toString() =>
      't: $time\tlat:\t$latitude\tlong: $longitude\talt: $altitude';
}

/// GPS point with additional information related to the measurement.
///
/// Some fields may be unavailable (null), depending on data source.
class GpsMeasurement extends GpsPoint {
  /// The accuracy of the measurement.
  final double? accuracy;

  /// The heading of the device.
  final double? heading;

  /// The speed, in meter/second.
  final double? speed;

  /// The accuracy of the speed measurement.
  final double? speedAccuracy;

  /// A measurement with all fields set to null if possible, or to zero otherwise.
  static final zeroOrNulls = GpsMeasurement.fromPoint(GpsPoint.zeroOrNulls);

  /// A measurement with all fields set to zero.
  static final allZero = GpsMeasurement.fromPoint(GpsPoint.allZero,
      accuracy: 0, heading: 0, speed: 0, speedAccuracy: 0);

  /// Constant constructor, as modifying points while they're part of a
  /// collection could have bad effects in that collection's meta flags, like
  /// sorted state.
  const GpsMeasurement({
    required DateTime time,
    required double latitude,
    required double longitude,
    double? altitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.speedAccuracy,
  }) : super(
          time: time,
          latitude: latitude,
          longitude: longitude,
          altitude: altitude,
        );

  GpsMeasurement.fromPoint(
    GpsPoint point, {
    this.accuracy,
    this.heading,
    this.speed,
    this.speedAccuracy,
  }) : super(
            time: point.time,
            latitude: point.latitude,
            longitude: point.longitude,
            altitude: point.altitude);

  @override
  GpsMeasurement copyWith(
      {DateTime? time,
      double? latitude,
      double? longitude,
      double? altitude,
      double? accuracy,
      double? heading,
      double? speed,
      double? speedAccuracy}) {
    return GpsMeasurement(
      time: time ?? this.time,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      speedAccuracy: speedAccuracy ?? this.speedAccuracy,
    );
  }

  @override
  bool operator ==(other) {
    if (!(super == (other))) {
      return false;
    }
    return other is GpsMeasurement &&
        other.accuracy == accuracy &&
        other.heading == heading &&
        other.speed == speed &&
        other.speedAccuracy == speedAccuracy;
  }

  @override
  int get hashCode {
    return hash5(super.hashCode, accuracy, heading, speed, speedAccuracy);
  }

  @override
  String toString() =>
      '${super.toString()}\tacc: $accuracy\thdng: $heading\tspd: $speed\tspdacc: $speedAccuracy';
}

/// Abstract class representing iterables with fast random access to contents.
///
/// Subclasses should implement fast access to [length], getting item by index
/// and similar functionality. This can not be enforced, but code using it
/// will rely on these operations not looping over the entire contents before
/// returning a result.
abstract class RandomAccessIterable<T> extends Iterable<T>
//with IterableMixin<T>
{
  T operator [](int index);

  @override
  RandomAccessIterator<T> get iterator => RandomAccessIterator<T>(this);

  @override
  T elementAt(int index) {
    return this[index];
  }

  @override
  T get first {
    if (isEmpty) {
      throw StateError('no element');
    }
    return this[0];
  }

  @override
  T get last {
    if (isEmpty) {
      throw StateError('no element');
    }
    return this[length - 1];
  }

  @override
  bool get isEmpty => length == 0;

  @override
  RandomAccessIterable<T> skip(int count) {
    return RandomAccessSkipIterable<T>(this, count);
  }
}

/// Iterator support for [RandomAccessIterable].
///
/// The iterator allows [RandomAccessIterable] and children to easily implement
/// an Iterable interface. An important limitation is that the wrapped
/// [RandomAccessIterable] must be random-access, with quick access to items and
/// properties like length. This is a workaround for the fact that Dart doesn't
/// expose the [RandomAccessSkipIterable] interface for implementation in
/// third party code.
class RandomAccessIterator<T> extends Iterator<T> {
  int _index = -1;
  final RandomAccessIterable<T> _source;

  /// Creates the iterator for the specified [_source] iterable, optionally
  /// allowing to skip [skipCount] items at the start of the iteration.
  RandomAccessIterator(this._source, [int skipCount = 0]) {
    assert(skipCount >= 0);
    _index += skipCount;
  }

  @override
  bool moveNext() {
    if (_index + 1 >= _source.length) {
      return false;
    }

    _index += 1;
    return true;
  }

  @override
  T get current {
    return _source[_index];
  }
}

/// An iterable aimed at quickly skipping a number of items at the beginning.
class RandomAccessSkipIterable<T> extends RandomAccessIterable<T> {
  final RandomAccessIterable<T> _iterable;
  final int _skipCount;

  factory RandomAccessSkipIterable(
      RandomAccessIterable<T> iterable, int skipCount) {
    return RandomAccessSkipIterable<T>._(iterable, _checkCount(skipCount));
  }

  RandomAccessSkipIterable._(this._iterable, this._skipCount);

  @override
  T operator [](int index) => _iterable[index + _skipCount];

  @override
  int get length {
    int result = _iterable.length - _skipCount;
    if (result >= 0) return result;
    return 0;
  }

  @override
  RandomAccessIterable<T> skip(int count) {
    return RandomAccessSkipIterable<T>._(
        _iterable, _skipCount + _checkCount(count));
  }

  @override
  RandomAccessIterator<T> get iterator {
    return RandomAccessIterator<T>(_iterable, _skipCount);
  }

  static int _checkCount(int count) {
    RangeError.checkNotNegative(count, "count");
    return count;
  }
}

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

  // Other
//  GpsPointsView<T> selectInBoundingBox(double minLatitude, double minLongitude,
//      double maxLatitude, double maxLongitude);
}

/// Used as result type for time comparison.
///
/// The enumeration values of [before], [same] and [after] are self-explanatory.
/// [overlapping] is used in situations where the compared times are time
/// spans rather than moments, meaning that the time spans may overlap partially
/// or completely.
enum TimeComparisonResult {
  before,
  same,
  after,
  overlapping,
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

  /// Creates a collection of the same type as this.
  ///
  /// To be overridden and implemented in children.
  @protected
  GpsPointsCollection<T> newEmpty();

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

  /// Indicates whether the contents are sorted in increasing order of time
  /// value. If this is the case, time-based queries can be faster by performing
  /// a binary search.
  bool get sortedByTime => _sortedByTime;

  /// Checks whether the contents are sorted by increasing time in cases where
  /// the list is not marked as [sortedByTime].
  ///
  /// Even if the collection is not marked as [sortedByTime], it might be
  /// entirely or partially sorted (depending on how its contents were
  /// initialized).
  /// If [sortedByTime] is true, the method immediately returns true. Otherwise
  /// it checks the contents (optionally skipping the first [skipItems] items)
  /// to determine if they are in fact sorted.
  /// In the situation that the list is found to be fully sorted,
  /// [sortedByTime] will be set to true as well.
  bool checkContentsSortedByTime([int skipItems = 0]) {
    if (sortedByTime) {
      return true;
    }

    var detectedSorted = true;
    for (var itemNr = skipItems + 1; itemNr < length; itemNr++) {
      switch (compareElementTime(itemNr - 1, itemNr)) {
        case TimeComparisonResult.before:
          continue;
        case TimeComparisonResult.same:
        case TimeComparisonResult.after:
        case TimeComparisonResult.overlapping:
          detectedSorted = false;
          break;
      }
    }

    // If we compared the entire list and found it's sorted, set the internal
    // flag.
    if (detectedSorted && skipItems == 0) {
      _sortedByTime = true;
    }

    // Note that detectedSorted is not necessarily same as _sortedByTime,
    // since the comparison may have skipped a number of items at the beginning!
    return detectedSorted;
  }

  /// Performs [compareTime] for the elements in the positions [elementNrA]
  /// and [elementNrB], then returns the result.
  ///
  /// Children my override this method to implement more efficient or custom
  /// implementations, for example if they support overlapping time or if
  /// they have a way to do quick time comparisons without doing full item
  /// retrieval.
  TimeComparisonResult compareElementTime(int elementNrA, int elementNrB) {
    return compareTime(this[elementNrA], this[elementNrB]);
  }

  /// Performs [compareTime] for the item in the positions [elementNr]
  /// and some separate [item] that's presumably not in the list, then returns
  /// the result.
  ///
  /// Children my override this method to implement more efficient or custom
  /// implementations, for example if they support overlapping time or if
  /// they have a way to do quick time comparisons without doing full item
  /// retrieval.
  TimeComparisonResult compareElementTimeWithSeparateItem(
      int elementNr, T item) {
    return compareTime(this[elementNr], item);
  }

  /// Compares the time values of [itemA] and [itemB] and returns the result.
  ///
  /// If the time of [itemA] is considered before that of [itemB], the result
  /// will be [TimeComparisonResult.before], etc.
  TimeComparisonResult compareTime(T itemA, T itemB) {
    switch (itemA.time.compareTo(itemB.time)) {
      case -1:
        return TimeComparisonResult.before;
      case 0:
        return TimeComparisonResult.same;
      case 1:
        return TimeComparisonResult.after;
      default:
        throw GpsPointsViewSortingException('Unexpected compareTo result!');
    }
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
  void addAllStartingAt(Iterable<T> source, [int skipItems = 0]) {
    // If the collection doesn't care about sorting or it's already unsorted, go
    // ahead and add.
    if (sortingEnforcement == SortingEnforcement.notRequired || !sortedByTime) {
      _addAllStartingAt_NoSortingRequired(source, skipItems);
      return;
    }

    // If the code arrives here, the current collection is sorted and cares
    // about sorting.

    // If the source is itself a collection, rely on its internal sorting
    // flags to determine the validity of the situation cheaply.
    if (source is GpsPointsCollection<T>) {
      _addAllStartingAt_CollectionSource(source, skipItems);
      return;
    }

    // Source is some random iterable. Convert it to a collection and run it
    // through the procedure again. This is an expensive operation both in time
    // and in terms of memory. Memory could possibly be reduced by using an
    // async stream-based approach, but that's not worth the effort for now.
    final copiedSource = newEmpty();
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
    for (final element in source.skip(skipItems)) {
      copiedSource.add(element);
    }
    // When adding, skip the reference item that we copied from the current
    // collection, if any.
    addAllStartingAt(copiedSource, isNotEmpty ? 1 : 0);
  }

  /// Implements the [addAllStartingAt] code path for the situation where the
  /// sorting is not relevant.
  // ignore: non_constant_identifier_names
  void _addAllStartingAt_NoSortingRequired(Iterable<T> source, int skipItems) {
    final originalLength = length;
    addAllStartingAt_Unsafe(source, skipItems);
    // If the collection was originally sorted by time, check if it still is.
    if (sortedByTime) {
      // Start checking including the original last element, because it needs
      // to determine if the first newly added element is sorted compared to
      // the original last element.
      checkContentsSortedByTime(
          originalLength > 0 // include original last element if there was one
              ? originalLength - 1 // position of original last element
              : 0 // no original last element -> start at beginning of list
          );
    }
  }

  /// Implements the [addAllStartingAt] code path for the situation where the
  /// source is a collection.
  // ignore: non_constant_identifier_names
  void _addAllStartingAt_CollectionSource(
      GpsPointsCollection<T> source, int skipItems) {
    // Stop if there's nothing to add.
    if (source.length - skipItems < 1) {
      return;
    }

    // If the source is sorted by time completely or at least for the part
    // starting at skipItems, find the correct starting point in the source for
    // performing the addition. Everything after that point can be inserted
    // immediately with confidence that sorted state will be maintained.
    if (source.checkContentsSortedByTime(skipItems)) {
      int maxStartingPoint = sortingEnforcement ==
              SortingEnforcement.throwIfWrongItems
          ? skipItems // unsorted not skipped -> there must be valid data from the start
          : source.length - 1; // can skip unsorted -> need valid data anywehere

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
          addAllStartingAt_Unsafe(source, i + 1);
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
        for (final element in source.skip(skipItems)) {
          add(element);
        }
      } else {
        assert(sortingEnforcement == SortingEnforcement.throwIfWrongItems);
        throw GpsPointsViewSortingException(
            'Adding all points from unsorted source would make the list unsorted.');
      }
    }
  }

  /// Internal implementation of [addAllStartingAt], which does not do any
  /// safety checks regarding sorting. Only to be overridden in children.
  @protected
  // ignore: non_constant_identifier_names
  void addAllStartingAt_Unsafe(Iterable<T> source, [int skipItems = 0]);

  /// Collections are typically not read-only.
  @override
  bool get isReadonly => false;
}
