# 0.0.4

* Various updates to be compatible with more modern (dart 2.17.6) tooling.
  This includes switching to the new linter, using dart doc instead of dartdoc.
  No API changes.


# 0.0.3

* Implemented persistence mechanism.


# 0.0.2

* Public API changes:
  * ```GoogleJsonHistoryBinaryDecoder``` renamed to 
    ```GoogleJsonHistoryDecoder```, as the binary parser seems pretty stable.
    Similar naming changes for related classes, but those are not typically 
    used directly.
  * Removed ```GoogleJsonHistoryStringDecoder``` as it's slower and less
    flexible than the now standard binary decoder.

* Fixes:
  * Several corner cases in the Google location history JSON parsing.
  * Unit tests for ```GoogleJsonHistoryDecoder```.
  * Added ```example.md``` file in the examples directory to convince pub.dev
    that there are indeed examples in the release.
  * Latitude cannot be -180..180, but -90..90.


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
