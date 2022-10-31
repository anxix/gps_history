/// Provides a real implementation for the compilation targets that support
/// the io library.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import '../../gpc_efficient.dart';
import 'gj_file_to_points_base.dart';

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
  GpcCompactGpsStay parse() {
    // Determine the number of threads to use.

    // Find the chunk boundaries.

    // Parse the chunks.

    // Return the results.
    throw UnimplementedError();
  }
}
