/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:async';

import 'package:gps_history/gps_history_persist.dart';

/// Sink for testing purposes that collects all data it receives into a list.
class TestSink implements Sink<List<int>> {
  final receivedData = List<int>.empty(growable: true);
  var isClosed = false;

  @override
  void add(List<int> data) {
    receivedData.addAll(data);
  }

  @override
  void close() {
    isClosed = true;
  }
}

/// A [TestSink] that implements the full [StreamSink] interface.
class TestStreamSink extends TestSink implements StreamSink<List<int>> {
  final closeCompleter = Completer();

  @override
  Future close() {
    closeCompleter.complete();
    return closeCompleter.future;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    throw error;
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    return Future.sync(() async {
      await for (var list in stream) {
        add(list);
      }
    });
  }

  @override
  Future get done {
    return closeCompleter.future;
  }
}

/// Class for testing purposes, as the global [Persistence] class is a singleton
/// and we don't want to interfere with its state. This one is not a singleton.
class PersistenceDummy extends Persistence {
  factory PersistenceDummy.get() => PersistenceDummy._internal();

  /// Internal constructor for use in not-singleton behaviour.
  PersistenceDummy._internal();
}
