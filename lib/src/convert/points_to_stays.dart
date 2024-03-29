/// Offers conversion facilities that can take a stream of GPS items and squeeze
/// that stream by removing duplication or converting multiple consecutive
/// items in the same location to to a [GpsStay].

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:convert';

import '../base.dart';
import '../utils/distance.dart';
import '../utils/time.dart';

/// Decoder that merges entities in a source stream to [GpsStay] entities, which
/// will typically reduce the total number of entries in the stream
/// significantly.
class PointsToStaysDecoder extends Converter<GpsPointWithAccuracy, GpsStay> {
  final int? _maxTimeGapSeconds;
  final double? _maxDistanceGapMeters;

  PointsToStaysDecoder({int? maxTimeGapSeconds, double? maxDistanceGapMeters})
      : _maxTimeGapSeconds = maxTimeGapSeconds,
        _maxDistanceGapMeters = maxDistanceGapMeters;

  /// The [convert] method cannot be called, because [input] may generate any
  /// number of [GpsStay] entities, which can therefore not be returned as
  /// one single result.
  @override
  GpsStay convert(GpsPointWithAccuracy input) {
    // This method doesn't really make sense, because the input may end up
    // generating more than one GpsStay.
    throw UnimplementedError();
  }

  @override
  Sink<GpsPointWithAccuracy> startChunkedConversion(Sink<GpsStay> sink) {
    return _GpsPointsToStaysSink(sink,
        maxTimeGapSeconds: _maxTimeGapSeconds,
        maxDistanceGapMeters: _maxDistanceGapMeters);
  }
}

/// Sink for converting chunks of [GpsPoint] or child classes to [GpsStay].
class _GpsPointsToStaysSink
    extends ChunkedConversionSink<GpsPointWithAccuracy> {
  /// Target for the identified [GpsStay] instances.
  final Sink<GpsStay> _outputSink;

  late PointMerger merger;

  _GpsPointsToStaysSink(this._outputSink,
      {int? maxTimeGapSeconds, double? maxDistanceGapMeters}) {
    merger = PointMerger(_outputSink.add,
        maxTimeGapSeconds: maxTimeGapSeconds,
        maxDistanceGapMeters: maxDistanceGapMeters);
  }

  @override
  void add(chunk) {
    merger.addPoint(chunk);
  }

  @override
  void close() {
    merger.close();
    _outputSink.close();
  }
}

/// Tool for merging multiple points that are adjacent in space and time into
/// a single stay of extended duration.
///
/// Make sure to call the [close] method after the last point added to
/// [PointMerger] in order to report the last tracked stay as a merge result.
class PointMerger {
  /// The current reference location to which any new points may either be
  /// merged, or that may be output as a merge result if an incoming point is
  /// too far removed in space and/or time.
  GpsStay? _currentStay;

  /// Function that will be called once a merged item has been identified and
  /// finalized, typically the add() method of an output sink.
  final void Function(GpsStay) reportMergeResult;

  /// Maximum amount of time in seconds between two measurements that are still
  /// allowed to be merged into one stay. This is because the data may contain
  /// huge time gaps during which no recording was performed.
  final int _maxTimeGapSeconds;

  /// Maximum distance between two measurements that are still allowed to be
  /// merged into one stay.
  final double _maxDistanceGapMeters;

  PointMerger(this.reportMergeResult,
      {int? maxTimeGapSeconds, double? maxDistanceGapMeters})
      : _maxTimeGapSeconds = maxTimeGapSeconds ?? GpsTime.resolutionSeconds,
        _maxDistanceGapMeters = maxDistanceGapMeters ?? 1.0;

  void addPoint(GpsPoint point) {
    final rt = point.runtimeType;

    // Make sure we're not dealing with an unsupported type.
    if (rt != GpsPoint &&
        rt != GpsPointWithAccuracy &&
        rt != GpsStay &&
        rt != GpsMeasurement) {
      throw TypeError();
    }

    _processPoint(point);
  }

  void _processPoint(GpsPoint point) {
    // Handle initial state: no stay yet, accept whatever comes in as initial.
    if (_currentStay == null) {
      _outputCurrentStayAndReset(point);
      return;
    }

    // We have some previous stay state -> requires checking times and mutual
    // distances.

    // If point is not after or time-identical to currentStay (this should
    // typically not happen, but it's not forbidden as such), it cannot be
    // merged. Conceptually it might be possible to merge two overlapping stays,
    // but it's not worth the hassle.
    final timeComparison = comparePointTimes(_currentStay!, point);
    if (timeComparison != TimeComparisonResult.before &&
        timeComparison != TimeComparisonResult.same) {
      // The current stay is finished -> output it and start a new one.
      _outputCurrentStayAndReset(point);
      return;
    }

    // If the current and new position are not sufficiently close together
    // in terms of time and space, output the current position and set point
    // as current stay.
    if (point.time.difference(_currentStay!.endTime) >= _maxTimeGapSeconds ||
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
    final endTime = point.endTime;

    var newAccuracy = point is GpsPointWithAccuracy ? point.accuracy : null;

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
      altitude: improvedAccuracy ? point.altitude : null,
      accuracy: improvedAccuracy ? newAccuracy : null,
    );
  }

  /// Reports [_currentStay] (if it's not null) as result, then resets
  /// [_currentStay] to [point].
  void _outputCurrentStayAndReset(GpsPoint point) {
    if (_currentStay != null) {
      reportMergeResult(_currentStay!);
    }

    if (point is GpsStay) {
      _currentStay = point.copyWith();
    } else {
      _currentStay = GpsStay.fromPoint(point,
          accuracy: point is GpsPointWithAccuracy ? point.accuracy : null);
    }
  }

  /// Method to be called at the end of the processing, in order to make sure
  /// any last stay entity is reported as merge result as well.
  void close() {
    // If we have an active stay, this is the time to emit and reset it.
    if (_currentStay != null) {
      reportMergeResult(_currentStay!);
      _currentStay = null;
    }
  }
}
