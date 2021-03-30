/* GPS points collections optimized for high performance and memory efficiency
 *
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';
import 'dart:typed_data';
import 'package:gps_history/src/base.dart';

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

  /// The elements are measured in externally perceived elements, not as bytes.
  var _elementsCount = 0;

  GpcEfficient([int startCapacity = 0]) {
    _rawData = ByteData(_elementNrToByteOffset(startCapacity));
  }

  /// Subclasses must override this to indicate how many slots in the buffer
  /// are required to store every element.
  int get _bytesPerElement;

  /// Length indicates how many elements are currently stored in the container.
  @override
  int get length => _elementsCount;

  @override
  T operator [](int index) =>
      _readElementFromByte(_elementNrToByteOffset(index));

  /// Capacity indicates how much space there is in the storage for elements.
  /// Not all the space is necessarily currently used (used space is indicated
  /// by the length property). Capacity may be increased manually for efficiency
  /// (pre-allocating the required memory), and will be grown automatically
  /// if elements are added without explicit pre-allocation of capacity.
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
    var newData = ByteData(_elementNrToByteOffset(newCapacity));
    // Even though currently we don't alow decreasing capacity below length,
    // keep in a safeguard that we won't copy more than the capacity.
    var bytesToCopy = _elementNrToByteOffset(min(newCapacity, length));
    // do a hopefully optimized memcopy
    newData.buffer
        .asUint8List()
        .setRange(0, bytesToCopy, _rawData.buffer.asUint8List());
    // Replace the buffer with the one with different capacity
    _rawData = newData;
  }

  /// Makes sure there is enough space to add at least incrementHint elements.
  /// May decide to increment by more than the hint though, in order to prevent
  /// repetitive resizing, which is a relatively expensive operation.
  /// For setting the capacity exactly, use the capacity property.
  void _growCapacity([int? incrementHint]) {
    // If we have enough capacity to fit the hint, don't bother increasing
    var localCapacity = capacity; // cache since we'll be using it quite a bit
    if (localCapacity >= length + (incrementHint ?? 1)) {
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
    if (localCapacity >= 1 << 18) {
      // over ~500k, grow in big chunks of about 260k
      minIncrement = 1 << 17;
    } else if (localCapacity >= 1 << 16) {
      // over ~130k, grow at >30k chunks
      minIncrement = localCapacity ~/ 4;
    } else if (localCapacity >= 1 << 13) {
      // over ~16k, grow at >8k chunks
      minIncrement = localCapacity ~/ 2;
    } else if (localCapacity >= 1 << 7) {
      // over 256, double in size
      minIncrement = localCapacity;
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

  /// Returns the element stored starting at the specified byteIndex. Must be
  /// overridden in children, as it depends on how they implement storage and
  /// what type T is.
  T _readElementFromByte(int byteIndex);

  /// Writes the element, starting at the specified byteIndex. Must be overridden
  /// in children, as it depends on how they implement storage and what type
  /// T is.
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
