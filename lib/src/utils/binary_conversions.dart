/// Facilitates conversion of the various fields of the point classes to
/// binary representations that can be used in for example the efficient storage
/// system.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';

import 'time.dart';

/// Implements common conversions needed for storing GPS values in byte arrays.
///
/// Ranges of data will be ensured only at writing time. This because the data
/// is written only once, but potentially read many times.
class Conversions {
  static final _zeroDateTimeUtc = 0;

  // Null datetime encoded as max Uint32.
  static final _nullDateTimeUtc = _zeroDateTimeUtc + 0xffffffff.toUnsigned(32);

  // Max datetime is then one below the null datetime.
  static final _maxDatetimeUtc = GpsTime.maxSecondsSinceEpoch;

  static final int _extremeAltitude = 32767 ~/ 2; //int16 is -32768..32767
  static final int _maxSmallDouble = 0xffff.toUnsigned(16);

  /// Convert a latitude in degrees to PosE7-spec, i.e.
  /// round((90 + degrees) * 1E7), meaning that the South Pole is stored as 0
  /// and the North Pole as 180.
  ///
  /// The minimum distance that can be represented by this accuracy is
  /// 1E-7 degrees, which at the equator represents about 1 cm. Valid range
  /// of latitude values is -90 <= value <= 90.
  /// If values outside the supported range are provided, they will be capped
  /// at the appropriate boundary (no exception will be raised).
  static int latitudeToUint32(double value) {
    // Make sure the value is in the valid range of -90..90. This prevents
    // overloading of the valid integer range.
    final cappedValue = value.abs() <= 90.0 ? value : value.sign * 90.0;
    return ((90 + cappedValue) * 1E7).round();
  }

  /// The opposite of [latitudeToUint32].
  static double uint32ToLatitude(int value) => (value / 1E7) - 90.0;

  /// Convert a longitude in degrees to PosE7-spec, i.e.
  /// round((180 + degrees) * 1E7).
  ///
  /// The minimum distance that can be represented by this accuracy is
  /// 1E-7 degrees, which at the equator represents about 1 cm. Valid range
  /// of longitude values is -180 <= value <= 180.
  /// If values outside the supported range are provided, they will be capped
  /// at the appropriate boundary (no exception will be raised).
  static int longitudeToUint32(double value) {
    // Make sure the value is in the valid range of -180..180. This prevents
    // overloading of the valid integer range.
    final cappedValue = value.abs() <= 180.0 ? value : value.sign * 180.0;
    return ((cappedValue + 180) * 1E7).round();
  }

  /// The opposite of [longitudeToUint32].
  static double uint32ToLongitude(int value) => (value / 1E7) - 180.0;

  /// Convert regular DateTime object to a [Uint32] value.
  ///
  /// The result will be seconds since 1/1/1970, in UTC. This amount is enough
  /// to cover over 135 years. Any fictitious GPS records before 1970 are
  /// thereby not supported, and neither are years beyond about 2105.
  /// If values outside the supported range are provided, they will be capped
  /// at the appropriate boundary (no exception will be raised).
  /// Null values are converted to the maximum possible [Uint32] value.
  static int gpsTimeToUint32(GpsTime? value) {
    late int cappedValue;
    if (value != null) {
      final valueUtc = value.secondsSinceEpoch;
      // Cap the value between zero and the max allowed
      cappedValue = valueUtc < _zeroDateTimeUtc
          ? _zeroDateTimeUtc
          : valueUtc > _maxDatetimeUtc
              ? _maxDatetimeUtc
              : valueUtc;
    } else {
      cappedValue = _nullDateTimeUtc;
    }
    return cappedValue - _zeroDateTimeUtc;
  }

  /// The opposite of [gpsTimeToUint32]
  static GpsTime? uint32ToGpsTime(int value) {
    final result = _zeroDateTimeUtc + value;
    return result == _nullDateTimeUtc ? null : GpsTime(result);
  }

  /// Convert altitude in meters to an [Int16] value.
  ///
  /// This is done by counting half-meters below/above zero, i.e.
  /// round(2 * altitude). That's enough to cover about 16km above/below zero
  /// level, a range outside which not many people venture. The altitude
  /// measurement accuracy of GPS devices also tends to be way more than
  /// 1 meter, so storing at half-meter accuracy doesn't lose us much.
  /// Null values are stored as the maximum positive [Int16].
  /// If values outside the supported range are provided, they will be capped
  /// at the appropriate boundary (no exception will be raised).
  static int altitudeToInt16(double? value) {
    if (value != null) {
      // The code below saves about 10% on a benchmark compared to a
      // more legible implementation using .sign(), .abs() and min().
      if (value > _extremeAltitude) {
        value = _extremeAltitude.toDouble();
      } else if (value < -_extremeAltitude) {
        value = -_extremeAltitude.toDouble();
      }

      return (2 * value).round();
    } else {
      // Encode null as the maximum allowed positive Int16.
      return 2 * _extremeAltitude + 1;
    }
  }

  /// The opposite of [altitudeToInt16].
  static double? int16ToAltitude(int value) =>
      value != 2 * _extremeAltitude + 1 ? value / 2.0 : null;

  /// Convert small double values (range about 0..6.5k) to [Uint16], maintaining
  /// one decimal of accuracy. Null values are supported and encoded as well.
  ///
  /// This is done by storing round(10 * value). Null values are stored as the
  /// maximum [Uint16]. Such values are useful for representing things like
  /// heading, speed, etc. all of which are positive and have relatively small
  /// values in human context.
  /// If values outside the supported range are provided, they will be capped
  /// at the appropriate boundary (no exception will be raised).
  static int smallDoubleToUint16(double? value) {
    // Encode null as max allowed.
    if (value == null) {
      return _maxSmallDouble;
    } else {
      // Clamp the value between 0 and _maxSmallDouble-1 (since _maxSmallDouble
      // is interpreted as null). In order to store one decimal, multiply by 10.
      return min(max(0, 10 * value), _maxSmallDouble - 1).round();
    }
  }

  /// The opposite of [smallDoubleToUint16].
  static double? uint16ToSmallDouble(int value) =>
      value != _maxSmallDouble ? value / 10.0 : null;

  /// Converts a heading to [Int16], making sure that heading values are
  /// between 0..360 even if provided as -huge..+huge (e.g. 450 degrees is the
  /// same as 90 degrees, -450 degrees is the same as 270 degrees).
  ///
  /// For the internal conversion and null handling see [smallDoubleToUint16].
  /// Note that unit tests assume [headingToInt16] calls [smallDoubleToUint16]
  /// and therefore will only test the boundaries. If this is changed, the unit
  /// tests need to be extended.
  static int headingToInt16(double? value) =>
      smallDoubleToUint16(value != null ? value % 360.0 : null);

  /// The opposite of [headingToInt16].
  static double? int16ToHeading(int value) => uint16ToSmallDouble(value);
}
