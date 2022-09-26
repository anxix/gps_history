/// Utilities for dealing with time related tasks.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';

import 'base.dart';

const earthRadiusMeters = 6371E3; // https://en.wikipedia.org/wiki/Earth_radius
const metersPerDegreeLongitude = earthRadiusMeters * 2 * pi / 360;

enum DistanceCalcMode {
  superfast, // rough approximation with only add/subtract/multiply operations
  approximate, // equirectangular approximation
  sphericalLawCosines, // spherical law of cosines
  haversine, // most accurate
}

/// Converts a value [deg] specified in degrees to radians.
double degToRad(double deg) {
  return pi * deg / 180;
}

/// On-demand filling list that indicates at a given index representing the
/// longitude (in degrees, rounded down towards zero), how many meters are in
/// one degree of latitude.
final _metersPerLatitudeDegreeAtLongitude = List<double?>.filled(90, null);

double getMetersPerLatitudeDegAtLongitudeDeg(longitudeDeg) {
  // Slice the earth in cylinders of 1 degree longitude, where the radius of
  // each cylinder is taken equal to the radius at the bottom of the cylinder
  // (assuming the Northern hemisphere).
  // This will overestimate the radius at the top of the cylinder.

  // Symmetry in the equator -> only deal with positive angles.
  var i = longitudeDeg.truncate().abs();

  // Prevent index out of bounds for the case of abs(latitude)==90 deg.
  i = i < 90 ? i : 89;

  // We may have a memoized value.
  var res = _metersPerLatitudeDegreeAtLongitude[i];

  if (res == null) {
    // No memoized value -> calculate and memoize.

    // With the earth being symmetric at the equator, only work in the
    // positive angles domain.
    final longitudeRad = degToRad(longitudeDeg.abs());

    // Radius of the circle of latitude at the specified longitude.
    final radiusOfParallel = earthRadiusMeters * cos(longitudeRad);

    // Calculate how many meters is one degree of latitude.
    final circumferenceOfParallel = radiusOfParallel * 2 * pi;
    res = circumferenceOfParallel / 360;

    // Memoize.
    _metersPerLatitudeDegreeAtLongitude[i] = res;
  }
  return res;
}

/// Returns the shortest latitude angle distance (in degrees) between two points
/// A and B with latitudes given by [latADeg] respectively [latBDeg], both in
/// degrees.
///
/// The result is always positive, in the range of 0..180 (both inclusive).
double deltaLatitudeAbs(double latADeg, double latBDeg) {
  // Latitude calculations require a bit of care as it's expressed in the
  // range -180..180, so LatA=-179 and LatB=179 is just 2 degrees difference,
  // not 358 degrees.
  var diffLatDeg = (latADeg - latBDeg).abs();
  return diffLatDeg <= 180 ? diffLatDeg : 360 - diffLatDeg;
}

/// Returns the shortest longitude angle distance (in degrees) between two
/// points A and B with latitudes given by [latADeg] respectively [latBDeg],
/// both in degrees.
///
/// The result is always positive, in the range of 0..180 (both inclusive).
double deltaLongitudeAbs(double longADeg, double longBDeg) {
  return (longADeg - longBDeg).abs();
}

/// Calculates an approximation of the distance in meters between point A
/// at polar (latitude, longitude) coordinates ([latADeg], [longADeg]) and B at
/// ([latBDeg], [longBDeg]) - all in degrees.
///
/// The result is an upper bound and is within a factor of about sqrt(2)
/// accuracy if the two points are "sufficiently" close together.
double distanceCoordsSuperFast(
    double latADeg, double longADeg, double latBDeg, double longBDeg) {
  final meterPerDegLatA = getMetersPerLatitudeDegAtLongitudeDeg(longADeg);
  final meterPerLatB = getMetersPerLatitudeDegAtLongitudeDeg(longBDeg);
  final averageMeterPerLatDeg = (meterPerDegLatA + meterPerLatB) / 2;
  final distLatMeter =
      averageMeterPerLatDeg * deltaLatitudeAbs(latADeg, latBDeg);

  var diffLongDeg = deltaLongitudeAbs(longADeg, longBDeg);
  final distLongMeter = metersPerDegreeLongitude * diffLongDeg;

  // Rough approximation, don't even do Pythagoras, so it's an upper bound.
  return distLongMeter + distLatMeter;
}

/// Calculates the distance in meters between point A at polar
/// (latitude, longitude) coordinates ([latADeg], [longADeg]) and B at
/// ([latBDeg], [longBDeg]) - all in degrees, using the haversine formula.
///
/// The result is very accurate for a perfectly spherical earth and has up to
/// about 0.3% error compared to the ellipsoidal shape of the earth.
/// Based on https://www.movable-type.co.uk/scripts/latlong.html.
double distanceCoordsHaversine(
    double latADeg, double longADeg, double latBDeg, double longBDeg) {
  final latARad = degToRad(latADeg);
  final latBRad = degToRad(latBDeg);
  final deltaLatRad = degToRad(latADeg - latBDeg);
  final deltaLongRad = degToRad(longBDeg - longADeg);

  final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
      cos(latARad) *
          cos(latBRad) *
          sin(deltaLongRad / 2) *
          sin(deltaLongRad / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusMeters * c;
}

double distanceCoords(double latADeg, double longADeg, double latBDeg,
    double longBDeg, DistanceCalcMode mode) {
  // TODO: implement
  return 0.0;
}

double distance(GpsPoint pointA, GpsPoint pointB, DistanceCalcMode mode) {
  return distanceCoords(pointA.latitude, pointA.longitude, pointB.latitude,
      pointB.longitude, mode);
}
