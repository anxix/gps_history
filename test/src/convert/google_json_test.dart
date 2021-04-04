/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:test/test.dart';
import 'package:gps_history/gps_history.dart';
import 'package:gps_history/gps_history_convert.dart';

/// Tests the PointParser against the specified sequence of [lines], ensuring
/// that it returns the correct response after each line ([expectedPoints]).
void _runPointParserTest(
    String testName, List<String> lines, List<GpsPoint?> expectedPoints) {
  test(testName, () {
    final parser = PointParser();

    for (var line in lines) {
      var p = parser.parseUpdate(line);

      if (expectedPoints.isEmpty) {
        fail('Returned more points than expected');
      }

      expect(p, expectedPoints[0],
          reason: 'Incorrect result after parsing: $line');

      expectedPoints.removeAt(0);
    }

    if (expectedPoints.isNotEmpty) {
      fail('Not all expected points found!');
    }
  });
}

void testPointParser() {
  _runPointParserTest('Nothing', [], []);
  _runPointParserTest('Empty string', [''], [null]);
  _runPointParserTest(
      'Arbitrary strings',
      ['wnvoiuvh', '"aiuwhe"', '"niniwuev" : "nioj"', '"jnj9aoiue": 3298'],
      [null, null, null, null]);
}

/// Runs a conversion test of the specified [json] checks if it is parsed to
/// the [expectedPoints].
void testJsonToGps(
    String testName, String json, List<GpsPoint> expectedPoints) {
  test(testName, () {
    var jsonStream = Stream.value(json);
    var points = jsonStream.transform(GoogleJsonHistoryDecoder());

    // Check that every point comes in as expected.
    points.listen((point) {
      // If we've already matched all expected points, but we get another one,
      // this is a failed test.
      if (expectedPoints.isEmpty) {
        fail('Parsed more points than expected');
      }

      // If the point we get is what we expected, remove it from the expected
      // list and continue.
      if (point == expectedPoints[0]) {
        expectedPoints.removeAt(0);
      }
    });

    // We've got all the points back that the parser found, if we expect even
    // more, that's a failed test.
    expect(expectedPoints.length, 0,
        reason: 'Some expectedPoints were not returned');
  });
}

void main() {
  testPointParser();

  testJsonToGps('Empty string', '', List.empty());
}
