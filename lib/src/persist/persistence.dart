/// Facilities for reading/writing GPS history data from/to streams.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:async';
import 'dart:typed_data';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_persist.dart';

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
///   * 1 byte: the number of bytes to be read from the following metadata
///     sub-stream
///   * 55 bytes: reserved for any kind of metadata a particular
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

  /// The maximum number of bytes allowed for the  metadata of a [_Persister].
  static final maxMetadataLength = 55;

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
    final loadedSignature = await state.readString(expectedSignature.length);
    if (loadedSignature != _signatureAndVersion.signature) {
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
    final loadedVersion = await state.readUint16();
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
    await _readValidateSignature(state, _signatureAndVersion.signature);

    // Read the streaming method version and stop if it's newer than what
    // we support internally.
    await _readValidateVersion(state, _signatureAndVersion.version, 'stream');

    final persister = _getPersister(view);

    // Read the persister signature and validate against the persister that's
    // supposed to read the specified view.
    await _readValidateSignature(
        state, persister.signatureAndVersion.signature);

    // Read the persister version number and stop if it's newer than what the
    // persister writes natively.
    final loadedPersisterVersion = await _readValidateVersion(
        state,
        persister.signatureAndVersion.version,
        'persister ${persister.runtimeType.toString()}');

    // Read the metadata.
    final metadataLength = await state.readUint8();
    if (metadataLength == null || metadataLength > maxMetadataLength) {
      throw (InvalidMetadataException(
          'Expected to read metadata with max length $maxMetadataLength, '
          'but found length $metadataLength.'));
    }
    // Always read entire metadata because it's fixed-length, will trim it
    // afterwards to reflect the actual length read above.
    final metadataList = await state.readBytes(maxMetadataLength);
    if (metadataList == null) {
      throw (InvalidMetadataException(
          'Failed reading metadata, probably the stream is corrupted '
          '(too short)'));
    }
    final metadata = ByteData(metadataLength);
    metadata.buffer.asUint8List().setRange(0, metadataLength, metadataList);

    // Have the persister read and interpret the actual data.
    persister._readViewFromStream(
        view, state, loadedPersisterVersion, metadata);
  }

  /// Writes [view] to [targetSink] in binary format.
  static void write(GpsPointsView view, StreamSink<List<int>> targetSink) {
    final sink = StreamSinkWriter(targetSink);

    // Write the signature and version of [Persistance].
    sink.writeString(_signatureAndVersion.signature);
    sink.writeUint16(_signatureAndVersion.version);

    final persister = _getPersister(view);

    // Write the signature and version information of [_Persister].
    sink.writeString(persister.signatureAndVersion.signature);
    sink.writeUint16(persister.signatureAndVersion.version);

    // Write the metadata of [_Persister].
    final metadata = persister.getMetadata(view) ?? ByteData(0);
    if (metadata.lengthInBytes > maxMetadataLength) {
      throw (InvalidMetadataException(
          'Incorrect meta information length. Expected max $maxMetadataLength '
          'but provided with ${metadata.lengthInBytes} bytes.'));
    }
    // First the size of the metadata...
    sink.writeUint8(metadata.lengthInBytes);
    // ...then the metadata...
    sink.writeBytes(metadata.buffer.asUint8List());
    // ...and finally any necessary all-zero padding.
    sink.writeBytes(
        List<int>.filled(maxMetadataLength - metadata.lengthInBytes, 0));

    // Write the view.
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

  /// Allows writing up to [Persistance.maxMetadataLength] bytes of extra
  /// information in the file header. Override in children if needed.
  ByteData? getMetadata(GpsPointsView view) => null;

  /// Converts [view] to a [Stream] of bytes. Override in children.
  Stream<List<int>> _writeStreamFromView(GpsPointsView view);

  /// Overwrites the contents of [view] (if it is not read-only) with
  /// the information fom the [source]. [version] and [metadata] indicate
  /// the additional information that was read from the block header in
  /// the file, and may be used to e.g. convert old formats to new.
  void _readViewFromStream(GpsPointsView view, StreamReaderState source,
      int version, ByteData metadata);
}
