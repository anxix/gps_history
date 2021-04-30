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
/// methods/properties like [supportedType] and [initializeSignatureAndVersion].
abstract class PGpcEfficient<T extends GpcEfficient> extends Persister {
  PGpcEfficient(Persistence persistence) : super(persistence);

  @override
  Future<void> readViewFromStream(GpsPointsView view, StreamReaderState source,
      int version, ByteData metadata) {
    return Future.sync(() async {
      final gpc = view as GpcEfficient;

      // Pre-allocate the capacity if possible.
      gpc.capacity = source.remainingStreamBytesHint ?? gpc.capacity;

      // Read data in roughly 64 kB chunks, but such that they're divisible
      // by the expected element size.
      final chunkSizeElements = (1 << 16) ~/ gpc.elementSizeInBytes;
      // Ensure it's robust for stupid situations where the element size is
      // huge: always read at least one element at a time.
      final chunkSizeBytes =
          gpc.elementSizeInBytes * max<int>(1, chunkSizeElements);

      do {
        final readData = await source.readByteData(chunkSizeBytes);
        if (readData.lengthInBytes == 0) {
          break;
        }
        gpc.addByteData(readData);
      } while (true);
    });
  }

  @override
  Stream<List<int>> writeViewToStream(GpsPointsView view);
}
