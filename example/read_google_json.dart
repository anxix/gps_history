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
  final gpsStays = GpcCompactGpsStay();

  final fileStream = file.openRead();

  final points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: 1, accuracyThreshold: 500));

  final stays = points.transform(
      PointsToStaysDecoder(maxTimeGapSeconds: 10, maxDistanceGapMeters: 10));

  final startTime = DateTime.now();
  await for (final s in stays) {
    gpsStays.add(s);
  }
  final endTime = DateTime.now();

  print(
      'Read ${gpsStays.length} points in ${endTime.difference(startTime).inMilliseconds} ms');

  // Calculate with what frequency the points have been recorded.
  final intervals = <int>[];
  final durations = <int>[];
  final distances = <double>[];
  GpsStay? prevPoint;

  for (final s in gpsStays) {
    durations.add(s.endTime.difference(s.startTime));
    if (prevPoint != null) {
      final diff = s.time.difference(prevPoint.endTime);
      intervals.add(diff);

      final dist = distance(prevPoint, s);
      distances.add(dist);
    }
    prevPoint = s;
  }

  intervals.sort();
  durations.sort();
  distances.sort();

  if (intervals.isNotEmpty) {
    print('Intervals:');
    print('  min    = ${intervals[0]} s');
    print('  median = ${intervals[intervals.length ~/ 2]} s');
    print('  max    = ${intervals[intervals.length - 1]} s');
  }
  if (durations.isNotEmpty) {
    print('Durations:');
    print('  min    = ${durations[0]} s');
    print('  median = ${durations[durations.length ~/ 2]} s');
    print('  max    = ${durations[durations.length - 1]} s');
  }
  if (distances.isNotEmpty) {
    print('Distances:');
    print('  min    = ${distances[0]} m');
    print('  median = ${distances[distances.length ~/ 2]} m');
    print('  max    = ${distances[distances.length - 1]} m');
  }
}
