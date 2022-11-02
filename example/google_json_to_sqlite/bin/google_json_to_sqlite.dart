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
        time TEXT,
        time_s_from_epoch INTEGER,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        accuracy REAL,
        heading REAL,
        speed REAL,
        speedAccuracy REAL
    )
    ''');

  await db.execute('''
    CREATE TABLE Stays (
        id INTEGER PRIMARY KEY,
        time TEXT,
        time_s_from_epoch INTEGER,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        accuracy REAL,
        endtime TEXT,
        endtime_s_from_epoch INTEGER
    )
    ''');

  // Create indexes on everything for easy exploring in a database browser.
  // This increases the size of the generated database file by about a factor 3,
  // but makes it feasible to sort and filter quickly by any column in a database
  // browser. Without indexes, the process is painfully slow, at least in
  // DB Browser for SQLite on Linux.
  await db.execute('''
    CREATE INDEX idx_time ON Points(time);
    CREATE INDEX idx_time_s_from_epoch ON Points(time_s_from_epoch);
    CREATE INDEX idx_latitude ON Points(latitude);
    CREATE INDEX idx_longitude ON Points(longitude);
    CREATE INDEX idx_altitude ON Points(altitude);
    CREATE INDEX idx_accuracy ON Points(accuracy);
    CREATE INDEX idx_heading ON Points(heading);
    CREATE INDEX idx_speed ON Points(speed);
    CREATE INDEX idx_speedAccuracy ON Points(speedAccuracy);
    ''');

  await db.execute('''
    CREATE INDEX idx_s_time ON Stays(time);
    CREATE INDEX idx_s_time_s_from_epoch ON Stays(time_s_from_epoch);
    CREATE INDEX idx_s_latitude ON Stays(latitude);
    CREATE INDEX idx_s_longitude ON Stays(longitude);
    CREATE INDEX idx_s_altitude ON Stays(altitude);
    CREATE INDEX idx_s_accuracy ON Stays(accuracy);
    CREATE INDEX idx_s_endtime ON Stays(endtime);
    CREATE INDEX idx_s_endtime_s_from_epoch ON Stays(endtime_s_from_epoch);
    ''');

  await db.transaction((txn) async {
    final batch = txn.batch();
    var pointsCount = 0;
    var staysCount = 0;
    try {
      var fileStream = file.openRead();
      final pointsStream = fileStream.transform(GoogleJsonHistoryDecoder(
          minSecondsBetweenDatapoints: null, accuracyThreshold: null));
      await for (final p in pointsStream) {
        // Insert the point in the SQLite database.
        await txn.insert('Points', {
          'time': p.time.toDateTimeUtc().toIso8601String(),
          'time_s_from_epoch': (p.time.secondsSinceEpoch),
          'latitude': p.latitude,
          'longitude': p.longitude,
          'altitude': p.altitude,
          'accuracy': p is GpsPointWithAccuracy ? p.accuracy : null,
          'heading': p is GpsMeasurement ? p.heading : null,
          'speed': p is GpsMeasurement ? p.speed : null,
          'speedAccuracy': p is GpsMeasurement ? p.speedAccuracy : null,
        });
        pointsCount++;
        if (pointsCount % 10000 == 0) {
          final now = DateTime.now();
          var formatter = DateFormat('H:mm:ss');
          print(
              '${formatter.format(now)}.${(now.millisecond / 100).truncate()} - Added $pointsCount points');
        }
      }

      fileStream = file.openRead();
      final staysStream = fileStream
          .transform(GoogleJsonHistoryDecoder(
              minSecondsBetweenDatapoints: 1.0, accuracyThreshold: null))
          .transform(PointsToStaysDecoder(
              maxTimeGapSeconds: 24 * 3600, maxDistanceGapMeters: 100));
      await for (final s in staysStream) {
        // Insert the stay in the SQLite database.
        await txn.insert('Stays', {
          'time': s.time.toDateTimeUtc().toIso8601String(),
          'time_s_from_epoch': (s.time.secondsSinceEpoch),
          'latitude': s.latitude,
          'longitude': s.longitude,
          'altitude': s.altitude,
          'accuracy': s.accuracy,
          'endtime': s.endTime.toDateTimeUtc().toIso8601String(),
          'endtime_s_from_epoch': (s.endTime.secondsSinceEpoch),
        });
        staysCount++;
        if (staysCount % 10000 == 0) {
          final now = DateTime.now();
          var formatter = DateFormat('H:mm:ss');
          print(
              '${formatter.format(now)}.${(now.millisecond / 100).truncate()} - Added $staysCount stays');
        }
      }
    } finally {
      print('Committing $pointsCount points and $staysCount stays...');
      await batch.commit(noResult: true, continueOnError: true);
    }
  }).whenComplete(() async {
    print('Closing database...');
    await db.close();
  });
}
