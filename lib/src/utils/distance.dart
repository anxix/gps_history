/// Utilities for dealing with time related tasks.
///
/// This module implements several algorithms for calculating distances between
/// points on Earth. Benchmarking on Linux running on an Intel Core i7-8565U
/// (plugged in) shows roughly the following runtime relationships:
/// - SuperFast: 1x (reference speed, fastest, 10M calcs in 0.2s)
/// - Equirectangular: 1.25x
/// - Haversine: 3x
/// - Lambert: 6x (slowest)
///
/// The accuracy on the other hand, with Lambert being the most accurate and
/// hence taken as benchmark, depends on the location and the distance between
/// points. Typically, for small distances of <= 1 degree (roughly 100-150km),
/// all methods are within 0.5% of Lambert. At large distances, such as 60 deg,
/// Haversine stays wihin 0.5% of Lambert, but the other two can show deviations
/// of e.g. 12% (SuperFast tends to be similar or better than Equirectangular).
///
/// This leads to the following recommendations:
/// - Use Lambert only if the best possible accuracy is required, as it's
///   2x slower than Haversine and only gives max ~0.5% extra accuracy.
///   Distances in reality are probably to come out differently anyway due to
///   local relief, which Lambert also doesn't know about.
/// - Use SuperFast for the best speed and decent accuracy as long as the points
///   are reasonably close together.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';

typedef DistanceCalculateFunc = double Function(
    double latADeg, double longADeg, double latBDeg, double longBDeg);

/// Class that operates as just a container for different types of Earth radii,
/// expressed in meters.
abstract class EarthRadiusMeters {
  // Values based on https://en.wikipedia.org/wiki/Earth_radius and
  // https://en.wikipedia.org/wiki/World_Geodetic_System#1984_version.
  static const mean = 6371E3;
  static const equatorial = 6378.1370E3;
  static const polar = 6356.752314245E3;
}

const metersPerDegreeLatitude = EarthRadiusMeters.mean * 2 * pi / 360;

enum DistanceCalcMode {
  auto, // autoselects a method based on input values
  superFast, // approximation with minimum operations
  equirectangular, // equirectangular approximation
  haversine, // very accurate
  lambert, // most accurate
}

/// Converts a value [deg] specified in degrees to radians.
double degToRad(double deg) {
  return pi * deg / 180;
}

/// Converts a value [rad] specified in radians to degrees.
double radToDeg(double rad) {
  return rad / pi * 180;
}

/// On-demand filling list that indicates at a given index representing the
/// latitude (in degrees, rounded down towards zero), how many meters are in
/// one degree of longitude.
final _metersPerLongitudeDegreeAtLatitude = List<double?>.filled(90, null);

double getMetersPerLongitudeDegAtLatitudeDeg(latitudeDeg) {
  // Slice the earth in cylinders of 1 degree latitude, where the radius of
  // each cylinder is taken equal to the radius at the bottom of the cylinder
  // (assuming the Northern hemisphere).
  // This will overestimate the radius at the top of the cylinder.

  // Symmetry in the equator -> only deal with positive angles.
  var i = latitudeDeg.truncate().abs();

  // Prevent index out of bounds for the case of abs(latitude)==90 deg.
  i = i < 90 ? i : 89;

  // We may have a memoized value.
  var res = _metersPerLongitudeDegreeAtLatitude[i];

  if (res == null) {
    // No memoized value -> calculate and memoize.

    // With the earth being symmetric at the equator, only work in the
    // positive angles domain.
    final latitudeRad = degToRad(latitudeDeg.abs());

    // Radius of the parallel at the specified latitude.
    final radiusOfParallel = EarthRadiusMeters.mean * cos(latitudeRad);

    // Calculate how many meters is one degree of latitude.
    final circumferenceOfParallel = radiusOfParallel * 2 * pi;
    res = circumferenceOfParallel / 360;

    // Memoize.
    _metersPerLongitudeDegreeAtLatitude[i] = res;
  }
  return res;
}

/// Returns the shortest longitude angle distance (in degrees) between two
/// points A and B with longitudes given by [longADeg] respectively [longBDeg],
/// both in degrees.
///
/// The result is always positive, in the range of 0..180 (both inclusive).
double deltaLongitudeAbs(double longADeg, double longBDeg) {
  // Longitude calculations require a bit of care as it's expressed in the
  // range -180..180, so LongA=-179 and LongB=179 is just 2 degrees difference,
  // not 358 degrees.
  var diffLongDeg = (longADeg - longBDeg).abs();
  return diffLongDeg <= 180 ? diffLongDeg : 360 - diffLongDeg;
}

/// Returns the shortest latitude angle distance (in degrees) between two
/// points A and B with latitudes given by [latADeg] respectively [latBDeg],
/// both in degrees.
///
/// The result is always positive, in the range of 0..180 (both inclusive).
double deltaLatitudeAbs(double latADeg, double latBDeg) {
  return (latADeg - latBDeg).abs();
}

/// Calculates an approximation of the distance in meters between point A
/// at spherical (latitude, longitude) coordinates ([latADeg], [longADeg]) and
/// B at ([latBDeg], [longBDeg]) - all in degrees.
double distanceCoordsSuperFast(
    double latADeg, double longADeg, double latBDeg, double longBDeg) {
  final meterPerDegLongA = getMetersPerLongitudeDegAtLatitudeDeg(latADeg);
  final meterPerDegLongB = getMetersPerLongitudeDegAtLatitudeDeg(latBDeg);
  final averageMeterPerLongDeg = (meterPerDegLongA + meterPerDegLongB) / 2;
  final distLongMeter =
      averageMeterPerLongDeg * deltaLongitudeAbs(longADeg, longBDeg);

  var diffLatDeg = deltaLatitudeAbs(latADeg, latBDeg);
  final distLatMeter = metersPerDegreeLatitude * diffLatDeg;

  return sqrt(distLongMeter * distLongMeter + distLatMeter * distLatMeter);
}

/// Calculates an approximation of the distance in meters between point A
/// at spherical (latitude, longitude) coordinates ([latADeg], [longADeg]) and
/// B at ([latBDeg], [longBDeg]) - all in degrees, using the equirectangular
/// approximation.
///
/// The accuracy depends on the distance between the points and the latitude.
double distanceCoordsEquirectangular(
    double latADeg, double longADeg, double latBDeg, double longBDeg) {
  final latARad = degToRad(latADeg);
  final latBRad = degToRad(latBDeg);
  final deltaLongRad = degToRad(deltaLongitudeAbs(longADeg, longBDeg));
  final x = deltaLongRad * cos((latARad + latBRad) / 2);
  final y =
      degToRad(deltaLatitudeAbs(latADeg, latBDeg)); // (latBRad - latARad);
  return sqrt(x * x + y * y) * EarthRadiusMeters.mean;
}

/// Calculates the distance in meters between point A at spherical
/// (latitude, longitude) coordinates ([latADeg], [longADeg]) and B at
/// ([latBDeg], [longBDeg]) - all in degrees, using the haversine formula.
///
/// [earthRadiusMeters] can be used to specify a radius to be used other than
/// the mean earth radius.
///
/// The result is very accurate for a perfectly spherical earth and has up to
/// about 0.3% error compared to the ellipsoidal shape of the earth.
/// Based on https://www.movable-type.co.uk/scripts/latlong.html.
double distanceCoordsHaversine(
    double latADeg, double longADeg, double latBDeg, double longBDeg,
    {earthRadiusMeters = EarthRadiusMeters.mean}) {
  final latARad = degToRad(latADeg);
  final latBRad = degToRad(latBDeg);
  final deltaLatRad =
      degToRad(deltaLatitudeAbs(latADeg, latBDeg)); // latBRad - latARad;
  final deltaLongRad =
      degToRad(deltaLongitudeAbs(longADeg, longBDeg)); //longBDeg - longADeg);

  final sinHalfDeltaLatRad = sin(deltaLatRad / 2);
  final sinHalfDeltaLongRad = sin(deltaLongRad / 2);
  final a = sinHalfDeltaLatRad * sinHalfDeltaLatRad +
      cos(latARad) * cos(latBRad) * sinHalfDeltaLongRad * sinHalfDeltaLongRad;
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusMeters * c;
}

// Calculate the flattening, being (1 - polarRadius/equatorRadius),
const earthFlattening =
    1 - EarthRadiusMeters.polar / EarthRadiusMeters.equatorial;

/// Calculates the distance in meters between point A at spherical
/// (latitude, longitude) coordinates ([latADeg], [longADeg]) and B at
/// ([latBDeg], [longBDeg]) - all in degrees, using Lambert's formula for
/// maximum accuracy, taking into account the earth's ellipsoid shape.
///
/// The result is very accurate, tens of meters over thousands of kilometers.
/// Based on https://www.calculator.net/distance-calculator.html,
/// https://en.wikipedia.org/wiki/Geographical_distance#Lambert's_formula_for_long_lines
/// and https://python.algorithms-library.com/geodesy/lamberts_ellipsoidal_distance.
double distanceCoordsLambert(
    double latADeg, double longADeg, double latBDeg, double longBDeg) {
  // Calculate the reduced latitudes.
  final latARad = degToRad(latADeg);
  final beta1 = atan((1 - earthFlattening) * tan(latARad));
  final latBRad = degToRad(latBDeg);
  final beta2 = atan((1 - earthFlattening) * tan(latBRad));

  // The correct value for the radius to use in the haversine calculation is
  // not clear, but the implementations at
  // https://www.calculator.net/distance-calculator.html and
  // https://python.algorithms-library.com/geodesy/lamberts_ellipsoidal_distance
  // use the radius at the equator rather than the mean radius.
  const haversineEarthRadius = EarthRadiusMeters.equatorial;

  // Calculate the haversine distance and with that the central angle sigma.
  final sigma = distanceCoordsHaversine(
          radToDeg(beta1), longADeg, radToDeg(beta2), longBDeg,
          earthRadiusMeters: haversineEarthRadius) /
      haversineEarthRadius;
  final sinSigma = sin(sigma);
  final sinHalfSigma = sin(sigma / 2);
  final cosHalfSigma = cos(sigma / 2);

  // Prevent division by zero further down.
  if (sinHalfSigma == 0 || cosHalfSigma == 0) {
    return 0;
  }

  // Calculate various components of the final formula.
  final p = (beta1 + beta2) / 2;
  final q = (beta2 - beta1) / 2;
  final sinP = sin(p);
  final cosP = cos(p);
  final sinQ = sin(q);
  final cosQ = cos(q);
  final x = (sigma - sinSigma) *
      (sinP * sinP * cosQ * cosQ / (cosHalfSigma * cosHalfSigma));
  final y = (sigma + sinSigma) *
      (cosP * cosP * sinQ * sinQ / (sinHalfSigma * sinHalfSigma));

  // Calculate and return the distance.
  final distance =
      EarthRadiusMeters.equatorial * (sigma - (earthFlattening / 2) * (x + y));
  return distance;
}

/// Up to what angle (roughly) is the fast method regarded as reliable (see
/// documentation of this module for the considerations).
const maxAngleForSuperFastDeg = 5;
double distanceCoords(double latADeg, double longADeg, double latBDeg,
    double longBDeg, DistanceCalcMode mode) {
  switch (mode) {
    case DistanceCalcMode.superFast:
      return distanceCoordsSuperFast(latADeg, longADeg, latBDeg, longBDeg);
    case DistanceCalcMode.equirectangular:
      return distanceCoordsEquirectangular(
          latADeg, longADeg, latBDeg, longBDeg);
    case DistanceCalcMode.haversine:
      return distanceCoordsHaversine(latADeg, longADeg, latBDeg, longBDeg);
    case DistanceCalcMode.lambert:
      return distanceCoordsLambert(latADeg, longADeg, latBDeg, longBDeg);
    case DistanceCalcMode.auto:
      {
        // For points that are relatively close together, choose super fast as
        // it's sufficiently accurate (< 0.5%).
        if (deltaLatitudeAbs(latADeg, latBDeg) <= maxAngleForSuperFastDeg &&
            deltaLongitudeAbs(longADeg, longBDeg) <= maxAngleForSuperFastDeg) {
          return distanceCoords(
              latADeg, longADeg, latBDeg, longBDeg, DistanceCalcMode.superFast);
        } else {
          // For points that are less close together, the chances increase that
          // the much slower haversine does give better accuracy.
          return distanceCoords(
              latADeg, longADeg, latBDeg, longBDeg, DistanceCalcMode.haversine);
        }
      }
  }
}
