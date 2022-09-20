import 'hash.dart';

/// Utilities for dealing with time related tasks.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/// Used as result type for time comparison.
///
/// The enumeration values of [before], [same] and [after] are self-explanatory.
/// [overlapping] is used in situations where the compared times are time
/// spans rather than moments, meaning that the time spans may overlap partially
/// or completely.
enum TimeComparisonResult {
  before,
  same,
  after,
  overlapping,
}

/// Compares two time values and returns the result.
///
/// If [timeA] is considered before [timeB], the result
/// will be [TimeComparisonResult.before], etc.
TimeComparisonResult compareTime(GpsTime timeA, GpsTime timeB) {
  // TODO: this is sensitive to below-second differences, which the Int representation is not. This needs addressing.
  return compareIntRepresentationTime(
      timeA.secondsSinceEpoch, timeB.secondsSinceEpoch);
}

/// Compares two time values and returns the result.
///
/// If [timeA] is considered before [timeB], the result
/// will be [TimeComparisonResult.before], etc.
TimeComparisonResult compareIntRepresentationTime(int timeA, int timeB) {
  if (timeA < timeB) {
    return TimeComparisonResult.before;
  } else if (timeA == timeB) {
    return TimeComparisonResult.same;
  } else {
    // timeA > timeB
    return TimeComparisonResult.after;
  }
}

/// Compares time spans representing for example two [GpsStay] entities.
///
/// Comparison must be defined such that comparing A to B gives the opposite
/// result than comparing B to A for the before/after results, but it gives
/// the same result for the same/overlapping results. Without this
/// inverse commutative behaviour, sorting and searching may give very
/// strange behaviour.
///
/// The following preconditions are given:
/// - for any item X: X.start <= X.end
///   Hence it's not needt to check for inverted time segments.
/// - the stay is defined as being exclusive of X.end itself. That means
///   that for two points M and N with M.end = N.start, M can be regarded
///   as being before N (there is no overlap since at the moment of M.end,
///   i.e. N.start, the position value of N will be valid). However,
///   if M.start == M.end == N.start, there is overlap as both the position
///   of M and that of N are valid at time M.start.
///
/// the comparison is defined as follows:
/// ```
/// -----------+------------------------+----------------------------------
/// Rule       | Condition              | Result
/// -----------+------------------------+----------------------------------
/// 1)      if | (A.end <= B.start &&   | A before B
///            |  A.start != B.start)   |
///            |                        |
///            |   A +---+              |
///            |           B +---+      |
///            |                        |
///            |   A +---+              |
///            |       B +---+          |
/// -----------+------------------------+----------------------------------
/// 2) else if | (B.end <= A.start &&   | A after B (inverse of rule 1)
///            |  A.start != B.start)   |
///            |                        |
///            |   B +---+              |
///            |           A +---+      |
///            |                        |
///            |   B +---+              |
///            |       A +---+          |
/// -----------+------------------------+----------------------------------
/// 3) else if | (A.start == B.start && | A same as B
///            |  A.end == B.end)       |
///            |                        |
///            |   A +---+              |
///            |   B +---+              |
///            |                        |
/// -----------+------------------------+----------------------------------
/// 4) else    |                        | overlapping (undefined sorting)
///            |   B +---+              |
///            |      A +---+           |
///            |                        |
///            |   A +---+              |
///            |      B +---+           |
///            |                        |
///            |                        |
///            |   A +                  |
///            |   B +---+              |
///            |                        |
///            |   B +                  |
///            |   A +---+              |
///            |                        |
/// -----------+------------------------+----------------------------------
/// ```
TimeComparisonResult compareTimeSpans(
    {required int startA,
    required int endA,
    required int startB,
    required int endB}) {
  final sameStartAB = startA == startB;

  // Rule 1.
  final cmpEndAStartB = compareIntRepresentationTime(endA, startB);
  if ((cmpEndAStartB == TimeComparisonResult.same ||
          cmpEndAStartB == TimeComparisonResult.before) &&
      !sameStartAB) {
    return TimeComparisonResult.before;
  }

  // Rule 2.
  final cmpEndBStartA = compareIntRepresentationTime(endB, startA);
  if ((cmpEndBStartA == TimeComparisonResult.same ||
          cmpEndBStartA == TimeComparisonResult.before) &&
      !sameStartAB) {
    return TimeComparisonResult.after;
  }

  // Rule 3.
  final sameEndAB = endA == endB;
  if (sameEndAB) {
    return TimeComparisonResult.same;
  }

  // Rule 4.
  return TimeComparisonResult.overlapping;
}

/// Represents a time value for [GpsPoint] and children.
///
/// Time is internally stored as UTC with accuracy level of 1 second, counted
/// since the epoch (1970).
class GpsTime {
  /// Number of seconds sinds the epoch (UTC).
  final int secondsSinceEpoch;

  static const secondsPerMinute = 60;
  static const minutesPerHour = 60;
  static const secondsPerHour = secondsPerMinute * minutesPerHour;
  static const hoursPerDay = 24;
  static const secondsPerDay = secondsPerHour * hoursPerDay;
  static const minutesPerday = minutesPerHour * hoursPerDay;

  /// Checks that the specified value is valid for [secondsSinceEpoch] and
  /// throws a [RangeError] if that is not the case, returns it otherwise.
  static int _validateSecondsSinceEpoch(int value) {
    if (value < 0 || maxSecondsSinceEpoch < value) {
      throw RangeError('Invalid time specified: $value');
    }
    return value;
  }

  /// Constructor.
  ///
  /// Will throw [RangeError] if called with an out-of-range argument.
  GpsTime(int secondsSinceEpoch)
      : secondsSinceEpoch = _validateSecondsSinceEpoch(secondsSinceEpoch);

  /// Factory constructor from number of [milliseconds] since the epoch.
  factory GpsTime.fromMillisecondsSinceEpochUtc(int milliseconds) {
    return GpsTime((milliseconds / 1000).round());
  }

  /// Factory constructor from a [DateTime] object.
  factory GpsTime.fromDateTime(DateTime dateTime) {
    return GpsTime.fromMillisecondsSinceEpochUtc(
        dateTime.millisecondsSinceEpoch);
  }

  /// Factory constructor from a UTC date specified by [year] and optionally
  /// [month], [day], [hour], [minute] and [second].
  factory GpsTime.fromUtc(int year,
      [int month = 1,
      int day = 1,
      int hour = 0,
      int minute = 0,
      int second = 0]) {
    final dateTime = DateTime.utc(year, month, day, hour, minute, second);
    return GpsTime.fromDateTime(dateTime);
  }

  /// Returns a new [GpsTime] that is [days], [hours], [minutes] and [seconds]
  /// later than the current one.
  GpsTime add({
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
  }) {
    return GpsTime(secondsSinceEpoch +
        seconds +
        secondsPerMinute * minutes +
        secondsPerHour * hours +
        secondsPerDay * days);
  }

  /// Calculates [this] - [other] and returns the outcome in seconds.
  int difference(GpsTime other) {
    return secondsSinceEpoch - other.secondsSinceEpoch;
  }

  /// The DateTime that is regarded as zero.
  static final zeroDateTime = DateTime.utc(1970);

  /// Maximum allowed seconds since epoch, so that the value fits in an Uint32.
  /// The -1 is to allow the storage system to use that for null representations.
  static final maxSecondsSinceEpoch = 0xffffffff.toUnsigned(32) - 1;

  /// A quasi-constant zero [GpsTime].
  static final zero = GpsTime(0);

  /// Wrapper method for [compareTime].
  TimeComparisonResult compareTo(GpsTime other) {
    return compareTime(this, other);
  }

  /// Returns true if [this] is after [other].
  bool isAfter(GpsTime other) {
    return secondsSinceEpoch > other.secondsSinceEpoch;
  }

  /// Returns true if [this] is before [other].
  bool isBefore(GpsTime other) {
    return secondsSinceEpoch < other.secondsSinceEpoch;
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return other is GpsTime && other.secondsSinceEpoch == secondsSinceEpoch;
  }

  @override
  int get hashCode => hash2(super.hashCode, secondsSinceEpoch);
}
