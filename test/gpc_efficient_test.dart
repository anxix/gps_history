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
      'GpcEfficientGpsPoint',
      () => GpcEfficientGpsPoint(),
      (int i) => GpsPoint(
          // The constraints of GpcEfficientGpsPoint mean the date must be
          // somewhat reasonable, so we can't just use year 1.
          DateTime.utc(2000 + i),
          i.toDouble(),
          i.toDouble(),
          i.toDouble()));
}
