/* Base classes for the GPS History functionality
 *
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:typed_data';
import 'package:gps_history/src/base.dart';

/// Implements a view that internally only stores indices in a referenced
/// collections, and queries the collection for the points when required.
class GpvQuerier<T extends GpsPoint> extends GpsPointsView<T> {
  /// The reference collection of points, which will be used to return the
  /// actual points.
  final GpsPointsCollection<T> _collection;

  /// The indices in the collection, stored for space and time efficiency
  /// as an Int32List. 32-bit integers can cover about 65 years of
  /// once-per-second position recordings. That seems more than enough.
  final Int32List _indices;

  GpvQuerier(this._collection, this._indices);

  @override
  int get length => _indices.length;

  @override
  forEach(void f(T element)) => _indices.forEach((index) {
        f(this[index]);
      });

  @override
  T operator [](int index) => _collection[_indices[index]];
}
