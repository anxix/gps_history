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

/// Converts [string] to a list of integers being the code units of its
/// characters.
List<int> stringToIntList(String string) {
  final result = List<int>.filled(string.length, 0);

  // Test as single chunk.
  for (var i = 0; i < string.length; i++) {
    result[i] = string.codeUnitAt(i);
  }

  return result;
}

/// Tests the PointParser against the specified sequence of [chunks], ensuring
/// that it returns the correct response after parsing ([expectedPoints]).
void _testPointParser(
    String testName, List<List<int>> chunks, List<GpsPoint?> expectedPoints) {
  void checkParserResult(List<GpsPoint> foundPoints) {
    expect(foundPoints.length, expectedPoints.length,
        reason: 'Incorrect number of parsed points.');

    for (var pointNr = 0; pointNr < foundPoints.length; pointNr++) {
      expect(foundPoints[pointNr], expectedPoints[pointNr],
          reason: 'Wrong point at position $pointNr');
    }
  }

  test(testName, () {
    final foundPoints = <GpsPoint>[];
    final Function(GpsPoint point) pointsCollector = (GpsPoint point) {
      foundPoints.add(point);
    };
    final parser = PointParser(null, null, pointsCollector);

    for (var chunk in chunks) {
      parser.parseUpdate(chunk, 0, chunk.length);
    }
    // Force outputting of any final point the parser is unsure of whether it's
    // been fully parsed or not.
    parser.toGpsPointAndReset();
    expect(parser.isAllNull, true,
        reason: 'Parser state not all null after extracting it last state.');

    checkParserResult(foundPoints);

    // After we extracted the last bit of information, the parser must not
    // return any more points.
    final oldNrFoundPoints = foundPoints.length;
    parser.toGpsPointAndReset();
    expect(foundPoints.length, oldNrFoundPoints,
        reason: 'Parser returned more than one final point.');
  });
}

/// Tests the PointParser against the specified sequence of [strings], ensuring
/// that it returns the correct response after parsing ([expectedPoints]).
void _testPointParserStrings(
    String testName, List<String> strings, List<GpsPoint?> expectedPoints) {
  final chunks = List<List<int>>.filled(0, [], growable: true);
  for (var string in strings) {
    chunks.add(stringToIntList(string));
  }

  _testPointParser(testName, chunks, expectedPoints);
}

/// Test various cases for the [PointParser] class.
void testPointParser() {
  // Test the empty cases.
  _testPointParserStrings('Nothing', [], []);
  _testPointParserStrings('Empty string', [''], [null]);

  // Test arbitrary junk data.
  _testPointParserStrings('Arbitrary strings',
      ['wnvoiuvh\n"aiuwhe"\n"niniwuev" : "nioj"\n"jnj9aoiue": 3298'], []);

  // Test simple one-point defintion.
  _testPointParserStrings('Parse invalid point in standard order',
      ['"timestampMs":0,\n"latitudeE7" :-,\n"longitudeE7": 2,'], []);
  _testPointParserStrings(
      'Parse single point in standard order',
      ['"timestampMs":0,\n"latitudeE7" :1, "longitudeE7": 2'],
      [GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null)]);
  _testPointParser('Test parsing when last character is part of number', [
    // Use raw stringToIntList instead of calling testPointParserStrings
    // because we want to prevent any automatic string processing that
    // the testPointParserStrings may do from affecting the shape of the
    // string. In particular we don't want any space/newline to be added
    // at the end, the last character must be a digit.
    stringToIntList('"timestampMs":0,\n"latitudeE7" :13\n"longitudeE7": 20')
  ], [
    GpsPoint(DateTime.utc(1970), 1.3E-6, 2.0E-6, null)
  ]);
  _testPointParserStrings(
      'Parse single point in nonstandard order',
      ['"latitudeE7" : \'1\',', '"timestampMs" : "0",', '"longitudeE7" : "2"'],
      [GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null)]);
  _testPointParserStrings('Parse single point with fluff in between', [
    '"timestampMs" : 0,',
    '"latitudeE7" : 1,',
    '"x" : 8',
    '"longitudeE7" : 2,'
  ], [
    GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null)
  ]);

  // Test resetting of internal state after incomplete initial point state.
  _testPointParserStrings('Parse single point after incomplete point', [
    '"timestampMs" : 99999,',
    '"latitudeE7" : 1,',
    '"timestampMs" : $oneDay,', // this should lead to the above two being discarded
    '"latitudeE7" : 5,',
    '"longitudeE7" : 6,',
    '"altitude" : 8,'
  ], [
    GpsPoint(DateTime.utc(1970, 1, 2), 5.0E-7, 6.0E-7, 8.0)
  ]);

  // Test negative values
  _testPointParserStrings('Parse negative values', [
    '"timestampMs" : -$oneDay,', // this should lead to the above two being discarded
    '"latitudeE7" : -5,',
    '"longitudeE7" : -6,',
    '"altitude" : -80,'
  ], [
    GpsPoint(DateTime.utc(1969, 12, 31), -5.0E-7, -6.0E-7, -80.0)
  ]);

  // Test parsing of multiple points.
  _testPointParserStrings('Parse two consecutive points', [
    '"timestampMs" : 0,',
    '"latitudeE7" : 1,',
    '"longitudeE7" : 2,',
    '"timestampMs" : $oneDay,',
    '"latitudeE7" : 5,',
    '"longitudeE7" : 6,'
  ], [
    GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null),
    GpsPoint(DateTime.utc(1970, 1, 2), 5.0E-7, 6.0E-7, null)
  ]);

  // Test parsing to [GpsMeasurement].
  _testPointParserStrings('Parse to GpsMeasurement', [
    '"timestampMs" : 0,',
    '"latitudeE7" : 1,',
    '"longitudeE7" : 2,',
    '"accuracy" : 12,',
  ], [
    GpsMeasurement(
        DateTime.utc(1970), 1.0E-7, 2.0E-7, null, 12, null, null, null)
  ]);

  // Test parsing with some real data.
  _testPointParserStrings('Parse real data', [
    '}, {\n'
        '"timestampMs" : "1616789690748",\n'
        '"latitudeE7" : 371395513,\n'
        '"longitudeE7" : -79376766,\n'
        '"accuracy" : 20,\n'
        '"altitude" : 402,\n'
        '"verticalAccuracy" : 3\n'
        '}, {'
  ], [
    GpsMeasurement(DateTime.utc(2021, 3, 26, 20, 14, 50, 748), 37.1395513,
        -7.9376766, 402, 20, null, null, null)
  ]);
}

/// Runs a conversion test of the specified [jsonByteChunks] and checks if they
/// are parsed to the [expectedPoints].
void testChunkedJsonToGps(String testName, List<List<int>> jsonByteChunks,
    List<GpsPoint> expectedPoints) {
  test(testName, () {
    final chunkedIntStream = Stream.fromIterable(jsonByteChunks);
    final points = chunkedIntStream.transform(GoogleJsonHistoryDecoder());

    expect(points, emitsInOrder(expectedPoints));
  });
}

/// Runs a conversion test of the specified [json] checks if it is parsed to
/// the [expectedPoints]. Can also try all possible 2-chunk splits for the
/// specified [json], by setting [testAllChunkingPairs] to true.
void testJsonToGps(String testName, String json, List<GpsPoint> expectedPoints,
    [bool testAllChunkingPairs = false]) {
  final stringAsIntList = stringToIntList(json);

  final chunkedList = [stringAsIntList];
  testChunkedJsonToGps(testName, chunkedList, expectedPoints);

  // Test every possible split into two chunks for the specified JSON. All of
  // them should parse to the same result.
  if (testAllChunkingPairs) {
    for (var i = 0; i < stringAsIntList.length; i++) {
      final chunkA = List<int>.from(stringAsIntList.getRange(0, i));
      final chunkB =
          List<int>.from(stringAsIntList.getRange(i, stringAsIntList.length));
      final chunkedList = [chunkA, chunkB];
      testChunkedJsonToGps(
          '$testName chunked at i=$i', chunkedList, expectedPoints);
    }
  }
}

void main() {
  // testPointParser();

  testJsonToGps('Empty string', '', List.empty());
  testJsonToGps(
      'Two points',
      '''
    "timestampMs" : 0,
    "latitudeE7" : 1,
    "longitudeE7" : 2,
    "timestampMs" : $oneDay,
    "latitudeE7" : 5,
    "longitudeE7" : 6''',
      [
        GpsPoint(DateTime.utc(1970), 1.0E-7, 2.0E-7, null),
        GpsPoint(DateTime.utc(1970, 1, 2), 5.0E-7, 6.0E-7, null)
      ],
      true);
}
