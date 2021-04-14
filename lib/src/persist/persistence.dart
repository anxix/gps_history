/// Facilities for reading/writing GPS history data from/to streams.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:async';
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
    if (c < 32 && 126 < c) {
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
  var _signature =
      String.fromCharCodes(List<int>.filled(RequiredSignatureLength, 32));

  /// The version of the entity.
  var version = 0;

  SignatureAndVersion(this._signature, this.version) {
    if (_signature.length != RequiredSignatureLength) {
      throw InvalidSignatureException(
          'Specified signature "$_signature" has the wrong length: ${_signature.length}');
    }
  }

  /// Returns the currently configured signature.
  String getSignature() => _signature;

  /// Allow users of this class to override the default signature, as long
  /// as it's of correct length and contents.
  ///
  /// Throws [InvalidSignatureException] if the new signature is not good.
  void setSignature(String value) {
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

  /// Keeps track of how many bytes have been read so far.
  int _bytesRead = 0;

  /// Manages leftover data from previous stream chunks.
  final _leftoverCache = List<int>.empty(growable: true);

  StreamReaderState(this._stream);

  /// Reads a list of bytes of [length] bytes from the stream, if possible,
  /// or null otherwise (e.g. the stream doesn't contain [length] bytes).
  List<int>? readBytes(int length) {
    throw Exception('Not yet implemented!');
    _bytesRead += length;
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

  /// Keeps track of how many bytes have been written so far.
  int _bytesWritten = 0;

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

/// The Persistence abstract class can write and potentially read
/// [GpsPointsView] instances to [StreamSink] respectively from [Stream]
/// instances. Reading from streams requires the view to be modifiable, which
/// not all views are.
///
/// The class relies on [_Persister] subclasses, that are registered with it
/// as supporting particular subclasses of [GpsPointsView], to do the actual
/// streaming conversions. These [_Persister] instances must therefore be
/// registered by the users of this library at runtime before trying to
/// load/store data.
///
/// Throws a [NoPersisterException] if called upon to operate on a view type
/// for which no [_Persister] has been registered.
///
/// The persisted format is structured as follows:
/// * 100 bytes: Header, consisting of:
///   * 20 bytes: signature to recognize that this is indeed a file stored
///     by the library. Default value may be overridden.
///   * 2 bytes: [Uint16] indicating the version number of the streaming method.
///     This is independent of the versioning of the persisted data.
///     [Persistence] will not read files that have a streaming method version
///     newer than its own, thus ensuring that older versions don't crash
///     or read incorrectly files that are written in a newer format.
///   * 20 bytes: [_Persister] signature header to recognize data type.
///     Each registered [_Persister] instance must have a unique signature.
///     This will be validated at reading time against the [_Persister]
///     registered for the data currently being read.
///   * 2 bytes: [Uint16] indicating the version number of the persisted data,
///     so that upgrades in format are possible and recognizable without
///     changing the header. [Persistence] will not read files that have a
///     persisted data version newer than the one supported by the relevant
///     registered [_Persister]. Again, this ensures old versions don't try
///     to read new data and do so badly.
///   * 56 bytes: reserved for any kind of meta information a particular
///     [_Persister] may require.
/// * unknown number of bytes: the streamed data.
/// By having a fixed header size, we can determine numbers of points in a file
/// without fully parsing it, by simply looking at the total file size minus
/// the header and dividing the outcome by the storage size per point.
abstract class Persistence {
  /// The signature and version at the start of the file.
  /// The version indicates the version of the streaming mechanism used by the
  /// current implementation of [Persistence].
  /// Only increase the version if the streaming method (not the contents!) is
  /// changed such that earlier versions cannot possibly support it. An example
  /// would be if the persistence starts compressing all streams.
  static final _signatureAndVersion =
      SignatureAndVersion('AnqsGpsHistoryFile--', 1);

  static const _knownPersisters = <Type, _Persister>{};

  static _Persister _getPersister(GpsPointsView view) {
    final result = _knownPersisters[view.runtimeType];
    if (result == null) {
      throw NoPersisterException(
          'No persister found for type ${view.runtimeType.toString()}');
    } else {
      return result;
    }
  }

  static void _registerPersister(Type viewType, _Persister persister) {
    _knownPersisters[viewType] = persister;
  }

  /// Reads a signature from [state], validates it against the
  /// [expectedSignature] and throws [InvalidSignatureError] if they don't
  /// match.
  static Future<void> _readValidateSignature(
      StreamReaderState state, String expectedSignature) async {
    final loadedSignature = state.readString(expectedSignature.length);
    if (loadedSignature != _signatureAndVersion.getSignature()) {
      throw InvalidSignatureException(
          'Stream contains no or invalid signature \'${loadedSignature ?? ""}\', '
          'while "$expectedSignature" was expected.');
    }
  }

  /// Reads a version number for [objectName] from [state], validates it
  /// against the [maximumCompatibleVersion] and throws [NewerVersionException]
  /// if the read version is newer and hence incompatible.
  static Future<int> _readValidateVersion(StreamReaderState state,
      int maximumCompatibleVersion, String objectName) async {
    final loadedVersion = state.readUint16();
    if ((loadedVersion ?? 1 << 31) > maximumCompatibleVersion) {
      throw NewerVersionException(
          'Found $objectName stored with version "$loadedVersion", '
          'which is newer than supported version "($maximumCompatibleVersion)".');
    }
    return Future.value(loadedVersion);
  }

  /// Overwrites the contents of [view] with data read from [sourceStream].
  ///
  /// Throws [ReadonlyException] if [view.isReadonly]==```true```, as the
  /// contents of a readonly view cannot be overwritten.
  /// Throws [InvalidSignatureError] if the stream contains an invalid
  /// signature at either [Persistance] level or [_Persister] level.
  /// Throws [NewerVersionError] if the stream contains a newer version at
  /// either [Persistance] level or [_Persister] level.
  static void read(GpsPointsView view, Stream<List<int>> sourceStream) async {
    if (view.isReadonly) {
      throw ReadonlyException();
    }

    final state = StreamReaderState(sourceStream);

    // Read the header signature and stop if it's unrecognized.
    await _readValidateSignature(state, _signatureAndVersion.getSignature());

    // Read the streaming method version and stop if it's newer than what
    // we support internally.
    await _readValidateVersion(state, _signatureAndVersion.version, 'stream');

    final persister = _getPersister(view);

    // Read the persister signature and validate against the persister that's
    // supposed to read the specified view.
    await _readValidateSignature(
        state, persister.signatureAndVersion.getSignature());

    // Read the persister version number and meta information and stop if it's
    // newer than what the persister writes natively.
    final loadedPersisterVersion = await _readValidateVersion(
        state,
        persister.signatureAndVersion.version,
        'persister ${persister.runtimeType.toString()}');

    // Have the persister read and interpret the actual data.
  }

  /// Writes [view] to [targetSink] in binary format.
  static void write(GpsPointsView view, StreamSink<List<int>> targetSink) {
    final persister = _getPersister(view);

    final sink = StreamSinkWriter(targetSink);

    // Write the signature and version of [Persistance]
    sink.writeString(_signatureAndVersion.getSignature());
    sink.writeUint16(_signatureAndVersion.version);

    // Write the signature and version of [_Persister];
    sink.writeString(persister.signatureAndVersion.getSignature());
    sink.writeUint16(persister.signatureAndVersion.version);

    throw Exception('Implement the streaming of the view!');
    targetSink.addStream(persister._writeStreamFromView(view));
  }
}

/// Children of [_Persister] implement the actual reading and writing of
/// particular types of [GpsPointsView] descendants.
abstract class _Persister {
  final signatureAndVersion = SignatureAndVersion(getSignature(), getVersion());

  /// Indicates what object type this [_Persister] can persist, to be overridden
  /// in child classes.
  static Type? getSupportedType() {
    return null;
  }

  _Persister() {
    Persistence._registerPersister(getSupportedType()!, this);
  }

  /// Indicates the version of the persistence method. Should be increased
  /// if for example new fields get persisted. In that case, the reader must
  /// contain compatibility code for reading older versions. Child classes
  /// should override as needed.
  static int getVersion() {
    return 1;
  }

  /// Returns the signature string for this [_Persister]. Method to be
  /// overridden in subclasses.
  static String getSignature() {
    if (getSupportedType() == null) {
      throw GpsHistoryException(
          'No supported type found for a specific persister!');
    }

    var sig = getSupportedType().toString();
    // Ensure the sig is not too short...
    sig = sig.padRight(SignatureAndVersion.RequiredSignatureLength, '-');
    // ...nor too long.
    sig = sig.substring(0, SignatureAndVersion.RequiredSignatureLength);

    return sig;
  }

  /// Converts [view] to a [Stream] of bytes. Override in children.
  Stream<List<int>> _writeStreamFromView(GpsPointsView view);

  /// Overwrites the contents of [view] (if it is not read-only) with
  /// the information fom the [sourceStream].
  void _readViewFromStream(GpsPointsView view, Stream<List<int>> sourceStream,
      String metaInformation, int version);
}
