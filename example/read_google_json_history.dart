import 'dart:io';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

void main() async {
  final filename = 'data/g_history_sample.json';

  final file = File(filename);
  final gpsPoints = GpcCompactGpsPoint();

  var fileStream = file.openRead();

  var points = fileStream.transform(GoogleJsonHistoryBinaryDecoder(
      minSecondsBetweenDatapoints: 240, accuracyThreshold: 500));

  await for (var p in points) {
    gpsPoints.add(p);
  }

  print('Read ${gpsPoints.length} points');

  // Calculate with what frequencey the points have been recorded.
  var intervals = <int>[];
  var prevPoint;

  for (var p in gpsPoints) {
    print(p);

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
