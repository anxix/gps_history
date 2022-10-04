/// Utilities for dealing with time related tasks.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'hash.dart';

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

/// Returns the opposite of [r].
TimeComparisonResult opposite(TimeComparisonResult r) {
  return r == TimeComparisonResult.after
      ? TimeComparisonResult.before // before is opposite of after
      : r == TimeComparisonResult.before
          ? TimeComparisonResult.after // after is opopsite of before
          : r; // same and overlapping are identical in inverse
}

/// Compares two time values and returns the result.
///
/// If [timeA] is considered before [timeB], the result
/// will be [TimeComparisonResult.before], etc.
TimeComparisonResult compareTime(GpsTime timeA, GpsTime timeB) {
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
///            |   A +-------+          |
///            |   B   +--+             |
///            |                        |
///            |   B +-------+          |
///            |   A   +--+             |
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
  if (sameStartAB && sameEndAB) {
    return TimeComparisonResult.same;
  }

  // Rule 4.
  return TimeComparisonResult.overlapping;
}

/// Like [diffIntTime], but with parameters provided in [GpsTime] rather than
/// directly as integers.
int diffTime(
    {required GpsTime startTimeA,
    required GpsTime? endTimeA,
    required GpsTime timeB}) {
  return diffIntTime(
    startTimeA: startTimeA.secondsSinceEpoch,
    endTimeA: endTimeA?.secondsSinceEpoch,
    timeB: timeB.secondsSinceEpoch,
  );
}

/// Calculates the difference between [timeB] and a time or time span
/// defined by a [startTimeA] and optionally, if it's a span rather than an
/// instance, an [endTimeA]. The result will be negative and equal to
/// [endTimeA]-[timeB] if A is before B, positive and equal to
/// [startTimeA]-[timeB] is A is after B.
///
///  Situation         | Result
/// -------------------+---------
///     A +--------+   | > 0
///   B +              |
/// -------------------+---------
///     A +--------+   | = 0
///     B +            |
///        B +         |
///              B +   |
/// -------------------+---------
///     A +--------+   | > 0
///                B + |
/// -------------------+---------
///
/// The result is zero if [timeB] is within the time span defined by the two "A"
/// parameters, even if it's equal to [endTimeA]. *This even though the
/// situation of [timeB]==[endTimeA] would not qualify as
/// [TimeComparisonResult.overlapping]!*. This inconsistency is rather hard to
/// avoid, as the infinitesimally small fraction of an instance prior to
/// [endTimeA] does count as/ overlapping - the difference is infinitely small
/// and can therefore not really be expressed in any way.
int diffIntTime(
    {required int startTimeA, required int? endTimeA, required int timeB}) {
  final startDiff = (startTimeA - timeB);
  if (endTimeA == null) {
    return startDiff;
  }

  final endDiff = (endTimeA - timeB);

  // B is within span A if startDiff is negative and endDiff is positive.
  if (0 > startDiff && endDiff > 0) {
    return 0;
  }

  // A is before B -> closest difference will be to the end point.
  if (endDiff <= 0) {
    return endDiff;
  }

  // A must be after B -> closest difference will be to the start point.
  return startDiff;
}

/// Represents a time value for [GpsPoint] and children.
///
/// Time is internally stored as UTC with accuracy level of 1 second, counted
/// since the epoch (1970).
class GpsTime {
  /// Number of seconds sinds the epoch (UTC).
  final int secondsSinceEpoch;

  static const resolutionSeconds = 1;

  /// Maximum allowed seconds since epoch, so that the value fits in an Uint32.
  /// The -1 is to allow the storage system to use that for null representations.
  static final maxSecondsSinceEpoch = 0xffffffff.toUnsigned(32) - 1;

  /// A quasi-constant zero [GpsTime].
  static final zero = GpsTime(0);

  static const secondsPerMinute = 60;
  static const minutesPerHour = 60;
  static const secondsPerHour = secondsPerMinute * minutesPerHour;
  static const hoursPerDay = 24;
  static const minutesPerday = minutesPerHour * hoursPerDay;
  static const secondsPerDay = secondsPerHour * hoursPerDay;

  /// Checks that the specified [value] is valid for [secondsSinceEpoch] and
  /// throws a [RangeError] if that is not the case, returns it otherwise.
  ///
  /// In order to get a version clamped within the boundaries instead of
  /// throwing an exception, use [_clampValidSecondsSinceEpoch].
  static int _validSecondsSinceEpochOrException(int value) {
    if (value < 0 || maxSecondsSinceEpoch < value) {
      throw RangeError('Invalid time specified: $value');
    }
    return value;
  }

  /// Checks that the specified [value] is valid for [secondsSinceEpoch] and
  /// clamps it to the lower/upper boundary if that's not the case,
  /// returning the potentially clamped value as result.
  ///
  /// In order to throw an exception in case of invalid [value] instead of
  /// clamping it, see [_validSecondsSinceEpochOrException].
  static int _clampValidSecondsSinceEpoch(int value) {
    return value < 0
        ? 0
        : value > maxSecondsSinceEpoch
            ? maxSecondsSinceEpoch
            : value;
  }

  /// Constructor.
  ///
  /// The [autoClamp] parameter indicates the behaviour in case of an value
  /// for [secondsSinceEpoch] that's outside the supported range:
  ///   - [autoClamp] = false: throw [RangeError] if out-of-range value given.
  ///   - [autoClamp] = true: clamp the value witin the allowed boundaries.
  GpsTime(int secondsSinceEpoch, {bool autoClamp = false})
      : secondsSinceEpoch = !autoClamp
            ? _validSecondsSinceEpochOrException(secondsSinceEpoch)
            : _clampValidSecondsSinceEpoch(secondsSinceEpoch);

  /// Factory constructor from number of [milliseconds] since the epoch.
  ///
  /// For [autoClamp] parameter see the standard [GpsTime] constructor.
  factory GpsTime.fromMillisecondsSinceEpochUtc(int milliseconds,
      {bool autoClamp = false}) {
    return GpsTime((milliseconds / 1000).round(), autoClamp: autoClamp);
  }

  /// Factory constructor from a [DateTime] object.
  ///
  /// For [autoClamp] parameter see the standard [GpsTime] constructor.
  factory GpsTime.fromDateTime(DateTime dateTime, {bool autoClamp = false}) {
    return GpsTime.fromMillisecondsSinceEpochUtc(
        dateTime.millisecondsSinceEpoch,
        autoClamp: autoClamp);
  }

  /// Factory constructor from a UTC date specified by [year] and optionally
  /// [month], [day], [hour], [minute] and [second].
  ///
  /// For [autoClamp] parameter see the standard [GpsTime] constructor.
  factory GpsTime.fromUtc(
    int year, {
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    bool autoClamp = false,
  }) {
    final dateTime = DateTime.utc(year, month, day, hour, minute, second);
    return GpsTime.fromDateTime(dateTime, autoClamp: autoClamp);
  }

  /// Returns a new [GpsTime] that is [days], [hours], [minutes] and [seconds]
  /// later than the current one.
  ///
  /// See the [GpsTime] default constructor for behaviour if the result is
  /// outside the valid range.
  ///
  /// For [autoClamp] parameter see the standard [GpsTime] constructor.
  GpsTime add({
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    bool autoClamp = false,
  }) {
    return GpsTime(
        secondsSinceEpoch +
            seconds +
            secondsPerMinute * minutes +
            secondsPerHour * hours +
            secondsPerDay * days,
        autoClamp: autoClamp);
  }

  /// Calculates [this] - [other] and returns the outcome in seconds.
  int difference(GpsTime other) {
    return secondsSinceEpoch - other.secondsSinceEpoch;
  }

  /// Wrapper method for [compareTime].
  TimeComparisonResult compareTo(GpsTime other) {
    return compareTime(this, other);
  }

  /// Returns true if [this] is before [other].
  bool isBefore(GpsTime other) {
    return secondsSinceEpoch < other.secondsSinceEpoch;
  }

  /// Returns true if [this] is after [other].
  bool isAfter(GpsTime other) {
    return secondsSinceEpoch > other.secondsSinceEpoch;
  }

  /// Converts to a [DateTime] object, in UTC.
  DateTime toDateTimeUtc() =>
      DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000,
          isUtc: true);

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
  int get hashCode => hash1(secondsSinceEpoch);

  @override
  String toString() => '$secondsSinceEpoch';
}
