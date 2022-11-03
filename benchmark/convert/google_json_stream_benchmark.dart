/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:io';
import 'dart:math';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';
import 'package:gps_history/src/convert/google_json/gj_file_to_points_io.dart';
import 'package:gps_history/src/utils/grid.dart';

void wait(String? msg) {
  if (msg != null) {
    print('$msg Press ENTER to continue.');
  }
  stdin.readLineSync();
}

void buildSparseArray(GpcCompactGpsPointWithAccuracy points) async {
  wait('Convert to stays.');

  final stopwatch = Stopwatch();
  stopwatch.start();

  final converter = PointsToStaysDecoder(
      maxTimeGapSeconds: 24 * 3600, maxDistanceGapMeters: 100);
  final stays = GpcCompactGpsStay()..capacity = points.length;
  final pointsStream = Stream<GpsPoint>.fromIterable(points);
  await for (final stay in pointsStream.transform(converter)) {
    stays.add(stay);
  }

  stopwatch.stop();
  print(
      'Converted to ${stays.length} stays in ${stopwatch.elapsedMilliseconds} ms');

  wait('Build map.');

  stopwatch.reset();
  stopwatch.start();

  final grid = Grid(stays);

  stopwatch.stop();

  wait('Finished building map.');

  final lengths = <int>[];
  grid.forEachCell((itemsInCell) {
    lengths.add(itemsInCell.length);
  });
  lengths.sort();

  print(
      'Built map with ${lengths.length} in ${stopwatch.elapsedMilliseconds} ms');

  if (lengths.length > 2) {
    print('Cell with largest number of values contains ${lengths.last} items\n '
        '  median is ${lengths[lengths.length ~/ 2]} items\n '
        '  90% is ${lengths[(lengths.length * 0.9).round()]}\n '
        '  95% is ${lengths[(lengths.length * 0.95).round()]}\n '
        '  99% is ${lengths[(lengths.length * 0.99).round()]}\n'
        '  99.9% is ${lengths[(lengths.length * 0.999).round()]}\n'
        '  99.99% is ${lengths[(lengths.length * 0.9999).round()]}\n');
  }
}

/// Try out the performance of the custom JSON.
/// Can also be used to check that its results are the same as those of the
/// reference decoder implemented in the benchmark
/// ```google_json_reference_decoder.dart```.
void main() async {
  print('Number of CPUs: ${Platform.numberOfProcessors}');
  // Indicate whether all the found points should be printed at the end.
  final printPoints = false;
  // Location of the file to parse.
  final filename = '../../large_data/locationhistory.json';
  // Filtering parameters for the parser.
  final minSecondsBetweenDatapoints = 1.0;
  final accuracyThreshold = null;

  final stopwatch = Stopwatch();

  const maxNrThreads = 32;

  wait('Loading file to points.');

  stopwatch.start();
  final parsingOptions = ParsingOptions(filename,
      maxNrThreads: maxNrThreads,
      accuracyThreshold: accuracyThreshold,
      minSecondsBetweenDatapoints: minSecondsBetweenDatapoints);
  final gpsPoints =
      await GoogleJsonFileParserMultithreaded(parsingOptions).parse();

  stopwatch.stop();

  final dt = stopwatch.elapsedMilliseconds / 1000;
  print(
      'Read ${gpsPoints.length} in $dt s: ${gpsPoints.length / 1000000 / dt} Mpoints/s or ${dt / (gpsPoints.length / 1000000)} s/Mpoint');

  wait('Finished reading file to points.');

  final diffs = <int>[];
  int sumdiffs = 0;
  GpsPoint? prevp;
  var mindiff = 100000000;
  var maxdiff = 0;

  for (final p in gpsPoints) {
    // ignore: dead_code
    if (printPoints) {
      print(p);
    }
    if (prevp != null) {
      final int diff = p.time.difference(prevp.time);
      if (diff > 0) {
        mindiff = min(diff, mindiff);
      }
      maxdiff = max(diff, maxdiff);
      sumdiffs += diff;
      diffs.add(diff);
    }
    prevp = p;
  }

  diffs.sort();

  print(
      'maxdiff=$maxdiff, mindiff=$mindiff, avgdiff=${sumdiffs / diffs.length}, mediandiff=${diffs[diffs.length ~/ 2]}');

  buildSparseArray(gpsPoints);
}
