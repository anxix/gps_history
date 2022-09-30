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

import 'package:gps_history/gps_history.dart';

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
abstract class Query<C extends GpsPointsView, R extends QueryResult> {
  /// Function that executes the actual query and returns the result.
  R query(C collection);
}

/// Query result for [QueryListInfo].
class ListInfo extends QueryResult {
  /// The start time of the first item in the collection, if non-empty.
  GpsTime? firstItemStartTime;

  /// The end time of the last item in the collection, if non-empty.
  GpsTime? lastItemEndTime;

  /// The number of items in the collection.
  int length;

  ListInfo(this.firstItemStartTime, this.lastItemEndTime, this.length);
}

/// Queries generic information about the collection and returns it as result
/// of [ListInfo] type.
class QueryListInfo<C extends GpsPointsView> extends Query<C, ListInfo> {
  @override
  ListInfo query(C collection) {
    return ListInfo(
        collection.isNotEmpty ? collection.first.time : null,
        collection.isNotEmpty ? collection.last.endTime : null,
        collection.length);
  }
}

/// Query result for [QueryListItems].
class SubList<C extends GpsPointsView> extends QueryResult {
  final int startIndex;

  final C collection;

  SubList(this.startIndex, this.collection);
}

/// Returns specified item range from the collection and as result
/// of [SubList] type.
///
/// The result will be a copy of the data, so that it can be transferred
/// cheaply via an isolate port.
class QueryListItems<C extends GpsPointsView> extends Query<C, SubList<C>> {
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
  QueryListItems({int startIndex = 0, int? nrItems})
      : _startIndex = startIndex,
        _nrItems = nrItems;

  @override
  SubList<C> query(C collection) {
    return SubList<C>(_startIndex,
        collection.subList(startIndex: _startIndex, nrItems: _nrItems) as C);
  }
}

// class QueryTime extends Query {}

// class QueryBoundingBox extends Query {}