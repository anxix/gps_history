/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:math';

import 'package:gps_history/gps_history.dart';

// Configure the tests to be executed. Note that CPUs may start throttling
// if the test load is too high, leading to unreliable and strange results.
const nrCalcsPerRun = 10000000;
const nrRunsPerTest = 5;
const testPerformance = true;
const compareAccuracy = true;

Future<void> runPerformanceTest(DistanceCalculateFunc dc) async {
  print('START performance test for $dc');

  var totalTime = Duration();
  for (var runNr = 0; runNr < nrRunsPerTest; runNr++) {
    final startTime = DateTime.now();

    for (var i = 0; i < nrCalcsPerRun; i++) {
      dc(1.1, 1.2, -1.3, -1.4);
    }

    final endTime = DateTime.now();
    final deltaTime = endTime.difference(startTime);
    print(
        '    Run $runNr: calculated $nrCalcsPerRun in ${deltaTime.inMilliseconds} ms');

    totalTime = totalTime + deltaTime;
  }

  print('END. Average: ${totalTime.inMilliseconds ~/ nrRunsPerTest} ms/run.');
}

Future<void> runAccuracyComparison() async {
  var funcs = [
    distanceCoordsSuperFast,
    distanceCoordsEquirectangular,
    distanceCoordsHaversine,
    distanceCoordsLambert
  ];

  // Print a header.
  var s = 'lat\tlong\t';
  for (final f in funcs) {
    s = '$s\t$f';
  }
  print(s);

  for (var latA = 0.0; latA < 90; latA += 2) {
    final lats = [latA + 0.0000001, latA + 1, latA + 10];
    for (final latB in lats) {
      var r = '$latA\t$latB';
      for (final f in funcs) {
        final res = f(min(latA, 89.5), latA, min(latB, 89.5), latB);
        r = '$r\t$res';
      }
      print(r);
    }
  }
}

void main() async {
  if (testPerformance) {
    await runPerformanceTest(distanceCoordsSuperFast);
    await runPerformanceTest(distanceCoordsEquirectangular);
    await runPerformanceTest(distanceCoordsHaversine);
    await runPerformanceTest(distanceCoordsLambert);
  }

  if (compareAccuracy) {
    await runAccuracyComparison();
  }
}
