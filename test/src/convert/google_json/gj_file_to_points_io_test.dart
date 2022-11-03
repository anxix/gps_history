/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history_convert.dart';
import 'package:test/test.dart';

main() {
  group('getNrChunks', () {
    const smallFileSize = 1000;
    const largeFileSize = 1000000000;

    runTestGetNrChunks(int expected,
        {int fileSizeBytes = 0,
        int? maxNrChunks,
        int nrCpus = 1,
        int? freeRamBytes}) {
      final result = GoogleJsonFileParser.getNrChunks(
          fileSizeBytes: fileSizeBytes,
          maxNrChunks: maxNrChunks,
          nrCpus: nrCpus,
          freeRamBytes: freeRamBytes);
      expect(result, expected);
    }

    test('Small file lots of resources', () {
      runTestGetNrChunks(1,
          fileSizeBytes: smallFileSize,
          maxNrChunks: 10,
          nrCpus: 10,
          freeRamBytes: largeFileSize);
    });

    test('Large file low memory', () {
      runTestGetNrChunks(1,
          fileSizeBytes: largeFileSize,
          maxNrChunks: 10,
          nrCpus: 10,
          freeRamBytes: 10);
    });

    test('Large file hard limit chunks', () {
      runTestGetNrChunks(4,
          fileSizeBytes: largeFileSize, maxNrChunks: 4, nrCpus: 10);
    });

    test('Large file hard limit CPUs', () {
      runTestGetNrChunks(8,
          fileSizeBytes: largeFileSize, maxNrChunks: 10, nrCpus: 8);
    });
  });

  test('Parsing JSON from file', () async {
    // For this test to work, it must be launched from the root of the package
    // so that paths are correct.
    final options =
        ParsingOptions('example/data/g_history_sample.json', maxNrThreads: 1);
    final parser = GoogleJsonFileParser(options);
    final result = await parser.parse();
    expect(result.length, 16, reason: 'Incorrect single threaded parsing');
  });
}
