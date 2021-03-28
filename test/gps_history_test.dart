/*
 * Copyright (c) 
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'package:gps_history/gps_history.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    Awesome? awesome;

    setUp(() {
      awesome = Awesome();
    });

    test('First Test', () {
      expect(awesome?.isAwesome, isTrue);
    });
  });
}
