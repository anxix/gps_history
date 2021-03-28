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

/// Provides access to GPS poins
abstract class GpsPointsProvider<T extends GpsPoint> {
  int get length;
  T operator [](index);
  GpsPointsProvider<T> selectInBoundingBox(
      minLatitude, minLongitude, maxLatitude, maxLongitude);
}


