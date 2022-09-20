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
TimeComparisonResult compareTime(DateTime timeA, DateTime timeB) {
  // TODO: this is sensitive to below-second differences, which the Int representation is not. This needs addressing.
  final cmpResult = timeA.compareTo(timeB);
  switch (cmpResult) {
    case -1:
      return TimeComparisonResult.before;
    case 0:
      return TimeComparisonResult.same;
    case 1:
      return TimeComparisonResult.after;
    default:
      throw RangeError('Unexpected compareTo result: $cmpResult!');
  }
}

/// Like [compareTime], except it works on Uint32 representation
/// of time that is used internally by some child classes of GpsCollection.
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
