# GPS History for Dart
Module intended to represent recorded histories of GPS points recorded at a
frequency >= 1 second. Features:

  * Three types of GPS point: a lean one with just the bare minimums and one
    with more meta information such as heading, speed, etc. that's useful for
    GPX files for example. Additionally a point that represents a longer stay
    at a location, which can be used to reduce duplicate entries in a database.
  * Different in-memory storage systems for GPS points: either simply 
    list-based, or efficient binary representation of just 14 to 22 bytes per
    point (at the cost of small loss of accuracy that's below what GPS sensors
    provide anyway).
  * Extremely low-memory and fast parser for Google location history JSON
    export. As a reference, a straighforward parser using the Dart JSON library
    on a ~500 MB history file takes about 2 GB of memory and on an Intel Core
    i7-8565U can produce about 140k points/s, while the custom parser takes
    almost no memory on top of the base memory use of the application and 
    outputs points about 2.5x-3.5x faster. Parse Google location history on
    mobile devices without any worries about running out of RAM.
  * Support for multithreaded parsing of Google location history JSON on 
    platforms that support the io library, giving about 2.7x performance boost
    for a quad core compared to single core parsing.
  * Modular and extensible architecture: add your own points definitions, 
    containers or persistence mechanisms.
  * Many unit tests, examples, benchmarks and lots of documentation.
  * Utility functions for dealing with time and distance.
  * Null safety.
  * Dependencies on third party libraries are limited to superficial 
    functionality, and then only very mainstream well supported ones.

## Example
Reading a JSON file containing location history exported from Google:
```dart
import 'dart:io';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

void main() async {
  final filename = 'data/g_history_sample.json';

  final file = File(filename);
  final gpsStays = GpcCompactGpsStay();

  final fileStream = file.openRead();

  final points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: 1, accuracyThreshold: 500));

  final stays = points.transform(
      PointsToStaysDecoder(maxTimeGapSeconds: 10, maxDistanceGapMeters: 10));

  await for (final s in stays) {
    gpsStays.add(s);
  }

  print('Read ${gpsStays.length} points');

  // Calculate with what frequency the points have been recorded.
  final intervals = <int>[];
  final durations = <int>[];
  final distances = <double>[];
  GpsStay? prevPoint;

  for (final s in gpsStays) {
    durations.add(s.endTime.difference(s.startTime));
    if (prevPoint != null) {
      final diff = s.time.difference(prevPoint.endTime);
      intervals.add(diff);

      final dist = distance(prevPoint, s);
      distances.add(dist);
    }
    prevPoint = s;
  }

  intervals.sort();
  durations.sort();
  distances.sort();

  if (intervals.isNotEmpty) {
    print('Intervals:');
    print('  min    = ${intervals[0]} s');
    print('  median = ${intervals[intervals.length ~/ 2]} s');
    print('  max    = ${intervals[intervals.length - 1]} s');
  }
  if (durations.isNotEmpty) {
    print('Durations:');
    print('  min    = ${durations[0]} s');
    print('  median = ${durations[durations.length ~/ 2]} s');
    print('  max    = ${durations[durations.length - 1]} s');
  }
  if (distances.isNotEmpty) {
    print('Distances:');
    print('  min    = ${distances[0]} m');
    print('  median = ${distances[distances.length ~/ 2]} m');
    print('  max    = ${distances[distances.length - 1]} m');
  }
}
```

# Automatic master branch test state
[![Dart](https://github.com/anxix/gps_history/actions/workflows/dart.yml/badge.svg)](https://github.com/anxix/gps_history/actions/workflows/dart.yml)
