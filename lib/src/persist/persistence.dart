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

/// The Persistence class should be used as a singleton (call [Persistence.get])
/// that can write and potentially read [GpsPointsView] instances to
/// [StreamSink] respectively from [Stream] instances. Reading from streams
/// requires the view to be modifiable, which not all views are.
///
/// The class relies on [Persister] subclasses, that are registered with it
/// as supporting particular subclasses of [GpsPointsView], to do the actual
/// streaming conversions. These [Persister] instances must therefore be
/// registered by the users of this library at runtime before trying to
/// load/store data.
///
/// Throws a [NoPersisterException] if called upon to operate on a view type
/// for which no [Persister] has been registered.
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
///   * 20 bytes: [Persister] signature header to recognize data type.
///     Each registered [Persister] instance must have a unique signature.
///     This will be validated at reading time against the [Persister]
///     registered for the data currently being read.
///   * 2 bytes: [Uint16] indicating the version number of the persisted data,
///     so that upgrades in format are possible and recognizable without
///     changing the header. [Persistence] will not read files that have a
///     persisted data version newer than the one supported by the relevant
///     registered [Persister]. Again, this ensures old versions don't try
///     to read new data and do so badly.
///   * 1 byte: the number of bytes to be read from the following metadata
///     sub-stream
///   * 55 bytes: reserved for any kind of metadata a particular
///     [Persister] may require.
/// * unknown number of bytes: the streamed data.
/// By having a fixed header size, we can determine numbers of points in a file
/// without fully parsing it, by simply looking at the total file size minus
/// the header and dividing the outcome by the storage size per point.
class Persistence {
  static var _singletonInstance;

  /// Factory that returns the singleton instance.
  factory Persistence.get() {
    _singletonInstance ??= Persistence._internal();
    return _singletonInstance;
  }

  /// Internal constructor for use in singleton behaviour.
  Persistence._internal();

  /// Do not call this constructor directly (needed for unit tests).
  Persistence();

  /// The signature and version at the start of the file.
  /// The version indicates the version of the streaming mechanism used by the
  /// current implementation of [Persistence].
  /// Only increase the version if the streaming method (not the contents!) is
  /// changed such that earlier versions cannot possibly support it. An example
  /// would be if the persistence starts compressing all streams.
  final _signatureAndVersion = SignatureAndVersion('AnqsGpsHistoryFile--', 1);

  /// The maximum number of bytes allowed for the metadata of a [Persister].
  /// Changing this requires changing the version number of the [Persistence] as
  /// well as compatibility/conversion code for reading older versions.
  final maxMetadataLength = 55;

  final _knownPersisters = <Type, Persister>{};

  /// Returns the [Persister] registered to handled objects of the type of
  /// [view] or raises [NoPersisterException] if not found.
  Persister getPersister(GpsPointsView view) {
    final result = _knownPersisters[view.runtimeType];
    if (result == null) {
      throw NoPersisterException(
          'No persister found for type ${view.runtimeType}');
    } else {
      return result;
    }
  }

  /// Registers the specified [persister] as supporting its
  /// [persister.supportedType], and returns [persister] as result.
  ///
  /// The returning of the input is useful for writing code such as:
  /// ```dart
  /// final persister = Persistence.get().register(SomePersister());
  /// ```
  ///
  /// Throws [ConflictingPersisterException] if there's already a persister
  /// with the same [Persister.signature] present, since it would be impossible
  /// to validate the correct reading of files if multiple persisters have
  /// the same signature.
  Persister register(Persister persister) {
    // Check for duplicate singature.
    for (var value in _knownPersisters.values) {
      if (value.signature.toLowerCase() == persister.signature.toLowerCase()) {
        throw ConflictingPersisterException(
            'Trying to register persister ${persister.runtimeType} with '
            'signature "${persister.signature}", but existing persister '
            '${value.runtimeType} already has that signature.');
      }
    }

    _knownPersisters[persister.supportedType] = persister;

    return persister;
  }

  /// Unregisters the specified [persister].
  ///
  /// Throws [ConflictingPersisterException] if the persister currently
  /// registered for [persister.supportedType] is not [persister] itself.
  void unregister(Persister persister) {
    // Ensure that the persister is indeed the one currently registered for
    // the specific type.
    final value = _knownPersisters[persister.supportedType];
    if (_knownPersisters[persister.supportedType] != persister) {
      throw ConflictingPersisterException(
          'Trying to unregister persister ${persister.runtimeType} with '
          'supporedType="${persister.supportedType}", but found in registry '
          '$value in that slot.');
    }
    _knownPersisters.remove(persister.supportedType);
  }

  /// Reads a signature from [state], validates it against the
  /// [expectedSignature] and throws [InvalidSignatureException] if they don't
  /// match.
  Future<void> _readValidateSignature(
      StreamReaderState state, String expectedSignature) async {
    final loadedSignature = await state.readString(expectedSignature.length);
    if (loadedSignature != expectedSignature) {
      throw InvalidSignatureException(
          'Stream contains no or invalid signature "${loadedSignature ?? ""}", '
          'while "$expectedSignature" was expected.');
    }
  }

  /// Reads a version number for [objectName] from [state], validates it
  /// against the [maximumCompatibleVersion] and throws [NewerVersionException]
  /// if the read version is newer and hence incompatible.
  Future<int> _readValidateVersion(StreamReaderState state,
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
  /// Optionally a non-null [streamSizeBytesHint] may be provided to
  /// indicate how large the stream is, but see caveats in
  /// [StreamReaderState.remainingStreamBytesHint] on its use.
  ///
  /// Throws [ReadonlyContainerException] if [view.isReadonly], as the contents
  /// of a readonly view cannot be overwritten.
  /// Throws [NotEmptyContainerException] if [view.isNotEmpty], as the contents
  /// of an already existing view cannot be overwritten (since there may be
  /// other views that depend on it).
  /// Throws [InvalidSignatureException] if the stream contains an invalid
  /// signature at either [Persistence] level or [Persister] level.
  /// Throws [NewerVersionException] if the stream contains a newer version at
  /// either [Persistence] level or [Persister] level.
  Future<void> read(GpsPointsView view, Stream<List<int>> sourceStream,
      [int? streamSizeBytesHint]) async {
    if (view.isReadonly) {
      throw ReadonlyContainerException();
    }

    if (view.isNotEmpty) {
      throw NotEmptyContainerException();
    }

    final state = StreamReaderState(sourceStream, streamSizeBytesHint);

    // Read the header signature and stop if it's unrecognized.
    await _readValidateSignature(state, _signatureAndVersion.signature);

    // Read the streaming method version and stop if it's newer than what
    // we support internally.
    await _readValidateVersion(state, _signatureAndVersion.version, 'stream');

    final persister = getPersister(view);

    // Read the persister signature and validate against the persister that's
    // supposed to read the specified view.
    await _readValidateSignature(state, persister.signature);

    // Read the persister version number and stop if it's newer than what the
    // persister writes natively.
    final loadedPersisterVersion = await _readValidateVersion(
        state, persister.version, 'persister ${persister.runtimeType}');

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
    return persister.readViewFromStream(
        view, state, loadedPersisterVersion, metadata);
  }

  /// Writes [view] to [targetSink] in binary format.
  Future<void> write(
      GpsPointsView view, StreamSink<List<int>> targetSink) async {
    final sink = StreamSinkWriter(targetSink);

    // Write the signature and version of the persistence system.
    sink.writeString(_signatureAndVersion.signature);
    sink.writeUint16(_signatureAndVersion.version);

    final persister = getPersister(view);

    // Write the signature and version information of the persister.
    sink.writeString(persister.signature);
    sink.writeUint16(persister.version);

    // Write the metadata of the persister.
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
    return targetSink.addStream(persister.writeViewToStream(view));
  }
}

/// Children of [Persister] implement the actual reading and writing of
/// particular types of [GpsPointsView] descendants. They must be stateless
/// w.r.t. to the data they are persisting, the only data they are allowed
/// to contain are generic information such as their own version number
/// and signature.
abstract class Persister {
  /// Creates the [Persister] and registers it to the specified [Persistence]
  /// manager class.
  const Persister();

  /// Indicates what object type this [Persister] can persist, to be overridden
  /// in child classes.
  Type get supportedType;

  /// Returns the signature string for this [Persister].
  String get signature {
    return signatureAndVersion.signature;
  }

  /// Indicates the version of the persistence method.
  int get version => signatureAndVersion.version;

  /// Override in children to indicate the signature of this class (used
  /// to recognize when reading a file which persister to initialize)
  /// and which version is written. The version should be increased
  /// if for example new fields get persisted. In that case, the reader must
  /// contain compatibility code for reading older versions.
  ///
  /// [signatureFromType] can be used to generate a standard signature from
  /// the [supportedType], but read the caveats in its documentation.
  SignatureAndVersion get signatureAndVersion;

  /// Creates a default signature from the type. This should be used carefully,
  /// since changing the name of the [supportedType] class in a refactoring can
  /// lead to stored files becoming incompatible.
  String signatureFromType(Type type) {
    var sig = type.toString();

    return signatureFromString(sig);
  }

  /// Makes sure that the specified [sig], if too short, is extended to be of
  /// valid signature length.
  ///
  /// Throws [InvalidSignatureException] if [sig] is too long, because trimming
  /// signatures blindly can lead to distinct signatures becoming identical.
  String signatureFromString(String sig) {
    if (sig.length > SignatureAndVersion.RequiredSignatureLength) {
      throw (InvalidSignatureException('Signature "$sig" is too long: '
          '${sig.length} > ${SignatureAndVersion.RequiredSignatureLength}'));
    }

    // Ensure the sig is not too short.
    var result = sig.padRight(SignatureAndVersion.RequiredSignatureLength, '-');

    return result;
  }

  /// Allows writing up to [Persistence.maxMetadataLength] bytes of extra
  /// information in the file header. Override in children if needed.
  ByteData? getMetadata(GpsPointsView view) => null;

  /// Overwrites the contents of [view] (if it is not read-only) with
  /// the information fom the [source]. [version] and [metadata] indicate
  /// the additional information that was read from the block header in
  /// the file, and may be used to e.g. convert old formats to new.
  Future<void> readViewFromStream(GpsPointsView view, StreamReaderState source,
      int version, ByteData metadata);

  /// Converts [view] to a [Stream] of bytes. Override in children.
  Stream<List<int>> writeViewToStream(GpsPointsView view);
}
