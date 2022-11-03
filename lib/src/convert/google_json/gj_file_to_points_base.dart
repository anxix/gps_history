/// Provides parsing of a JSON file by using the stream parser, and adding
/// multithreading isolate-based behaviour on top. Only intended to be
/// used on platforms that support the io package.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';

import '../../gpc_efficient.dart';

import 'gj_file_to_points_no_io.dart'
    if (dart.library.io) 'gj_file_to_points_io.dart';

/// Container of parsing options to be passed to [CoogleJsonFileParser].
class ParsingOptions {
  /// Name of the file to be parsed.
  String fileName;

  /// The maximum number of threads to be used in parsing. If null, will be
  /// automatically determined based on number of available CPU cores.
  int? maxNrThreads;

  /// Passed directly to constructor of [GoogleJsonHistoryDecoder], see its
  /// documentation for details.
  double minSecondsBetweenDatapoints;

  /// Passed directly to constructor of [GoogleJsonHistoryDecoder], see its
  /// documentation for details.
  double? accuracyThreshold;

  /// Constructor.
  ParsingOptions(this.fileName,
      {this.accuracyThreshold,
      this.minSecondsBetweenDatapoints = 1.0,
      this.maxNrThreads});
}

/// Base class for a Google JSON file parser, only required for keeping the
/// package compatible with the web compile target, which does not support io.
class GoogleJsonFileParser {
  factory GoogleJsonFileParser(ParsingOptions options) {
    // getParser should be implemented by conditionally imported modules.
    return getParser(options);
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

      // 16 bytes per point in [GpcCompactGpsPointWithAccuracy].
      final estimatedGpcSize = estimatedNrPoints * 16;

      // Multithreading might double the amount of required memory as the data
      // will be stored in chunks in the different threads, and then added
      // together into the final result.
      final estimatedRequiredFreeSpace = estimatedGpcSize * 2;

      // Give it some margin (factor 2) and if there's not enough free memory,
      // go to just one chunk.
      if (estimatedRequiredFreeSpace * 2 > freeRamBytes) {
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

  /// Parsing method, to be implemented in child class that does support io.
  ///
  /// Returns the result of the parsing.
  Future<GpcCompactGpsPointWithAccuracy> parse() async {
    throw UnimplementedError();
  }
}
