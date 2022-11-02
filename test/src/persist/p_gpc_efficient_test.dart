/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:test/test.dart';

import 'package:gps_history/gps_history_persist.dart';
import 'persist_test_helpers.dart';

/// Runs the persistence test for a specific points collection type
Future<void>
    testPersister<T extends GpsPoint, C extends GpsPointsCollection<T>>(
        String name,
        Persister Function() persisterConstructor,
        C Function() collectionConstructor,
        T Function(int itemIndex) itemConstructor) async {
  group(name, () {
    Persistence? persistence;

    setUp(() {
      persistence = PersistenceDummy.get();
      persistence!.register(persisterConstructor());
    });

    tearDown(() {
      persistence = null;
    });

    runTestSaveLoad(C sourceCollection) async {
      final sink = TestStreamSink();
      await persistence!.write(sourceCollection, sink);

      final loadedCollection = collectionConstructor();
      await persistence!
          .read(loadedCollection, Stream.value(sink.receivedData));

      expect(loadedCollection, sourceCollection);
    }

    test('emtpy', () async {
      await runTestSaveLoad(collectionConstructor());
    });

    test('single item', () async {
      final collection = collectionConstructor();
      collection.add(itemConstructor(0));

      await runTestSaveLoad(collection);
    });

    test('many items', () async {
      final collection = collectionConstructor();
      for (var i = 0; i < 1000000; i++) {
        collection.add(itemConstructor(i));
      }

      await runTestSaveLoad(collection);
    });
  });
}

void main() async {
  await testPersister(
      'GpcCompactGpsPoint',
      () => PGpcCompactGpsPoint(),
      () => GpcCompactGpsPoint(),
      (i) => GpsPoint(
          time: GpsTime.zero.add(hours: i),
          latitude: (i + 1) / 1000.0,
          longitude: (i + 1) / 2000.0,
          altitude: (i + 1) / 100));

  // TODO: add tests for Stay and WithAccuracy

  await testPersister(
      'GpcCompactGpsMeasurement',
      () => PGpcCompactGpsMeasurement(),
      () => GpcCompactGpsMeasurement(),
      (i) => GpsMeasurement(
          time: GpsTime.zero.add(hours: i),
          latitude: (i + 1) / 1000.0,
          longitude: (i + 1) / 2000.0,
          altitude: (i + 1) / 100,
          accuracy: (i + 1) / 200,
          heading: (i + 1) / 300,
          speed: (i + 1) / 400,
          speedAccuracy: (i + 1) / 500));
}
