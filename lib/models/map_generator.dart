import 'dart:math';

import 'package:flutter/material.dart';

import 'level_status.dart';
import 'level_ui_item.dart';
import 'long_distance_target_ui_item.dart';
import 'road_map.dart';
import 'side_ui_item.dart';

class MapGenerator {
  static const int totalLevels = 100;
  static const int passedCount = 20;
  static const int groupSize = 5;

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

  List<LevelUiItem> _generate100LevelsAsWaves() {
    return List.generate(totalLevels, (index) {
      final number = index + 1;
      final status = number <= passedCount
          ? LevelStatus.passed
          : (number == passedCount + 1 ? LevelStatus.inProgress : LevelStatus.notPassed);
      return LevelUiItem(
        number: number,
        status: status,
        xOffset: waveXOffsetForPosition(number.toDouble()),
      );
    });
  }

  static const int sideItemCount = 12;
  static const int targetLevelPosition = 45;

  static const List<SideItemShape> _shapeCycle = [
    SideItemShape.sphere,
    SideItemShape.cube,
    SideItemShape.pyramid,
  ];

  static const List<Color> _colorCycle = [
    Colors.orange,
    Colors.lightBlue,
    Colors.pinkAccent,
    Colors.amber,
  ];

  List<SideUiItem> _generateSideItems() {
    final spacing = totalLevels / sideItemCount;
    return List.generate(sideItemCount, (index) {
      final centerLevel = ((index + 1) * spacing).round().clamp(1, totalLevels);
      final side = index.isEven ? 1.0 : -1.0;
      final xOffset = side * (1.3 + (index % 3) * 0.1);
      return SideUiItem(
        xOffset: xOffset,
        minLevelSeen: (centerLevel - 4).clamp(1, totalLevels),
        maxLevelSeen: (centerLevel + 4).clamp(1, totalLevels),
        shape: _shapeCycle[index % _shapeCycle.length],
        color: _colorCycle[index % _colorCycle.length],
      );
    });
  }

  LongDistanceTargetUiItem _generateTarget() {
    return const LongDistanceTargetUiItem(
      xOffset: 0.0,
      levelPosition: targetLevelPosition,
    );
  }

  RoadMap generateMap() {
    return RoadMap(
      levels: _generate100LevelsAsWaves(),
      sideItems: _generateSideItems(),
      target: _generateTarget(),
    );
  }
}
