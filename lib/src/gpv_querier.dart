/// Base classes for the GPS History functionality

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:typed_data';

import 'base.dart';
import 'base_collections.dart';
import 'utils/time.dart';

/// A view that internally only stores indices in a referenced
/// collections, and queries the collection for the points when required.
class GpvQuerier<T extends GpsPoint> extends GpsPointsView<T> {
  bool? _sortedByTime;

  /// The reference collection of points, which will be used to return the
  /// actual points.
  final GpsPointsCollection<T> _collection;

  /// The indices in the collection, stored for space and time efficiency
  /// as an Int32List.
  ///
  /// 32-bit integers can cover about 65 years of once-per-second position
  /// recordings. That seems more than enough.
  final Int32List _indices;

  GpvQuerier(this._collection, this._indices);

  @override
  GpsPointsView<T> newEmpty({int? capacity}) {
    return GpvQuerier<T>(_collection, Int32List(0));
  }

  @override
  GpsPointsView<T> sublist(int start, [int? end]) {
    return GpvQuerier(_collection, _indices.sublist(start, end));
  }

  @override
  int get length => _indices.length;

  @override
  T operator [](int index) => _collection[_indices[index]];

  @override
  bool get sortedByTime {
    // If cached, return cached value.
    if (_sortedByTime != null) {
      return _sortedByTime!;
    }

    // Not cached -> determine state now. Start out assuming it's sorted,
    // then try to prove that's not the case.
    _sortedByTime = true;

    if (_collection.sortedByTime) {
      // If the wrapped collection is sorted by time, it's enough to check that
      // the indices list is in incremental order.
      for (var i = 1; i < _indices.length; i++) {
        if (_indices[i - 1] >= _indices[i]) {
          _sortedByTime = false;
          break;
        }
      }
    } else {
      // Wrapped collection is not sorted by time, but the indices may have
      // been provided in an order such that the result is sorted.
      for (var itemNr = 1; itemNr < length; itemNr++) {
        if (comparePointTimes(this[itemNr - 1], this[itemNr]) !=
            TimeComparisonResult.before) {
          _sortedByTime = false;
          break;
        }
      }
    }

    return _sortedByTime!;
  }
}
