/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

/// Try out the performance of the point parser on huge amounts of data.
/// The runtime of this test should not made worse with new versions.
void main() {
  print('Starting big parsing loop ${DateTime.now().toString()}.');
  var pp = PointParser();

  final nrLoops = 10000000;
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < nrLoops; i++) {
    pp.parseUpdate('"timestampMs" : 0,');
    pp.parseUpdate('"latitudeE7" : 1,');
    pp.parseUpdate('"longitudeE7" :2,');
    pp.parseUpdate('"accuracy" : 12,');
    pp.parseUpdate('}');
  }
  stopwatch.stop();
  print('Ended big parsing loop ${DateTime.now().toString()}.');

  final dt = stopwatch.elapsedMilliseconds / 1000.0;
  print('''BENCHMARK: $nrLoops in ${dt.toString()}s
    i.e. ${dt / (nrLoops / 1000000.0)} s/1M points
    or ${nrLoops / dt / 1000000} M points/s''');
}
