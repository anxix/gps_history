/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_queries.dart';
import 'package:gps_history/src/utils/bounding_box.dart';

const nrItems = 10000000;
const nrLoops = 10;
// The more intervals, the longer the benchmark will take.
const nrIntervals = 8000;
// The smaller the bounding box, the longer the process will take.
final boundingBox = GeodeticLatLongBoundingBox(0, 0, 0, 0);

void main() async {
  print('Creating $nrItems stays...');
  final collection = GpcCompactGpsStay()..capacity = nrItems;
  for (var i = 0; i < nrItems; i++) {
    collection.add(GpsStay.allZero.copyWith(
      time: GpsTime(i * 10),
      latitude: (i * 180 / nrItems) - 90,
      longitude: (i * 360 / nrItems) - 180,
    ));
  }
  print('Done');

  final stopwatch = Stopwatch();

  final query = QueryDataAvailability<GpsStay, GpcCompactGpsStay>(
      collection.first.time, collection.last.time, nrIntervals, boundingBox);

  stopwatch.start();
  DataAvailability? result;
  for (var loopNr = 0; loopNr < nrLoops; loopNr++) {
    result = await query.query(collection);
  }

  stopwatch.stop();

  print(
      'Executed $nrLoops queries in $nrItems in ${stopwatch.elapsedMilliseconds} ms');

  int nrInBoundingBox = 0;
  int nrOutsideBoundingBox = 0;
  int nrNotAvailable = 0;
  for (var i = 0; i < result!.length; i++) {
    switch (result[i]) {
      case Data.availableWithinBoundingBox:
        nrInBoundingBox++;
        break;
      case Data.availableOutsideBoundingBox:
        nrOutsideBoundingBox++;
        break;
      case Data.notAvailable:
        nrNotAvailable++;
        break;
    }
  }

  print(
      'Using ${result.length} intervals, with BB($boundingBox), responses:\n   $nrInBoundingBox in BB, $nrOutsideBoundingBox outside BB, $nrNotAvailable unavailable.');
}
