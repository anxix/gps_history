# GPS History for Dart
Module intended to represent histories of GPS points. Features:

  * Two types of GPS point: a lean one with just the bare minimums and one
    with more meta information such as heading, speed, etc. that's useful for
    GPX files for example.
  * Different in-memory storage systems for GPS points: either simply 
    list-based, or efficient binary representation of just 14 or 22 bytes per
    point (at the cost of small loss of accuracy that's below what GPS sensors
    provide anyway).
  * Extremely low-memory and fast parser for Google location history JSON
    export. As a reference, a straighforward parser using the Dart JSON library
    on a ~500 MB history file takes about 2 GB of memory and on an Intel Core
    i7-8565U can produce about 140k points/s, while the custom parser takes
    almost no memory on top of the base memory use of the application and 
    outputs points about 2.5x-3.5x faster. Parse Google location history on
    mobile devices without any worries about running out of RAM.
  * Modular and extensible architecture: add your own points definitions, 
    containers or persistence mechanisms.
  * Many unit tests, examples and lots of documentation.
  * Null safety.
  * No dependencies on third party libraries.

## Example
Reading a JSON file containing location history exported from Google:
```dart
import 'dart:io';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

void main() async {
  final filename = 'data/g_history_sample.json';

  final file = File(filename);
  final gpsPoints = GpcCompactGpsPoint();

  var fileStream = file.openRead();

  var points = fileStream.transform(GoogleJsonHistoryDecoder(
      minSecondsBetweenDatapoints: 240, accuracyThreshold: 500));

  await for (var p in points) {
    gpsPoints.add(p);
  }

  print('Read ${gpsPoints.length} points');

  // Calculate with what frequency the points have been recorded.
  var intervals = <int>[];
  GpsPoint? prevPoint;

  for (var p in gpsPoints) {
    if (prevPoint != null) {
      final diff = p.time.difference(prevPoint.time).inSeconds;
      intervals.add(diff);
    }
    prevPoint = p;
  }

  intervals.sort();

  if (intervals.isNotEmpty) {
    print('Median interval = ${intervals[intervals.length ~/ 2]} s');
  }
}
```
