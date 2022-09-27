/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:io';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

void main() async {
  final filename = 'data/g_history_sample.json';

  final file = File(filename);
  final gpsPoints = GpcCompactGpsPoint();

  var fileStream = file.openRead();

  var points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: 240, accuracyThreshold: 500));

  await for (var p in points) {
    gpsPoints.add(p);
  }

  print('Read ${gpsPoints.length} points');

  // Calculate with what frequency the points have been recorded.
  var intervals = <int>[];
  var distances = <double>[];
  GpsPoint? prevPoint;

  for (var p in gpsPoints) {
    if (prevPoint != null) {
      final diff = p.time.difference(prevPoint.time);
      intervals.add(diff);

      final dist = distance(prevPoint, p);
      distances.add(dist);
    }
    prevPoint = p;
  }

  intervals.sort();
  distances.sort();

  if (intervals.isNotEmpty) {
    print('Intervals:');
    print('  min    = ${intervals[0]} s');
    print('  median = ${intervals[intervals.length ~/ 2]} s');
    print('  max    = ${intervals[intervals.length - 1]} s');
  }
  if (distances.isNotEmpty) {
    print('Distances:');
    print('  min    = ${distances[0]} m');
    print('  median = ${distances[distances.length ~/ 2]} m');
    print('  max    = ${distances[distances.length - 1]} m');
  }
}
