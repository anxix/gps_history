/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';

void main() async {
  final points = GpcCompactGpsPoint();
  points.capacity = 10000000;

  final point = GpsPoint.allZero.copyWith(time: DateTime.now().toUtc());
  final startTime = DateTime.now();

  for (var i = 0; i < points.capacity; i++) {
    points.add(point);
  }

  final endTime = DateTime.now();
  final deltaTime = endTime.difference(startTime);

  print('Added ${points.length} in ${deltaTime.inMilliseconds} ms');
}
