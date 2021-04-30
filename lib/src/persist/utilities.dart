/// Utilities for reading/writing GPS history data from/to streams.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'package:gps_history/gps_history.dart';

/// An exception raised if no persister is found for a particular object.
class NoPersisterException extends GpsHistoryException {
  NoPersisterException([String? message]) : super(message);
}

/// An exception raised if there is an attempt to register conflicting
/// persisters (e.g. multiple of them with the same signature).
class ConflictingPersisterException extends GpsHistoryException {
  ConflictingPersisterException([String? message]) : super(message);
}

/// An exception raised if trying to read data into a readonly object.
class ReadonlyContainerException extends GpsHistoryException {
  ReadonlyContainerException([String? message]) : super(message);
}

/// An exception raised if trying to set an invalid signature (e.g incorrect
/// length).
class InvalidSignatureException extends GpsHistoryException {
  InvalidSignatureException([String? message]) : super(message);
}

/// An exception raised if trying to read data from a stream written with a
/// newer version of the streaming method or of the persister.
class NewerVersionException extends GpsHistoryException {
  NewerVersionException([String? message]) : super(message);
}

/// An exception raised if trying to set an invalid metadata (e.g incorrect
/// length).
class InvalidMetadataException extends GpsHistoryException {
  InvalidMetadataException([String? message]) : super(message);
}

/// An exception raised if trying to read data into an object that's not empty.
class NotEmptyContainerException extends GpsHistoryException {
  NotEmptyContainerException([String? message]) : super(message);
}

/// Determines if [codeUnit] is between SPACE (ASCII 32) and ~ (ASCII 126).
bool isValidAsciiChar(int codeUnit) => 32 <= codeUnit && codeUnit <= 126;

/// Returns, if any, the index of the first non-ASCII character in the string.
/// If the string is either empty or all-ASCII, null is returned.
int? getFirstNonAsciiCharIndex(String string) {
  for (var i = 0; i < string.length; i++) {
    final c = string.codeUnitAt(i);
    if (!isValidAsciiChar(c)) {
      return i;
    }
  }
  return null;
}

/// Represents the signature and version data of [Persistence] and [Persister].
class SignatureAndVersion {
  /// Indicates the exact required length of signatures (in bytes/ASCII chars).
  static const RequiredSignatureLength = 20;

  /// The signature of the entity, must have a length of [RequiredSignatureLength].
  var _signature = getEmptySignature();

  /// The version of the entity.
  var version = 0;

  SignatureAndVersion(this._signature, this.version) {
    _checkValidSignature(_signature, RequiredSignatureLength);
  }

  /// Returns a valid, but empty (all-space) signature.
  static String getEmptySignature() =>
      String.fromCharCodes(List<int>.filled(RequiredSignatureLength, 32));

  /// Returns the currently configured signature.
  String get signature => _signature;

  /// Allow users of this class to override the default signature, as long
  /// as it's of correct length and contents.
  ///
  /// Throws [InvalidSignatureException] if the new signature is not good.
  set signature(String value) {
    _checkValidSignature(value, _signature.length);

    _signature = value;
  }

  /// Checks that the specified signature is valid, meaning valid ASCII subset
  /// only and of correct length. Throws [InvalidSignatureException] if that
  /// is not the case.
  void _checkValidSignature(String string, int requiredLength) {
    if (string.length != requiredLength) {
      throw InvalidSignatureException(
          'Specified signature "$string" has length of ${string.length}, '
          'but must be of length $requiredLength.');
    }

    final invalidCharIndex = getFirstNonAsciiCharIndex(string);
    if (invalidCharIndex != null) {
      throw InvalidSignatureException('Specified signature "$string" contains '
          'invalid character ${string.codeUnitAt(invalidCharIndex)} at position $invalidCharIndex.');
    }
  }
}

/// As the [Persistence] class is itself stateless, it uses the
/// [StreamReaderState] class to maintain and feed it with information from
/// a stream.
///
/// The [StreamReaderState] abstracts away the chunked reading and presents
/// to the outside world a continuous linear interface to the stream.
class StreamReaderState {
  final Stream<List<int>> _stream;

  /// The number of bytes read from the stream so far.
  int _bytesRead = 0;

  /// Used to calculate [remainingStreamBytesHint], see its documentation for
  /// purpose.
  final int? _streamSizeBytesHint;

  /// Keeps track of how many bytes have been read so far.
  int get bytesRead => _bytesRead;

  /// Returns the number of bytes of the stream that have not been read yet,
  /// if known. This is a hint only, and may thus be incorrect - it can only
  /// be used to pre-allocate memory in readers in order to hopefully reduce
  /// repeated re-allocations, not to determine if the stream is finished.
  /// If more bytes have already been read than the hint promised, the result
  /// is by definition invalid and null will be returned.
  int? get remainingStreamBytesHint {
    if (_streamSizeBytesHint == null) return null;
    final result = _streamSizeBytesHint! - bytesRead;
    return (result < 0) ? null : result;
  }

  /// Remembers whether the stream has finished providing data.
  var _streamFinished = false;

  /// Keep track of the lists that have come in from the stream. They're in
  /// order, so once the first list is processed, it can be discarded.
  final _cachedLists = DoubleLinkedQueue<List<int>>();
  StreamSubscription? _streamSubscription;
  var _positionInFrontList = 0;

  StreamReaderState(this._stream, [this._streamSizeBytesHint]);

  void _addToCacheAndPause(List<int> list) {
    // Make sure we get just one list at a time, so we cache as little as
    // possible in memory.
    if (!_streamFinished) {
      _streamSubscription!.pause();
    }
    _cachedLists.add(list);
  }

  /// Retrieves, if possible, the next list from the stream.
  Future<List<int>?> _cacheNextListFromStream() async {
    if (_streamFinished) {
      return null;
    }

    // Set up the strem subscription if we don't have it yet.
    _streamSubscription ??= _stream.listen(null)..pause();

    final completer = Completer<List<int>?>();

    // Replace the current subscription with a new one that works
    // asynchronously.
    _streamSubscription!
      ..onData((list) {
        _addToCacheAndPause(list);
        completer.complete(list);
      })
      ..onDone(() {
        _streamFinished = true;
        completer.complete(null);
      })
      ..onError((error) => completer.completeError(error));

    _streamSubscription!.resume();

    return completer.future;
  }

  /// Makes sure (by retrieving more data from the stream if necessary) that
  /// there are at least [nrBytesToRead] bytes present in the cache.
  Future<int> _ensureEnoughBytesInCache(int nrBytesToRead) async {
    var cachedBytes = 0;
    if (_cachedLists.isNotEmpty) {
      cachedBytes = _cachedLists.first.length - _positionInFrontList;
      for (var element in _cachedLists.skip(1)) {
        cachedBytes += element.length;
        if (cachedBytes >= nrBytesToRead) {
          break;
        }
      }
    }

    // If didn't have enough data -> try to read more from the stream until we
    // do have enough or the stream is finished.
    while (cachedBytes < nrBytesToRead && !_streamFinished) {
      final nextList = await _cacheNextListFromStream();
      if (nextList != null) {
        cachedBytes += nextList.length;
      } else {
        break;
      }
    }

    return cachedBytes;
  }

  /// Reads a list of bytes of [nrBytesToRead] bytes from the stream, if
  /// possible, or null otherwise (e.g. the stream doesn't contain
  /// [nrBytesToRead] bytes).
  Future<List<int>?> readBytes(int nrBytesToRead) async {
    // If we don't want to read anything, stop immediately.
    if (nrBytesToRead == 0) {
      return null;
    }

    // Try to get enough data in the cache.
    var cachedBytes = await _ensureEnoughBytesInCache(nrBytesToRead);

    // If we still don't have enough bytes, stop.
    if (cachedBytes < nrBytesToRead) {
      return null;
    }

    // Have enough bytes -> return them.
    final result = List<int>.filled(nrBytesToRead, 0);
    _bytesRead += nrBytesToRead;
    do {
      final firstList = _cachedLists.first;
      // Determine how many items we can take from the first list.
      final nrBytesFromFirstList =
          min(nrBytesToRead, firstList.length - _positionInFrontList);

      // Get those items to the result.
      final srcRange = firstList.getRange(
          _positionInFrontList, _positionInFrontList + nrBytesFromFirstList);
      // We need to start setting bytes to result after the ones we've already
      // set in previous loops.
      final targetPos = result.length - nrBytesToRead;
      result.setRange(targetPos, targetPos + nrBytesFromFirstList, srcRange);

      // Remove the first list if it's fully consumed.
      _positionInFrontList += nrBytesFromFirstList;
      if (_positionInFrontList == firstList.length) {
        _cachedLists.removeFirst();
        _positionInFrontList = 0;
      }

      // Calculate how many bytes we still need to read.
      nrBytesToRead -= nrBytesFromFirstList;

      // Continue until we've read all we needed to.
    } while (nrBytesToRead != 0);

    return result;
  }

  Future<ByteData> readByteData(int maxBytes) async {
    // Try to get enough data in the cache.
    final cachedBytes = await _ensureEnoughBytesInCache(maxBytes);
    final nrBytesToRead = min(maxBytes, cachedBytes);

    final bytes = await readBytes(nrBytesToRead);

    final result = ByteData(nrBytesToRead);
    if (bytes != null) {
      result.buffer.asUint8List().setRange(0, nrBytesToRead, bytes);
    }

    return result;
  }

  /// Like [readBytes], but reads a single [Uint8] and returns it as int.
  Future<int?> readUint8() async {
    final bytes = await readBytes(1);
    return (bytes != null) ? bytes[0] : null;
  }

  /// Like [readBytes], but reads a [Uint16] and returns it as int.
  Future<int?> readUint16() async {
    final bytes = await readBytes(2);
    if (bytes == null) {
      return null;
    }

    final bytesBuilder = BytesBuilder()..add(bytes);
    final byteData = ByteData.sublistView(bytesBuilder.takeBytes());
    return byteData.getUint16(0, Endian.little);
  }

  /// Like [readBytes], but returns an ASCII string.
  Future<String?> readString(int length) async {
    final bytes = await readBytes(length);

    if (bytes != null) {
      return String.fromCharCodes(bytes);
    } else {
      return null;
    }
  }
}

/// Utility class for writing various data types to a [Sink].
class StreamSinkWriter {
  /// The sink all data will be written to.
  final Sink<List<int>> _targetSink;

  int _bytesWritten = 0;

  /// Keeps track of how many bytes have been written so far.
  int get bytesWritten => _bytesWritten;

  StreamSinkWriter(this._targetSink);

  /// Writes the bytes in [data] to the sink.
  void writeBytes(List<int> data) {
    _targetSink.add(data);
    _bytesWritten += data.length;
  }

  /// Writes [number] as [Uint8] to the sink. If the number is outside valid
  /// [Uint8] range, it is capped at the appropriate boundary before writing.
  void writeUint8(int number) {
    // Trim the number at Uint8 boundaries.
    var n = max<int>(0, number.sign * min<int>(number.abs(), (1 << 8) - 1));

    // Write the trimmed number to the sink.
    writeBytes([n]);
  }

  /// Writes [number] as [Uint16] to the sink. If the number is outside valid
  /// [Uint16] range, it is capped at the appropriate boundary before writing.
  void writeUint16(int number) {
    // Trim the number at Uint16 boundaries.
    var n = max<int>(0, number.sign * min<int>(number.abs(), (1 << 16) - 1));

    // Write the trimmed number to the sink.
    final byteData = ByteData(2);
    byteData.setUint16(0, n, Endian.little);
    writeBytes(List<int>.generate(
        byteData.lengthInBytes, (index) => byteData.getUint8(index)));
  }

  /// Writes ASCII [string] to the sink, replacing any non-ASCII characters
  /// with whitespace.
  void writeString(String string) {
    final intAtIndex = (int index) {
      var c = string.codeUnitAt(index);
      if (isValidAsciiChar(c)) {
        return c;
      } else {
        return 32;
      }
    };

    writeBytes(List<int>.generate(string.length, intAtIndex));
  }
}
