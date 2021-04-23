/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_persist.dart';

/// Class for testing purposes, as the global [Persistence] class is a singleton
/// and we don't want to interfere with its state. This one is not a singleton.
class PersistenceDummy extends Persistence {
  factory PersistenceDummy.get() => PersistenceDummy._internal();

  /// Internal constructor for use in singleton behaviour.
  PersistenceDummy._internal();
}

/// Class for testing purposes.
class PersisterDummy extends Persister {
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
  group('Persister registration', () {
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

void main() {
  testPersistence();
}
