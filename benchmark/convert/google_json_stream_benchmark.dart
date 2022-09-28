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

/// Try out the performance of the custom JSON.
/// Can also be used to check that its results are the same as those of the
/// reference decoder implemented in the benchmark
/// ```google_json_reference_decoder.dart```.
void main() async {
  // Indicate whether all the found points should be printed at the end.
  final printPoints = false;
  // Location of the file to parse.
  final filename = '../../large_data/locationhistory.json';
  // Filtering parameters that only influence the binary implementation,
  // allowing it to not emit points that are of low quality or too frequent.
  final binaryMinSecondsBetweenDatapoints = 1.0;
  final binaryAccuracyThreshold = null;

  final file = File(filename);
  final stopwatch = Stopwatch();
  final gpsPoints = GpcCompactGpsPoint();

  final fileStream = file.openRead();

  stopwatch.start();

  final points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: binaryMinSecondsBetweenDatapoints,
      accuracyThreshold: binaryAccuracyThreshold));

  await for (final p in points) {
    gpsPoints.add(p);
  }

  stopwatch.stop();
  final dt = stopwatch.elapsedMilliseconds / 1000;
  print(
      'Read ${gpsPoints.length} in $dt s: ${gpsPoints.length / 1000000 / dt} Mpoints/s or ${dt / (gpsPoints.length / 1000000)} s/Mpoint');

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
}
