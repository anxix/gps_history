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
  double? minSecondsBetweenDatapoints;

  /// Passed directly to constructor of [GoogleJsonHistoryDecoder], see its
  /// documentation for details.
  double? accuracyThreshold;

  /// Constructor.
  ParsingOptions(this.fileName,
      {this.accuracyThreshold,
      this.minSecondsBetweenDatapoints,
      this.maxNrThreads});
}

/// Base class for a Google JSON file parser, only required for keeping the
/// package compatible with the web compile target, which does not support io.
class GoogleJsonFileParser {
  factory GoogleJsonFileParser(ParsingOptions options) {
    return getParser(options);
  }

  /// Parsing method, to be implemented in child class that does support io.
  ///
  /// Returns the result of the parsing. Selected to use [GpcCompactGpsStay]
  /// because we need accuracy and stays are smaller than measurements.
  GpcCompactGpsStay parse() {
    throw UnimplementedError();
  }
}
