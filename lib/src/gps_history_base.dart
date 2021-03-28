/*
 * Copyright (c) 
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

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
abstract class GpsPointsView<T extends GpsPoint> {
  // List-likes
  int get length;
  forEach(void f(T element));
  T operator [](int index);

  // Other
  GpsPointsView<T> selectInBoundingBox(double minLatitude, double minLongitude,
      double maxLatitude, double maxLongitude);
}

/// Provides read/write access to GPS points. Because lightweight
/// views may be created on the data in the list, adding is the only
/// modification operation that's allowed, as inserting or removing
/// could lead to invalid views.
abstract class GpsPointsCollection<T extends GpsPoint>
    extends GpsPointsView<T> {
  // List-like.
  add(T element);
  addAll(Iterable<T> iterable);
}
