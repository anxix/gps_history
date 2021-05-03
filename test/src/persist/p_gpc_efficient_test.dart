/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/src/base.dart';
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

    final _testSaveLoad = (C sourceCollection) async {
      final sink = TestStreamSink();
      final s = Stopwatch();
      s.start();
      await persistence!.write(sourceCollection, sink);
      s.stop();
      // TODO: remove prints
      print('saved in ${s.elapsedMilliseconds} ms');
      final loadedCollection = collectionConstructor();
      s.reset();
      s.start();
      await persistence!
          .read(loadedCollection, Stream.value(sink.receivedData));
      s.stop();
      print('loaded in ${s.elapsedMilliseconds} ms');
      expect(loadedCollection, sourceCollection);
    };

    test('emtpy', () async {
      await _testSaveLoad(collectionConstructor());
    });

    test('single item', () async {
      final collection = collectionConstructor();
      collection.add(itemConstructor(0));

      await _testSaveLoad(collection);
    });

    test('many items', () async {
      final collection = collectionConstructor();
      for (var i = 0; i < 1000000; i++) {
        collection.add(itemConstructor(i));
      }

      await _testSaveLoad(collection);
    });
  });
}

void main() async {
  await testPersister(
      'GpcCompactGpsPoint',
      () => PGpcCompactGpsPoint(),
      () => GpcCompactGpsPoint(),
      (i) => GpsPoint(DateTime.utc(1970).add(Duration(hours: i)),
          (i + 1) / 1000.0, (i + 1) / 2000.0, (i + 1) / 100));

  await testPersister(
      'GpcCompactGpsMeasurement',
      () => PGpcCompactGpsMeasurement(),
      () => GpcCompactGpsMeasurement(),
      (i) => GpsMeasurement(
          DateTime.utc(1970).add(Duration(hours: i)),
          (i + 1) / 1000.0,
          (i + 1) / 2000.0,
          (i + 1) / 100,
          (i + 1) / 200,
          (i + 1) / 300,
          (i + 1) / 400,
          (i + 1) / 500));
}
