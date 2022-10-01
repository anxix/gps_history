/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

const nrLoops = 500000000;

int f(int x) {
  return x + 1;
}

int g(int Function(int) func, int value) {
  return func(value);
}

int h(int value) {
  return f(value);
}

void main(List<String> args) {
  final stopwatch = Stopwatch();

  stopwatch.start();
  int sum = 0;
  for (var i = 0; i <= nrLoops; i++) {
    sum = f(sum);
  }
  stopwatch.stop();
  print('Direct: answer $sum in ${stopwatch.elapsedMilliseconds} ms');

  stopwatch.reset();

  stopwatch.start();
  sum = 0;
  for (var i = 0; i <= nrLoops; i++) {
    sum = g(f, sum);
  }
  stopwatch.stop();
  print('Function pointer: answer $sum in ${stopwatch.elapsedMilliseconds} ms');

  stopwatch.reset();

  stopwatch.start();
  sum = 0;
  for (var i = 0; i <= nrLoops; i++) {
    sum = h(sum);
  }
  stopwatch.stop();
  print(
      'Function calling function: answer $sum in ${stopwatch.elapsedMilliseconds} ms');
}
