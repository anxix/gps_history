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
class PointParserBin {
  final void Function(GpsPoint point) resultReporter;

  final _values = List<int?>.filled(5, null);
  static const int _indexTimestampMs = 0;
  static const int _indexLatitudeE7 = 1;
  static const int _indexLongitudeE7 = 2;
  static const int _indexAltitude = 3; // altitude exported since ~2018-11-13
  static const int _indexAccuracy = 4;

  int pos = 0;
  int posStartNextStreamChunk = 0;

  PointParserBin(this.resultReporter);

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
  /// [minLengthAfterKeyStart] indicates how many characters must at least
  /// be left over in the [bytes] after the start of the key in order to
  /// have enough space for ending quote, colon and numbers.
  bool _findStartOfKey(List<int> bytes, int lastPossibleStartOfKey) {
    for (var i = pos; i < lastPossibleStartOfKey; i++) {
      pos = i;
      final char = bytes[i];
      // Interested in characters between a and t (both inclusive).
      if (_charLowerA <= char && char <= _charLowerT) {
        return true;
      }
    }
    return false;
  }

  /// Returns the index of the first found key starting at the current [pos],
  /// or null if such key is not found.
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

    // Remember the last position, because if we don't find a proper value,
    // that may be because the stream is split at an unfortunate place (e.g.
    // between a key and its value, or in the middle of a key or something
    // like that), the part towards the end will need to be glued to the
    // next chunk from the stream.
//    posStartNextStreamChunk = pos;

    if (!foundKey) {
      return null;
    }

    final currentChar = bytes[pos];
    // TODO: maybe test the pos-1 for being doublequote
    // Deal with the "t" case.
    if (currentChar == _charLowerT && end >= pos + 12) {
      // If it ends in 's"', we assume we've got timestampMs.
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
      // Identifiers are [0..9, A..Z, a..z], so skip to first character
      // after one of those.
      if (!(_char0 <= char && char <= _char9 ||
          _charUpperA <= char && char <= _charUpperZ ||
          _charLowerA <= char && char <= _charLowerZ)) {
        break;
      }
    }
  }

  /// Returns the string representing the value in a JSON ("key" : value)
  /// string.
  ///
  /// The value must be a number, possibly negative, possibly wrapped between
  /// double quotes. [pos] indicates where to start looking in [line] for the
  /// value part.
  String? _parseValueString(List<int> line, int end) {
    // Skip ahead to digits or minus sign.
    var valueString;
    for (var i = pos; i < end; i++) {
      final cu = line[i];
      // Interested in characters between 0 and 9 (both inclusive), or -
      if ((_char0 <= cu && cu <= _char9) || cu == _charMinus) {
        pos = i;
        var endpos = pos + 1;
        // Find the end of the number (first non-digit).
        for (var digitsEnd = i + 1; digitsEnd < end; digitsEnd++) {
          final digitCandidate = line[digitsEnd];
          if (digitCandidate < _char0 || _char9 < digitCandidate) {
            break;
          } else {
            endpos = digitsEnd + 1;
          }
        }
        // If the number ends at the end of the bytes, we don't know if this
        // is truly the end of the number - possibly the enxt chunk of stream
        // will provide more digits. Therefore reject it in that case.
        // Since the JSON will contain an object, we know for sure the file
        // cannot possibly end in a digit, but rather in "}".
        if (endpos != end) {
          valueString = String.fromCharCodes(line, pos, endpos);
          pos = endpos;
          // Finished a successful key-value parse, so any continued parsing
          // can start from the current position.
//          posStartNextStreamChunk = pos;
        }
        break;
      }
    }

    return valueString;
  }

  /// Tries to update its fields based on information from the specified
  /// [bytes], which should come from a JSON file. Returns a new GpsPoint
  /// if it's determined based on the new [bytes] that the previous information
  /// it contained was a valid point, or [null] otherwise.
  ///
  /// Valid JSON input will have forms like:
  /// * "key": -456
  /// * "key": "123"
  /// * 'key' : '78'
  ///
  /// The implementation is very much aimed at specifically the way the Google
  /// location history export looks, rather than being a generic JSON parser.
  /// This makes it possible to optimize it a lot, at the expense of legibility.
  void parseUpdate(List<int> bytes, int start, int end) {
    pos = start;
    var prevLoopStartPos = -1;
    while (pos < end) {
      if (pos == prevLoopStartPos) {
        break;
      }
      prevLoopStartPos = pos;
      // See if we find any key we're interested in.
      final index = _getKeyIndex(bytes, end);
      if (index == null) {
        continue;
      }

      final valueString = _parseValueString(bytes, end);
      if (valueString == null) {
        break;
      }
      posStartNextStreamChunk = pos;

      final value = int.tryParse(valueString);
      if (value == null) {
        // Cannot really happen given the parsing method, but just in case.
        continue;
      }

      // If starting the definition of a new point and the current state looks
      // like a fully defined point, return the current state as result.
      if (_values[index] != null && !isUndefined) {
        toGpsPointAndReset();
      }

      _setValue(index, value);
    }
  }

  @override
  String toString() {
    return '${_values[0]}\t${_values[1]}\t${_values[2]}\t${_values[3]}\t${_values[4]}';
  }

  /// Returns a GpsPoint representing the current internal state, if that state
  /// is sufficiently defined to represent such a point (null otherwise). The
  /// internal state is reset by this operation.
  ///
  /// The returned point may be GpsPoint if no accuracy is present in the
  /// current state, or GpsMeasurement if the accuracy is present.
  void toGpsPointAndReset() {
    if (isUndefined) {
      reset();
      return null;
    }

    var p = GpsPoint(
        DateTime.fromMillisecondsSinceEpoch(timestampMs!, isUtc: true),
        latitudeE7! / 1E7,
        longitudeE7! / 1E7,
        altitude?.toDouble());

    // If we have accuracy specified, return a GpsMeasurement object that's
    // capable of storing accuracy information.
    if (accuracy != null) {
      p = GpsMeasurement.fromPoint(p, accuracy!.toDouble(), null, null, null);
    }

    reset();
    resultReporter(p);
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
class GoogleJsonHistoryDecoderBinary extends Converter<List<int>, GpsPoint> {
  double? _minSecondsBetweenDataponts;
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
  /// Specify [accuracyThreshold] to any non-null value to skip an points
  /// that don't have an accuracy better that the threshold. If null, the
  /// accuracy will not be a reason to skip a point.
  GoogleJsonHistoryDecoderBinary(
      {double? minSecondsBetweenDatapoints = 10,
      double? accuracyThreshold = 100}) {
    _minSecondsBetweenDataponts = minSecondsBetweenDatapoints;
    _accuracyThreshold = accuracyThreshold;
  }

  @override
  Stream<GpsPoint> bind(Stream<List<int>> inputStream) {
    return Stream.eventTransformed(
        inputStream,
        (EventSink<GpsPoint> outputSink) =>
            _GpsPointParserEventSinkBin(outputSink));
  }

  @override
  GpsPoint convert(List<int> line, [int start = 0, int? end]) {
    // There's no guarantee that inputting a line would output a GpsPoint,
    // so this method seems rather difficult to implement.
    throw UnsupportedError('Not yet implemented convert: $this');
  }

  @override
  Sink<List<int>> startChunkedConversion(Sink<GpsPoint> outputSink) {
    return _GpsPointParserSinkBin(outputSink);
  }
}

/// Sink for converting *entire* lines from a Google JSON file to GPS points.
class _GpsPointParserSinkBin extends ChunkedConversionSink<List<int>> {
  final Sink<GpsPoint> _outputSink;
  PointParserBin? _pointParser;
  final _leftoverChunk = <int>[];
  var leftoverChunk = 0;
  var callNr = 0;

  _GpsPointParserSinkBin(this._outputSink) {
    _pointParser = PointParserBin((GpsPoint point) => _outputSink.add(point));
  }

  /// [str] must be one single line from a Google JSON file.
  @override
  void add(List<int> chunk) {
    var pos = _leftoverChunk.length;
    if (_leftoverChunk.isNotEmpty) {
      // Get enough bytes from the new chunk to be guaranteed to finish parsing
      // whatever was left over from previous chunk.
      _leftoverChunk.addAll(chunk.getRange(0, min(chunk.length, 1000)));
      _pointParser!.parseUpdate(_leftoverChunk, 0, _leftoverChunk.length);
      // Because we copied part of the new chunk to the leftover, that's been
      // already parsed -> don't reparse.
      pos = _pointParser!.posStartNextStreamChunk - pos;

      _leftoverChunk.clear();
    }

    _pointParser!.parseUpdate(chunk, pos, chunk.length);

    _leftoverChunk.addAll(
        chunk.getRange(_pointParser!.posStartNextStreamChunk, chunk.length));
  }

  @override
  void close() {
    // Parse any leftover chunks.
    //_pointParser!.parseUpdate(_leftoverChunk, 0, _leftoverChunk.length);
    // The parser may still contain information on a last, not yet
    // emitted point.
    _pointParser!.toGpsPointAndReset();

    _outputSink.close();
  }
}

class _GpsPointParserEventSinkBin extends _GpsPointParserSinkBin
    implements EventSink<List<int>> {
  final EventSink<GpsPoint> _eventOutputSink;

  _GpsPointParserEventSinkBin(EventSink<GpsPoint> eventOutputSink)
      : _eventOutputSink = eventOutputSink,
        super(eventOutputSink);

  @override
  void addError(Object o, [StackTrace? stackTrace]) {
    _eventOutputSink.addError(o, stackTrace);
  }
}
