/* Base classes for the GPS History functionality
 *
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:typed_data';

/// Represents a GPS location (excludes heading and accuracy
/// information that is typically provided by GPS sensors).
class GpsPoint {
  /// The datetime for the point record.
  final DateTime time;

  /// The latitude of the point, in degrees.
  final double latitude;

  /// The longitude of the point, in degrees.
  final double longitude;

  /// The altitude of the point, in meters.
  final double altitude;

  GpsPoint(this.time, this.latitude, this.longitude, this.altitude);
}

/// GPS point with additional information related to the measurement.
/// Some fields may be unavailable, depending on data source.
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
      double altitude,
      this.accuracy,
      this.heading,
      this.speed,
      this.speedAccuracy)
      : super(time, latitude, longitude, altitude);
}

/// Provides read-only access to GPS poins, therefore typically acting as
/// a view onto a read/write collection of GpsPoints.
/// Subclass names may start with "Gpv".
abstract class GpsPointsView<T extends GpsPoint> {
  // List-likes
  int get length;
  forEach(void f(T element));
  T operator [](int index);

  // Other
//  GpsPointsView<T> selectInBoundingBox(double minLatitude, double minLongitude,
//      double maxLatitude, double maxLongitude);
}

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

/// Provides read/write access to GPS points. Because lightweight
/// views may be created on the data in the list, adding is the only
/// modification operation that's allowed, as inserting or removing
/// could lead to invalid views.
/// Subclass names may start with "Gpc".
abstract class GpsPointsCollection<T extends GpsPoint>
    extends GpsPointsView<T> {
  // List-like.
  add(T element);
  addAll(Iterable<T> iterable);
}
