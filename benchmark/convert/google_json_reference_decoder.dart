/// Module intended for checking correctness of parsing against real data.
/// Parses a Google location history JSON file using the Dart JSON libraries
/// and prints the data. This is relatively slow and memory intensive, but
/// it's also straightforward and gives a correct output that other
/// implementations can be checked against.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:gps_history/gps_history.dart';

void main() async {
  // Indicate whether all the found points should be printed at the end.
  final printPoints = false;
  // Location of the file to parse.
  final filename = '../../large_files/locationhistory.json';

  final stopwatch = Stopwatch();
  final gpsPoints = GpcCompactGpsPoint();
  final file = File(filename);
  var fileStream = file.openRead();

  stopwatch.start();
  var pointsJson = fileStream
      .transform(Utf8Decoder(allowMalformed: true))
      .transform(JsonDecoder());

  await for (var o in pointsJson) {
    var locationsList = (o as Map)['locations'];
    for (var location in locationsList) {
      var lm = location as Map;
      var time = int.parse(lm['timestampMs']);
      var latE7 = lm['latitudeE7'] as int;
      var longE7 = lm['longitudeE7'] as int;
      var accuracy = lm.containsKey('accuracy') ? lm['accuracy'] as int : null;
      var altitude = lm.containsKey('altitude') ? lm['altitude'] as int : null;

      var p = GpsPoint(DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
          latE7 / 1E7, longE7 / 1E7, altitude?.toDouble());
      // If we have accuracy specified, return a GpsMeasurement object that's
      // capable of storing accuracy information.
      if (accuracy != null) {
        p = GpsMeasurement.fromPoint(p, accuracy.toDouble(), null, null, null);
      }
      gpsPoints.add(p);
    }

    stopwatch.stop();
    final dt = stopwatch.elapsedMilliseconds / 1000;
    print(
        'Read ${gpsPoints.length} in $dt s: ${gpsPoints.length / 1000000 / dt} Mpoints/s or ${dt / (gpsPoints.length / 1000000)} s/Mpoint');

    var diffs = <int>[];
    var sumdiffs = 0;
    GpsPoint? prevp;
    var mindiff = 100000000;
    var maxdiff = 0;

    for (var p in gpsPoints) {
      // ignore: dead_code
      if (printPoints) {
        print(p);
      }
      if (prevp != null) {
        final int diff = p.time.difference(prevp.time).inSeconds;
        if (diff > 0) {
          mindiff = min(diff, mindiff);
        }
        maxdiff = max(diff, maxdiff);
        sumdiffs += diff;
        diffs.add(diff);
      }
      prevp = p;
    }

    diffs.sort();

    print(
        'maxdiff=$maxdiff, mindiff=$mindiff, avgdiff=${sumdiffs / diffs.length}, mediandiff=${diffs[diffs.length ~/ 2]}');
  }
}
