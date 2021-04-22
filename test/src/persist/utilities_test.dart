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

Future<void> _runReaderTest<T>(
    List<List<int>> bytes,
    List<T?> expecteds,
    Future<T?> Function(StreamReaderState state, T? expected)
        readFunction) async {
  var sr = StreamReaderState(Stream<List<int>>.fromIterable(bytes));
  var valueNr = 0;
  for (var expected in expecteds) {
    var value = await readFunction(sr, expected);
    expect(value, expected, reason: 'at position $valueNr');
    valueNr += 1;
  }
}

Future<void> _runReaderTestUint16(
    List<List<int>> bytes, List<int?> expecteds) async {
  return _runReaderTest<int>(
      bytes, expecteds, (state, expected) => state.readUint16());
}

Future<void> _runReaderTestString(
    List<List<int>> bytes, List<String?> expecteds) async {
  return _runReaderTest<String>(
      bytes,
      expecteds,
      (state, expected) =>
          state.readString((expected == null) ? 0 : expected.length));
}

/// Tests for all possible ways of grouping the values in [srcList] whether
/// they return the same [expecteds] when calling [_runtTest].
Future<void> _testAllGroups<T>(List<int> srcList, List<T?> expecteds,
    Future<T?> Function(StreamReaderState state, T? expected) readFunction,
    [List<List<int>>? testList]) async {
  testList ??= List<List<int>>.empty(growable: true);

  if (srcList.isEmpty) {
    await _runReaderTest(testList, expecteds, readFunction);
    return;
  }

  for (var i = 1; i <= srcList.length; i++) {
    final testListCopy = List<List<int>>.from(testList, growable: true);
    testListCopy.add(List<int>.from(srcList.take(i)));
    final subList = srcList.sublist(i);
    await _testAllGroups(subList, expecteds, readFunction, testListCopy);
  }
}

/// Test the behaviours of the StreamReaderState object.
void testStreamReaderState() {
  final listOfList = (List<int> list) {
    return List<List<int>>.filled(1, list);
  };

  group('readUint16', () {
    test('valid single value', () async {
      await _runReaderTestUint16(listOfList([0, 0]), [0]);
      await _runReaderTestUint16(listOfList([1, 0]), [1]);
      await _runReaderTestUint16(listOfList([0, 1]), [256]);
      await _runReaderTestUint16(listOfList([255, 255]), [65535]);
    });

    test('insufficient data', () async {
      await _runReaderTestUint16([[]], [null]);
      await _runReaderTestUint16(listOfList([0]), [null]);
      await _runReaderTestUint16(listOfList([1, 0, 2]), [1, null]);
    });

    test('valid multiple values', () async {
      await _runReaderTestUint16(listOfList([0, 0, 1, 0]), [0, 1]);
      await _runReaderTestUint16(listOfList([0, 1, 1, 0]), [256, 1]);
      await _runReaderTestUint16(listOfList([255, 255, 0, 0]), [65535, 0]);
      await _runReaderTestUint16(listOfList([0, 0, 255, 255]), [0, 65535]);
      await _runReaderTestUint16(
          listOfList([1, 2, 3, 4, 5, 8]), [513, 1027, 2053]);
    });

    test('various streaming conditions', () async {
      var bytes = [1, 2];
      await _testAllGroups<int>(
          bytes, [513], (state, expected) => state.readUint16());

      bytes = [0, 0, 1, 0];
      await _testAllGroups<int>(
          bytes, [0, 1], (state, expected) => state.readUint16());

      bytes = [1, 2, 3, 4, 5, 8];
      await _testAllGroups<int>(
          bytes, [513, 1027, 2053], (state, expected) => state.readUint16());
    });
  });

  group('readString', () {
    test('valid single string', () async {
      await _runReaderTestString(listOfList([97, 98, 99]), ['abc']);
    });

    test('empty data', () async {
      await _runReaderTestString(listOfList([]), [null]);
    });

    test('multiple strings', () async {
      await _runReaderTestString(listOfList([90, 97, 98, 99]), ['Z', 'abc']);
      await _testAllGroups<String>(
          [89, 90, 100, 97, 98, 99],
          ['YZ', 'd', 'abc'],
          (state, expected) =>
              state.readString((expected == null) ? 0 : expected.length));
    });
  });
}

void main() {
  testGetFirstNonAsciiCharIndex();

  testSignatureAndVersion();

  testStreamReaderState();
}
