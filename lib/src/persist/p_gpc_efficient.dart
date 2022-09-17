/// Facilities for persisting the GpcEfficient family.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';
import 'dart:typed_data';

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_persist.dart';

/// Abstract persister for [GpcEfficient]. Child classes should be created
/// for specific children of [GpcEfficient], providing overriddes for
/// methods/properties like [supportedType] and [signatureAndVersion].
abstract class PGpcEfficient<T extends GpcEfficient> extends Persister {
  /// Approximate number of bytes to use as chunk size when reading/writing.
  /// After some basic testing settled on about 4 MB chunks, since some
  /// performance checks with 1M [GpsPoint] in a [GpcCompactGpsPoint] showed
  /// less than 15% performance improvements if huge chunk sizes are allowed
  /// that fit the whole list in one go.
  final chunkSize = 1 << 22;

  const PGpcEfficient() : super();

  @override
  Future<void> readViewFromStream(GpsPointsView view, StreamReaderState source,
      int version, ByteData metadata) {
    return Future.sync(() async {
      final gpc = view as GpcEfficient;

      // Pre-allocate the capacity if possible.
      gpc.capacity = source.remainingStreamBytesHint ?? gpc.capacity;

      // Read data in roughly chunks, such that they're divisible by the
      // expected element size.
      final elementsPerChunk = chunkSize ~/ gpc.elementSizeInBytes;
      // Ensure it's robust for stupid situations where the element size is
      // huge: always read at least one element at a time.
      final chunkSizeBytes =
          gpc.elementSizeInBytes * max<int>(1, elementsPerChunk);

      do {
        final readData =
            await source.readByteData(chunkSizeBytes, gpc.elementSizeInBytes);

        if (readData.lengthInBytes == 0) {
          break;
        }
        gpc.addByteData(readData);
      } while (true);
    });
  }

  @override
  Stream<List<int>> writeViewToStream(GpsPointsView view) async* {
    final gpc = view as GpcEfficient;

    // Split it in chunks, making sure in case of huge element size that we
    // write at least one element per chunk.
    final elementsPerChunk = max<int>(1, chunkSize ~/ gpc.elementSizeInBytes);

    var elementsWritten = 0;
    while (elementsWritten < gpc.length) {
      // Don't try to write more elements than there are yet unwritten.
      final elementsToWrite =
          min<int>(elementsPerChunk, gpc.length - elementsWritten);

      yield gpc.exportAsBytes(elementsWritten, elementsToWrite);

      elementsWritten += elementsToWrite;
    }
  }
}

/// Persister for [GpcCompactGpsPoint].
class PGpcCompactGpsPoint extends PGpcEfficient<GpcCompactGpsPoint> {
  PGpcCompactGpsPoint() : super();

  @override
  SignatureAndVersion get signatureAndVersion {
    return SignatureAndVersion(signatureFromString('CGpsPoints'), 1);
  }

  @override
  Type get supportedType => GpcCompactGpsPoint;
}

/// Persister for [GpcCompactGpsMeasurement].
class PGpcCompactGpsMeasurement
    extends PGpcEfficient<GpcCompactGpsMeasurement> {
  const PGpcCompactGpsMeasurement() : super();

  @override
  SignatureAndVersion get signatureAndVersion {
    return SignatureAndVersion(signatureFromString('CGpsMeasurement'), 1);
  }

  @override
  Type get supportedType => GpcCompactGpsMeasurement;
}
