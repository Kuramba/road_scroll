import 'dart:math';

import 'package:flutter/material.dart';

import 'level_status.dart';
import 'level_ui_item.dart';
import 'long_distance_target_ui_item.dart';
import 'side_ui_item.dart';

/// Levels are infinite: nothing here is pre-generated into a fixed-size
/// list. Every member is a pure, stateless function of a level number, so
/// callers (the ViewModel) can ask for whatever window they currently need.
class MapGenerator {
  static const int passedCount = 20;
  static const int groupSize = 5;
  static const int sideItemSpacing = 8;
  static const int sideItemVisibilityHalfWidth = 4;

  static const List<SideItemShape> _shapeCycle = [SideItemShape.sphere, SideItemShape.cube, SideItemShape.pyramid];

  static const List<Color> _colorCycle = [Colors.orange, Colors.lightBlue, Colors.pinkAccent, Colors.amber];

  static const LongDistanceTargetUiItem target = LongDistanceTargetUiItem(xOffset: 0.0);

  /// Continuous, pure wave function: -1..1, period of 10 levels
  /// (5 sweeping left-to-right, 5 sweeping back), smoothed across
  /// direction-change boundaries so the path curves rather than kinks.
  /// `levelPosition` may be fractional (used for camera tracking too).
  static double waveXOffsetForPosition(double levelPosition) {
    final relative = levelPosition - 1.0;
    final group = (relative / groupSize).floor();
    final localFraction = (relative / groupSize) - group;
    final eased = 0.5 - 0.5 * cos(pi * localFraction);
    final sweepingUp = group.isEven;
    return sweepingUp ? (-1.0 + 2.0 * eased) : (1.0 - 2.0 * eased);
  }

  static LevelStatus statusForLevel(int number) {
    if (number <= passedCount) return LevelStatus.passed;
    if (number == passedCount + 1) return LevelStatus.inProgress;
    return LevelStatus.notPassed;
  }

  /// The single level at [number], generated on demand.
  static LevelUiItem levelAt(int number) {
    return LevelUiItem(number: number, status: statusForLevel(number), xOffset: waveXOffsetForPosition(number.toDouble()));
  }

  /// The side item centered at [centerLevel], which must be a positive
  /// multiple of [sideItemSpacing].
  static SideUiItem sideItemAt(int centerLevel) {
    final index = centerLevel ~/ sideItemSpacing;
    final side = index.isEven ? 1.0 : -1.0;
    // Smooth curve instead of a stepped magnitude, so the distance from
    // the road swells and eases across the sequence of side items.
    final curveMagnitude = 1.3 + 0.5 * sin(index * pi / 3);
    return SideUiItem(
      xOffset: side * curveMagnitude,
      minLevelSeen: centerLevel - sideItemVisibilityHalfWidth,
      maxLevelSeen: centerLevel + sideItemVisibilityHalfWidth,
      shape: _shapeCycle[index % _shapeCycle.length],
      color: _colorCycle[index % _colorCycle.length],
    );
  }

  /// Every side item whose visibility range overlaps [minLevel, maxLevel].
  static List<SideUiItem> sideItemsInRange(double minLevel, double maxLevel) {
    final firstCenter = ((minLevel - sideItemVisibilityHalfWidth) / sideItemSpacing).floor() * sideItemSpacing;
    final items = <SideUiItem>[];
    for (var center = firstCenter; center <= maxLevel + sideItemVisibilityHalfWidth; center += sideItemSpacing) {
      if (center < sideItemSpacing) continue;
      items.add(sideItemAt(center));
    }
    return items;
  }
}
