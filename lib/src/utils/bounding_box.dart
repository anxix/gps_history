/// Implement bounding boxes and bounding box checks.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'binary_conversions.dart';
import 'hash.dart';

/// Represents a latitude/longitude aligned bounding box for a query, intended
/// to be subclassed and implemented for geodetic (floating point latitude
/// and longitude with ranges (-90..90) respectively (-180..180)) or flattened
/// in 1E7 representation as used by the efficient GPS point collections.
///
/// Bounding boxes can be created based on doubles (if using coordinates as-is)
/// or on integers (e.g. if using data directly from the efficient collections).
///
/// A bounding box must be defined from the bottomleft point, going to the right
/// and up. Because of the antimeridian at +/- 180 deg longitude, a bounding
/// box that crosses the antimeridian will have its start point with a higher
/// longitude value than its end point.
abstract class LatLongBoundingBox<T extends num> {
  /// The lower latitude boundary of the bounding box.
  final T bottomLatitude;

  /// The left longitude boundary of the bounding box.
  final T leftLongitude;

  /// THe upper latitude boundary of the bounding box.
  final T topLatitude;

  /// The right longitude boundary of the bounding box.
  final T rightLongitude;

  /// Indicates if the bounding box wraps the antimeridian.
  final bool wrapsAntimeridian;

  /// The global minimum latitude boundary, to be set in subclasses based on
  /// coordinate system.
  late T globalMinLatitude;

  /// The global maximum latitude boundary, to be set in subclasses based on
  /// coordinate system.
  late T globalMaxLatitude;

  /// The global minimum longitude boundary, to be set in subclasses based on
  /// coordinate system.
  late T globalMinLongitude;

  /// The global maximum longitude boundary, to be set in subclasses based on
  /// coordinate system.
  late T globalMaxLongitude;

  /// Indicates if the bounding box touches the North pole (singular point).
  late bool touchesNorthPole;

  /// Indicates if the bounding box touches the South pole (singular point).
  late bool touchesSouthPole;

  LatLongBoundingBox(this.bottomLatitude, this.leftLongitude, this.topLatitude,
      this.rightLongitude)
      : wrapsAntimeridian = leftLongitude > rightLongitude {
    // Sanity check on latitude boundaries (equal is allowed, then box is a
    // line, or more accurately an arc).
    if (topLatitude < bottomLatitude) {
      throw RangeError(
          '$runtimeType cannot have maxLatitude ($topLatitude) < minLatitude ($bottomLatitude)');
    }
    // If rightLongitude < leftLongitude, we're dealing with a BB that wraps the
    // antimeridian, so it's a valid configuration.

    // Force subclasses to initialize the global min/max boundaries.
    initGlobalExtents();

    touchesNorthPole = topLatitude == globalMaxLatitude;
    touchesSouthPole = bottomLatitude == globalMinLatitude;
  }

  /// Initializes the global extends fields, to be overridden by child classes.
  initGlobalExtents();

  bool contains(T latitude, T longitude) {
    // Catch the situation where the point is on one of the poles.
    if ((touchesNorthPole && latitude == topLatitude) ||
        (touchesSouthPole && latitude == bottomLatitude)) {
      return true;
    }

    // Not on the poles -> straight bounding box containership test, but taking
    // into account the box may span over the antimeridian.
    return (bottomLatitude <= latitude && latitude <= topLatitude) &&
        (wrapsAntimeridian
            ? (leftLongitude <= longitude || longitude <= rightLongitude)
            : (leftLongitude <= longitude && longitude <= rightLongitude));
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return other is LatLongBoundingBox &&
        other.bottomLatitude == bottomLatitude &&
        other.leftLongitude == leftLongitude &&
        other.topLatitude == topLatitude &&
        other.rightLongitude == rightLongitude;
  }

  @override
  int get hashCode {
    return hash4(bottomLatitude, leftLongitude, topLatitude, rightLongitude);
  }
}

/// A bounding box implementation for the geodetic coordinate system.
class GeodeticLatLongBoundingBox extends LatLongBoundingBox<double> {
  GeodeticLatLongBoundingBox(super.bottomLatitude, super.leftLongitude,
      super.topLatitude, super.rightLongitude);

  @override
  initGlobalExtents() {
    globalMinLatitude = -90.0;
    globalMaxLatitude = 90.0;
    globalMinLongitude = -180.0;
    globalMaxLongitude = 180.0;
  }
}

/// A bounding box implementation for the flattened coordinate system as used
/// by the efficient GPS point collections.
class FlatLatLongBoundingBox extends LatLongBoundingBox<int> {
  FlatLatLongBoundingBox(super.bottomLatitude, super.leftLongitude,
      super.topLatitude, super.rightLongitude);

  @override
  initGlobalExtents() {
    globalMinLatitude = Conversions.latitudeToUint32(-90.0);
    globalMaxLatitude = Conversions.latitudeToUint32(90.0);
    globalMinLongitude = Conversions.longitudeToUint32(-180.0);
    globalMaxLongitude = Conversions.longitudeToUint32(180.0);
  }
}
