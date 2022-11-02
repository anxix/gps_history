/// Provides a real implementation for the compilation targets that support
/// the io library.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import '../../gpc_efficient.dart';
import 'gj_file_to_points_base.dart';
import 'gj_stream_to_points.dart';

/// Returns a parser that does parse the contents of the file specified in the
/// [options], and supports multithreaded (Isolate based) parsing.
GoogleJsonFileParser getParser(ParsingOptions options) =>
    GoogleJsonFileParserMultithreaded(options);

/// Represents a chunk of the file to be parsed in a single isolate.
class FileChunk {
  /// First position in the file where to parse.
  int start;

  /// Last position in the file to be parsed (exclusive).
  int end;

  /// Constructor.
  FileChunk(this.start, this.end);

  @override
  String toString() {
    return 'chunk: $start - $end';
  }
}

/// Parser that supports multithreading using isolates. For large files measured
/// parsing dual core being 1.7x as fast and quad core 2.7x as fast as single
/// core. Further gains can be expected in CPUs with more cores. A large file
/// of about 500 MB can be parsed on an Intel i7-8565U in about 1 second when
/// using 4 cores.
///
/// The trade-off compared to straightforward parsing is increased memory use
/// (the resulting list will be present in memory in its final size, but also
/// in separate parts in the separate threads).
class GoogleJsonFileParserMultithreaded implements GoogleJsonFileParser {
  ParsingOptions options;

  GoogleJsonFileParserMultithreaded(this.options);

  @override
  Future<GpcCompactGpsPointWithAccuracy> parse() async {
    final file = File(options.fileName);

    final chunks = await getChunks(file, options.maxNrThreads);

    // Parse the chunks.
    if (chunks.length == 1) {
      // Only one chunk required -> don't bother with setting up an isolate,
      // which will require additional memory.
      return parseStream(file.openRead(), options.minSecondsBetweenDatapoints,
          options.accuracyThreshold);
    } else {
      // Use isolates to speed up simultaneous processing of multiple chunks.
      return parseFileInChunks(file, chunks,
          options.minSecondsBetweenDatapoints, options.accuracyThreshold);
    }
  }

  /// Determines into how many chunks the file should be split, taking into
  /// account the [fileSizeBytes], an optionally imposed [maxNrChunks], the
  /// [nrCpus] and optionally the [freeRamBytes].
  ///
  /// All parameters are treated in a very tolerant manner, so a result will
  /// come out even in case of invalid parameters.
  static int getNrChunks(
      {int fileSizeBytes = 0,
      int? maxNrChunks,
      int nrCpus = 1,
      int? freeRamBytes}) {
    // Parsing is very quick, so there's no use in chunking files that are
    // relatively small and can be parsed in a fraction of a second.
    if (fileSizeBytes < 1000000) {
      return 1;
    }

    // Determine if we're possibly going to have a memory problem in case of
    // multithreaded processing.determineNrChunks
    if (freeRamBytes != null) {
      // Order of magnitude derived from a large sample file is 250 bytes of
      // JSON per point, but this can vary wildly.
      final estimatedNrPoints = fileSizeBytes ~/ 250;

      // 20 bytes per point in [GpcCompactGpsMeasurement].
      final estimatedGpcSize = estimatedNrPoints * 24;

      // Multithreading might double the amount of required memory as the data
      // will be stored in chunks in the different threads, and then added
      // together into the final result.
      final estimatedRequiredFreeSpace = estimatedGpcSize * 2;

      // Give it some margin (factor 2) and if there's not enough free memory,
      // go to just one chunk.
      if (estimatedRequiredFreeSpace * 2 < freeRamBytes) {
        return 1;
      }
    }

    // Trim nrCpus and maxNrChunks to reasonable boundaries: must have at least
    // one chunk and at most one chunk per cpu.
    nrCpus = max(1, nrCpus);
    maxNrChunks = max(maxNrChunks ?? nrCpus, 1);
    // Prevent ridiculous results by capping at 32 chunks.
    return min(min(nrCpus, maxNrChunks), 32);
  }

  /// Determines how to read the [file] in independent chunks and returns
  /// those chunks as a result. If specified [maxNrChunks] will be the maximum
  /// number of chunks created, otherwise the maximum will depend on the
  /// number of processors on the system (uses [getNrChunks] for the
  /// actual number of chunks).
  static Future<List<FileChunk>> getChunks(File file, int? maxNrChunks) async {
    final chunks = <FileChunk>[];

    final fileSize = file.lengthSync();

    // numberOfProcessors will include hyperthreading or power-efficient cores.
    // Either way, prefer not to hog all resources, so leave 2 cores unused.
    final nrCpus = max(1, Platform.numberOfProcessors - 2);
    final nrChunks = getNrChunks(
        maxNrChunks: maxNrChunks, fileSizeBytes: fileSize, nrCpus: nrCpus);

    // In case of single chunk, don't do any further processing.
    if (nrChunks == 1) {
      chunks.add(FileChunk(0, fileSize));
      return chunks;
    }

    // Determining chunks by jumping around a random access file takes at most
    // a few milliseconds, while using stream-based processing requires going
    // through most of the file and can take e.g. 0.25s on a 500 MB file on a
    // laptop CPU.
    final bytesPerChunk = 1 + fileSize ~/ nrChunks;
    final raFile = await file.open();
    try {
      while (true) {
        if (chunks.isNotEmpty) {
          final lastChunk = chunks.last;
          if (lastChunk.end >= fileSize) {
            break;
          }
        }

        var chunkEnd = min(bytesPerChunk * (1 + chunks.length), fileSize);
        // If the previous chunk is already longer than what one might expect
        // the next chunk to end at (should not happen except for intentionally
        // malformed input), make sure there is no overlap created between the
        // new and the previous chunk.
        if (chunks.isNotEmpty) {
          chunkEnd = max(chunkEnd, chunks.last.end);
        }
        raFile.setPositionSync(chunkEnd);
        await _moveToChunkBoundary(raFile);
        chunks.add(FileChunk(
            chunks.isEmpty ? 0 : chunks.last.end, raFile.positionSync()));
      }
    } finally {
      await raFile.close();
    }
    return chunks;
  }

  /// Increases the position in [raFile] until a location is found that is
  /// suitable for splitting the parsing over multiple threads in a way that
  /// ensures every thread ends up with a correct and completely defined subset
  /// of points (i.e. data belonging to a single point will not be split over
  /// different threads).
  ///
  /// A suitable place is after a JSON object is defined, which is detected by
  /// the sequence of closed curly brace followed by comma: "},".
  static _moveToChunkBoundary(RandomAccessFile raFile) async {
    bool lookingForClosingCurly = true;
    bool lookingForComma = false;
    // Starting at current position, look at one character at a time trying to
    // identify the location of "}," (ASCII 125, 44).
    final maxChars = raFile.lengthSync() - raFile.positionSync();
    var charNr = 0;
    while (charNr < maxChars) {
      final byte = raFile.readByteSync();
      charNr++;
      if (lookingForClosingCurly) {
        if (byte == 125) {
          // Found closing curly brace -> see if next char is a comma.
          lookingForClosingCurly = false;
          lookingForComma = true;
        }
      } else if (lookingForComma) {
        if (byte == 44) {
          // It's a comma and we were looking for one -> done, found good split.
          return;
        } else {
          // We're looking for a comma, but it's not what we found (i.e. the
          // preceding closing curly brace was not the closing delimiter of a
          // JSON object definition) -> start looking for the next closing
          // curly brace.
          lookingForClosingCurly = true;
          lookingForComma = false;
        }
      }
    }
  }

  /// Parses the [file] split according to the specified [chunks] in separate
  /// isolates and returns the identified points. For the meaning of the rest
  /// of the parameters, see [GoogleJsonHistoryDecoder].
  Future<GpcCompactGpsPointWithAccuracy> parseFileInChunks(
      File file,
      List<FileChunk> chunks,
      double minSecondsBetweenDatapoints,
      double? accuracyThreshold) async {
    final result = GpcCompactGpsPointWithAccuracy();

    // Split the work in separate isolates.
    final recPorts = <ReceivePort>[];
    for (final chunk in chunks) {
      final rp = ReceivePort('$chunk');
      recPorts.add(rp);
      Isolate.spawn((SendPort sp) async {
        final fileStream = file.openRead(chunk.start, chunk.end);
        final chunkResult = await parseStream(
            fileStream, minSecondsBetweenDatapoints, accuracyThreshold);
        Isolate.exit(sp, chunkResult);
      }, rp.sendPort);
    }

    final pointLists = <GpcCompactGpsPointWithAccuracy>[];
    for (final rp in recPorts) {
      final gpc = await rp.first as GpcCompactGpsPointWithAccuracy;
      pointLists.add(gpc);
      result.addAll(gpc);
    }
    return result;
  }

  /// Parses the contents of [jsonStream] and returns the identified points
  /// as result. For the meaning of the rest of the parameters, see
  /// [GoogleJsonHistoryDecoder].
  Future<GpcCompactGpsPointWithAccuracy> parseStream(
      Stream<List<int>> jsonStream,
      double minSecondsBetweenDatapoints,
      double? accuracyThreshold) async {
    final result = GpcCompactGpsPointWithAccuracy();
    final pointsStream = jsonStream.transform(GoogleJsonHistoryDecoder(
        minSecondsBetweenDatapoints: minSecondsBetweenDatapoints,
        accuracyThreshold: accuracyThreshold));
    await for (final point in pointsStream) {
      result.add(point);
    }
    return result;
  }
}
