/// Provides a stub implementation for the web compilation target, which does
/// not support io and hence cannot support file-based parsing.

/*
 * Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'gj_file_to_points_base.dart';

/// Returns a parser stub that does not actually work.
GoogleJsonFileParser getParser(ParsingOptions options) =>
    GoogleJsonFileParser(options);
