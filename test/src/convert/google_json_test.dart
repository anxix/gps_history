/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

final oneDay = 24 * 3600 * 1000; // one day in milliseconds

/// Tests the PointParser against the specified sequence of [lines], ensuring
/// that it returns the correct response after each line ([expectedPoints]).
void _testPointParser(
    String testName, List<String> lines, List<GpsPoint?> expectedPoints) {
  // Checks for the given point that it matche sthe first item in
  // [expectedPoints]. If it doesn't, the test is failed.
  void checkParserResult(GpsPoint? point) {
    if (expectedPoints.isEmpty) {
      fail('Returned more points than expected');
    }

    expect(point, expectedPoints[0], reason: 'Incorrect result after parsing');

    expectedPoints.removeAt(0);
  }

  test(testName, () {
    final parser = PointParser();

    for (var line in lines) {
      final point = parser.parseUpdate(line);

      checkParserResult(point);
    }

    // At the end there may still be a valid point state in the parser, so
    // check for that.
    final point = parser.toGpsPointAndReset();
    if (point != null) {
      checkParserResult(point);
    }

    // After we extracted the last bit of information, the parser must not
    // return any more points.
    expect(parser.toGpsPointAndReset(), null,
        reason: 'Parser returned more than one final point.');

    expect(parser.isAllNull, true,
        reason: 'Parser state not all null after extracting it last state.');

    if (expectedPoints.isNotEmpty) {
      fail('Not all expected points found!');
    }
  });
}

/// Simplified version of [_testPointParser] that expects nulls for every
/// line in [lines] and only tests the final parser state at the end against
/// the [expectedPoint].
void _testPointParserAllNullsAndLastState(
    String testName, List<String> lines, GpsPoint? expectedPoint) {
  var expectedPoints = <GpsPoint?>[];

  for (var _ in lines) {
    expectedPoints.add(null);
  }

  expectedPoints.add(expectedPoint);
  _testPointParser(testName, lines, expectedPoints);
}

void testPointParser() {
  // Test the empty cases.
  _testPointParser('Nothing', [], []);
  _testPointParser('Empty string', [''], [null]);

  // Test arbitrary junk data.
  _testPointParser(
      'Arbitrary strings',
      ['wnvoiuvh', '"aiuwhe"', '"niniwuev" : "nioj"', '"jnj9aoiue": 3298'],
      [null, null, null, null]);

  // Test simple one-point defintion.
  _testPointParser(
      'Parse invalid point in standard order',
      ['"timestampMs":0,', '"latitudeE7" :-,', '"longitudeE7": 2,'],
      [null, null, null]);
  _testPointParserAllNullsAndLastState(
      'Parse single point in standard order',
      ['"timestampMs":0,', '"latitudeE7" :1,', '"longitudeE7": 2,'],
      GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null));
  _testPointParserAllNullsAndLastState(
      'Parse single point in nonstandard order',
      ['"latitudeE7" : \'1\',', '"timestampMs" : "0",', '"longitudeE7" : 2'],
      GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null));
  _testPointParserAllNullsAndLastState(
      'Parse single point with fluff in between',
      [
        '"timestampMs" : 0,',
        '"latitudeE7" : 1,',
        '"x" : 8',
        '"longitudeE7" : 2,'
      ],
      GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null));

  // Test resetting of internal state after incomplete initial point state.
  _testPointParserAllNullsAndLastState(
      'Parse single point after incomplete point',
      [
        '"timestampMs" : 99999,',
        '"latitudeE7" : 1,',
        '"timestampMs" : $oneDay,', // this should lead to the above two being discarded
        '"latitudeE7" : 5,',
        '"longitudeE7" : 6,',
        '"altitude" : 8,'
      ],
      GpsPoint(DateTime.utc(1970, 1, 2), 5.0E-7, 6.0E-7, 8.0));

  // Test negative values
  _testPointParserAllNullsAndLastState(
      'Parse negative values',
      [
        '"timestampMs" : -$oneDay,', // this should lead to the above two being discarded
        '"latitudeE7" : -5,',
        '"longitudeE7" : -6,',
        '"altitude" : -80,'
      ],
      GpsPoint(DateTime.utc(1969, 12, 31), -5.0E-7, -6.0E-7, -80.0));

  // Test parsing of multiple points.
  _testPointParser('Parse two consecutive points', [
    '"timestampMs" : 0,',
    '"latitudeE7" : 1,',
    '"longitudeE7" : 2,',
    '"timestampMs" : $oneDay,',
    '"latitudeE7" : 5,',
    '"longitudeE7" : 6,'
  ], [
    null,
    null,
    null, // Here it doesn't yet know the point is fully defined (finds that next).
    GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null),
    null,
    null,
    GpsPoint(DateTime.utc(1970, 1, 2), 5.0E-7, 6.0E-7, null)
  ]);

  // Test parsing to [GpsMeasurement].
  _testPointParserAllNullsAndLastState(
      'Parse to GpsMeasurement',
      [
        '"timestampMs" : 0,',
        '"latitudeE7" : 1,',
        '"longitudeE7" : 2,',
        '"accuracy" : 12,',
      ],
      GpsMeasurement(
          DateTime.utc(1970), 1.0E-7, 2.0E-7, null, 12, null, null, null));

  // Test parsing with some real data.
  _testPointParserAllNullsAndLastState(
      'Parse real data',
      [
        '}, {',
        '"timestampMs" : "1616789690748",',
        '"latitudeE7" : 371395513,',
        '"longitudeE7" : -79376766,',
        '"accuracy" : 20,',
        '"altitude" : 402,',
        '"verticalAccuracy" : 3',
        '}, {'
      ],
      GpsMeasurement(DateTime.utc(2021, 3, 26, 20, 14, 50, 748), 37.1395513,
          -7.9376766, 402, 20, null, null, null));
}

/// Runs a conversion test of the specified [json] checks if it is parsed to
/// the [expectedPoints].
void testJsonToGps(
    String testName, String json, List<GpsPoint> expectedPoints) {
  test(testName, () {
    final jsonStream = Stream.value(json);
    final points = jsonStream.transform(GoogleJsonHistoryDecoder());

    expect(points, emitsInOrder(expectedPoints));
  });
}

void main() {
  testPointParser();

  testJsonToGps('Empty string', '', List.empty());
  testJsonToGps('Two points', '''
    "timestampMs" : 0,
    "latitudeE7" : 1,
    "longitudeE7" : 2,
    "timestampMs" : $oneDay,
    "latitudeE7" : 5,
    "longitudeE7" : 6''', [
    GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null),
    GpsPoint(DateTime.utc(1970, 1, 2), 5.0E-7, 6.0E-7, null)
  ]);
}
