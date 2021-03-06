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

/// A space-efficient [GpsPointsCollection] implementation.
///
/// Implements a collection that internally stores the points in ByteData.
/// This requires runtime value conversions, but cuts down drastically on
/// memory use particularly for large data sets. A test of 12.5 million
/// points represented as a list of objects of 4 doubles each, versus 12.5
/// million points represented as a list of [Int32x4] showed memory use drop
/// from about 400MB to about 200MB. On mobile devices in particular this could
/// be quite a significant gain.
/// This does come at the expense of some accuracy, as we store lower-accuracy
/// integer subtypes rather than doubles.
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
  int get elementSizeInBytes;

  /// The number of elements currently stored in the container.
  @override
  int get length => _elementsCount;

  @override
  T operator [](int index) =>
      _readElementFromBytes(_elementNrToByteOffset(index));

  /// The available capacity (in elements) for storage.
  ///
  /// Not all the space is necessarily currently used (used space is indicated
  /// by the [length] property). Capacity may be increased manually for
  /// efficiency (pre-allocating the required memory), and will be grown
  /// automatically if elements are added without explicit pre-allocation of
  /// capacity.
  /// Capacity cannot be decreased to less than the current length, since
  /// that might invalidate any pre-existing views on this container.
  int get capacity => _rawData.lengthInBytes ~/ elementSizeInBytes;
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
  int _elementNrToByteOffset(int elementNr) => elementNr * elementSizeInBytes;

  /// Returns the element stored starting at the specified byteIndex.
  ///
  /// Must be overridden in children, as it depends on how they implement
  /// storage and what type T is.
  T _readElementFromBytes(int byteIndex);

  /// Writes the element, starting at the specified byteIndex.
  ///
  /// Must be overridden in children, as it depends on how they implement
  /// storage and what type T is.
  void _writeElementToBytes(T element, int byteIndex);

  @override
  void add(T element) {
    _growCapacity();
    _writeElementToBytes(element, _elementNrToByteOffset(_elementsCount));
    _elementsCount += 1;
  }

  @override
  void addAll(Iterable<T> iterable) {
    capacity = _elementsCount + iterable.length;
    for (var element in iterable) {
      add(element);
    }
  }

  /// Specialized version of [addAll] that can copy from a source of the
  /// same type as this object, by doing a binary copy of the internal data.
  void addAllFast(GpcEfficient<T> source) {
    // Copying binary data between different types is not safe.
    if (runtimeType != source.runtimeType) {
      throw TypeError();
    }

    // source._rawData may contain allocated, but currently unused bytes. Don't
    // copy those. Instead, create a view of only the used bytes and copy that.
    addByteData(source._rawData.buffer
        .asByteData(0, source.length * source.elementSizeInBytes));
  }

  /// Adds all the [sourceData] to the internal buffer. The data must conform
  /// to the internal format, i.e. the number of bytes must be sufficient to
  /// represent completely a certain number of elements, otherwise an exception
  /// will be thrown.
  void addByteData(ByteData sourceData) {
    // Make sure that the data we receive is well formed.
    if (sourceData.lengthInBytes % elementSizeInBytes != 0) {
      throw Exception(
          'Provided number of bytes ${sourceData.lengthInBytes} not divisible by bytes per element $elementSizeInBytes.');
    }

    // Allocate sufficient space for the new elements.
    final newElements = sourceData.lengthInBytes ~/ elementSizeInBytes;
    capacity = max(capacity, length + newElements);

    // Copy the data over.
    final targetByte = _elementNrToByteOffset(length);
    _rawData.buffer.asUint8List().setRange(targetByte,
        targetByte + sourceData.lengthInBytes, sourceData.buffer.asUint8List());

    // Update the number of elements.
    _elementsCount += newElements;
  }

  /// Returns a view of the internal bytes data starting at [startElement] and
  /// containing [viewLengthElements] elements. Care must be taken that
  /// [startElement] + [viewLengthElements] <= [length].
  List<int> getByteDataView(int startElement, int viewLengthElements) {
    return _rawData.buffer.asUint8List(_elementNrToByteOffset(startElement),
        _elementNrToByteOffset(viewLengthElements));
  }
}

/// Implements common conversions needed for storing GPS values in byte arrays.
///
/// Ranges of data will be ensured only at writing time. This because the data
/// is written only once, but potentially read many times.
class Conversions {
  static final _zeroDateTimeUtc = DateTime.utc(1970);
  static final _maxDatetimeUtc =
      _zeroDateTimeUtc.add(Duration(seconds: 0xffffffff.toUnsigned(32)));
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
  static int dateTimeToUint32(DateTime value) {
    final valueUtc = value.toUtc();
    // Cap the value between zero and the max allowed
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
      final cappedValue = value.sign * min(value.abs(), _extremeAltitude);
      return (2 * cappedValue).round();
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

  //// The opposite of [headingToInt16].
  static double? int16ToHeading(int value) => uint16ToSmallDouble(value);
}

/// Implements compact storage for [GpsPoint] elements.
///
/// [GpsPoint] consists of four doubles: time, latitude, longitude, altitude.
/// In order to improve the storage efficiency, these are stored as follows,
/// all in *little endian* representation:
/// - [GpsPoint.time]: [Uint32] representation of time. For details see
///   [Conversions.dateTimeToUint32].
/// - [GpsPoint.latitude]: [Uint32] in PosE7-spec. For details see
///   [Conversions.latitudeToUint32].
/// - [GpsPoint.longitude]: [Uint32] in PosE7-spec. For details see
///   [Conversions.longitudeToUint32].
/// - [GpsPoint.altitude]: [Int16]. For details see
///   [Conversions.altitudeToInt16].
///
/// Added together it's 14 bytes per element.
abstract class GpcCompact<T extends GpsPoint> extends GpcEfficient<T> {
  static const _endian = Endian.little;
  static const int _offsetLatitude = 4;
  static const int _offsetLongitude = 8;
  static const int _offsetAltitude = 12;

  @override
  int get elementSizeInBytes => 14;

  // Various wrappers around ByteData routines to ensure uniform endianness.
  int _getInt16(int byteIndex) => _rawData.getInt16(byteIndex, _endian);
  int _getUint16(int byteIndex) => _rawData.getUint16(byteIndex, _endian);
  int _getUint32(int byteIndex) => _rawData.getUint32(byteIndex, _endian);
  void _setInt16(int byteIndex, int value) =>
      _rawData.setInt16(byteIndex, value, _endian);
  void _setUint16(int byteIndex, int value) =>
      _rawData.setUint16(byteIndex, value, _endian);
  void _setUint32(int byteIndex, int value) =>
      _rawData.setUint32(byteIndex, value, _endian);

  /// Reads a single GPS point from the [_rawData].
  ///
  /// Useful to use in children's [_readElementFromBytes] implementations.
  GpsPoint _readGpsPointFromBytes(int byteIndex) {
    return GpsPoint(
        Conversions.uint32ToDateTime(_getUint32(byteIndex)),
        Conversions.uint32ToLatitude(_getUint32(byteIndex + _offsetLatitude)),
        Conversions.uint32ToLongitude(_getUint32(byteIndex + _offsetLongitude)),
        Conversions.int16ToAltitude(_getInt16(byteIndex + _offsetAltitude)));
  }

  /// Writes a single GPS point to the [_rawData].
  ///
  /// Useful to use in children's [_writeElementToBytes] implmentations.
  void _writeGpsPointToBytes(T element, int byteIndex) {
    _setUint32(byteIndex, Conversions.dateTimeToUint32(element.time));
    _setUint32(byteIndex + _offsetLatitude,
        Conversions.latitudeToUint32(element.latitude));
    _setUint32(byteIndex + _offsetLongitude,
        Conversions.longitudeToUint32(element.longitude));
    _setInt16(byteIndex + _offsetAltitude,
        Conversions.altitudeToInt16(element.altitude));
  }
}

/// Implements efficient storage for [GpsPoint] elements.
class GpcCompactGpsPoint extends GpcCompact<GpsPoint> {
  @override
  GpsPoint _readElementFromBytes(int byteIndex) {
    return _readGpsPointFromBytes(byteIndex);
  }

  @override
  void _writeElementToBytes(GpsPoint element, int byteIndex) {
    return _writeGpsPointToBytes(element, byteIndex);
  }
}

/// Implements efficient storage for [GpsMeasurement] elements.
///
/// The basic storage is the same of [GpcCompactGpsPoint], with additional
/// fields for: accuracy, heading, speed, speedAccuracy. One or more of these
/// may be null.
/// These are stored as follows after the inherited fields, all in
/// *little endian* representation:
/// - [GpsMeasurement.accuracy]: [Uint16] representation of accuracy.
///   For details see [Conversions.smallDoubleToUint16].
/// - [GpsMeasurement.heading]: [Uint16] representation of heading.
///   For details see [Conversions.headingToInt16].
/// - [GpsMeasurement.speed]: [Uint16] representation of speed.
///   For details see [Conversions.smallDoubleToUint16].
/// - [GpsMeasurement.speedAccuracy]: [Uint16] representation of speed accuracy.
///   For details see [Conversions.smallDoubleToUint16].
///
/// Added together it's 8 bytes per element extra compared to what's needed
/// for the inherited [GpsPoint] properties.
class GpcCompactGpsMeasurement extends GpcCompact<GpsMeasurement> {
  static const int _offsetAccuracy = 14;
  static const int _offsetHeading = 16;
  static const int _offsetSpeed = 18;
  static const int _offsetSpeedAccuracy = 20;

  @override
  int get elementSizeInBytes => 22;

  @override
  GpsMeasurement _readElementFromBytes(int byteIndex) {
    final point = _readGpsPointFromBytes(byteIndex);

    return GpsMeasurement.fromPoint(
        point,
        Conversions.uint16ToSmallDouble(
            _getUint16(byteIndex + _offsetAccuracy)),
        Conversions.int16ToHeading(_getUint16(byteIndex + _offsetHeading)),
        Conversions.uint16ToSmallDouble(_getUint16(byteIndex + _offsetSpeed)),
        Conversions.uint16ToSmallDouble(
            _getUint16(byteIndex + _offsetSpeedAccuracy)));
  }

  @override
  void _writeElementToBytes(GpsMeasurement element, int byteIndex) {
    _writeGpsPointToBytes(element, byteIndex);

    _setUint16(byteIndex + _offsetAccuracy,
        Conversions.smallDoubleToUint16(element.accuracy));
    _setUint16(byteIndex + _offsetHeading,
        Conversions.headingToInt16(element.heading));
    _setUint16(byteIndex + _offsetSpeed,
        Conversions.smallDoubleToUint16(element.speed));
    _setUint16(byteIndex + _offsetSpeedAccuracy,
        Conversions.smallDoubleToUint16(element.speedAccuracy));
  }
}
