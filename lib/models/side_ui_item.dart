import 'package:flutter/material.dart';

enum SideItemShape { sphere, cube, pyramid }

class SideUiItem {
  /// -1 = pure left, 0 = middle, 1 = pure right. May exceed [-1, 1]
  /// since side items sit beside the road, not on it.
  final double xOffset;

  /// Level range during which this item is visible.
  final int minLevelSeen;
  final int maxLevelSeen;

  final SideItemShape shape;
  final Color color;

  const SideUiItem({
    required this.xOffset,
    required this.minLevelSeen,
    required this.maxLevelSeen,
    required this.shape,
    required this.color,
  });
}
