# GPS History for Dart
Module intended to represent histories of GPS points. Includes:

  * Two types of GPS point: a lean one with just the bare minimums and one
    with more meta information such as heading, speed, etc. that's useful for
    GPX files for example.
  * Different in-memory storage systems for GPS points: either simply 
    list-based, or efficient binary representation of just 14 or 22 bytes per
    point (at the cost of small loss of accuracy).
  * Extremely fast and low-memory parser for Google location history JSON
    export.
  * Many unit tests and doc strings.

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
  var prevPoint;

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
