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

import 'base.dart';
import 'base_collections.dart';
import 'utils/binary_conversions.dart';
import 'utils/bounding_box.dart';
import 'utils/random_access_iterable.dart';
import 'utils/time.dart';

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

  /// The number of elements currently stored in the collection.
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
  /// that might invalidate any pre-existing views on this collection.
  int get capacity => _rawData.lengthInBytes ~/ elementSizeInBytes;
  set capacity(int newCapacity) {
    // Don't allow deleting any currently in-use elements, for it could invalidate
    // existing views.
    newCapacity = max(length, newCapacity);

    // If there's no change, stop.
    if (newCapacity == capacity) {
      return;
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
  // ignore: non_constant_identifier_names
  void add_Unsafe(T element) {
    _growCapacity();
    _writeElementToBytes(element, _elementNrToByteOffset(_elementsCount));
    _elementsCount += 1;
  }

  @override
  rollbackAddingLastItem() {
    // Pretend the last element doesn't exist (decreases the length).
    _elementsCount--;

    // Overwrite the data with all zeroes (this will increase the length again).
    addByteData(ByteData(elementSizeInBytes));

    // Move the length backwars again.
    _elementsCount--;
  }

  @override
  // ignore: non_constant_identifier_names
  void addAllStartingAt_Unsafe(Iterable<T> source,
      [int skipItems = 0, int? nrItems]) {
    // Try the fast algorithm if the data is of the correct type.
    if (runtimeType == source.runtimeType) {
      _addAllStartingAtFast_Unsafe(
          source as GpcEfficient<T>, skipItems, nrItems);
    } else {
      // No the same type -> do a slow copy.

      // For regular iterables, calling length will consume it, so we don't
      // want to do it. But for RandomAccessIterable, it's a safe operation and
      // we can use it to preset the capacity for performance reasons.
      if (source is RandomAccessIterable) {
        capacity = _elementsCount + (nrItems ?? (source.length - skipItems));
      }

      for (var element in getSubSource(source, skipItems, nrItems)) {
        add_Unsafe(element);
      }
    }
  }

  /// Specialized version of [addAllStartingAt_Unsafe] that can copy from a source
  /// of the same type as this object, by doing a binary copy of the internal
  /// data.
  // ignore: non_constant_identifier_names
  void _addAllStartingAtFast_Unsafe(GpcEfficient<T> source,
      [int skipItems = 0, int? nrItems]) {
    // Copying binary data between different types is not safe.
    if (runtimeType != source.runtimeType) {
      throw TypeError();
    }

    final skipBytes = skipItems * source.elementSizeInBytes;

    // source._rawData may contain allocated, but currently unused bytes, which
    // the buffer would still regard as being part of its length. We don't want
    // to copy those unused bytes, which is what would happen if we called
    // buffer.asByteData without a length argument. We want a view of only the
    // used bytes.
    final bytesToCopy =
        (nrItems ?? (source.length - skipItems)) * source.elementSizeInBytes;

    addByteData(source._rawData.buffer.asByteData(skipBytes, bytesToCopy));
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
    final sourceBytes = sourceData.buffer
        .asUint8List(sourceData.offsetInBytes, sourceData.lengthInBytes);
    _rawData.buffer.asUint8List().setRange(
        targetByte, targetByte + sourceData.lengthInBytes, sourceBytes);

    // Update the number of elements.
    _elementsCount += newElements;
  }

  /// Returns a copy of the internal bytes data starting at [startElement] and
  /// containing [nrElements] elements.
  ///
  /// Care must be taken that [startElement] + [nrElements] <= [length].
  /// Note that this is not a view, because a view would allow the caller to
  /// modify the contents directly, thereby bypassing any checks related to
  /// sorted state.
  List<int> exportAsBytes(int startElement, int nrElements) {
    final startByte = _elementNrToByteOffset(startElement);
    final endByte = _elementNrToByteOffset(nrElements);
    final view = _rawData.buffer.asUint8List(startByte, endByte);

    // Convert the view to a new list, so the internal buffer data cannot be
    // modified by the recipient of the result, which would allow bypassing
    // internal checks regarding sorted state.
    return view.toList(growable: false);
  }
}

/// Implements compact storage for [GpsPoint] elements.
///
/// [GpsPoint] consists of four doubles: time, latitude, longitude, altitude.
/// In order to improve the storage efficiency, these are stored as follows,
/// all in *little endian* representation:
/// - [GpsPoint.time]: [Uint32] representation of time. For details see
///   [Conversions.gpsTimeToUint32].
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
        // If the time storage method is changed, also modify the compareTime
        // method!
        time: Conversions.uint32ToGpsTime(_getUint32(byteIndex))!,
        latitude: Conversions.uint32ToLatitude(
            _getUint32(byteIndex + _offsetLatitude)),
        longitude: Conversions.uint32ToLongitude(
            _getUint32(byteIndex + _offsetLongitude)),
        altitude: Conversions.int16ToAltitude(
            _getInt16(byteIndex + _offsetAltitude)));
  }

  /// Writes a single GPS point to the [_rawData].
  ///
  /// Useful to use in children's [_writeElementToBytes] implmentations.
  void _writeGpsPointToBytes(T element, int byteIndex) {
    _setUint32(byteIndex, Conversions.gpsTimeToUint32(element.time));
    _setUint32(byteIndex + _offsetLatitude,
        Conversions.latitudeToUint32(element.latitude));
    _setUint32(byteIndex + _offsetLongitude,
        Conversions.longitudeToUint32(element.longitude));
    _setInt16(byteIndex + _offsetAltitude,
        Conversions.altitudeToInt16(element.altitude));
  }

  @override
  TimeComparisonResult compareElementTime(int elementNrA, int elementNrB) {
    // No need to fully parse and instantiate the points, it's enough to
    // compare the integer representations of the time values.
    final timeA = _getUint32(_elementNrToByteOffset(elementNrA));
    final timeB = _getUint32(_elementNrToByteOffset(elementNrB));

    return compareIntRepresentationTime(timeA, timeB);
  }

  @override
  TimeComparisonResult compareElementTimeWithSeparateTime(
      int elementNrA, GpsTime timeB) {
    final elementTime = _getUint32(_elementNrToByteOffset(elementNrA));
    final itemTime = Conversions.gpsTimeToUint32(timeB);

    return compareIntRepresentationTime(elementTime, itemTime);
  }

  @override
  TimeComparisonResult compareElementTimeWithSeparateTimeSpan(
      int elementNrA, int startB, int endB) {
    final elementTime = _getUint32(_elementNrToByteOffset(elementNrA));
    return compareTimeSpans(
        startA: elementTime, endA: elementTime, startB: startB, endB: endB);
  }

  @override
  TimeComparisonResult compareElementTimeWithSeparateItem(
      int elementNrA, T elementB) {
    final elementTime = _getUint32(_elementNrToByteOffset(elementNrA));
    final itemTime = Conversions.gpsTimeToUint32(elementB.time);

    return compareIntRepresentationTime(elementTime, itemTime);
  }

  @override
  bool elementContainedByBoundingBox(
      int elementNr, LatLongBoundingBox boundingBox) {
    // Internal storage uses the same notation as the FlatLatLongBoundingBox,
    // hence prefer using that type of bounding box.
    if (boundingBox is GeodeticLatLongBoundingBox) {
      boundingBox = FlatLatLongBoundingBox.fromGeodetic(boundingBox);
    }
    final byteIndex = _elementNrToByteOffset(elementNr);
    return boundingBox.contains(_getUint32(byteIndex + _offsetLatitude),
        _getUint32(byteIndex + _offsetLongitude));
  }

  @override
  void callLatLongE7FuncForItemAt(ItemLatLongFunction func, int index) {
    final byteIndex = _elementNrToByteOffset(index);
    func(index, _getUint32(byteIndex + GpcCompact._offsetLatitude),
        _getUint32(byteIndex + GpcCompact._offsetLongitude));
  }
}

/// Implements efficient storage for [GpsPoint] elements.
class GpcCompactGpsPoint extends GpcCompact<GpsPoint> {
  @override
  GpsPointsCollection<GpsPoint> newEmpty({int? capacity}) {
    return GpcCompactGpsPoint()..capacity = capacity ?? 0;
  }

  @override
  GpsPoint _readElementFromBytes(int byteIndex) {
    return _readGpsPointFromBytes(byteIndex);
  }

  @override
  void _writeElementToBytes(GpsPoint element, int byteIndex) {
    return _writeGpsPointToBytes(element, byteIndex);
  }
}

/// Implements efficient storage for [GpsStay] elements.
///
/// The basic storage is the same of [GpcCompactGpsPoint], with additional
/// fields for: accuracy, endTime. One or more of these may be null.
/// These are stored as follows after the inherited fields, all in
/// *little endian* representation:
/// - [GpsStay.accuracy]: [Uint16] representation of accuracy.
///   For details see [Conversions.smallDoubleToUint16].
/// - [GpsStay.endTime]: [Uint32] representation of endtime.
///   For details see [Conversions.gpsTimeToUint32].
///
/// Added together it's 6 bytes per element extra compared to what's needed
/// for the inherited [GpsPoint] properties.
class GpcCompactGpsStay extends GpcCompact<GpsStay> {
  static const int _offsetAccuracy = 14;
  static const int _offsetEndTime = 16;

  @override
  GpcCompactGpsStay newEmpty({int? capacity}) {
    return GpcCompactGpsStay()..capacity = capacity ?? 0;
  }

  @override
  int get elementSizeInBytes => 20;

  @override
  GpsStay _readElementFromBytes(int byteIndex) {
    final point = _readGpsPointFromBytes(byteIndex);

    return GpsStay.fromPoint(point,
        accuracy: Conversions.uint16ToSmallDouble(
            _getUint16(byteIndex + _offsetAccuracy)),
        endTime: Conversions.uint32ToGpsTime(
            _getUint32(byteIndex + _offsetEndTime)));
  }

  @override
  void _writeElementToBytes(GpsStay element, int byteIndex) {
    _writeGpsPointToBytes(element, byteIndex);

    _setUint16(byteIndex + _offsetAccuracy,
        Conversions.smallDoubleToUint16(element.accuracy));
    _setUint32(byteIndex + _offsetEndTime,
        Conversions.gpsTimeToUint32(element.endTime));
  }

  /// Compares the time conditions for the two elements and indices [elementNrA]
  /// and [elementNrB].
  @override
  TimeComparisonResult compareElementTime(int elementNrA, int elementNrB) {
    final startA = _getUint32(_elementNrToByteOffset(elementNrA));
    final endA =
        _getUint32(_elementNrToByteOffset(elementNrA) + _offsetEndTime);
    final startB = _getUint32(_elementNrToByteOffset(elementNrB));
    final endB =
        _getUint32(_elementNrToByteOffset(elementNrB) + _offsetEndTime);

    return compareTimeSpans(
        startA: startA, endA: endA, startB: startB, endB: endB);
  }

  @override
  TimeComparisonResult compareElementTimeWithSeparateTimeSpan(
      int elementNrA, int startB, int endB) {
    // See documentation of compareElementTime for what the various rules are.
    // This implementation is effectively a copypaste operation, for speed
    // reasons.
    final startA = _getUint32(_elementNrToByteOffset(elementNrA));
    final endA =
        _getUint32(_elementNrToByteOffset(elementNrA) + _offsetEndTime);

    return compareTimeSpans(
        startA: startA, endA: endA, startB: startB, endB: endB);
  }

  @override
  TimeComparisonResult compareElementTimeWithSeparateItem(
      int elementNrA, GpsStay elementB) {
    // See documentation of compareElementTime for what the various rules are.
    // This implementation is effectively a copypaste operation, for speed
    // reasons.
    final startA = _getUint32(_elementNrToByteOffset(elementNrA));
    final endA =
        _getUint32(_elementNrToByteOffset(elementNrA) + _offsetEndTime);
    final startB = Conversions.gpsTimeToUint32(elementB.time);
    final endB = Conversions.gpsTimeToUint32(elementB.endTime);

    return compareTimeSpans(
        startA: startA, endA: endA, startB: startB, endB: endB);
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
  GpcCompactGpsMeasurement newEmpty({int? capacity}) {
    return GpcCompactGpsMeasurement()..capacity = capacity ?? 0;
  }

  @override
  int get elementSizeInBytes => 22;

  @override
  GpsMeasurement _readElementFromBytes(int byteIndex) {
    final point = _readGpsPointFromBytes(byteIndex);

    return GpsMeasurement.fromPoint(point,
        accuracy: Conversions.uint16ToSmallDouble(
            _getUint16(byteIndex + _offsetAccuracy)),
        heading:
            Conversions.int16ToHeading(_getUint16(byteIndex + _offsetHeading)),
        speed: Conversions.uint16ToSmallDouble(
            _getUint16(byteIndex + _offsetSpeed)),
        speedAccuracy: Conversions.uint16ToSmallDouble(
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
