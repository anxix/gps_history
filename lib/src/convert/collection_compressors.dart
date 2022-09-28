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
import '../distance.dart';
import '../utils/time.dart';

typedef GpsPointIterable = Iterable<GpsPoint>;

/// Decoder that merges entities in a source stream to [GpsStay] entities, which
/// will typically reduce the total number of entries in the stream
/// significantly.
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
  /// Target for the identified [GpsStay] instances.
  final Sink<GpsStay> _outputSink;

  // Maximum amount of time in seconds between two measurements that are still
  // allowed to be merged into one stay. This is because the data may contain
  // huge time gaps during which no recording was performed.
  final int _maxTimeGapSeconds;

  // Maximum distance between two measurements that are still allowed to be
  // merged into one stay.
  final double _maxDistanceGapMeters;

  GpsStay? _currentStay;

  _GpsPointsToStaysSink(this._outputSink,
      {int? maxTimeGapSeconds, double? maxDistanceGapMeters})
      : _maxTimeGapSeconds = maxTimeGapSeconds ?? GpsTime.resolutionSeconds,
        _maxDistanceGapMeters = maxDistanceGapMeters ?? 1.0;

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
      _outputCurrentStayAndReset(point);
      return;
    }

    // We have some previous stay state -> requires checking times and mutual
    // distances.

    // If point is not after currentStay (this should typically not happen,
    // but it's not forbidden as such), it cannot be merged. Conceptually
    // it might be possible to merge two overlapping stays, but it's not worth
    // the hassle.
    if (comparePointTimes(_currentStay!, point) !=
        TimeComparisonResult.before) {
      // The current stay is finished -> output it and start a new one.
      _outputCurrentStayAndReset(point);
      return;
    }

    // If the current and new position are not sufficiently close together
    // in terms of time and space, output the current position and set point
    // as current stay.
    if (point.time.difference(_currentStay!.time) >= _maxTimeGapSeconds ||
        distance(_currentStay!, point, DistanceCalcMode.auto) >=
            _maxDistanceGapMeters) {
      _outputCurrentStayAndReset(point);
      return;
    }

    // Points are close together in time and space -> merge point to current
    // stay.
    _mergePointToCurrentStay(point);
  }

  /// Updates the [_currentStay] state with the information contained in
  /// [point].
  ///
  /// Caller must make sure that it makes sense to do this update in terms of
  /// time/space distance between the new point and the [_currentStay], this
  /// method merely executes the merge operation.
  void _mergePointToCurrentStay(GpsPoint point) {
    // Sanity check.
    if (_currentStay == null) {
      throw GpsHistoryException(
          'Called _updateCurrentStay while _currentStay == null!');
    }

    // endTime definitely needs to be updated.
    late GpsTime endTime;
    if (point.runtimeType == GpsStay) {
      endTime = (point as GpsStay).endTime;
    } else if (point.runtimeType == GpsPoint ||
        point.runtimeType == GpsMeasurement) {
      endTime = point.time;
    } else {
      // In case new classes are added.
      throw TypeError();
    }

    var newAccuracy = point is GpsStay
        ? point.accuracy
        : point is GpsMeasurement
            ? point.accuracy
            : null;

    // Update position if accuracy of new point is better than that of the
    // current stay.
    final currentAccuracy = _currentStay!.accuracy ?? 1E300;
    final improvedAccuracy =
        (newAccuracy != null) && (newAccuracy < currentAccuracy);

    _currentStay = _currentStay!.copyWith(
      // endTime needs to be updated regardless of accuracy
      endTime: endTime,
      // Positional components updated only if accuracy is better.
      latitude: improvedAccuracy ? point.latitude : null,
      longitude: improvedAccuracy ? point.longitude : null,
      accuracy: improvedAccuracy ? newAccuracy : null,
    );
  }

  /// Output the [_currentStay] to the output sink (if it's not null), then
  /// resets [_currentStay] to [point].
  void _outputCurrentStayAndReset(GpsPoint point) {
    if (_currentStay != null) {
      _outputSink.add(_currentStay!);
    }

    if (point is GpsStay) {
      _currentStay = point.copyWith();
    } else {
      _currentStay = GpsStay.fromPoint(point,
          accuracy: point is GpsMeasurement ? point.accuracy : null);
    }
  }

  @override
  void close() {
    // If we have an active stay, this is the time to emit and reset it.
    if (_currentStay != null) {
      _outputSink.add(_currentStay!);
      _currentStay = null;
    }
  }
}
