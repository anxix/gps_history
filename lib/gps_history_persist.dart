/// The GPS History Persistence library provides persistence related facilities
/// for the GPS History library.

/* Copyright (c) 
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

library gps_history_persist;

import 'package:gps_history/src/persist/persistence.dart';
import 'package:gps_history/src/persist/p_gpc_efficient.dart';

export 'src/persist/persistence.dart';
export 'src/persist/utilities.dart';
export 'src/persist/p_gpc_efficient.dart';

/// Function that creates and registers the default persisters for the
/// built-in container types. Call it from the calling code's main() function
/// for example, unless you want to do your own persistence registration from
/// scratch.
void initializeDefaultPersisters() {
  Persistence.get()
    ..register(PGpcCompactGpsPoint())
    ..register(PGpcCompactGpsMeasurement());
}
