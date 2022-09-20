/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'gpc_test_skeleton.dart';

void main() {
  testGpsPointsCollection<GpsPoint>(
      'GpcListBased',
      () => GpcListBased<GpsPoint>(),
      (int i) => GpsPoint(
          time: GpsTime.fromUtc(1970 + i),
          latitude: i.toDouble(), // required to be equal to i
          longitude: i.toDouble(),
          altitude: i.toDouble()));
}
