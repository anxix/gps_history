/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

void main() async {
  final jsonFilename = '../data/g_history_sample.json';

  final file = File(jsonFilename);
  final sqliteDbFilename = path.join(path.dirname(file.absolute.path),
      '${path.basenameWithoutExtension(jsonFilename)}.sqlite');

  // Init ffi loader if needed.
  sqfliteFfiInit();
  // Remove and recreate the database.
  var databaseFactory = databaseFactoryFfi;
  await databaseFactory.deleteDatabase(sqliteDbFilename);
  var db = await databaseFactory.openDatabase(sqliteDbFilename);
  await db.execute('''
  CREATE TABLE Points (
      id INTEGER PRIMARY KEY,
      datetime TEXT,
      datetime_s_from_epoch INTEGER,
      latitude REAL,
      longitude REAL,
      altitude REAL,
      accuracy REAL,
      heading REAL,
      speed REAL,
      speedAccuracy REAL
  )
  ''');

  var fileStream = file.openRead();

  var points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: null, accuracyThreshold: null));

  final batch = db.batch();
  try {
    await for (var p in points) {
      // Insert the point in the SQLite database.
      await db.insert('Points', {
        'datetime': p.time.toIso8601String(),
        'datetime_s_from_epoch': p.time.millisecondsSinceEpoch / ~1000,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'altitude': p.altitude,
        'accuracy': p is GpsMeasurement ? p.accuracy ?? -1 : -1,
        'heading': p is GpsMeasurement ? p.heading ?? -1 : -1,
        'speed': p is GpsMeasurement ? p.speed ?? -1 : -1,
        'speedAccuracy': p is GpsMeasurement ? p.speedAccuracy ?? -1 : -1,
      });
    }
  } finally {
    await batch.commit(noResult: true, continueOnError: true);
    await db.close();
  }
}
