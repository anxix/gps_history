# 0.0.7

* Public API changes:
  * The time values of ```GpsPoint``` have been changed to use an integer 
    representation with 1 second resolution. This is similar to what the
    efficient collection implementation already did, and reduces complexity
    and inconsistencies between the previouw DateTime based versions and
    integer based versions (two points could be different when stored in a List
    or list-based collection compared to when stored in an efficient 
    collection).
  * Setting time values to values outside the supported range (from 1970 up
    to around 2106) will by default throw an exception, but can optionally be
    clamped by the additional ```autoClamp``` paramter accepted by the various
    methods that can instantiate ```GpsTime``` objects.

* New features:
  * Added ```GpsStay``` to represent a longer period of time spent in one place,
    without requiring a bunch of separate ```GpsPoint``` instances.

* Fixes:
  * The various time comparison functions for ```GpcCompactGpsMeasurement```
    would not use fast comparisons on the binary representation. They do now.
  * 3-4x faster ```addAll``` implementation when dealing with a generic iterable 
    source that has millions upon millions of items. OF course copying from 
    efficient collection to an efficient collection of the same time is even 
    faster, by a factor 10 or so.
  * Rearranged internals into a few smaller files for easier navigation.


# 0.0.6

* Public API changes:
  * Removed the ```addAll*Fast``` family of methods from the ```GpcEfficient```
   classes. The fast implementation was already called automatically by the
   ```addAll*``` methods when possible (as of version 0.0.5).
  * Made the constructors of all ```GpsPoint``` and children use mandatory 
    named parameters, because reading and writing the long lists of positional
    arguments is a bit error-prone. Nullable parameters are made optional,
    in order to reduce pointless noise.

* New features:
  * Implemented faster versions of several methods in the RandomAccessIterable.
  * Added a sample application for converting Google location history JSON file 
    to a SQLite database.
  * Support for tracking and enforcing sorted state of 
    ```GpsPointsCollection```. This will allow fast binary search queries based
    on time.
  * Added ```copyWith``` methods for ```GpsPoint``` and children.
  * Added null-like and zero-like statics for ```GpsPoint``` and children, which
    are useful in unit tests. Also combined with the ```copyWith``` methods.


# 0.0.5

* New features:
  * Added addAllStartingAt. This required some refactoring of the base 
    classes for the Iterable implementation.

* Fixes:
  * The addAll implementation of GpcEfficient<T> automatically switches to
    addAllFast when possible.
  * Fixed bugs in the addAll/addAllFast implementations.


# 0.0.4

* Various updates to be compatible with more modern (dart 2.17.6) tooling.
  This includes switching to the new linter, using dart doc instead of dartdoc.
  No API changes.


# 0.0.3

* New features:
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
