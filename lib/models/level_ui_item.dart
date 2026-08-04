import 'level_status.dart';

class LevelUiItem {
  final int number;
  final LevelStatus status;

  /// -1 = pure left, 0 = middle, 1 = pure right.
  final double xOffset;

  const LevelUiItem({
    required this.number,
    required this.status,
    required this.xOffset,
  });
}
