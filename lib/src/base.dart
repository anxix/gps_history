/// Base classes for the GPS History functionality

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'hash.dart';
import 'utils/distance.dart';
import 'utils/time.dart';

/// [Exception] class that can act as ancestor for exceptions raised by
class GpsHistoryException implements Exception {
  final String? message;

  GpsHistoryException([this.message]);

  @override
  String toString() {
    final extraText = (message != null) ? ': $message' : '';
    return '${runtimeType.toString()}$extraText';
  }
}

/// Compares the time values of [itemA] and [itemB] and returns the result.
///
/// Implemented to handle correct comparisons for types that have just one
/// time field ([GpsPoint], [GpsMeasurement]) and types that have a secondary
/// time field as well ([GpsStay]).
TimeComparisonResult comparePointTimes(GpsPoint itemA, GpsPoint itemB) {
  // Comparing GpsStay to non-stay items requires special care, because a stay
  // may overlap a GpsPoint, but the GpsPoint doesn't know about overlapping.
  if (itemA is GpsStay) {
    final startA = itemA.time.secondsSinceEpoch;
    final endA = itemA.endTime.secondsSinceEpoch;
    final startB = itemB.time.secondsSinceEpoch;
    final endB = (itemB is GpsStay)
        ? itemB.endTime.secondsSinceEpoch
        : itemB.time.secondsSinceEpoch; // non-stay same as zero length stay
    return compareTimeSpans(
        startA: startA, endA: endA, startB: startB, endB: endB);
  } else if (itemB is GpsStay) {
    // Put itemB in the lead of the comparison and simply invert the result.
    return opposite(comparePointTimes(itemB, itemA));
  }

  // Non-GpsStay items can be compared simply.
  return compareTime(itemA.time, itemB.time);
}

/// Calculates the distance between [pointA] and [pointB], optionally using
/// a specific calculation [mode] to balance speed and accuracy.
double distance(GpsPoint pointA, GpsPoint pointB,
    [DistanceCalcMode mode = DistanceCalcMode.auto]) {
  return distanceCoords(pointA.latitude, pointA.longitude, pointB.latitude,
      pointB.longitude, mode);
}

/// Represents the most basic GPS location.
///
/// This excludes heading and accuracy information that is typically provided
/// by GPS sensors).
class GpsPoint {
  /// The time for the point record, measured in seconds since the epoch
  /// (1/1/1970 UTC).
  final GpsTime time;

  /// The latitude of the point, in degrees.
  final double latitude;

  /// The longitude of the point, in degrees.
  final double longitude;

  /// The altitude of the point, in meters (is not present for some data
  /// sources).
  final double? altitude;

  /// A point with all fields set to null if possible, or to zero otherwise.
  static final zeroOrNulls =
      GpsPoint(time: GpsTime(0), latitude: 0, longitude: 0);

  /// A point with all fields set to zero.
  static final allZero =
      GpsPoint(time: GpsTime(0), latitude: 0, longitude: 0, altitude: 0);

  /// Constant constructor, as modifying points while they're part of a
  /// collection could have bad effects in that collection's meta flags, like
  /// sorted state.
  const GpsPoint({
    required this.time,
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  /// Create a copy of the point with optionally one or more of its fields set
  /// to new values.
  GpsPoint copyWith({
    GpsTime? time,
    double? latitude,
    double? longitude,
    double? altitude,
  }) {
    return GpsPoint(
      time: time ?? this.time,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
    );
  }

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

  @override
  String toString() =>
      't: $time\tlat:\t$latitude\tlong: $longitude\talt: $altitude';
}

/// Exception class for invalid values.
class GpsInvalidValue extends GpsHistoryException {
  GpsInvalidValue([message]) : super(message);
}

/// GPS point representing a stay in that location for some amount of time.
///
/// Some fields may be unavailable (null), depending on data source. The
/// inherited [time] indicates the start of the stay.
class GpsStay extends GpsPoint {
  /// The accuracy of the measurement.
  final double? accuracy;

  /// Internal representation of [endTime]. Will be kept to null
  /// when it's a zero-length stay ([time] == [endTime]).
  final GpsTime? _endTime;

  /// A stay with all fields set to null if possible, or to zero otherwise.
  static final zeroOrNulls = GpsStay.fromPoint(GpsPoint.zeroOrNulls);

  /// A stay with all fields set to zero.
  static final allZero = GpsStay.fromPoint(GpsPoint.allZero,
      accuracy: 0,
      // endTime must be null even though we're zeroing out, because it simply
      // means it's equal to (start)time.
      endTime: null);

  /// Converts a specified [endTime] to its required internal representation
  /// if it's valid, throws [GpsInvalidValue] if not.
  ///
  /// The internal representation is:
  /// - null: if [endTime] == [startTime] (where [startTime] will be the [time]
  ///         field of [GpsStay])
  /// - endTime: if [endTime] > [startTime]
  ///
  /// An exception is thrown if [endTime] < [startTime] as it would render any
  /// containers unable to process a negative time duration.
  static GpsTime? _endTimeToInternal(GpsTime? endTime, GpsTime startTime) {
    if (endTime == null) {
      return null;
    } else if (endTime.isBefore(startTime)) {
      throw GpsInvalidValue('endTime $endTime is before startTime $startTime');
    } else {
      return endTime;
    }
  }

  /// Constructor.
  GpsStay(
      {required GpsTime time,
      required double latitude,
      required double longitude,
      double? altitude,
      this.accuracy,
      GpsTime? endTime})
      : _endTime = _endTimeToInternal(endTime, time),
        super(
          time: time,
          latitude: latitude,
          longitude: longitude,
          altitude: altitude,
        );

  /// Constructs a [GpsStay] from the data in [point], with optionally the
  /// additional information in [accuracy] and [endTime].
  GpsStay.fromPoint(GpsPoint point, {this.accuracy, GpsTime? endTime})
      : _endTime = _endTimeToInternal(endTime, point.time),
        super(
          time: point.time,
          latitude: point.latitude,
          longitude: point.longitude,
          altitude: point.altitude,
        );

  /// Create a copy of the point with optionally one or more of its fields set
  /// to new values.
  ///
  /// It's a bit debatable what should happen with the [endTime] when copying
  /// from an original where [_endTime] == nul and modifying [time] for the
  /// copy without also modifying [endTime] for the copy.
  ///
  /// Options for handling this situation would be:
  /// - Copy implicitly modifies [endTime] to maintain the duration of the
  ///   original:
  ///   ```copy.endTime - copy.time == original.endTime - original.time```
  /// - Copy keeps [endTime] identical to the original, but shifts it to
  ///   copy.time if copy would become invalid:
  ///   ```copy.endTime == max(copy.time, original.endTime)```
  /// - Maintain ```copy.endTime == original.endTime```, and throw an exception
  ///   if ```copy.time > original.endTime```.
  ///
  /// Additionally there's no way to reset [endTime] to null during the copy
  /// operation, except by calling the [copyWith] with an explicit [endTime]
  /// equal to [time]:
  /// ```c = s.copyWith(time: t, endTime: t);```
  ///
  /// There's no obviously superior choice, so the implementation chooses the
  /// strictest possible mode: leave [endTime] identical to the souce and throw
  /// an exception if that renders the copy invalid.
  @override
  GpsStay copyWith(
      {GpsTime? time,
      double? latitude,
      double? longitude,
      double? altitude,
      double? accuracy,
      GpsTime? endTime}) {
    // Catch the issue explained in the documentation and throw an exception
    // here. This way the feedback will be more explicit if it happens at
    // runtime.
    final newTime = time ?? this.time;
    final newEndTime = endTime ?? _endTime;

    // Only perform the check if the caller is trying to modify times (saves
    // on relatively expensive time comparison).
    if (time != null || endTime != null) {
      // Caller is trying to modify times -> catch invalid configuration.
      if (newEndTime != null && newEndTime.isBefore(newTime)) {
        throw GpsInvalidValue(
            'Called $runtimeType.copyWith in a way that generates an invalid situation where endTime < time. Consider specifying the endPoint argument as well in the call.');
      }
    }

    return GpsStay(
      time: newTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      endTime: newEndTime,
    );
  }

  /// Alias [time] to [startTime] because it's easier to think of it as the
  /// start time of the stay in the specified location.
  get startTime => time;

  /// End time of the stay in the specified location (must be >= [time]).
  ///
  /// The stay duration is to be regarded as *exclusive* of [endTime].
  /// This means that if in a list we have two consecutive [GpsStay] items
  /// defined (with position being the latitude/longitude components) as:
  /// ```
  /// 0: time=1, position=A, endTime=2
  /// 1: time=2, position=B, endTime=3
  /// ```
  /// for time=2 the correct position is B, not A.
  get endTime => _endTime ?? time;

  @override
  bool operator ==(other) {
    if (!(super == (other))) {
      return false;
    }
    return other is GpsStay &&
        other.accuracy == accuracy &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    return hash3(super.hashCode, accuracy, endTime);
  }

  @override
  String toString() => '${super.toString()}\tacc: $accuracy\tend: $endTime';
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

  /// A measurement with all fields set to null if possible, or to zero otherwise.
  static final zeroOrNulls = GpsMeasurement.fromPoint(GpsPoint.zeroOrNulls);

  /// A measurement with all fields set to zero.
  static final allZero = GpsMeasurement.fromPoint(GpsPoint.allZero,
      accuracy: 0, heading: 0, speed: 0, speedAccuracy: 0);

  /// Constant constructor, as modifying points while they're part of a
  /// collection could have bad effects in that collection's meta flags, like
  /// sorted state.
  const GpsMeasurement({
    required GpsTime time,
    required double latitude,
    required double longitude,
    double? altitude,
    this.accuracy,
    this.heading,
    this.speed,
    this.speedAccuracy,
  }) : super(
          time: time,
          latitude: latitude,
          longitude: longitude,
          altitude: altitude,
        );

  GpsMeasurement.fromPoint(
    GpsPoint point, {
    this.accuracy,
    this.heading,
    this.speed,
    this.speedAccuracy,
  }) : super(
            time: point.time,
            latitude: point.latitude,
            longitude: point.longitude,
            altitude: point.altitude);

  @override
  GpsMeasurement copyWith(
      {GpsTime? time,
      double? latitude,
      double? longitude,
      double? altitude,
      double? accuracy,
      double? heading,
      double? speed,
      double? speedAccuracy}) {
    return GpsMeasurement(
      time: time ?? this.time,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      speedAccuracy: speedAccuracy ?? this.speedAccuracy,
    );
  }

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

  @override
  String toString() =>
      '${super.toString()}\tacc: $accuracy\thdng: $heading\tspd: $speed\tspdacc: $speedAccuracy';
}
