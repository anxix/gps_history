/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/src/base.dart';
import 'package:gps_history/gps_history_convert.dart';

/// Try out the performance of the point parser on huge amounts of data.
/// The runtime of this test should not made worse with new versions.
void main() {
  var nrPointsFound = 0;

  var pointParser = PointParser(null, null, (GpsPoint point) {
    nrPointsFound++;
  });
  var lines = '''}, {
    "timestampMs" : "1542094587054",
    "latitudeE7" : 520264968,
    "longitudeE7" : 42965754,
    "accuracy" : 16
  }, {
    "timestampMs" : "1542094707100",
    "latitudeE7" : 520264968,
    "longitudeE7" : 42965754,
    "accuracy" : 16,
    "activity" : [ {
      "timestampMs" : "1542094717559",
      "activity" : [ {
        "type" : "STILL",
        "confidence" : 100
      } ]
    } ]
  }, {
    "timestampMs" : "1542094779762",
    "latitudeE7" : 520264884,
    "longitudeE7" : 42966157,
    "accuracy" : 16,
    "altitude" : 34,
    "verticalAccuracy" : 2
  }, {
    "timestampMs" : "1542094869902",
    "latitudeE7" : 520264884,
    "longitudeE7" : 42966157,
    "accuracy" : 16,
    "altitude" : 34,
    "verticalAccuracy" : 2,
    "activity" : [ {'''
      .split('\n');

  final nrLoops = 500000;
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < nrLoops; i++) {
    for (var line in lines) {
      final bytes = stringToIntList(line);
      pointParser.parseUpdate(bytes, 0, bytes.length);
    }
  }
  stopwatch.stop();

  final dt = stopwatch.elapsedMilliseconds / 1000.0;
  var nrLines = nrLoops * lines.length;
  print(
      'BENCHMARK: $nrPointsFound points from $nrLines lines in ${dt.toString()}s '
      'i.e. ${dt / (nrLines / 1000000.0)} s/1M lines '
      'or ${nrLines / dt / 1000000} M lines/s');
}
