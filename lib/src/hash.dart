// This file based on
//   https://github.com/google/quiver-dart/blob/master/lib/src/core/hash.dart
// and extended with hashes for more than four objects (hash5 and higher).
//
// Copyright 2013 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Generates a hash code for multiple [objects].
int hashObjects(Iterable objects) =>
    _finish(objects.fold(0, (h, i) => _combine(h, i.hashCode)));

/// Generates a hash code for two objects.
int hash2(a, b) => _finish(_combine(_combine(0, a.hashCode), b.hashCode));

/// Generates a hash code for three objects.
int hash3(a, b, c) => _finish(
    _combine(_combine(_combine(0, a.hashCode), b.hashCode), c.hashCode));

/// Generates a hash code for four objects.
int hash4(a, b, c, d) => _finish(_combine(
    _combine(_combine(_combine(0, a.hashCode), b.hashCode), c.hashCode),
    d.hashCode));

/// Generates a hash code for five objects.
int hash5(a, b, c, d, e) => _finish(_combine(
    _combine(
        _combine(_combine(_combine(0, a.hashCode), b.hashCode), c.hashCode),
        d.hashCode),
    e.hashCode));

/// Generates a hash code for six objects.
int hash6(a, b, c, d, e, f) => _finish(_combine(
    _combine(
        _combine(
            _combine(_combine(_combine(0, a.hashCode), b.hashCode), c.hashCode),
            d.hashCode),
        e.hashCode),
    f.hashCode));

/// Generates a hash code for seven objects.
int hash7(a, b, c, d, e, f, g) => _finish(_combine(
    _combine(
        _combine(
            _combine(
                _combine(
                    _combine(_combine(0, a.hashCode), b.hashCode), c.hashCode),
                d.hashCode),
            e.hashCode),
        f.hashCode),
    g.hashCode));

/// Generates a hash code for eight objects.
int hash8(a, b, c, d, e, f, g, h) => _finish(_combine(
    _combine(
        _combine(
            _combine(
                _combine(
                    _combine(_combine(_combine(0, a.hashCode), b.hashCode),
                        c.hashCode),
                    d.hashCode),
                e.hashCode),
            f.hashCode),
        g.hashCode),
    h.hashCode));

// Jenkins hash functions

int _combine(int hash, int value) {
  hash = 0x1fffffff & (hash + value);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}

int _finish(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}
