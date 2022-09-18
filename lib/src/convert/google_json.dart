/// Provides parsing of a JSON stream as exported by Google location history
/// when the user requests an export of the stored data.
///
/// The amount of data in the JSON may be enormous (many hundreds of megabytes,
/// probably even into the gigabytes). This makes it unfeasible to parse it
/// completely in memory, especially when thinking about mobile devices.
/// Instead, the parsing will rely on knowledge about the way the document is
/// formatted as well as potential fields, and do a "dumb" linear parsing. If
/// Google changes the export format even without changing the actual
/// represented JSON structure, this can potentially break the parser.
///
/// Here is an example chunk from the JSON file:
///
/// ```javascript
/// {
///    "timestampMs" : "1716788980015",
///    "latitudeE7" : 361395542,
///    "longitudeE7" : -69377067,
///    "accuracy" : 56,
///    "altitude" : 432,
///    "verticalAccuracy" : 3,
///    "activity" : [ {
///      "timestampMs" : "1716788990015",
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
///    "timestampMs" : "1378729140146",
///    "latitudeE7" : 514503757,
///    "longitudeE7" : 47482361,
///    "accuracy" : 14
///  }, {
///    "timestampMs" : "1379029161184",
///    "latitudeE7" : 523603755,
///    "longitudeE7" : 45682364,
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
import 'dart:math';
import 'package:gps_history/gps_history.dart';

const _charDoubleQuote = 34;
const _charMinus = 45;
const _char0 = 48;
const _char7 = 55;
const _char9 = 57;
const _charUpperA = 65;
const _charUpperZ = 90;
const _charLowerA = 97;
const _charLowerC = 99;
const _charLowerL = 108;
const _charLowerS = 115;
const _charLowerT = 116;
const _charLowerZ = 122;

/// Parses a the List<int> instances emitted by a stream and attempts to collect
/// the complete information to represent individual points.
///
/// The object maintains an internal state with all information that's been
/// parsed so far. If then information is sent that seems to indicates a new
/// point definition, the parser makes a choice:
/// - if the current state is sufficient to define a point, a point is
///   created and returned
/// - otherwise it assumes that the previously provided information was not
///   in fact a correct point. The parser resets its internal state and
///   starts working on a new point. No point is returned.
class PointParser {
  /// Function called when a point has been identified (typically a [Sink.add]
  /// accepting the points).
  final void Function(GpsPoint point) resultReporter;

  // Parameters for filtering out undesired data points. Not creating points
  // also saves time in the overall parsing.
  final double? _minSecondsBetweenDatapoints;
  final double? _accuracyThreshold;
  GpsPoint? _prevParsedPoint;

  /// The various values of points that we're interested in, as read so far.
  final _values = List<int?>.filled(5, null);
  static const int _indexUninterestingKey = -1;
  static const int _indexTimestampMs = 0;
  static const int _indexLatitudeE7 = 1;
  static const int _indexLongitudeE7 = 2;
  static const int _indexAltitude = 3; // altitude exported since ~2018-11-13
  static const int _indexAccuracy = 4;

  /// Current position of the parser in the bytes list.
  int pos = 0;

  /// Position up to which we've successfully parsed. This is where we should
  /// continue parsing with the next chunk of data from a stream, if the current
  /// chunk contained incomplete data to define a point.
  int? posStartNextStreamChunk;

  PointParser(this._minSecondsBetweenDatapoints, this._accuracyThreshold,
      this.resultReporter);

  @override
  String toString() {
    return '${_values[0]}\t${_values[1]}\t${_values[2]}\t${_values[3]}\t${_values[4]}';
  }

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

  /// Determine the position where the key identifier in the JSON line starts
  /// ("key" : value) format - i.e. after the opening quote.
  ///
  /// [lastPossibleStartOfKey] indicates what the last possible position is
  /// in [bytes] where a key may start. A key plus the required space for ending
  /// quotes, colon and the value of the key require a certain amount of space.
  /// If the [bytes] doesn't have enough space for that, we know for sure we
  /// won't be able to parse a key-value pair.
  bool _findStartOfKey(List<int> bytes, int lastPossibleStartOfKey) {
    for (var i = pos; i < lastPossibleStartOfKey; i++) {
      pos = i;
      final char = bytes[i];
      // Interested in characters between a and t (both inclusive) due to the
      // key names we wish to store.
      if (_charLowerA <= char && char <= _charLowerT) {
        return true;
      }
    }
    return false;
  }

  /// Returns the index in [_values] corresponding to the first found key
  /// starting at the current [pos], or null if such key is not found.
  ///
  /// All the keys used in a Google location export JSON file and their length,
  /// with the ' indicating the ones we're interested in, and " the ones that
  /// are mandatory for a valid definition:
  /// * accuracy : 8'
  /// * activity : 8
  /// * altitude : 8'
  /// * confidence : 10
  /// * heading : 7
  /// * latitudeE7 : 10"
  /// * locations : 9
  /// * longitudeE7 : 11"
  /// * timestampMs : 11"
  /// * type : 4
  /// * velocity : 8
  /// * verticalAccuracy : 16
  int? _getKeyIndex(List<int> bytes, int end) {
    // After the string we need enough space for the closing quote, a colon
    // and at least one digit, so we only need to scan up to end-(8+3);
    final lastPossibleStartOfKey = end - 11;

    final foundKey = _findStartOfKey(bytes, lastPossibleStartOfKey);
    if (!foundKey) {
      return null;
    }

    final currentChar = bytes[pos];
    // Deal with the "t" case.
    if (currentChar == _charLowerT && end >= pos + 12) {
      // If it ends in 's"', assume we've got timestampMs.
      if (bytes[pos + 10] == _charLowerS &&
          bytes[pos + 11] == _charDoubleQuote) {
        pos += 12;
        return _indexTimestampMs;
      }
    } else if (currentChar == _charLowerL) {
      // Deal with the "l" case. Might be "latitudeE7" or "longitudeE7".
      if (end > pos + 10 &&
          bytes[pos + 9] == _char7 &&
          bytes[pos + 10] == _charDoubleQuote) {
        pos += 11;
        return _indexLatitudeE7;
      } else if (end > pos + 11 &&
          bytes[pos + 10] == _char7 &&
          bytes[pos + 11] == _charDoubleQuote) {
        pos += 12;
        return _indexLongitudeE7;
      }
    } else if (currentChar == _charLowerA) {
      // Interested in "accuracy" or "altitude", but "activity" may also occur
      // and should be excluded by the matching.
      if (end > pos + 8 && bytes[pos + 8] == _charDoubleQuote) {
        // It's indeed a string of 8 characters. Find out which of the three.
        if (bytes[pos + 1] == _charLowerL) {
          pos += 9;
          return _indexAltitude;
        } else if (bytes[pos + 2] == _charLowerC) {
          pos += 9;
          return _indexAccuracy;
        }
      }
    }

    // We are at some kind of identifier, but not one of the expected ones.
    // In order to continue parsing, we must skip this itentifier and go to
    // the next one.
    for (var i = pos + 1; i < lastPossibleStartOfKey; i++) {
      pos = i;
      final char = bytes[i];
      // Identifiers consist of [0..9, A..Z, a..z], so skip to first character
      // after one of those.
      if (!(_char0 <= char && char <= _char9 ||
          _charUpperA <= char && char <= _charUpperZ ||
          _charLowerA <= char && char <= _charLowerZ)) {
        break;
      }
    }

    return _indexUninterestingKey;
  }

  /// Returns the string representing the value in a JSON ("key" : value)
  /// string.
  ///
  /// The value must be a number, possibly negative, possibly wrapped between
  /// double quotes. [pos] indicates where to start looking in [bytes] for the
  /// value part.
  String? _parseValueString(List<int> bytes, int end) {
    // Skip ahead to digits or minus sign.
    String? valueString;
    for (var i = pos; i < end; i++) {
      final cu = bytes[i];
      // Interested in characters between 0 and 9 (both inclusive), or -
      if ((_char0 <= cu && cu <= _char9) || cu == _charMinus) {
        pos = i;
        var numberEnd = pos + 1;
        // Find the end of the number (first non-digit).
        for (var lastDigitPos = i + 1; lastDigitPos < end; lastDigitPos++) {
          final digitCandidate = bytes[lastDigitPos];
          if (digitCandidate < _char0 || _char9 < digitCandidate) {
            break;
          } else {
            numberEnd = lastDigitPos + 1;
          }
        }

        // If the number ends at the end of the bytes, we don't know if this
        // is truly the end of the number - possibly the next chunk of stream
        // will provide more digits. Therefore reject it in that case.
        // Since the JSON will contain an object, we know for sure the file
        // cannot possibly end in a digit, but rather in "}".
        if (numberEnd != end) {
          valueString = String.fromCharCodes(bytes, pos, numberEnd);
          pos = numberEnd;
        }
        break;
      }
    }

    return valueString;
  }

  /// Tries to update its fields based on information from the specified
  /// [bytes], which should come from a JSON file. Creates and sends new points
  /// to [resultReporter] when such fully defined points are detected.
  ///
  /// Valid JSON input will have forms like:
  /// * "key": -456
  /// * "key": "123"
  /// * 'key' : '78'
  ///
  /// The implementation is very much aimed at specifically the way the Google
  /// location history export looks, rather than being a generic JSON parser.
  /// This makes it possible to optimize it a lot in terms of speed and memory
  /// usage, at the expense of legibility.
  void parseUpdate(List<int> bytes, int start, int end) {
    pos = start;
    posStartNextStreamChunk = null; // indicates we haven't parsed anything
    var prevLoopStartPos = -1;
    while (pos < end) {
      // If we're just spinning our wheels, stop.
      if (pos == prevLoopStartPos) {
        break;
      }
      prevLoopStartPos = pos;

      // Find first key we're interested in.
      final index = _getKeyIndex(bytes, end);
      if (index == _indexUninterestingKey) {
        // Even if the key is not interesting, it is correctly parsed and
        // doesn't need to be parsed again if it happens to be towards the
        // end of [bytes] and the next chunk will be appended.
        posStartNextStreamChunk = pos;
        continue;
      }
      if (index == null) {
        continue;
      }

      // Get the key's value
      final valueString = _parseValueString(bytes, end);
      if (valueString == null) {
        break;
      }
      // Remember the position, because if we don't find a proper value in the
      // next loop, that may be because the stream is split at an unfortunate
      // place (e.g. between a key and its value, or in the middle of a key or
      // something like that). The part after the current, known correct,
      // key-value pair may need to be re-parsed including additional information
      // from the next chunk of the stream providing our [bytes].
      posStartNextStreamChunk = pos;

      final value = int.tryParse(valueString);
      if (value == null) {
        // Cannot really happen given the parsing method, but just in case.
        continue;
      }

      // If starting the definition of a new point and the current state looks
      // like a fully defined point, report the current state.
      if (_values[index] != null && !isUndefined) {
        toGpsPointAndReset();
      }

      _setValue(index, value);
    }
  }

  /// Creates and adds a point representing the current internal state to
  /// [resultReporter], if the current state is sufficiently defined to
  /// represent such a point. The internal state is consequently reset, whether
  /// a point was created or not.
  ///
  /// The returned point may be [GpsPoint] if no accuracy is present in the
  /// current state, or [GpsMeasurement] if the accuracy is present.
  void toGpsPointAndReset() {
    if (isUndefined) {
      reset();
      return;
    }

    var time = DateTime.fromMillisecondsSinceEpoch(timestampMs!, isUtc: true);

    if (_prevParsedPoint != null &&
        _minSecondsBetweenDatapoints != null &&
        time.difference(_prevParsedPoint!.time).inSeconds <=
            _minSecondsBetweenDatapoints!) {
      // Don't do anything, we don't want this point.
    } else if (_accuracyThreshold != null &&
        _values[_indexAccuracy] != null &&
        _values[_indexAccuracy]! > _accuracyThreshold!) {
      // Don't do anything, we don't want this point.
    } else {
      // We do want this point -> create and report it.
      var p = GpsPoint(
          time: time,
          latitude: latitudeE7! / 1E7,
          longitude: longitudeE7! / 1E7,
          altitude: altitude?.toDouble());

      // If we have accuracy specified, return a GpsMeasurement object that's
      // capable of storing accuracy information.
      if (accuracy != null) {
        p = GpsMeasurement.fromPoint(p, accuracy: accuracy!.toDouble());
      }

      _prevParsedPoint = p;
      resultReporter(p);
    }

    reset();
  }
}

/// An exception thrown if the JSON parsing goes wrong in an unrecoverable way.
class JsonParseException extends GpsHistoryException {
  JsonParseException([String? message]) : super(message);
}

/// Decoder for a stream of bytes from a Google location history JSON file to
/// a stream of [GpsPoint] and/or [GpsMeasurement] instances.
class GoogleJsonHistoryDecoder extends Converter<List<int>, GpsPoint> {
  double? _minSecondsBetweenDatapoints;
  double? _accuracyThreshold;

  /// Create the decoder with optional configuration parameters that can filter
  /// out undesired points, reducing the amount of data.
  ///
  /// Specify [minSecondsBetweenDatapoints] to any non-null value to ensure that
  /// consecutive GPS points are at least that many seconds apart. If null,
  /// time from previous emitted point will not be a reason to skip a point.
  /// Google's data tracks at a median of 1 minute intervals, which is rather
  /// granular and can generate over 5 million data points in 10 years.
  /// An interval of 10 minutes cuts that down tremendously, at no great loss
  /// for the purpose intended.
  ///
  /// Specify [accuracyThreshold] to any non-null value to skip any points
  /// that don't have an accuracy better that the threshold. If null, the
  /// accuracy will not be a reason to skip a point.
  GoogleJsonHistoryDecoder(
      {double? minSecondsBetweenDatapoints, double? accuracyThreshold}) {
    _minSecondsBetweenDatapoints = minSecondsBetweenDatapoints;
    _accuracyThreshold = accuracyThreshold;
  }

  @override
  Stream<GpsPoint> bind(Stream<List<int>> stream) {
    return Stream.eventTransformed(
        stream,
        (EventSink<GpsPoint> outputSink) => _GpsPointParserEventSink(
            outputSink, _minSecondsBetweenDatapoints, _accuracyThreshold));
  }

  /// Override [Converter.convert] that returns the last point that is fully
  /// defined by the [bytes].
  ///
  /// There's no guarantee that inputting a stream will indeed contain at least
  /// one [GpsPoint]. If no point is found, the method will raise a
  /// [JsonParseException], since the interface disallows returning a nullable.
  @override
  GpsPoint convert(List<int> bytes, [int start = 0, int? end]) {
    GpsPoint? result;
    var passthroughSink = _PassthroughSink((point) {
      result = point;
    });
    var parserSink = _GpsPointParserSink(
        passthroughSink, _minSecondsBetweenDatapoints, _accuracyThreshold);

    // Decide how far we need to parse.
    end = end ?? bytes.length;
    // If it's not the whole [bytes], create a new list with the relevant part.
    if (end < bytes.length) {
      parserSink.add(List<int>.from(bytes.getRange(start, end)));
    } else {
      // Whole [bytes] => pass it on directly.
      parserSink.add(bytes);
    }
    parserSink.close();

    if (result != null) {
      return result!;
    } else {
      throw JsonParseException('Unable to parse point from specified bytes');
    }
  }

  @override
  Sink<List<int>> startChunkedConversion(Sink<GpsPoint> sink) {
    return _GpsPointParserSink(
        sink, _minSecondsBetweenDatapoints, _accuracyThreshold);
  }
}

/// Simple sink to make the [GoogleJsonHistoryDecoder.convert]
/// implementation possible. Translates [add] to a call to a [_wrappedFunction].
class _PassthroughSink extends Sink<GpsPoint> {
  final void Function(GpsPoint point) _wrappedFunction;

  _PassthroughSink(this._wrappedFunction);

  @override
  void add(GpsPoint point) {
    _wrappedFunction(point);
  }

  @override
  void close() {
    // Nothing to do.
  }
}

/// Sink for converting chunks of data from Google location history JSON file to
/// GPS points.
class _GpsPointParserSink extends ChunkedConversionSink<List<int>> {
  final Sink<GpsPoint> _outputSink;

  PointParser? _pointParser;

  final _leftoverChunk = <int>[];

  _GpsPointParserSink(this._outputSink, double? minSecondsBetweenDatapoints,
      double? accuracyThreshold) {
    _pointParser = PointParser(minSecondsBetweenDatapoints, accuracyThreshold,
        (GpsPoint point) => _outputSink.add(point));
  }

  @override
  void add(List<int> chunk) {
    const overlapBetweenChunks = 521;

    int? pos;

    final originalLeftoverBytes = _leftoverChunk.length;
    if (_leftoverChunk.isNotEmpty) {
      // Get enough bytes from the new chunk to be guaranteed to finish parsing
      // whatever was left over from previous chunk.
      _leftoverChunk
          .addAll(chunk.getRange(0, min(chunk.length, overlapBetweenChunks)));
      _pointParser!.parseUpdate(_leftoverChunk, 0, _leftoverChunk.length);
      if (_pointParser!.posStartNextStreamChunk != null) {
        // Because we copied part of the new chunk to the leftover, that's been
        // already parsed -> don't reparse.
        pos = _pointParser!.posStartNextStreamChunk! - originalLeftoverBytes;
        _leftoverChunk.clear();
      } else {
        // Pathological situation where the previous chunk is not parsed
        // completely, but the new chunk doesn't contain enough information to
        // finish parsing. Just add the whole chunk to the leftovers and leave
        // it to the next run to figure it out.
        _leftoverChunk.addAll(chunk.getRange(
            _leftoverChunk.length - originalLeftoverBytes, chunk.length));
        return;
      }
    } else {
      pos = 0;
    }

    _pointParser!.parseUpdate(chunk, pos, chunk.length);
    // If we didn't parse anything at all, regard anything starting with pos
    // as leftover.
    var leftoverStart = _pointParser!.posStartNextStreamChunk ?? pos;
    // There are pathological cases that can force huge repeated copies with
    // ever increasing memory use. An example would be streaming in huge strings
    // of only spaces. In that case the leftover could grow and grow. Prevent
    // this by cutting off how much we're willing to copy at each run. This
    // may hurt correct parsing of very weirdly formatted JSON, but that's a
    // price we'll pay for not having this attack vector.
    leftoverStart = max(leftoverStart, chunk.length - overlapBetweenChunks);

    // Store leftover.
    if (leftoverStart <= chunk.length) {
      _leftoverChunk.addAll(chunk.getRange(leftoverStart, chunk.length));
    }
  }

  @override
  void close() {
    // Parse any leftover chunks (can mainly happen in incomplete malformed
    // JSON such as in unit tests). Make sure it doesn't stay malformed by
    // adding a space so it knows for sure it's the end of any final number.
    _leftoverChunk.add(32);
    _pointParser!.parseUpdate(_leftoverChunk, 0, _leftoverChunk.length);

    // The parser may still contain information on a last, not yet
    // emitted point.
    _pointParser!.toGpsPointAndReset();

    _outputSink.close();
  }
}

class _GpsPointParserEventSink extends _GpsPointParserSink
    implements EventSink<List<int>> {
  final EventSink<GpsPoint> _eventOutputSink;

  _GpsPointParserEventSink(EventSink<GpsPoint> eventOutputSink,
      double? minSecondsBetweenDatapoints, double? accuracyThreshold)
      : _eventOutputSink = eventOutputSink,
        super(eventOutputSink, minSecondsBetweenDatapoints, accuracyThreshold);

  @override
  void addError(Object o, [StackTrace? stackTrace]) {
    _eventOutputSink.addError(o, stackTrace);
  }
}
