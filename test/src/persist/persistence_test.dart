/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_persist.dart';

import 'persist_test_helpers.dart';

/// Class for testing purposes, as the global [Persistence] class is a singleton
/// and we don't want to interfere with its state. This one is not a singleton.
class PersistenceDummy extends Persistence {
  factory PersistenceDummy.get() => PersistenceDummy._internal();

  /// Internal constructor for use in singleton behaviour.
  PersistenceDummy._internal();
}

/// Class for testing purposes.
class PersisterDummy extends Persister {
  /// Remember if readViewFromStream was called, what the version was.
  var readViewVersion;

  /// Remember if readViewFromStream was called, what the metadata was.
  var readViewMetadata;

  PersisterDummy(Persistence persistence) : super(persistence);

  @override
  SignatureAndVersion initializeSignatureAndVersion() {
    // Signature of all 'x' characters.
    final sig = String.fromCharCodes(
        List<int>.filled(SignatureAndVersion.RequiredSignatureLength, 120));
    return SignatureAndVersion(sig, 1);
  }

  @override
  Type get supportedType => GpcDummy;

  /// Keeps track of which parameters it was called with (in [readViewVersion]
  /// and [redViewMetadata], and instantiates a point for every byte found
  /// in the stream).
  @override
  void readViewFromStream(GpsPointsView view, StreamReaderState source,
      int version, ByteData metadata) async {
    readViewVersion = version;
    readViewMetadata = metadata;

    // Should only be called for GpcDummy.
    view = view as GpsPointsCollection;
    while (true) {
      var readByte = await source.readUint8();
      if (readByte == null) {
        break;
      }
      view.add(GpsPoint(DateTime.utc(readByte ~/ 10, readByte % 10),
          readByte.toDouble(), readByte.toDouble(), readByte.toDouble()));
    }
  }

  /// Writes one byte for every item in the [view], with the byte being the
  /// index (capped of course at byte value boundary if more than 255 items
  /// are in the list).
  @override
  Stream<List<int>> writeViewToStream(GpsPointsView view) {
    return Stream<List<int>>.value(
        List<int>.generate(view.length, (index) => index));
  }
}

/// Dummy class that has the same signature as [PersisterDummy], to check that
/// duplicate signatures are not allowed.
class PersisterDummyDupeSignature extends PersisterDummy {
  PersisterDummyDupeSignature(Persistence persistence) : super(persistence);

  /// Duplicate types are checked seapartely, so give it a different supported
  /// type.
  @override
  Type get supportedType => GpcListBased;
}

/// Dummy class that has the same [supportedType] as [PersisterDummy], to check
/// that duplicate supported types are overwritten.
class PersisterDummyDupeSupportedType extends PersisterDummy {
  PersisterDummyDupeSupportedType(Persistence persistence) : super(persistence);

  /// Duplicate signatures are checked seapartely, so give it a different
  /// signature.
  @override
  SignatureAndVersion initializeSignatureAndVersion() {
    // Signature of all 'y' characters.
    final sig = String.fromCharCodes(
        List<int>.filled(SignatureAndVersion.RequiredSignatureLength, 121));
    return SignatureAndVersion(sig, 1);
  }
}

/// Class for testing purposes.
class GpcDummy extends GpcListBased {}

/// Tests the Persistence behaviours.
void testPersistence() {
  /// Checks that the standard [Persistence] class behaves correctly as a
  /// singleton.
  test('Singleton behaviour', () {
    final p0 = Persistence.get();
    final p1 = Persistence.get();
    expect(identical(p0, p1), true,
        reason: 'Factory did not return identical object (singleton).');
  });

  /// Test the registration of [Persister]s.
  group('Persister registration and getPersister', () {
    test('Regular registration', () {
      final persistence = PersistenceDummy.get();
      final persister = PersisterDummy(persistence);

      expect(identical(persistence.getPersister(GpcDummy()), persister), true,
          reason: 'Dummy persister should have been returned.');

      expect(
          () => persistence.getPersister(GpcListBased()),
          throwsA(isA<NoPersisterException>().having((e) => e.message,
              'message', contains('${GpcListBased().runtimeType}'))),
          reason:
              'Dummy persister should not have a persister for ${GpcListBased().runtimeType}');

      expect(
          () => Persistence.get().getPersister(GpcDummy()),
          throwsA(isA<NoPersisterException>().having((e) => e.message,
              'message', contains('${GpcDummy().runtimeType}'))),
          reason:
              'Global singleton Persistence should not contain persister for ${GpcDummy().runtimeType}');
    });

    test('Duplicate signatures', () {
      final persistence = PersistenceDummy.get();
      PersisterDummy(persistence);
      expect(
          () => PersisterDummyDupeSignature(persistence),
          throwsA(isA<ConflictingPersisterException>()
              .having((e) => e.message, 'message', contains('signature'))));
    });

    test('Overwriting persisters', () {
      final persistence = PersistenceDummy.get();

      // Register the first persister supporting GpsDummy.
      PersisterDummy(persistence);

      // Register a second persister supporting GpsDummy. This shoud
      // owverwite the previous persister for that type.
      final overwritingPersister = PersisterDummyDupeSupportedType(persistence);
      expect(
          identical(persistence.getPersister(GpcDummy()), overwritingPersister),
          true,
          reason: 'Dummy persister should have been overwritten returned.');
    });
  });
}

/// Tests [Persistence.write].
void testWrite() {
  group('Test writing', () {
    PersistenceDummy? persistence;
    GpcDummy? gpc;
    TestStreamSink? sink;

    setUp(() {
      persistence = PersistenceDummy.get();
      PersisterDummy(persistence!);

      gpc = GpcDummy();

      sink = TestStreamSink();
    });

    tearDown(() {
      persistence = null;
      gpc = null;
    });

    test('Write empty list', () {
      persistence!.write(gpc!, sink!);

      final sig = 'AnqsGpsHistoryFile--';
      final sigList = sig.codeUnits;
      final versionList = [1, 0];
      final persisterSigList = List<int>.filled(
          SignatureAndVersion.RequiredSignatureLength, 'x'.codeUnitAt(0));
      final metadataLength = [0];
      final metadata = List<int>.filled(55, 0);

      expect(sink!.receivedData.length, 100, reason: 'incorrect data');

      expect(sink!.receivedData, [
        ...sigList,
        ...versionList,
        ...persisterSigList,
        ...versionList,
        ...metadataLength,
        ...metadata
      ]);
    });
  });
}

void main() {
  testPersistence();

  testWrite();
}
