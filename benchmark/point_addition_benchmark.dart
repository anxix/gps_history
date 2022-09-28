/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';

// Configure the tests to be executed. Note that CPUs may start throttling
// if the test load is too high, leading to unreliable and strange results.
const nrPoints = 5000000;
const nrRunsPerTest = 5;
const runFromBasicList = true;
const runFromGpc = true;

Future<void> runPerformanceTest(
    Iterable<GpsPoint> source, SortingEnforcement sortingEnforcement) async {
  print(
      'START performance test adding from ${source.runtimeType} with enforcement $sortingEnforcement');

  var totalTime = Duration();
  for (var runNr = 0; runNr < nrRunsPerTest; runNr++) {
    final target = GpcCompactGpsPoint();
    target.capacity = source.length;
    target.sortingEnforcement = sortingEnforcement;

    final startTime = DateTime.now();

    target.addAll(source);

    final endTime = DateTime.now();
    final deltaTime = endTime.difference(startTime);
    print(
        '    Run $runNr: added ${target.length} in ${deltaTime.inMilliseconds} ms');

    totalTime = totalTime + deltaTime;
  }

  print('END. Average: ${totalTime.inMilliseconds ~/ nrRunsPerTest} ms/run.');
}

void main() async {
  print('Generating $nrPoints source points...');
  final source = <GpsPoint>[];
  final gpcSource = GpcCompactGpsPoint()..capacity = source.length;
  for (var i = 0; i < nrPoints; i++) {
    final p = GpsPoint(
        time: GpsTime(i), latitude: i.toDouble(), longitude: i.toDouble());
    if (runFromBasicList) source.add(p);
    if (runFromGpc) gpcSource.add(p);
  }
  print('Done.');

  if (runFromBasicList) {
    await runPerformanceTest(source, SortingEnforcement.throwIfWrongItems);
    await runPerformanceTest(source, SortingEnforcement.skipWrongItems);
    await runPerformanceTest(source, SortingEnforcement.notRequired);
  }

  if (runFromGpc) {
    await runPerformanceTest(gpcSource, SortingEnforcement.throwIfWrongItems);
    await runPerformanceTest(gpcSource, SortingEnforcement.skipWrongItems);
    await runPerformanceTest(gpcSource, SortingEnforcement.notRequired);
  }
}
