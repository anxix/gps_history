/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:io';

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_persist.dart';

GpcCompactGpsPoint generatePoints(int nrPoints) {
  final result = GpcCompactGpsPoint();
  for (var i = 1; i <= nrPoints; i++) {
    final point = GpsPoint(
        time: GpsTime.zero.add(minutes: i),
        latitude: i / 150.0,
        longitude: i / 250.0,
        altitude: i / 350.0);
    result.add(point);
  }
  return result;
}

void main() async {
  /// The number of points to generate.
  final nrPoints = 1000000;

  /// Where to store the file. Launch from examples directory as:
  /// ```dart save_reload.dart```
  final filename = './data/save_reload.agh';

  /// Implementation.

  // Register persisters, otherwise it's not possible to save/load anything.
  initializeDefaultPersisters();

  // Create the points.
  final sourcePoints = generatePoints(nrPoints);

  // Write them.
  final writeSink = File(filename).openWrite();
  await Persistence.get().write(sourcePoints, writeSink);
  await writeSink.close();

  // Reload them.
  final loadedPoints = GpcCompactGpsPoint();
  final readStream = File(filename).openRead();
  await Persistence.get().read(loadedPoints, readStream);

  // Check they're the same.
  var identicalPoints = 0;
  var differentPoints = 0;
  if (loadedPoints.length != sourcePoints.length) {
    print('Changed number of points after save/reload.');
  } else {
    for (var i = 0; i < loadedPoints.length; i++) {
      if (loadedPoints[i] == sourcePoints[i]) {
        identicalPoints++;
      } else {
        differentPoints++;
      }
    }
    print('Identical points: $identicalPoints\n'
        'Different points: $differentPoints');
  }
}
