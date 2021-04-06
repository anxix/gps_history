/// Provides parsing of a JSON stream as exported by Google location history
/// when the user requests an export of the stored data.
///
/// The amount of data in the JSON may be enormous (many hundreds of megabytes,
/// probably even into the gigabytes). This makes it unfeasible to parse it
/// completely in memory. Instead, the parsing will rely on knowledge about
/// the way the document is formatted and do a "dumb" linear parsing. If Google
/// changes the export format even without changing the actual represented JSON
/// structure, this can break the parser.
///
/// Here is an example chunk from the JSON file:
///
/// ```javascript
/// {
///    "timestampMs" : "1616788980015",
///    "latitudeE7" : 371395542,
///    "longitudeE7" : -79377067,
///    "accuracy" : 56,
///    "altitude" : 402,
///    "verticalAccuracy" : 3,
///    "activity" : [ {
///      "timestampMs" : "1616786618030",
///      "activity" : [ {
///        "type" : "STILL",
///        "confidence" : 100
///      } ]
///    } ]
/// ```
///
/// Another chunk, note that some fields may be absent in some records:
///
/// ```javascript
/// {
///  "locations" : [ {
///    "timestampMs" : "1378029160146",
///    "latitudeE7" : 523503757,
///    "longitudeE7" : 46482361,
///    "accuracy" : 14
///  }, {
///    "timestampMs" : "1378029161184",
///    "latitudeE7" : 523503755,
///    "longitudeE7" : 46482364,
///    "accuracy" : 11
///  }, {
/// ```
///
/// The relevant fields are, according to Google's specificatin:
/// * timestampMs: UTC, in milliseconds since 1/1/1970
/// * latitudeE7: latitude in E7 notation, i.e. round(degrees * 1E7)
/// * longitudeE7: longitude, same notation as latitude
/// * accuracy: in meters (int16)
/// * altitude: in meters

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:async';
import 'dart:convert';
import 'package:gps_history/gps_history.dart';

/// Parses successive lines and attempts to collect the complete information
/// to represent an individual point.
///
/// The object maintains an internal state with all information that's been
/// parsed so far. If then information is sent that seems to indicates a new
/// point definition, the parser makes a choice:
/// - if the current state is sufficient to define a point, a point is
///   created and returned
/// - otherwise it assumes that the previously provided information was not
///   in fact a correct point. The parser resets its internal state and
///   starts working on a new point (null is returned).
class PointParser {
  final _values = List<int?>.filled(5, null);
  static const int _indexTimestampMs = 0;
  static const int _indexLatitudeE7 = 1;
  static const int _indexLongitudeE7 = 2;
  static const int _indexAltitude = 3;
  static const int _indexAccuracy = 4;

  // Match things such as:
  // "key": "123"
  // key: -456
  // 'key' : '78'
  static const String _keyPattern = r'''\w+''';
  static final _keyRegExp = RegExp(_keyPattern);
  static const String _valuePattern = r'''(-?\d+)''';
  static final _valueRegExp = RegExp(_valuePattern);

  /// Points are defined if the minimum required information is provided
  /// (timestamp, latitude and longitude).
  bool get isUndefined =>
      ((timestampMs == null) || (latitudeE7 == null) || (longitudeE7 == null));

  bool get isAllNull => !_values.any((element) => element != null);

  // Getters for the properties.
  int? get timestampMs => _values[_indexTimestampMs];
  int? get latitudeE7 => _values[_indexLatitudeE7];
  int? get longitudeE7 => _values[_indexLongitudeE7];
  int? get altitude => _values[_indexAltitude];
  int? get accuracy => _values[_indexAccuracy];

  // Setters for the properties.
  set timestampMs(int? value) => _setValue(_indexTimestampMs, value);
  set latitudeE7(int? value) => _setValue(_indexLatitudeE7, value);
  set longitudeE7(int? value) => _setValue(_indexLongitudeE7, value);
  set altitude(int? value) => _setValue(_indexAltitude, value);
  set accuracy(int? value) => _setValue(_indexAccuracy, value);

  /// Sets an individual value in the [_values] list.
  ///
  /// If the value in question is currently already set, it means we've reached
  /// the next point before completing the previous one. Therefore reset the
  /// point state completely. This will happen because of some fields being
  /// used in the JSON for purposes other than denoting a complete element.
  /// In particular the timestampMs is also used in activity descriptions.
  void _setValue(int index, int? value) {
    if (_values[index] != null) {
      reset();
    }
    _values[index] = value;
  }

  /// Resets the internal parser state to completely null.
  void reset() {
    for (var i = 0; i < _values.length; i++) {
      _values[i] = null;
    }
  }

  /// Tries to update its fields based on information from the specified
  /// [line], which should come from a JSON file. Returns a new GpsPoint
  /// if it's determined based on the new [line] that the previous information
  /// it contained was a valid point, or [null] otherwise.
  GpsPoint? parseUpdate(String line) {
    final keyMatch = _keyRegExp.firstMatch(line);
    if (keyMatch == null) {
      return null;
    }

    final key = keyMatch.input.substring(keyMatch.start, keyMatch.end);

    int index;
    if (key == 'timestampMs') {
      index = _indexTimestampMs;
    } else if (key == 'latitudeE7') {
      index = _indexLatitudeE7;
    } else if (key == 'longitudeE7') {
      index = _indexLongitudeE7;
    } else if (key == 'altitude') {
      index = _indexAltitude;
    } else if (key == 'accuracy') {
      index = _indexAccuracy;
    } else {
      return null;
    }

    // Usually if the key looks valid, the value will also look valid. Therefore
    // we only parse the value if the key is not just valid, but also is one of
    // the keys we're interested in. There are several keys in the JSON we're
    // not interested in, so we can save time dealing with the number part of
    // those.
    final valueMatch = _valueRegExp.firstMatch(line.substring(keyMatch.end));
    if (valueMatch == null) {
      return null;
    }

    final valueString =
        valueMatch.input.substring(valueMatch.start, valueMatch.end);

    int value;
    try {
      value = int.parse(valueString);
    } catch (e) {
      // Cannot really happen given the regex used to parse the string, but
      // since it turns out not to cost any performance, keep the safety.
      return null;
    }

    // If starting the definition of a new point and the current state looks
    // like a fully defined point, return the current state as result.
    final result = (_values[index] != null) && (!isUndefined)
        ? toGpsPointAndReset()
        : null;

    _setValue(index, value);

    return result;
  }

  /// Returns a GpsPoint representing the current internal state, if that state
  /// is sufficiently defined to represent such a point (null otherwise). The
  /// internal state is reset by this operation.
  ///
  /// The returned point may be GpsPoint if no accuracy is present in the
  /// current state, or GpsMeasurement if the accuracy is present.
  GpsPoint? toGpsPointAndReset() {
    if (isUndefined) {
      reset();
      return null;
    }

    var p = GpsPoint(DateTime.fromMillisecondsSinceEpoch(timestampMs!).toUtc(),
        latitudeE7! / 1E7, longitudeE7! / 1E7, altitude?.toDouble());

    // If we have accuracy specified, return a GpsMeasurement object that's
    // capable of storing accuracy information.
    if (accuracy != null) {
      p = GpsMeasurement.fromPoint(p, accuracy!.toDouble(), null, null, null);
    }

    reset();
    return p;
  }
}

/// Decoder for a stream of text from a Google JSON file to a stream of
/// GpsPoint instances.
///
/// Although the stream may contain information about accuracy, this is
/// deemed insufficiently important to store in the converted data, particularly
/// given the huge amount involved and that the rest of the GpsMeasurement
/// fields are not present. For the purpose of this data, namely show global
/// historic position information, the accuracy etc. should not be of great
/// importance.
class GoogleJsonHistoryDecoder extends Converter<String, GpsPoint> {
  double? _minSecondsBetweenDataponts;
  double? _accuracyThreshold;

  /// Create the decoder with optional configuration parameters that can filter
  /// out undesired points, reducing the amount of data.
  ///
  /// Specify [minSecondsBetweenDatapoints] to any non-null value to ensure that
  /// consecutive GPS points are at least that many seconds apart. If null,
  /// time from previous emitted point will not be a reason to skip a point.
  /// Google's data tracks at 1 second intervals, which is rather ridiculously
  /// granular and can generate over 5 million data points in 10 years.
  /// An interval of 10 seconds cuts that down tremendously, at no great loss
  /// for the purpose intended.
  ///
  /// Specify [accuracyThreshold] to any non-null value to skip an points
  /// that don't have an accuracy better that the threshold. If null, the
  /// accuracy will not be a reason to skip a point.
  GoogleJsonHistoryDecoder(
      {double? minSecondsBetweenDatapoints = 10,
      double? accuracyThreshold = 100}) {
    _minSecondsBetweenDataponts = minSecondsBetweenDatapoints;
    _accuracyThreshold = accuracyThreshold;
  }

  @override
  Stream<GpsPoint> bind(Stream<String> inputStream) {
    // split the string into lines
    final linesStream = inputStream.transform(LineSplitter());
    return Stream.eventTransformed(
        linesStream,
        (EventSink<GpsPoint> outputSink) =>
            _GpsPointParserEventSink(outputSink));
  }

  @override
  GpsPoint convert(String line, [int start = 0, int? end]) {
    // There's no guarantee that inputting a line would output a GpsPoint,
    // so this method seems rather difficult to implement.
    throw UnsupportedError('Not yet implemented convert: $this');
  }

  @override
  Sink<String> startChunkedConversion(Sink<GpsPoint> outputSink) {
    return _GpsPointParserSink(outputSink);
  }
}

/// Sink for converting *entire* lines from a Google JSON file to GPS points.
class _GpsPointParserSink extends StringConversionSinkBase {
  final Sink<GpsPoint> _outputSink;
  final _pointParser = PointParser();

  _GpsPointParserSink(this._outputSink);

  /// [str] must be one single line from a Google JSON file.
  @override
  void addSlice(String str, int start, int end, bool isLast) {
    // Skip invalid or empty strings while parsing.
    if (start < end) {
      var point = _pointParser.parseUpdate(str.substring(start, end));
      if (point != null) {
        _outputSink.add(point);
      }
    }

    if (isLast) {
      close();
    }
  }

  @override
  void close() {
    // The parser probably still contains information on a last, not yet
    // emitted point.
    var point = _pointParser.toGpsPointAndReset();
    if (point != null) {
      _outputSink.add(point);
    }
    _outputSink.close();
  }
}

class _GpsPointParserEventSink extends _GpsPointParserSink
    implements EventSink<String> {
  final EventSink<GpsPoint> _eventOutputSink;

  _GpsPointParserEventSink(EventSink<GpsPoint> eventOutputSink)
      : _eventOutputSink = eventOutputSink,
        super(eventOutputSink);

  @override
  void addError(Object o, [StackTrace? stackTrace]) {
    _eventOutputSink.addError(o, stackTrace);
  }
}
