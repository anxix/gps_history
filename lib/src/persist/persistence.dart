import 'dart:async';

import 'package:gps_history/src/base.dart';

/// Abstract interface io implementation just so that the package can be
/// used in environments that don't have io.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

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
/// newer streaming method version.
class NewerStreamingMethodError extends GpsHistoryException {
  NewerStreamingMethodError([String? message]) : super(message);
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

  // Reads an ASCII string of [length] bytes from the stream, if possible,
  // or null otherwise (e.g. the stream doesn't contain [length] bytes).
  Future<String?> readString(int length) {
    throw Exception('Not implemented!');

    _bytesRead += length;
  }

  // Like [readString], but reads a [Uint16] and returns it as int.
  Future<int?> readUint16() {
    throw Exception('Not implemented!');

    _bytesRead += 2;
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
  /// Indicates the version of the streaming mechanism used by the current
  /// implementation of [Persistence].
  /// Only increase if the streaming method (not the contents!) is changed such
  /// that earlier versions cannot possibly support it. An example would be if
  /// the persistence starts compressing all streams.
  static const _streamingMethodVersion = 1;

  /// The signature at the start of the file. Must have a length of 20.
  static var _signature = 'AnqsGpsHistoryFile--';

  /// Returns the currently configured signature.
  static String getSignature() => _signature;

  /// Allow users of this class to override the default signature, as long
  /// as it's of correct length.
  ///
  /// Throws [InvalidSignatureException] if the new signature is not good.
  static void setSignature(String value) {
    _checkValidSignature(value, _signature.length);

    _signature = value;
  }

  /// Checks that the specified signature is valid, meaning valid ASCII subset
  /// only and of correct length. Throws [InvalidSignatureException] if that
  /// is not the case.
  static void _checkValidSignature(String value, int requiredLength) {
    if (value.length != requiredLength) {
      throw InvalidSignatureException(
          'Specified signature "$value" has length of ${value.length}, '
          'but must be of length $requiredLength.');
    }

    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      // Accept characters between SPACE (ASCII 32) and ~ (ASCII 126).
      if (c < 32 && 126 < c) {
        throw InvalidSignatureException('Specified signature "$value" contains '
            'invalid character $c at position $i.');
      }
    }
  }

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

  /// Overwrites the contents of [view] with data read from [sourceStream].
  ///
  /// Throws [ReadonlyException] if [view.isReadonly]==```true```, as the
  /// contents of a readonly view cannot be overwritten.
  /// Throws [InvalidSignatureError] if the stream contains an invalid
  /// signature at either [Persistance] level or [_Persister] level.
  static void read(GpsPointsView view, Stream<List<int>> sourceStream) async {
    if (view.isReadonly) {
      throw ReadonlyException();
    }

    final persister = _getPersister(view);

    final state = StreamReaderState(sourceStream);

    // Read the header signature and stop if it's unrecognized.
    var loadedSignature = await state.readString(getSignature().length);
    if (loadedSignature != getSignature()) {
      throw InvalidSignatureException(
          'Stream contains no or invalid signature \'${loadedSignature ?? ""}\', '
          'while ${getSignature()} was expected.');
    }

    // Read the streaming method version and stop if it's newer than what
    // we support internally.
    var loadedVersion = await state.readUint16();
    if ((loadedVersion ?? 1 << 31) > _streamingMethodVersion) {
      throw NewerStreamingMethodError(
          'Stream is stored with method version "$loadedVersion", '
          'which is newer than supported version "($_streamingMethodVersion)".');
    }

    // Read the persister signature and validate against the persister that's
    // supposed to read the specified view.

    // Read the persister version number and meta information and stop if it's
    // newer than what the persister writes natively.

    // Have the persister read and interpret the actual data.
  }

  /// Writes [view] to [targetSink] in binary format.
  static void write(GpsPointsView view, StreamSink<List<int>> targetSink) {
    final persister = _getPersister(view);
    targetSink.addStream(persister._writeStreamFromView(view));
  }
}

/// Children of [_Persister] implement the actual reading and writing of
/// particular types of [GpsPointsView] descendants.
abstract class _Persister {
  /// Indicates the version of the persistence method. Should be increased
  /// if for example new fields get persisted. In that case, the reader must
  /// contain compatibility code for reading older versions.
  var dataVersion = 1;

  Type get _supportedType;

  _Persister() {
    Persistence._registerPersister(_supportedType, this);
  }

  /// Converts [view] to a [Stream] of bytes. Override in children.
  Stream<List<int>> _writeStreamFromView(GpsPointsView view);

  /// Overwrites the contents of [view] (if it is not read-only) with
  /// the information fom the [sourceStream].
  void _readViewFromStream(GpsPointsView view, Stream<List<int>> sourceStream,
      String metaInformation, int version);
}
