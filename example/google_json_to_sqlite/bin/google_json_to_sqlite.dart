// Sample for converting a Google location history JSON file to a SQLite DB.
// Compile and launch as follows, in a console with the current directory being
// set to <gps_history_dir>/examples/google_json_to_sqlite:
//
//    dart compile exe bin/google_json_to_sqlite.dart && bin/google_json_to_sqlite.exe

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

void main() async {
  final jsonFilename = '/home/me/src/locstory/locationhistory.json';

  final file = File(jsonFilename);
  final sqliteDbFilename = path.join(path.dirname(file.absolute.path),
      '${path.basenameWithoutExtension(jsonFilename)}.sqlite');

  print('Converting from: ${file.absolute.path}');
  print('Converting to: $sqliteDbFilename');

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

  // Create indexes on everything for easy exploring in a database browser.
  // This increases the size of the generated database file by about a factor 3,
  // but makes it feasible to sort and filter quickly by any column in a database
  // browser. Without indexes, the process is painfully slow, at least in
  // DB Browser for SQLite on Linux.
  await db.execute('''
    CREATE INDEX idx_datetime ON Points(datetime);
    CREATE INDEX idx_datetime_s_from_epoch ON Points(datetime_s_from_epoch);
    CREATE INDEX idx_latitude ON Points(latitude);
    CREATE INDEX idx_longitude ON Points(longitude);
    CREATE INDEX idx_altitude ON Points(altitude);
    CREATE INDEX idx_accuracy ON Points(accuracy);
    CREATE INDEX idx_heading ON Points(heading);
    CREATE INDEX idx_speed ON Points(speed);
    CREATE INDEX idx_speedAccuracy ON Points(speedAccuracy);
    ''');

  var fileStream = file.openRead();

  var points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: null, accuracyThreshold: null));

  await db.transaction((txn) async {
    final batch = txn.batch();
    var count = 0;
    try {
      await for (var p in points) {
        // Insert the point in the SQLite database.
        await txn.insert('Points', {
          'datetime': p.time.toIso8601String(),
          'datetime_s_from_epoch':
              (p.time.millisecondsSinceEpoch / 1000).round(),
          'latitude': p.latitude,
          'longitude': p.longitude,
          'altitude': p.altitude,
          'accuracy': p is GpsMeasurement ? p.accuracy : null,
          'heading': p is GpsMeasurement ? p.heading : null,
          'speed': p is GpsMeasurement ? p.speed : null,
          'speedAccuracy': p is GpsMeasurement ? p.speedAccuracy : null,
        });
        count++;
        if (count % 10000 == 0) {
          final now = DateTime.now();
          var formatter = DateFormat('H:mm:ss');
          print(
              '${formatter.format(now)}.${(now.millisecond / 100).truncate()} - Added $count points');
        }
      }
    } finally {
      print('Committing $count points...');
      await batch.commit(noResult: true, continueOnError: true);
    }
  }).whenComplete(() async {
    print('Closing database...');
    await db.close();
  });
}
