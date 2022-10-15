/// Offers facilities for organizing GPS items into a sparse spatial grid.

/* Copyright (c)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import 'dart:collection';

import '../base_collections.dart';
import 'hash.dart';

/// Object used as key for grid cells.
class GridCell {
  int componentA;
  int componentB;

  GridCell(this.componentA, this.componentB);

  @override
  bool operator ==(other) {
    return other is GridCell &&
        other.componentA == componentA &&
        other.componentB == componentB;
  }

  @override
  int get hashCode => hash2(componentA, componentB);
}

/// Represents a sparsely populated spatial grid of cells for GPS items, where
/// for each cell the grid remembers which item(s) in a collection of GPS items
/// are present in the cell.
class Grid {
  /// For each latitude/longitude cell, remember which index in the collection
  /// is stored there. If more than one index is stored, the value is instead
  /// an index in [_indexList] containing all the item indices for that cell.
  final _cells = HashMap<GridCell, int>();

  /// Stores for grid cells that have more than one item in them, all the items.
  /// Since by far most grid cells contain at most one item, splitting off
  /// only the ones that do contain multiple items to lists can save tens of
  /// megabytes of memory in cases with many hundreds of thousands of items.
  final List<List<int>> _indexLists = [];

  final GpsPointsView collection;

  Grid(this.collection) {
    _populateGrid();
  }

  /// Creates a key in the grid based on [latitude] and [longitude].
  GridCell _makeKey(int latitude, int longitude) {
    // Cells of 1E-4 degrees lat/long, which is order of magnitude 10m at the
    // equator.
    return GridCell(latitude ~/ 1000, longitude ~/ 1000);
  }

  /// Populates the grid based on the items in the [collection].
  _populateGrid() {
    collection.forEachLatLongE7((int index, int latitude, int longitude) {
      final key = _makeKey(latitude, longitude);

      // If there's a single item in the cell, store it as (index+1).
      // If there's more than one item in the cell, all the items will be stored
      // in a separate list that is stored in _indexLists; the position of that
      // list in _indexLists is stored as -(posInIndexLists+1) in the cell.
      final value = _cells[key];
      if (value == null) {
        // Cell previously empty -> store first item directly. Store offset by 1
        // because otherwise couldn't distinguish between 0 and -0.
        final newValue = index + 1;
        _cells[key] = newValue;
      } else if (value > 0) {
        // Cell previously contained a single item -> convert it to a multi-item
        // list.
        final int prevIndex = value - 1;
        _indexLists.add([prevIndex, index]);

        // Store the list index as negative and offset by one as well.
        final newValue = _indexLists.length;
        _cells[key] = -newValue;
      } else {
        // Cell already contained multiple items -> add to that list.
        final listPos = -value - 1;
        _indexLists[listPos].add(index);
      }
    });
  }

  /// Executes [func] for each cell in the grid that contains at least one item.
  /// [func] takes as argument a list of indices in [colleciton] present in
  /// that cell.
  forEachCell(Function(List<int> itemsInCell) func) {
    for (final key in _cells.keys) {
      // Looping over all keys -> cannot have a null value.
      final value = _cells[key]!;
      if (value > 0) {
        final index = value - 1;
        func([index]);
      } else {
        final listPos = -value - 1;
        func(_indexLists[listPos]);
      }
    }
  }
}
