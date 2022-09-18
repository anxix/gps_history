/// Simple list-based GPS points collection

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/src/base.dart';

/// A collection that internally stores the points in a basic list.
///
/// This is easy to follow and understand, but consumes a lot of memory
/// compared to more efficient implementations, due to the overhead of the
/// objects and the use of doubles.
class GpcListBased<T extends GpsPoint> extends GpsPointsCollection<T> {
  /// The points in the collection.
  final List<T> _points = [];

  GpcListBased();

  @override
  GpcListBased<T> newEmpty() {
    return GpcListBased<T>();
  }

  @override
  int get length => _points.length;

  @override
  T operator [](int index) => _points[index];

  @override
  // ignore: non_constant_identifier_names
  void add_Unsafe(T element) {
    _points.add(element);
  }

  @override
  rollbackAddingLastItem() {
    _points.removeLast();
  }

  @override
  // ignore: non_constant_identifier_names
  void addAllStartingAt_Unsafe(Iterable<T> source, [int skipItems = 0]) {
    _points.addAll(source.skip(skipItems));
  }
}
