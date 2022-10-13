/// Queries allow seleting particular subdata from collsection of GPS point
/// data.
///
/// Queries:
///
/// 1) Timeline rendering, or showing on a calendar which days have recordings
///    in a particular region.
///    Input:
///      - list of time instances, each with a tolerance
///      - optionally a BB
///    Output:
///      A list of results, one for each input element, indicating one of:
///      - position information available
///      - position information available, but outside BB
///      - no position information available
///    Special cases:
///      If the times with their tolerances overlap, cut off
///      tolerances such that there's no overlap.
///    Expected number of input/output items:
///      At most about 8k on a desktop, more typically hundreds up to 2k.
///
/// 2) Places you've been in a certain period and in a particular region, but
///    limiting the number of reponses so the map rendering doesn't get
///    overwhelmed.
///    Input:
///      - time range
///      - bounding box
///      - horizontal and vertical number of grid rectangles within the
///        bounding box such that at most one result is returned per grid
///        rectangle.
///    Output:
///      A list of points (time+location info), at most one per grid rectangle.
///    Expected number of input/output items:
///      The goal being to render location indicators on a map, each grid rect
///      shouldn't be larger than a location icon, say 16x16px. For an 8k
///      screen, resolution is about 33Mpx giving a max. of about 125k grid
///      items. For phone screens they're more in the 400kpx resolution, giving
///      a max of about 1.5k items. It's more likely there will be way fewer
///      items though, because the user will never have been on every grid
///      rectangle.
///
/// 3) Location at a specific time, with a given tolerance.
///    Input:
///      - time with tolerance
///    Output:
///      - null (if no location found for the specific period) or
///      - a single location being the one nearest to the specified time
///
/// 4) Information about the list.
///    Output:
///      - time of first item, time of last item, number of items.
///
/// 5) Item(s) at a particular index range in the list (e.g. for showing in
///    a table).
///    Input:
///      - start index
///      - number of items (if will reach beyond length, auto-capped)
///    Output:
///      - up to number of items from the list, starting at the start index

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:typed_data';

import '../../gps_queries.dart';
import '../base.dart';
import '../base_collections.dart';
import '../utils/bounding_box.dart';
import '../utils/hash.dart';
import '../utils/time.dart';

/// Abstract ancestor class for query results.
///
/// The goal is to be able to send queries to a separate isolate and get the
/// results back efficiently. This requires the [QueryResult] children to store
/// internally a representation that is cheap to transfer over an isolate port.
/// In particular for transferring point collections, the efficient collections
/// perform very well, but the list-based collection is very slow.
abstract class QueryResult {}

/// Abstract generic ancestor class for queries parametrized for collection type
/// [C] containing points of type [P] and returning result type [R].
///
/// Since queries may have specific implementations for particular collection
/// types, they are generics parametrized for collection type.
///
/// The goal is to be able to send queries to a separate isolate and get the
/// results back efficiently. This requires the [Query] children to store
/// internally a representation that is cheap to transfer over an isolate port.
abstract class Query<P extends GpsPoint, C extends GpsPointsView<P>,
    R extends QueryResult> {
  /// Function that executes the actual query and returns the result.
  Future<R> query(C collection);
}

/// Query result for [QueryCollectionInfo].
class CollectionInfo extends QueryResult {
  /// The start time of the first item in the collection, if non-empty.
  GpsTime? firstItemStartTime;

  /// The end time of the last item in the collection, if non-empty.
  GpsTime? lastItemEndTime;

  /// The number of items in the collection.
  int length;

  CollectionInfo(this.firstItemStartTime, this.lastItemEndTime, this.length);
}

/// Queries generic information about the collection and returns it as result
/// of [CollectionInfo] type.
///
/// This type of query can be useful e.g. for determining how many rows to
/// report in a table of all points, or what time span a timeline should
/// display.
class QueryCollectionInfo<P extends GpsPoint, C extends GpsPointsView<P>>
    extends Query<P, C, CollectionInfo> {
  @override
  Future<CollectionInfo> query(C collection) async {
    return CollectionInfo(
        collection.isNotEmpty ? collection.first.time : null,
        collection.isNotEmpty ? collection.last.endTime : null,
        collection.length);
  }
}

/// Query result for [QueryCollectionItems].
class CollectionItems<P extends GpsPoint, C extends GpsPointsView<P>>
    extends QueryResult {
  /// The starting index for which the query was executed.
  final int startIndex;

  /// A collection of the same type as the one the query was apllied to,
  /// containing copies of the requested items.
  final C collection;

  CollectionItems(this.startIndex, this.collection);
}

/// Returns specified item range from the collection and as result
/// of [CollectionItems] type.
///
/// The result will be a copy of the data, so that it can be transferred
/// cheaply via an isolate port.
///
/// This type of query can be used to e.g. populate rows in a table.
class QueryCollectionItems<P extends GpsPoint, C extends GpsPointsView<P>>
    extends Query<P, C, CollectionItems<P, C>> {
  final int _startIndex;
  final int? _nrItems;

  /// Constructor for the query, with arguments indicating how much of the
  /// collection should be returned.
  ///
  /// [startIndex] indicates, if provided, the first item that should be copied
  /// by the query. If not provided, it defaults to 0.
  ///
  /// [nrItems] indicates, if provided, how many items should be copied by the
  /// query. If not provided (or null), the copying will copy till the end of
  /// the collection (equivalent to providing (length-startIndex)).
  QueryCollectionItems({int startIndex = 0, int? nrItems})
      : _startIndex = startIndex,
        _nrItems = nrItems;

  @override
  Future<CollectionItems<P, C>> query(C collection) async {
    final end = _nrItems == null ? collection.length : _startIndex + _nrItems!;
    return CollectionItems<P, C>(
        _startIndex, collection.sublist(_startIndex, end) as C);
  }
}

/// Query result for [QueryLocationByTime].
class LocationByTime<P extends GpsPoint> extends QueryResult {
  /// The time for which the query was executed.
  final GpsTime time;

  /// The tolerance that was specified for finding the location (if no exact
  /// match was available).
  final int? toleranceSeconds;

  /// The point that was found.
  final P? location;

  LocationByTime(this.time, this.toleranceSeconds, this.location);
}

/// Finds the location at a specific time if available, or the nearest within
/// a specified tolerance, returning it as a result of [LocationByTime] type.
///
/// This type of query can be used to e.g. show a marker on a map based on
/// a selected moment in time.
class QueryLocationByTime<P extends GpsPoint, C extends GpsPointsView<P>>
    extends Query<P, C, LocationByTime<P>> {
  final GpsTime _time;
  final int? _toleranceSeconds;

  /// Creates the query with [time] indicating at what time we want to find a
  /// location. The optionsl [toleranceSeconds], if provided, allows finding
  /// a location that is nearest to [time], within +/- the tolerance if no
  /// exact match is identified.
  QueryLocationByTime(GpsTime time, int? toleranceSeconds)
      : _time = time,
        _toleranceSeconds = toleranceSeconds;

  @override
  Future<LocationByTime<P>> query(C collection) async {
    final searchAlgorithm = SearchAlgorithm.getBestAlgorithm(
        collection,
        collection.sortedByTime,
        SearchCompareDiff(compareItemToTime, diffItemAndTime));
    final resultIndex = searchAlgorithm.find(_time, _toleranceSeconds);
    return LocationByTime(_time, _toleranceSeconds,
        resultIndex != null ? collection[resultIndex] : null);
  }
}

/// Represents the data availability for [DataAvailability] results.
///
/// Possible values:
/// * [Data.notAvailable]: no data was found for that interval
/// * [Data.availableOutsideBoundingBox]: data was found, but only outside the
///   specified bounding box.
/// * [Data.availableWithinBoundingBox]: data was found within the specified
///   bounding box.
enum Data {
  notAvailable,
  availableOutsideBoundingBox,
  availableWithinBoundingBox,
}

/// Query result for [QueryDataAvailability].
class DataAvailability extends QueryResult {
  /// The start time for which the query was executed.
  final GpsTime startTime;

  /// The end time for which the query was executed.
  final GpsTime endTime;

  /// The number of time intervals (should be equal to the number of entries
  /// in [_items]).
  final int nrIntervals;

  /// If specified, the bounding box within which the query was executed.
  final GeodeticLatLongBoundingBox? boundingBox;

  /// Contains for each interval a [Data] as integer (so
  /// that it can be transferred cheaply via isolates, which would not be the
  /// case if this was List<> based).
  final Uint8List _items;

  DataAvailability(this.startTime, this.endTime, this.nrIntervals,
      this.boundingBox, List<Data> foundData)
      : _items = Uint8List(foundData.length) {
    for (var i = 0; i < foundData.length; i++) {
      _items[i] = foundData[i].index;
    }
  }

  /// Returns for each interval what data availability was identified.
  Data operator [](int index) => Data.values[_items[index]];

  /// Returns the number of items, normally equal to [nrIntervals].
  int get length => _items.length;
}

/// Represents a time interval for a [QueryDataAvailability].
class Interval {
  /// Start time of the interval.
  GpsTime start;

  /// End time of the interval.
  GpsTime end;

  Interval(this.start, this.end);

  /// Creates an interval directly from times specified in seconds.
  factory Interval.fromSeconds(int startSeconds, int endSeconds) {
    return Interval(GpsTime(startSeconds), GpsTime(endSeconds));
  }

  @override
  operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return other is Interval && other.start == start && other.end == end;
  }

  @override
  int get hashCode => hash2(start, end);

  @override
  String toString() => 'start: $start, end: $end';
}

/// Returns a stream of [nrInterval] [Interval]s distributed as equally as
/// possible between [startTime] and [endTime].
Stream<Interval> generateIntervals(
    GpsTime startTime, GpsTime endTime, int nrIntervals) async* {
  if (nrIntervals <= 0 || !startTime.isBefore(endTime)) {
    return;
  }

  final intervalDuration = endTime.difference(startTime) / nrIntervals;

  for (var intervalNr = 0; intervalNr < nrIntervals; intervalNr++) {
    final intervalStart =
        startTime.add(seconds: (intervalNr * intervalDuration).round());
    final intervalEnd =
        startTime.add(seconds: ((intervalNr + 1) * intervalDuration).round());

    yield Interval(intervalStart, intervalEnd);
  }
}

/// Identifies if location data is available for specific time intervals,
/// optionally within a specific bounding box.
///
/// This type of query can be used to e.g. render a timeline, or show in
/// a calendar which days have recordings in a particular geographic region.
///
/// The amount of data to be returned is expected to have an upper boundary
/// of about 8k for a desktop with a very high resolution screen.
class QueryDataAvailability<P extends GpsPoint, C extends GpsPointsView<P>>
    extends Query<P, C, DataAvailability> {
  final GpsTime _startTime;
  final GpsTime _endTime;
  final int _nrIntervals;
  final GeodeticLatLongBoundingBox? _boundingBox;

  /// Creates a query for the period between [startTime] and [endTime], to be
  /// split into [nrIntervals] intervals. The query will identify for each of
  /// these intervals if data is available in the target collection, optionally
  /// constrained to the [boundingBox].
  QueryDataAvailability(GpsTime startTime, GpsTime endTime, int nrIntervals,
      GeodeticLatLongBoundingBox? boundingBox)
      : _startTime = startTime,
        _endTime = endTime,
        _nrIntervals = nrIntervals,
        _boundingBox = boundingBox;

  @override
  Future<DataAvailability> query(C collection) async {
    // Determine how many items to generate based on the input parameters. This
    // also helps prevent issues in case of bad input parameters.
    final nrIntervals = _nrIntervals > 0 &&
            _startTime.isBefore(_endTime) &&
            collection.length > 0
        ? _nrIntervals
        : 0;
    final foundData = List<Data>.filled(nrIntervals, Data.notAvailable);

    if (nrIntervals > 0) {
      // TODO: Convert bounding box to flat representation if necessary.

      final intervalsStream =
          generateIntervals(_startTime, _endTime, nrIntervals);

      var intervalNr = -1;
      if (collection.sortedByTime) {
        final searchAlgorithm = SearchAlgorithm.getBestAlgorithm<P, C, GpsTime>(
            collection,
            true,
            SearchCompareDiff<C, GpsTime>(compareItemToTime, diffItemAndTime));

        // Pick a tolerance based on the interval. This should guarantee that
        // it either finds both start and end of the interval, or neither.
        final tolerance = _endTime.difference(_startTime);

        await for (final interval in intervalsStream) {
          intervalNr++;
          var startIndex = searchAlgorithm.find(interval.start, tolerance);
          var endIndex = interval.start == interval.end
              ? startIndex
              : searchAlgorithm.find(interval.end, tolerance);

          foundData[intervalNr] = _binarySearchForInterval(
              collection, interval, startIndex, endIndex);
        }
      } else {
        await for (final interval in intervalsStream) {
          intervalNr++;
          foundData[intervalNr] =
              _linearSearchForInterval(collection, interval);
        }
      }
    }

    return DataAvailability(
        _startTime, _endTime, _nrIntervals, _boundingBox, foundData);
  }

  Data _binarySearchForInterval(
      C collection, Interval interval, int? startIndex, int? endIndex) {
    var result = Data.notAvailable;

    // If nothing found, looks like no data available for this interval.
    if (startIndex == null || endIndex == null) {
      return result;
    }

    // Data found for the interval -> see if it is indeed interesting.
    for (var index = startIndex; index <= endIndex; index++) {
      final comparison = collection.compareElementTimeWithSeparateTimeSpan(
          index,
          interval.start.secondsSinceEpoch,
          interval.end.secondsSinceEpoch);

      final gpsItem = collection[index];
      // If the item is relevant to the interval, compare bounding box.
      if (comparison == TimeComparisonResult.overlapping ||
          comparison == TimeComparisonResult.same) {
        if (_boundingBox == null ||
            _boundingBox!.contains(gpsItem.latitude, gpsItem.longitude)) {
          // It's in the bounding box or the bounding box is irrelevant,
          // so this is as good as it gets -> go to next interval.
          return Data.availableWithinBoundingBox;
        } else {
          // Bounding box is relevant and not within the box -> store as
          // match, but continue looking as there may still be a match
          // that will also be within the box.
          result = Data.availableOutsideBoundingBox;
        }
      }
    }

    return result;
  }

  Data _linearSearchForInterval(C collection, Interval interval) {
    var result = Data.notAvailable;

    // Unsorted -> horribly slow linear search.
    for (var i = 0; i < collection.length; i++) {
      final item = collection[i];
      final timeComparison = compareTimeSpans(
          startA: interval.start.secondsSinceEpoch,
          endA: interval.end.secondsSinceEpoch,
          startB: item.time.secondsSinceEpoch,
          endB: item.endTime.secondsSinceEpoch);

      if (timeComparison == TimeComparisonResult.overlapping ||
          timeComparison == TimeComparisonResult.same) {
        // This is a matching time, so it's definitely relevant.
        if (_boundingBox == null ||
            _boundingBox!.contains(item.latitude, item.longitude)) {
          // It's in the bounding box or the bounding box is irrelevant,
          // so this is as good as it gets -> go to next interval.
          return Data.availableWithinBoundingBox;
        } else {
          // Bounding box is relevant and not within the box -> store as
          // match, but continue looking as there may still be a match
          // that will also be within the box.
          result = Data.availableOutsideBoundingBox;
        }
      }
    }

    return result;
  }
}
