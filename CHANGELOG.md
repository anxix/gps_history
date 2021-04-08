# 0.0.1

* Initial public release. Includes:
  * Two types of GPS point: a lean one with just the bare minimums and one
    with more meta information such as heading, speed, etc. that's useful for
    GPX files for example.
  * Different in-memory storage systems for GPS points: either simply 
    list-based, or extremely efficient binary representation (at the cost of
    minuscule loss of accuracy).
  * Extremely fast and low-memory parser for Google location history JSON
    export.
  * Many unit tests and doc strings.
