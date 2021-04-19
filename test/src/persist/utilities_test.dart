/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history_persist.dart';

/// Tests the [getFirstNonAsciiCharIndex] function.
void testGetFirstNonAsciiCharIndex() {
  test('getFirstNonAsciiCharIndex', () {
    // Test all invalid char codes before the space.
    for (var charChode = 0; charChode < 32; charChode++) {
      final s = String.fromCharCode(charChode);
      expect(getFirstNonAsciiCharIndex(s), 0,
          reason: 'Incorrect result for charCode=$charChode');
    }

    // Test some invalid char codes after ~.
    for (var charChode = 127; charChode < 1000; charChode++) {
      var s = String.fromCharCode(charChode);
      expect(getFirstNonAsciiCharIndex(s), 0,
          reason: 'Incorrect result for charCode=$charChode');
    }

    // Test valid char codes.
    for (var charChode = 32; charChode <= 126; charChode++) {
      final s = String.fromCharCode(charChode);
      expect(getFirstNonAsciiCharIndex(s), null,
          reason: 'Incorrect result for charCode=$charChode');
    }

    // Test multi-char strings.
    expect(getFirstNonAsciiCharIndex('string'), null,
        reason: 'String with all-valid chars');
    expect(getFirstNonAsciiCharIndex('str\ning'), 3,
        reason: 'String with one invalid char');
  });
}

/// Tests the [SignatureAndVersion] class.
void testSignatureAndVersion() {
  test('Test version', () {
    final v = SignatureAndVersion(SignatureAndVersion.getEmptySignature(), 5);
    expect(v.version, 5);

    v.version = 19;
    expect(v.version, 19);
  });

  group('Invalid signature:', () {
    test('too short', () {
      final sig = SignatureAndVersion.getEmptySignature().substring(1);
      expect(
          () => SignatureAndVersion(sig, 1),
          throwsA(isA<InvalidSignatureException>()
              .having((e) => e.message, 'message', contains('19'))
              .having((e) => e.message, 'message', contains('length'))));
    });

    test('too long', () {
      final sig = SignatureAndVersion.getEmptySignature() + ' ';
      expect(
          () => SignatureAndVersion(sig, 1),
          throwsA(isA<InvalidSignatureException>()
              .having((e) => e.message, 'message', contains('21'))
              .having((e) => e.message, 'message', contains('length'))));
    });

    test('invalid characters', () {
      final sig = SignatureAndVersion.getEmptySignature().substring(1) + '\n';
      expect(
          () => SignatureAndVersion(sig, 1),
          throwsA(isA<InvalidSignatureException>()
              .having((e) => e.message, 'message', contains('19'))
              .having(
                  (e) => e.message, 'message', contains('invalid character'))));
    });

    test('modify', () {
      final signatureAndVersion =
          SignatureAndVersion(SignatureAndVersion.getEmptySignature(), 1);
      expect(
          () => signatureAndVersion.signature = 'x',
          throwsA(isA<InvalidSignatureException>()
              .having((e) => e.message, 'message', contains('1'))
              .having((e) => e.message, 'message', contains('length'))));
    });
  });

  group('Valid signature:', () {
    test('modify', () {
      var sig = SignatureAndVersion.getEmptySignature();
      final signatureAndVersion = SignatureAndVersion(sig, 1);

      sig = 'x' + sig.substring(1);
      signatureAndVersion.signature = sig;
      expect(signatureAndVersion.signature, sig);
    });
  });
}

void main() {
  testGetFirstNonAsciiCharIndex();

  testSignatureAndVersion();
}
