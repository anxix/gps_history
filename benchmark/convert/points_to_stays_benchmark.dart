/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

const nrPoints = 10000000;

void main() async {
  final points = <GpsPoint>[];

  print('Generating $nrPoints points');

  for (var pointNr = 0; pointNr < nrPoints; pointNr++) {
    // Spacing between points is calculated to get about 80% fewer stays than
    // original points, which is roughly the ratio seen for actual Google JSON
    // history data. Therefore performance improvements have a decent chance of
    // being representative of actual data (which should still be checked
    // separately of course).
    final longitude = (pointNr / 50000) % 360 - 180;
    final point =
        GpsPoint(time: GpsTime(pointNr), latitude: 0, longitude: longitude);
    points.add(point);
  }

  final stays = GpcCompactGpsStay()..capacity = nrPoints;
  final pointsStream = Stream<GpsPoint>.fromIterable(points);
  final converter =
      PointsToStaysDecoder(maxTimeGapSeconds: 10, maxDistanceGapMeters: 10);

  print('Starting conversion...');
  final startTime = DateTime.now();

  await for (final stay in pointsStream.transform(converter)) {
    stays.add(stay);
  }

  final endTime = DateTime.now();
  final runTime = endTime.difference(startTime);
  print(
      'Converted $nrPoints points to ${stays.length} stays in ${runTime.inMilliseconds} ms');
}
