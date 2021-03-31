/// GPS points collections optimized for high performance and memory efficiency

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';
import 'dart:typed_data';
import 'package:gps_history/src/base.dart';

/// A space-efficient storage [GpsPointsCollection] implementation.
///
/// Implements a collection that internally stores the points in ByteData.
/// This requires runtime value conversions, but cuts down drastically on
/// memory use particularly for large data sets. A test of 12.5 million
/// points represented as a list of objects of 4 doubles each, versus 12.5
/// million points represented as a list of Int32x4 showed memory use drop
/// from about 400MB to about 200MB. On mobile device in particular this could
/// be quite a significant gain. This does come at the expense of some accuracy,
/// as we store lower-accuracy integer subtypes rather than doubles.
abstract class GpcEfficient<T extends GpsPoint> extends GpsPointsCollection<T> {
  /// The raw data representation of the collection (starts empty).
  var _rawData = ByteData(0);

  /// The number of elements as externally perceived elements, not as bytes.
  var _elementsCount = 0;

  GpcEfficient([int startCapacity = 0]) {
    _rawData = ByteData(_elementNrToByteOffset(startCapacity));
  }

  /// The number of bytes in [_rawData] required to store a single element.
  ///
  /// Subclasses must override this to indicate how many slots in the buffer
  /// are required to store every element.
  int get _bytesPerElement;

  /// The number of elements currently stored in the container.
  @override
  int get length => _elementsCount;

  @override
  T operator [](int index) =>
      _readElementFromByte(_elementNrToByteOffset(index));

  /// The available capacity (in elements) for storage.
  ///
  /// Not all the space is necessarily currently used (used space is indicated
  /// by the [length] property). Capacity may be increased manually for
  /// efficiency (pre-allocating the required memory), and will be grown
  /// automatically if elements are added without explicit pre-allocation of
  /// capacity.
  /// Capacity cannot be decreased to less than the current length, since
  /// that might invalidate any pre-existing views on this container.
  int get capacity => _rawData.lengthInBytes ~/ _bytesPerElement;
  set capacity(int newCapacity) {
    // Don't allow deleting any currently in-use elements, for it could invalidate
    // existing views.
    newCapacity = max(length, newCapacity);

    // If there's no change, stop.
    if (newCapacity == capacity) {
      return null;
    }

    // Capacity needs to change -> rebuild the list
    final newData = ByteData(_elementNrToByteOffset(newCapacity));
    // Even though currently we don't alow decreasing capacity below length,
    // keep in a safeguard that we won't copy more than the capacity.
    final bytesToCopy = _elementNrToByteOffset(min(newCapacity, length));
    // do a hopefully optimized memcopy
    newData.buffer
        .asUint8List()
        .setRange(0, bytesToCopy, _rawData.buffer.asUint8List());
    // Replace the buffer with the one with different capacity
    _rawData = newData;
  }

  /// Makes sure there is enough space to add at least [incrementHint] elements.
  ///
  /// May decide to increment by more than the hint though, in order to prevent
  /// repetitive resizing, which is a relatively expensive operation.
  /// For setting the capacity exactly, use the [capacity] property.
  void _growCapacity([int? incrementHint]) {
    // If we have enough capacity to fit the hint, don't bother increasing
    final currentCapacity =
        capacity; // cache since we'll be using it quite a bit
    if (currentCapacity >= length + (incrementHint ?? 1)) {
      return;
    }

    // In order to prevent excessive resizing, increment size in sufficiently
    // large chunks. Sizes are very roughly inspired by FreePascal's
    // TFPList.Expand implementation, but not benchmarked.
    // To give an idea of required capacity for different location tracking:
    //   - lifetime rough:              50 years   6x per hour     => ~2500k elements
    //   - Google-style history:         1 year    1x per minute   =>  ~500k elements
    //   - accurate long walk:           8 hours   1x per second   =>   ~30k elements
    // In terms of memory use, an unsophisticated implementation using 8 Int32
    // fields for each element, 100k elements represent ~3 MiB.
    var minIncrement = 0;
    if (currentCapacity >= 1 << 18) {
      // over ~500k, grow in big chunks of about 260k
      minIncrement = 1 << 17;
    } else if (currentCapacity >= 1 << 16) {
      // over ~130k, grow at >30k chunks
      minIncrement = currentCapacity ~/ 4;
    } else if (currentCapacity >= 1 << 13) {
      // over ~16k, grow at >8k chunks
      minIncrement = currentCapacity ~/ 2;
    } else if (currentCapacity >= 1 << 7) {
      // over 256, double in size
      minIncrement = currentCapacity;
    } else {
      // grow by 32
      minIncrement = 1 << 5;
    }

    // Grow by either the incrementHint, or the minimum sensible increment,
    // whichever is highest.
    capacity = capacity + max(minIncrement, incrementHint ?? 0);
  }

  /// Converts the number of an element to the byte offset where the representation
  /// of that element starts in the buffer.
  int _elementNrToByteOffset(int elementNr) => elementNr * _bytesPerElement;

  /// Returns the element stored starting at the specified byteIndex.
  ///
  /// Must be overridden in children, as it depends on how they implement
  /// storage and what type T is.
  T _readElementFromByte(int byteIndex);

  /// Writes the element, starting at the specified byteIndex.
  ///
  /// Must be overridden in children, as it depends on how they implement
  /// storage and what type T is.
  void _writeElementToByte(T element, int byteIndex);

  @override
  void add(T element) {
    _growCapacity();
    _writeElementToByte(element, _elementNrToByteOffset(_elementsCount));
    _elementsCount += 1;
  }

  @override
  void addAll(Iterable<T> iterable) {
    capacity = _elementsCount + iterable.length;
    for (var element in iterable) {
      add(element);
    }
  }
}

/// Implements common conversions needed for storing GPS values in byte arrays
class Conversions {
  static final _zeroDateTimeUtc = DateTime.utc(1970);
  static final _maxDatetimeUtc =
      _zeroDateTimeUtc.add(Duration(seconds: 0xffffffff.toUnsigned(32)));
  static final int _extremeAltitude = 0xffff.toUnsigned(16) ~/ 2;

  /// Convert a latitude/longitude in degrees to E7-spec, i.e.
  /// round(degrees * 1E7).
  ///
  /// The minimum distance that can be represented by this accuracy is
  /// 1E-7 degrees, which at the equator represents about 1 cm.
  static int degreesToInt32(double value) => (value * 1E7).round();

  /// The opposite of [degreesToInt32].
  static double int32ToDegrees(int value) => value / 1E7;

  /// Convert regular DateTime object to a Uint32 value.
  ///
  /// The result will be seconds since 1/1/1970, in UTC. This amount is enough
  /// to cover over 135 years. Any fictitious GPS records before 1970 are
  /// thereby not supported, and neither are years beyond about 2105.
  /// If values outside the supported range are provided, they will be capped
  /// at the appropriate boundary (no exception will be raised).
  static int dateTimeToUint32(DateTime value) {
    final valueUtc = value.toUtc();
    // Cap the value between the zero and the max allowed
    final cappedValue = valueUtc.isBefore(_zeroDateTimeUtc)
        ? _zeroDateTimeUtc
        : valueUtc.isAfter(_maxDatetimeUtc)
            ? _maxDatetimeUtc
            : valueUtc;
    return cappedValue.difference(_zeroDateTimeUtc).inSeconds;
  }

  /// The opposite of [dateTimeToUint32]
  static DateTime uint32ToDateTime(int value) =>
      _zeroDateTimeUtc.add(Duration(seconds: value));

  /// Convert altitude in meters to an Int16 value.
  ///
  /// This is done by counting half-meters below/above zero, i.e.
  /// round(2 * altitude). That's enough to cover about 16km above/below zero
  /// level, a range outside which not many people venture. The altitude
  /// measurement accuracy of GPS devices also tends to be way more than
  /// 1 meter, so storing at half-meter accuracy doesn't lose us much.
  /// If values outside the supported range are provided, they will be capped
  /// at the appropriate boundary (no exception will be raised).
  static int altitudeToInt16(double value) {
    final cappedValue =
        value.abs() < _extremeAltitude ? value : value.sign * _extremeAltitude;
    return (cappedValue * 2).round();
  }

  /// The opposite of [altitudeToInt16].
  static double int16ToAltitude(int value) => value / 2.0;
}

/// Implements efficient storage for [GpsPoint] elements.
///
/// [GpsPoint] consists of four doubles: time, latitude, longitude, altitude.
/// In order to improve the storage efficiency, these are stored as follows,
/// all in *little endian* representation:
/// - [GpsPoint.time]: UInt32 representation of time. For details see
///   [Conversions.dateTimeToUint32].
/// - [GpsPoint.latitude]: Int32 in E7-spec. For details see
///   [Conversions.degreesToInt32].
/// - [GpsPoint.longitude]: like the latitude
/// - [GpsPoint.altitude]: Int16. For details see [Conversions.altitudeToInt16].
/// Added together it's 14 bytes per element.
class GpcEfficientGpsPoint extends GpcEfficient<GpsPoint> {
  static const _endian = Endian.little;

  @override
  int get _bytesPerElement => 14;

  @override
  GpsPoint _readElementFromByte(int byteIndex) {
    final raw_datetime = _rawData.getUint32(byteIndex, _endian);
    final raw_latitude = _rawData.getInt32(byteIndex + 4, _endian);
    final raw_longitude = _rawData.getInt32(byteIndex + 8, _endian);
    final raw_altitude = _rawData.getInt16(byteIndex + 12, _endian);

    return GpsPoint(
        Conversions.uint32ToDateTime(raw_datetime),
        Conversions.int32ToDegrees(raw_latitude),
        Conversions.int32ToDegrees(raw_longitude),
        Conversions.int16ToAltitude(raw_altitude));
  }

  @override
  void _writeElementToByte(GpsPoint element, int byteIndex) {
    _rawData.setInt32(
        byteIndex, Conversions.dateTimeToUint32(element.time), _endian);
    _rawData.setInt32(
        byteIndex + 4, Conversions.degreesToInt32(element.latitude), _endian);
    _rawData.setInt32(
        byteIndex + 8, Conversions.degreesToInt32(element.longitude), _endian);
    _rawData.setInt16(
        byteIndex + 12, Conversions.altitudeToInt16(element.altitude), _endian);
  }
}
