/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_queries.dart';

const nrItems = 10000000;
const nrLoops = 1000000;

void main(List<String> args) {
  print('Creating $nrItems points...');
  final collection = GpcCompactGpsPoint()..capacity = nrItems;
  for (var i = 0; i < nrItems; i++) {
    collection.add(GpsPoint.allZero.copyWith(time: GpsTime(i)));
  }
  print('Done');

  final stopwatch = Stopwatch();

  final targetTime = GpsTime(0); // pretty much worst case for binary search
  final searchAlgo = BinarySearchInGpcEfficient(collection, compareItemToTime);

  stopwatch.start();

  for (var loopNr = 0; loopNr < nrLoops; loopNr++) {
    final found = searchAlgo.find(targetTime);
    if (found == null || collection[found].time != targetTime) {
      print('Bad result');
      break;
    }
  }

  stopwatch.stop();
  print(
      'Executed $nrLoops searches in $nrItems in ${stopwatch.elapsedMilliseconds} ms');
}
