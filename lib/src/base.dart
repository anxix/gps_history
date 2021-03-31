/// Base classes for the GPS History functionality

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:collection';

import 'package:gps_history/src/hash.dart';

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

  /// The altitude of the point, in meters.
  final double altitude;

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
      double altitude,
      this.accuracy,
      this.heading,
      this.speed,
      this.speedAccuracy)
      : super(time, latitude, longitude, altitude);

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
}

/// Iterator support for GPS points views.
///
/// The iterator allows [GpsPointsView] and children to easily implement
/// an Iterable interface.
class GpsPointsViewIterator<T extends GpsPoint> extends Iterator<T> {
  int _index = -1;
  final GpsPointsView<T> _source;

  GpsPointsViewIterator(this._source);

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

/// Read-only view on the GPS points stored in a [GpsPointsCollection].
///
/// Provides read-only access to GPS poins, therefore typically acting as
/// a view onto a read/write collection of GpsPoints.
/// Subclass names may start with "Gpv".
abstract class GpsPointsView<T extends GpsPoint> with IterableMixin<T> {
  // List-likes
  @override
  Iterator<T> get iterator => GpsPointsViewIterator<T>(this);

  T operator [](int index);

  // Other
//  GpsPointsView<T> selectInBoundingBox(double minLatitude, double minLongitude,
//      double maxLatitude, double maxLongitude);
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
  // List-like wriet operations.
  void add(T element);
  void addAll(Iterable<T> iterable);
}
