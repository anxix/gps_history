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

  GpsPoint(this.time, this.latitude, this.longitude, this.altitude);

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

  GpsMeasurement(
      DateTime time,
      double latitude,
      double longitude,
      double? altitude,
      this.accuracy,
      this.heading,
      this.speed,
      this.speedAccuracy)
      : super(time, latitude, longitude, altitude);

  GpsMeasurement.fromPoint(GpsPoint point, this.accuracy, this.heading,
      this.speed, this.speedAccuracy)
      : super(point.time, point.latitude, point.longitude, point.altitude);

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
  T operator [](int index) => _iterable[index];

  @override
  int get length {
    int length = _iterable.length - _skipCount;
    if (length >= 0) return length;
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

/// Stores GPS points with read/write access.
///
/// Provides read/write access to GPS points. Because lightweight
/// [GpsPointsView]s may be created on the data in the list, adding is the only
/// modification operation that's allowed, as inserting or removing could lead
/// to invalid views.
/// Subclass names may start with "Gpc".
abstract class GpsPointsCollection<T extends GpsPoint>
    extends GpsPointsView<T> {
  bool _forceSortedTime = true;
  bool _sortedByTime = true;

  /// Whether the list is will disallow modifications that render it
  /// in a state that's not sorted by time. Setting this property to true
  /// while the collection is in an unsorted state will raise an exception.
  bool get forceSortedTime => _forceSortedTime;
  set forceSortedTime(bool value) {
    // If unchanged, do nothing.
    if (forceSortedTime == value) {
      return;
    }

    // Change to not force sorting is always safe.
    if (!value) {
      _forceSortedTime = value;
    } else {
      // Change to force sorting -> only safe if the contents are currently
      // sorted, otherwise throw an exception.
      if (!sortedByTime) {
        throw GpsPointsViewSortingException(
            'Cannot switch to force sorting by time if the list is currently unsorted.');
      } else {
        _forceSortedTime = value;
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
      switch (compareItemTime(itemNr - 1, itemNr)) {
        case TimeComparisonResult.before:
        case TimeComparisonResult.same:
          continue;
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

  /// Performs [compareTime] for the items in the positions [itemNrA]
  /// and [itemNrB], then returns the result.
  ///
  /// Children my override this method to implement more efficient or custom
  /// implementations, for example if they support overlapping time or if
  /// they have a way to do quick time comparisons without doing full item
  /// retrieval.
  TimeComparisonResult compareItemTime(int itemNrA, int itemNrB) {
    return compareTime(this[itemNrA], this[itemNrB]);
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
  void add(T element) {
    // For the non-empty list, we need to take into consideration sorting
    // requirements.
    if (isNotEmpty) {
      // If it's already not sorted by time, we don't have to check anything, so
      // only do further checks if currently sorted.
      if (sortedByTime) {
        final comparison = compareTime(last, element);
        switch (comparison) {
          case TimeComparisonResult.before:
          case TimeComparisonResult.same:
            break;
          case TimeComparisonResult.after:
          case TimeComparisonResult.overlapping:
            // Disallow adding unsorted item if configured to force sorting.
            if (forceSortedTime) {
              throw GpsPointsViewSortingException('');
            }
            _sortedByTime = false;
        }
      }
    }

    addUnsafe(element);
  }

  /// Internal implementation of [add], which does not do any safety checks
  /// regarding sorting. Only to be overridden in children.
  @protected
  void addUnsafe(T element) {
    if (isNotEmpty) {}
  }

  void addAll(Iterable<T> source) {
    addAllStartingAt(source);
  }

  /// Add all elements from [source] to [this], after skipping [skipItems]
  /// items from the [source]. [skipItems]=0 is equivalent to calling [addAll].
  void addAllStartingAt(Iterable<T> source, [int skipItems = 0]);

  /// Collections are typically not read-only.
  @override
  bool get isReadonly => false;
}
