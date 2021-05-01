/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';
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
  int? readViewVersion;

  /// Remember if readViewFromStream was called, what the metadata was.
  ByteData? readViewMetadata;

  /// Custom metadata to write to stream.
  ByteData? metadataToWrite;

  PersisterDummy() : super();

  @override
  SignatureAndVersion get signatureAndVersion {
    // Signature of all 'x' characters.
    final sig = String.fromCharCodes(List<int>.filled(
        SignatureAndVersion.RequiredSignatureLength, 'x'.codeUnitAt(0)));
    return SignatureAndVersion(sig, 13);
  }

  @override
  Type get supportedType => GpcDummy;

  @override
  ByteData? getMetadata(GpsPointsView view) => metadataToWrite;

  /// Keeps track of which parameters it was called with (in [readViewVersion]
  /// and [redViewMetadata], and instantiates a point for every byte found
  /// in the stream).
  @override
  Future<void> readViewFromStream(GpsPointsView view, StreamReaderState source,
      int version, ByteData metadata,
      [int? streamSizeBytesHint]) async {
    return Future.sync(() async {
      readViewVersion = version;
      readViewMetadata = metadata;

      while (true) {
        var readByte = await source.readUint8();
        if (readByte == null) {
          break;
        }
        // Should only be called for GpcDummy.
        (view as GpsPointsCollection).add(GpsPoint(
            DateTime.utc(readByte ~/ 10, readByte % 10),
            readByte.toDouble(),
            readByte.toDouble(),
            readByte.toDouble()));
      }
    });
  }

  /// Writes one byte for every item in the [view], with the byte being the
  /// index + 1 (capped of course at byte value boundary if more than 255 items
  /// are in the list).
  @override
  Stream<List<int>> writeViewToStream(GpsPointsView view) {
    return Stream<List<int>>.value(
        List<int>.generate(view.length, (index) => index + 1));
  }
}

/// Dummy class that has the same signature as [PersisterDummy], to check that
/// duplicate signatures are not allowed.
class PersisterDummyDupeSignature extends PersisterDummy {
  PersisterDummyDupeSignature() : super();

  /// Duplicate types are checked seapartely, so give it a different supported
  /// type.
  @override
  Type get supportedType => GpcListBased;
}

/// Dummy class that has the same [supportedType] as [PersisterDummy], to check
/// that duplicate supported types are overwritten.
class PersisterDummyDupeSupportedType extends PersisterDummy {
  PersisterDummyDupeSupportedType() : super();

  /// Duplicate signatures are checked seapartely, so give it a different
  /// signature.
  @override
  SignatureAndVersion get signatureAndVersion {
    // Signature of all 'y' characters.
    final sig = String.fromCharCodes(
        List<int>.filled(SignatureAndVersion.RequiredSignatureLength, 121));
    return SignatureAndVersion(sig, 1);
  }
}

/// Class for testing purposes.
class GpcDummy extends GpcListBased {
  bool? _isReadonly;

  @override
  bool get isReadonly => _isReadonly ?? false;

  set isReadonly(bool value) {
    _isReadonly = value;
  }
}

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
      final persister = persistence.register(PersisterDummy());

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
      persistence.register(PersisterDummy());
      expect(
          () => persistence.register(PersisterDummyDupeSignature()),
          throwsA(isA<ConflictingPersisterException>()
              .having((e) => e.message, 'message', contains('signature'))));
    });

    test('Overwriting persisters', () {
      final persistence = PersistenceDummy.get();

      // Register the first persister supporting GpsDummy.
      persistence.register(PersisterDummy());

      // Register a second persister supporting GpsDummy. This shoud
      // overwite the previous persister for that type.
      final overwritingPersister =
          persistence.register(PersisterDummyDupeSupportedType());
      expect(
          identical(persistence.getPersister(GpcDummy()), overwritingPersister),
          true,
          reason: 'Dummy persister should have been overwritten returned.');
    });
  });
}

/// Tests [Persistence.write] and [Persistence.read].
void testReadWrite() {
  PersistenceDummy? persistence;
  PersisterDummy? persister;
  GpcDummy? gpc;
  TestStreamSink? sink;
  // Make sure all the variables below are reset in tearDown().
  var sigList = <int>[];
  var versionList = <int>[];
  var persisterSigList = <int>[];
  var persisterVersionList = <int>[];

  final getMetadata = () => persister?.metadataToWrite?.buffer.asUint8List();
  final setMetadata = (List<int>? data) {
    if (data == null) {
      persister!.metadataToWrite = null;
      return;
    }
    final bytedata = ByteData(data.length);
    for (var i = 0; i < data.length; i++) {
      bytedata.setUint8(i, data[i]);
    }
    persister!.metadataToWrite = bytedata;
  };

  final getHeader = () {
    // The metadata in the header requires some processing if it's null or
    // of shorter length than the maximum supported.

    // null gets translated to zero length.
    final metadataLength = getMetadata()?.length ?? 0;

    // Ensure correct length (right-pad with zeroes if necessary).
    var metadata =
        getMetadata() ?? List<int>.filled(persistence!.maxMetadataLength, 0);
    metadata = [
      ...metadata,
      ...List<int>.filled(
          max(0, persistence!.maxMetadataLength - metadata.length), 0)
    ];

    return [
      ...sigList,
      ...versionList,
      ...persisterSigList,
      ...persisterVersionList,
      ...[metadataLength],
      ...metadata
    ];
  };

  setUp(() {
    persistence = PersistenceDummy.get();
    persister = persistence!.register(PersisterDummy()) as PersisterDummy;

    gpc = GpcDummy();

    sink = TestStreamSink();

    sigList = 'AnqsGpsHistoryFile--'.codeUnits;
    versionList = [1, 0];
    persisterSigList = List<int>.filled(
        SignatureAndVersion.RequiredSignatureLength, 'x'.codeUnitAt(0));
    persisterVersionList = [13, 0];
    setMetadata(List<int>.filled(55, 0));
  });

  tearDown(() {
    persistence = null;
    gpc = null;

    sigList = <int>[];
    versionList = <int>[];
    persisterSigList = <int>[];
    persisterVersionList = <int>[];
    setMetadata(null);
  });

  group('Signature building', () {
    test('from type', () {
      final s = persister!.signatureFromType(GpcDummy);
      expect(
          s,
          'GpcDummy'
              .padRight(SignatureAndVersion.RequiredSignatureLength, '-'));
    });

    test('from string', () {
      final s = persister!.signatureFromString('x');
      expect(s, 'x'.padRight(SignatureAndVersion.RequiredSignatureLength, '-'));
    });

    test('too long', () {
      final charCodes = List<int>.filled(
          SignatureAndVersion.RequiredSignatureLength + 1, 100);
      expect(
          () => persister!.signatureFromString(String.fromCharCodes(charCodes)),
          throwsA(isA<InvalidSignatureException>()));
    });
  });

  group('Test writing', () {
    test('headers', () {
      persistence!.write(gpc!, sink!);

      expect(sink!.receivedData.length, 100, reason: 'incorrect data');
      expect(sink!.receivedData, getHeader());
    });

    test('custom metadata', () {
      setMetadata(List<int>.generate(20, (index) => 10 * (1 + index)));
      persistence!.write(gpc!, sink!);

      expect(sink!.receivedData.sublist(44, sink!.receivedData.length), [
        ...[20],
        ...List<int>.generate(55, (index) => index < 20 ? 10 * (1 + index) : 0)
      ]);
    });

    test('too much metadata', () {
      setMetadata(List<int>.filled(56, 0));
      expect(
          () => persistence!.write(gpc!, sink!),
          throwsA(isA<InvalidMetadataException>()
              .having((e) => e.message, 'message', contains('56'))));
    });

    test('some dummy points', () async {
      final point = GpsPoint(DateTime.utc(1970), 0, 0, 0);
      gpc!.add(point);
      gpc!.add(point);

      await persistence!.write(gpc!, sink!);

      expect(
          sink!.receivedData.sublist(100, sink!.receivedData.length), [1, 2]);
    });
  });

  group('Test reading', () {
    test('basic headers', () async {
      setMetadata(null);
      await persistence!.read(gpc!, Stream.value(getHeader()));

      expect(persister!.readViewVersion, 13,
          reason: 'incorrect persister version');

      expect(persister!.readViewMetadata!.lengthInBytes, 0,
          reason: 'incorrect metadata');
    });

    test('basic headers size hints', () async {
      final _testSizeHint = (int? sizeHint) async {
        setMetadata(null);
        // The size hint is just a hint, should not affect reading if wrong.
        await persistence!.read(gpc!, Stream.value(getHeader()), sizeHint);

        expect(persister!.readViewVersion, 13,
            reason: 'incorrect persister version');

        expect(persister!.readViewMetadata!.lengthInBytes, 0,
            reason: 'incorrect metadata');
      };

      // No size hint.
      await _testSizeHint(null);

      // Size hint that's too small.
      await _testSizeHint(2);

      // Size hint that's too high.
      await _testSizeHint(2000000000000);
    });

    test('metadata', () async {
      setMetadata(<int>[20, 21, 22]);
      await persistence!.read(gpc!, Stream.value(getHeader()));

      expect(persister!.readViewMetadata!.lengthInBytes, 3,
          reason: 'wrong amount of metadata read');
      for (var i = 0; i < 3; i++) {
        expect(persister!.readViewMetadata!.getUint8(i), i + 20,
            reason: 'wrong metadata at position $i');
      }
    });

    test('values', () async {
      await persistence!.read(
          gpc!,
          Stream.value([
            ...getHeader(),
            ...[0, 1, 2]
          ]));

      expect(gpc!.length, 3, reason: 'wrong number of items read');
    });

    test('invalid signature', () async {
      expect(() async => await persistence!.read(gpc!, Stream.value([10, 30])),
          throwsA(isA<InvalidSignatureException>()),
          reason: 'too short signature');

      final badSig = List<int>.filled(
          SignatureAndVersion.RequiredSignatureLength, '-'.codeUnitAt(0));
      expect(
          () async => await persistence!.read(gpc!, Stream.value(badSig)),
          throwsA(isA<InvalidSignatureException>().having((e) => e.message,
              'message', contains(String.fromCharCodes(badSig)))),
          reason: 'wrong signature');
    });

    test('version too new', () async {
      expect(
        () async => await persistence!.read(
            gpc!,
            Stream.value([
              ...sigList,
              ...[255, 255]
            ])),
        throwsA(isA<NewerVersionException>()),
      );
    });

    test('persister readonly', () async {
      gpc!.isReadonly = true;
      expect(() async => await persistence!.read(gpc!, Stream.value([])),
          throwsA(isA<ReadonlyContainerException>()));
    });

    test('persister not empty', () async {
      gpc!.add(GpsPoint(DateTime.utc(1970), 0.0, 0.0, 0.0));
      expect(() async => await persistence!.read(gpc!, Stream.value([])),
          throwsA(isA<NotEmptyContainerException>()));
    });

    test('persister signature wrong', () async {
      persisterSigList =
          List<int>.from(persisterSigList.map((value) => value + 1));
      final header = getHeader();
      expect(
        () async => await persistence!.read(gpc!, Stream.value(header)),
        throwsA(isA<InvalidSignatureException>().having((e) => e.message,
            'signature', contains(String.fromCharCodes(persisterSigList)))),
      );
    });

    test('persister version too new', () async {
      persisterVersionList = [255, 255];
      final header = getHeader();
      expect(
        () async => await persistence!.read(gpc!, Stream.value(header)),
        throwsA(isA<NewerVersionException>()
            .having((e) => e.message, 'found version', contains('65535'))),
      );
    });

    test('bad metadata', () async {
      // Try with a header that doesn't contain enough metadata.
      expect(
          () async => await persistence!.read(
              gpc!,
              Stream.value([
                ...sigList,
                ...versionList,
                ...persisterSigList,
                ...persisterVersionList,
                ...[1],
                ...[2, 3]
              ])),
          throwsA(isA<InvalidMetadataException>()));

      // Try with a header that claims to contain more metadata than is allowed.
      final invalidMetadataSize = persistence!.maxMetadataLength + 1;
      expect(
          () async => await persistence!.read(
              gpc!,
              Stream.value([
                ...sigList,
                ...versionList,
                ...persisterSigList,
                ...persisterVersionList,
                ...[invalidMetadataSize],
                ...List<int>.filled(persistence!.maxMetadataLength, 0)
              ])),
          throwsA(isA<InvalidMetadataException>()));
    });
  });
}

void main() {
  testPersistence();

  testReadWrite();
}
