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

import '../../gps_queries.dart';
import '../base.dart';
import '../base_collections.dart';
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
/// [C] and result type [R].
///
/// Since queries may have specific implementations for particular collection
/// types, they are generics parametrized for collection type.
///
/// The goal is to be able to send queries to a separate isolate and get the
/// results back efficiently. This requires the [Query] children to store
/// internally a representation that is cheap to transfer over an isolate port.
abstract class Query<C extends GpsPointsView, R extends QueryResult> {
  /// Function that executes the actual query and returns the result.
  R query(C collection);
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
class QueryCollectionInfo<C extends GpsPointsView>
    extends Query<C, CollectionInfo> {
  @override
  CollectionInfo query(C collection) {
    return CollectionInfo(
        collection.isNotEmpty ? collection.first.time : null,
        collection.isNotEmpty ? collection.last.endTime : null,
        collection.length);
  }
}

/// Query result for [QueryCollectionItems].
class CollectionItems<C extends GpsPointsView> extends QueryResult {
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
class QueryCollectionItems<C extends GpsPointsView>
    extends Query<C, CollectionItems<C>> {
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
  CollectionItems<C> query(C collection) {
    final end = _nrItems == null ? collection.length : _startIndex + _nrItems!;
    return CollectionItems<C>(
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

  /// The point that was found
  final P? location;

  LocationByTime(this.time, this.toleranceSeconds, this.location);
}

/// Finds the location at a specific time if available, or the nearest within
/// a specified tolerance, returning it as a result of [LocationByTime] type.
///
/// This type of query can be used to e.g. show a marker on a map based on
/// a selected moment in time.
class QueryLocationByTime<C extends GpsPointsView<P>, P extends GpsPoint>
    extends Query<C, LocationByTime<P>> {
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
  LocationByTime<P> query(C collection) {
    final compareFunc = makeTimeCompareFunc();
    final searchAlgorithm = SearchAlgorithm.getBestAlgorithm(
        collection, collection.sortedByTime, compareFunc);
    final resultIndex = searchAlgorithm.find(_time);
    return LocationByTime(_time, _toleranceSeconds,
        resultIndex != null ? collection[resultIndex] : null);
  }
}

// class QueryBoundingBox extends Query {}
