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
abstract class RandomAccessIterable<T> extends Iterable<T>
//with IterableMixin<T>
{
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
  // @override
  // RandomAccessIterable<T> take(int count) {
  //   return RandomAccessSkipIterable<T>(this, count);
  // }
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
  int _index = -1;
  final RandomAccessIterable<T> _source;

  /// Creates the iterator for the specified [_source] iterable, optionally
  /// allowing to skip [skipCount] items at the start of the iteration.
  RandomAccessIterator(this._source, [int skipCount = 0]) {
    assert(skipCount >= 0);
    _index += skipCount;
  }

  @override
  bool moveNext() {
    if (_index + 1 >= _source.length) {
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

// class RandomAccessTakeIterable<E> extends RandomAccessIterable<E> {
//   final RandomAccessIterable<E> _iterable;
//   final int _takeCount;

//   factory RandomAccessTakeIterable(
//       RandomAccessIterable<E> iterable, int takeCount) {
//     ArgumentError.checkNotNull(takeCount, "takeCount");
//     RangeError.checkNotNegative(takeCount, "takeCount");
//     return RandomAccessTakeIterable<E>._(iterable, takeCount);
//   }

//   RandomAccessTakeIterable._(this._iterable, this._takeCount);

//   @override
//   RandomAccessIterator<E> get iterator {
//     return RandomAccessTakeIterator<E>(_iterable, _takeCount);
//   }

//   @override
//   int get length {
//     int iterableLength = _iterable.length;
//     if (iterableLength > _takeCount) return _takeCount;
//     return iterableLength;
//   }

//   @override
//   E operator [](int index) {
//     if (index >= length) {
//       throw IndexError(index, this, '', '', length);
//     }
//     return _iterable[index];
//   }
// }

// class RandomAccessTakeIterator<E> extends RandomAccessIterator<E> {
//   int _remaining;

//   RandomAccessTakeIterator(super._source, this._remaining) {
//     assert(_remaining >= 0);
//   }

//   @override
//   bool moveNext() {
//     _remaining--;
//     if (_remaining >= 0) {
//       return _source.iterator.moveNext();
//     }
//     _remaining = -1;
//     return false;
//   }

//   @override
//   E get current {
//     // Before NNBD, this returned null when iteration was complete. In order to
//     // avoid a hard breaking change, we return "null as E" in that case so that
//     // if strong checking is not enabled or E is nullable, the existing
//     // behavior is preserved.
//     if (_remaining < 0) return null as E;
//     return _source.iterator.current;
//   }
// }
