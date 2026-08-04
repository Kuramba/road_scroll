class LongDistanceTargetUiItem {
  /// -1 = pure left, 0 = middle, 1 = pure right.
  final double xOffset;

  /// Fixed level position this target sits at, far ahead on the road.
  final int levelPosition;

  const LongDistanceTargetUiItem({
    required this.xOffset,
    required this.levelPosition,
  });
}
