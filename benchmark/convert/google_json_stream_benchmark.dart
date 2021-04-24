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

/// Try out the performance of the string-based JSON parser versus the
/// byte-based one. Can also be used to check that their results are the same.
void main() async {
  // Indicate whether all the found points should be printed at the end.
  final printPoints = false;
  // Location of the file to parse.
  final filename = '../../large_data/locationhistory.json';
  // Filtering parameters that only influence the binary implementation,
  // allowing it to not emit points that are of low quality or too frequent.
  final binaryMinSecondsBetweenDatapoints = null;
  final binaryAccuracyThreshold = null;

  final file = File(filename);
  final stopwatch = Stopwatch();
  final gpsPoints = GpcCompactGpsPoint();

  var fileStream = file.openRead();

  stopwatch.start();

  var points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: binaryMinSecondsBetweenDatapoints,
      accuracyThreshold: binaryAccuracyThreshold));

  await for (var p in points) {
    gpsPoints.add(p);
  }

  stopwatch.stop();
  final dt = stopwatch.elapsedMilliseconds / 1000;
  print(
      'Read ${gpsPoints.length} in $dt s: ${gpsPoints.length / 1000000 / dt} Mpoints/s or ${dt / (gpsPoints.length / 1000000)} s/Mpoint');

  var diffs = <int>[];
  var sumdiffs = 0;
  var prevp;
  var mindiff = 100000000;
  var maxdiff = 0;

  for (var p in gpsPoints) {
    if (printPoints) {
      print(p);
    }
    if (prevp != null) {
      final diff = p.time.difference(prevp.time).inSeconds;
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
