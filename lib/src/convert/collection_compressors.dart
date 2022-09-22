/// Implements converters that can take a stream of GPS items and squeeze
/// that stream by removing duplication or converting multiple consecutive
/// items in the same locationto to a [GpsStay].

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:convert';

import '../base.dart';
import '../time.dart';

typedef GpsPointIterable = Iterable<GpsPoint>;

class PointsToStaysDecoder<GpsPoint>
    extends Converter<GpsPointIterable, GpsStay> {
  @override
  GpsStay convert(GpsPointIterable input) {
    // TODO: implement convert
    throw UnimplementedError();
  }

  @override
  Sink<GpsPointIterable> startChunkedConversion(Sink<GpsStay> sink) {
    // TODO: implement startChunkedConversion
    return _GpsPointsToStaysSink(sink);
  }
}

/// Sink for converting chunks of [GpsPoint] or child classes to [GpsStay].
class _GpsPointsToStaysSink extends ChunkedConversionSink<GpsPointIterable> {
  final Sink<GpsStay> _outputSink;

  GpsStay? _currentStay;

  _GpsPointsToStaysSink(this._outputSink);

  @override
  void add(chunk) {
    for (final point in chunk) {
      final rt = point.runtimeType;

      // Make sure we're not dealing with an unsupported type.
      if (rt != GpsPoint && rt != GpsMeasurement && rt != GpsStay) {
        throw TypeError();
      }

      _processPoint(point);
    }
  }

  void _processPoint(GpsPoint point) {
    // Handle initial state: no stay yet, accept whatever comes in as initial.
    if (_currentStay == null) {
      _resetCurrentStayTo(point);
    } else {
      // If point is not after currentStay (this should typically not happen,
      // but it's not forbidden as such), it cannot be merged. Conceptually
      // it might be possible to merge two overlapping stays, but it's not worth
      // the hassle.
      if (comparePointTimes(_currentStay!, point) !=
          TimeComparisonResult.before) {
        // The current stay is finished -> output it and start a new one.
        _outputSink.add(_currentStay!);
        _resetCurrentStayTo(point);
      }
      // We have some previous stay state -> requires checking times etc.
      if (point is GpsStay) {
      } else {}
    }
  }

  void _resetCurrentStayTo(GpsPoint point) {
    if (point is GpsStay) {
      _currentStay = point.copyWith();
    } else {
      _currentStay = GpsStay.fromPoint(point,
          accuracy: point is GpsMeasurement ? point.accuracy : null);
    }
  }

  @override
  void close() {
    if (_currentStay != null) {
      _outputSink.add(_currentStay!);
      _currentStay = null;
    }
  }
}
