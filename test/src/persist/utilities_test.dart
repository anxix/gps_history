/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history_persist.dart';

import 'persist_test_helpers.dart';

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

/// Runs a test on the specified lists of [bytes] and checks that calling
/// [readFunction] returns the correct [expecteds].
Future<void> _runReaderTest<T>(
    List<List<int>> bytes,
    List<T?> expecteds,
    Future<T?> Function(StreamReaderState state, T? expected)
        readFunction) async {
  final sr = StreamReaderState(Stream<List<int>>.fromIterable(bytes));
  var valueNr = 0;
  for (var expected in expecteds) {
    var value = await readFunction(sr, expected);
    expect(value, expected, reason: 'at position $valueNr');
    valueNr += 1;
  }
}

/// Wrapper for [_runReaderTest] specialized in Uint8.
Future<void> _runReaderTestUint8(
    List<List<int>> bytes, List<int?> expecteds) async {
  return _runReaderTest<int>(
      bytes, expecteds, (state, expected) => state.readUint8());
}

/// Wrapper for [_runReaderTest] specialized in Uint16.
Future<void> _runReaderTestUint16(
    List<List<int>> bytes, List<int?> expecteds) async {
  return _runReaderTest<int>(
      bytes, expecteds, (state, expected) => state.readUint16());
}

/// Wrapper for [_runReaderTest] specialized in String.
Future<void> _runReaderTestString(
    List<List<int>> bytes, List<String?> expecteds) async {
  return _runReaderTest<String>(
      bytes,
      expecteds,
      (state, expected) =>
          state.readString((expected == null) ? 0 : expected.length));
}

/// Wrapper for [_runReaderTest] specialized in bytes.
Future<void> _runReaderTestBytes(
    List<List<int>> bytes, List<List<int>?> expecteds) async {
  return _runReaderTest<List<int>?>(
      bytes,
      expecteds,
      (state, expected) =>
          state.readBytes((expected == null) ? 0 : expected.length));
}

/// Tests for all possible ways of grouping the values in [srcList] whether
/// they return the same [expecteds] when calling the specified
/// [readerTestRunner]. This function recurses for purposes of generating
/// all the groupings, using the [testList] argument to pass around information
/// during the recursion.
Future<void> _testAllGroups<T>(
    List<int> srcList,
    List<T?> expecteds,
    Future<void> Function(List<List<int>> bytes, List<T?> expecteds)
        readerTestRunner,
    [List<List<int>>? testList]) async {
  testList ??= List<List<int>>.empty(growable: true);

  if (srcList.isEmpty) {
    await readerTestRunner(testList, expecteds);
    return;
  }

  for (var i = 1; i <= srcList.length; i++) {
    final testListCopy = List<List<int>>.from(testList, growable: true);
    testListCopy.add(List<int>.from(srcList.take(i)));
    final subList = srcList.sublist(i);
    await _testAllGroups(subList, expecteds, readerTestRunner, testListCopy);
  }
}

/// Test the behaviours of the StreamReaderState object.
void testStreamReaderState() {
  final listOfList = (List<int> list) {
    return List<List<int>>.filled(1, list);
  };

  group('readUint8', () {
    test('valid single value', () async {
      await _runReaderTestUint8(listOfList([0]), [0]);
      await _runReaderTestUint8(listOfList([128]), [128]);
      await _runReaderTestUint8(listOfList([255]), [255]);
    });

    test('valid multiple values', () async {
      await _runReaderTestUint8(listOfList([1, 2, 3]), [1, 2, 3]);
    });

    test('various streaming conditions', () async {
      final bytes = [1, 2, 123, 224];
      await _testAllGroups<int>(bytes, bytes, _runReaderTestUint8);
    });
  });

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
      await _testAllGroups<int>(bytes, [513], _runReaderTestUint16);

      bytes = [0, 0, 1, 0];
      await _testAllGroups<int>(bytes, [0, 1], _runReaderTestUint16);

      bytes = [1, 2, 3, 4, 5, 8];
      await _testAllGroups<int>(bytes, [513, 1027, 2053], _runReaderTestUint16);
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
          [89, 90, 100, 97, 98, 99], ['YZ', 'd', 'abc'], _runReaderTestString);
    });
  });

  group('readBytes', () {
    test('valid single bytes list', () async {
      await _runReaderTestBytes(
          listOfList([10, 11, 12]), listOfList([10, 11, 12]));
    });

    test('empty data', () async {
      await _runReaderTestBytes(listOfList([]), [null]);
    });

    test('multiple bytes lists', () async {
      await _runReaderTestBytes(listOfList([90, 97, 98, 99]), [
        [90],
        [97, 98, 99]
      ]);
      await _testAllGroups<List<int>?>([
        89,
        90,
        100,
        97,
        98,
        99
      ], [
        [89, 90],
        [100],
        [97, 98, 99]
      ], _runReaderTestBytes);
    });
  });

  group('bytesRead', () {
    test('simple', () async {
      final sr = StreamReaderState(Stream<List<int>>.value([1, 2, 3, 4]));

      expect(sr.bytesRead, 0, reason: 'start out with zero bytes read');

      await sr.readUint16();
      expect(sr.bytesRead, 2, reason: 'should have read 16 bits');

      await sr.readUint16();
      expect(sr.bytesRead, 4, reason: 'should have read 16 bits again');

      final value = await sr.readUint16();
      expect(value, null, reason: 'stream should be finished');
      expect(sr.bytesRead, 4, reason: 'should not read beyond stream end');
    });

    group('remainingStreamBytesHint', () {
      test('no hint', () async {
        final sr =
            StreamReaderState(Stream<List<int>>.value([1, 2, 3, 4]), null);

        expect(sr.remainingStreamBytesHint, null,
            reason: 'unspecified stream bytes');

        await sr.readUint16();
        expect(sr.remainingStreamBytesHint, null,
            reason: 'unspecified stream bytes');
      });

      test('too small hint', () async {
        final sr = StreamReaderState(Stream<List<int>>.value([1, 2, 3, 4]), 1);

        expect(sr.remainingStreamBytesHint, 1,
            reason: 'specified stream bytes');

        await sr.readUint16();
        expect(sr.remainingStreamBytesHint, -1,
            reason: 'already read more bytes than the hint claimed');
      });

      test('too large hint', () async {
        final sr =
            StreamReaderState(Stream<List<int>>.value([1, 2, 3, 4]), 100);

        expect(sr.remainingStreamBytesHint, 100,
            reason: 'specified stream bytes');

        await sr.readUint16();
        expect(sr.remainingStreamBytesHint, 98);
      });
    });

    test('chunked plus leftover bytes', () async {
      // Ensure the counter works properly over chunk boundaries.
      final bytes = Stream<List<int>>.fromIterable([
        [1],
        [2, 3],
        [4, 5, 6, 7],
      ]);
      final sr = StreamReaderState(bytes);

      await sr.readUint16();
      await sr.readUint16();
      await sr.readUint16();
      expect(sr.bytesRead, 6, reason: 'should have read 3x16 bits');

      final value = await sr.readUint16();
      expect(value, null,
          reason: 'there should be insufficient bytes in stream');
      expect(sr.bytesRead, 6,
          reason: 'should not be able to read 16 bits anymore');
    });
  });
}

/// Writes [dataList] to a sink using [writeFunction] and checks that the sink
/// contents afterwards match [expected].
void _runWriterTest<T>(List<T> dataList, List<int> expected,
    void Function(StreamSinkWriter writer, T data) writeFunction) {
  final sink = TestSink();
  final writer = StreamSinkWriter(sink);
  for (var data in dataList) {
    writeFunction(writer, data);
  }

  expect(sink.receivedData, expected);

  expect(writer.bytesWritten, expected.length);
}

/// Wrapper for [_runWriterTest] specialized in Uint8.
void _runWriterTestUint8(List<int> dataList, List<int> expected) {
  return _runWriterTest<int>(
      dataList, expected, (writer, data) => writer.writeUint8(data));
}

/// Wrapper for [_runWriterTest] specialized in Uint16.
void _runWriterTestUint16(List<int> dataList, List<int> expected) {
  return _runWriterTest<int>(
      dataList, expected, (writer, data) => writer.writeUint16(data));
}

/// Wrapper for [_runWriterTest] specialized in String.
void _runWriterTestString(List<String> dataList, List<int> expected) {
  return _runWriterTest<String>(
      dataList, expected, (writer, data) => writer.writeString(data));
}

/// Wrapper for [_runWriterTest] specialized in bytes.
void _runWriterTestBytes(List<List<int>> dataList, List<int> expected) {
  return _runWriterTest<List<int>>(
      dataList, expected, (writer, data) => writer.writeBytes(data));
}

void testStreamSinkWriter() {
  group('writeUint8', () {
    test('simple', () {
      _runWriterTestUint8([], []);

      _runWriterTestUint8([0], [0]);
      _runWriterTestUint8([1], [1]);
      _runWriterTestUint8([255], [255]);
    });

    test('value capping', () {
      _runWriterTestUint8([-1], [0]);
      _runWriterTestUint8([256], [255]);
    });
  });

  group('writeUint16', () {
    test('simple', () {
      _runWriterTestUint16([], []);

      _runWriterTestUint16([0], [0, 0]);
      _runWriterTestUint16([1], [1, 0]);
      _runWriterTestUint16([65535], [255, 255]);
    });

    test('value capping', () {
      _runWriterTestUint16([-1], [0, 0]);
      _runWriterTestUint16([65536], [255, 255]);
    });
  });

  group('writeString', () {
    test('simple', () {
      _runWriterTestString(['a', 'bc'], [97, 98, 99]);
    });

    test('invalid ASCII character replacement', () {
      _runWriterTestString(['A\nB\rC'], [65, 32, 66, 32, 67]);
    });
  });

  group('writeBytes', () {
    test('simple', () {
      _runWriterTestBytes([], []);

      _runWriterTestBytes([
        [1, 2]
      ], [
        1,
        2
      ]);

      _runWriterTestBytes([
        [1, 2],
        [3],
        [4, 5]
      ], [
        1,
        2,
        3,
        4,
        5
      ]);
    });
  });
}

void main() {
  testGetFirstNonAsciiCharIndex();

  testSignatureAndVersion();

  testStreamReaderState();

  testStreamSinkWriter();
}
