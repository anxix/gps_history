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

/// An exception raised if trying to read data into a readonly object.
class ReadonlyException extends GpsHistoryException {
  ReadonlyException([String? message]) : super(message);
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

/// Returns, if any, the index of the first non-ASCII character in the string.
/// If the string is either empty or all-ASCII, null is returned.
int? getFirstNonAsciiCharIndex(String string) {
  for (var i = 0; i < string.length; i++) {
    final c = string.codeUnitAt(i);
    // Accept characters between SPACE (ASCII 32) and ~ (ASCII 126).
    if (c < 32 || 126 < c) {
      return i;
    }
  }
  return null;
}

/// Represents the signature and version data of [Persistence] and [_Persister].
class SignatureAndVersion {
  /// Indicates the exact required length of signatures (in bytes/ASCII chars).
  static const RequiredSignatureLength = 20;

  /// The signature of the entity, must have a length of [RequiredSignatureLength].
  var _signature = getEmptySignature();

  /// The version of the entity.
  var version = 0;

  SignatureAndVersion(this._signature, this.version) {
    _checkValidSignature(this._signature, RequiredSignatureLength);
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
  void set signature(String value) {
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

  int _bytesRead = 0;

  /// Keeps track of how many bytes have been read so far.
  int get bytesRead => _bytesRead;

  /// Remembers whether the stream has finished providing data.
  var _streamFinished = false;

  /// Keep track of the lists that have come in from the stream. They're in
  /// order, so once the first list is processed, it can be discarded.
  final _streamedLists = DoubleLinkedQueue<List<int>>();
  StreamSubscription? _streamSubscription;
  var _positionInFrontList = 0;

  StreamReaderState(this._stream) {
    _streamSubscription = _stream.listen((event) {
      _addAndPause(event);
    }, onDone: () {
      _streamFinished = true;
    })
      ..pause();
  }

  void _addAndPause(List<int> list) {
    // Make sure we get just one list at a time, so we cache as little as
    // possible in memory.
    _streamedLists.add(list);
    if (!_streamFinished) {
      _streamSubscription!.pause();
    }
  }

  /// Reads a list of bytes of [nrBytesToRead] bytes from the stream, if possible,
  /// or null otherwise (e.g. the stream doesn't contain [nrBytesToRead] bytes).
  List<int>? readBytes(int nrBytesToRead) {
    // See if we have enough data.
    var foundBytes = 0;
    if (_streamedLists.isNotEmpty) {
      foundBytes = _streamedLists.first.length - _positionInFrontList;
      for (var element in _streamedLists.skip(1)) {
        foundBytes += element.length;
        if (foundBytes >= nrBytesToRead) {
          break;
        }
      }
    }

    // Didn't have enough data -> try to read more from the stream until we
    // do have enough or the stream is finished..
    while (foundBytes < nrBytesToRead && !_streamFinished) {
      _streamSubscription!.resume();
      foundBytes += _streamedLists.last.length;
    }

    // If we still don't have enough bytes, stop.
    if (foundBytes < nrBytesToRead) {
      return null;
    }

    // Have enough bytes -> return them.
    final result = List<int>.filled(nrBytesToRead, 0);
    _bytesRead += nrBytesToRead;
    do {
      final firstList = _streamedLists.first;
      // Determine how many items we can take from the first list.
      final nrItemsFromFirstList =
          min(nrBytesToRead, firstList.length - _positionInFrontList);

      // Get those items to the result.
      final srcRange = firstList.getRange(
          _positionInFrontList, _positionInFrontList + nrItemsFromFirstList);
      result.setRange(0, nrItemsFromFirstList, srcRange);

      // Remove the first list if it's fully consumed.
      _positionInFrontList += nrItemsFromFirstList;
      if (_positionInFrontList == firstList.length) {
        _streamedLists.removeFirst();
        _positionInFrontList = 0;
      }

      // Calculate how many bytes we still need to read.
      nrBytesToRead -= nrItemsFromFirstList;

      // Continue until we've read all we needed to.
    } while (nrBytesToRead == 0);

    return result;
  }

  /// Like [readBytes], but returns an ASCII string.
  String? readString(int length) {
    final bytes = readBytes(length);

    if (bytes != null) {
      return String.fromCharCodes(bytes);
    } else {
      return null;
    }
  }

  /// Like [readBytes], but reads a [Uint16] and returns it as int.
  int? readUint16() {
    final bytes = readBytes(2);
    if (bytes == null) {
      return null;
    }

    final bytesBuilder = BytesBuilder()..add(bytes);
    final byteData = ByteData.sublistView(bytesBuilder.takeBytes());
    return byteData.getInt16(0, Endian.little);
  }
}

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

  /// Writes ASCII [string] to the sink, replacing any non-ASCII characters
  /// with whitespace.
  void writeString(String string) {
    writeBytes(List<int>.generate(string.length, (index) {
      var cu = string.codeUnitAt(index);
      if (cu < 32 || 126 < cu) {
        cu = 32;
      }
      return cu;
    }));
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
}
