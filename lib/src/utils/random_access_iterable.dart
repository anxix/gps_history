/// Classes providing [Iterable] functionality with guaranteed fast random
/// item access.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/// Abstract class representing iterables with fast random access to contents.
///
/// Subclasses should implement fast access to [length], getting item by index
/// and similar functionality. This can not be enforced, but code using it
/// will rely on these operations not looping over the entire contents before
/// returning a result.
abstract class RandomAccessIterable<T> extends Iterable<T> {
  T operator [](int index);

  @override
  RandomAccessIterator<T> get iterator => RandomAccessIterator<T>(this);

  @override
  T elementAt(int index) {
    return this[index];
  }

  @override
  T get first {
    if (isEmpty) {
      throw StateError('no element');
    }
    return this[0];
  }

  @override
  T get last {
    if (isEmpty) {
      throw StateError('no element');
    }
    return this[length - 1];
  }

  @override
  bool get isEmpty => length == 0;

  @override
  RandomAccessIterable<T> skip(int count) {
    return RandomAccessSkipIterable<T>(this, count);
  }

// TODO: implement take()
  @override
  RandomAccessIterable<T> take(int count) {
    return RandomAccessTakeIterable<T>(this, count);
  }
}

/// Iterator support for [RandomAccessIterable].
///
/// The iterator allows [RandomAccessIterable] and children to easily implement
/// an Iterable interface. An important limitation is that the wrapped
/// [RandomAccessIterable] must be random-access, with quick access to items and
/// properties like length. This is a workaround for the fact that Dart doesn't
/// expose the [RandomAccessSkipIterable] interface for implementation in
/// third party code.
class RandomAccessIterator<T> extends Iterator<T> {
  late int _index;
  late int _end;
  final RandomAccessIterable<T> _source;

  /// Creates the iterator for the specified [_source] iterable, optionally
  /// allowing to skip [skipCount] items at the start of the iteration and
  /// stop the iteration at position [end] (skipCount <= end <= [length]).
  RandomAccessIterator(this._source, [int skipCount = 0, int? end]) {
    RangeError.checkValidRange(skipCount, end, _source.length, 'skipCount',
        'end', 'Incorrect paramters for RandomAccessIterator');
    _index = skipCount - 1;
    _end = end ?? _source.length;
  }

  @override
  bool moveNext() {
    if (_index + 1 >= _end) {
      return false;
    }

    _index += 1;
    return true;
  }

  @override
  T get current {
    return _source[_index];
  }
}

/// An iterable aimed at quickly skipping a number of items at the beginning.
class RandomAccessSkipIterable<T> extends RandomAccessIterable<T> {
  final RandomAccessIterable<T> _iterable;
  final int _skipCount;

  factory RandomAccessSkipIterable(
      RandomAccessIterable<T> iterable, int skipCount) {
    return RandomAccessSkipIterable<T>._(iterable, _checkCount(skipCount));
  }

  RandomAccessSkipIterable._(this._iterable, this._skipCount);

  @override
  T operator [](int index) => _iterable[index + _skipCount];

  @override
  int get length {
    int result = _iterable.length - _skipCount;
    if (result >= 0) return result;
    return 0;
  }

  @override
  RandomAccessIterable<T> skip(int count) {
    return RandomAccessSkipIterable<T>._(
        _iterable, _skipCount + _checkCount(count));
  }

  @override
  RandomAccessIterator<T> get iterator {
    return RandomAccessIterator<T>(_iterable, _skipCount);
  }

  static int _checkCount(int count) {
    RangeError.checkNotNegative(count, "count");
    return count;
  }
}

/// An iterable aimed at only taking a limited number of items at the beginning.
class RandomAccessTakeIterable<E> extends RandomAccessIterable<E> {
  final RandomAccessIterable<E> _iterable;
  final int _takeCount;

  factory RandomAccessTakeIterable(
      RandomAccessIterable<E> iterable, int takeCount) {
    ArgumentError.checkNotNull(takeCount, "takeCount");
    RangeError.checkNotNegative(takeCount, "takeCount");
    return RandomAccessTakeIterable<E>._(iterable, takeCount);
  }

  RandomAccessTakeIterable._(this._iterable, this._takeCount);

  @override
  RandomAccessIterator<E> get iterator {
    return RandomAccessIterator<E>(_iterable, 0, _takeCount);
  }

  @override
  int get length {
    int iterableLength = _iterable.length;
    if (iterableLength > _takeCount) return _takeCount;
    return iterableLength;
  }

  @override
  E operator [](int index) {
    if (index >= length) {
      throw IndexError(index, this, '', '', length);
    }
    return _iterable[index];
  }
}
