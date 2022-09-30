import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:gps_history/gps_history.dart';

const nrPoints = 100000000;

void main(List<String> args) async {
  final stopwatch = Stopwatch();
  print('Generating $nrPoints points...');
  stopwatch.start();
  final points = GpcCompactGpsPoint()..capacity = nrPoints;
  for (var i = 0; i < nrPoints; i++) {
    final point = GpsPoint(
        time: GpsTime(i),
        latitude: i / nrPoints * 89,
        longitude: i / nrPoints * 179);
    points.add(point);
  }
  stopwatch.stop();
  print('Done in ${stopwatch.elapsedMilliseconds} ms.');

  print('Spawning isolate...');
  stopwatch.reset();
  print('Sleeping in main isolate before starting isoloate');
  sleep(Duration(seconds: 10));
  stopwatch.start();
  final receivePort = ReceivePort();
  await Isolate.spawn((SendPort p) async {
    print('Working in sub isolate...');
    // sleep(Duration(seconds: 60));
    var total = 0.0;
    for (final p in points) {
      total += p.latitude * p.latitude - p.longitude * p.longitude;
      total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
      total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
      total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
      total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
      total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
    }
    print('total from isolate: $total');
    print('From isolate: points.length==${points.length}');
    Isolate.exit(p, null);
  }, receivePort.sendPort);
  print('Created isolate in ${stopwatch.elapsedMilliseconds} ms');

  print('Working in main isolate...');
  // sleep(Duration(seconds: 50));
  var total = 0.0;
  for (final p in points) {
    total += p.latitude * p.latitude - p.longitude * p.longitude;
    total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
    total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
    total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
    total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
    total = total - sqrt(sqrt(sqrt(sqrt(sqrt(sqrt(total.abs()))))));
  }
  print('total from main: $total.');
  print('Finished work in main isolate.');

  await receivePort.first;
  stopwatch.stop();
  print('Done in ${stopwatch.elapsedMilliseconds} ms.');
}
